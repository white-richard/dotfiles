#!/usr/bin/env python3
import argparse
import os
import pwd
import re
import shutil
import socket
import subprocess
import sys
import time

INTERVAL = 1.0
MIN_UID = 1000  # Below this are root and system daemons.
NOBODY_UID = 65534
MIN_CORES = 0.5  # Users under both thresholds aren't "intensive" and are hidden.
MIN_RAM = 2**30
TICKS = os.sysconf("SC_CLK_TCK")
PAGE_SIZE = os.sysconf("SC_PAGE_SIZE")
CGROUP_ROOT = "/sys/fs/cgroup"
MAX_TASKS = 3  # Tasks listed per user, unless a user is named.
SMALL_TASK_RAM = 50 * 2**20  # Idle tasks under this are only counted when a user is named.
INTERPRETERS = ("python", "java", "node", "bash", "sh", "perl", "ruby")

# What counts as a problem. Each check only reports; nothing here acts on a process.
IDLE_NOW = 0.05  # Cores in the sample window.
IDLE_AVG = 0.02  # Cores averaged over a process's lifetime.
MIN_AGE = 600  # Younger processes may just be starting up.
ORPHAN_COUNT = 5
SWARM_COUNT = 64
ZOMBIE_COUNT = 10
SLURM_IDLE_FRACTION = 0.1
SLURM_IDLE_MIN_CPUS = 4
SLURM_IDLE_MIN_AGE = 3600
OUTSIDE_SLURM_FRACTION = 1 / 8
RAM_HOG_FRACTION = 0.5
LOW_RAM_FRACTION = 0.1
GPU_IDLE_UTIL = 5
DISK_LIMITS = (("/tmp", 0.9), ("/dev/shm", 0.5))


def read_processes():
    """Return {(pid, start_ticks): process}; start_ticks guards against PID reuse."""
    processes = {}
    for entry in os.listdir("/proc"):
        if not entry.isdigit() or int(entry) == os.getpid():
            continue
        try:
            with open("/proc/%s/stat" % entry) as handle:
                uid = os.fstat(handle.fileno()).st_uid
                text = handle.read()
            with open("/proc/%s/statm" % entry) as handle:
                statm = handle.read().split()
            # comm can contain spaces or parentheses; split after its closing paren.
            name, fields = text[text.index("(") + 1 :].rsplit(")", 1)
            fields = fields.split()
            processes[(int(entry), fields[19])] = dict(
                pid=int(entry),
                uid=uid,
                name=name,
                state=fields[0],
                ppid=int(fields[1]),
                start=int(fields[19]),
                ticks=int(fields[11]) + int(fields[12]),
                # Private pages only; full RSS includes libraries and file mappings.
                rss=(int(statm[1]) - int(statm[2])) * PAGE_SIZE,
            )
        except (OSError, ValueError, IndexError):
            continue  # Exited while being read.
    return processes


def boot_time():
    with open("/proc/stat") as handle:
        for line in handle:
            if line.startswith("btime "):
                return int(line.split()[1])
    raise OSError("btime missing from /proc/stat")


def sample(interval):
    """Measure current CPU over an interval; ps %CPU is a lifetime average."""
    before = read_processes()
    began = time.monotonic()
    time.sleep(interval)
    after = read_processes()
    elapsed = time.monotonic() - began
    now, booted = time.time(), boot_time()
    for key, process in after.items():
        # A process that started mid-sample accrued all of its ticks in the window.
        previous = before[key]["ticks"] if key in before else 0
        process["cores"] = (process["ticks"] - previous) / TICKS / elapsed
        process["age"] = max(now - booted - process["start"] / TICKS, 1.0)
        process["avg"] = process["ticks"] / TICKS / process["age"]
        # A single D reading is normal I/O; two a second apart looks stuck.
        process["stuck"] = process["state"] == "D" and key in before and before[key]["state"] == "D"
        process["group"] = memory_group(process["pid"])
        match = re.search(r"/job_(\d+)", process["group"] or "")
        process["job"] = match.group(1) if match else None
        process["short"] = short_command(process)
        process["gpus"] = {}
    return list(after.values())


def short_command(process):
    """Name a process by what it runs, so two python scripts stay distinct."""
    name = process["name"]
    if not name.startswith(INTERPRETERS):
        return name
    try:
        with open("/proc/%d/cmdline" % process["pid"], "rb") as handle:
            args = handle.read().decode(errors="replace").split("\0")[1:]
    except OSError:
        return name
    skip = False
    for index, arg in enumerate(args):
        if skip:
            skip = False
        elif arg == "-m" and index + 1 < len(args):
            return "%s -m %s" % (name, args[index + 1])
        elif arg in ("-cp", "-classpath"):
            skip = True
        elif arg and not arg.startswith("-"):
            return "%s %s" % (name, os.path.basename(arg)[:40])
    return name


def username(uid):
    try:
        return pwd.getpwuid(uid).pw_name
    except KeyError:
        return str(uid)


def memory_group(pid):
    """Return the login session or Slurm job cgroup holding a process, if any."""
    try:
        with open("/proc/%d/cgroup" % pid) as handle:
            path = handle.read().splitlines()[0].split("::", 1)[1]
    except (OSError, IndexError):
        return None
    parts = path.split("/")
    for index, part in enumerate(parts):
        if part.startswith("job_") or (part.startswith("user-") and part.endswith(".slice")):
            return CGROUP_ROOT + "/".join(parts[: index + 1])
    return None


def group_memory(group):
    """Return a cgroup's anonymous and shared memory, or None if unreadable."""
    try:
        with open(group + "/memory.stat") as handle:
            stat = dict(line.split() for line in handle)
        return int(stat["anon"]) + int(stat["shmem"])
    except (OSError, ValueError, KeyError):
        return None


def group_cpu_seconds(group):
    """Return a cgroup's total CPU time, or None if unreadable."""
    try:
        with open(group + "/cpu.stat") as handle:
            stat = dict(line.split() for line in handle)
        return int(stat["usage_usec"]) / 1e6
    except (OSError, ValueError, KeyError):
        return None


def new_user():
    return dict(cores=0.0, rss=0, count=0, processes=[], jobs=[], groups={}, on_for=None, oldest=None)


def is_tracked(process):
    return process["uid"] >= MIN_UID and process["uid"] != NOBODY_UID


def find_attached(processes):
    """Return PIDs belonging to a real session, not background services.

    Walk up to each process's top ancestor: a root-owned top is a login daemon such
    as sshd or slurmstepd; tmux and screen hold sessions open across logins.
    """
    by_pid = {process["pid"]: process for process in processes}
    attached = set()
    for process in processes:
        top = process
        while top["ppid"] in by_pid and by_pid[top["ppid"]]["ppid"] != 0:
            top = by_pid[top["ppid"]]
        parent = by_pid.get(top["ppid"])
        if parent and parent["name"] == "systemd" and parent["uid"] != 0:
            continue  # Started by systemd --user, whose own parent is init.
        if process["job"] or top["uid"] == 0 or top["name"].lower().startswith(("tmux", "screen")):
            attached.add(process["pid"])
    return attached


def by_user(processes, attached):
    users = {}
    for process in processes:
        if not is_tracked(process):
            continue
        user = users.setdefault(username(process["uid"]), new_user())
        user["cores"] += process["cores"]
        group = process["group"]
        user["groups"][group] = user["groups"].get(group, 0) + process["rss"]
        user["count"] += 1
        user["processes"].append(process)
        user["oldest"] = max(user["oldest"] or 0, process["age"])
        if process["pid"] in attached:
            user["on_for"] = max(user["on_for"] or 0, process["age"])
    # Forked processes map the same pages, so per-process totals can exceed the
    # node's RAM. Cgroups count each page once; sum processes only as a fallback.
    for user in users.values():
        for group, summed in user["groups"].items():
            measured = group_memory(group) if group else None
            user["rss"] += summed if measured is None else measured
    return users


def parse_slurm_time(text):
    """Convert Slurm's [days-]hours:minutes:seconds to seconds, or None."""
    match = re.fullmatch(r"(?:(\d+)-)?(?:(\d+):)?(\d+):(\d+)", text)
    if not match:
        return None  # UNLIMITED, INVALID, NOT_SET.
    days, hours, minutes, seconds = (int(value or 0) for value in match.groups())
    return days * 86400 + hours * 3600 + minutes * 60 + seconds


def run_query(*command):
    """Return a command's output lines, or None if it's unavailable."""
    try:
        result = subprocess.run(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=5,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    return None if result.returncode else result.stdout.splitlines()


def slurm_jobs(processes):
    """Return running jobs on this node, or None without Slurm."""
    node = socket.gethostname().split(".")[0]
    lines = run_query("squeue", "-h", "-t", "R", "-w", node, "-o", "%A|%u|%C|%D|%M|%L|%j")
    if lines is None:
        return None
    groups = {process["job"]: process["group"] for process in processes if process["job"]}
    jobs = []
    for line in lines:
        job, user, cpus, nodes, used, left, name = line.split("|", 6)
        elapsed = parse_slurm_time(used)
        seconds = group_cpu_seconds(groups[job]) if job in groups else None
        jobs.append(
            dict(
                id=job,
                user=user,
                # %C spans the whole job; assume an even split across its nodes.
                cpus=int(cpus) // int(nodes),
                elapsed=elapsed,
                left=parse_slurm_time(left),
                name=name,
                cores=sum(p["cores"] for p in processes if p["job"] == job),
                avg=seconds / elapsed if seconds is not None and elapsed else None,
            ),
        )
    return jobs


def slurm_cluster():
    """Return (allocated, idle, unavailable, total, pending), or None without Slurm."""
    totals = run_query("sinfo", "-h", "-o", "%C")
    pending = run_query("squeue", "-h", "-t", "PD", "-o", "%A")
    if not totals or pending is None:
        return None
    return tuple(int(value) for value in totals[0].split("/")) + (len(pending),)


def gpu_status():
    """Return (utilization by GPU UUID, {uuid: index}, compute apps); empty without GPUs."""
    gpus = run_query(
        "nvidia-smi",
        "--query-gpu=index,uuid,utilization.gpu",
        "--format=csv,noheader,nounits",
    )
    apps = run_query(
        "nvidia-smi",
        "--query-compute-apps=gpu_uuid,pid,used_memory",
        "--format=csv,noheader,nounits",
    )
    util, indices, held = {}, {}, []
    for line in gpus or []:
        index, uuid, used = line.split(", ")
        indices[uuid] = index
        util[uuid] = int(used) if used.isdigit() else None
    for line in apps or []:
        uuid, pid, memory = line.split(", ")
        if pid.isdigit() and memory.isdigit():
            held.append((uuid, int(pid), int(memory) * 2**20))
    return util, indices, held


def find_orphans(processes):
    """Return {pid: process} whose owner is gone: reparented to init or systemd --user.

    Pool workers of an orphaned server count too, even while it's still their parent.
    """
    by_pid = {process["pid"]: process for process in processes}

    def is_orphan(process):
        while True:
            parent = by_pid.get(process["ppid"])
            if process["ppid"] == 1 or (parent and parent["name"] == "systemd"):
                return True
            if not parent or parent["name"] != process["name"]:
                return False
            process = parent

    # Slurm cleans up its own job cgroups, so desktop daemons there aren't leaks.
    return {
        process["pid"]: process
        for process in processes
        if is_tracked(process) and not process["job"] and process["state"] != "Z" and is_orphan(process)
    }


def is_idle(process):
    return process["cores"] < IDLE_NOW and process["avg"] < IDLE_AVG and process["age"] >= MIN_AGE


def leaked_groups(orphans):
    """Group idle orphans; many of one command, or a lot of RAM, is a leak, not a daemon."""
    groups = {}
    for process in orphans.values():
        if is_idle(process):
            groups.setdefault((process["uid"], process["short"]), []).append(process)
    return {
        key: group
        for key, group in groups.items()
        if len(group) >= ORPHAN_COUNT or sum(p["rss"] for p in group) >= MIN_RAM
    }


def is_kill_safe(group):
    """A few idle orphans may be a deliberate daemon; only pile-ups are clearly leaks."""
    return len(group) >= ORPHAN_COUNT


def real_memory(group, limit):
    """Return (bytes, exact) for processes: PSS for your own, an upper bound for others'."""
    total = 0
    try:
        for process in group:
            with open("/proc/%d/smaps_rollup" % process["pid"]) as handle:
                for line in handle:
                    if line.startswith("Pss:"):
                        total += int(line.split()[1]) * 1024
                        break
        return total, True
    except (OSError, ValueError, IndexError):
        return min(sum(process["rss"] for process in group), limit), False


def format_memory(group, limit):
    value, exact = real_memory(group, limit)
    return "%s%.1f GiB" % ("" if exact else "up to ", gib(value))


def plural(count, word):
    return "%d %s%s" % (count, word, "" if count == 1 else "es" if word.endswith("s") else "s")


def find_problems(snapshot, me):
    """Return [(user or None for the whole node, description)], worst-affecting first."""
    problems = []
    cores, total, available = snapshot["cores"], snapshot["total"], snapshot["available"]
    users, jobs = snapshot["users"], snapshot["jobs"]

    if available < total * LOW_RAM_FRACTION:
        problems.append((None, "Low memory: only %.0f of %.0f GiB available" % (gib(available), gib(total))))
    if snapshot["swap_used"] > 0:
        problems.append((None, "Swapping: %.1f GiB of swap in use" % gib(snapshot["swap_used"])))
    if snapshot["load"] > cores:
        problems.append((None, "Overloaded: load %.0f on %d cores" % (snapshot["load"], cores)))
    for path, used, capacity, limit in snapshot["disks"]:
        if used >= capacity * limit:
            problems.append(
                (
                    None,
                    "%s is %.0f%% full (%.1f GiB left)" % (path, 100 * used / capacity, gib(capacity - used)),
                ),
            )

    orphans = snapshot["orphans"]
    leaked = leaked_groups(orphans)
    leaked_pids = {process["pid"] for group in leaked.values() for process in group}
    for (uid, short), group in sorted(leaked.items(), key=lambda item: -len(item[1])):
        name = username(uid)
        hint = ""
        if name == me:
            hint = "; clear with: kill (,use --orphans)" if is_kill_safe(group) else "; still needed?"
        problems.append(
            (
                name,
                "%s: %s orphaned and idle, holding %s, oldest %s%s"
                % (
                    name,
                    plural(len(group), short + " process"),
                    format_memory(group, users[name]["rss"]),
                    duration(max(p["age"] for p in group)),
                    hint,
                ),
            ),
        )

    for name, user in users.items():
        commands = {}
        for process in user["processes"]:
            if process["pid"] not in leaked_pids and process["state"] != "Z":
                commands.setdefault(process["short"], []).append(process)
        for short, group in commands.items():
            idle = [process for process in group if process["cores"] < IDLE_NOW]
            if len(group) >= SWARM_COUNT and len(idle) >= 0.9 * len(group):
                problems.append(
                    (
                        name,
                        "%s: %s, %d idle, holding %s; a worker pool sized to the node?"
                        % (name, plural(len(group), short + " process"), len(idle), format_memory(group, user["rss"])),
                    ),
                )
        stuck = [process for process in user["processes"] if process["stuck"]]
        if stuck:
            problems.append(
                (
                    name,
                    "%s: %s stuck in uninterruptible I/O wait (%s); suspect a disk or NFS hang"
                    % (name, plural(len(stuck), "process"), stuck[0]["short"]),
                ),
            )
        zombies = [process for process in user["processes"] if process["state"] == "Z"]
        if len(zombies) >= ZOMBIE_COUNT:
            problems.append((name, "%s: %s not reaped by their parent" % (name, plural(len(zombies), "zombie"))))
        if user["rss"] >= total * RAM_HOG_FRACTION:
            problems.append((name, "%s: holding %.0f%% of the node's RAM" % (name, 100 * user["rss"] / total)))
        if jobs is not None:
            outside = sum(process["cores"] for process in user["processes"] if not process["job"])
            if outside >= max(cores * OUTSIDE_SLURM_FRACTION, 1):
                problems.append(
                    (
                        name,
                        "%s: %.1f cores outside Slurm, which can't see them when scheduling" % (name, outside),
                    ),
                )
        for process in user["processes"]:
            for index, (memory, util) in process["gpus"].items():
                if util is not None and util < GPU_IDLE_UTIL and process["age"] >= MIN_AGE:
                    problems.append(
                        (
                            name,
                            "%s: %s (pid %d) holds %.1f GiB on GPU %s at %d%% use right now"
                            % (name, process["short"], process["pid"], gib(memory), index, util),
                        ),
                    )

    for job in jobs or []:
        cutoff = job["cpus"] * SLURM_IDLE_FRACTION
        if (
            job["cpus"] >= SLURM_IDLE_MIN_CPUS
            and job["elapsed"]
            and job["elapsed"] >= SLURM_IDLE_MIN_AGE
            and job["avg"] is not None
            and job["avg"] < cutoff
            and job["cores"] < cutoff
        ):
            problems.append(
                (
                    job["user"],
                    "%s: job %s holds %d CPUs, using %.1f now, %.1f on average over %s"
                    % (job["user"], job["id"], job["cpus"], job["cores"], job["avg"], duration(job["elapsed"])),
                ),
            )
    return problems


def read_memory():
    memory = {}
    with open("/proc/meminfo") as handle:
        for line in handle:
            key, value = line.split(":")
            memory[key] = int(value.split()[0]) * 1024
    return memory["MemTotal"], memory["MemAvailable"], memory["SwapTotal"] - memory["SwapFree"]


def gib(value):
    return value / 2**30


def duration(seconds):
    """Format seconds as its two largest units."""
    seconds = int(seconds)
    days, seconds = divmod(seconds, 86400)
    hours, seconds = divmod(seconds, 3600)
    minutes, seconds = divmod(seconds, 60)
    if days:
        return "%dd %dh" % (days, hours)
    if hours:
        return "%dh %dm" % (hours, minutes)
    if minutes:
        return "%dm" % minutes
    return "%ds" % seconds


def is_intensive(user):
    return bool(
        user["cores"] >= MIN_CORES
        or user["rss"] >= MIN_RAM
        or user["jobs"]
        or any(process["gpus"] for process in user["processes"]),
    )


def take_snapshot():
    util_before, _, _ = gpu_status()
    processes = sample(INTERVAL)
    util, indices, held = gpu_status()
    by_pid = {process["pid"]: process for process in processes}
    for uuid, pid, memory in held:
        if pid in by_pid:
            # Utilization is a brief window; only trust "idle" if both readings agree.
            readings = [value for value in (util_before.get(uuid), util.get(uuid)) if value is not None]
            by_pid[pid]["gpus"][indices[uuid]] = (memory, max(readings) if readings else None)
    orphans = find_orphans(processes)
    users = by_user(processes, find_attached(processes))
    jobs = slurm_jobs(processes)
    for job in jobs or []:
        if job["user"] != "root":
            users.setdefault(job["user"], new_user())["jobs"].append(job)
    total, available, swap_used = read_memory()
    disks = []
    for path, limit in DISK_LIMITS:
        try:
            usage = shutil.disk_usage(path)
            disks.append((path, usage.total - usage.free, usage.total, limit))
        except OSError:
            continue
    return dict(
        cores=os.cpu_count(),
        total=total,
        available=available,
        swap_used=swap_used,
        load=os.getloadavg()[0],
        disks=disks,
        orphans=orphans,
        users=users,
        jobs=jobs,
        cluster=slurm_cluster(),
        gpus_total=len(indices),
        gpus_used=len({uuid for uuid, _, _ in held}),
    )


def tasks_of(user):
    """Group a user's processes by command, busiest first."""
    tasks = {}
    for process in user["processes"]:
        if process["state"] != "Z":
            tasks.setdefault(process["short"], []).append(process)
    rows = []
    for short, group in tasks.items():
        gpus = sorted({index for process in group for index in process["gpus"]})
        rows.append(
            dict(
                short=short,
                count=len(group),
                cores=sum(process["cores"] for process in group),
                avg=sum(process["avg"] for process in group),
                # Forked processes share pages, so a sum can't exceed the user's total.
                rss=min(sum(process["rss"] for process in group), user["rss"]),
                age=max(process["age"] for process in group),
                gpus=gpus,
            ),
        )
    rows.sort(key=lambda row: (row["cores"], row["avg"], row["rss"]), reverse=True)
    return rows


def print_user(name, user, cores, total, limit):
    if user["on_for"] is not None:
        presence = "on for %s" % duration(user["on_for"])
    elif user["oldest"] is not None:
        presence = "no session, processes up to %s old" % duration(user["oldest"])
    else:
        presence = "no visible processes"
    print(
        "%s  %.1f cores (%.1f%%)  %.1f GiB (%.1f%%)  %s  %s"
        % (
            name,
            user["cores"],
            100 * user["cores"] / cores,
            gib(user["rss"]),
            100 * user["rss"] / total,
            plural(user["count"], "proc"),
            presence,
        ),
    )
    for job in user["jobs"]:
        average = "" if job["avg"] is None else ", avg %.1f" % job["avg"]
        running = "?" if job["elapsed"] is None else duration(job["elapsed"])
        left = "" if job["left"] is None else ", %s left" % duration(job["left"])
        print(
            "  job %s  %d CPUs, using %.1f%s  running %s%s  %s"
            % (job["id"], job["cpus"], job["cores"], average, running, left, job["name"]),
        )
    tasks = tasks_of(user)
    small = 0
    if limit is None:
        kept = [task for task in tasks if task["cores"] >= IDLE_NOW or task["rss"] >= SMALL_TASK_RAM or task["gpus"]]
        small = len(tasks) - len(kept)
        tasks = kept
    for task in tasks[:limit]:
        label = task["short"] if task["count"] == 1 else "%s x%d" % (task["short"], task["count"])
        gpus = "  GPU %s" % ",".join(task["gpus"]) if task["gpus"] else ""
        print(
            "  %s  %.1f cores, avg %.1f  %.1f GiB  up %s%s"
            % (label, task["cores"], task["avg"], gib(task["rss"]), duration(task["age"]), gpus),
        )
    if limit is not None and len(tasks) > limit:
        print("  ... %d more; ,use %s lists them" % (len(tasks) - limit, name))
    if small:
        print("  ... %d small idle %s" % (small, "task" if small == 1 else "tasks"))


def show(show_all=False, only_user=None, problems_only=False):
    snapshot = take_snapshot()
    me = username(os.getuid())
    users, cores, total = snapshot["users"], snapshot["cores"], snapshot["total"]
    mine = users.get(me, new_user())
    others = [(name, user) for name, user in users.items() if name != me]

    gpus = ""
    if snapshot["gpus_total"]:
        gpus = "; %d of %d GPUs in use" % (snapshot["gpus_used"], snapshot["gpus_total"])
    print(
        "%s: %d cores, load %.1f; %.0f of %.0f GiB RAM available%s"
        % (
            socket.gethostname().split(".")[0],
            cores,
            snapshot["load"],
            gib(snapshot["available"]),
            gib(total),
            gpus,
        ),
    )
    if snapshot["cluster"]:
        allocated, _, _, cluster_total, pending = snapshot["cluster"]
        print(
            "Cluster: %d of %d CPUs allocated, %s pending"
            % (allocated, cluster_total, plural(pending, "job")),
        )
    print(
        "Others: %.1f cores, %.1f GiB   You: %.1f cores, %.1f GiB"
        % (
            sum(user["cores"] for _, user in others),
            gib(sum(user["rss"] for _, user in others)),
            mine["cores"],
            gib(mine["rss"]),
        ),
    )

    problems = find_problems(snapshot, me)
    if only_user:
        problems = [problem for problem in problems if problem[0] == only_user]
    print()
    print("Problems: %s" % ("none found" if not problems else len(problems)))
    for _, text in problems:
        print("  ! %s" % text)
    if problems_only:
        return

    if only_user:
        print()
        if only_user in users:
            print_user(only_user, users[only_user], cores, total, None)
        else:
            print("%s has no processes or jobs on this node." % only_user)
        return

    rows = users.items() if show_all else others
    shown = sorted(
        ((name, user) for name, user in rows if show_all or is_intensive(user)),
        key=lambda row: (row[1]["cores"], row[1]["rss"]),
        reverse=True,
    )
    if not shown:
        print("\nNo other users are doing anything intensive.")
    for name, user in shown:
        print()
        print_user(name, user, cores, total, MAX_TASKS)

    hidden = 0 if show_all else len(others) - len(shown)
    if hidden:
        print(
            "\n%s below %.1f cores and %.0f GiB; --all shows them."
            % (plural(hidden, "more user"), MIN_CORES, gib(MIN_RAM)),
        )


def print_orphans():
    """Print PIDs of your own leaked processes, for: kill (,use --orphans)."""
    orphans = find_orphans(sample(INTERVAL))
    for (uid, _), group in leaked_groups(orphans).items():
        if uid == os.getuid() and is_kill_safe(group):
            for process in group:
                print(process["pid"])


def main():
    parser = argparse.ArgumentParser(
        prog=",use",
        description="Summarize who is using this node, for how long, and what looks wrong.",
        epilog="Covers this node only. CPU is measured over 1 second; avg is lifetime CPU time divided by age. RAM is anonymous and shared memory from each user's session and Slurm job cgroups, excluding file cache. Problem checks are heuristics and only report.",
    )
    parser.add_argument("user", nargs="?", help="show one user's problems and every task")
    parser.add_argument(
        "-a",
        "--all",
        action="store_true",
        help="show every non-root user, including you and light users",
    )
    parser.add_argument(
        "-p",
        "--problems",
        action="store_true",
        help="show only the summary and problems",
    )
    parser.add_argument(
        "--orphans",
        action="store_true",
        help="print PIDs of your own piled-up orphaned, idle processes",
    )
    args = parser.parse_args()
    if args.orphans:
        print_orphans()
        return 0
    show(show_all=args.all, only_user=args.user, problems_only=args.problems)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(0)
    except BrokenPipeError:
        sys.exit(0)
    except OSError as error:
        print("Error: %s" % error, file=sys.stderr)
        sys.exit(1)
