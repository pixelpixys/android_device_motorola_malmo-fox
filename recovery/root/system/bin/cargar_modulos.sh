#!/system/bin/sh
# Lineage recovery (malmo): loads the vendor_dlkm modules that only Android loads.
DIR=/vendor/lib/modules-recovery

# Same relative order as /vendor_dlkm/lib/modules/modules.load
for m in sc8541_mmi_iio mmi_annotate mmi_info mmi_charger mmi-smbcharger-iio \
         mmi_parallel_charger_iio sensors_class mmi_relay touchscreen_mmi goodix_brl_mmi; do
    insmod $DIR/$m.ko || echo "cargar_modulos: insmod $m failed" > /dev/kmsg
done

# Start health HAL daemon now that battery power_supply nodes exist
start health-hal-2-1

# Trigger haptics warmup for AW86927 vibrator
setprop twrp.modules.loaded true
start twrp-haptics-warmup

# dwc3-msm (glue 4e00000.ssusb on blair) in peripheral mode
i=0
while [ ! -e /sys/bus/platform/devices/4e00000.ssusb/mode ] && [ $i -lt 50 ]; do
    sleep 0.2; i=$((i + 1))
done
echo peripheral > /sys/bus/platform/devices/4e00000.ssusb/mode

C=$(getprop sys.usb.controller)
[ -n "$C" ] || C=4e00000.dwc3
i=0
while [ ! -e /sys/class/udc/$C ] && [ $i -lt 50 ]; do
    sleep 0.2; i=$((i + 1))
done

# Always ensure adbd is started
start adbd

# Background watchdog: continuously ensures ADB function, UDC, and Battery status
(
    # Wait for TWRP recovery process to start
    while [ ! -e /tmp/openrecoveryscript ] && [ -z "$(pidof recovery)" ]; do
        sleep 1
    done
    sleep 2

    while true; do
        # 1. USB Watchdog
        CFG=$(getprop sys.usb.config)
        UDC=$(cat /config/usb_gadget/g1/UDC 2>/dev/null)
        if [ "$CFG" != "none" ]; then
            if [ "$(getprop init.svc.adbd)" != "running" ]; then
                start adbd
            fi
            if [ -z "$UDC" ] && [ "$(getprop sys.usb.ffs.ready)" = "1" ]; then
                [ -e /config/usb_gadget/g1/configs/b.1/f1 ] || \
                    ln -s /config/usb_gadget/g1/functions/ffs.adb /config/usb_gadget/g1/configs/b.1/f1 2>/dev/null
                echo 4e00000.dwc3 > /config/usb_gadget/g1/UDC 2>/dev/null || true
                setprop sys.usb.state "$CFG"
            fi
        fi

        # 2. Battery Watchdog (sync hardware PMIC capacity to TWRP GUI)
        if [ -e /sys/class/power_supply/battery/capacity ]; then
            CAP=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null)
            if [ -n "$CAP" ]; then
                twrp set tw_battery "$CAP" >/dev/null 2>&1
                twrp set tw_battery_charge "${CAP}%" >/dev/null 2>&1
            fi
        fi

        sleep 5
    done
) &

echo "cargar_modulos: done, udc=$(ls /sys/class/udc 2>/dev/null)" > /dev/kmsg
