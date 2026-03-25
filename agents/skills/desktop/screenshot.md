<usage>
Run scripts/screenshot.sh. Flags: --region (interactive select), --active (focused window), --output PATH. Prints absolute path to saved PNG.
</usage>

<pitfalls>
On macOS, uses screencapture — --region opens interactive selection (user must drag-select), --active captures the focused window via osascript. On Linux, uses grim/slurp (Wayland-only). The --region flag is interactive — don't use it in unattended automation. The --active flag depends on having a focused window.
</pitfalls>
