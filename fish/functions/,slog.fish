function ,slog
    set job_name (basename (pwd))
    set pattern "/data/$job_name""_*.out"

    set worker ""
    set i 1
    while test $i -le (count $argv)
        if test $argv[$i] = "-w"
            set i (math $i + 1)
            set worker $argv[$i]
        end
        set i (math $i + 1)
    end

    if test -z "$worker"
        docker exec slurmctld bash -c "tail -f -n +1 \$(ls -t $pattern | head -1)"
    else
        ssh $worker "docker exec $worker bash -c \"tail -f -n +1 \\\$(ls -t $pattern | head -1)\""
    end
end
