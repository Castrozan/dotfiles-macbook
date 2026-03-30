---
name: glab
description: Manage GitLab merge requests, issues, pipelines, and code review via glab CLI. Use when user asks to create MRs, list issues, check CI status, review code, or interact with GitLab.
---

<announcement>
"I'm using the glab skill to interact with GitLab."
</announcement>

<auth>
Token is managed by agenix and exported as GITLAB_TOKEN. The GitLab instance is git.coates.io, not gitlab.com. If auth fails, source secrets from the agenix-managed file in ~/.secrets/. The helper script auto-sources when GITLAB_TOKEN is missing.
</auth>

<helper_script>
The scripts/ directory contains a Python helper that wraps glab CLI and API. Prefer it over raw glab commands; it handles auth sourcing, uses the REST API directly (avoiding glab CLI quirks with non-interactive MR creation), resolves usernames to IDs, and URL-encodes branch names for protected branch operations. Run with `--help` to see available subcommands.
</helper_script>

<glab_cli_mr_creation_trap>
`glab mr create --title` silently fails in non-interactive mode even when --no-editor is passed. The helper script bypasses this by calling the REST API directly. Use glab CLI only with `--fill` (auto-populates from commits) or for operations other than MR creation.
</glab_cli_mr_creation_trap>

<protected_branch_deletion_trap>
`git push --delete` fails on protected branches with a pre-receive hook rejection. The helper's delete-branch command uses the REST API which bypasses branch protection rules. This is the only reliable way to delete release/* branches.
</protected_branch_deletion_trap>

<merge_request_updates>
`glab mr update` works well for --assignee, --reviewer (prefix with + to add, ! to remove). For description updates with markdown or special characters, prefer the helper's mr-update command which avoids shell escaping issues by passing fields directly to the API.
</merge_request_updates>

<worktree_trap>
glab misdetects repo context inside git worktrees. Run MR commands from the main repo directory. Use `--head <branch>` to target worktree branches from the main repo.
</worktree_trap>
