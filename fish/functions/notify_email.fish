# notify_email — send yourself an email from a fish script
# Usage: notify_email "Subject" "Body (optional)"
function notify_email
    set -l subject (string join " " $argv[1])
    set -l body    (string join " " $argv[2..-1])

    if test -z "$subject"
        echo "Usage: notify_email \"Subject\" \"Optional body\""
        return 1
    end

    if test -z "$body"
        set body "(no body)"
    end

    echo "$body" | mail -s "$subject" rich.white285@gmail.com
    and echo "📧 Email sent: $subject"
    or  echo "❌ Failed to send email — check: sudo journalctl -u postfix -n 20"
end

