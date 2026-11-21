#!/bin/sh
# POST "do=lte_restart" | "do=oled_restart" | "do=reboot"
printf 'Content-Type: text/plain\r\nCache-Control: no-store\r\n\r\n'
[ "$REQUEST_METHOD" = POST ] || { echo "POST only"; exit 0; }
body=$(head -c "${CONTENT_LENGTH:-0}")
case "$body" in
    *do=lte_restart*) setsid /etc/init.d/S45lte restart </dev/null >/dev/null 2>&1 & echo OK ;;
    *do=oled_restart*) setsid /etc/init.d/S95oled restart </dev/null >/dev/null 2>&1 & echo OK ;;
    *do=reboot*) logger -t web "reboot requested"; (sleep 2; sync; reboot) </dev/null >/dev/null 2>&1 & echo OK ;;
    *) echo "unknown action" ;;
esac
