function lsz --description 'Print file sizes of files and dirs in current directory'
    # Parse arguments for -s or --sudo
    argparse 's/sudo' -- $argv
    or return 1

    if set -ql _flag_sudo
        sudo du -sch (ls -A) | sort -h
    else
        du -sch (ls -A) | sort -h
    end
end
