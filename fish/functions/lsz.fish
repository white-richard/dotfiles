function lsz --description 'Print file sizes of files and dirs in current directory'
    sudo du -sch (ls -A) | sort -h
end
