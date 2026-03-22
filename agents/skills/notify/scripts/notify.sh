#!/usr/bin/env bash
set -Eeuo pipefail

MESSAGE="${1:-Done}"
VOICE=""
SEND_MOBILE=false

shift || true
while [[ $# -gt 0 ]]; do
	case "$1" in
	--voice)
		VOICE="$2"
		shift 2
		;;
	--mobile)
		SEND_MOBILE=true
		shift
		;;
	*) shift ;;
	esac
done

_resolve_voice() {
	local tts_json="${WORKSPACE:+${WORKSPACE}/tts.json}"
	[[ -z "$tts_json" ]] && tts_json="$(git -C "${PWD}" rev-parse --show-toplevel 2>/dev/null)/tts.json"
	jq -r '.voice // empty' "${tts_json}" 2>/dev/null || echo "en-US-GuyNeural"
}

_notify_darwin() {
	osascript -e "display notification \"${MESSAGE//\"/\\\"}\" with title \"Claude Code\"" &>/dev/null || true
	say "$MESSAGE" &>/dev/null || true
}

_notify_linux() {
	[[ -z "$VOICE" ]] && VOICE=$(_resolve_voice)

	local XDG_RUNTIME_DIR
	XDG_RUNTIME_DIR="/run/user/$(id -u)"
	local AUDIO_FILE
	AUDIO_FILE=$(mktemp /tmp/notify-XXXXXX.mp3)
	export XDG_RUNTIME_DIR

	trap 'rm -f "$AUDIO_FILE"' EXIT

	edge-tts --voice "$VOICE" --text "$MESSAGE" --write-media "$AUDIO_FILE" 2>/dev/null
	wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 &>/dev/null || true
	mpv --no-video --ao=pulse "$AUDIO_FILE" &>/dev/null || true

	DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus" \
		notify-send -a "Claude Code" "Claude Code" "$MESSAGE" &>/dev/null || true
}

case "$(uname -s)" in
Darwin) _notify_darwin ;;
*) _notify_linux ;;
esac

if [[ "$SEND_MOBILE" == true ]]; then
	NTFY_TOPIC="${NTFY_TOPIC:-@notifyTopic@}"
	curl -sf -H "Title: Claude Code" -H "Priority: 3" -d "$MESSAGE" "ntfy.sh/${NTFY_TOPIC}" &>/dev/null || true
fi
