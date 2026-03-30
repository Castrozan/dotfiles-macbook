---
name: glab
description: Manage GitLab merge requests, issues, pipelines, and code review via glab CLI. Use when user asks to create MRs, list issues, check CI status, review code, or interact with GitLab.
---

<announcement>
"I'm using the glab skill to interact with GitLab."
</announcement>

<auth>
Token is managed by agenix and exported as GITLAB_TOKEN. The GitLab instance is git.coates.io; glab must be configured to target this host, not gitlab.com. Run `glab auth status` to verify authentication before operations. If auth fails, check that source-secrets.sh has been sourced (rebuild activates it).
</auth>

<merge_requests>
Creating MRs: `glab mr create` with `--fill` auto-populates title and description from commits and pushes the branch. Use `--draft` for work-in-progress. `--assignee`, `--reviewer`, `--label` accept usernames/values directly. `--related-issue` links an issue and uses its title if no `--title` given. `--copy-issue-labels` pulls labels from the linked issue. Always push the branch first or use `--fill` which auto-pushes.

Reviewing: `glab mr diff` shows changes, `glab mr approve` approves, `glab mr note -m "comment"` adds comments (use `--unique` to avoid duplicate CI bot comments). `glab mr checkout` fetches locally for testing.

Merging: `glab mr merge` with `--squash` for squash merge, `--remove-source-branch` to clean up. Auto-merge is on by default.

Updating: `glab mr update` supports prefix modifiers on `--assignee` and `--reviewer`: `+user` adds, `!user` or `-user` removes, bare `user` replaces. Toggle draft with `--draft`/`--ready`.
</merge_requests>

<issues>
`glab issue create` with `--title`, `--description`, `--assignee`, `--label`, `--milestone`. Use `--confidential` for security issues. `glab issue list` filters by `--assignee`, `--label`, `--milestone`, `--search`. Output as JSON with `--output json` for scripting.
</issues>

<ci_cd>
`glab ci status` shows current pipeline state (use `--live` for real-time updates). `glab ci view` opens an interactive TUI with vi keybindings. `glab ci trace` streams job logs. `glab ci run` triggers a new pipeline; pass variables with `--variables key:value`. `glab ci lint` validates .gitlab-ci.yml before pushing. `glab ci retry` retries failed jobs by ID or name.
</ci_cd>

<api_access>
`glab api` makes authenticated REST calls with placeholder substitution (`:fullpath`, `:id`). Supports GraphQL: `glab api graphql -f query="..."`. Use `--paginate` for large result sets. This is the escape hatch for anything not covered by dedicated subcommands.
</api_access>

<worktree_trap>
PR commands must run from the main repo directory, not a git worktree, because glab misdetects the repo context inside worktrees. Use `--head <branch>` to target the worktree branch from the main repo.
</worktree_trap>

<aliases>
`glab alias set` creates shortcuts with positional args (`$1`, `$2`). Use `--shell` for piping: `glab alias set --shell igrep 'glab issue list --assignee="$1" | grep $2'`. Check existing aliases with `glab alias list` before creating new ones.
</aliases>
