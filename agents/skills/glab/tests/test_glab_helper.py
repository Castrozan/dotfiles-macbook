import json
import subprocess
from unittest.mock import patch

import pytest

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))

import importlib

glab_helper = importlib.import_module("glab-helper")


@pytest.fixture(autouse=True)
def set_gitlab_token_environment_variable(monkeypatch):
    monkeypatch.setenv("GITLAB_TOKEN", "fake-token-for-testing")


def make_successful_subprocess_result(stdout="", stderr=""):
    return subprocess.CompletedProcess(
        args=[], returncode=0, stdout=stdout, stderr=stderr
    )


def make_failed_subprocess_result(stderr="error"):
    return subprocess.CompletedProcess(args=[], returncode=1, stdout="", stderr=stderr)


class TestEnsureAuthentication:
    def test_succeeds_when_gitlab_token_is_set(self, monkeypatch):
        monkeypatch.setenv("GITLAB_TOKEN", "test-token")
        glab_helper.ensure_authentication()

    def test_exits_when_no_token_and_no_secrets_file(self, monkeypatch, tmp_path):
        monkeypatch.delenv("GITLAB_TOKEN", raising=False)
        monkeypatch.setattr(
            os.path, "expanduser", lambda x: str(tmp_path / "nonexistent")
        )
        with pytest.raises(SystemExit):
            glab_helper.ensure_authentication()

    @patch("subprocess.run")
    def test_sources_secrets_when_token_missing(self, mock_run, monkeypatch, tmp_path):
        monkeypatch.delenv("GITLAB_TOKEN", raising=False)
        secrets_file = tmp_path / ".secrets" / "source-secrets.sh"
        secrets_file.parent.mkdir(parents=True)
        secrets_file.touch()
        monkeypatch.setattr(os.path, "expanduser", lambda x: str(secrets_file))
        mock_run.return_value = make_successful_subprocess_result(
            stdout="sourced-token\n"
        )
        glab_helper.ensure_authentication()
        assert os.environ.get("GITLAB_TOKEN") == "sourced-token"


class TestGlabApi:
    @patch("subprocess.run")
    def test_get_request_returns_parsed_json(self, mock_run):
        expected_response = {"id": 1, "name": "test"}
        mock_run.return_value = make_successful_subprocess_result(
            stdout=json.dumps(expected_response)
        )
        result = glab_helper.glab_api("projects/:fullpath/merge_requests/1")
        assert result == expected_response
        called_command = mock_run.call_args[0][0]
        assert "glab" in called_command
        assert "--method" in called_command
        assert "GET" in called_command

    @patch("subprocess.run")
    def test_post_request_includes_fields(self, mock_run):
        mock_run.return_value = make_successful_subprocess_result(
            stdout=json.dumps({"iid": 99})
        )
        glab_helper.glab_api(
            "projects/:fullpath/merge_requests",
            method="POST",
            fields={"title": "Test MR", "source_branch": "dev"},
        )
        called_command = mock_run.call_args[0][0]
        assert "POST" in called_command
        assert "-f" in called_command
        field_args = [
            called_command[i + 1] for i, arg in enumerate(called_command) if arg == "-f"
        ]
        assert "title=Test MR" in field_args
        assert "source_branch=dev" in field_args

    @patch("subprocess.run")
    def test_exits_on_api_error(self, mock_run):
        mock_run.return_value = make_failed_subprocess_result(stderr="401 Unauthorized")
        with pytest.raises(SystemExit):
            glab_helper.glab_api("projects/:fullpath/bad-endpoint")


class TestCreateMergeRequest:
    @patch("subprocess.run")
    def test_creates_merge_request_with_required_fields(self, mock_run):
        mock_run.return_value = make_successful_subprocess_result(
            stdout=json.dumps(
                {"iid": 42, "title": "Test", "web_url": "https://example.com/mr/42"}
            )
        )
        result = glab_helper.create_merge_request(
            source_branch="develop",
            target_branch="main",
            title="Test",
        )
        assert result["iid"] == 42
        called_command = mock_run.call_args[0][0]
        field_args = [
            called_command[i + 1] for i, arg in enumerate(called_command) if arg == "-f"
        ]
        assert "source_branch=develop" in field_args
        assert "target_branch=main" in field_args
        assert "title=Test" in field_args

    @patch("subprocess.run")
    def test_creates_merge_request_with_assignees_and_reviewers(self, mock_run):
        user_lookup_response = json.dumps([{"id": 10, "username": "alice"}])
        merge_request_response = json.dumps(
            {
                "iid": 43,
                "title": "With reviewers",
                "web_url": "https://example.com/mr/43",
            }
        )
        mock_run.side_effect = [
            make_successful_subprocess_result(stdout=user_lookup_response),
            make_successful_subprocess_result(stdout=user_lookup_response),
            make_successful_subprocess_result(stdout=merge_request_response),
        ]
        result = glab_helper.create_merge_request(
            source_branch="feat",
            target_branch="main",
            title="With reviewers",
            assignee_usernames="alice",
            reviewer_usernames="alice",
        )
        assert result["iid"] == 43


class TestResolveUserIds:
    @patch("subprocess.run")
    def test_resolves_single_username(self, mock_run):
        mock_run.return_value = make_successful_subprocess_result(
            stdout=json.dumps([{"id": 5, "username": "bob"}])
        )
        ids = glab_helper.resolve_user_ids("bob")
        assert ids == [5]

    @patch("subprocess.run")
    def test_resolves_multiple_comma_separated_usernames(self, mock_run):
        mock_run.side_effect = [
            make_successful_subprocess_result(stdout=json.dumps([{"id": 5}])),
            make_successful_subprocess_result(stdout=json.dumps([{"id": 8}])),
        ]
        ids = glab_helper.resolve_user_ids("bob,carol")
        assert ids == [5, 8]

    @patch("subprocess.run")
    def test_warns_on_unknown_username(self, mock_run, capsys):
        mock_run.return_value = make_successful_subprocess_result(stdout=json.dumps([]))
        ids = glab_helper.resolve_user_ids("nobody")
        assert ids == []
        assert "not found" in capsys.readouterr().err


class TestViewMergeRequest:
    @patch("subprocess.run")
    def test_prints_merge_request_details(self, mock_run, capsys):
        mock_run.return_value = make_successful_subprocess_result(
            stdout=json.dumps(
                {
                    "iid": 86,
                    "title": "Release",
                    "state": "open",
                    "source_branch": "release/uat",
                    "target_branch": "main",
                    "author": {"username": "lucas"},
                    "assignees": [{"username": "lucas"}],
                    "reviewers": [{"username": "brian"}, {"username": "vishwa"}],
                    "has_conflicts": False,
                    "detailed_merge_status": "mergeable",
                    "web_url": "https://example.com/mr/86",
                    "description": "Test description",
                }
            )
        )
        result = glab_helper.view_merge_request(86)
        output = capsys.readouterr().out
        assert "!86" in output
        assert "Release" in output
        assert "lucas" in output
        assert "brian" in output
        assert result["state"] == "open"


class TestViewMergeRequestChanges:
    @patch("subprocess.run")
    def test_lists_changed_files(self, mock_run, capsys):
        mock_run.return_value = make_successful_subprocess_result(
            stdout=json.dumps(
                {
                    "changes": [
                        {"new_path": "src/app.tsx"},
                        {"new_path": "src/layout.css"},
                    ]
                }
            )
        )
        changes = glab_helper.view_merge_request_changes(86)
        output = capsys.readouterr().out
        assert "2 files changed" in output
        assert "src/app.tsx" in output
        assert len(changes) == 2


class TestListPipelines:
    @patch("subprocess.run")
    def test_lists_pipelines_for_ref(self, mock_run, capsys):
        mock_run.return_value = make_successful_subprocess_result(
            stdout=json.dumps(
                [
                    {
                        "id": 1000,
                        "status": "success",
                        "source": "push",
                        "created_at": "2026-03-28T06:08:57Z",
                    },
                ]
            )
        )
        pipelines = glab_helper.list_pipelines(ref="release/uat-27-03-2026")
        output = capsys.readouterr().out
        assert "#1000" in output
        assert "success" in output
        assert len(pipelines) == 1
        called_command = mock_run.call_args[0][0]
        endpoint = called_command[4]
        assert "release" in endpoint


class TestViewPipelineJobs:
    @patch("subprocess.run")
    def test_lists_jobs_for_pipeline(self, mock_run, capsys):
        mock_run.return_value = make_successful_subprocess_result(
            stdout=json.dumps(
                [
                    {
                        "name": "build:uat",
                        "status": "success",
                        "stage": "build",
                        "finished_at": "2026-03-28T07:30:00Z",
                    },
                    {
                        "name": "deploy:uat-ec2",
                        "status": "success",
                        "stage": "deploy",
                        "finished_at": "2026-03-28T07:31:00Z",
                    },
                ]
            )
        )
        jobs = glab_helper.view_pipeline_jobs(1000)
        output = capsys.readouterr().out
        assert "build:uat" in output
        assert "deploy:uat-ec2" in output
        assert len(jobs) == 2


class TestCloseMergeRequest:
    @patch("subprocess.run")
    def test_closes_merge_request(self, mock_run, capsys):
        mock_run.return_value = make_successful_subprocess_result(
            stdout=json.dumps({"iid": 83, "state": "closed"})
        )
        glab_helper.close_merge_request(83)
        output = capsys.readouterr().out
        assert "!83 closed" in output


class TestDeleteBranch:
    @patch("subprocess.run")
    def test_deletes_branch_with_url_encoding(self, mock_run, capsys):
        mock_run.return_value = make_successful_subprocess_result(stdout="{}")
        glab_helper.delete_branch("release/uat-27-03-2026")
        called_command = mock_run.call_args[0][0]
        endpoint = called_command[4]
        assert "release%2Fuat-27-03-2026" in endpoint
        output = capsys.readouterr().out
        assert "deleted" in output
