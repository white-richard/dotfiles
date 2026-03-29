#!/usr/bin/env fish
# setup_dvc_config.fish
# Sets up .dvc/config (global) and .dvc/config.local (per-host) for the mammoclip project.

# ── Configuration ─────────────────────────────────────────────────────────────

set known_hosts \
    home-server \
    home-desktop \
    wpeb-mary \
    wpeb-print \
    wpeb-server

# Derive the cache path from the current working directory.
# We store the path relative to $HOME so it resolves correctly on each host.
set repo_abs (pwd)
set cache_abs "$repo_abs/.dvc/cache"

# Strip $HOME prefix to get a portable relative path (e.g. .code/mammoclip/.dvc/cache)
if string match -q "$HOME/*" $cache_abs
    set cache_rel_path (string replace "$HOME/" "" $cache_abs)
else
    echo "error: repo ($repo_abs) is not under \$HOME — cannot derive a portable cache path." >&2
    exit 1
end

# SSH identity file (uses $HOME at write-time, not hardcoded username)
set keyfile "$HOME/.ssh/id_ed25519"

# The remote that DVC will use by default
set core_remote "wpeb-print"

# ── Sanity checks ─────────────────────────────────────────────────────────────

if not test -d .dvc
    echo "error: no .dvc directory found — run this script from the root of the mammoclip repo." >&2
    exit 1
end

set current_host (hostname -s)

if not contains -- $current_host $known_hosts
    echo "warning: current hostname '$current_host' is not in the known-hosts list."
    echo "         It will be added as a local remote; add it to the script's known_hosts list to silence this."
    set known_hosts $known_hosts $current_host
end

# ── Write .dvc/config (shared / committed) ────────────────────────────────────

echo "→ Writing .dvc/config"

cat > .dvc/config << 'EOF'
[cache]
    type = "hardlink,symlink"
    protected = true
[core]
    autostage = true
EOF

# ── Write .dvc/config.local (machine-specific / gitignored) ───────────────────

set config_local ".dvc/config.local"

echo "→ Writing $config_local for host: $current_host"

# Header — core remote is always wpeb-print
printf '[core]\n' > $config_local
printf '    remote = %s\n' $core_remote >> $config_local

for host in $known_hosts
    printf "\n['remote \"%s\"']\n" $host >> $config_local

    if test "$host" = "$current_host"
        # Local (non-SSH) entry for the machine we are currently on
        printf '    url = %s/%s\n' $HOME $cache_rel_path >> $config_local
    else
        # SSH entry for every other known host
        printf '    url = ssh://%s/home/%s/%s\n' $host $USER $cache_rel_path >> $config_local
        printf '    keyfile = %s\n' $keyfile >> $config_local
    end
end

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "Done.  Generated files:"
echo ""
echo "  .dvc/config  (commit this)"
cat .dvc/config | sed 's/^/    /'

echo ""
echo "  $config_local  (gitignored — machine-specific)"
cat $config_local | sed 's/^/    /'
