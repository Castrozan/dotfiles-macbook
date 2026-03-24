#!/usr/bin/env bats

load '../../../../tests/helpers/bash-script-assertions'

@test "passes shellcheck" {
	assert_passes_shellcheck
}

@test "uses strict error handling" {
	assert_uses_strict_error_handling
}

@test "safety check extracts basename from full nix store path" {
	assert_script_source_matches 'CLAUDE_COMMAND_NAME="\$\{CLAUDE_COMMAND_FULL_PATH##\*/\}'
}

@test "only kills process when command name matches claude" {
	assert_script_source_matches 'CLAUDE_COMMAND_NAME.*==.*claude'
}

@test "sends SIGTERM not SIGKILL for clean shutdown" {
	assert_script_source_matches 'kill -TERM'
	run grep -c 'SIGKILL\|kill -9\|kill -KILL' "$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/../scripts/claude-exit"
	[ "$output" = "0" ]
}

@test "resolves grandparent pid for process hierarchy traversal" {
	assert_script_source_matches 'ps -p "\$PPID" -o ppid='
}

@test "reports full path in safety check failure message" {
	assert_script_source_matches 'CLAUDE_COMMAND_FULL_PATH.*PID'
}
