function rclone-serve --description "Serve a directory using Rclone for Rclone copy."

    if test (count $argv) -lt 2
        echo "Error: Expected at least 2 arguments."
    end

    set -l dir $argv[1]
    set -l tailscale_ip $argv[2]
    set -l port 8080


    if test (count $argv) -ge 3
        set port $argv[3]
    end

    rclone serve http $dir --addr $tailscale_ip:$port

end
