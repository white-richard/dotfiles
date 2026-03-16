function rclone-files --description "Copy a directory of files to a remote destination over SSH"
    set -l zip_path $argv[1]
    set -l ssh_alias $argv[2]
    set -l remote_dest $argv[3]

    # Normalize remote path
    if test "$remote_dest" = ~ -o "$remote_dest" = "~" -o -z "$remote_dest"
        set remote_dest ""
    end

    # rclone copy $zip_path :sftp,ssh="ssh $ssh_alias":$remote_dest --transfers 12 --order-by size,mixed,75 --max-backlog 10000 --b2-chunk-size 256M --progress --checksum --retries 5 --retries-sleep 30s

    rclone copy $zip_path :sftp,ssh="ssh $ssh_alias":$remote_dest \
    --transfers 12 \
    --order-by size,mixed,75 \
    --max-backlog 10000 \
    --progress \
    --checksum \
    --retries 5 \
    --retries-sleep 30s

end
