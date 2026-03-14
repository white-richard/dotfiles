function lsz --description 'Print file sizes of files and dirs in current directory'
    find . -maxdepth 1 ! -name "." -print0 | xargs -0 du -sh 2>/dev/null | sort -h
end
