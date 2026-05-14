#!/bin/bash
#SBATCH --job-name=train
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err
#SBATCH --partition=ankita
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --gres=gpu:1
#SBATCH --time=24:00:00
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=98299003+white-richard@users.noreply.github.com

export PYTHONUNBUFFERED=1

# ==========================================
# Parse Command Line Arguments
# ==========================================

GPU_INDEX=4

while [[ $# -gt 0 ]]; do
    case "$1" in
        -g|--gpu)
            if [ -z "$2" ]; then
                echo "ERROR: --gpu requires a value"
                exit 1
            fi
            GPU_INDEX="$2"
            shift 2
            ;;
        --gpu=*)
            GPU_INDEX="${1#*=}"
            shift
            ;;
        --)
            shift
            break
            ;;
        -*)
            break
            ;;
        *)
            break
            ;;
    esac
done

export CUDA_VISIBLE_DEVICES="$GPU_INDEX"

# Count GPUs in the (possibly comma-separated) list and export for training scripts
NUM_GPUS=$(echo "$GPU_INDEX" | awk -F',' '{print NF}')
export NUM_GPUS

# Assumed to come from ,sbatch
# REPO_PATH=$PWD
REPO_NAME=$(basename "$REPO_PATH")
# Assumed to be made by sbatch
# COMMIT=$(git -C "$REPO_PATH" rev-parse HEAD)
WORKTREE_PATH="tmp/${REPO_NAME}_${SLURM_JOB_ID}"

# ==========================================
# Setup Environment
# ==========================================

cd "$REPO_PATH" || exit 1

# if [ -d "$REPO_PATH/.git" ]; then
#     echo "ERROR: Working directory is not a git repository."
#     exit 1
# fi

mkdir -p logs

git -C "$REPO_PATH" worktree add "$WORKTREE_PATH" "$COMMIT"

fish setup.fish
source .venv/bin/activate

# ==========================================
# Run Code
# ==========================================

SCRIPT=$1
if [ -z "$SCRIPT" ]; then
    echo "ERROR: Missing script argument"
    exit 1
fi

case "${SCRIPT##*.}" in
py) INTERP="python" ;;
sh) INTERP="sh" ;;
bash) INTERP="bash" ;;
fish) INTERP="fish" ;;
*)
    echo "ERROR: Unknown script type '${SCRIPT##*.}'. Supported: .py, .sh, .bash, .fish"
    exit 1
    ;;
esac

echo "=========================================="
echo "Executing: $INTERP $@"
echo "=========================================="

$INTERP "$WORKTREE_PATH/$SCRIPT" "${@:2}"

git -C "$REPO_PATH" worktree remove "$WORKTREE_PATH"
