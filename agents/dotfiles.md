---
description: Agent behavior instructions specific to the .dotfiles repository
alwaysApply: true
---

## Policies

### External repository access

The repository github.com/castrozan/.dotfiles must never be cloned locally, not to the working directory, /tmp, or any path on this machine. It contains filenames that are prohibited on local disk by infra policy. All access to that repo must go through GitHub API (`gh api`, `gh browse`) or HTTPS raw file fetches. This constraint applies to all agents, subagents, worktrees, and one-shot sessions without exception.

### Compositor reload

System rebuilds must never cause visual disruption to the running compositor. Configuration reloads that do not involve monitor hardware changes must not re-apply monitor rules, as mode negotiation causes DRM mode switches visible as screen blackouts. Compositor autoreload from config management symlink updates must be suppressed because the config directory symlink changes on every rebuild regardless of content. Only monitor hardware events (plug, unplug, manual toggle) justify full compositor reload with monitor re-application.
