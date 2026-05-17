import json
import subprocess
from unittest.mock import MagicMock


def _make_completed_process_with_exit_zero(stdout_text=""):
    completion = MagicMock()
    completion.returncode = 0
    completion.stdout = stdout_text
    return completion


def _make_completed_process_with_exit_one(stdout_text=""):
    completion = MagicMock()
    completion.returncode = 1
    completion.stdout = stdout_text
    return completion


def _karabiner_cli_list_connected_devices_json_with_one_keyboard():
    return json.dumps(
        [{"device_identifiers": {"is_keyboard": True, "product_id": 1, "vendor_id": 1}}]
    )


def _route_subprocess_run_to_fake_completions(call_route_map):
    def fake_subprocess_run(command_line_arguments, **_kwargs):
        first_argument = command_line_arguments[0]
        second_argument = (
            command_line_arguments[1] if len(command_line_arguments) > 1 else ""
        )
        if first_argument == "/usr/bin/pgrep":
            return call_route_map["pgrep"]
        if "karabiner_cli" in first_argument:
            if second_argument == "--show-current-profile-name":
                return call_route_map["karabiner_cli_profile"]
            if second_argument == "--list-connected-devices":
                return call_route_map["karabiner_cli_devices"]
        if "launchctl" in first_argument:
            return call_route_map.get(
                "launchctl", _make_completed_process_with_exit_zero()
            )
        return _make_completed_process_with_exit_zero()

    return fake_subprocess_run


def test_kick_writes_kick_metadata_and_increments_total_counter(
    daemon_module_with_temporary_paths, monkeypatch
):
    daemon_module = daemon_module_with_temporary_paths
    monkeypatch.setattr(
        daemon_module.subprocess,
        "run",
        MagicMock(return_value=_make_completed_process_with_exit_zero()),
    )
    daemon_module.kick_karabiner_console_user_server_via_launchctl("wake")
    daemon_module.kick_karabiner_console_user_server_via_launchctl(
        "periodic_safety_net"
    )
    final_health_state = daemon_module.read_current_health_state_from_file()
    assert final_health_state["kick_count_total"] == 2
    assert final_health_state["last_kick_reason"] == "periodic_safety_net"
    assert "last_kick_epoch" in final_health_state
    assert "last_kick_duration_seconds" in final_health_state


def test_wake_event_writes_wake_epoch_and_kicks(
    daemon_module_with_temporary_paths, monkeypatch
):
    daemon_module = daemon_module_with_temporary_paths
    monkeypatch.setattr(
        daemon_module.subprocess,
        "run",
        MagicMock(return_value=_make_completed_process_with_exit_zero()),
    )
    daemon_module.record_wake_event_in_health_state_and_kick()
    final_health_state = daemon_module.read_current_health_state_from_file()
    assert "last_wake_epoch" in final_health_state
    assert final_health_state["last_kick_reason"] == "wake"


def test_periodic_safety_net_kick_uses_periodic_reason(
    daemon_module_with_temporary_paths, monkeypatch
):
    daemon_module = daemon_module_with_temporary_paths
    monkeypatch.setattr(
        daemon_module.subprocess,
        "run",
        MagicMock(return_value=_make_completed_process_with_exit_zero()),
    )
    daemon_module.run_periodic_safety_net_kick()
    final_health_state = daemon_module.read_current_health_state_from_file()
    assert final_health_state["last_kick_reason"] == "periodic_safety_net"


def test_health_state_writes_are_merged_not_overwritten(
    daemon_module_with_temporary_paths,
):
    daemon_module = daemon_module_with_temporary_paths
    daemon_module.write_merged_health_state_updates_to_file({"alpha": 1, "beta": 2})
    daemon_module.write_merged_health_state_updates_to_file({"beta": 99, "gamma": 3})
    final_health_state = daemon_module.read_current_health_state_from_file()
    assert final_health_state == {"alpha": 1, "beta": 99, "gamma": 3}


def test_structured_log_appends_one_json_line_per_event(
    daemon_module_with_temporary_paths,
):
    daemon_module = daemon_module_with_temporary_paths
    daemon_module.append_structured_event_log_line({"event": "first"})
    daemon_module.append_structured_event_log_line({"event": "second", "extra": 42})
    with open(daemon_module.DAEMON_STRUCTURED_EVENT_LOG_FILE_PATH, "r") as log_file:
        log_lines = log_file.readlines()
    assert len(log_lines) == 2
    first_event = json.loads(log_lines[0])
    second_event = json.loads(log_lines[1])
    assert first_event["event"] == "first"
    assert second_event["event"] == "second"
    assert second_event["extra"] == 42
    assert "epoch" in first_event
    assert "iso8601" in first_event


def test_karabiner_cli_ipc_probe_returns_success_with_profile_and_keyboard_count(
    daemon_module_with_temporary_paths, monkeypatch
):
    daemon_module = daemon_module_with_temporary_paths
    fake_run = _route_subprocess_run_to_fake_completions(
        {
            "pgrep": _make_completed_process_with_exit_zero(),
            "karabiner_cli_profile": _make_completed_process_with_exit_zero(
                "Default\n"
            ),
            "karabiner_cli_devices": _make_completed_process_with_exit_zero(
                _karabiner_cli_list_connected_devices_json_with_one_keyboard()
            ),
        }
    )
    monkeypatch.setattr(daemon_module.subprocess, "run", fake_run)
    probe_outcome = daemon_module.probe_karabiner_cli_ipc_and_return_outcome()
    assert probe_outcome["succeeded"] is True
    assert probe_outcome["failure_reason"] is None
    assert probe_outcome["profile_name"] == "Default"
    assert probe_outcome["grabbed_keyboard_device_count"] == 1


def test_karabiner_cli_ipc_probe_returns_failure_on_timeout(
    daemon_module_with_temporary_paths, monkeypatch
):
    daemon_module = daemon_module_with_temporary_paths

    def raising_subprocess_run(command_line_arguments, **_kwargs):
        raise subprocess.TimeoutExpired(command_line_arguments, timeout=2)

    monkeypatch.setattr(daemon_module.subprocess, "run", raising_subprocess_run)
    probe_outcome = daemon_module.probe_karabiner_cli_ipc_and_return_outcome()
    assert probe_outcome["succeeded"] is False
    assert "timed out" in probe_outcome["failure_reason"]


def test_karabiner_cli_ipc_probe_returns_failure_on_nonzero_exit(
    daemon_module_with_temporary_paths, monkeypatch
):
    daemon_module = daemon_module_with_temporary_paths
    fake_run = _route_subprocess_run_to_fake_completions(
        {
            "pgrep": _make_completed_process_with_exit_zero(),
            "karabiner_cli_profile": _make_completed_process_with_exit_one(""),
            "karabiner_cli_devices": _make_completed_process_with_exit_zero("[]"),
        }
    )
    monkeypatch.setattr(daemon_module.subprocess, "run", fake_run)
    probe_outcome = daemon_module.probe_karabiner_cli_ipc_and_return_outcome()
    assert probe_outcome["succeeded"] is False
    assert "show-current-profile-name exit 1" in probe_outcome["failure_reason"]


def test_karabiner_cli_ipc_probe_returns_failure_when_binary_missing(
    daemon_module_with_temporary_paths, monkeypatch
):
    daemon_module = daemon_module_with_temporary_paths

    def raising_subprocess_run(_command_line_arguments, **_kwargs):
        raise FileNotFoundError("karabiner_cli")

    monkeypatch.setattr(daemon_module.subprocess, "run", raising_subprocess_run)
    probe_outcome = daemon_module.probe_karabiner_cli_ipc_and_return_outcome()
    assert probe_outcome["succeeded"] is False
    assert "karabiner_cli binary not found" in probe_outcome["failure_reason"]


def test_full_health_probe_records_state_and_does_not_kick_when_healthy(
    daemon_module_with_temporary_paths, monkeypatch
):
    daemon_module = daemon_module_with_temporary_paths
    fake_run = _route_subprocess_run_to_fake_completions(
        {
            "pgrep": _make_completed_process_with_exit_zero(),
            "karabiner_cli_profile": _make_completed_process_with_exit_zero(
                "Default\n"
            ),
            "karabiner_cli_devices": _make_completed_process_with_exit_zero(
                _karabiner_cli_list_connected_devices_json_with_one_keyboard()
            ),
        }
    )
    subprocess_run_mock = MagicMock(side_effect=fake_run)
    monkeypatch.setattr(daemon_module.subprocess, "run", subprocess_run_mock)
    monkeypatch.setattr(
        daemon_module,
        "get_file_modification_epoch_seconds_or_none",
        lambda _file_path: 1234567890.5,
    )
    daemon_module.run_full_health_probe_and_kick_if_ipc_probe_failed()
    final_health_state = daemon_module.read_current_health_state_from_file()
    assert final_health_state["karabiner_cli_ipc_probe_succeeded"] is True
    assert final_health_state["karabiner_current_profile_name"] == "Default"
    assert final_health_state["karabiner_grabbed_keyboard_device_count"] == 1
    assert "last_kick_epoch" not in final_health_state
    kickstart_call_count = sum(
        1
        for call in subprocess_run_mock.call_args_list
        if "launchctl" in call.args[0][0]
    )
    assert kickstart_call_count == 0


def test_full_health_probe_does_not_kick_when_kick_feature_flag_is_disabled(
    daemon_module_with_temporary_paths, monkeypatch
):
    daemon_module = daemon_module_with_temporary_paths
    monkeypatch.setattr(
        daemon_module, "KARABINER_CLI_IPC_PROBE_FAILURE_KICK_IS_ENABLED", False
    )
    monkeypatch.setattr(
        daemon_module,
        "CONSECUTIVE_IPC_PROBE_FAILURES_REQUIRED_BEFORE_KICK",
        1,
    )
    fake_run = _route_subprocess_run_to_fake_completions(
        {
            "pgrep": _make_completed_process_with_exit_zero(),
            "karabiner_cli_profile": _make_completed_process_with_exit_one(""),
            "karabiner_cli_devices": _make_completed_process_with_exit_zero("[]"),
        }
    )
    subprocess_run_mock = MagicMock(side_effect=fake_run)
    monkeypatch.setattr(daemon_module.subprocess, "run", subprocess_run_mock)
    monkeypatch.setattr(
        daemon_module,
        "get_file_modification_epoch_seconds_or_none",
        lambda _file_path: 1234567890.5,
    )
    daemon_module.run_full_health_probe_and_kick_if_ipc_probe_failed()
    final_health_state = daemon_module.read_current_health_state_from_file()
    assert final_health_state["karabiner_cli_ipc_probe_succeeded"] is False
    assert final_health_state["karabiner_cli_ipc_probe_failure_count_total"] == 1
    assert final_health_state["consecutive_ipc_probe_failure_count"] == 1
    assert "last_kick_epoch" not in final_health_state


def test_full_health_probe_kicks_when_feature_flag_enabled_and_threshold_met(
    daemon_module_with_temporary_paths, monkeypatch
):
    daemon_module = daemon_module_with_temporary_paths
    monkeypatch.setattr(
        daemon_module, "KARABINER_CLI_IPC_PROBE_FAILURE_KICK_IS_ENABLED", True
    )
    monkeypatch.setattr(
        daemon_module,
        "CONSECUTIVE_IPC_PROBE_FAILURES_REQUIRED_BEFORE_KICK",
        2,
    )
    monkeypatch.setattr(daemon_module, "MINIMUM_SECONDS_BETWEEN_REACTIVE_KICKS", 0.0)
    fake_run = _route_subprocess_run_to_fake_completions(
        {
            "pgrep": _make_completed_process_with_exit_zero(),
            "karabiner_cli_profile": _make_completed_process_with_exit_one(""),
            "karabiner_cli_devices": _make_completed_process_with_exit_zero("[]"),
        }
    )
    monkeypatch.setattr(
        daemon_module.subprocess, "run", MagicMock(side_effect=fake_run)
    )
    monkeypatch.setattr(
        daemon_module,
        "get_file_modification_epoch_seconds_or_none",
        lambda _file_path: 1234567890.5,
    )
    daemon_module.run_full_health_probe_and_kick_if_ipc_probe_failed()
    assert (
        "last_kick_epoch" not in daemon_module.read_current_health_state_from_file()
    ), "first failure must not kick yet"
    daemon_module.run_full_health_probe_and_kick_if_ipc_probe_failed()
    final_health_state = daemon_module.read_current_health_state_from_file()
    assert (
        final_health_state["last_kick_reason"]
        == daemon_module.KICK_REASON_KARABINER_CLI_IPC_PROBE_FAILURE
    )
    assert final_health_state["consecutive_ipc_probe_failure_count"] == 2


def test_full_health_probe_resets_consecutive_failure_counter_on_success(
    daemon_module_with_temporary_paths, monkeypatch
):
    daemon_module = daemon_module_with_temporary_paths
    daemon_module.write_merged_health_state_updates_to_file(
        {"consecutive_ipc_probe_failure_count": 5}
    )
    fake_run = _route_subprocess_run_to_fake_completions(
        {
            "pgrep": _make_completed_process_with_exit_zero(),
            "karabiner_cli_profile": _make_completed_process_with_exit_zero(
                "Default\n"
            ),
            "karabiner_cli_devices": _make_completed_process_with_exit_zero(
                _karabiner_cli_list_connected_devices_json_with_one_keyboard()
            ),
        }
    )
    monkeypatch.setattr(
        daemon_module.subprocess, "run", MagicMock(side_effect=fake_run)
    )
    monkeypatch.setattr(
        daemon_module,
        "get_file_modification_epoch_seconds_or_none",
        lambda _file_path: 1234567890.5,
    )
    daemon_module.run_full_health_probe_and_kick_if_ipc_probe_failed()
    final_health_state = daemon_module.read_current_health_state_from_file()
    assert final_health_state["consecutive_ipc_probe_failure_count"] == 0


def test_full_health_probe_respects_cooldown_between_reactive_kicks(
    daemon_module_with_temporary_paths, monkeypatch
):
    daemon_module = daemon_module_with_temporary_paths
    monkeypatch.setattr(
        daemon_module, "KARABINER_CLI_IPC_PROBE_FAILURE_KICK_IS_ENABLED", True
    )
    monkeypatch.setattr(
        daemon_module,
        "CONSECUTIVE_IPC_PROBE_FAILURES_REQUIRED_BEFORE_KICK",
        1,
    )
    monkeypatch.setattr(daemon_module, "MINIMUM_SECONDS_BETWEEN_REACTIVE_KICKS", 3600.0)
    daemon_module.write_merged_health_state_updates_to_file(
        {"last_reactive_kick_epoch": daemon_module.current_epoch_seconds()}
    )
    fake_run = _route_subprocess_run_to_fake_completions(
        {
            "pgrep": _make_completed_process_with_exit_zero(),
            "karabiner_cli_profile": _make_completed_process_with_exit_one(""),
            "karabiner_cli_devices": _make_completed_process_with_exit_zero("[]"),
        }
    )
    monkeypatch.setattr(
        daemon_module.subprocess, "run", MagicMock(side_effect=fake_run)
    )
    monkeypatch.setattr(
        daemon_module,
        "get_file_modification_epoch_seconds_or_none",
        lambda _file_path: 1234567890.5,
    )
    daemon_module.run_full_health_probe_and_kick_if_ipc_probe_failed()
    final_health_state = daemon_module.read_current_health_state_from_file()
    assert "last_kick_epoch" not in final_health_state


def test_full_health_probe_does_not_kick_when_user_server_not_running(
    daemon_module_with_temporary_paths, monkeypatch
):
    daemon_module = daemon_module_with_temporary_paths
    monkeypatch.setattr(
        daemon_module, "KARABINER_CLI_IPC_PROBE_FAILURE_KICK_IS_ENABLED", True
    )
    monkeypatch.setattr(
        daemon_module,
        "CONSECUTIVE_IPC_PROBE_FAILURES_REQUIRED_BEFORE_KICK",
        1,
    )
    monkeypatch.setattr(daemon_module, "MINIMUM_SECONDS_BETWEEN_REACTIVE_KICKS", 0.0)
    fake_run = _route_subprocess_run_to_fake_completions(
        {
            "pgrep": _make_completed_process_with_exit_one(),
            "karabiner_cli_profile": _make_completed_process_with_exit_one(""),
            "karabiner_cli_devices": _make_completed_process_with_exit_zero("[]"),
        }
    )
    monkeypatch.setattr(
        daemon_module.subprocess, "run", MagicMock(side_effect=fake_run)
    )
    monkeypatch.setattr(
        daemon_module,
        "get_file_modification_epoch_seconds_or_none",
        lambda _file_path: None,
    )
    daemon_module.run_full_health_probe_and_kick_if_ipc_probe_failed()
    final_health_state = daemon_module.read_current_health_state_from_file()
    assert "last_kick_epoch" not in final_health_state
