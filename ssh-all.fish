#!/usr/bin/fish

if test (count $argv) -eq 0
    echo "Usage: ssh-all 'command-to-run'"
    exit 1
end

set -l cmd $argv

# Extract the machines list from .env
set -l machines (grep "^SSH_MACHINES=" .env | sed 's/SSH_MACHINES=//' | tr -d '"')

if test -z "$machines"
    echo "Error: No machines found in .env (looking for SSH_MACHINES=)"
    exit 1
end

for machine in (string split " " $machines)
    echo "--- Executing on: $machine ---"
    ssh -n $machine "$cmd"
end

echo "--- Finished ---"
