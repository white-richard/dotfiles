function ,cuda -d "Set CUDA_VISIBLE_DEVICES globally as a env var."
    set -gx CUDA_VISIBLE_DEVICES $argv
end
