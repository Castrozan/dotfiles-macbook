#!/usr/bin/env python3
import argparse
import json
import os
import subprocess
import sys
import urllib.parse


def run_command(command, capture_output=True):
    result = subprocess.run(
        command,
        capture_output=capture_output,
        text=True,
        shell=isinstance(command, str),
    )
    return result


def ensure_authentication():
    secrets_path = os.path.expanduser("~/.secrets/source-secrets.sh")
    if not os.environ.get("GITLAB_TOKEN") and os.path.exists(secrets_path):
        result = run_command(f"source {secrets_path} && echo $GITLAB_TOKEN")
        if result.returncode == 0 and result.stdout.strip():
            os.environ["GITLAB_TOKEN"] = result.stdout.strip()

    if not os.environ.get("GITLAB_TOKEN"):
        print(
            "Error: GITLAB_TOKEN not set. Source ~/.secrets/source-secrets.sh",
            file=sys.stderr,
        )
        sys.exit(1)


def glab_api(endpoint, method="GET", fields=None):
    command = ["glab", "api", "--method", method, endpoint]
    for key, value in (fields or {}).items():
        command.extend(["-f", f"{key}={value}"])
    result = run_command(command)
    if result.returncode != 0:
        print(f"API error: {result.stderr}", file=sys.stderr)
        sys.exit(1)
    return json.loads(result.stdout) if result.stdout.strip() else {}


def get_current_user_id():
    user = glab_api("user")
    return user["id"]


def create_merge_request(
    source_branch,
    target_branch,
    title,
    description=None,
    assignee_usernames=None,
    reviewer_usernames=None,
    remove_source_branch=False,
):
    fields = {
        "source_branch": source_branch,
        "target_branch": target_branch,
        "title": title,
    }

    if description:
        fields["description"] = description

    if remove_source_branch:
        fields["remove_source_branch"] = "true"

    if assignee_usernames:
        user_ids = resolve_user_ids(assignee_usernames)
        for index, user_id in enumerate(user_ids):
            fields[f"assignee_ids[{index}]"] = str(user_id)

    if reviewer_usernames:
        user_ids = resolve_user_ids(reviewer_usernames)
        for index, user_id in enumerate(user_ids):
            fields[f"reviewer_ids[{index}]"] = str(user_id)

    merge_request = glab_api(
        "projects/:fullpath/merge_requests", method="POST", fields=fields
    )
    print(f"!{merge_request['iid']} | {merge_request['title']}")
    print(merge_request["web_url"])
    return merge_request


def resolve_user_ids(usernames):
    user_ids = []
    for username in usernames.split(","):
        username = username.strip()
        users = glab_api(f"users?username={urllib.parse.quote(username)}")
        if users:
            user_ids.append(users[0]["id"])
        else:
            print(f"Warning: user '{username}' not found", file=sys.stderr)
    return user_ids


def update_merge_request(merge_request_iid, fields):
    merge_request = glab_api(
        f"projects/:fullpath/merge_requests/{merge_request_iid}",
        method="PUT",
        fields=fields,
    )
    print(f"!{merge_request['iid']} | {merge_request['title']}")
    print(merge_request["web_url"])
    return merge_request


def view_merge_request(merge_request_iid):
    merge_request = glab_api(f"projects/:fullpath/merge_requests/{merge_request_iid}")
    print(f"!{merge_request['iid']} | {merge_request['title']}")
    print(f"State: {merge_request['state']}")
    print(
        f"Source: {merge_request['source_branch']} → {merge_request['target_branch']}"
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
    return merge_request


def view_merge_request_changes(merge_request_iid):
    data = glab_api(f"projects/:fullpath/merge_requests/{merge_request_iid}/changes")
    changes = data.get("changes", [])
    print(f"{len(changes)} files changed:")
    for change in changes:
        print(f"  {change['new_path']}")
    return changes


def list_pipelines(ref=None, count=5):
    endpoint = f"projects/:fullpath/pipelines?per_page={count}"
    if ref:
        endpoint += f"&ref={urllib.parse.quote(ref)}"
    pipelines = glab_api(endpoint)
    for pipeline in pipelines:
        print(
            f"#{pipeline['id']} | {pipeline['status']:10s} | "
            f"{pipeline['source']:20s} | {pipeline['created_at']}"
        )
    return pipelines


def view_pipeline_jobs(pipeline_id):
    jobs = glab_api(f"projects/:fullpath/pipelines/{pipeline_id}/jobs?per_page=50")
    for job in jobs:
        finished = job.get("finished_at", "")
        print(f"  {job['name']:30s} {job['status']:12s} {job['stage']:15s} {finished}")
    return jobs


def close_merge_request(merge_request_iid):
    merge_request = glab_api(
        f"projects/:fullpath/merge_requests/{merge_request_iid}",
        method="PUT",
        fields={"state_event": "close"},
    )
    print(f"!{merge_request['iid']} closed")
    return merge_request


def delete_branch(branch_name):
    encoded_branch = urllib.parse.quote(branch_name, safe="")
    glab_api(
        f"projects/:fullpath/repository/branches/{encoded_branch}", method="DELETE"
    )
    print(f"Branch '{branch_name}' deleted")


def main():
    parser = argparse.ArgumentParser(description="GitLab helper for common operations")
    subparsers = parser.add_subparsers(dest="command", required=True)

    merge_request_create_parser = subparsers.add_parser("mr-create")
    merge_request_create_parser.add_argument("--source", required=True)
    merge_request_create_parser.add_argument("--target", required=True)
    merge_request_create_parser.add_argument("--title", required=True)
    merge_request_create_parser.add_argument("--description")
    merge_request_create_parser.add_argument("--assignee")
    merge_request_create_parser.add_argument("--reviewer")
    merge_request_create_parser.add_argument(
        "--remove-source-branch", action="store_true"
    )

    merge_request_update_parser = subparsers.add_parser("mr-update")
    merge_request_update_parser.add_argument("iid", type=int)
    merge_request_update_parser.add_argument("--title")
    merge_request_update_parser.add_argument("--description")
    merge_request_update_parser.add_argument("--assignee")
    merge_request_update_parser.add_argument("--reviewer")

    merge_request_view_parser = subparsers.add_parser("mr-view")
    merge_request_view_parser.add_argument("iid", type=int)

    merge_request_changes_parser = subparsers.add_parser("mr-changes")
    merge_request_changes_parser.add_argument("iid", type=int)

    merge_request_close_parser = subparsers.add_parser("mr-close")
    merge_request_close_parser.add_argument("iid", type=int)

    pipelines_parser = subparsers.add_parser("pipelines")
    pipelines_parser.add_argument("--ref")
    pipelines_parser.add_argument("--count", type=int, default=5)

    pipeline_jobs_parser = subparsers.add_parser("pipeline-jobs")
    pipeline_jobs_parser.add_argument("pipeline_id", type=int)

    delete_branch_parser = subparsers.add_parser("delete-branch")
    delete_branch_parser.add_argument("branch_name")

    args = parser.parse_args()
    ensure_authentication()

    if args.command == "mr-create":
        create_merge_request(
            source_branch=args.source,
            target_branch=args.target,
            title=args.title,
            description=args.description,
            assignee_usernames=args.assignee,
            reviewer_usernames=args.reviewer,
            remove_source_branch=args.remove_source_branch,
        )
    elif args.command == "mr-update":
        fields = {}
        if args.title:
            fields["title"] = args.title
        if args.description:
            fields["description"] = args.description
        if args.assignee:
            user_ids = resolve_user_ids(args.assignee)
            for index, user_id in enumerate(user_ids):
                fields[f"assignee_ids[{index}]"] = str(user_id)
        if args.reviewer:
            user_ids = resolve_user_ids(args.reviewer)
            for index, user_id in enumerate(user_ids):
                fields[f"reviewer_ids[{index}]"] = str(user_id)
        update_merge_request(args.iid, fields)
    elif args.command == "mr-view":
        view_merge_request(args.iid)
    elif args.command == "mr-changes":
        view_merge_request_changes(args.iid)
    elif args.command == "mr-close":
        close_merge_request(args.iid)
    elif args.command == "pipelines":
        list_pipelines(ref=args.ref, count=args.count)
    elif args.command == "pipeline-jobs":
        view_pipeline_jobs(args.pipeline_id)
    elif args.command == "delete-branch":
        delete_branch(args.branch_name)


if __name__ == "__main__":
    main()
