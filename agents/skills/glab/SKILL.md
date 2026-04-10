---
name: glab
description: Manage GitLab merge requests, pipelines, and code review. Use when user asks to create/update/merge MRs, read MR comments, check CI status, review code, or interact with GitLab.
---

<announcement>
"I'm using the glab skill to interact with GitLab."
</announcement>

<harness>
Use only `python3 <this skill's scripts/glab-harness.py>` for all GitLab operations. No glab CLI, no curl, no direct API calls. Run `--help` for commands, `<subcommand> --help` for flags. Handles auth, project resolution, and URL encoding. Descriptions take `--description-file` (file path), not inline strings. Use `delete-branch` instead of `git push --delete` (protected branches reject silently).
</harness>
