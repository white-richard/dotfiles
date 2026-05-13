function ,tail -d "Tail the most recent .out and .err files in a log directory"
    # Take the first argument as the directory, default to "logs" if empty
    set -l log_dir $argv[1]
    if test -z "$log_dir"
        set log_dir "logs"
    end

    if not test -d "$log_dir"
        echo "Error: Directory '$log_dir' does not exist."
        return 1
    end

    # Find the most recent .out and .err files safely
    # We use ls -t and grep to avoid fish wildcard expansion errors
    set -l latest_out_file (ls -t $log_dir | grep '\.out$' | head -n 1)
    set -l latest_err_file (ls -t $log_dir | grep '\.err$' | head -n 1)

    set -l files_to_tail

    if test -n "$latest_out_file"
        set -a files_to_tail "$log_dir/$latest_out_file"
    end

    if test -n "$latest_err_file"
        set -a files_to_tail "$log_dir/$latest_err_file"
    end

    if count $files_to_tail > /dev/null
        for f in $files_to_tail
            echo " -> $f"
        end
        echo "=========================================="
        
        tail -f $files_to_tail
    else
        echo "No .out or .err files found in $log_dir"
        return 1
    end
end
