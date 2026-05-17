## Window Management

AeroSpace manages virtual workspaces — all windows live on macOS space 1, with AeroSpace hiding inactive workspace windows by moving them offscreen. This means macOS-native tools (AltTab, Mission Control) see every window as being on the same space.

### Cmd+Tab workspace-aware switching

macOS intercepts Cmd+Tab at the WindowServer level before any app can catch it. Karabiner operates at the HID layer, which is lower, so it intercepts Cmd+Tab and runs `hosts/macbook/scripts/workspace-window-switcher` via `shell_command`. The script queries AeroSpace for windows on the focused workspace and presents them through `choose` (a macOS native fuzzy picker). Selecting a window calls `aerospace focus --window-id` to switch to it.

Karabiner's shell environment has no nix PATH, so all binaries in the script use absolute paths (`/usr/bin/python3`, `/etc/profiles/per-user/lucas.zanoni/bin/choose`). The AeroSpace CLI path is resolved dynamically from the running AeroSpace process via `lsof` to survive nix store hash changes.

### Karabiner install architecture

Karabiner-Elements 15.x is installed via the homebrew cask `karabiner-elements` in `hosts/macbook/default.nix`. Three processes do the work:

- `Karabiner-Core-Service` (root, launchd label `org.pqrs.service.agent.Karabiner-Core-Service`) hosts the HID device grabber as a C++ class. Replaces the standalone `karabiner_grabber` binary from 14.x and earlier.
- `karabiner_console_user_server` (per-user launchd agent `org.pqrs.service.agent.karabiner_console_user_server`) loads `~/.config/karabiner/karabiner.json` and pushes rules to the core service.
- `Karabiner-VirtualHIDDevice-Daemon` plus the DriverKit system extension `org.pqrs.Karabiner-DriverKit-VirtualHIDDevice` provide the virtual keyboard and mouse used to post the remapped events back into the system.

Install (Homebrew cask) lives at `hosts/macbook/karabiner/homebrew-cask.nix` because `homebrew.casks` is a nix-darwin system-level option and cannot sit inside a home-manager module. Everything else (rules, deployment, restart-on-wake daemon, orphan cleanup) is user-scoped under `home/modules/desktop/karabiner/`:

```
home/modules/desktop/karabiner/
├── default.nix                              # imports every sub-module below
├── rules/default.nix                        # rule list (pure function imported with { username })
├── config-deployment/
│   ├── copy-rules-json-to-user-config-directory.nix
│   └── kick-console-user-server-every-rebuild.nix
├── restart-on-wake/
│   ├── launchd-agent.nix                    # home-manager launchd.agents.karabiner-restart-on-wake
│   └── scripts/karabiner-restart-on-wake-daemon
├── status/
│   ├── home-manager-binary.nix              # wires karabiner-status into home.packages
│   └── scripts/karabiner-status
├── orphan-launchd-cleanup/
│   ├── home-manager-activation.nix
│   └── scripts/remove-orphan-nix-darwin-karabiner-launchd-entries
└── tests/
    ├── conftest.py
    ├── test_karabiner_restart_on_wake_daemon.py
    └── test_karabiner_status_cli.py
```

Config flow: `rules/default.nix` returns the rule list, `config-deployment/copy-rules-json-to-user-config-directory.nix` serializes it to `~/.config/karabiner/karabiner.json` (only when content differs, preserving inode), and `config-deployment/kick-console-user-server-every-rebuild.nix` runs `launchctl kickstart -k karabiner_console_user_server` so the new config loads immediately.

### Karabiner health-monitor daemon (IPC probe + passive observability)

`restart-on-wake/launchd-agent.nix` declares a home-manager LaunchAgent labelled `com.dotfiles.karabiner-restart-on-wake` that runs the Python daemon at `restart-on-wake/scripts/karabiner-restart-on-wake-daemon`. The daemon does three things:

1. **Full health probe every 60s.** Two parts: (a) passive checks — `pgrep -x` for both `Karabiner-Core-Service` and `karabiner_console_user_server`, plus mtime of each Karabiner-managed log file; (b) IPC probe — `karabiner_cli --show-current-profile-name` and `karabiner_cli --list-connected-devices` with a 5s timeout. The IPC probe roundtrips through `karabiner_console_user_server` itself — the same component that silently degrades — so a failed probe is evidence that rules may also stop firing. Reactive kicking on probe failure is enabled (`KARABINER_CLI_IPC_PROBE_FAILURE_KICK_IS_ENABLED = True`), gated by `CONSECUTIVE_IPC_PROBE_FAILURES_REQUIRED_BEFORE_KICK = 3` consecutive failures and a `MINIMUM_SECONDS_BETWEEN_REACTIVE_KICKS = 300s` cooldown to prevent cascading kicks. Steady-state probe latency from the launchd-managed daemon is 1-2 seconds (vs ~70ms from a shell); the 5s timeout accommodates that with margin. Observe `karabiner-status` over the first few days after enabling — if reactive kicks fire only after wake events or rebuilds, the safeguards are doing their job and the 30-min periodic safety net can be dropped.
2. **Wake-event kick.** On `NSWorkspaceDidWakeNotification`, kicks `karabiner_console_user_server` unconditionally because Karabiner reliably loses HID grab state across sleep/wake.
3. **Periodic safety-net kick every 30 minutes.** Last-resort backstop for failure modes the IPC probe cannot detect (e.g. degradation that affects rule firing without breaking the IPC channel). Was 15 min before the IPC probe was added.

CGEventPost-based active canary was tried and removed: macOS gates keyboard event posting from launchd-managed processes behind Accessibility permission, which cannot be granted persistently to a binary whose nix store path changes every rebuild. `karabiner_cli` is a stable-path binary shipped by Karabiner-Elements itself, requires no permissions, and exercises the same IPC channel as rule firing.

### Health observability

The daemon maintains two files in `/tmp`:

- `/tmp/karabiner-health.json` - structured health state read by the `karabiner-status` CLI. Keys: `daemon_started_epoch`, `daemon_process_id`, `last_health_probe_epoch`, `karabiner_core_service_process_running`, `karabiner_console_user_server_process_running`, `karabiner_core_service_log_mtime_epoch`, `karabiner_console_user_server_log_mtime_epoch`, `karabiner_cli_ipc_probe_succeeded`, `karabiner_cli_ipc_probe_latency_seconds`, `karabiner_cli_ipc_probe_failure_reason`, `karabiner_current_profile_name`, `karabiner_grabbed_keyboard_device_count`, `karabiner_cli_ipc_probe_failure_count_total`, `last_kick_epoch`, `last_kick_reason`, `last_kick_duration_seconds`, `last_wake_epoch`, `kick_count_total`.
- `/tmp/karabiner-daemon.log` - one JSON event per line. `event` values: `daemon_started`, `wake`, `health_probe`, `ipc_probe_degraded_detected`, `kick_attempt`, `kick_completed`. Each line carries `epoch` and `iso8601` timestamps.

`kick_reason` values: `wake`, `karabiner_cli_ipc_probe_failure`, `periodic_safety_net`.

Karabiner-Elements writes its own structured logs at `~/.local/share/karabiner/log/console_user_server.log` (per-user, owned) and `/var/log/karabiner/core_service.log` (root-owned, world-readable). The daemon never writes to these but uses their mtime as a freshness signal in the health file.

### `karabiner-status` CLI

`status/home-manager-binary.nix` exposes `karabiner-status` on PATH. Reads the health file and prints a human summary:

```
$ karabiner-status
Karabiner daemon: HEALTHY
  Daemon process:                pid=51849, started 3.2h ago
  Karabiner-Core-Service:        running
  karabiner_console_user_server: running
  karabiner_cli IPC probe:       OK (62ms latency)
  Current Karabiner profile:     Default
  Grabbed keyboard devices:      5
  Last health probe:             12s ago
  Core service log last write:   4s ago
  User server log last write:    8s ago
  Last kick:                     27m ago (reason: periodic_safety_net)
  Last wake:                     2.1h ago
  Total kicks:                   7
  IPC probe failures total:      0
```

Flags: `--json` for raw JSON, `--log-tail N` to append the last N event log lines. Exit code is 0 when both Karabiner processes are running AND the last IPC probe succeeded, 1 otherwise (script-friendly for monitoring).

### Orphan launchd cleanup

`orphan-launchd-cleanup/home-manager-activation.nix` runs `scripts/remove-orphan-nix-darwin-karabiner-launchd-entries` on every home-manager activation. It removes plists left behind by an earlier `services.karabiner-elements.enable = true` (no longer in the repo): two LaunchDaemons under `/Library/LaunchDaemons/org.nixos.*karabiner*.plist`, one LaunchAgent under `~/Library/LaunchAgents/`, and `/Applications/.Nix-Karabiner/`. The orphans pointed to garbage-collected nix store paths and failed on every boot with exit 126. The script gates sudo behind presence checks, so a fresh machine without any orphans incurs zero privileged calls.

### Keybinding chain

Karabiner intercepts physical keys first. Removing the Cmd+1-7 → Ctrl+1-7 Karabiner rules was required for AeroSpace keybindings to work — those rules were previously sending Ctrl+N to macOS for native space switching, which meant AeroSpace never received Cmd+N. AeroSpace now handles Cmd+1-7 for workspace switching and Cmd+Tab is routed through Karabiner's shell_command to the switcher script.

### AltTab

Installed via homebrew cask, configured declaratively in `hosts/macbook/default.nix` under `CustomUserPreferences."com.lwouis.alt-tab-macos"`. The `holdShortcut` preference uses a dict format (`{ string = "⌘"; }`) that nix-darwin's `defaults write` does not serialize correctly, so the Cmd+Tab shortcut must be set manually in AltTab's GUI. AltTab is not currently used for Cmd+Tab since the AeroSpace workspace switcher replaced it, but remains installed as a fallback.

### AeroSpace config

`~/.config/aerospace/aerospace.toml` is a mutable file outside the nix store. The backup branch `backup/aerospace-workspaces` in this repo contains the nix module at `home/modules/desktop/aerospace.nix` if declarative management is needed later.
