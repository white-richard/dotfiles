#!/usr/bin/env fish

function ,dvcinit
    # ── Configuration ─────────────────────────────────────────────────────────────

    # Parallel lists — indices must stay in sync
    set known_hosts \
        home-server \
        home-desktop \
        wpeb-mary \
        wpeb-print \
        wpeb-server

    set host_users \
        richw \
        richiewhite \
        richw \
        richw \
        richw

    # Helper: look up the username for a given hostname.
    function user_for_host
        set target $argv[1]
        for i in (seq (count $known_hosts))
            if test "$known_hosts[$i]" = "$target"
                echo $host_users[$i]
                return
            end
        end
        echo $USER   # fallback for unknown hosts
    end

    # The remote DVC will use by default
    set core_remote "wpeb-print"

    # ── Derive cache path from CWD ────────────────────────────────────────────────

    set repo_abs (pwd)
    set cache_abs "$repo_abs/.dvc/cache"

    if string match -q "$HOME/*" $cache_abs
        set cache_rel_path (string replace "$HOME/" "" $cache_abs)
    else
        echo "error: repo ($repo_abs) is not under \$HOME — cannot derive a portable cache path." >&2
        exit 1
    end

    # ── Sanity checks ─────────────────────────────────────────────────────────────

    if not test -d .dvc
        echo "error: no .dvc directory found — run this script from the root of the repo." >&2
        exit 1
    end

    set current_host (hostname -s)

    # ── Write .dvc/config (shared / committed) ────────────────────────────────────
    # Contains ALL remotes as SSH entries so unknown hosts can still push/pull.

    echo "→ Writing .dvc/config"

    printf '[cache]\n'                       > .dvc/config
    printf '    type = "hardlink,symlink"\n' >> .dvc/config
    printf '    protected = true\n'          >> .dvc/config
    printf '[core]\n'                        >> .dvc/config
    printf '    autostage = true\n'          >> .dvc/config
    printf '    remote = %s\n' $core_remote  >> .dvc/config

    for host in $known_hosts
        set remote_user (user_for_host $host)
        printf "\n['remote \"%s\"']\n" $host >> .dvc/config
        printf '    url = ssh://%s/home/%s/%s\n' $host $remote_user $cache_rel_path >> .dvc/config
    end

    # ── Write .dvc/config.local (machine-specific / gitignored) ───────────────────
    # Only written when we are on a known host — overrides that host's remote with
    # a local (non-SSH) path.  On unknown hosts (containers, etc.) this file is
    # left absent and the SSH remotes in .dvc/config are used as-is.

    if contains -- $current_host $known_hosts
        set config_local ".dvc/config.local"
        echo "→ Writing $config_local for known host: $current_host"

        printf '[core]\n'                         > $config_local
        printf '    remote = %s\n' $core_remote  >> $config_local
        printf "\n['remote \"%s\"']\n" $current_host >> $config_local
        printf '    url = %s/%s\n' $HOME $cache_rel_path >> $config_local
    else
        echo "→ Skipping config.local — '$current_host' is not a known host; SSH remotes in .dvc/config will be used."
    end

    # ── Summary ───────────────────────────────────────────────────────────────────

    echo ""
    echo "Done.  Generated files:"
    echo ""
    echo "  .dvc/config  (commit this)"
    cat .dvc/config | sed 's/^/    /'

    if test -f .dvc/config.local
        echo ""
        echo "  .dvc/config.local  (gitignored — machine-specific)"
        cat .dvc/config.local | sed 's/^/    /'
    end

end
