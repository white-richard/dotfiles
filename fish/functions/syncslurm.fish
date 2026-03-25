function syncslurm
    # Pull worker hostnames from slurm.conf, excluding the host itself
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
    sinfo
end