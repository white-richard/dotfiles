function ,pids -d "Summarize info about a process by PID"
    set -l pid $argv[1]

    if test -z "$pid"
        set_color red; echo "Error: Please provide a PID."; set_color normal
        echo "Usage: pid_summary <PID>"
        return 1
    end

    if not test -d "/proc/$pid"
        set_color red; echo "Error: Process $pid does not exist."; set_color normal
        return 1
    end

    set -l proc_dir "/proc/$pid"

    set_color blue; echo "========================================="
    echo " Process Summary for PID: $pid"
    echo "========================================="; set_color normal

    # Basic Process Identity & State
    set_color green; echo -e "\n[ Identity & State ]"; set_color normal
    ps -p $pid -o user,group,pid,ppid,state,start,time,comm

    # Full Command Line
    set_color green; echo -e "\n[ Full Command Line ]"; set_color normal
    if test -r "$proc_dir/cmdline"
        set -l cmd (tr '\0' ' ' < "$proc_dir/cmdline" | string trim)
        if test -n "$cmd"
            echo $cmd
        else
            echo "(No command line - likely a kernel thread or zombie process)"
        end
    else
        echo "(Permission denied or unreadable)"
    end

    # Memory & Threads
    set_color green; echo -e "\n[ Resource Usage & Threads ]"; set_color normal
    if test -r "$proc_dir/status"
        grep -E '^(VmPeak|VmSize|VmRSS|Threads|voluntary_ctxt_switches):' "$proc_dir/status"
    else
        echo "(Status file unreadable)"
    end

    # Control Groups
    set_color green; echo -e "\n[ Cgroups / Systemd Slices ]"; set_color normal
    if test -r "$proc_dir/cgroup"
        cat "$proc_dir/cgroup" | head -n 3
    else
        echo "(Cgroup file unreadable)"
    end
end
