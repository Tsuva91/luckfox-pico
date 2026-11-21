#!/bin/sh
. /usr/lib/recstat.sh
collect
[ "$1" = "--raw" ] || printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'
js() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
n() { case "$1" in ''|-|*[!0-9.-]*) echo null ;; *) echo "$1" ;; esac; }
cat <<J
{"name":"$(js "$S_NAME")","time":"$S_TIME","time_ok":$S_TIME_OK,"now":$NOW,"uptime":$S_UP,
"temp":$S_TEMP,"load":"$S_LOAD","mem_mb":$S_MEM,"version":"$(js "$S_VER")",
"lte":{"state":"$S_LTE","rsrp":$(n $S_RSRP),"rsrq":$(n $S_RSRQ),"band":"$(js "$S_BAND")","oper":"$(js "$S_OPER")","ip":"$S_LTE_IP","rx":$S_RX,"tx":$S_TX},
"sd":{"state":"$S_SD","total_kb":$S_SD_TOTAL,"used_kb":$S_SD_USED,"pct":$S_SD_PCT},
"rec":{"state":"$S_REC","since":$S_REC_SINCE,"why":"$(js "$S_REC_WHY")","segment_min":$SEGMENT_MIN},
"cam":{"ip":"$CAM_IP","up":$S_CAM},
"vpn":{"ip":"$S_VPN_IP","handshake_age":$S_VPN_HS},
"nas":{"state":"$S_NAS","at":$S_NAS_AT},
"web_default_pass":$([ -z "$WEB_PASS" ] && echo 1 || echo 0)}
J
