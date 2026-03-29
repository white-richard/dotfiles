function ,slog
    set job_name (basename (pwd))
    set pattern "/data/$job_name""_*.out"
    docker exec slurmctld bash -c "tail -f -n +1 \$(ls -t $pattern | head -1)"
end
