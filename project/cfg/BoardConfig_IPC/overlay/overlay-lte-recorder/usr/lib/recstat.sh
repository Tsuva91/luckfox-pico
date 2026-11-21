# Shared status collector for /usr/bin/status (text) and /www/cgi-bin/status.cgi (JSON).
# Usage: . /usr/lib/recstat.sh; collect
CONF=/userdata/recorder.conf
CAM_IP=10.5.4.10
SEGMENT_MIN=15
DEVNAME=$(hostname)
WEB_PASS=
[ -f "$CONF" ] && . "$CONF"

collect() {
    NOW=$(date +%s)
    S_NAME=$DEVNAME
    S_TIME=$(date '+%F %T')
    [ -f /tmp/time_ok ] && S_TIME_OK=1 || S_TIME_OK=0
    S_UP=$(cut -d. -f1 /proc/uptime)
    S_TEMP=$(( $(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0) / 1000 ))
    S_LOAD=$(cut -d' ' -f1 /proc/loadavg)
    S_MEM=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo)
    S_VER=$(cat /etc/recorder-version 2>/dev/null)

    # LTE (cached by S45lte once a minute)
    S_LTE=offline
    grep -q online /tmp/lte.status 2>/dev/null && S_LTE=online
    S_RSRP=; S_RSRQ=; S_SNR=; S_BAND=; S_OPER=
    [ -f /tmp/lte.signal ] && read S_RSRP S_RSRQ S_SNR S_BAND S_OPER < /tmp/lte.signal
    S_LTE_IP=$(ip -4 -o addr show wwan0 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
    S_RX=$(cat /sys/class/net/wwan0/statistics/rx_bytes 2>/dev/null || echo 0)
    S_TX=$(cat /sys/class/net/wwan0/statistics/tx_bytes 2>/dev/null || echo 0)

    # SD
    S_SD=$(cat /tmp/sd.status 2>/dev/null || echo unknown)
    S_SD_TOTAL=0; S_SD_USED=0; S_SD_PCT=0; S_SD_FILES=0
    if [ "$S_SD" = ok ] || [ "$S_SD" = readonly ]; then
        set -- $(df -k /mnt/sdcard 2>/dev/null | awk 'NR==2{print $2, $3, $5}')
        S_SD_TOTAL=${1:-0}; S_SD_USED=${2:-0}; S_SD_PCT=${3%\%}; S_SD_PCT=${S_SD_PCT:-0}
    fi

    # recorder writes "rec <epoch file started>" or "stop <reason>"
    S_REC=stop; S_REC_SINCE=0; S_REC_WHY=
    if [ -f /tmp/rec.status ]; then
        read a b < /tmp/rec.status
        if [ "$a" = rec ]; then S_REC=rec; S_REC_SINCE=$b; else S_REC_WHY=$b; fi
    fi
    if [ "$S_REC" != rec ] && [ -z "$S_REC_WHY" ]; then
        if [ "$S_SD" != ok ]; then S_REC_WHY="no SD card"
        elif [ ! -f /tmp/time_ok ]; then S_REC_WHY="no time"
        else S_REC_WHY="recorder not running"; fi
    fi

    # camera
    if ping -c 1 -W 1 "$CAM_IP" >/dev/null 2>&1; then S_CAM=1; else S_CAM=0; fi

    # VPN
    S_VPN_IP=$(ip -4 -o addr show wg0 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
    S_VPN_HS=-1
    if [ -n "$S_VPN_IP" ]; then
        hs=$(wg show wg0 latest-handshakes 2>/dev/null | awk '{print $2}' | sort -n | tail -n 1)
        [ -n "$hs" ] && [ "$hs" -gt 0 ] && S_VPN_HS=$((NOW - hs))
    fi

    # NAS sync writes "ok <epoch>" / "fail <epoch>"
    S_NAS=none; S_NAS_AT=0
    [ -f /tmp/nas.status ] && read S_NAS S_NAS_AT < /tmp/nas.status
}
