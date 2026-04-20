import subprocess
import sys


def run_aerospace_command(*arguments):
    result = subprocess.run(
        ["aerospace", *arguments],
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def run_aerospace_json_command(*arguments):
    import json

    output = run_aerospace_command(*arguments, "--json")
    if not output:
        return []
    return json.loads(output)


def get_focused_workspace_name():
    return run_aerospace_command("list-workspaces", "--focused")


def find_first_window_by_application_name(application_name):
    all_windows = run_aerospace_json_command("list-windows", "--all")
    for window in all_windows:
        if window.get("app-name") == application_name:
            return window
    return None


def get_workspace_for_window(window_id):
    output = run_aerospace_command(
        "list-windows",
        "--all",
        "--format",
        "%{window-id} %{workspace}",
    )
    for line in output.split("\n"):
        if not line.strip():
            continue
        parts = line.strip().split(" ", 1)
        if parts[0] == str(window_id):
            return parts[1]
    return None


def launch_application(application_name):
    subprocess.Popen(["open", "-a", application_name])


def focus_window(window_id):
    run_aerospace_command("focus", "--window-id", str(window_id))


def move_window_to_workspace_and_focus(window_id, workspace_name):
    run_aerospace_command(
        "move-node-to-workspace",
        "--window-id",
        str(window_id),
        "--focus-follows-window",
        workspace_name,
    )


def summon_or_launch_browser(application_name):
    current_workspace = get_focused_workspace_name()
    window = find_first_window_by_application_name(application_name)

    if window is None:
        launch_application(application_name)
        return

    window_id = window["window-id"]
    window_workspace = get_workspace_for_window(window_id)

    if window_workspace == current_workspace:
        focus_window(window_id)
        return

    move_window_to_workspace_and_focus(window_id, current_workspace)


def main():
    if len(sys.argv) < 2:
        sys.exit(1)

    application_name = sys.argv[1]
    summon_or_launch_browser(application_name)


if __name__ == "__main__":
    main()
