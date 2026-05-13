#!/usr/bin/env fish

function ,sbatch
    set -l job_script "$HOME/.dotfiles/job.sh"
    
    # Capture the commit at submit time and export it
    if set -q GIT_COMMIT
        set -x COMMIT $GIT_COMMIT
    else
        set -x COMMIT (git -C (pwd) rev-parse HEAD)
    end

    # Call sbatch with the arguments
    sbatch $job_script $argv
end
