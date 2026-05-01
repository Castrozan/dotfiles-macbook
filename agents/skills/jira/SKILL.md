---
name: jira
description: Manage Jira issues, sprints, epics, and boards via jira-cli. Use when user asks to create issues, check sprint status, move tickets, log work, or interact with Jira.
---

<announcement>
"I'm using the jira skill to interact with Jira."
</announcement>

<auth>
Token is managed by agenix at ~/.secrets/jira-api-token and exposed as JIRA_API_TOKEN in interactive fish shells. Config lives at ~/.config/.jira/.config.yml, deployed by home-manager. Auth type is `basic` for cloud (email + API token). The helper script auto-loads the token from the secret file, so callers do not need to source secrets first; raw jira-cli does require JIRA_API_TOKEN in the environment.
</auth>

<helper_script>
The scripts/ directory contains a Python helper that wraps jira-cli with consistent flags (always passes --no-input and --plain) and self-loads JIRA_API_TOKEN from ~/.secrets/jira-api-token when not already in the environment. Run with `--help` to see available subcommands. Prefer the helper for automation; use jira-cli directly for interactive workflows or JQL queries not covered by the helper.
</helper_script>

<non_interactive_trap>
jira-cli prompts interactively by default and hangs in non-interactive contexts. Always pass `--no-input` when running from scripts or agents. The helper does this automatically.
</non_interactive_trap>

<filter_negation>
Negate filters with tilde prefix: `-s~Done` means "not Done", `-ax` means unassigned. This is non-obvious and not in --help.
</filter_negation>

<batch_update_spam>
Use `--skip-notify` when editing multiple issues to avoid flooding team inboxes. Without it, each edit sends a Jira notification.
</batch_update_spam>

<worklog_timezone>
Worklog entries default to server timezone. Always pass `--timezone` when logging time for users in different timezones, or the hours land on the wrong day.
</worklog_timezone>
