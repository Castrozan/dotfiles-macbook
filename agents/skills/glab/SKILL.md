---
name: glab
description: Manage GitLab merge requests, pipelines, and code review. Use when user asks to create/update/merge MRs, read MR comments, check CI status, review code, or interact with GitLab.
---

<announcement>
"I'm using the glab skill to interact with GitLab."
</announcement>

<harness>
All GitLab operations go through `python3 <this skill's scripts/glab-harness.py>`. Run with `--help` and `<subcommand> --help` for flags and syntax. The Nix store copy lacks execute permission; always invoke with `python3`. The harness uses direct HTTP to the GitLab API (no glab CLI dependency), resolves the project path from git remote origin, and auto-sources GITLAB_TOKEN from `~/.secrets/source-secrets.sh`. Do not use the `glab` CLI, raw curl, or direct API calls; the harness exists to prevent the silent failures and escaping issues those approaches cause.

Descriptions use `--description-file` (path to a file) instead of inline strings. Write markdown to a temp file, pass the path. This eliminates shell escaping corruption that breaks markdown, special characters, and code blocks.
</harness>

<traps>
Do not use `git push --delete` on protected branches; the pre-receive hook rejects silently. Use the harness `delete-branch` command which calls the REST API and bypasses branch protection.

The harness resolves the project from `git remote get-url origin`. Inside a git worktree this works correctly (unlike the glab CLI which misdetects repo context), but run from the main repo directory when possible.
</traps>
