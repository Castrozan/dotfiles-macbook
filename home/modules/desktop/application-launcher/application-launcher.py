#!/usr/bin/env python3

import json
import os
import shutil
import subprocess
import time
from pathlib import Path

APPLICATION_SEARCH_DIRECTORIES = [
    Path("/Applications"),
    Path("/Applications/Utilities"),
    Path("/System/Applications"),
    Path("/System/Applications/Utilities"),
    Path.home() / "Applications",
    Path.home() / "Applications" / "Home Manager Apps",
]

ADDITIONAL_PATH_DIRECTORIES = [
    Path.home() / ".nix-profile" / "bin",
    Path("/run/current-system/sw/bin"),
    Path("/etc/profiles/per-user") / os.environ.get("USER", "nobody") / "bin",
]

LAUNCH_HISTORY_FILE_PATH = (
    Path.home() / ".local" / "share" / "application-launcher" / "history.json"
)

FRECENCY_HALF_LIFE_DAYS = 7

RUNNING_APPLICATION_INDICATOR = "●"
NOT_RUNNING_APPLICATION_INDICATOR = " "

APPLESCRIPT_MAKE_NEW_WINDOW_APPLICATIONS = {
    "Brave Browser",
    "Google Chrome",
    "Safari",
    "Firefox",
}


def ensure_nix_packages_in_path():
    current_path = os.environ.get("PATH", "")
    additional_paths = ":".join(
        str(directory)
        for directory in ADDITIONAL_PATH_DIRECTORIES
        if directory.is_dir()
    )
    os.environ["PATH"] = f"{additional_paths}:{current_path}"


def discover_installed_applications():
    applications = set()
    for directory in APPLICATION_SEARCH_DIRECTORIES:
        if directory.is_dir():
            for entry in directory.iterdir():
                if entry.suffix == ".app":
                    applications.add(entry.stem)
    return sorted(applications)


def load_launch_history():
    if not LAUNCH_HISTORY_FILE_PATH.exists():
        return {}
    try:
        return json.loads(LAUNCH_HISTORY_FILE_PATH.read_text())
    except (json.JSONDecodeError, OSError):
        return {}


def save_launch_history(history):
    LAUNCH_HISTORY_FILE_PATH.parent.mkdir(parents=True, exist_ok=True)
    LAUNCH_HISTORY_FILE_PATH.write_text(json.dumps(history, indent=2))


def record_application_launch_in_history(history, application_name):
    now = time.time()
    entry = history.get(application_name, {"launch_count": 0, "last_launched_at": 0})
    entry["launch_count"] = entry["launch_count"] + 1
    entry["last_launched_at"] = now
    history[application_name] = entry
    save_launch_history(history)


def calculate_frecency_score(history_entry):
    days_since_last_launch = (
        time.time() - history_entry.get("last_launched_at", 0)
    ) / 86400
    recency_weight = 2 ** (-days_since_last_launch / FRECENCY_HALF_LIFE_DAYS)
    return history_entry.get("launch_count", 0) * recency_weight


def sort_applications_by_frecency(application_names, history):
    def frecency_sort_key(application_name):
        entry = history.get(application_name)
        if entry is None:
            return (1, application_name.lower())
        return (0, -calculate_frecency_score(entry))

    return sorted(application_names, key=frecency_sort_key)


def get_currently_running_application_names():
    result = subprocess.run(
        ["ps", "-eo", "comm"],
        capture_output=True,
        text=True,
        timeout=5,
    )
    if result.returncode != 0:
        return set()
    return {
        line.strip().split("/")[-1].replace(".app", "")
        for line in result.stdout.splitlines()
        if ".app/" in line
    }


def build_display_line_for_application(application_name, running_application_names):
    if application_name in running_application_names:
        return f"{RUNNING_APPLICATION_INDICATOR} {application_name}"
    return f"{NOT_RUNNING_APPLICATION_INDICATOR} {application_name}"


def start_chooser_process():
    return subprocess.Popen(
        ["choose"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )


def finish_chooser_with_display_lines(chooser_process, display_lines):
    chooser_input = "\n".join(display_lines)
    stdout, _ = chooser_process.communicate(input=chooser_input)
    selected = stdout.strip()
    if chooser_process.returncode != 0 or not selected:
        return None
    return selected


def extract_application_name_from_display_line(display_line):
    return display_line.lstrip(
        f"{RUNNING_APPLICATION_INDICATOR}{NOT_RUNNING_APPLICATION_INDICATOR} "
    )


def is_application_currently_running(application_name):
    result = subprocess.run(
        ["osascript", "-e", f'application "{application_name}" is running'],
        capture_output=True,
        text=True,
        timeout=5,
    )
    return result.stdout.strip() == "true"


def find_wezterm_binary():
    return shutil.which("wezterm")


def open_new_window_via_applescript(application_name):
    subprocess.run(
        [
            "osascript",
            "-e",
            f'tell application "{application_name}" to make new window',
        ],
        timeout=5,
    )


def open_new_window_via_keystroke(application_name):
    subprocess.run(
        [
            "osascript",
            "-e",
            f'tell application "{application_name}" to activate\n'
            f"delay 0.3\n"
            f'tell application "System Events"\n'
            f'    keystroke "n" using command down\n'
            f"end tell",
        ],
        timeout=5,
    )


def launch_application(application_name):
    subprocess.run(["open", "-a", application_name], timeout=5)


def open_application_with_new_window_if_running(application_name):
    if not is_application_currently_running(application_name):
        launch_application(application_name)
        return

    wezterm_binary = find_wezterm_binary()
    if application_name == "WezTerm" and wezterm_binary:
        subprocess.run([wezterm_binary, "start"], timeout=5)
        return

    if application_name in APPLESCRIPT_MAKE_NEW_WINDOW_APPLICATIONS:
        open_new_window_via_applescript(application_name)
        return

    open_new_window_via_keystroke(application_name)


def main():
    ensure_nix_packages_in_path()
    chooser_process = start_chooser_process()

    applications = discover_installed_applications()
    history = load_launch_history()
    sorted_applications = sort_applications_by_frecency(applications, history)
    running_applications = get_currently_running_application_names()

    display_lines = [
        build_display_line_for_application(app, running_applications)
        for app in sorted_applications
    ]
    display_line_to_application_name = dict(zip(display_lines, sorted_applications))

    selected_display_line = finish_chooser_with_display_lines(
        chooser_process, display_lines
    )
    if not selected_display_line:
        return

    selected_application = display_line_to_application_name.get(
        selected_display_line,
        extract_application_name_from_display_line(selected_display_line),
    )

    record_application_launch_in_history(history, selected_application)
    open_application_with_new_window_if_running(selected_application)


if __name__ == "__main__":
    main()
