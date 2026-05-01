import json
import urllib.error
import urllib.request
from unittest.mock import MagicMock, patch

import pytest

import importlib
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))

glab_harness = importlib.import_module("glab-harness")


@pytest.fixture(autouse=True)
def set_gitlab_token_environment_variable(monkeypatch):
    monkeypatch.setenv("GITLAB_TOKEN", "fake-token-for-testing")


@pytest.fixture(autouse=True)
def mock_git_remote(monkeypatch):
    import subprocess

    original_run = subprocess.run

    def patched_run(command, **kwargs):
        if isinstance(command, list) and "get-url" in command:
            return subprocess.CompletedProcess(
                args=command,
                returncode=0,
                stdout="git@git.coates.io:digital-production/mcdca-tools/mcdca-workspace.git\n",
                stderr="",
            )
        return original_run(command, **kwargs)

    monkeypatch.setattr(subprocess, "run", patched_run)


def make_mock_http_response(response_data):
    response_body = json.dumps(response_data).encode("utf-8")
    mock_response = MagicMock()
    mock_response.read.return_value = response_body
    mock_response.__enter__ = lambda s: s
    mock_response.__exit__ = MagicMock(return_value=False)
    return mock_response


class TestResolveGitlabToken:
    def test_returns_token_from_environment(self, monkeypatch):
        monkeypatch.setenv("GITLAB_TOKEN", "env-token")
        assert glab_harness.resolve_gitlab_token() == "env-token"

    def test_exits_when_no_token_and_no_secret_file(self, monkeypatch, tmp_path):
        monkeypatch.delenv("GITLAB_TOKEN", raising=False)
        monkeypatch.setattr(
            glab_harness,
            "GITLAB_TOKEN_SECRET_FILE_PATH",
            tmp_path / "does-not-exist",
        )
        with pytest.raises(SystemExit):
            glab_harness.resolve_gitlab_token()

    def test_reads_token_from_secret_file(self, monkeypatch, tmp_path):
        monkeypatch.delenv("GITLAB_TOKEN", raising=False)
        secret_file = tmp_path / "glab-token"
        secret_file.write_text("token-from-disk\n")
        monkeypatch.setattr(glab_harness, "GITLAB_TOKEN_SECRET_FILE_PATH", secret_file)
        assert glab_harness.resolve_gitlab_token() == "token-from-disk"


class TestResolveProjectPathFromGitRemote:
    @patch("subprocess.run")
    def test_parses_ssh_remote_url(self, mock_run):
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout="git@git.coates.io:digital-production/mcdca-tools/mcdca-workspace.git\n",
        )
        assert (
            glab_harness.resolve_project_path_from_git_remote()
            == "digital-production/mcdca-tools/mcdca-workspace"
        )

    @patch("subprocess.run")
    def test_parses_https_remote_url(self, mock_run):
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout="https://git.coates.io/digital-production/mcdca-tools/mcdca-workspace.git\n",
        )
        assert (
            glab_harness.resolve_project_path_from_git_remote()
            == "digital-production/mcdca-tools/mcdca-workspace"
        )

    @patch("subprocess.run")
    def test_exits_when_not_a_git_repo(self, mock_run):
        mock_run.return_value = MagicMock(
            returncode=1, stdout="", stderr="not a git repo"
        )
        with pytest.raises(SystemExit):
            glab_harness.resolve_project_path_from_git_remote()


class TestGitlabApiRequest:
    @patch("urllib.request.urlopen")
    def test_get_request_returns_parsed_json(self, mock_urlopen):
        expected_response = {"id": 1, "name": "test"}
        mock_urlopen.return_value = make_mock_http_response(expected_response)
        result = glab_harness.gitlab_api_request(
            "GET", "projects/123/merge_requests/1", "fake-token"
        )
        assert result == expected_response

    @patch("urllib.request.urlopen")
    def test_post_request_sends_json_body(self, mock_urlopen):
        mock_urlopen.return_value = make_mock_http_response({"iid": 42})
        glab_harness.gitlab_api_request(
            "POST", "projects/123/merge_requests", "fake-token", body={"title": "Test"}
        )
        sent_request = mock_urlopen.call_args[0][0]
        assert sent_request.method == "POST"
        assert json.loads(sent_request.data) == {"title": "Test"}
        assert sent_request.headers["Content-type"] == "application/json"

    @patch("urllib.request.urlopen")
    def test_includes_private_token_header(self, mock_urlopen):
        mock_urlopen.return_value = make_mock_http_response({})
        glab_harness.gitlab_api_request("GET", "test", "my-secret-token")
        sent_request = mock_urlopen.call_args[0][0]
        assert sent_request.headers["Private-token"] == "my-secret-token"

    @patch("urllib.request.urlopen")
    def test_exits_on_http_error(self, mock_urlopen):
        mock_urlopen.side_effect = urllib.error.HTTPError(
            url="test",
            code=404,
            msg="Not Found",
            hdrs={},
            fp=MagicMock(read=lambda: b'{"message":"not found"}'),
        )
        with pytest.raises(SystemExit):
            glab_harness.gitlab_api_request("GET", "bad-endpoint", "fake-token")


class TestResolveUsernameToId:
    @patch("urllib.request.urlopen")
    def test_resolves_single_username(self, mock_urlopen):
        mock_urlopen.return_value = make_mock_http_response(
            [{"id": 5, "username": "bob"}]
        )
        assert glab_harness.resolve_username_to_id("bob", "fake-token") == 5

    @patch("urllib.request.urlopen")
    def test_returns_none_for_unknown_username(self, mock_urlopen, capsys):
        mock_urlopen.return_value = make_mock_http_response([])
        assert glab_harness.resolve_username_to_id("nobody", "fake-token") is None
        assert "not found" in capsys.readouterr().err


class TestResolveCommaSeparatedUsernamesToIds:
    @patch("urllib.request.urlopen")
    def test_resolves_multiple_usernames(self, mock_urlopen):
        mock_urlopen.side_effect = [
            make_mock_http_response([{"id": 5, "username": "bob"}]),
            make_mock_http_response([{"id": 8, "username": "carol"}]),
        ]
        assert glab_harness.resolve_comma_separated_usernames_to_ids(
            "bob,carol", "fake-token"
        ) == [5, 8]


class TestCommandMergeRequestView:
    @patch("urllib.request.urlopen")
    def test_prints_merge_request_details(self, mock_urlopen, capsys):
        mock_urlopen.return_value = make_mock_http_response(
            {
                "iid": 88,
                "title": "Tiered permissions",
                "state": "opened",
                "source_branch": "feature/tiered",
                "target_branch": "develop",
                "author": {"username": "lucas"},
                "assignees": [{"username": "lucas"}],
                "reviewers": [{"username": "brian"}],
                "has_conflicts": False,
                "detailed_merge_status": "mergeable",
                "web_url": "https://git.coates.io/mr/88",
                "description": "Test description",
            }
        )
        args = MagicMock(iid=88)
        glab_harness.command_merge_request_view(args, "fake-token", "test/project")
        output = capsys.readouterr().out
        assert "!88" in output
        assert "Tiered permissions" in output
        assert "lucas" in output
        assert "brian" in output


class TestCommandMergeRequestCreate:
    @patch("urllib.request.urlopen")
    def test_creates_merge_request_with_required_fields(self, mock_urlopen):
        mock_urlopen.return_value = make_mock_http_response(
            {"iid": 42, "title": "Test", "web_url": "https://example.com/mr/42"}
        )
        args = MagicMock(
            source="feature/test",
            target="develop",
            title="Test",
            description_file=None,
            assignee=None,
            reviewer=None,
            remove_source_branch=False,
        )
        glab_harness.command_merge_request_create(args, "fake-token", "test/project")
        sent_request = mock_urlopen.call_args[0][0]
        sent_body = json.loads(sent_request.data)
        assert sent_body["source_branch"] == "feature/test"
        assert sent_body["target_branch"] == "develop"
        assert sent_body["title"] == "Test"

    @patch("urllib.request.urlopen")
    def test_reads_description_from_file(self, mock_urlopen, tmp_path):
        description_file = tmp_path / "description.md"
        description_file.write_text(
            "## What\n- Feature with `special` chars & markdown\n"
        )
        mock_urlopen.return_value = make_mock_http_response(
            {"iid": 43, "title": "With desc", "web_url": "https://example.com/mr/43"}
        )
        args = MagicMock(
            source="feature/test",
            target="develop",
            title="With desc",
            description_file=str(description_file),
            assignee=None,
            reviewer=None,
            remove_source_branch=False,
        )
        glab_harness.command_merge_request_create(args, "fake-token", "test/project")
        sent_body = json.loads(mock_urlopen.call_args[0][0].data)
        assert "special" in sent_body["description"]
        assert "&" in sent_body["description"]


class TestCommandMergeRequestUpdate:
    @patch("urllib.request.urlopen")
    def test_updates_title(self, mock_urlopen):
        mock_urlopen.return_value = make_mock_http_response(
            {"iid": 88, "title": "New title", "web_url": "https://example.com/mr/88"}
        )
        args = MagicMock(
            iid=88,
            title="New title",
            description_file=None,
            assignee=None,
            reviewer=None,
        )
        glab_harness.command_merge_request_update(args, "fake-token", "test/project")
        sent_body = json.loads(mock_urlopen.call_args[0][0].data)
        assert sent_body["title"] == "New title"

    @patch("urllib.request.urlopen")
    def test_updates_description_from_file(self, mock_urlopen, tmp_path):
        description_file = tmp_path / "desc.md"
        description_file.write_text("Updated description with @mentions and `code`")
        mock_urlopen.return_value = make_mock_http_response(
            {"iid": 88, "title": "Same", "web_url": "https://example.com/mr/88"}
        )
        args = MagicMock(
            iid=88,
            title=None,
            description_file=str(description_file),
            assignee=None,
            reviewer=None,
        )
        glab_harness.command_merge_request_update(args, "fake-token", "test/project")
        sent_body = json.loads(mock_urlopen.call_args[0][0].data)
        assert "@mentions" in sent_body["description"]

    def test_exits_when_no_fields_provided(self):
        args = MagicMock(
            iid=88, title=None, description_file=None, assignee=None, reviewer=None
        )
        with pytest.raises(SystemExit):
            glab_harness.command_merge_request_update(
                args, "fake-token", "test/project"
            )


class TestCommandMergeRequestDiscussions:
    @patch("urllib.request.urlopen")
    def test_prints_inline_code_comment_with_file_and_line(self, mock_urlopen, capsys):
        mock_urlopen.return_value = make_mock_http_response(
            [
                {
                    "notes": [
                        {
                            "system": False,
                            "author": {
                                "name": "Vishwa Shah",
                                "username": "Vishwa.Shah",
                            },
                            "body": "seems like username is missing here",
                            "position": {
                                "new_path": "backend/services/users.service.ts",
                                "new_line": 55,
                            },
                        }
                    ]
                }
            ]
        )
        args = MagicMock(iid=87)
        glab_harness.command_merge_request_discussions(
            args, "fake-token", "test/project"
        )
        output = capsys.readouterr().out
        assert "Vishwa Shah" in output
        assert "users.service.ts:55" in output
        assert "username is missing" in output

    @patch("urllib.request.urlopen")
    def test_prints_general_comment_without_position(self, mock_urlopen, capsys):
        mock_urlopen.return_value = make_mock_http_response(
            [
                {
                    "notes": [
                        {
                            "system": False,
                            "author": {"name": "Brian", "username": "Brian.A"},
                            "body": "LGTM",
                        }
                    ]
                }
            ]
        )
        args = MagicMock(iid=87)
        glab_harness.command_merge_request_discussions(
            args, "fake-token", "test/project"
        )
        output = capsys.readouterr().out
        assert "Brian" in output
        assert "LGTM" in output

    @patch("urllib.request.urlopen")
    def test_skips_system_notes(self, mock_urlopen, capsys):
        mock_urlopen.return_value = make_mock_http_response(
            [
                {
                    "notes": [
                        {
                            "system": True,
                            "author": {"name": "System", "username": "system"},
                            "body": "merged",
                        }
                    ]
                }
            ]
        )
        args = MagicMock(iid=87)
        glab_harness.command_merge_request_discussions(
            args, "fake-token", "test/project"
        )
        output = capsys.readouterr().out
        assert "No comments" in output

    @patch("urllib.request.urlopen")
    def test_prints_no_comments_message_when_empty(self, mock_urlopen, capsys):
        mock_urlopen.return_value = make_mock_http_response([])
        args = MagicMock(iid=87)
        glab_harness.command_merge_request_discussions(
            args, "fake-token", "test/project"
        )
        output = capsys.readouterr().out
        assert "No comments" in output


class TestCommandMergeRequestChanges:
    @patch("urllib.request.urlopen")
    def test_lists_changed_files(self, mock_urlopen, capsys):
        mock_urlopen.return_value = make_mock_http_response(
            {"changes": [{"new_path": "src/app.tsx"}, {"new_path": "src/layout.css"}]}
        )
        args = MagicMock(iid=88)
        glab_harness.command_merge_request_changes(args, "fake-token", "test/project")
        output = capsys.readouterr().out
        assert "2 files changed" in output
        assert "src/app.tsx" in output


class TestCommandMergeRequestClose:
    @patch("urllib.request.urlopen")
    def test_closes_merge_request(self, mock_urlopen, capsys):
        mock_urlopen.return_value = make_mock_http_response(
            {"iid": 83, "state": "closed"}
        )
        args = MagicMock(iid=83)
        glab_harness.command_merge_request_close(args, "fake-token", "test/project")
        output = capsys.readouterr().out
        assert "!83 closed" in output


class TestCommandMergeRequestMerge:
    @patch("urllib.request.urlopen")
    def test_merges_merge_request(self, mock_urlopen, capsys):
        mock_urlopen.return_value = make_mock_http_response(
            {"iid": 88, "state": "merged"}
        )
        args = MagicMock(iid=88, squash=False)
        glab_harness.command_merge_request_merge(args, "fake-token", "test/project")
        output = capsys.readouterr().out
        assert "!88 merged" in output

    @patch("urllib.request.urlopen")
    def test_merges_with_squash(self, mock_urlopen):
        mock_urlopen.return_value = make_mock_http_response(
            {"iid": 88, "state": "merged"}
        )
        args = MagicMock(iid=88, squash=True)
        glab_harness.command_merge_request_merge(args, "fake-token", "test/project")
        sent_body = json.loads(mock_urlopen.call_args[0][0].data)
        assert sent_body["squash"] is True


class TestCommandPipelines:
    @patch("urllib.request.urlopen")
    def test_lists_pipelines(self, mock_urlopen, capsys):
        mock_urlopen.return_value = make_mock_http_response(
            [
                {
                    "id": 1000,
                    "status": "success",
                    "source": "push",
                    "created_at": "2026-03-28T06:08:57Z",
                }
            ]
        )
        args = MagicMock(ref=None, count=5)
        glab_harness.command_pipelines(args, "fake-token", "test/project")
        output = capsys.readouterr().out
        assert "#1000" in output
        assert "success" in output

    @patch("urllib.request.urlopen")
    def test_filters_by_ref(self, mock_urlopen):
        mock_urlopen.return_value = make_mock_http_response([])
        args = MagicMock(ref="release/uat", count=5)
        glab_harness.command_pipelines(args, "fake-token", "test/project")
        sent_url = mock_urlopen.call_args[0][0].full_url
        assert "release" in sent_url


class TestCommandPipelineJobs:
    @patch("urllib.request.urlopen")
    def test_lists_jobs(self, mock_urlopen, capsys):
        mock_urlopen.return_value = make_mock_http_response(
            [
                {
                    "name": "build:uat",
                    "status": "success",
                    "stage": "build",
                    "finished_at": "2026-03-28T07:30:00Z",
                }
            ]
        )
        args = MagicMock(pipeline_id=1000)
        glab_harness.command_pipeline_jobs(args, "fake-token", "test/project")
        output = capsys.readouterr().out
        assert "build:uat" in output
        assert "success" in output


class TestCommandDeleteBranch:
    @patch("urllib.request.urlopen")
    def test_deletes_branch_with_url_encoding(self, mock_urlopen, capsys):
        mock_urlopen.return_value = make_mock_http_response({})
        args = MagicMock(branch_name="release/uat-27-03-2026")
        glab_harness.command_delete_branch(args, "fake-token", "test/project")
        sent_url = mock_urlopen.call_args[0][0].full_url
        assert "release%2Fuat-27-03-2026" in sent_url
        output = capsys.readouterr().out
        assert "deleted" in output
