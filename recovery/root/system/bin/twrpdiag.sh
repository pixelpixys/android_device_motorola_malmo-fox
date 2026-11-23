#!/system/bin/sh
# TEMPORARY DIAGNOSTICS: TWRP malmo boot (it bootloops and there is no adb).
# Started from init.recovery.qcom.rc in "on init". Every 2 s for 10 minutes it saves dmesg,
# recovery.log, props, processes and the pstore contents (if the previous boot ended in a
# kernel panic) to the metadata partition:
#   /metadata/twrpdiag/arranque-N/
# Read them from Android with: adb root; adb pull /metadata/twrpdiag
# metadata is mounted on a separate directory and unmounted on every pass, so TWRP's own
# mount of /metadata (needed for decryption) is not disturbed.

MNT=/dev/twrpdiag-meta
mkdir -p $MNT

blk=""
for c in /dev/block/by-name/metadata /dev/block/bootdevice/by-name/metadata \
         /dev/block/platform/soc/*/by-name/metadata; do
    [ -e "$c" ] && { blk=$c; break; }
done

montar() {
    [ -n "$blk" ] || return 1
    mount -t f2fs -o rw,noatime,nosuid,nodev "$blk" $MNT 2>/dev/null
}

# pstore (kernel log of the previous boot if it ended in a panic/watchdog)
mountpoint -q /sys/fs/pstore || mount -t pstore pstore /sys/fs/pstore 2>/dev/null

if ! montar; then
    # Without metadata at least leave a trace in the kernel log
    echo "twrpdiag: no se pudo montar metadata (blk=$blk)" > /dev/kmsg
    exit 0
fi
mkdir -p $MNT/twrpdiag
n=1
while [ -d $MNT/twrpdiag/arranque-$n ]; do n=$((n + 1)); done
# keep only the last 6 boots
viejo=$((n - 6))
[ $viejo -ge 1 ] && rm -rf $MNT/twrpdiag/arranque-$viejo
D=$MNT/twrpdiag/arranque-$n
mkdir -p $D
cp -a /sys/fs/pstore/. $D/pstore-del-arranque-anterior/ 2>/dev/null
cat /proc/cmdline > $D/cmdline.txt 2>&1
cat /proc/bootconfig > $D/bootconfig.txt 2>&1
echo "twrpdiag: guardando en metadata/twrpdiag/arranque-$n" > /dev/kmsg
sync
umount $MNT

i=0
while [ $i -lt 300 ]; do      # 10 min: enough to try decrypting and use MTP
    if montar; then
        echo "$i $(cat /proc/uptime)" > $D/vuelta.txt
        dmesg > $D/dmesg.txt.tmp 2>&1
        cp /tmp/recovery.log $D/recovery.log.tmp 2>/dev/null
        getprop > $D/props.txt.tmp 2>&1
        ps -A > $D/ps.txt.tmp 2>&1
        cat /proc/modules > $D/modules.txt.tmp 2>&1
        ls -la /dev/block/by-name /sys/class/udc /dev/input /dev/graphics /dev/dri > $D/dev.txt.tmp 2>&1
        logcat -d -b all > $D/logcat.txt.tmp 2>/dev/null
        for f in dmesg.txt recovery.log props.txt ps.txt modules.txt dev.txt logcat.txt; do
            [ -s "$D/$f.tmp" ] && mv -f "$D/$f.tmp" "$D/$f"
            rm -f "$D/$f.tmp"
        done
        sync
        umount $MNT
    fi
    sleep 2
    i=$((i + 1))
done
