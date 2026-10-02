#!/usr/bin/env python3
import argparse
import ctypes as ct
import datetime as dt
import fcntl
import json
import math
import os
import pwd
import re
import signal
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path

INTERVAL = 0.25
SCRIPT = Path(__file__).resolve()
UNIT = "gpuu.service"


class ProcessInfo(ct.Structure):
    # nvmlProcessInfo_t, used by the v3 process query entry points.
    _fields_ = [
        ("pid", ct.c_uint),
        ("memory", ct.c_ulonglong),
        ("gpu_instance", ct.c_uint),
        ("compute_instance", ct.c_uint),
    ]


class NVML:
    def __init__(self):
        self.lib = ct.CDLL("libnvidia-ml.so.1")
        self.lib.nvmlErrorString.restype = ct.c_char_p
        self.check(self.lib.nvmlInit_v2())
        try:
            count = ct.c_uint()
            self.check(self.lib.nvmlDeviceGetCount_v2(ct.byref(count)))
            self.devices = []
            for index in range(count.value):
                handle = ct.c_void_p()
                self.check(
                    self.lib.nvmlDeviceGetHandleByIndex_v2(index, ct.byref(handle)),
                )
                uuid, name = ct.create_string_buffer(96), ct.create_string_buffer(256)
                self.check(self.lib.nvmlDeviceGetUUID(handle, uuid, len(uuid)))
                self.check(self.lib.nvmlDeviceGetName(handle, name, len(name)))
                self.devices.append(
                    (handle, index, uuid.value.decode(), name.value.decode()),
                )
            if not self.devices:
                raise RuntimeError("No NVIDIA GPUs detected")
        except Exception:
            self.close()
            raise

    def check(self, result):
        if result:
            raise RuntimeError(self.lib.nvmlErrorString(result).decode())

    def close(self):
        self.lib.nvmlShutdown()

    def processes(self, handle, kind):
        query = getattr(self.lib, "nvmlDeviceGet%sRunningProcesses_v3" % kind)
        size = 32
        for _ in range(8):
            count = ct.c_uint(size)
            entries = (ProcessInfo * size)()
            result = query(handle, ct.byref(count), entries)
            if result == 7:  # NVML_ERROR_INSUFFICIENT_SIZE; process count changed.
                size = max(size * 2, count.value + 16)
                continue
            if result == 3 and kind == "Graphics":  # Unsupported graphics query.
                return []
            self.check(result)
            return list(entries[: count.value])
        raise RuntimeError("GPU process list kept changing; retrying")

    def sample(self):
        devices, identities = [], {}
        for handle, index, uuid, name in self.devices:
            processes = {}
            for kind in ("Compute", "Graphics"):
                for entry in self.processes(handle, kind):
                    if entry.pid not in identities:
                        identities[entry.pid] = process_identity(entry.pid)
                    process = processes.setdefault(
                        entry.pid,
                        dict(identities[entry.pid], pid=entry.pid, kinds=[]),
                    )
                    process["kinds"].append(kind.lower())
                    process["memory"] = None if entry.memory == 2**64 - 1 else entry.memory
            devices.append(
                dict(
                    index=index,
                    uuid=uuid,
                    name=name,
                    processes=list(processes.values()),
                ),
            )
        return devices


def process_identity(pid):
    """Capture owners while processes are alive; don't resolve an exited PID later."""
    try:
        with open("/proc/%s/stat" % pid) as handle:
            uid = os.fstat(handle.fileno()).st_uid
            text = handle.read()
        # comm can contain spaces or parentheses; split after its closing paren.
        name, fields = text[text.index("(") + 1 :].rsplit(")", 1)
        start_ticks = int(fields.split()[19])
        try:
            user = pwd.getpwuid(uid).pw_name
        except KeyError:
            user = str(uid)
        return dict(user=user, uid=uid, name=name, start_ticks=start_ticks)
    except (OSError, ValueError, IndexError):
        return dict(user="?", uid=None, name="?", start_ticks=None)


def cache_directory():
    root = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache")
    host = re.sub(r"[^a-zA-Z0-9_.-]", "_", socket.gethostname())
    directory = root / "gpuu" / host
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    return directory


def read_state(directory):
    try:
        with (directory / "state.json").open() as handle:
            state = json.load(handle)
        if state.get("version") != 1 or not isinstance(state.get("history"), dict):
            raise RuntimeError("Unrecognized GPU history format: %s" % directory)
        return state
    except FileNotFoundError:
        return dict(version=1, history={}, devices=[], collection_started=time.time())
    except (ValueError, AttributeError) as error:
        raise RuntimeError("Cannot read GPU history: %s" % error) from error


def write_state(directory, state):
    fd, temporary = tempfile.mkstemp(prefix="state-", dir=str(directory))
    try:
        with os.fdopen(fd, "w") as handle:
            json.dump(state, handle)
            handle.write("\n")
        os.replace(temporary, directory / "state.json")
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def collector_running(directory):
    with (directory / "collector.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return True
        return False


def record_sample(state, devices, timestamp):
    for device in devices:
        if device["processes"]:
            users = sorted({process["user"] for process in device["processes"]})
            state["history"][device["uuid"]] = dict(time=timestamp, users=users)
    state.update(devices=devices, updated=timestamp, error=None)


def collect(directory, factory=NVML):
    with (directory / "collector.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return 0
        state = read_state(directory)
        state.update(
            pid=os.getpid(),
            started=time.time(),
            interval=INTERVAL,
            stopped=False,
        )
        stopping = False

        def stop(signum, frame):
            nonlocal stopping
            stopping = True

        signal.signal(signal.SIGTERM, stop)
        signal.signal(signal.SIGINT, stop)
        monitor, last_write, previous = None, 0, None
        try:
            while not stopping:
                began = time.monotonic()
                try:
                    if monitor is None:
                        monitor = factory()
                    devices = monitor.sample()
                    record_sample(state, devices, time.time())
                    signature = [
                        (
                            d["uuid"],
                            [(p["pid"], p["start_ticks"], p["user"]) for p in d["processes"]],
                        )
                        for d in devices
                    ]
                    delay = INTERVAL
                except (OSError, RuntimeError, AttributeError) as error:
                    state["error"] = str(error)
                    signature, delay = str(error), 2
                    if monitor is not None:
                        monitor.close()
                        monitor = None
                state["heartbeat"] = time.time()
                # Persist transitions immediately, plus a heartbeat once per second.
                if signature != previous or began - last_write >= 1:
                    write_state(directory, state)
                    previous, last_write = signature, began
                time.sleep(max(0, delay - (time.monotonic() - began)))
        finally:
            if monitor is not None:
                monitor.close()
            state["stopped"] = True
            write_state(directory, state)
    return 0


def systemctl(*args):
    return subprocess.run(
        ["systemctl", "--user", *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=10,
    )


def unit_file():
    config = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    return config / "systemd" / "user" / UNIT


def managed_service_exists():
    target = unit_file()
    if not target.exists():
        return False
    if "# Managed by ,gpuu\n" not in target.read_text():
        raise RuntimeError("Unrelated service already exists: %s" % target)
    return True


def preflight():
    monitor = NVML()
    try:
        monitor.sample()
    finally:
        monitor.close()


def ensure_running(directory):
    if collector_running(directory):
        return
    preflight()  # Don't leave a failing daemon on machines without a GPU driver.
    managed = False
    if managed_service_exists():
        try:
            managed = systemctl("start", UNIT).returncode == 0
        except (OSError, subprocess.TimeoutExpired):
            pass
    if not managed:
        # Detached fallback survives closing the calling shell.
        with (directory / "collector.log").open("a") as log:
            subprocess.Popen(
                [sys.executable, str(SCRIPT), "--collect"],
                stdin=subprocess.DEVNULL,
                stdout=log,
                stderr=log,
                start_new_session=True,
                close_fds=True,
            )
    deadline = time.monotonic() + 6
    while time.monotonic() < deadline:
        state = read_state(directory)
        if collector_running(directory) and not state.get("stopped", True):
            if state.get("error"):
                raise RuntimeError("GPU collector: " + state["error"])
            if time.time() - state.get("updated", 0) < 3:
                return
        time.sleep(0.1)
    raise RuntimeError(
        "Collector did not start; see %s" % (directory / "collector.log"),
    )


def stop_collector(directory):
    if managed_service_exists():
        result = systemctl("stop", UNIT)
        if result.returncode:
            raise RuntimeError(result.stderr.strip())
    if not collector_running(directory):
        return
    state = read_state(directory)
    pid = state.get("pid")
    try:
        # Verify the PID before signaling a detached collector; PIDs are reusable.
        args = Path("/proc/%s/cmdline" % pid).read_bytes().split(b"\0")
        if str(SCRIPT).encode() not in args or b"--collect" not in args:
            raise RuntimeError("Collector PID could not be verified")
        os.kill(pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    deadline = time.monotonic() + 5
    while collector_running(directory) and time.monotonic() < deadline:
        time.sleep(0.1)
    if collector_running(directory):
        raise RuntimeError("Collector did not stop")


def install_service(directory):
    # Explicit --install enables collection again at future user logins.
    result = systemctl("show-environment")
    if result.returncode:
        raise RuntimeError("User service manager unavailable: " + result.stderr.strip())
    preflight()
    target = unit_file()
    managed_service_exists()

    def quote(value):
        return '"' + str(value).replace("\\", "\\\\").replace('"', '\\"').replace("%", "%%") + '"'

    stop_collector(directory)
    target.parent.mkdir(parents=True, exist_ok=True)
    cache_root = directory.parent.parent
    target.write_text(
        "# Managed by ,gpuu\n[Unit]\nDescription=GPU usage history for ,gpuu\n"
        "ConditionPathExists=/dev/nvidiactl\n\n"
        "[Service]\nType=simple\nExecStart=%s %s --collect\n"
        "Environment=%s\nRestart=on-failure\nRestartSec=5\nUMask=0077\n\n"
        "[Install]\nWantedBy=default.target\n"
        % (
            quote(sys.executable),
            quote(SCRIPT),
            quote("XDG_CACHE_HOME=" + str(cache_root)),
        ),
    )
    for args in (("daemon-reload",), ("enable", "--now", UNIT)):
        result = systemctl(*args)
        if result.returncode:
            raise RuntimeError(result.stderr.strip())
    ensure_running(directory)
    print("Installed user service: %s" % target)


def timestamp(value):
    return dt.datetime.fromtimestamp(value).astimezone().strftime("%Y-%m-%d %H:%M:%S %z")


def show(directory, status_only=False):
    state = read_state(directory)
    running = collector_running(directory)
    healthy = running and not state.get("error") and time.time() - state.get("heartbeat", 0) < 5
    print(
        "Collector: %s; history since %s"
        % (
            "running (250 ms samples)" if healthy else "stopped or unavailable",
            timestamp(state["collection_started"]),
        ),
    )
    if state.get("error"):
        print("GPU query error: " + state["error"])
    if not healthy and state.get("updated"):
        print(
            "Last successful snapshot: %s (current activity unknown)" % timestamp(state["updated"]),
        )
    if status_only:
        print("History: %s" % (directory / "state.json"))
        return
    for device in state["devices"]:
        processes = device["processes"]
        print("GPU %s (%s):" % (device["index"], device["name"]))
        if healthy and processes:
            users = ", ".join(sorted({process["user"] for process in processes}))
            print("  in use by %s" % users)
            for process in processes:
                memory = "?" if process["memory"] is None else str(process["memory"] // 2**20)
                print(
                    "  %-16s pid=%s  mem=%s MiB  %s"
                    % (process["user"], process["pid"], memory, process["name"]),
                )
        else:
            print("  %s" % ("idle" if healthy else "current activity unknown"))
        previous = state["history"].get(device["uuid"])
        if previous:
            print(
                "  last observed use: %s by %s"
                % (timestamp(previous["time"]), ", ".join(previous["users"])),
            )
        else:
            print("  no use recorded since collection began")


def positive_seconds(text):
    try:
        value = float(text)
    except ValueError:
        raise argparse.ArgumentTypeError("must be a positive number of seconds")
    if not math.isfinite(value) or value <= 0:
        raise argparse.ArgumentTypeError("must be a positive number of seconds")
    return value


def main():
    parser = argparse.ArgumentParser(
        prog=",gpuu",
        description="Show GPU users and last observed use; automatically start background collection.",
        epilog="History begins with collection. Sub-250 ms jobs can fall between samples. No administrator access required.",
    )
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument(
        "--start",
        action="store_true",
        help="start background collection",
    )
    modes.add_argument(
        "--stop",
        action="store_true",
        help="stop collection; retain history",
    )
    modes.add_argument(
        "--status",
        action="store_true",
        help="show collector status without starting it",
    )
    modes.add_argument(
        "--install",
        action="store_true",
        help="install and enable a user service for future logins",
    )
    modes.add_argument(
        "--watch",
        type=positive_seconds,
        metavar="SECONDS",
        help="refresh the report periodically",
    )
    modes.add_argument("--collect", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    directory = cache_directory()
    if args.collect:
        return collect(directory)
    if args.stop:
        stop_collector(directory)
        print("GPU collection stopped; history retained.")
        return 0
    if args.install:
        install_service(directory)
    if not args.status:
        ensure_running(directory)
    while True:
        show(directory, status_only=args.status or args.start or args.install)
        if args.watch is None:
            return 0
        print()
        time.sleep(args.watch)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(0)
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        print("Error: %s" % error, file=sys.stderr)
        sys.exit(1)
