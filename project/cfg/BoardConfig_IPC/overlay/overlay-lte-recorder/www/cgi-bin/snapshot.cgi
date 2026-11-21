#!/bin/sh
# JPEG from the camera (Hikvision ISAPI, digest auth). CAM_USER/CAM_PASS in recorder.conf.
. /userdata/recorder.conf 2>/dev/null
CAM_IP=${CAM_IP:-10.5.4.10}
f=/tmp/snap.$$.jpg
if [ -n "$CAM_USER" ] && curl -s -m 8 --digest -u "$CAM_USER:$CAM_PASS" -o $f \
     "http://$CAM_IP/ISAPI/Streaming/channels/${SNAP_CHANNEL:-102}/picture" && [ -s $f ] \
     && head -c 2 $f | od -An -tx1 | grep -q 'ff d8'; then
    printf 'Content-Type: image/jpeg\r\nCache-Control: no-store\r\n\r\n'
    cat $f
else
    printf 'Status: 503 Service Unavailable\r\nContent-Type: text/plain\r\n\r\n'
    [ -z "$CAM_USER" ] && echo "CAM_USER/CAM_PASS are not set in /userdata/recorder.conf" || echo "camera did not return a picture"
fi
rm -f $f
