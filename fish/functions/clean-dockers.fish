function clean-dockers --description "Close all dockers in docker ps"
    sudo docker stop $(sudo docker ps -q)
end