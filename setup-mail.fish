#!/usr/bin/env fish
# setup_mail.fish — one-time setup for postfix + Gmail relay
# Run with: fish setup_mail.fish

function setup_mail
    echo "=== Postfix + Gmail Relay Setup ==="
    echo ""

    # ── Detect OS ──────────────────────────────────────────────────────────────
    set -l os ""

    if test (uname) = "Darwin"
        set os "macos"
        echo "Detected: macOS"
    else if test -f /etc/arch-release
        set os "arch"
        echo "Detected: Arch Linux"
    else if test -f /etc/debian_version
        set os "ubuntu"
        echo "Detected: Ubuntu/Debian"
    else
        echo "❌ Unsupported OS. Only macOS, Arch, and Ubuntu/Debian are supported."
        return 1
    end

    # ── Gather credentials ─────────────────────────────────────────────────────
    echo ""
    read -P "Gmail address (you@gmail.com): " gmail_user
    read -P "Gmail App Password (16 chars, no spaces): " -s gmail_pass
    echo ""
    read -P "Send notifications to (can be same address): " notify_to

    if test -z "$gmail_user" -o -z "$gmail_pass" -o -z "$notify_to"
        echo "❌ All fields are required."
        return 1
    end

    # ── Install dependencies ───────────────────────────────────────────────────
    echo ""
    echo "▸ Installing packages..."

    switch $os
        case macos
            # Postfix is pre-installed on macOS, but ensure mailutils via brew
            if not command -q brew
                echo "  ⚠ Homebrew not found — skipping mailutils install."
                echo "  Postfix is built-in to macOS and will be used directly."
            else
                brew install mailutils 2>/dev/null
                or echo "  (mailutils already installed or skipped)"
            end

        case arch
            sudo pacman -Sy --noconfirm postfix s-nail
            sudo systemctl enable postfix

        case ubuntu
            # Pre-set answers to avoid interactive debconf prompt
            echo "postfix postfix/main_mailer_type select Internet Site" | sudo debconf-set-selections
            echo "postfix postfix/mailname string localhost" | sudo debconf-set-selections
            sudo apt-get update -qq
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y postfix mailutils
    end

    # ── Configure Postfix ──────────────────────────────────────────────────────
    echo "▸ Configuring Postfix..."

    set -l main_cf ""
    switch $os
        case macos
            set main_cf /etc/postfix/main.cf
        case arch ubuntu
            set main_cf /etc/postfix/main.cf
    end

    # Remove any existing relay/sasl lines so we don't duplicate on re-runs
    sudo sed -i.bak \
        -e '/^relayhost/d' \
        -e '/^smtp_sasl/d' \
        -e '/^smtp_tls/d' \
        -e '/^smtp_use_tls/d' \
        $main_cf

    # Append relay config
    echo "
# Gmail relay — added by setup_mail.fish
relayhost = [smtp.gmail.com]:587
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_tls_starttls_enforce = yes
smtp_use_tls = yes
" | sudo tee -a $main_cf > /dev/null

    # ── Write credentials ──────────────────────────────────────────────────────
    echo "▸ Writing credentials..."

    echo "[smtp.gmail.com]:587 $gmail_user:$gmail_pass" | sudo tee /etc/postfix/sasl_passwd > /dev/null
    sudo postmap /etc/postfix/sasl_passwd
    sudo chmod 600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db

    # ── Start / restart Postfix ────────────────────────────────────────────────
    echo "▸ (Re)starting Postfix..."

    switch $os
        case macos
            sudo postfix stop 2>/dev/null; sudo postfix start
        case arch ubuntu
            sudo systemctl restart postfix
    end

    # ── Install notify_email function ──────────────────────────────────────────
    echo "▸ Installing notify_email fish function..."

    set -l functions_dir ~/.config/fish/functions
    mkdir -p $functions_dir

    # Write the function, baking in the destination address
    set -l func_file $functions_dir/notify_email.fish
    echo "# notify_email — send yourself an email from a fish script
# Usage: notify_email \"Subject\" \"Body (optional)\"
function notify_email
    set -l subject (string join \" \" \$argv[1])
    set -l body    (string join \" \" \$argv[2..-1])

    if test -z \"\$subject\"
        echo \"Usage: notify_email \\\"Subject\\\" \\\"Optional body\\\"\"
        return 1
    end

    if test -z \"\$body\"
        set body \"(no body)\"
    end

    echo \"\$body\" | mail -s \"\$subject\" $notify_to
    and echo \"📧 Email sent: \$subject\"
    or  echo \"❌ Failed to send email — check: sudo journalctl -u postfix -n 20\"
end
" > $func_file

    echo ""
    echo "✅ Done! Testing with a quick email..."
    echo ""

    # ── Send a test email ──────────────────────────────────────────────────────
    echo "Setup complete on $os" | mail -s "✅ notify_email is working!" $notify_to

    echo "Check $notify_to for a confirmation email."
    echo ""
    echo "Usage:"
    echo "  notify_email \"Subject\""
    echo "  notify_email \"Subject\" \"Body text\""
    echo "  ./my_script.sh; notify_email \"Done\" \"Finished with status \$status\""
    echo ""
    echo "Tip: store your app password more securely with:"
    echo "  set -Ux GMAIL_APP_PASS 'yourpassword'"
end

setup_mail