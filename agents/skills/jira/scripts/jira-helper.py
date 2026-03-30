#!/usr/bin/env python3
import argparse
import subprocess
import sys


def run_jira_command(arguments, expect_output=True):
    command = ["jira"] + arguments
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error: {result.stderr}", file=sys.stderr)
        if expect_output:
            sys.exit(1)
    return result


def view_issue(issue_key):
    result = run_jira_command(["issue", "view", issue_key])
    print(result.stdout)
    return result


def list_issues(
    project=None,
    status=None,
    issue_type=None,
    assignee=None,
    label=None,
    jql_query=None,
    columns=None,
):
    arguments = ["issue", "list", "--plain", "--no-input"]
    if project:
        arguments.extend(["--project", project])
    if status:
        arguments.extend(["-s", status])
    if issue_type:
        arguments.extend(["--type", issue_type])
    if assignee:
        arguments.extend(["-a", assignee])
    if label:
        arguments.extend(["--label", label])
    if jql_query:
        arguments.extend(["-q", jql_query])
    if columns:
        arguments.extend(["--columns", columns])
    result = run_jira_command(arguments)
    print(result.stdout)
    return result


def create_issue(
    summary,
    issue_type="Task",
    description=None,
    assignee=None,
    priority=None,
    labels=None,
    parent=None,
):
    arguments = ["issue", "create", "--no-input", "-t", issue_type, "-s", summary]
    if description:
        arguments.extend(["-b", description])
    if assignee:
        arguments.extend(["-a", assignee])
    if priority:
        arguments.extend(["-y", priority])
    if labels:
        arguments.extend(["-l", labels])
    if parent:
        arguments.extend(["-P", parent])
    result = run_jira_command(arguments)
    print(result.stdout)
    return result


def move_issue(issue_key, target_status, comment=None, assignee=None):
    arguments = ["issue", "move", issue_key, target_status, "--no-input"]
    if comment:
        arguments.extend(["--comment", comment])
    if assignee:
        arguments.extend(["-a", assignee])
    result = run_jira_command(arguments)
    print(result.stdout)
    return result


def edit_issue(
    issue_key, summary=None, description=None, assignee=None, labels=None, priority=None
):
    arguments = ["issue", "edit", issue_key, "--no-input"]
    if summary:
        arguments.extend(["-s", summary])
    if description:
        arguments.extend(["-b", description])
    if assignee:
        arguments.extend(["-a", assignee])
    if labels:
        arguments.extend(["-l", labels])
    if priority:
        arguments.extend(["-y", priority])
    result = run_jira_command(arguments)
    print(result.stdout)
    return result


def add_comment(issue_key, comment_body):
    result = run_jira_command(
        ["issue", "comment", "add", issue_key, "-b", comment_body, "--no-input"]
    )
    print(result.stdout)
    return result


def list_sprints(current_only=False):
    arguments = ["sprint", "list", "--plain", "--no-input"]
    if current_only:
        arguments.append("--current")
    result = run_jira_command(arguments)
    print(result.stdout)
    return result


def log_work(issue_key, time_spent, comment=None):
    arguments = ["issue", "worklog", "add", issue_key, time_spent, "--no-input"]
    if comment:
        arguments.extend(["--comment", comment])
    result = run_jira_command(arguments)
    print(result.stdout)
    return result


def open_in_browser(issue_key):
    result = run_jira_command(["open", issue_key, "--no-browser"])
    print(result.stdout)
    return result


def my_issues(status=None):
    status_flag = f" -s {status}" if status else ""
    jira_command = f"jira issue list --plain --no-input -a $(jira me){status_flag}"
    result = subprocess.run(
        jira_command,
        capture_output=True,
        text=True,
        shell=True,
    )
    if result.returncode != 0:
        print(f"Error: {result.stderr}", file=sys.stderr)
        sys.exit(1)
    print(result.stdout)
    return result


def main():
    parser = argparse.ArgumentParser(description="Jira helper for common operations")
    subparsers = parser.add_subparsers(dest="command", required=True)

    view_parser = subparsers.add_parser("view")
    view_parser.add_argument("issue_key")

    list_parser = subparsers.add_parser("list")
    list_parser.add_argument("--project")
    list_parser.add_argument("--status")
    list_parser.add_argument("--type")
    list_parser.add_argument("--assignee")
    list_parser.add_argument("--label")
    list_parser.add_argument("--jql")
    list_parser.add_argument("--columns")

    create_parser = subparsers.add_parser("create")
    create_parser.add_argument("--summary", required=True)
    create_parser.add_argument("--type", default="Task")
    create_parser.add_argument("--description")
    create_parser.add_argument("--assignee")
    create_parser.add_argument("--priority")
    create_parser.add_argument("--labels")
    create_parser.add_argument("--parent")

    move_parser = subparsers.add_parser("move")
    move_parser.add_argument("issue_key")
    move_parser.add_argument("target_status")
    move_parser.add_argument("--comment")
    move_parser.add_argument("--assignee")

    edit_parser = subparsers.add_parser("edit")
    edit_parser.add_argument("issue_key")
    edit_parser.add_argument("--summary")
    edit_parser.add_argument("--description")
    edit_parser.add_argument("--assignee")
    edit_parser.add_argument("--labels")
    edit_parser.add_argument("--priority")

    comment_parser = subparsers.add_parser("comment")
    comment_parser.add_argument("issue_key")
    comment_parser.add_argument("body")

    subparsers.add_parser("sprints")
    subparsers.add_parser("current-sprint")

    worklog_parser = subparsers.add_parser("log-work")
    worklog_parser.add_argument("issue_key")
    worklog_parser.add_argument("time_spent")
    worklog_parser.add_argument("--comment")

    open_parser = subparsers.add_parser("open")
    open_parser.add_argument("issue_key")

    my_issues_parser = subparsers.add_parser("my-issues")
    my_issues_parser.add_argument("--status")

    args = parser.parse_args()

    if args.command == "view":
        view_issue(args.issue_key)
    elif args.command == "list":
        list_issues(
            project=args.project,
            status=args.status,
            issue_type=args.type,
            assignee=args.assignee,
            label=args.label,
            jql_query=args.jql,
            columns=args.columns,
        )
    elif args.command == "create":
        create_issue(
            summary=args.summary,
            issue_type=args.type,
            description=args.description,
            assignee=args.assignee,
            priority=args.priority,
            labels=args.labels,
            parent=args.parent,
        )
    elif args.command == "move":
        move_issue(
            args.issue_key,
            args.target_status,
            comment=args.comment,
            assignee=args.assignee,
        )
    elif args.command == "edit":
        edit_issue(
            args.issue_key,
            summary=args.summary,
            description=args.description,
            assignee=args.assignee,
            labels=args.labels,
            priority=args.priority,
        )
    elif args.command == "comment":
        add_comment(args.issue_key, args.body)
    elif args.command == "sprints":
        list_sprints()
    elif args.command == "current-sprint":
        list_sprints(current_only=True)
    elif args.command == "log-work":
        log_work(args.issue_key, args.time_spent, comment=args.comment)
    elif args.command == "open":
        open_in_browser(args.issue_key)
    elif args.command == "my-issues":
        my_issues(status=args.status)


if __name__ == "__main__":
    main()
