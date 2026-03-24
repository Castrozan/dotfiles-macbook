---
name: jira
description: Manage Jira issues, sprints, epics, and boards via jira-cli. Use when user asks to create issues, check sprint status, move tickets, log work, or interact with Jira.
---

<announcement>
"I'm using the jira skill to interact with Jira."
</announcement>

<auth>
Token is managed by agenix and exported as JIRA_API_TOKEN. Run `jira init` for first-time setup — requires `--server` (Jira instance URL), `--login` (email), `--project` (default project key), `--board` (default board). Config lives at `~/.config/.jira/.config.yml`. Auth type is `bearer` for cloud API tokens. If commands fail with auth errors, verify the token is sourced (rebuild activates agenix secrets).
</auth>

<issues>
Creating: `jira issue create -tTask -s"Summary" -b"Description"`. Required flags are `-t` (type: Task, Bug, Story, Epic) and `-s` (summary). Optional: `-a` (assignee), `-l` (label), `-C` (component), `-P` (parent for subtasks), `-y` (priority), `--custom story-points=3` for custom fields. Use `--template /path/to/file.tmpl` for body from file, or pipe stdin: `echo "body" | jira issue create -s"Title" -tTask`.

Listing: `jira issue list` with filters `--type`, `--status`, `--assignee`, `--label`, `--priority`. Negate with tilde: `-s~Done` means "not Done", `-ax` means unassigned. Date filters: `--created today`, `--updated -10d`. Raw JQL with `-q "project = FOO AND status = Open"`. Output: `--plain` for tables, `--raw` for JSON, `--columns KEY,STATUS,SUMMARY` to select fields.

Moving: `jira issue move ISSUE-1 "In Progress"` transitions issues through workflow states. Add `--comment` and `--assignee` in the same call.

Editing: `jira issue edit ISSUE-1 -s"New summary"` — same flags as create. Remove labels/components with minus prefix: `--label -urgent`. Use `--skip-notify` to avoid notification spam on batch updates.
</issues>

<sprints>
`jira sprint list` shows sprints for the configured board. Use `--current` for the active sprint, `--next`/`--prev` for adjacent ones. With a sprint ID, it lists issues in that sprint. `jira sprint add SPRINT_ID ISSUE-1 ISSUE-2` assigns issues (max 50 per call).
</sprints>

<epics>
`jira epic list` without args shows all epics; with an epic key shows child issues. `jira epic create -n"Epic Name" -s"Summary"` creates epics. `jira epic add EPIC-KEY ISSUE-1` assigns issues to an epic (max 50).
</epics>

<scripting>
For non-interactive automation always use `--no-input` to skip prompts. `--plain` gives parseable tables, `--raw` gives JSON, `--csv` gives CSV. `jira me` returns the configured username — useful in subshells: `jira issue list --assignee $(jira me)`. `jira open ISSUE-1` opens in browser, `--no-browser` prints the URL instead.
</scripting>

<worklog>
`jira issue worklog add ISSUE-1 "2d 1h 30m"` logs time. Supports `--started "2024-01-15 09:00"`, `--timezone "America/Sao_Paulo"`, `--comment`, `--new-estimate` for remaining time adjustment.
</worklog>
