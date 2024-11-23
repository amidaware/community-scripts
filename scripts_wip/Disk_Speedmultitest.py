#!/usr/bin/python3

# v1.0 8/28/2024 silversword411 Testing drives for read speed
# v1.1 8/28/2024 silversword411 Fixing sporadic problems, added Linux support, adding error when below 200MB/s

import ctypes
import time
import sys
import platform
import os
import subprocess

GENERIC_READ = 0x80000000
OPEN_EXISTING = 3
FILE_SHARE_READ = 1
FILE_SHARE_WRITE = 2
FILE_SHARE_DELETE = 4

warnbelowspeed = 200  # MB/s


def get_drive_size_windows(drive_path, retries=5):
    for attempt in range(retries):
        try:
            handle = ctypes.windll.kernel32.CreateFileW(
                drive_path,
                GENERIC_READ,
                FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                None,
                OPEN_EXISTING,
                0,
                None,
            )
            if handle == -1:
                raise ctypes.WinError()

            size = ctypes.c_ulonglong()
            ctypes.windll.kernel32.GetDiskFreeSpaceExW(
                drive_path, None, ctypes.byref(size), None
            )
            ctypes.windll.kernel32.CloseHandle(handle)
            return size.value
        except PermissionError:
            if attempt < retries - 1:
                print(
                    f"Retrying to access the drive... (Attempt {attempt + 1}/{retries})"
                )
                time.sleep(1)
            else:
                raise


def get_drive_size_linux(drive_path):
    with open(drive_path, "rb") as f:
        f.seek(0, os.SEEK_END)
        return f.tell()


def detect_linux_drive():
    try:
        result = subprocess.run(
            ["lsblk", "-dpno", "NAME,TYPE"], stdout=subprocess.PIPE, text=True
        )
        drives = [
            line.split()[0] for line in result.stdout.splitlines() if "disk" in line
        ]
        return drives[0] if drives else None
    except Exception as e:
        print(f"Error detecting drive: {e}")
        sys.exit(1)


def read_speed_test_windows(drive_path, offset, length):
    handle = ctypes.windll.kernel32.CreateFileW(
        drive_path,
        GENERIC_READ,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
        None,
        OPEN_EXISTING,
        0,
        None,
    )
    if handle == -1:
        raise ctypes.WinError()

    high_offset = ctypes.c_long(offset >> 32)
    low_offset = ctypes.c_long(offset & 0xFFFFFFFF)
    ctypes.windll.kernel32.SetFilePointer(
        handle, low_offset, ctypes.byref(high_offset), 0
    )

    buffer = ctypes.create_string_buffer(length)
    bytes_read = ctypes.c_ulong(0)

    start_time = time.time()
    success = ctypes.windll.kernel32.ReadFile(
        handle, buffer, length, ctypes.byref(bytes_read), None
    )
    end_time = time.time()

    ctypes.windll.kernel32.CloseHandle(handle)

    if not success:
        raise ctypes.WinError()

    read_time = end_time - start_time
    read_speed = bytes_read.value / read_time
    return read_speed


def read_speed_test_linux(drive_path, offset, length):
    with open(drive_path, "rb") as f:
        f.seek(offset)
        start_time = time.time()
        buffer = f.read(length)
        end_time = time.time()

    read_time = end_time - start_time
    read_speed = len(buffer) / read_time
    return read_speed


def check_speed_difference(speed1, speed2):
    difference = abs(speed1 - speed2) / ((speed1 + speed2) / 2) * 100
    return difference


def main():
    if platform.system() == "Windows":
        drive_path = r"\\.\PhysicalDrive0"
        drive_size = get_drive_size_windows(drive_path)
        read_speed_test = read_speed_test_windows
    elif platform.system() == "Linux":
        drive_path = detect_linux_drive()
        if not drive_path:
            print("No suitable drive found on the system.")
            sys.exit(1)
        drive_size = get_drive_size_linux(drive_path)
        read_speed_test = read_speed_test_linux
    else:
        print("Unsupported OS")
        sys.exit(1)

    read_length = 500 * 1024 * 1024  # 500 MB

    front_offset = 0
    middle_offset = drive_size // 2
    back_offset = drive_size - read_length

    front_speed = read_speed_test(drive_path, front_offset, read_length) / (1024 * 1024)
    middle_speed = read_speed_test(drive_path, middle_offset, read_length) / (
        1024 * 1024
    )
    back_speed = read_speed_test(drive_path, back_offset, read_length) / (1024 * 1024)

    print(f"Front read speed: {front_speed:.2f} MB/s")
    print(f"Middle read speed: {middle_speed:.2f} MB/s")
    print(f"Back read speed: {back_speed:.2f} MB/s")

    # Flag to track if any condition for exit is met
    error_detected = False

    # Check if any speed is below the warning threshold
    if (
        front_speed < warnbelowspeed
        or middle_speed < warnbelowspeed
        or back_speed < warnbelowspeed
    ):
        print(f"Error: One or more read speeds are below {warnbelowspeed} MB/s.")
        error_detected = True

    # Check if speed differences exceed 20%
    if (
        check_speed_difference(front_speed, middle_speed) > 20
        or check_speed_difference(middle_speed, back_speed) > 20
        or check_speed_difference(front_speed, back_speed) > 20
    ):
        print("Error: Read speeds differ by more than 20%.")
        error_detected = True

    # Exit with error if any condition is met
    if error_detected:
        sys.exit(1)


if __name__ == "__main__":
    main()
