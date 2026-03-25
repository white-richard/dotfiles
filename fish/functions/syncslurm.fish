function syncslurm
    set host (hostname)
    set workers (grep "^NodeName=" /etc/slurm/slurm.conf \
        | grep -oP 'NodeName=\K\S+' \
        | grep -v $host)

    for worker in $workers
        echo "Syncing to $worker..."
        scp /etc/slurm/slurm.conf richw@$worker:/tmp/slurm.conf
        ssh richw@$worker "sudo mv /tmp/slurm.conf /etc/slurm/slurm.conf && sudo systemctl restart slurmd"
    end

    sudo systemctl restart slurmctld

    # Resume any nodes that went unk after restart
    for node in $host $workers
        sudo scontrol update NodeName=$node State=RESUME 2>/dev/null
    end

    sinfo
end