function rclone-big --description "Copy large zip files to a remote destination over SSH"
    set -l zip_path $argv[1]
    set -l ssh_alias $argv[2]
    set -l remote_dest $argv[3]

    # Normalize remote path
    if test "$remote_dest" = ~ -o "$remote_dest" = "~" -o -z "$remote_dest"
        set remote_dest ""
    end

    rclone copy $zip_path :sftp,ssh="ssh $ssh_alias":$remote_dest \
        --progress \
        --transfers 1 \
        --sftp-concurrency 32 \
        --sftp-chunk-size 255k \
        --buffer-size 256M \
        --use-mmap \
        --checksum \
        --retries 10 \
        --retries-sleep 30s \
        --low-level-retries 20 \
        --timeout 2h \
        --contimeout 60s \
        --log-level ERROR
end