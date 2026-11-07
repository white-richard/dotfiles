function ,use --description 'Summarize who is using this node, for how long, and what looks wrong'
    if not command -q python3
        echo 'Error: ,use requires python3' >&2
        return 1
    end
    # Locate the helper beside this file, including through the config symlink.
    set -l helper (path dirname (status filename))/__use.py
    command python3 "$helper" $argv
end
