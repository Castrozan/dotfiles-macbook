---
name: rebuild
description: Apply Nix configuration changes. Use when modifying .nix files, after flake updates, or when user asks to rebuild/apply dotfiles changes.
---

<announcement>
"I'm using the rebuild skill to apply configuration changes."
</announcement>

<prerequisite>
Nix reads from git index, not working tree. Stage all modified .nix files before rebuilding. Never use `git add -A` or `git add .` (may stage unrelated parallel work). The rebuild script auto-stages unstaged .nix files, but you should still commit first per git conventions.
</prerequisite>

<execution>
The `rebuild` script is packaged via `hosts/macbook/scripts/rebuild.nix` and available in PATH after first install. It sources nix-daemon.sh if needed, stages unstaged .nix files, and runs `sudo darwin-rebuild switch --flake ~/.dotfiles#macbook`. Pass extra args like `--dry-run` directly.

The Bash tool inherits PATH from Claude Code's `env.PATH` setting in `settings.json`, which includes all Nix profile paths. Just run `rebuild` directly — no PATH export needed.

For the first bootstrap (before the rebuild script or settings.json exist), run directly:
```
export PATH="/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:$PATH" && sudo darwin-rebuild switch --flake ~/.dotfiles#macbook
```
</execution>

<timeout_trap>
Run rebuild in the background with short poll intervals. Never use process poll with timeout > 60000ms. A hung nix build can block for minutes — a single long poll eats the entire agent timeout budget and bricks the session. The rebuild output is verbose — use background execution and only check the final exit code + last few lines.
</timeout_trap>

<dry_run>
Validate configuration before applying by running `rebuild --dry-run`. Catches syntax errors, missing imports, and evaluation failures without modifying the system.
</dry_run>

<troubleshooting>
Build fails with import error: file not staged (check git status). Attribute not found: module not imported in home.nix or configuration.nix. Unfree package: nixpkgs config sets allowUnfree. Wrong config: flake output is `darwinConfigurations.macbook`.
</troubleshooting>
