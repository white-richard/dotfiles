function rclone-copy --description "Rclone copy from a Rclone-serve dir."

    if test (count $argv) -lt 3
        echo "Error: Expected at least 3 arguments."
    end

    set -l file_path $argv[1]
    set -l save_dir $argv[2]
    set -l tailscale_ip $argv[3]
    set -l port 8080


    if test (count $argv) -ge 4
        set port $argv[4]
    end

    rclone copy :http:$file_path $save_dir \
      --http-url http://$tailscale_ip:$port \
      --progress \
      --transfers 8 \
      --multi-thread-streams 8

end

