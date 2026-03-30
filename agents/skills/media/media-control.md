<usage>
Run scripts/media-control.sh with subcommands: status, play, pause, toggle, next, previous, volume VALUE, list. Pass --player NAME to target a specific player when multiple are active.
</usage>

<pitfalls>
On macOS, controls Music.app via osascript; volume values are 0-100 (not 0.0-1.0). On Linux, uses playerctl with MPRIS and requires DBUS_SESSION_BUS_ADDRESS. playerctl auto-selects the "most relevant" player which may not be what you expect with multiple players running, so use "list" first, then --player NAME. Some players (Brave/Chrome) expose MPRIS but ignore volume commands; use system volume instead for browser audio.
</pitfalls>
