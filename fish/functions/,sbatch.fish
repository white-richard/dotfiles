#!/usr/bin/env fish

function ,sbatch
    set job_script "$HOME/.dotfiles/job.sh"
    sbatch $job_script $argv
end
