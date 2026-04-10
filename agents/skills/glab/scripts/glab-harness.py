#!/usr/bin/env python3
import argparse
import json
import os
import subprocess
import sys
import urllib.parse
import urllib.request


GITLAB_HOST = "git.coates.io"
GITLAB_API_BASE = f"https://{GITLAB_HOST}/api/v4"


def resolve_gitlab_token():
    token = os.environ.get("GITLAB_TOKEN")
    if token:
        return token

    secrets_path = os.path.expanduser("~/.secrets/source-secrets.sh")
    if os.path.exists(secrets_path):
        result = subprocess.run(
            f"source {secrets_path} && echo $GITLAB_TOKEN",
            capture_output=True,
            text=True,
            shell=True,
        )
        if result.returncode == 0 and result.stdout.strip():
            token = result.stdout.strip()
            os.environ["GITLAB_TOKEN"] = token
            return token

    print(
        "Error: GITLAB_TOKEN not set. Source ~/.secrets/source-secrets.sh",
        file=sys.stderr,
    )
    sys.exit(1)


def resolve_project_path_from_git_remote():
    result = subprocess.run(
        ["git", "remote", "get-url", "origin"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print("Error: not a git repository or no origin remote", file=sys.stderr)
        sys.exit(1)

    remote_url = result.stdout.strip()

    if remote_url.startswith("git@"):
        path = remote_url.split(":", 1)[1]
    elif remote_url.startswith("https://") or remote_url.startswith("http://"):
        path = "/".join(remote_url.split("/")[3:])
    else:
        print(f"Error: unrecognized remote URL format: {remote_url}", file=sys.stderr)
        sys.exit(1)

    if path.endswith(".git"):
        path = path[:-4]

    return path


def gitlab_api_request(method, endpoint, token, body=None):
    url = f"{GITLAB_API_BASE}/{endpoint}"
    headers = {"PRIVATE-TOKEN": token}

    data = None
    if body is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(body).encode("utf-8")

    request = urllib.request.Request(url, data=data, headers=headers, method=method)

    try:
        with urllib.request.urlopen(request) as response:
            response_body = response.read().decode("utf-8")
            if response_body.strip():
                return json.loads(response_body)
            return {}
    except urllib.error.HTTPError as http_error:
        error_body = http_error.read().decode("utf-8")
        print(f"API error ({http_error.code}): {error_body}", file=sys.stderr)
        sys.exit(1)


def encoded_project_path(project_path):
    return urllib.parse.quote(project_path, safe="")


def resolve_username_to_id(username, token):
    encoded_username = urllib.parse.quote(username.strip())
    users = gitlab_api_request("GET", f"users?username={encoded_username}", token)
    if users:
        return users[0]["id"]
    print(f"Warning: user '{username}' not found", file=sys.stderr)
    return None


def resolve_comma_separated_usernames_to_ids(usernames_string, token):
    user_ids = []
    for username in usernames_string.split(","):
        user_id = resolve_username_to_id(username, token)
        if user_id:
            user_ids.append(user_id)
    return user_ids


def command_merge_request_view(args, token, project):
    project_encoded = encoded_project_path(project)
    merge_request = gitlab_api_request(
        "GET", f"projects/{project_encoded}/merge_requests/{args.iid}", token
    )

    print(f"!{merge_request['iid']} | {merge_request['title']}")
    print(f"State: {merge_request['state']}")
    print(
        f"Source: {merge_request['source_branch']} -> {merge_request['target_branch']}"
    )
    print(f"Author: {merge_request['author']['username']}")

    assignee_names = ", ".join(
        a["username"] for a in merge_request.get("assignees", [])
    )
    reviewer_names = ", ".join(
        r["username"] for r in merge_request.get("reviewers", [])
    )
    merge_status = merge_request.get(
        "detailed_merge_status", merge_request.get("merge_status")
    )

    print(f"Assignees: {assignee_names}")
    print(f"Reviewers: {reviewer_names}")
    print(f"Has conflicts: {merge_request.get('has_conflicts')}")
    print(f"Merge status: {merge_status}")
    print(f"URL: {merge_request['web_url']}")

    if merge_request.get("description"):
        print(f"\n{merge_request['description']}")


def command_merge_request_create(args, token, project):
    project_encoded = encoded_project_path(project)

    body = {
        "source_branch": args.source,
        "target_branch": args.target,
        "title": args.title,
    }

    if args.description_file:
        with open(args.description_file) as description_file:
            body["description"] = description_file.read()

    if args.remove_source_branch:
        body["remove_source_branch"] = True

    if args.assignee:
        body["assignee_ids"] = resolve_comma_separated_usernames_to_ids(
            args.assignee, token
        )

    if args.reviewer:
        body["reviewer_ids"] = resolve_comma_separated_usernames_to_ids(
            args.reviewer, token
        )

    merge_request = gitlab_api_request(
        "POST", f"projects/{project_encoded}/merge_requests", token, body=body
    )
    print(f"!{merge_request['iid']} | {merge_request['title']}")
    print(merge_request["web_url"])


def command_merge_request_update(args, token, project):
    project_encoded = encoded_project_path(project)

    body = {}
    if args.title:
        body["title"] = args.title
    if args.description_file:
        with open(args.description_file) as description_file:
            body["description"] = description_file.read()
    if args.assignee:
        body["assignee_ids"] = resolve_comma_separated_usernames_to_ids(
            args.assignee, token
        )
    if args.reviewer:
        body["reviewer_ids"] = resolve_comma_separated_usernames_to_ids(
            args.reviewer, token
        )

    if not body:
        print("Error: no update fields provided", file=sys.stderr)
        sys.exit(1)

    merge_request = gitlab_api_request(
        "PUT", f"projects/{project_encoded}/merge_requests/{args.iid}", token, body=body
    )
    print(f"!{merge_request['iid']} | {merge_request['title']}")
    print(merge_request["web_url"])


def command_merge_request_changes(args, token, project):
    project_encoded = encoded_project_path(project)
    data = gitlab_api_request(
        "GET", f"projects/{project_encoded}/merge_requests/{args.iid}/changes", token
    )
    changes = data.get("changes", [])
    print(f"{len(changes)} files changed:")
    for change in changes:
        print(f"  {change['new_path']}")


def command_merge_request_discussions(args, token, project):
    project_encoded = encoded_project_path(project)
    discussions = gitlab_api_request(
        "GET",
        f"projects/{project_encoded}/merge_requests/{args.iid}/discussions?per_page=100",
        token,
    )

    found_comments = False
    for discussion in discussions:
        for note in discussion.get("notes", []):
            if note.get("system"):
                continue

            found_comments = True
            author = note["author"]["name"]
            username = note["author"]["username"]
            position = note.get("position")

            if position:
                file_path = position.get("new_path", "?")
                line_number = position.get("new_line", "?")
                print(f"--- {author} ({username}) on {file_path}:{line_number} ---")
            else:
                print(f"--- {author} ({username}) ---")

            print(note["body"])
            print()

    if not found_comments:
        print("No comments on this merge request.")


def command_merge_request_close(args, token, project):
    project_encoded = encoded_project_path(project)
    merge_request = gitlab_api_request(
        "PUT",
        f"projects/{project_encoded}/merge_requests/{args.iid}",
        token,
        body={"state_event": "close"},
    )
    print(f"!{merge_request['iid']} closed")


def command_merge_request_merge(args, token, project):
    project_encoded = encoded_project_path(project)
    body = {}
    if args.squash:
        body["squash"] = True
    merge_request = gitlab_api_request(
        "PUT",
        f"projects/{project_encoded}/merge_requests/{args.iid}/merge",
        token,
        body=body,
    )
    print(f"!{merge_request['iid']} merged")


def command_pipelines(args, token, project):
    project_encoded = encoded_project_path(project)
    endpoint = f"projects/{project_encoded}/pipelines?per_page={args.count}"
    if args.ref:
        endpoint += f"&ref={urllib.parse.quote(args.ref)}"
    pipelines = gitlab_api_request("GET", endpoint, token)
    for pipeline in pipelines:
        print(
            f"#{pipeline['id']} | {pipeline['status']:10s} | {pipeline['source']:20s} | {pipeline['created_at']}"
        )


def command_pipeline_jobs(args, token, project):
    project_encoded = encoded_project_path(project)
    jobs = gitlab_api_request(
        "GET",
        f"projects/{project_encoded}/pipelines/{args.pipeline_id}/jobs?per_page=50",
        token,
    )
    for job in jobs:
        finished = job.get("finished_at", "")
        print(f"  {job['name']:30s} {job['status']:12s} {job['stage']:15s} {finished}")


def command_delete_branch(args, token, project):
    project_encoded = encoded_project_path(project)
    encoded_branch = urllib.parse.quote(args.branch_name, safe="")
    gitlab_api_request(
        "DELETE",
        f"projects/{project_encoded}/repository/branches/{encoded_branch}",
        token,
    )
    print(f"Branch '{args.branch_name}' deleted")


def main():
    parser = argparse.ArgumentParser(description="GitLab harness for agent operations")
    subparsers = parser.add_subparsers(dest="command", required=True)

    merge_request_view_parser = subparsers.add_parser("mr-view")
    merge_request_view_parser.add_argument("iid", type=int)

    merge_request_create_parser = subparsers.add_parser("mr-create")
    merge_request_create_parser.add_argument("--source", required=True)
    merge_request_create_parser.add_argument("--target", required=True)
    merge_request_create_parser.add_argument("--title", required=True)
    merge_request_create_parser.add_argument("--description-file")
    merge_request_create_parser.add_argument("--assignee")
    merge_request_create_parser.add_argument("--reviewer")
    merge_request_create_parser.add_argument(
        "--remove-source-branch", action="store_true"
    )

    merge_request_update_parser = subparsers.add_parser("mr-update")
    merge_request_update_parser.add_argument("iid", type=int)
    merge_request_update_parser.add_argument("--title")
    merge_request_update_parser.add_argument("--description-file")
    merge_request_update_parser.add_argument("--assignee")
    merge_request_update_parser.add_argument("--reviewer")

    merge_request_changes_parser = subparsers.add_parser("mr-changes")
    merge_request_changes_parser.add_argument("iid", type=int)

    merge_request_discussions_parser = subparsers.add_parser("mr-discussions")
    merge_request_discussions_parser.add_argument("iid", type=int)

    merge_request_close_parser = subparsers.add_parser("mr-close")
    merge_request_close_parser.add_argument("iid", type=int)

    merge_request_merge_parser = subparsers.add_parser("mr-merge")
    merge_request_merge_parser.add_argument("iid", type=int)
    merge_request_merge_parser.add_argument("--squash", action="store_true")

    pipelines_parser = subparsers.add_parser("pipelines")
    pipelines_parser.add_argument("--ref")
    pipelines_parser.add_argument("--count", type=int, default=5)

    pipeline_jobs_parser = subparsers.add_parser("pipeline-jobs")
    pipeline_jobs_parser.add_argument("pipeline_id", type=int)

    delete_branch_parser = subparsers.add_parser("delete-branch")
    delete_branch_parser.add_argument("branch_name")

    args = parser.parse_args()
    token = resolve_gitlab_token()
    project = resolve_project_path_from_git_remote()

    commands = {
        "mr-view": command_merge_request_view,
        "mr-create": command_merge_request_create,
        "mr-update": command_merge_request_update,
        "mr-changes": command_merge_request_changes,
        "mr-discussions": command_merge_request_discussions,
        "mr-close": command_merge_request_close,
        "mr-merge": command_merge_request_merge,
        "pipelines": command_pipelines,
        "pipeline-jobs": command_pipeline_jobs,
        "delete-branch": command_delete_branch,
    }

    commands[args.command](args, token, project)


if __name__ == "__main__":
    main()
