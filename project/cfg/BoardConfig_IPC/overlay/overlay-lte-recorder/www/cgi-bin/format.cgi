#!/bin/sh
# GET: progress log of the last format.  POST "confirm=FORMAT": start formatting.
printf 'Content-Type: text/plain; charset=utf-8\r\nCache-Control: no-store\r\n\r\n'
if [ "$REQUEST_METHOD" = POST ]; then
    body=$(head -c "${CONTENT_LENGTH:-0}")
    case "$body" in
        *confirm=FORMAT*)
            [ -e /tmp/sd_format.lock ] && { echo "BUSY"; exit 0; }
            setsid /usr/bin/sd_format.sh </dev/null >/dev/null 2>&1 &
            sleep 1; echo "STARTED" ;;
        *) echo "NOT CONFIRMED" ;;
    esac
else
    cat /tmp/sd_format.log 2>/dev/null
fi
