#!/system/bin/sh
# recovery-erofs: mounts the "extra" part of the recovery, which does not fit in the ramdisk.
#
# The bootloader loads only the ramdisk of recovery.img (on malmo it has to be lz4 legacy and
# about 19.6 MB at most). Everything else (big binaries and libraries, themes, blobs) lives in an
# erofs image written INSIDE the recovery partition itself, at a fixed offset, in the free space
# after the boot image. Here it is mounted as a loop device and laid over the ramdisk dirs with
# overlayfs (the erofs on top, the ramdisk underneath), so the recovery sees everything as if it
# were all in the ramdisk. The overlays are WRITABLE: the upper layer is a tmpfs, because the
# recovery writes into its own dirs (TWRP: /etc/additional.fstab; with a read-only overlay it
# aborts on startup in a loop).
#
# Run from montar-extra.rc in "on early-init" with exec (init waits), before any service
# starts. Uses only sh/toybox, which stay in the ramdisk.
#
# dividir_recovery.py fills in these values:
OFFSET=33554432             # bytes from the start of the partition where the erofs begins
TAMANO=51453952             # erofs size in bytes
PARTICION=recovery       # partition name without slot (normally "recovery")
LOOP=/dev/block/loop7      # fixed loop device (avoids depending on "losetup -f")
PUNTO=/recovery_extra              # where the erofs gets mounted
RAICES="system/bin system/lib64 twres vendor/bin vendor/firmware vendor/firmware_mnt vendor/lib vendor/lib64"           # ramdisk dirs that get the overlay (the moved dirs: system/bin, twres...)
LOGPART=metadata           # partition for a persistent log of each boot ("" = none)

LOG=/dev/recovery-erofs.log
log() {
    echo "recovery-erofs: $*" > /dev/kmsg
    echo "$(cut -d' ' -f1 /proc/uptime 2>/dev/null) $*" >> $LOG
}

buscar() {   # buscar NAME -> path of the by-name node, waiting up to 10 s for ueventd (coldboot)
    i=0
    while [ $i -lt 100 ]; do
        for c in /dev/block/by-name/$1 /dev/block/bootdevice/by-name/$1 \
                 /dev/block/platform/*/by-name/$1 /dev/block/platform/soc/*/by-name/$1; do
            [ -e "$c" ] && { echo "$c"; return 0; }
        done
        sleep 0.1; i=$((i + 1))
    done
    return 1
}

# Saves the log and dmesg to $LOGPART (e.g. metadata), under recovery-erofs/arranque-N. It is the
# only trace when the recovery does not boot: kmsg is lost on reboot.
guardar() {
    [ -n "$LOGPART" ] || return 0
    b=$(buscar $LOGPART) || return 0
    m=/dev/recovery-erofs-meta
    mkdir -p $m
    mount -o rw,noatime,nosuid,nodev "$b" $m 2>>$LOG || return 0
    mkdir -p $m/recovery-erofs
    n=1
    while [ -d $m/recovery-erofs/arranque-$n ]; do n=$((n + 1)); done
    viejo=$((n - 6)); [ $viejo -ge 1 ] && rm -rf $m/recovery-erofs/arranque-$viejo
    d=$m/recovery-erofs/arranque-$n
    mkdir -p $d
    cp $LOG $d/montar_extra.log
    dmesg > $d/dmesg.txt 2>&1
    cat /proc/mounts > $d/mounts.txt 2>&1
    ls -la /dev/block /dev/block/by-name > $d/dev.txt 2>&1
    sync
    umount $m
}

fallo() { log "FAILED: $*"; guardar; exit 1; }

log "start: offset=$OFFSET size=$TAMANO partition=$PARTICION loop=$LOOP point=$PUNTO roots=$RAICES"
SLOT=$(getprop ro.boot.slot_suffix)
log "slot='$SLOT'"
DEV=$(buscar $PARTICION$SLOT) || fallo "partition $PARTICION$SLOT does not exist"
log "partition: $DEV -> $(readlink -f $DEV)"

# Loop node. Its minor is NOT the loop number: with loop.max_part=N on the cmdline (malmo: 7)
# each loop uses N+1 minors (loop7 = 7:56). mknod 7,7 creates the node of a PARTITION of loop0 and
# losetup fails with "Bad file descriptor". The kernel's real major:minor is in /sys/block.
nombre=${LOOP##*/}
i=0
while [ ! -b $LOOP ] && [ $i -lt 50 ]; do      # ueventd usually creates it during coldboot
    sleep 0.1; i=$((i + 1))
done
if [ ! -b $LOOP ]; then
    mm=$(cat /sys/block/$nombre/dev 2>/dev/null)
    [ -n "$mm" ] || fallo "/sys/block/$nombre/dev does not exist"
    mknod $LOOP b ${mm%%:*} ${mm##*:} 2>>$LOG && log "created node $LOOP ($mm)"
else
    log "$LOOP exists ($(cat /sys/block/$nombre/dev 2>/dev/null))"
fi
losetup -r -o $OFFSET -S $TAMANO $LOOP $DEV 2>>$LOG || fallo "losetup $LOOP $DEV"
log "losetup ok: $(losetup $LOOP 2>&1)"

mkdir -p $PUNTO
mount -t erofs -o ro $LOOP $PUNTO 2>>$LOG || { losetup -d $LOOP; fallo "mount erofs"; }
log "erofs mounted on $PUNTO: $(ls $PUNTO | tr '\n' ' ')"

# Writable layer: a tmpfs of its own (not /dev, which is nosuid). On malmo CONFIG_TMPFS_XATTR is off:
# overlayfs warns "failed to set xattr on upper" and drops the features that need it (index,
# metacopy, opaque dirs), but creating, modifying, deleting and chmod all work.
RW=${PUNTO}_rw
mkdir -p $RW
mount -t tmpfs -o mode=0755 tmpfs $RW 2>>$LOG || log "FAILED tmpfs $RW (overlays will be read-only)"
for r in $RAICES; do
    [ -d "$PUNTO/$r" ] || continue
    mkdir -p "/$r"
    k=$(echo "$r" | tr / _)
    up=$RW/up/$k; wk=$RW/work/$k
    mkdir -p $up $wk
    # the root of the merged dir takes the upper's mode and owner: copy them from the original
    chmod $(stat -c %a "/$r") $up 2>>$LOG
    chown $(stat -c %u:%g "/$r") $up 2>>$LOG
    if mount -t overlay overlay -o "lowerdir=$PUNTO/$r:/$r,upperdir=$up,workdir=$wk" "/$r" 2>>$LOG; then
        log "overlay /$r ok (rw)"
    elif mount -t overlay overlay -o "lowerdir=$PUNTO/$r:/$r" "/$r" 2>>$LOG; then
        log "overlay /$r ok (READ-ONLY: the rw one failed)"
    else
        log "FAILED overlay /$r"
    fi
done
log "done"
guardar
