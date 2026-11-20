#!/bin/sh
# Format the microSD to FAT32 (called from the web admin, runs in background).
# S30sdcard pauses while /tmp/sd_format.lock exists and remounts afterwards.
MNT=/mnt/sdcard
LOG=/tmp/sd_format.log
LOCK=/tmp/sd_format.lock
REC=/etc/init.d/S90recorder

[ -e "$LOCK" ] && { echo "already running" >>"$LOG"; exit 1; }
touch "$LOCK"; trap 'rm -f "$LOCK"' EXIT
: >"$LOG"
say() { echo "$(date '+%H:%M:%S') $*" >>"$LOG"; }

if [ -b /dev/mmcblk1p1 ]; then DEV=/dev/mmcblk1p1
elif [ -b /dev/mmcblk1 ]; then DEV=/dev/mmcblk1
else say "ERROR: no card"; echo FAIL >>"$LOG"; exit 1; fi

[ -x "$REC" ] && { say "Stopping recording"; $REC stop >>"$LOG" 2>&1; sleep 2; }

say "Unmounting $MNT"
sync
grep -q " $MNT " /proc/mounts && { umount "$MNT" 2>>"$LOG" || umount -l "$MNT" 2>>"$LOG"; }

say "Formatting $DEV as FAT32"
if ! mkfs.vfat -F 32 -n VIDEO "$DEV" >>"$LOG" 2>&1; then
    say "ERROR: format failed"; echo FAIL >>"$LOG"
    [ -x "$REC" ] && $REC start >>"$LOG" 2>&1
    exit 1
fi

rm -f "$LOCK"
say "Waiting for remount"
i=0
while ! grep -q " $MNT " /proc/mounts && [ $i -lt 40 ]; do sleep 1; i=$((i+1)); done
if grep -q " $MNT " /proc/mounts; then
    [ -x "$REC" ] && { say "Starting recording"; $REC start >>"$LOG" 2>&1; }
    say "Done: $(df -h "$MNT" | awk 'NR==2{print $4 " free of " $2}')"
    echo DONE >>"$LOG"
else
    say "ERROR: card did not mount"; echo FAIL >>"$LOG"
fi
