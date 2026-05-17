import importlib.machinery
import importlib.util
import sys
from pathlib import Path
from unittest.mock import MagicMock

import pytest

PYOBJC_FRAMEWORK_MODULES_TO_MOCK = [
    "AppKit",
    "Foundation",
    "PyObjCTools",
    "PyObjCTools.AppHelper",
]

for pyobjc_framework_module_name in PYOBJC_FRAMEWORK_MODULES_TO_MOCK:
    sys.modules.setdefault(pyobjc_framework_module_name, MagicMock())

KARABINER_RESTART_ON_WAKE_DAEMON_SCRIPT_PATH = (
    Path(__file__).parent.parent
    / "restart-on-wake"
    / "scripts"
    / "karabiner-restart-on-wake-daemon"
)

KARABINER_STATUS_CLI_SCRIPT_PATH = (
    Path(__file__).parent.parent / "status" / "scripts" / "karabiner-status"
)


def _load_module_from_path(module_name, module_file_path):
    loader = importlib.machinery.SourceFileLoader(module_name, str(module_file_path))
    spec = importlib.util.spec_from_loader(module_name, loader)
    loaded_module = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = loaded_module
    spec.loader.exec_module(loaded_module)
    return loaded_module


@pytest.fixture
def karabiner_restart_on_wake_daemon_module():
    return _load_module_from_path(
        "karabiner_restart_on_wake_daemon",
        KARABINER_RESTART_ON_WAKE_DAEMON_SCRIPT_PATH,
    )


@pytest.fixture
def karabiner_status_cli_module():
    return _load_module_from_path(
        "karabiner_status_cli", KARABINER_STATUS_CLI_SCRIPT_PATH
    )


@pytest.fixture
def temporary_daemon_state_paths(tmp_path):
    health_state_file_path = tmp_path / "karabiner-health.json"
    structured_event_log_file_path = tmp_path / "karabiner-daemon.log"
    return {
        "health_state_file_path": str(health_state_file_path),
        "structured_event_log_file_path": str(structured_event_log_file_path),
    }


@pytest.fixture
def daemon_module_with_temporary_paths(
    karabiner_restart_on_wake_daemon_module, temporary_daemon_state_paths, monkeypatch
):
    monkeypatch.setattr(
        karabiner_restart_on_wake_daemon_module,
        "DAEMON_HEALTH_STATE_FILE_PATH",
        temporary_daemon_state_paths["health_state_file_path"],
    )
    monkeypatch.setattr(
        karabiner_restart_on_wake_daemon_module,
        "DAEMON_STRUCTURED_EVENT_LOG_FILE_PATH",
        temporary_daemon_state_paths["structured_event_log_file_path"],
    )
    return karabiner_restart_on_wake_daemon_module


@pytest.fixture
def status_cli_module_with_temporary_paths(
    karabiner_status_cli_module, temporary_daemon_state_paths, monkeypatch
):
    monkeypatch.setattr(
        karabiner_status_cli_module,
        "DAEMON_HEALTH_STATE_FILE_PATH",
        temporary_daemon_state_paths["health_state_file_path"],
    )
    monkeypatch.setattr(
        karabiner_status_cli_module,
        "DAEMON_STRUCTURED_EVENT_LOG_FILE_PATH",
        temporary_daemon_state_paths["structured_event_log_file_path"],
    )
    return karabiner_status_cli_module
