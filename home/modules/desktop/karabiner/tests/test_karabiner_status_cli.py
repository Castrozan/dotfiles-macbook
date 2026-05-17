import json
import time


def test_format_seconds_ago_returns_never_for_none(karabiner_status_cli_module):
    assert (
        karabiner_status_cli_module.format_seconds_ago_as_human_readable_duration(None)
        == "never"
    )


def test_format_seconds_ago_returns_seconds_under_minute(karabiner_status_cli_module):
    epoch_thirty_seconds_ago = time.time() - 30
    formatted_duration = (
        karabiner_status_cli_module.format_seconds_ago_as_human_readable_duration(
            epoch_thirty_seconds_ago
        )
    )
    assert "s ago" in formatted_duration


def test_format_seconds_ago_returns_minutes_under_hour(karabiner_status_cli_module):
    epoch_five_minutes_ago = time.time() - 300
    formatted_duration = (
        karabiner_status_cli_module.format_seconds_ago_as_human_readable_duration(
            epoch_five_minutes_ago
        )
    )
    assert "m ago" in formatted_duration


def test_format_seconds_ago_returns_hours_under_day(karabiner_status_cli_module):
    epoch_two_hours_ago = time.time() - 7200
    formatted_duration = (
        karabiner_status_cli_module.format_seconds_ago_as_human_readable_duration(
            epoch_two_hours_ago
        )
    )
    assert "h ago" in formatted_duration


def test_health_status_is_healthy_when_both_processes_running_and_ipc_probe_succeeded(
    karabiner_status_cli_module,
):
    health_state = {
        "karabiner_core_service_process_running": True,
        "karabiner_console_user_server_process_running": True,
        "karabiner_cli_ipc_probe_succeeded": True,
        "last_health_probe_epoch": time.time(),
    }
    assert (
        karabiner_status_cli_module.determine_overall_health_status_from_state(
            health_state
        )
        == "HEALTHY"
    )


def test_health_status_is_degraded_when_ipc_probe_failed(karabiner_status_cli_module):
    health_state = {
        "karabiner_core_service_process_running": True,
        "karabiner_console_user_server_process_running": True,
        "karabiner_cli_ipc_probe_succeeded": False,
        "karabiner_cli_ipc_probe_failure_reason": "show-current-profile-name timed out",
        "last_health_probe_epoch": time.time(),
    }
    assert "DEGRADED" in (
        karabiner_status_cli_module.determine_overall_health_status_from_state(
            health_state
        )
    )


def test_health_status_is_degraded_when_core_service_not_running(
    karabiner_status_cli_module,
):
    health_state = {
        "karabiner_core_service_process_running": False,
        "karabiner_console_user_server_process_running": True,
    }
    assert (
        "DEGRADED"
        in karabiner_status_cli_module.determine_overall_health_status_from_state(
            health_state
        )
    )


def test_health_status_is_degraded_when_console_user_server_not_running(
    karabiner_status_cli_module,
):
    health_state = {
        "karabiner_core_service_process_running": True,
        "karabiner_console_user_server_process_running": False,
    }
    assert (
        "DEGRADED"
        in karabiner_status_cli_module.determine_overall_health_status_from_state(
            health_state
        )
    )


def test_health_status_is_no_file_when_state_is_none(karabiner_status_cli_module):
    assert (
        karabiner_status_cli_module.determine_overall_health_status_from_state(None)
        == "NO HEALTH FILE"
    )


def test_health_status_is_unknown_when_no_health_probe_yet(
    karabiner_status_cli_module,
):
    health_state = {
        "daemon_started_epoch": time.time(),
        "karabiner_core_service_process_running": True,
        "karabiner_console_user_server_process_running": True,
    }
    assert (
        "UNKNOWN"
        in karabiner_status_cli_module.determine_overall_health_status_from_state(
            health_state
        )
    )


def test_summary_exits_zero_for_healthy_state(karabiner_status_cli_module):
    health_state = {
        "karabiner_core_service_process_running": True,
        "karabiner_console_user_server_process_running": True,
        "karabiner_cli_ipc_probe_succeeded": True,
        "last_health_probe_epoch": time.time(),
        "daemon_process_id": 123,
        "daemon_started_epoch": time.time() - 60,
    }
    _summary, exit_code = (
        karabiner_status_cli_module.format_health_state_as_human_readable_summary(
            health_state
        )
    )
    assert exit_code == karabiner_status_cli_module.EXIT_CODE_HEALTHY


def test_summary_exits_nonzero_for_process_not_running(karabiner_status_cli_module):
    health_state = {
        "karabiner_core_service_process_running": False,
        "karabiner_console_user_server_process_running": True,
        "karabiner_cli_ipc_probe_succeeded": True,
        "last_health_probe_epoch": time.time(),
        "daemon_process_id": 123,
        "daemon_started_epoch": time.time() - 60,
    }
    _summary, exit_code = (
        karabiner_status_cli_module.format_health_state_as_human_readable_summary(
            health_state
        )
    )
    assert exit_code == karabiner_status_cli_module.EXIT_CODE_DEGRADED


def test_summary_exits_nonzero_for_ipc_probe_failure(karabiner_status_cli_module):
    health_state = {
        "karabiner_core_service_process_running": True,
        "karabiner_console_user_server_process_running": True,
        "karabiner_cli_ipc_probe_succeeded": False,
        "karabiner_cli_ipc_probe_failure_reason": "timed out",
        "last_health_probe_epoch": time.time(),
        "daemon_process_id": 123,
        "daemon_started_epoch": time.time() - 60,
    }
    _summary, exit_code = (
        karabiner_status_cli_module.format_health_state_as_human_readable_summary(
            health_state
        )
    )
    assert exit_code == karabiner_status_cli_module.EXIT_CODE_DEGRADED


def test_summary_exits_nonzero_for_missing_health_file(karabiner_status_cli_module):
    _summary, exit_code = (
        karabiner_status_cli_module.format_health_state_as_human_readable_summary(None)
    )
    assert exit_code == karabiner_status_cli_module.EXIT_CODE_DEGRADED


def test_read_health_state_returns_none_when_file_missing(
    status_cli_module_with_temporary_paths,
):
    assert (
        status_cli_module_with_temporary_paths.read_health_state_from_file_or_none()
        is None
    )


def test_read_health_state_returns_parsed_json_when_file_present(
    status_cli_module_with_temporary_paths,
):
    test_payload = {
        "kick_count_total": 7,
        "karabiner_core_service_process_running": True,
        "karabiner_console_user_server_process_running": True,
    }
    with open(
        status_cli_module_with_temporary_paths.DAEMON_HEALTH_STATE_FILE_PATH, "w"
    ) as health_state_file:
        json.dump(test_payload, health_state_file)
    assert (
        status_cli_module_with_temporary_paths.read_health_state_from_file_or_none()
        == test_payload
    )


def test_read_health_state_returns_none_when_file_is_corrupt_json(
    status_cli_module_with_temporary_paths,
):
    with open(
        status_cli_module_with_temporary_paths.DAEMON_HEALTH_STATE_FILE_PATH, "w"
    ) as health_state_file:
        health_state_file.write("not valid json {{{")
    assert (
        status_cli_module_with_temporary_paths.read_health_state_from_file_or_none()
        is None
    )
