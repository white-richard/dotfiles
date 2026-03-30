function ,slog
    set job_name (basename (pwd))
    argparse \
        'w/worker=' \
        -- $argv
    or return 1

    if set -q _flag_worker
        # Find the most recent job ID for this job name that ran on the specified node
        set job_id (docker exec slurmctld bash -c \
            "sacct -n -X --name=$job_name --nodelist=$_flag_worker --format=JobID --state=ANY \
             | tail -1 | tr -d ' '")
        if test -z "$job_id"
            echo "No jobs found for '$job_name' on worker '$_flag_worker'"
            return 1
        end
        echo "Tailing job $job_id (ran on $_flag_worker)..."
        docker exec slurmctld bash -c "tail -f -n +1 /data/{$job_name}_{$job_id}.out"
    else
        set pattern "/data/$job_name""_*.out"
        docker exec slurmctld bash -c "tail -f -n +1 \$(ls -t $pattern | head -1)"
    end
end
