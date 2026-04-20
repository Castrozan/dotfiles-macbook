import subprocess
import sys


def run_aerospace_command(*arguments):
    result = subprocess.run(
        ["aerospace", *arguments],
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def get_focused_workspace_number():
    output = run_aerospace_command("list-workspaces", "--focused")
    return int(output)


def get_visible_workspace_numbers():
    output = run_aerospace_command("list-workspaces", "--monitor", "all", "--visible")
    return [int(line) for line in output.split("\n") if line.strip()]


def parse_monitors_with_names():
    output = run_aerospace_command("list-monitors")
    monitors = {}
    for line in output.split("\n"):
        if "|" in line:
            monitor_id, monitor_name = line.split("|", 1)
            monitors[monitor_id.strip()] = monitor_name.strip()
    return monitors


def find_monitor_name_containing_workspace(monitors, workspace_number):
    for monitor_id, monitor_name in monitors.items():
        workspaces_output = run_aerospace_command(
            "list-workspaces", "--monitor", monitor_id
        )
        workspace_numbers_on_monitor = [
            int(line) for line in workspaces_output.split("\n") if line.strip()
        ]
        if workspace_number in workspace_numbers_on_monitor:
            return monitor_name
    return None


def build_navigable_workspaces(total_workspaces, focused_workspace, visible_workspaces):
    all_workspaces = list(range(1, total_workspaces + 1))
    workspaces_visible_on_other_monitors = [
        workspace for workspace in visible_workspaces if workspace != focused_workspace
    ]
    return [
        workspace
        for workspace in all_workspaces
        if workspace not in workspaces_visible_on_other_monitors
    ]


def calculate_adjacent_workspace_with_wraparound(current, all_workspaces, direction):
    if current not in all_workspaces:
        if direction == "next":
            return all_workspaces[0]
        return all_workspaces[-1]
    current_index = all_workspaces.index(current)
    if direction == "next":
        adjacent_index = (current_index + 1) % len(all_workspaces)
    else:
        adjacent_index = (current_index - 1) % len(all_workspaces)
    return all_workspaces[adjacent_index]


def move_workspace_to_focused_monitor_if_needed(
    target_workspace, focused_monitor_name, monitors
):
    target_monitor_name = find_monitor_name_containing_workspace(
        monitors, target_workspace
    )
    if target_monitor_name is not None and target_monitor_name != focused_monitor_name:
        run_aerospace_command(
            "move-workspace-to-monitor",
            "--workspace",
            str(target_workspace),
            focused_monitor_name,
        )


def main():
    direction = sys.argv[1]
    total_workspaces = int(sys.argv[2])
    should_move_focused_window = "--move-window" in sys.argv

    focused_workspace = get_focused_workspace_number()
    visible_workspaces = get_visible_workspace_numbers()

    navigable_workspaces = build_navigable_workspaces(
        total_workspaces, focused_workspace, visible_workspaces
    )

    target_workspace = calculate_adjacent_workspace_with_wraparound(
        focused_workspace, navigable_workspaces, direction
    )

    monitors = parse_monitors_with_names()

    if len(monitors) > 1:
        focused_monitor_name = find_monitor_name_containing_workspace(
            monitors, focused_workspace
        )
        move_workspace_to_focused_monitor_if_needed(
            target_workspace, focused_monitor_name, monitors
        )

    if should_move_focused_window:
        run_aerospace_command("move-node-to-workspace", str(target_workspace))

    run_aerospace_command("workspace", str(target_workspace))


if __name__ == "__main__":
    main()
