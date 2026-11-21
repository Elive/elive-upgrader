#!/bin/bash

main() {
    if ! command -v crontab >/dev/null 2>&1; then
        return 0
    fi

    local cron_file="$HOME/.crontab"
    crontab -l 2>/dev/null > "$cron_file" || true

    if grep -v '^[[:space:]]*#' "$cron_file" | grep -q -- "elive-news.*--security-only" ; then
        return 0
    fi

    if grep -q "autostart/elive-news.desktop" "$cron_file"; then
        awk '
        /autostart\/elive-news\.desktop/ {
            print "# Elive news, every 2 days at 11 am is enough, so user may boot the desktop before that"
            print "5 11 */2 * *       elive-cron-gui-run  /etc/xdg/autostart/elive-news.desktop"
            print "# Show security update notifications, ultra-light run:"
            print "*/21 * * * *       elive-cron-gui-run elive-news --security-only"
            next
        }
        { print }
        ' "$cron_file" > "${cron_file}.tmp" && mv "${cron_file}.tmp" "$cron_file"
    else
        (
            cat "$cron_file"
            echo "# Elive news, every 2 days at 11 am is enough, so user may boot the desktop before that"
            echo "5 11 */2 * *       elive-cron-gui-run  /etc/xdg/autostart/elive-news.desktop"
            echo "# Show security update notifications, ultra-light run:"
            echo "*/21 * * * *       elive-cron-gui-run elive-news --security-only"
        ) > "${cron_file}.tmp" && mv "${cron_file}.tmp" "$cron_file"
    fi

    crontab ~/.crontab 2>/dev/null || true
}

main "$@"
