function ,tail -d "Tail the nth most recent .out and .err files in a log directory"
    argparse 'n/nth=' -- $argv
    or return 1

    set -l nth 1
    if set -q _flag_n
        set nth $_flag_n
    end

    set -l log_dir $argv[1]
    if test -z "$log_dir"
        set log_dir "logs"
    end

    if not test -d "$log_dir"
        echo "Error: Directory '$log_dir' does not exist."
        return 1
    end

    # Find the nth most recent .out and .err files
    set -l latest_out_file (ls -t $log_dir | grep '\.out$' | sed -n "$nth"p)
    set -l latest_err_file (ls -t $log_dir | grep '\.err$' | sed -n "$nth"p)

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
        echo "Error: Could not find log pair #$nth in $log_dir"
        return 1
    end
end
