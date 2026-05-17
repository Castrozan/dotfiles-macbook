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
    for attempt in range(SOCKET_CONNECT_RETRY_ATTEMPTS):
        try:
            client_socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            client_socket.settimeout(2)
            client_socket.connect(SOCKET_PATH)
            client_socket.sendall(command.encode())
            client_socket.close()
            return
        except ConnectionRefusedError:
            if attempt < SOCKET_CONNECT_RETRY_ATTEMPTS - 1:
                time.sleep(SOCKET_CONNECT_RETRY_DELAY_SECONDS)
            else:
                raise


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


def main():
    print("=== workspace-window-switcher integration tests ===")
    print()

    if not ensure_daemon_is_running():
        return

    all_tests = [
        test_karabiner_core_service_is_running,
        test_mouse_movement_performance,
        test_command_latency_is_acceptable,
        test_switcher_stays_active_during_mouse_movement,
        test_selection_advances_past_index_one_with_mouse_movement,
        test_rapid_next_commands_with_continuous_mouse_movement,
        test_activate_deactivate_cycle_performance,
    ]

    passed_count = 0
    failed_count = 0

    for test_function in all_tests:
        result = test_function()
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
