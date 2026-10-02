function ,gpuu --description 'Report GPU users and recorded last use; start background tracking automatically'
    if not command -q python3
        echo 'Error: ,gpuu requires python3' >&2
        return 1
    end
    # Locate the helper beside this file, including through the config symlink.
    set -l helper (path dirname (status filename))/__gpuu.py
    command python3 "$helper" $argv
end
