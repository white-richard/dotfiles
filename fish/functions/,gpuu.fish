function ,gpuu --description 'Show which users have processes running on each CUDA GPU, grouped by GPU index'
    if not command -q nvidia-smi
        echo "Error: nvidia-smi not found in PATH" >&2
        return 1
    end

    # Build a map of GPU UUID -> index
    set -l indices
    set -l uuids
    for line in (nvidia-smi --query-gpu=index,uuid --format=csv,noheader)
        set -l parts (string split ', ' -- $line)
        set -a indices $parts[1]
        set -a uuids $parts[2]
    end

    if test (count $indices) -eq 0
        echo "No CUDA GPUs detected."
        return 1
    end

    # Pull every compute process across all GPUs in one call
    set -l proc_lines (nvidia-smi --query-compute-apps=gpu_uuid,pid,process_name,used_memory --format=csv,noheader,nounits)

    for i in (seq (count $indices))
        set -l idx $indices[$i]
        set -l uuid $uuids[$i]
        echo "GPU $idx:"

        set -l found 0
        for line in $proc_lines
            set -l fields (string split ', ' -- $line)
            if test "$fields[1]" = "$uuid"
                set found 1
                set -l pid $fields[2]
                set -l pname $fields[3]
                set -l mem $fields[4]
                set -l user (ps -o user= -p $pid 2>/dev/null | string trim)
                set -l runtime (ps -o etime= -p $pid 2>/dev/null | string trim)
                test -z "$user"; and set user "?"
                test -z "$runtime"; and set runtime "?"
                printf "  %-10s pid=%-8s mem=%6s MiB  time=%-12s cmd=%s\n" $user $pid $mem $runtime $pname
            end
        end

        if test $found -eq 0
            echo "  (no processes)"
        end
    end
end
