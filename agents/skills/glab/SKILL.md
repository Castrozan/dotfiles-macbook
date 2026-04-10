---
name: glab
description: Manage GitLab merge requests, issues, pipelines, and code review via glab CLI. Use when user asks to create MRs, list issues, check CI status, review code, or interact with GitLab.
---

<announcement>
"I'm using the glab skill to interact with GitLab."
</announcement>

<helper>
All GitLab operations go through the helper script in this skill's `scripts/` directory. Run it with `--help` and `<subcommand> --help` to see available commands and flags. It handles auth sourcing, REST API calls, username-to-ID resolution, and URL-encoding. Never use raw `glab` CLI commands directly; they fail silently in multiple scenarios documented below.
</helper>

<auth>
Token is managed by agenix and exported as GITLAB_TOKEN. The GitLab instance is git.coates.io, not gitlab.com. The helper auto-sources from `~/.secrets/source-secrets.sh` when GITLAB_TOKEN is missing. For direct API calls outside the helper, source that file first.
</auth>

<traps>
Do not use `glab mr create --title`; it silently fails in non-interactive mode. The helper's mr-create uses the REST API and works reliably.

Do not use `git push --delete` on protected branches; the pre-receive hook rejects it silently. The helper's delete-branch command uses the REST API which bypasses branch protection.

Do not run glab or the helper from inside a git worktree; glab misdetects repo context. Run from the main repo directory, use `--head <branch>` to target worktree branches.
</traps>

<helper_gaps>
The helper does not cover MR description updates with markdown (shell escaping corrupts them) or reading MR comments/discussions. For these, use the GitLab REST API directly with curl.

The URL-encoded project path is `digital-production%2Fmcdca-tools%2Fmcdca-workspace`. Base URL: `https://git.coates.io/api/v4/projects/digital-production%2Fmcdca-tools%2Fmcdca-workspace`.

For description updates: write markdown to a temp file, use `jq -n --arg desc "$(cat /tmp/desc.md)" '{description: $desc}'` to safely encode it, then PUT to `/merge_requests/:iid`.

For MR comments: GET `/merge_requests/:iid/discussions?per_page=50`. Use `/discussions` not `/notes`; only discussions include inline code review comments with file path and line number in the `position` object. Filter out system notes with `n.get('system')`.

Auth header for direct curl calls: `--header "PRIVATE-TOKEN: $GITLAB_TOKEN"` after sourcing `~/.secrets/source-secrets.sh`.
</helper_gaps>
