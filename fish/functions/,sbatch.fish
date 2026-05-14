#!/usr/bin/env fish

function ,sbatch
    set -l job_script "$HOME/.dotfiles/job.sh"
    set -x REPO_PATH $PWD

    # Capture the commit at submit time and export it
    if set -q GIT_COMMIT
        set -x COMMIT $GIT_COMMIT
    else
        set -x COMMIT (git -C (pwd) rev-parse HEAD)
    end

    # Scan argv for --gpu/-g to derive --gres=gpu:N for sbatch.
    # Supports --gpu 4, --gpu=4, --gpu 4,5, --gpu=4,5
    set -l gpu_val ""
    set -l i 1
    while test $i -le (count $argv)
        switch $argv[$i]
            case '--gpu' '-g'
                set i (math $i + 1)
                set gpu_val $argv[$i]
            case '--gpu=*'
                set gpu_val (string sub -s 7 $argv[$i])
            case '-g=*'
                set gpu_val (string sub -s 4 $argv[$i])
        end
        set i (math $i + 1)
    end

    # Count comma-separated GPU indices to determine how many to request
    set -l num_gpus 1
    if test -n "$gpu_val"
        set num_gpus (count (string split ',' $gpu_val))
    end

    sbatch --gres=gpu:$num_gpus $job_script $argv
end
