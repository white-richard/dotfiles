#!/usr/bin/env fish

function ,dvcinit
    # ── Configuration ─────────────────────────────────────────────────────────────
    set -l known_hosts home-desktop wpeb-mary wpeb-print wpeb-server
    set -l host_users richiewhite richw richw richw
    set -l core_remote "wpeb-print"

    # ── Identify Host from Tailscale ─────────────────────────────────────────────
    # We take the first line and 2nd column
    set -l current_host (tailscale status | head -n1 | awk '{print $2}' | string lower | string trim)

    # ── Nested Helper ─────────────────────────────────────────────────────────────
    # Inherits lists from parent scope to find the correct SSH username
    function _get_user -V known_hosts -V host_users
        set -l target $argv[1]
        for i in (seq (count $known_hosts))
            if test "$known_hosts[$i]" = "$target"
                echo $host_users[$i]
                return 0
            end
        end
        echo $USER # Fallback
    end

    # ── Path Logic ────────────────────────────────────────────────────────────────
    set -l repo_abs (pwd)
    if not test -d .dvc
        echo "error: .dvc directory not found. Run from repo root." >&2
        return 1
    end
    set -l cache_rel_path (string replace "$HOME/" "" "$repo_abs/.dvc/cache")

    # ── Write .dvc/config (Shared) ────────────────────────────────────────────────
    echo "→ Writing .dvc/config (Self identified as: $current_host)"

    printf '[cache]\n    type = "hardlink,symlink"\n    protected = true\n' > .dvc/config
    printf '[core]\n    autostage = true\n    remote = %s\n' $core_remote >> .dvc/config

    for host in $known_hosts
        set -l r_user (_get_user $host)
        printf "\n['remote \"%s\"']\n" $host >> .dvc/config
        # Format: ssh://user@host/absolute/path/to/home/user/cache
        printf '    url = ssh://%s@%s/home/%s/%s\n' $r_user $host $r_user $cache_rel_path >> .dvc/config
    end

    # ── Write .dvc/config.local (Machine Override) ───────────────────────────────
    if contains -- $current_host $known_hosts
        echo "→ Match found! Writing .dvc/config.local"

        printf "[core]\n    remote = %s\n\n['remote \"%s\"']\n    url = %s/%s\n" \
            $core_remote $current_host $HOME $cache_rel_path > .dvc/config.local
    else
        echo "→ No match for '$current_host' in known_hosts."
        echo "  (Checked against: $known_hosts)"
        rm -f .dvc/config.local
    end

    # ── Verification ──────────────────────────────────────────────────────────────
    if test -f .dvc/config.local
        echo "Created .dvc/config.local successfully."
    else
        echo "config.local was not created."
    end
end
