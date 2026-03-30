function ,sjob
    # Infer from current directory
    set PROJECT_DIR (pwd)
    set job_name (basename $PROJECT_DIR)
    # Defaults with option overrides
    set container_image (cat ~/.slurm/default_image)
    set CONTAINER_IMAGE $container_image
    set nodes 1
    set ntasks 1
    set gpus 1
    set nodelist ""
    argparse \
        'i/image=' \
        'n/nodes=' \
        't/ntasks=' \
        'g/gpus=' \
        'w/worker=' \
        -- $argv
    or return 1
    if set -q _flag_image;  set container_image $_flag_image;  end
    if set -q _flag_nodes;  set nodes $_flag_nodes;            end
    if set -q _flag_ntasks; set ntasks $_flag_ntasks;          end
    if set -q _flag_gpus;   set gpus $_flag_gpus;              end
    if set -q _flag_worker; set nodelist $_flag_worker;        end
    echo "Submitting job..."
    echo "  Name:    $job_name"
    echo "  Dir:     $PROJECT_DIR"
    echo "  Image:   $container_image"
    echo "  Nodes:   $nodes  Tasks: $ntasks  GPUs: $gpus"
    if test -n "$nodelist"
        echo "  Worker:  $nodelist"
    end
    echo ""
    docker cp ~/.slurm/job.sh slurmctld:/data/job.sh

    set nodelist_flag
    if test -n "$nodelist"
        set nodelist_flag --nodelist=$nodelist
    end

    set -x GITHUB_URL (git -C $PROJECT_DIR remote get-url origin)
    set -x GITHUB_BRANCH (git -C $PROJECT_DIR rev-parse --abbrev-ref HEAD)

    # docker cp ~/.slurm/job.sh slurmctld:/data/job.sh
    # docker cp $PROJECT_DIR/run.sh slurmctld:/data/run.sh
    docker cp ~/.slurm/job.sh slurmctld:/data/job.sh
    scp $PROJECT_DIR/run.sh richw@wpeb-server:~/slurm-worker/run.sh

    docker exec \
        -e JOB_NAME=$job_name \
        -e JOB_NAME=$job_name \
        -e PROJECT_DIR=$PROJECT_DIR \
        -e CONTAINER_IMAGE=$container_image \
        -e GITHUB_URL=$GITHUB_URL \
        -e GITHUB_BRANCH=$GITHUB_BRANCH \
        -e HOST_HOME=$HOME \
        slurmctld \
        sbatch \
            --job-name=$job_name \
            --output=/data/{$job_name}_%j.out \
            --nodes=$nodes \
            --ntasks=$ntasks \
            --partition=gpu \
            --gres=gpu:$gpus \
            --export=ALL \
            $nodelist_flag \
            /data/job.sh
end
