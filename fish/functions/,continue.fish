# Example: ,continue 23:30 my-session OR ,continue 23:30 my-session:0.1 for a specific pane
function ,continue --description "Send 'Continue.' to a tmux target at a specific time"
    if test (count $argv) -lt 2
        echo "Usage: ,continue TIME TMUX_TARGET"
        echo "Example: ,continue 23:30 my-session"
        echo "Example: ,continue 02:15 my-session:0.1"
        return 1
    end

    set -l when $argv[1]
    set -l target $argv[2]

    set -l target_ts (date -d "today $when" +%s 2>/dev/null)

    if test -z "$target_ts"
        echo "Invalid time: $when"
        return 1
    end

    set -l now (date +%s)

    # If the time already passed today, schedule it for tomorrow.
    if test $target_ts -le $now
        set target_ts (date -d "tomorrow $when" +%s)
    end

    if not tmux has-session -t "$target" 2>/dev/null
        echo "tmux target not found: $target"
        return 1
    end

    set -l delay (math "$target_ts - $now")
    set -l pretty_time (date -d "@$target_ts" "+%Y-%m-%d %H:%M:%S")

    echo "Will send 'Continue.' to '$target' at $pretty_time"

    begin
        sleep $delay

        tmux send-keys -t "$target" -l "Continue."
        tmux send-keys -t "$target" Enter
    end >/dev/null 2>&1 &

    disown
end
