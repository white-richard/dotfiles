function ,gput --description 'Plot per-week GPU usage by user from ,gpuu history'
    if not command -q python3
        echo 'Error: ,gput requires python3' >&2
        return 1
    end
    # Locate the helper beside this file, including through the config symlink.
    set -l helper (path dirname (status filename))/__gput.py
    command python3 "$helper" $argv
end
