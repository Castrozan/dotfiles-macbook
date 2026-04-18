#!/usr/bin/env bats

load '../../../../tests/helpers/bash-script-assertions'

SCRIPT_UNDER_TEST="$(command -v close-focused-window)"

@test "is executable" {
	assert_is_executable
}

@test "queries aerospace for focused window pid" {
	assert_script_source_matches 'aerospace list-windows --focused.*app-pid'
}

@test "exits cleanly when no window is focused" {
	assert_script_source_matches '\[ -z "\$focused_application_pid" \] && exit 0'
}

@test "calls aerospace close before killing process" {
	assert_pattern_appears_before 'aerospace close' 'kill'
}

@test "sends sigterm before sigkill" {
	assert_pattern_appears_before 'kill "\$focused_application_pid"' 'kill -9'
}

@test "sigkill fallback runs in background" {
	assert_script_source_matches '^\(sleep 1 &&.*kill -9.*&$'
}

@test "sigkill only fires if process still alive" {
	assert_script_source_matches 'kill -0 "\$focused_application_pid".*kill -9'
}
