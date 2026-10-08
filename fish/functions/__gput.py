#!/usr/bin/env python3
"""Plot per-week GPU usage by user from the history ,gpuu's collector records."""
import argparse
import datetime as dt
import json
import os
import pwd
import shutil
import sys
import time

import __gpuu as gpuu  # Sibling helper; the script's directory is on sys.path.

ME = pwd.getpwuid(os.getuid()).pw_name
MY_COLOR, MY_GLYPH = "1;38;5;46", "◆"
USER_GLYPH, OTHER_GLYPH, IDLE_GLYPH = "●", "○", "·"
PALETTE = ["38;5;39", "38;5;208", "38;5;170", "38;5;220", "38;5;51", "38;5;203",
           "38;5;141", "38;5;180", "38;5;75", "38;5;214", "38;5;121", "38;5;217"]
OTHER_COLOR, IDLE_COLOR, DIM = "38;5;245", "38;5;238", "2"
OTHERS = "\0others"  # Pseudo-user for everyone outside a --user filter.


def load_usage(directory, state):
    """Return {(hour, uuid): bucket}, summing restarts and skipping re-flushed buckets."""
    records, seen = {}, set()

    def add(entry):
        if (entry["id"], entry["gpu"]) in seen:
            return
        seen.add((entry["id"], entry["gpu"]))
        bucket = records.setdefault(
            (entry["hour"], entry["gpu"]),
            dict(index=entry["index"], name=entry["name"], observed=0.0, users={}),
        )
        bucket["observed"] += entry["observed"]
        for user, seconds in entry["users"].items():
            bucket["users"][user] = bucket["users"].get(user, 0.0) + seconds

    try:
        with (directory / "usage.jsonl").open() as log:
            for line in log:
                try:
                    add(json.loads(line))
                except (ValueError, KeyError):
                    pass  # A line still being appended by the collector.
    except FileNotFoundError:
        pass
    current = state.get("usage")
    if current:
        for uuid, gpu in current["gpus"].items():
            add(dict(gpu, id=current["id"], hour=current["hour"], gpu=uuid))
    return records


def week_periods(weeks, now):
    """Monday-to-Monday local weeks, oldest first; the current week ends now."""
    today = dt.datetime.fromtimestamp(now).date()
    monday = today - dt.timedelta(days=today.weekday())
    periods = []
    for back in range(weeks - 1, -1, -1):
        start = monday - dt.timedelta(weeks=back)
        periods.append((start, local_epoch(start), min(local_epoch(start + dt.timedelta(weeks=1)), now)))
    return periods


def day_periods(weeks, now):
    first = week_periods(weeks, now)[0][0]
    today = dt.datetime.fromtimestamp(now).date()
    days = (today - first).days + 1
    return [
        (day, local_epoch(day), min(local_epoch(day + dt.timedelta(days=1)), now))
        for day in (first + dt.timedelta(days=i) for i in range(days))
    ]


def local_epoch(day):
    return dt.datetime.combine(day, dt.time()).timestamp()


def aggregate(records, periods, focus):
    """Return ({uuid: (index, name)}, {uuid: [period totals]})."""
    gpus, totals = {}, {}
    for (hour, uuid), bucket in records.items():
        gpus[uuid] = (bucket["index"], bucket["name"])
        rows = totals.setdefault(uuid, [dict(observed=0.0, users={}) for _ in periods])
        for i, (_, start, end) in enumerate(periods):
            if start <= hour < end:
                rows[i]["observed"] += bucket["observed"]
                for user, seconds in bucket["users"].items():
                    if focus and user not in focus:
                        user = OTHERS
                    rows[i]["users"][user] = rows[i]["users"].get(user, 0.0) + seconds
                break
    return gpus, totals


def combine(rows):
    total = dict(observed=0.0, users={})
    for row in rows:
        total["observed"] += row["observed"]
        for user, seconds in row["users"].items():
            total["users"][user] = total["users"].get(user, 0.0) + seconds
    return total


def allocate(parts, width):
    """Split width cells across (key, seconds) parts by largest remainder."""
    total = sum(seconds for _, seconds in parts)
    if total <= 0:
        return []
    exact = [(key, seconds * width / total) for key, seconds in parts]
    cells = {key: int(share) for key, share in exact}
    spare = width - sum(cells.values())
    for key, share in sorted(exact, key=lambda item: item[1] - int(item[1]), reverse=True)[:spare]:
        cells[key] += 1
    return [(key, cells[key]) for key, _ in parts if cells[key]]


class Painter:
    def __init__(self, users, color):
        self.color = color
        self.styles = {ME: (MY_COLOR, MY_GLYPH), OTHERS: (OTHER_COLOR, OTHER_GLYPH),
                       None: (IDLE_COLOR, IDLE_GLYPH)}
        others = sorted(user for user in users if user not in self.styles)
        for i, user in enumerate(others):
            self.styles[user] = (PALETTE[i % len(PALETTE)], USER_GLYPH)

    def paint(self, text, style):
        return "\033[%sm%s\033[0m" % (style, text) if self.color and style else text

    def cells(self, key, count=1, glyph=None):
        style, default = self.styles[key]
        return self.paint((glyph or default) * count, style)

    def label(self, user):
        if user == OTHERS:
            return "other users"
        if user is None:
            return "idle"
        return user + " (you)" if user == ME else user

    def legend(self, users):
        keys = [ME] if ME in users else []
        keys += sorted(user for user in users if user not in (ME, OTHERS))
        keys += [OTHERS] if OTHERS in users else []
        return "  ".join("%s %s" % (self.cells(key), self.label(key)) for key in keys + [None])


def parts_of(row):
    """Ordered (user, seconds) segments with idle last; you always come first."""
    users = sorted(row["users"].items(), key=lambda item: (item[0] != ME, item[0] == OTHERS, -item[1]))
    idle = max(0.0, row["observed"] - sum(seconds for _, seconds in users))
    return [(user, seconds) for user, seconds in users if seconds > 0] + [(None, idle)]


def bar(painter, row, width):
    if row["observed"] <= 0:
        return painter.paint("no data".center(width), DIM)
    return "".join(painter.cells(key, count) for key, count in allocate(parts_of(row), width))


def summary(row, span):
    if row["observed"] <= 0:
        return ""
    used = sum(row["users"].values()) / row["observed"]
    text = "%3.0f%% used" % (100 * used)
    if span > 0 and row["observed"] < 0.995 * span:
        text += "  (observed %.0f%%)" % (100 * min(1, row["observed"] / span))
    return text


def breakdown(painter, row):
    if row["observed"] <= 0:
        return ""
    return "  ".join(
        "%s %s %.0f%%" % (painter.cells(user), painter.label(user), 100 * seconds / row["observed"])
        for user, seconds in parts_of(row)[:-1]
    )


def week_label(start, now):
    this_week = dt.datetime.fromtimestamp(now).date() - dt.timedelta(days=dt.datetime.fromtimestamp(now).weekday())
    return "this week" if start == this_week else "wk " + start.strftime("%b %d")


def render_weeks(painter, gpus, totals, periods, width, now):
    for uuid in sorted(gpus, key=lambda u: gpus[u][0]):
        print("GPU %s  %s" % gpus[uuid])
        for (start, begin, end), row in zip(periods, totals[uuid]):
            print("  %-10s │%s│ %s" % (week_label(start, now), bar(painter, row, width), summary(row, end - begin)))
        print()


def render_average(painter, gpus, totals, periods, width):
    span = sum(end - begin for _, begin, end in periods)
    rows = []
    for uuid in sorted(gpus, key=lambda u: gpus[u][0]):
        row = combine(totals[uuid])
        rows.append(row)
        print("GPU %s  %s" % gpus[uuid])
        print("  │%s│ %s" % (bar(painter, row, width), summary(row, span)))
        if breakdown(painter, row):
            print("   " + breakdown(painter, row))
        print()
    if len(rows) > 1:
        row = combine(rows)
        print("All GPUs")
        print("  │%s│ %s" % (bar(painter, row, width), summary(row, span * len(rows))))
        print("   " + breakdown(painter, row))
        print()


def render_daily(painter, gpus, totals, days, height, columns):
    weeks = (len(days) + 6) // 7
    step = 2 if 7 + len(days) * 2 + weeks <= columns else 1
    for uuid in sorted(gpus, key=lambda u: gpus[u][0]):
        stacks = []
        for row in totals[uuid]:
            stack = []
            if row["observed"] > 0:
                for key, count in allocate(parts_of(row), height):
                    stack += [key] * count
            stacks.append(stack)
        print("GPU %s  %s" % gpus[uuid])
        for level in range(height - 1, -1, -1):
            axis = {height - 1: "100%", (height - 1) // 2: " 50%", 0: "  0%"}.get(level, "")
            line = ""
            for i, stack in enumerate(stacks):
                if i and i % 7 == 0:
                    line += " "
                if not stack:
                    cell = painter.paint("-", DIM) if level == 0 else " "
                else:
                    cell = painter.cells(stack[level])
                line += cell + " " * (step - 1)
            print("%4s ┤%s" % (axis, line))
        names = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"] if step == 2 else "MTWTFSS"
        weekdays = dates = ""
        for i, (day, _, _) in enumerate(days):
            if i and i % 7 == 0:
                weekdays += " "
            weekdays += names[day.weekday()]
        for week in range(weeks):
            block = 7 * step + (1 if week else 0)
            text = days[week * 7][0].strftime("%m/%d")
            dates += (" " * (1 if week else 0) + text).ljust(block)[:block]
        print("      " + weekdays)
        print("      " + painter.paint(dates, DIM))
        print()


IDLE_HOUR = 0.05  # An hour counts as idle when under 5% of observed time was in use.


def hour_rows(records, uuids, begin, now, focus):
    """{hour: {uuid: bucket}} for complete-enough hours inside the window."""
    hours = {}
    for (hour, uuid), bucket in records.items():
        if uuid in uuids and begin <= hour < now and bucket["observed"] > 0:
            users = {}
            for user, seconds in bucket["users"].items():
                key = OTHERS if focus and user not in focus else user
                users[key] = users.get(key, 0.0) + seconds
            hours.setdefault(hour, {})[uuid] = dict(bucket, users=users)
    return hours


def heat(painter, fraction):
    """Green when mostly free, through yellow, to red when busy."""
    for limit, style in ((0.25, "38;5;46"), (0.5, "38;5;148"), (0.75, "38;5;214"), (2, "38;5;196")):
        if fraction <= limit:
            return style


def render_when(painter, gpus, records, begin, now, focus):
    hours = hour_rows(records, set(gpus), begin, now, focus)
    if not hours:
        print("No usage recorded in this window yet.")
        return
    cells = {}
    for hour, buckets in hours.items():
        local = dt.datetime.fromtimestamp(hour)
        cell = cells.setdefault((local.weekday(), local.hour), dict(observed=0.0, users={}))
        for bucket in buckets.values():
            cell["observed"] += bucket["observed"]
            for user, seconds in bucket["users"].items():
                cell["users"][user] = cell["users"].get(user, 0.0) + seconds
    days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    header = "      " + "".join("%-2d" % h if h % 3 == 0 else "  " for h in range(24))

    print("Average free GPUs by hour (of %d; green = mostly free, red = busy)" % len(gpus))
    print(header)
    for day in range(7):
        line = ""
        for h in range(24):
            cell = cells.get((day, h))
            if not cell:
                line += painter.paint("- ", DIM)
                continue
            used = min(1.0, sum(cell["users"].values()) / cell["observed"])
            free = int(round((1 - used) * len(gpus)))
            line += painter.paint(("%d" % free if free < 10 else "+") + " ", heat(painter, used))
        print("  %s %s" % (days[day], line))
    print()

    print("Who is usually on (busiest user; %s ≥50%% of GPUs  • 15-50%%  · <15%%)" % USER_GLYPH)
    print(header)
    for day in range(7):
        line = ""
        for h in range(24):
            cell = cells.get((day, h))
            if not cell or not cell["users"]:
                line += painter.paint("- " if not cell else "  ", DIM)
                continue
            user, seconds = max(cell["users"].items(), key=lambda item: item[1])
            share = sum(cell["users"].values()) / cell["observed"]
            glyph = USER_GLYPH if share >= 0.5 else "•" if share >= 0.15 else "·"
            line += painter.cells(user, glyph=glyph) + " "
        print("  %s %s" % (days[day], line))
    print()

    def is_idle(bucket):
        return sum(bucket["users"].values()) < IDLE_HOUR * bucket["observed"]

    print("How often GPUs are free at once (share of observed hours)")
    counts = [sum(map(is_idle, buckets.values())) for buckets in hours.values()]
    line = "  ".join(
        "≥%d free %3.0f%%" % (k, 100 * sum(c >= k for c in counts) / len(counts))
        for k in range(1, len(gpus) + 1)
    )
    print("  " + line)
    print("  all busy %.0f%% of hours; typically %d free" % (
        100 * sum(c == 0 for c in counts) / len(counts), sorted(counts)[len(counts) // 2]))
    print()

    print("Most dependable free windows (GPUs idle in every observed week at that time)")
    slots = {}
    for hour, buckets in hours.items():
        local = dt.datetime.fromtimestamp(hour)
        slots.setdefault((local.weekday(), local.hour), []).append(sum(map(is_idle, buckets.values())))
    windows = []
    for day in range(7):
        run = []
        for h in range(25):
            free = slots.get((day, h)) if h < 24 else None
            if run and (not free or min(free) != run[0][1]):
                if len(run) >= 2 and run[0][1] > 0:
                    windows.append((day, run))
                run = []
            if free:
                run.append((h, min(free), sum(free) / len(free), len(free)))
    windows.sort(key=lambda w: (-w[1][0][1], -len(w[1])))
    for day, run in windows[:10]:
        print("  %s %02d:00-%02d:00  %d guaranteed free, avg %.1f  (%d weeks seen)" % (
            days[day], run[0][0], run[-1][0] + 1, run[0][1],
            sum(r[2] for r in run) / len(run), min(r[3] for r in run)))
    if not windows:
        print("  none yet (needs ≥2 consecutive hours with a GPU idle every week)")
    print()

    print("Per GPU (idle hour = under %d%% in use)" % (IDLE_HOUR * 100))
    for uuid in sorted(gpus, key=lambda u: gpus[u][0]):
        observed = idle_hours = streak = longest = long_gaps = 0
        used = total = 0.0
        last, owners = None, {}
        stretches = []
        for hour in sorted(hours):
            bucket = hours[hour].get(uuid)
            if not bucket:
                continue
            for user, seconds in bucket["users"].items():
                owners[user] = owners.get(user, 0.0) + seconds
            used += sum(bucket["users"].values())
            total += bucket["observed"]
            observed += 1
            if is_idle(bucket):
                idle_hours += 1
                streak = streak + 1 if last == hour - 3600 and streak else 1
            else:
                if streak:
                    stretches.append(streak)
                streak = 0
            last = hour
        if streak:
            stretches.append(streak)
        if not observed:
            continue
        longest = max(stretches or [0])
        long_gaps = sum(s >= 4 for s in stretches)
        main = sorted(owners.items(), key=lambda kv: -kv[1])[:2]
        print("  GPU %-2s idle %3.0f%%  %4d/%-4d idle h  longest idle %-7s  %2d idle stretches ≥4h  mostly %s"
              % (gpus[uuid][0], 100 * (1 - used / total), idle_hours, observed, duration(longest), long_gaps,
                 ", ".join("%s %.0f%%" % (painter.label(u), 100 * sec / max(used, 1)) for u, sec in main) or "nobody"))
    print()

    print("Per user (GPU-hours, share of capacity, habits)")
    stats = {}
    capacity = sum(b["observed"] for buckets in hours.values() for b in buckets.values())
    for hour, buckets in hours.items():
        local = dt.datetime.fromtimestamp(hour)
        for uuid, bucket in buckets.items():
            for user, seconds in bucket["users"].items():
                item = stats.setdefault(user, dict(seconds=0.0, hours={}, gpus={}, by_hour=[0.0] * 24, by_day=[0.0] * 7))
                item["seconds"] += seconds
                item["hours"][hour] = item["hours"].get(hour, 0.0) + seconds
                item["gpus"][gpus[uuid][0]] = item["gpus"].get(gpus[uuid][0], 0.0) + seconds
                item["by_hour"][local.hour] += seconds
                item["by_day"][local.weekday()] += seconds
    for user, item in sorted(stats.items(), key=lambda kv: -kv[1]["seconds"]):
        if item["seconds"] < 60:
            continue
        active = sorted(hour for hour, seconds in item["hours"].items() if seconds >= 60)
        sessions = []
        for hour in active:
            if sessions and sessions[-1][1] == hour - 3600:
                sessions[-1][1] = hour
            else:
                sessions.append([hour, hour])
        lengths = sorted((end - start) // 3600 + 1 for start, end in sessions) or [0]
        top_hours = sorted(range(24), key=lambda h: -item["by_hour"][h])[:3]
        top_days = [days[d] for d in sorted(range(7), key=lambda d: -item["by_day"][d]) if item["by_day"][d] > 0][:3]
        favorite = [str(i) for i, _ in sorted(item["gpus"].items(), key=lambda kv: -kv[1])[:3]]
        print("  %s %s" % (painter.cells(user), painter.label(user)))
        print("      %.1f GPU-h (%.0f%% of capacity)  avg %.1f GPUs when on, peak %.1f  favorite GPUs %s"
              % (item["seconds"] / 3600, 100 * item["seconds"] / capacity,
                 item["seconds"] / 3600 / max(1, len(active)), max(item["hours"].values()) / 3600,
                 ",".join(favorite)))
        print("      %d sessions, typical %s (longest %s)  mostly %s around %s"
              % (len(sessions), duration(lengths[len(lengths) // 2]), duration(lengths[-1]),
                 "/".join(top_days), " ".join("%02d:00" % h for h in sorted(top_hours))))
    print()


def duration(hours):
    return "%dd %dh" % divmod(hours, 24) if hours >= 24 else "%dh" % hours


def main():
    parser = argparse.ArgumentParser(
        prog=",gput",
        description="Plot GPU usage per week by user (root excluded).",
        epilog="Bars show share of observed time; history begins when ,gpuu's collector "
        "started tracking usage. Shared GPUs split time evenly between users.",
    )
    parser.add_argument("-n", "--weeks", type=int, default=4, metavar="N", help="weeks to show (default 4)")
    parser.add_argument("-u", "--user", action="append", default=[], metavar="USER",
                        help="highlight USER; everyone else shows as 'other users' (repeatable)")
    parser.add_argument("-m", "--me", action="store_true", help="same as --user %s" % ME)
    parser.add_argument("-g", "--gpu", type=int, action="append", default=[], metavar="INDEX",
                        help="only show GPU INDEX (repeatable)")
    view = parser.add_mutually_exclusive_group()
    view.add_argument("-a", "--avg", action="store_true", help="one bar per GPU averaged over N weeks")
    view.add_argument("-d", "--daily", action="store_true", help="column chart with one column per day")
    view.add_argument("-W", "--when", action="store_true",
                      help="weekday x hour patterns: free GPUs, who is usually on, idle and per-user stats")
    parser.add_argument("-w", "--width", type=int, default=50, help="bar width in dots (default 50)")
    parser.add_argument("--height", type=int, default=10, help="daily chart height in dots (default 10)")
    parser.add_argument("--no-color", action="store_true", help="disable colors")
    args = parser.parse_args()
    if args.weeks < 1 or args.width < 1 or args.height < 2:
        parser.error("--weeks and --width must be positive; --height at least 2")

    directory = gpuu.cache_directory()
    try:
        gpuu.ensure_running(directory)
    except (OSError, RuntimeError) as error:
        print("Warning: collector not running (%s); showing recorded history." % error, file=sys.stderr)
    state = gpuu.read_state(directory)
    if gpuu.collector_running(directory) and state.get("usage_version") != 1:
        print("Warning: the running collector predates usage tracking; restart it with "
              "',gpuu --stop; ,gpuu --start'.", file=sys.stderr)

    now = time.time()
    focus = set(args.user + ([ME] if args.me else []))
    periods = day_periods(args.weeks, now) if args.daily else week_periods(args.weeks, now)
    gpus, totals = aggregate(load_usage(directory, state), periods, focus)
    if args.gpu:
        gpus = {uuid: gpu for uuid, gpu in gpus.items() if gpu[0] in args.gpu}
    if not gpus:
        print("No usage recorded in the last %d week(s) yet." % args.weeks)
        return 0

    users = set()
    for uuid in gpus:
        for row in totals[uuid]:
            users.update(user for user, seconds in row["users"].items() if seconds > 0)
    color = not args.no_color and sys.stdout.isatty() and "NO_COLOR" not in os.environ
    painter = Painter(users, color)
    print(painter.legend(users))
    print()
    if args.when:
        render_when(painter, gpus, load_usage(directory, state), periods[0][1], now, focus)
    elif args.avg:
        render_average(painter, gpus, totals, periods, args.width)
    elif args.daily:
        columns = shutil.get_terminal_size().columns
        render_daily(painter, gpus, totals, periods, args.height, columns)
    else:
        render_weeks(painter, gpus, totals, periods, args.width, now)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(0)
    except (OSError, RuntimeError) as error:
        print("Error: %s" % error, file=sys.stderr)
        sys.exit(1)
