#!/bin/sh
# Status screen on the 0.96" OLED, refreshed every 5 s.
# Text also goes to /tmp/oled.txt (handy over SSH and for the web page).
CONF=/userdata/recorder.conf
CAM_IP=10.5.4.10
DEVNAME=$(hostname)
SEGMENT_MIN=15
OLED_DIM_MIN=10
[ -f "$CONF" ] && . "$CONF"
MNT=/mnt/sdcard
OUT=/tmp/oled.txt
DOT=$(printf '\007'); SQ=$(printf '\376'); BLK=$(printf '\333'); DEG=$(printf '\370')
BL=$(ls -d /sys/class/backlight/* 2>/dev/null | head -n 1)
START=$(cut -d. -f1 /proc/uptime)
SIG_AT=0; RSRP=""; OPER=""

bright() { [ -n "$BL" ] && [ "$(cat $BL/brightness)" != "$1" ] && echo "$1" > "$BL/brightness"; }

line_top() {
    if [ -f /tmp/time_ok ]; then t=$(date +%H:%M); else t="--:--"; fi
    printf '%-15.15s %5s\n' "$DEVNAME" "$t"
}

line_rec() {
    # the recorder writes "rec <epoch when current file started>" to /tmp/rec.status
    if [ -f /tmp/rec.status ] && read st since < /tmp/rec.status && [ "$st" = rec ]; then
        a=$(( $(date +%s) - since ))
        printf '%s REC  %02d:%02d   %sm\n' "$DOT" $((a / 60 % 100)) $((a % 60)) "$SEGMENT_MIN"
        return
    fi
    if [ "$(cat /tmp/sd.status 2>/dev/null)" != ok ]; then why="no SD card"
    elif [ "$CAM" != ok ]; then why="no camera"
    elif [ ! -f /tmp/time_ok ]; then why="no time"
    else why="stopped"; fi
    printf '!%s STOP %s\n' "$SQ" "$why"
}

line_lte() {
    now=$(cut -d. -f1 /proc/uptime)
    if [ $((now - SIG_AT)) -ge 30 ]; then
        SIG_AT=$now
        RSRP=$(uqmi -d /dev/cdc-wdm0 --get-signal-info 2>/dev/null | sed -n 's/.*"rsrp":\([-0-9]*\).*/\1/p')
        OPER=$(uqmi -d /dev/cdc-wdm0 --get-serving-system 2>/dev/null | sed -n 's/.*"plmn_description":"\([^"]*\)".*/\1/p')
    fi
    if ! grep -q online /tmp/lte.status 2>/dev/null; then
        printf '!LTE %-4s NO INTERNET\n' "${RSRP:---}"; return
    fi
    b=""
    if [ -n "$RSRP" ]; then
        for lim in -115 -105 -95 -85; do [ "$RSRP" -ge $lim ] && b="$b$BLK"; done
    fi
    printf 'LTE%4sdBm %-5.5s %s\n' "${RSRP:---}" "$OPER" "$b"
}

line_vpn() {
    ip link show wg0 >/dev/null 2>&1 || { echo "VPN not set"; return; }
    a=$(ip -4 -o addr show wg0 | awk '{print $4}' | cut -d/ -f1)
    hs=$(wg show wg0 latest-handshakes 2>/dev/null | awk '{print $2}' | sort -n | tail -n 1)
    if [ -n "$hs" ] && [ "$hs" -gt 0 ] && [ $(( $(date +%s) - hs )) -lt 180 ]; then
        printf 'VPN %-14s OK\n' "$a"
    else
        printf '!VPN %-12s DOWN\n' "$a"
    fi
}

line_sd() {
    case "$(cat /tmp/sd.status 2>/dev/null)" in
        ok) set -- $(df -k "$MNT" | awk 'NR==2{print $2, $3, $5}')
            printf 'SD  %d/%dG %9s\n' $(( ($2 + 524288) / 1048576 )) $(( ($1 + 524288) / 1048576 )) "$3" ;;
        absent)     echo "!SD  NO CARD" ;;
        readonly)   echo "!SD  READ-ONLY" ;;
        unknown)    echo "!SD  BAD FORMAT" ;;
        formatting) echo "SD  formatting..." ;;
        *)          echo "SD  ..." ;;
    esac
}

line_cam() {
    if [ "$CAM" = ok ]; then printf 'CAM %-14s OK\n' "$CAM_IP"
    else printf '!CAM %-12s OFF\n' "$CAM_IP"; fi
}

line_nas() {
    # the sync script writes "ok <epoch>" or "fail <epoch>" to /tmp/nas.status
    if [ -f /tmp/nas.status ] && read st at < /tmp/nas.status; then
        t=$(date -d "@$at" +%H:%M 2>/dev/null)
        if [ "$st" = ok ]; then printf 'NAS sync %-9s OK\n' "$t"
        else printf '!NAS fail %-8s\n' "$t"; fi
    else
        echo "NAS not set"
    fi
}

line_sys() {
    tc=$(( $(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0) / 1000 ))
    u=$(cut -d. -f1 /proc/uptime)
    printf '%d%sC   up %dd%02dh%02dm\n' "$tc" "$DEG" $((u / 86400)) $((u / 3600 % 24)) $((u / 60 % 60))
}

while true; do
    if ping -c 1 -W 1 "$CAM_IP" >/dev/null 2>&1; then CAM=ok; else CAM=down; fi
    { line_top; line_rec; line_lte; line_vpn; line_sd; line_cam; line_nas; line_sys; } > $OUT.new
    mv $OUT.new $OUT
    oledtext < $OUT
    # full brightness for the first minutes and while something is wrong, then dim
    now=$(cut -d. -f1 /proc/uptime)
    if grep -q '^!' $OUT || [ $((now - START)) -lt $((OLED_DIM_MIN * 60)) ]; then bright 255; else bright 10; fi
    sleep 5
done
