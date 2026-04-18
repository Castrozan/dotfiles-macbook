import importlib
from unittest.mock import patch

workspace_navigator = importlib.import_module("workspace-navigator")


class TestCalculateAdjacentWorkspaceWithWraparound:
    all_workspaces = [1, 2, 3, 4, 5, 6, 7]

    def test_next_from_middle_increments(self):
        result = workspace_navigator.calculate_adjacent_workspace_with_wraparound(
            3, self.all_workspaces, "next"
        )
        assert result == 4

    def test_prev_from_middle_decrements(self):
        result = workspace_navigator.calculate_adjacent_workspace_with_wraparound(
            3, self.all_workspaces, "prev"
        )
        assert result == 2

    def test_next_wraps_from_last_to_first(self):
        result = workspace_navigator.calculate_adjacent_workspace_with_wraparound(
            7, self.all_workspaces, "next"
        )
        assert result == 1

    def test_prev_wraps_from_first_to_last(self):
        result = workspace_navigator.calculate_adjacent_workspace_with_wraparound(
            1, self.all_workspaces, "prev"
        )
        assert result == 7


class TestParseMonitorsWithNames:
    def test_parses_single_monitor(self):
        with patch.object(
            workspace_navigator,
            "run_aerospace_command",
            return_value="1 | Built-in Retina Display",
        ):
            result = workspace_navigator.parse_monitors_with_names()
        assert result == {"1": "Built-in Retina Display"}

    def test_parses_dual_monitors(self):
        with patch.object(
            workspace_navigator,
            "run_aerospace_command",
            return_value="1 | Built-in Retina Display\n2 | RG241Y",
        ):
            result = workspace_navigator.parse_monitors_with_names()
        assert result == {"1": "Built-in Retina Display", "2": "RG241Y"}


def make_aerospace_mock(focused_workspace, monitors, workspace_to_monitor):
    all_workspaces = sorted(workspace_to_monitor.keys())

    def mock_run_aerospace_command(*args):
        if args == ("list-workspaces", "--focused"):
            return str(focused_workspace)
        if args == ("list-workspaces", "--all"):
            return "\n".join(str(w) for w in all_workspaces)
        if args == ("list-monitors",):
            return "\n".join(
                f"{monitor_id} | {monitor_name}"
                for monitor_id, monitor_name in monitors.items()
            )
        if len(args) == 3 and args[0] == "list-workspaces" and args[1] == "--monitor":
            monitor_id = args[2]
            workspaces_on_monitor = [
                w for w, m in workspace_to_monitor.items() if m == monitor_id
            ]
            return "\n".join(str(w) for w in sorted(workspaces_on_monitor))
        return ""

    return mock_run_aerospace_command


SINGLE_MONITOR = {"1": "Built-in Retina Display"}
SINGLE_MONITOR_ALL_WORKSPACES = {w: "1" for w in range(1, 8)}

DUAL_MONITORS = {"1": "Built-in Retina Display", "2": "RG241Y"}
DUAL_MONITOR_WORKSPACES = {
    1: "1",
    2: "1",
    3: "1",
    4: "2",
    5: "1",
    6: "1",
    7: "1",
}


class TestSingleMonitorNavigation:
    def test_switches_to_next_workspace(self):
        mock = make_aerospace_mock(3, SINGLE_MONITOR, SINGLE_MONITOR_ALL_WORKSPACES)
        with (
            patch.object(
                workspace_navigator, "run_aerospace_command", side_effect=mock
            ) as mock_cmd,
            patch("sys.argv", ["workspace-navigate", "next"]),
        ):
            workspace_navigator.main()

        mock_cmd.assert_any_call("workspace", "4")

    def test_does_not_move_workspace_between_monitors(self):
        mock = make_aerospace_mock(3, SINGLE_MONITOR, SINGLE_MONITOR_ALL_WORKSPACES)
        with (
            patch.object(
                workspace_navigator, "run_aerospace_command", side_effect=mock
            ) as mock_cmd,
            patch("sys.argv", ["workspace-navigate", "next"]),
        ):
            workspace_navigator.main()

        for invocation in mock_cmd.call_args_list:
            assert invocation[0][0] != "move-workspace-to-monitor"


class TestMultiMonitorNavigation:
    def test_moves_workspace_from_other_monitor_to_focused(self):
        mock = make_aerospace_mock(4, DUAL_MONITORS, DUAL_MONITOR_WORKSPACES)
        with (
            patch.object(
                workspace_navigator, "run_aerospace_command", side_effect=mock
            ) as mock_cmd,
            patch("sys.argv", ["workspace-navigate", "next"]),
        ):
            workspace_navigator.main()

        mock_cmd.assert_any_call(
            "move-workspace-to-monitor", "--workspace", "5", "RG241Y"
        )
        mock_cmd.assert_any_call("workspace", "5")

    def test_skips_move_when_target_already_on_focused_monitor(self):
        mock = make_aerospace_mock(3, DUAL_MONITORS, DUAL_MONITOR_WORKSPACES)
        with (
            patch.object(
                workspace_navigator, "run_aerospace_command", side_effect=mock
            ) as mock_cmd,
            patch("sys.argv", ["workspace-navigate", "prev"]),
        ):
            workspace_navigator.main()

        for invocation in mock_cmd.call_args_list:
            assert invocation[0][0] != "move-workspace-to-monitor"
        mock_cmd.assert_any_call("workspace", "2")

    def test_wraps_around_and_moves_across_monitors(self):
        mock = make_aerospace_mock(7, DUAL_MONITORS, DUAL_MONITOR_WORKSPACES)
        with (
            patch.object(
                workspace_navigator, "run_aerospace_command", side_effect=mock
            ) as mock_cmd,
            patch("sys.argv", ["workspace-navigate", "next"]),
        ):
            workspace_navigator.main()

        mock_cmd.assert_any_call("workspace", "1")


class TestMoveWindowFlag:
    def test_moves_focused_window_when_flag_is_set(self):
        mock = make_aerospace_mock(3, SINGLE_MONITOR, SINGLE_MONITOR_ALL_WORKSPACES)
        with (
            patch.object(
                workspace_navigator, "run_aerospace_command", side_effect=mock
            ) as mock_cmd,
            patch("sys.argv", ["workspace-navigate", "next", "--move-window"]),
        ):
            workspace_navigator.main()

        mock_cmd.assert_any_call("move-node-to-workspace", "4")
        mock_cmd.assert_any_call("workspace", "4")

    def test_does_not_move_window_without_flag(self):
        mock = make_aerospace_mock(3, SINGLE_MONITOR, SINGLE_MONITOR_ALL_WORKSPACES)
        with (
            patch.object(
                workspace_navigator, "run_aerospace_command", side_effect=mock
            ) as mock_cmd,
            patch("sys.argv", ["workspace-navigate", "next"]),
        ):
            workspace_navigator.main()

        for invocation in mock_cmd.call_args_list:
            assert invocation[0][0] != "move-node-to-workspace"

    def test_moves_window_and_workspace_across_monitors(self):
        mock = make_aerospace_mock(4, DUAL_MONITORS, DUAL_MONITOR_WORKSPACES)
        with (
            patch.object(
                workspace_navigator, "run_aerospace_command", side_effect=mock
            ) as mock_cmd,
            patch("sys.argv", ["workspace-navigate", "prev", "--move-window"]),
        ):
            workspace_navigator.main()

        mock_cmd.assert_any_call(
            "move-workspace-to-monitor", "--workspace", "3", "RG241Y"
        )
        mock_cmd.assert_any_call("move-node-to-workspace", "3")
        mock_cmd.assert_any_call("workspace", "3")
