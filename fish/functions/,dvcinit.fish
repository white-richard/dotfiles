#!/usr/bin/env fish

function ,dvcinit
    # ── Configuration ─────────────────────────────────────────────────────────────

    # Use local scope to prevent interference
    set -l known_hosts \
        home-desktop \
        wpeb-mary \
        wpeb-print \
        wpeb-server

    set -l host_users \
        richiewhite \
        richw \
        richw \
        richw

    # Helper: look up the username for a given hostname.
    # We pass the lists in or use the parent's scope via 'v' (variable)
    function user_for_host -S -V known_hosts -V host_users
        set -l target $argv[1]
        for i in (seq (count $known_hosts))
            if test "$known_hosts[$i]" = "$target"
                echo $host_users[$i]
                return
            end
        end
        echo $USER   # fallback for unknown hosts
    end

    set -l core_remote "wpeb-print"

    # ── Derive cache path ────────────────────────────────────────────────────────

    set -l repo_abs (pwd)
    set -l cache_abs "$repo_abs/.dvc/cache"

    if string match -q "$HOME/*" $cache_abs
        set -l cache_rel_path (string replace "$HOME/" "" $cache_abs)
        
        # ── Sanity checks ─────────────────────────────────────────────────────────

        if not test -d .dvc
            echo "error: no .dvc directory found — run from repo root." >&2
            return 1
        end

        # Lowercase the hostname to ensure a match
        set -l current_host (hostname -s | string lower)

        # ── Write .dvc/config ─────────────────────────────────────────────────────
        echo "→ Writing .dvc/config"

        printf '[cache]\n'                      > .dvc/config
        printf '    type = "hardlink,symlink"\n' >> .dvc/config
        printf '    protected = true\n'          >> .dvc/config
        printf '[core]\n'                        >> .dvc/config
        printf '    autostage = true\n'          >> .dvc/config
        printf '    remote = %s\n' $core_remote  >> .dvc/config

        for host in $known_hosts
            set -l remote_user (user_for_host $host)
            # Use double brackets for DVC remote naming format
            printf "\n['remote \"%s\"']\n" $host >> .dvc/config
            printf '    url = ssh://%s@%s/home/%s/%s\n' $remote_user $host $remote_user $cache_rel_path >> .dvc/config
        end

        # ── Write .dvc/config.local ───────────────────────────────────────────────

        if contains -- $current_host $known_hosts
            echo "→ Writing .dvc/config.local for known host: $current_host"

            printf '[core]\n'                          > .dvc/config.local
            printf '    remote = %s\n' $core_remote    >> .dvc/config.local
            printf "\n['remote \"%s\"']\n" $current_host >> .dvc/config.local
            printf '    url = %s/%s\n' $HOME $cache_rel_path >> .dvc/config.local
        else
            # Explicitly remove old local config if we are now on an unknown host
            rm -f .dvc/config.local
            echo "→ Skipping config.local — '$current_host' is not a known host."
        end

        # ── Summary ───────────────────────────────────────────────────────────────
        echo -e "\nDone. Generated files:\n"
        echo ".dvc/config:"
        sed 's/^/    /' .dvc/config
        
        if test -f .dvc/config.local
            echo -e "\n.dvc/config.local:"
            sed 's/^/    /' .dvc/config.local
        end

    else
        echo "error: repo ($repo_abs) is not under \$HOME." >&2
        return 1
    end
end