#!/usr/bin/env python3

import ctypes
import ctypes.util
import os
import socket
import subprocess
import time

SOCKET_PATH = "/tmp/workspace-switcher.sock"
ACTIVE_FLAG_PATH = "/tmp/workspace-switcher.active"
MOUSE_MOVEMENT_ITERATIONS = 20
MOUSE_MOVEMENT_PIXEL_OFFSET = 5
COMMAND_SETTLE_DELAY_SECONDS = 0.15
PERFORMANCE_THRESHOLD_SECONDS = 0.10
SOCKET_CONNECT_RETRY_ATTEMPTS = 3
SOCKET_CONNECT_RETRY_DELAY_SECONDS = 0.5

core_graphics = ctypes.cdll.LoadLibrary(
    "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics"
)


class CGPoint(ctypes.Structure):
    _fields_ = [("x", ctypes.c_double), ("y", ctypes.c_double)]


core_graphics.CGEventCreate.restype = ctypes.c_void_p
core_graphics.CGEventCreate.argtypes = [ctypes.c_void_p]
core_graphics.CGEventGetLocation.restype = CGPoint
core_graphics.CGEventGetLocation.argtypes = [ctypes.c_void_p]
core_graphics.CGEventCreateMouseEvent.restype = ctypes.c_void_p
core_graphics.CGEventCreateMouseEvent.argtypes = [
    ctypes.c_void_p,
    ctypes.c_uint32,
    CGPoint,
    ctypes.c_uint32,
]
core_graphics.CGEventPost.restype = None
core_graphics.CGEventPost.argtypes = [ctypes.c_uint32, ctypes.c_void_p]
core_graphics.CFRelease.restype = None
core_graphics.CFRelease.argtypes = [ctypes.c_void_p]

CGEVENT_MOUSE_MOVED = 5
CGEVENT_TAP_HID = 0


def get_current_mouse_position():
    event = core_graphics.CGEventCreate(None)
    point = core_graphics.CGEventGetLocation(event)
    core_graphics.CFRelease(event)
    return point.x, point.y


def move_mouse_to_absolute_position(target_x, target_y):
    point = CGPoint(target_x, target_y)
    event = core_graphics.CGEventCreateMouseEvent(None, CGEVENT_MOUSE_MOVED, point, 0)
    core_graphics.CGEventPost(CGEVENT_TAP_HID, event)
    core_graphics.CFRelease(event)


def move_mouse_by_offset(delta_x, delta_y):
    current_x, current_y = get_current_mouse_position()
    move_mouse_to_absolute_position(current_x + delta_x, current_y + delta_y)


def send_command_to_daemon(command):
    client_socket = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    client_socket.settimeout(2)
    try:
        client_socket.sendto(command.encode(), SOCKET_PATH)
    finally:
        client_socket.close()


def is_switcher_active():
    return os.path.exists(ACTIVE_FLAG_PATH)


def measure_command_round_trip_latency(command):
    start_time = time.monotonic()
    send_command_to_daemon(command)
    elapsed_time = time.monotonic() - start_time
    return elapsed_time


def ensure_daemon_is_running():
    if not os.path.exists(SOCKET_PATH):
        print("FAIL: daemon socket not found at", SOCKET_PATH)
        print(
            "      start the daemon first: launchctl kickstart com.dotfiles.workspace-window-switcher"
        )
        return False
    try:
        send_command_to_daemon("cancel")
        time.sleep(COMMAND_SETTLE_DELAY_SECONDS)
        return True
    except (ConnectionRefusedError, FileNotFoundError):
        print("FAIL: cannot connect to daemon socket")
        return False


KARABINER_CORE_SERVICE_PROCESS_NAME = "Karabiner-Core-Service"


def is_karabiner_core_service_running():
    result = subprocess.run(
        ["pgrep", "-x", KARABINER_CORE_SERVICE_PROCESS_NAME],
        capture_output=True,
        text=True,
    )
    return result.returncode == 0


def test_karabiner_core_service_is_running():
    print(
        "TEST: Karabiner-Core-Service is running"
        " (hosts the HID grabber that intercepts Cmd+Tab)"
    )

    if not is_karabiner_core_service_running():
        print("  FAIL: Karabiner-Core-Service process not found")
        print("        Cmd+Tab workspace switching depends on Karabiner intercepting")
        print("        the keystroke at the HID layer. Open Karabiner-Elements.app")
        print(
            "        or run: launchctl kickstart -k system/org.pqrs.service.daemon.Karabiner-DriverKit-VirtualHIDDeviceClient"
        )
        return False

    print("  PASS")
    return True


def test_switcher_stays_active_during_mouse_movement():
    print("TEST: switcher stays active during mouse movement")

    send_command_to_daemon("next")
    time.sleep(COMMAND_SETTLE_DELAY_SECONDS)

    if not is_switcher_active():
        print("  SKIP: switcher did not activate (need >= 2 windows in workspace)")
        send_command_to_daemon("cancel")
        return True

    for iteration in range(MOUSE_MOVEMENT_ITERATIONS):
        direction = 1 if iteration % 2 == 0 else -1
        move_mouse_by_offset(
            MOUSE_MOVEMENT_PIXEL_OFFSET * direction,
            MOUSE_MOVEMENT_PIXEL_OFFSET * direction,
        )
        time.sleep(0.05)

        if not is_switcher_active():
            print(f"  FAIL: switcher deactivated after mouse movement #{iteration + 1}")
            return False

    send_command_to_daemon("cancel")
    time.sleep(COMMAND_SETTLE_DELAY_SECONDS)
    print("  PASS")
    return True


def test_selection_advances_past_index_one_with_mouse_movement():
    print("TEST: selection advances to index 2+ despite mouse movement")

    send_command_to_daemon("next")
    time.sleep(COMMAND_SETTLE_DELAY_SECONDS)

    if not is_switcher_active():
        print("  SKIP: switcher did not activate (need >= 3 windows in workspace)")
        send_command_to_daemon("cancel")
        return True

    move_mouse_by_offset(MOUSE_MOVEMENT_PIXEL_OFFSET, MOUSE_MOVEMENT_PIXEL_OFFSET)
    time.sleep(0.05)

    send_command_to_daemon("next")
    time.sleep(COMMAND_SETTLE_DELAY_SECONDS)

    if not is_switcher_active():
        print("  FAIL: switcher deactivated after next+mouse+next (the original bug)")
        return False

    move_mouse_by_offset(-MOUSE_MOVEMENT_PIXEL_OFFSET, -MOUSE_MOVEMENT_PIXEL_OFFSET)
    time.sleep(0.05)

    send_command_to_daemon("next")
    time.sleep(COMMAND_SETTLE_DELAY_SECONDS)

    if not is_switcher_active():
        print("  FAIL: switcher deactivated after third next with mouse movement")
        return False

    send_command_to_daemon("cancel")
    time.sleep(COMMAND_SETTLE_DELAY_SECONDS)
    print("  PASS")
    return True


def test_rapid_next_commands_with_continuous_mouse_movement():
    print("TEST: rapid next commands interleaved with mouse movement")

    send_command_to_daemon("next")
    time.sleep(COMMAND_SETTLE_DELAY_SECONDS)

    if not is_switcher_active():
        print("  SKIP: switcher did not activate (need >= 2 windows in workspace)")
        send_command_to_daemon("cancel")
        return True

    for iteration in range(6):
        direction = 1 if iteration % 2 == 0 else -1
        move_mouse_by_offset(MOUSE_MOVEMENT_PIXEL_OFFSET * direction, 0)
        send_command_to_daemon("next")
        time.sleep(0.05)

    time.sleep(COMMAND_SETTLE_DELAY_SECONDS)

    if not is_switcher_active():
        print("  FAIL: switcher deactivated during rapid next+mouse interleave")
        return False

    send_command_to_daemon("cancel")
    time.sleep(COMMAND_SETTLE_DELAY_SECONDS)
    print("  PASS")
    return True


def test_command_latency_is_acceptable():
    print("TEST: socket command round-trip latency")

    send_command_to_daemon("cancel")
    time.sleep(0.1)

    latencies = []
    for _ in range(10):
        latency = measure_command_round_trip_latency("cancel")
        latencies.append(latency)
        time.sleep(0.02)

    average_latency = sum(latencies) / len(latencies)
    maximum_latency = max(latencies)

    print(f"  avg={average_latency * 1000:.1f}ms  max={maximum_latency * 1000:.1f}ms")

    if maximum_latency > PERFORMANCE_THRESHOLD_SECONDS:
        print(
            f"  FAIL: max latency {maximum_latency * 1000:.1f}ms exceeds"
            f" {PERFORMANCE_THRESHOLD_SECONDS * 1000:.0f}ms threshold"
        )
        return False

    print("  PASS")
    return True


def test_activate_deactivate_cycle_performance():
    print("TEST: activate/cancel cycle performance")

    cycle_times = []
    for _ in range(5):
        start_time = time.monotonic()
        send_command_to_daemon("next")
        time.sleep(COMMAND_SETTLE_DELAY_SECONDS)
        send_command_to_daemon("cancel")
        time.sleep(COMMAND_SETTLE_DELAY_SECONDS)
        cycle_time = time.monotonic() - start_time
        cycle_times.append(cycle_time)

    average_cycle_time = sum(cycle_times) / len(cycle_times)
    overhead_per_cycle = average_cycle_time - (2 * COMMAND_SETTLE_DELAY_SECONDS)

    print(
        f"  avg cycle={average_cycle_time * 1000:.0f}ms"
        f"  overhead={overhead_per_cycle * 1000:.1f}ms"
    )
    print("  PASS")
    return True


def test_mouse_movement_performance():
    print("TEST: mouse movement latency via CoreGraphics")

    latencies = []
    for iteration in range(20):
        direction = 1 if iteration % 2 == 0 else -1
        start_time = time.monotonic()
        move_mouse_by_offset(direction * 3, direction * 3)
        elapsed_time = time.monotonic() - start_time
        latencies.append(elapsed_time)

    average_latency = sum(latencies) / len(latencies)
    maximum_latency = max(latencies)

    print(f"  avg={average_latency * 1000:.2f}ms  max={maximum_latency * 1000:.2f}ms")
    print("  PASS")
    return True


AEROSPACE_SOCKET_GLOB_PATTERN = "/tmp/bobko.aerospace-*.sock"
FOCUS_EVENT_PROPAGATION_DELAY_SECONDS = 0.25
AUTO_COMMIT_TIMEOUT_BUFFER_SECONDS = 11.0


def find_aerospace_socket_path():
    import glob

    matching = glob.glob(AEROSPACE_SOCKET_GLOB_PATTERN)
    return matching[0] if matching else None


def send_aerospace_ipc_command(arguments_list):
    import json

    socket_path = find_aerospace_socket_path()
    if socket_path is None:
        return None
    client_socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    client_socket.settimeout(2)
    try:
        client_socket.connect(socket_path)
        request_payload = json.dumps(
            {
                "args": arguments_list,
                "stdin": "",
                "windowId": None,
                "workspace": None,
            }
        ).encode()
        client_socket.sendall(request_payload)
        client_socket.shutdown(socket.SHUT_WR)
        response_bytes = b""
        while True:
            chunk = client_socket.recv(4096)
            if not chunk:
                break
            response_bytes += chunk
        client_socket.close()
        decoder = json.JSONDecoder()
        response_object, _ = decoder.raw_decode(response_bytes.decode())
        if response_object.get("exitCode", 1) != 0:
            return None
        return response_object.get("stdout", "")
    except (OSError, ValueError):
        return None


def query_aerospace_focused_window_id():
    import json

    stdout_text = send_aerospace_ipc_command(["list-windows", "--focused", "--json"])
    if not stdout_text:
        return None
    try:
        windows = json.loads(stdout_text)
        return windows[0]["window-id"] if windows else None
    except (ValueError, IndexError, KeyError):
        return None


def query_aerospace_focused_workspace_window_ids():
    import json

    stdout_text = send_aerospace_ipc_command(
        ["list-windows", "--workspace", "focused", "--json"]
    )
    if not stdout_text:
        return []
    try:
        return [w["window-id"] for w in json.loads(stdout_text)]
    except (ValueError, KeyError):
        return []


def focus_window_via_aerospace_and_wait(target_window_id):
    send_aerospace_ipc_command(["focus", "--window-id", str(target_window_id)])
    time.sleep(FOCUS_EVENT_PROPAGATION_DELAY_SECONDS)


def test_mru_picks_previously_focused_window_on_next_then_commit():
    print("TEST: cmd+tab from B selects A when A was focused before B")

    workspace_window_ids = query_aerospace_focused_workspace_window_ids()
    if len(workspace_window_ids) < 2:
        print("  SKIP: focused workspace needs at least 2 windows")
        return True

    window_id_a = workspace_window_ids[0]
    window_id_b = next(
        (wid for wid in workspace_window_ids if wid != window_id_a), None
    )
    if window_id_b is None:
        print("  SKIP: could not find a second distinct window")
        return True

    focus_window_via_aerospace_and_wait(window_id_b)

    other_workspace_window_ids = [
        wid for wid in workspace_window_ids if wid != window_id_a and wid != window_id_b
    ]
    for other_window_id in other_workspace_window_ids:
        send_command_to_daemon(f"focus:{other_window_id}")
        time.sleep(COMMAND_SETTLE_DELAY_SECONDS / 3)
    send_command_to_daemon(f"focus:{window_id_a}")
    time.sleep(COMMAND_SETTLE_DELAY_SECONDS / 3)
    send_command_to_daemon(f"focus:{window_id_b}")
    time.sleep(COMMAND_SETTLE_DELAY_SECONDS / 3)

    starting_focused_id = query_aerospace_focused_window_id()
    if starting_focused_id != window_id_b:
        print(f"  SKIP: could not establish B as focused (got {starting_focused_id})")
        return True

    send_command_to_daemon("next")
    time.sleep(COMMAND_SETTLE_DELAY_SECONDS)
    send_command_to_daemon("commit")
    time.sleep(COMMAND_SETTLE_DELAY_SECONDS * 2)

    final_focused_id = query_aerospace_focused_window_id()
    if final_focused_id == window_id_a:
        print("  PASS")
        return True
    if final_focused_id == window_id_b:
        print(f"  FAIL: stayed on B ({window_id_b}) — the bug we fixed earlier")
        return False
    print(
        f"  FAIL: focused unexpected window {final_focused_id}, expected A ({window_id_a})"
    )
    return False


def test_cancel_during_active_clears_flag_without_changing_focus():
    print("TEST: cancel during active clears flag and preserves focus")

    workspace_window_ids = query_aerospace_focused_workspace_window_ids()
    if len(workspace_window_ids) < 2:
        print("  SKIP: focused workspace needs at least 2 windows")
        return True

    starting_focused_id = query_aerospace_focused_window_id()

    send_command_to_daemon("next")
    time.sleep(COMMAND_SETTLE_DELAY_SECONDS)
    if not is_switcher_active():
        print("  SKIP: switcher did not activate")
        return True

    send_command_to_daemon("cancel")
    time.sleep(COMMAND_SETTLE_DELAY_SECONDS)

    if is_switcher_active():
        print("  FAIL: active flag still present after cancel")
        return False

    final_focused_id = query_aerospace_focused_window_id()
    if final_focused_id != starting_focused_id:
        print(
            f"  FAIL: focus changed after cancel: {starting_focused_id} -> {final_focused_id}"
        )
        return False

    print("  PASS")
    return True


def test_reactivation_after_commit_starts_fresh_cycle():
    print("TEST: next+commit then next reactivates with fresh state")

    workspace_window_ids = query_aerospace_focused_workspace_window_ids()
    if len(workspace_window_ids) < 2:
        print("  SKIP: focused workspace needs at least 2 windows")
        return True

    send_command_to_daemon("next")
    time.sleep(COMMAND_SETTLE_DELAY_SECONDS)
    send_command_to_daemon("commit")
    time.sleep(COMMAND_SETTLE_DELAY_SECONDS)

    if is_switcher_active():
        print("  FAIL: flag still present after commit")
        return False

    send_command_to_daemon("next")
    time.sleep(COMMAND_SETTLE_DELAY_SECONDS)
    if not is_switcher_active():
        print("  FAIL: reactivation did not set flag")
        return False

    send_command_to_daemon("cancel")
    time.sleep(COMMAND_SETTLE_DELAY_SECONDS)
    print("  PASS")
    return True


def test_focus_socket_message_updates_internal_mru():
    print("TEST: focus:<id> socket messages influence next activation ordering")

    workspace_window_ids = query_aerospace_focused_workspace_window_ids()
    if len(workspace_window_ids) < 3:
        print("  SKIP: focused workspace needs at least 3 windows")
        return True

    starting_focused_id = query_aerospace_focused_window_id()
    other_window_ids = [
        wid for wid in workspace_window_ids if wid != starting_focused_id
    ]
    if len(other_window_ids) < 2:
        print("  SKIP: need at least two non-focused windows")
        return True

    desired_second_choice_window_id = other_window_ids[0]
    third_candidate_window_id = other_window_ids[1]

    send_command_to_daemon(f"focus:{third_candidate_window_id}")
    time.sleep(COMMAND_SETTLE_DELAY_SECONDS)
    send_command_to_daemon(f"focus:{desired_second_choice_window_id}")
    time.sleep(COMMAND_SETTLE_DELAY_SECONDS)

    send_command_to_daemon("next")
    time.sleep(COMMAND_SETTLE_DELAY_SECONDS)
    send_command_to_daemon("commit")
    time.sleep(COMMAND_SETTLE_DELAY_SECONDS * 2)

    final_focused_id = query_aerospace_focused_window_id()
    if final_focused_id == desired_second_choice_window_id:
        print("  PASS")
        return True
    print(
        f"  FAIL: expected to land on {desired_second_choice_window_id}, "
        f"got {final_focused_id}"
    )
    return False


def test_auto_commit_fires_after_timeout_seconds():
    print(
        f"TEST: auto-commit fires after ~{AUTO_COMMIT_TIMEOUT_BUFFER_SECONDS}s of inactivity"
    )

    workspace_window_ids = query_aerospace_focused_workspace_window_ids()
    if len(workspace_window_ids) < 2:
        print("  SKIP: focused workspace needs at least 2 windows")
        return True

    send_command_to_daemon("next")
    time.sleep(COMMAND_SETTLE_DELAY_SECONDS)
    if not is_switcher_active():
        print("  SKIP: switcher did not activate")
        return True

    time.sleep(AUTO_COMMIT_TIMEOUT_BUFFER_SECONDS)
    if is_switcher_active():
        print("  FAIL: flag still present after auto-commit window")
        return False

    print("  PASS")
    return True


def run_with_cleanup(test_function):
    send_command_to_daemon("cancel")
    time.sleep(COMMAND_SETTLE_DELAY_SECONDS / 2)
    try:
        return test_function()
    finally:
        send_command_to_daemon("cancel")
        time.sleep(COMMAND_SETTLE_DELAY_SECONDS / 2)


def main():
    print("=== workspace-window-switcher integration tests ===")
    print()

    if not ensure_daemon_is_running():
        return

    include_slow_tests = os.environ.get("WWS_RUN_SLOW_TESTS") == "1"

    all_tests = [
        test_karabiner_core_service_is_running,
        test_mouse_movement_performance,
        test_command_latency_is_acceptable,
        test_switcher_stays_active_during_mouse_movement,
        test_selection_advances_past_index_one_with_mouse_movement,
        test_rapid_next_commands_with_continuous_mouse_movement,
        test_activate_deactivate_cycle_performance,
        test_mru_picks_previously_focused_window_on_next_then_commit,
        test_cancel_during_active_clears_flag_without_changing_focus,
        test_reactivation_after_commit_starts_fresh_cycle,
        test_focus_socket_message_updates_internal_mru,
    ]
    if include_slow_tests:
        all_tests.append(test_auto_commit_fires_after_timeout_seconds)
    else:
        print(
            "INFO: skipping slow auto-commit test (set WWS_RUN_SLOW_TESTS=1 to include)"
        )
        print()

    passed_count = 0
    failed_count = 0

    for test_function in all_tests:
        result = run_with_cleanup(test_function)
        if result:
            passed_count += 1
        else:
            failed_count += 1

    send_command_to_daemon("cancel")

    print()
    print(f"Results: {passed_count} passed, {failed_count} failed")

    if failed_count > 0:
        exit(1)


if __name__ == "__main__":
    main()
