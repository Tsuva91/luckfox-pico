#!/bin/sh
# last 24 h of the per-minute LTE log: "date time rsrp rsrq snr band oper rx= tx= [probe=]"
printf 'Content-Type: text/plain\r\nCache-Control: no-store\r\n\r\n'
tail -n 1440 /tmp/lte.log 2>/dev/null
