function ,sjob
    # Infer from current directory
    set project_dir (pwd)
    set job_name (basename $project_dir)

    # Defaults with option overrides
    set container_image "pytorch/pytorch:2.11.0-cuda12.8-cudnn9-devel"
    set nodes 1
    set ntasks 1
    set gpus 1

    argparse \
        'i/image=' \
        'n/nodes=' \
        't/ntasks=' \
        'g/gpus=' \
        -- $argv
    or return 1

    if set -q _flag_image;  set container_image $_flag_image;  end
    if set -q _flag_nodes;  set nodes $_flag_nodes;            end
    if set -q _flag_ntasks; set ntasks $_flag_ntasks;          end
    if set -q _flag_gpus;   set gpus $_flag_gpus;              end

    echo "Submitting job..."
    echo "  Name:    $job_name"
    echo "  Dir:     $project_dir"
    echo "  Image:   $container_image"
    echo "  Nodes:   $nodes  Tasks: $ntasks  GPUs: $gpus"
    echo ""

    docker cp ~/.slurm/job.sh slurmctld:/data/job.sh

    docker exec \
        -e JOB_NAME=$job_name \
        -e PROJECT_DIR=$project_dir \
        -e CONTAINER_IMAGE=$container_image \
        slurmctld \
        sbatch \
            --job-name=$job_name \
            --output=/data/{$job_name}_%j.out \
            --nodes=$nodes \
            --ntasks=$ntasks \
            /data/job.sh
end

