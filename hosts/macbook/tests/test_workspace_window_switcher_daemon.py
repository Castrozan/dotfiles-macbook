import json
import os
from unittest.mock import MagicMock, call, patch

import workspace_window_switcher_daemon as daemon


class TestStateMachineInitialState:
    def test_starts_inactive(self, switcher_state):
        assert not switcher_state.is_active

    def test_starts_with_empty_window_list(self, switcher_state):
        assert switcher_state._windows == []
        assert switcher_state._selected_index == 0


class TestStateMachineActivation:
    def test_activates_with_multiple_windows(
        self, aerospace_provider_with_windows, mock_overlay
    ):
        state = daemon.WindowSwitcherStateMachine(
            aerospace_provider_with_windows, mock_overlay
        )
        state.handle_next_command()
        assert state.is_active
        mock_overlay.show_with_windows_and_selection.assert_called_once()

    def test_does_not_activate_with_single_window(
        self, mock_aerospace_provider, mock_overlay
    ):
        mock_aerospace_provider.get_focused_workspace_windows.return_value = [
            {"window-id": 1001, "app-name": "WezTerm", "window-title": "term"}
        ]
        mock_aerospace_provider.get_focused_window_id.return_value = 1001
        state = daemon.WindowSwitcherStateMachine(mock_aerospace_provider, mock_overlay)
        state.handle_next_command()
        assert not state.is_active
        mock_overlay.show_with_windows_and_selection.assert_not_called()

    def test_does_not_activate_with_zero_windows(
        self, mock_aerospace_provider, mock_overlay
    ):
        mock_aerospace_provider.get_focused_workspace_windows.return_value = []
        state = daemon.WindowSwitcherStateMachine(mock_aerospace_provider, mock_overlay)
        state.handle_next_command()
        assert not state.is_active
        mock_overlay.show_with_windows_and_selection.assert_not_called()


class TestStateMachineWindowOrdering:
    def test_focused_window_is_placed_first(
        self, aerospace_provider_with_windows, mock_overlay
    ):
        state = daemon.WindowSwitcherStateMachine(
            aerospace_provider_with_windows, mock_overlay
        )
        state.handle_next_command()
        assert state._windows[0]["window-id"] == 1001

    def test_non_focused_windows_follow_focused(
        self, aerospace_provider_with_windows, mock_overlay
    ):
        state = daemon.WindowSwitcherStateMachine(
            aerospace_provider_with_windows, mock_overlay
        )
        state.handle_next_command()
        non_focused_ids = [w["window-id"] for w in state._windows[1:]]
        assert non_focused_ids == [1002, 1003, 1004]


class TestStateMachineInitialSelection:
    def test_first_next_selects_second_window(
        self, aerospace_provider_with_windows, mock_overlay
    ):
        state = daemon.WindowSwitcherStateMachine(
            aerospace_provider_with_windows, mock_overlay
        )
        state.handle_next_command()
        assert state._selected_index == 1

    def test_first_prev_selects_last_window(
        self, aerospace_provider_with_windows, mock_overlay
    ):
        state = daemon.WindowSwitcherStateMachine(
            aerospace_provider_with_windows, mock_overlay
        )
        state.handle_prev_command()
        assert state._selected_index == 3


class TestStateMachineSelectionCycling:
    def test_next_advances_selection(
        self, aerospace_provider_with_windows, mock_overlay
    ):
        state = daemon.WindowSwitcherStateMachine(
            aerospace_provider_with_windows, mock_overlay
        )
        state.handle_next_command()
        state.handle_next_command()
        assert state._selected_index == 2
        mock_overlay.update_selected_index.assert_called_with(2)

    def test_prev_reverses_selection(
        self, aerospace_provider_with_windows, mock_overlay
    ):
        state = daemon.WindowSwitcherStateMachine(
            aerospace_provider_with_windows, mock_overlay
        )
        state.handle_next_command()
        state.handle_next_command()
        state.handle_prev_command()
        assert state._selected_index == 1

    def test_next_wraps_past_end(self, aerospace_provider_with_windows, mock_overlay):
        state = daemon.WindowSwitcherStateMachine(
            aerospace_provider_with_windows, mock_overlay
        )
        state.handle_next_command()
        for _ in range(3):
            state.handle_next_command()
        assert state._selected_index == 0

    def test_prev_wraps_past_start(self, aerospace_provider_with_windows, mock_overlay):
        state = daemon.WindowSwitcherStateMachine(
            aerospace_provider_with_windows, mock_overlay
        )
        state.handle_next_command()
        state.handle_prev_command()
        assert state._selected_index == 0
        state.handle_prev_command()
        assert state._selected_index == 3


class TestStateMachineCommit:
    def test_commit_focuses_selected_window(
        self, aerospace_provider_with_windows, mock_overlay
    ):
        state = daemon.WindowSwitcherStateMachine(
            aerospace_provider_with_windows, mock_overlay
        )
        state.handle_next_command()
        state.handle_commit_command()
        aerospace_provider_with_windows.focus_window.assert_called_once_with(1002)

    def test_commit_focuses_cycled_window(
        self, aerospace_provider_with_windows, mock_overlay
    ):
        state = daemon.WindowSwitcherStateMachine(
            aerospace_provider_with_windows, mock_overlay
        )
        state.handle_next_command()
        state.handle_next_command()
        state.handle_next_command()
        state.handle_commit_command()
        aerospace_provider_with_windows.focus_window.assert_called_once_with(1004)

    def test_commit_hides_overlay(self, aerospace_provider_with_windows, mock_overlay):
        state = daemon.WindowSwitcherStateMachine(
            aerospace_provider_with_windows, mock_overlay
        )
        state.handle_next_command()
        state.handle_commit_command()
        mock_overlay.hide.assert_called_once()

    def test_commit_deactivates_state(
        self, aerospace_provider_with_windows, mock_overlay
    ):
        state = daemon.WindowSwitcherStateMachine(
            aerospace_provider_with_windows, mock_overlay
        )
        state.handle_next_command()
        state.handle_commit_command()
        assert not state.is_active

    def test_commit_clears_windows_and_index(
        self, aerospace_provider_with_windows, mock_overlay
    ):
        state = daemon.WindowSwitcherStateMachine(
            aerospace_provider_with_windows, mock_overlay
        )
        state.handle_next_command()
        state.handle_commit_command()
        assert state._windows == []
        assert state._selected_index == 0

    def test_commit_when_not_active_is_ignored(
        self, mock_aerospace_provider, mock_overlay
    ):
        state = daemon.WindowSwitcherStateMachine(mock_aerospace_provider, mock_overlay)
        state.handle_commit_command()
        mock_aerospace_provider.focus_window.assert_not_called()
        mock_overlay.hide.assert_not_called()


class TestStateMachineCancel:
    def test_cancel_hides_overlay(self, aerospace_provider_with_windows, mock_overlay):
        state = daemon.WindowSwitcherStateMachine(
            aerospace_provider_with_windows, mock_overlay
        )
        state.handle_next_command()
        state.handle_cancel_command()
        mock_overlay.hide.assert_called_once()

    def test_cancel_does_not_focus_any_window(
        self, aerospace_provider_with_windows, mock_overlay
    ):
        state = daemon.WindowSwitcherStateMachine(
            aerospace_provider_with_windows, mock_overlay
        )
        state.handle_next_command()
        state.handle_cancel_command()
        aerospace_provider_with_windows.focus_window.assert_not_called()

    def test_cancel_deactivates_state(
        self, aerospace_provider_with_windows, mock_overlay
    ):
        state = daemon.WindowSwitcherStateMachine(
            aerospace_provider_with_windows, mock_overlay
        )
        state.handle_next_command()
        state.handle_cancel_command()
        assert not state.is_active

    def test_cancel_when_not_active_is_ignored(
        self, mock_aerospace_provider, mock_overlay
    ):
        state = daemon.WindowSwitcherStateMachine(mock_aerospace_provider, mock_overlay)
        state.handle_cancel_command()
        mock_overlay.hide.assert_not_called()


class TestStateMachineCommitBeforeReady:
    def test_fast_commit_focuses_without_showing_overlay(
        self, mock_aerospace_provider, mock_overlay, sample_workspace_windows
    ):
        mock_aerospace_provider.get_focused_workspace_windows.return_value = (
            sample_workspace_windows
        )
        mock_aerospace_provider.get_focused_window_id.return_value = 1001

        state = daemon.WindowSwitcherStateMachine(mock_aerospace_provider, mock_overlay)

        state._active = True
        state._create_active_flag_file()
        state._fetching_windows = True
        state._commit_requested_before_ready = False
        state._pending_direction_changes = 1

        state.handle_commit_command()
        assert state._commit_requested_before_ready

        state._on_aerospace_windows_fetched(sample_workspace_windows, 1001)
        mock_overlay.show_with_windows_and_selection.assert_not_called()
        mock_aerospace_provider.focus_window.assert_called_once_with(1002)
        assert not state.is_active


class TestStateMachineDirectionAccumulation:
    def test_multiple_nexts_during_fetch_accumulate(
        self, mock_aerospace_provider, mock_overlay, sample_workspace_windows
    ):
        mock_aerospace_provider.get_focused_workspace_windows.return_value = (
            sample_workspace_windows
        )
        mock_aerospace_provider.get_focused_window_id.return_value = 1001

        state = daemon.WindowSwitcherStateMachine(mock_aerospace_provider, mock_overlay)
        state._active = True
        state._create_active_flag_file()
        state._fetching_windows = True
        state._pending_direction_changes = 1

        state.handle_next_command()
        state.handle_next_command()

        state._on_aerospace_windows_fetched(sample_workspace_windows, 1001)
        assert state._selected_index == 3

    def test_multiple_prevs_during_fetch_accumulate(
        self, mock_aerospace_provider, mock_overlay, sample_workspace_windows
    ):
        mock_aerospace_provider.get_focused_workspace_windows.return_value = (
            sample_workspace_windows
        )
        mock_aerospace_provider.get_focused_window_id.return_value = 1001

        state = daemon.WindowSwitcherStateMachine(mock_aerospace_provider, mock_overlay)
        state._active = True
        state._create_active_flag_file()
        state._fetching_windows = True
        state._pending_direction_changes = -1

        state.handle_prev_command()

        state._on_aerospace_windows_fetched(sample_workspace_windows, 1001)
        assert state._selected_index == 2

    def test_mixed_directions_during_fetch_cancel_out(
        self, mock_aerospace_provider, mock_overlay, sample_workspace_windows
    ):
        mock_aerospace_provider.get_focused_workspace_windows.return_value = (
            sample_workspace_windows
        )
        mock_aerospace_provider.get_focused_window_id.return_value = 1001

        state = daemon.WindowSwitcherStateMachine(mock_aerospace_provider, mock_overlay)
        state._active = True
        state._create_active_flag_file()
        state._fetching_windows = True
        state._pending_direction_changes = 1

        state.handle_next_command()
        state.handle_prev_command()

        state._on_aerospace_windows_fetched(sample_workspace_windows, 1001)
        assert state._selected_index == 1


class TestStateMachineFlagFile:
    def test_flag_file_created_on_activation(
        self, aerospace_provider_with_windows, mock_overlay, temporary_active_flag_path
    ):
        state = daemon.WindowSwitcherStateMachine(
            aerospace_provider_with_windows, mock_overlay
        )
        state.handle_next_command()
        assert os.path.exists(temporary_active_flag_path)

    def test_flag_file_removed_on_commit(
        self, aerospace_provider_with_windows, mock_overlay, temporary_active_flag_path
    ):
        state = daemon.WindowSwitcherStateMachine(
            aerospace_provider_with_windows, mock_overlay
        )
        state.handle_next_command()
        state.handle_commit_command()
        assert not os.path.exists(temporary_active_flag_path)

    def test_flag_file_removed_on_cancel(
        self, aerospace_provider_with_windows, mock_overlay, temporary_active_flag_path
    ):
        state = daemon.WindowSwitcherStateMachine(
            aerospace_provider_with_windows, mock_overlay
        )
        state.handle_next_command()
        state.handle_cancel_command()
        assert not os.path.exists(temporary_active_flag_path)

    def test_flag_file_removed_on_deactivation_with_no_windows(
        self, mock_aerospace_provider, mock_overlay, temporary_active_flag_path
    ):
        mock_aerospace_provider.get_focused_workspace_windows.return_value = []
        mock_aerospace_provider.get_focused_window_id.return_value = None
        state = daemon.WindowSwitcherStateMachine(mock_aerospace_provider, mock_overlay)
        state.handle_next_command()
        assert not os.path.exists(temporary_active_flag_path)


class TestStateMachineReactivation:
    def test_can_reactivate_after_commit(
        self, aerospace_provider_with_windows, mock_overlay
    ):
        state = daemon.WindowSwitcherStateMachine(
            aerospace_provider_with_windows, mock_overlay
        )
        state.handle_next_command()
        state.handle_commit_command()
        assert not state.is_active

        state.handle_next_command()
        assert state.is_active
        assert mock_overlay.show_with_windows_and_selection.call_count == 2

    def test_can_reactivate_after_cancel(
        self, aerospace_provider_with_windows, mock_overlay
    ):
        state = daemon.WindowSwitcherStateMachine(
            aerospace_provider_with_windows, mock_overlay
        )
        state.handle_next_command()
        state.handle_cancel_command()

        state.handle_next_command()
        assert state.is_active


class TestStateMachineWithTwoWindows:
    def test_single_tab_switches_between_two_windows(
        self, mock_aerospace_provider, mock_overlay
    ):
        mock_aerospace_provider.get_focused_workspace_windows.return_value = [
            {"window-id": 1, "app-name": "A", "window-title": "a"},
            {"window-id": 2, "app-name": "B", "window-title": "b"},
        ]
        mock_aerospace_provider.get_focused_window_id.return_value = 1
        state = daemon.WindowSwitcherStateMachine(mock_aerospace_provider, mock_overlay)
        state.handle_next_command()
        state.handle_commit_command()
        mock_aerospace_provider.focus_window.assert_called_with(2)


class TestAeroSpaceWindowProviderSocketResolution:
    def test_resolves_socket_from_username(self, tmp_path):
        provider = daemon.AeroSpaceWindowProvider()
        socket_file = tmp_path / "bobko.aerospace-testuser.sock"
        socket_file.touch()
        with patch.dict(os.environ, {"USER": "testuser"}):
            with patch.object(daemon.os.path, "exists", return_value=True):
                result = provider._resolve_aerospace_socket_path()
        assert "bobko.aerospace-testuser.sock" in result

    def test_returns_none_when_no_socket_exists(self):
        provider = daemon.AeroSpaceWindowProvider()
        with patch.dict(os.environ, {"USER": "nonexistent"}):
            with patch.object(daemon.os.path, "exists", return_value=False):
                with patch.object(daemon.glob, "glob", return_value=[]):
                    result = provider._resolve_aerospace_socket_path()
        assert result is None

    def test_caches_socket_path(self):
        provider = daemon.AeroSpaceWindowProvider()
        provider._cached_socket_path = "/tmp/bobko.aerospace-cached.sock"
        assert provider._get_socket_path() == "/tmp/bobko.aerospace-cached.sock"


class TestAeroSpaceWindowProviderIpcCommands:
    def test_parses_focused_workspace_windows(self):
        provider = daemon.AeroSpaceWindowProvider()
        windows_json = '[{"window-id": 1, "app-name": "Test", "window-title": "t"}]'
        ipc_response = json.dumps(
            {
                "exitCode": 0,
                "stdout": windows_json,
                "stderr": "",
                "serverVersionAndHash": "test",
            }
        )
        with patch.object(provider, "_send_ipc_command", return_value=windows_json):
            result = provider.get_focused_workspace_windows()
        assert len(result) == 1
        assert result[0]["window-id"] == 1

    def test_returns_empty_list_on_ipc_failure(self):
        provider = daemon.AeroSpaceWindowProvider()
        with patch.object(provider, "_send_ipc_command", return_value=None):
            result = provider.get_focused_workspace_windows()
        assert result == []

    def test_extracts_focused_window_id(self):
        provider = daemon.AeroSpaceWindowProvider()
        focused_json = '[{"window-id": 42}]'
        with patch.object(provider, "_send_ipc_command", return_value=focused_json):
            result = provider.get_focused_window_id()
        assert result == 42

    def test_returns_none_focused_id_with_empty_list(self):
        provider = daemon.AeroSpaceWindowProvider()
        with patch.object(provider, "_send_ipc_command", return_value="[]"):
            result = provider.get_focused_window_id()
        assert result is None

    def test_returns_none_focused_id_on_ipc_failure(self):
        provider = daemon.AeroSpaceWindowProvider()
        with patch.object(provider, "_send_ipc_command", return_value=None):
            result = provider.get_focused_window_id()
        assert result is None

    def test_focus_window_sends_correct_args(self):
        provider = daemon.AeroSpaceWindowProvider()
        with patch.object(provider, "_send_ipc_command") as mock_ipc:
            provider.focus_window(1234)
            mock_ipc.assert_called_once_with(["focus", "--window-id", "1234"])

    def test_invalidates_socket_cache_on_connection_error(self):
        provider = daemon.AeroSpaceWindowProvider()
        provider._cached_socket_path = "/tmp/nonexistent.sock"
        result = provider._send_ipc_command(["list-windows", "--focused"])
        assert result is None
        assert provider._cached_socket_path is None


class TestCommandSocketServerDispatch:
    def test_dispatches_next_to_handler(self):
        mock_state = MagicMock()
        server = daemon.CommandSocketServer(mock_state)
        server._dispatch_command_to_main_thread("next")
        mock_state.handle_next_command.assert_called_once()

    def test_dispatches_prev_to_handler(self):
        mock_state = MagicMock()
        server = daemon.CommandSocketServer(mock_state)
        server._dispatch_command_to_main_thread("prev")
        mock_state.handle_prev_command.assert_called_once()

    def test_dispatches_commit_to_handler(self):
        mock_state = MagicMock()
        server = daemon.CommandSocketServer(mock_state)
        server._dispatch_command_to_main_thread("commit")
        mock_state.handle_commit_command.assert_called_once()

    def test_dispatches_cancel_to_handler(self):
        mock_state = MagicMock()
        server = daemon.CommandSocketServer(mock_state)
        server._dispatch_command_to_main_thread("cancel")
        mock_state.handle_cancel_command.assert_called_once()

    def test_ignores_unknown_commands(self):
        mock_state = MagicMock()
        server = daemon.CommandSocketServer(mock_state)
        server._dispatch_command_to_main_thread("unknown_garbage")
        mock_state.handle_next_command.assert_not_called()
        mock_state.handle_prev_command.assert_not_called()
        mock_state.handle_commit_command.assert_not_called()
        mock_state.handle_cancel_command.assert_not_called()
