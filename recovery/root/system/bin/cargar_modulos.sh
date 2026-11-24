#!/system/bin/sh
# Lineage recovery (malmo): loads the vendor_dlkm modules that only Android loads.
DIR=/vendor/lib/modules-recovery

# Load essential kernel modules in order
for m in sc8541_mmi_iio mmi_annotate mmi_info mmi_charger mmi-smbcharger-iio \
         mmi_parallel_charger_iio sensors_class mmi_relay touchscreen_mmi goodix_brl_mmi focaltech_v3_4; do
    insmod $DIR/$m.ko || echo "cargar_modulos: insmod $m failed" > /dev/kmsg
done

# Trigger haptics warmup for AW86927 vibrator
setprop twrp.modules.loaded true
start twrp-haptics-warmup

# Start health HAL so GUI battery widget gets live battery and charging state
start health-hal-2-1

# dwc3-msm (glue 4e00000.ssusb on blair) in peripheral mode
i=0
while [ ! -e /sys/bus/platform/devices/4e00000.ssusb/mode ] && [ $i -lt 50 ]; do
    sleep 0.1; i=$((i + 1))
done
echo peripheral > /sys/bus/platform/devices/4e00000.ssusb/mode

C=4e00000.dwc3
setprop sys.usb.controller $C

# Wait up to 3s for UDC to appear
i=0
while [ ! -e /sys/class/udc/$C ] && [ $i -lt 30 ]; do
    sleep 0.1; i=$((i + 1))
done

# If UDC appeared, bind gadget for instant ADB
if [ -e /sys/class/udc/$C ]; then
    [ -e /config/usb_gadget/g1/configs/b.1/f1 ] || \
        ln -s /config/usb_gadget/g1/functions/ffs.adb /config/usb_gadget/g1/configs/b.1/f1 2>/dev/null
    if [ -z "$(cat /config/usb_gadget/g1/UDC 2>/dev/null)" ]; then
        echo $C > /config/usb_gadget/g1/UDC 2>/dev/null || true
    fi
    setprop sys.usb.state adb
fi

# Always ensure adbd is running
start adbd

# Background watchdog: monitors cable reconnect and battery
(
    CTRL="4e00000.dwc3"
    PREV_STATE=""

    # Wait until recovery process exists and is running its UI loop
    while [ -z "$(pidof recovery)" ]; do
        sleep 0.5
    done
    sleep 2

    while true; do
        # 1. Update battery capacity and charging indicator in GUI
        if [ -e /sys/class/power_supply/battery/capacity ]; then
            CAP=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null)
            STAT=$(cat /sys/class/power_supply/battery/status 2>/dev/null)
            if [ -n "$CAP" ]; then
                twrp set tw_battery "$CAP" >/dev/null 2>&1
                if [ "$STAT" = "Charging" ] || [ "$STAT" = "Full" ]; then
                    twrp set tw_battery_charge "${CAP}%+" >/dev/null 2>&1
                else
                    twrp set tw_battery_charge "${CAP}%" >/dev/null 2>&1
                fi
            fi
        fi

        # 2. Check UDC and controller connection
        UDC=$(cat /config/usb_gadget/g1/UDC 2>/dev/null)
        if [ -z "$UDC" ] || [ "$UDC" = "none" ]; then
            if [ "$(getprop init.svc.adbd)" != "running" ]; then
                start adbd
            fi
            setprop sys.usb.ffs.ready 1
            [ -e /config/usb_gadget/g1/configs/b.1/f1 ] || \
                ln -s /config/usb_gadget/g1/functions/ffs.adb /config/usb_gadget/g1/configs/b.1/f1 2>/dev/null
            echo $CTRL > /config/usb_gadget/g1/UDC 2>/dev/null || true
            setprop sys.usb.state adb
        fi

        sleep 1
    done
) &

echo "cargar_modulos: done, udc=$(ls /sys/class/udc 2>/dev/null)" > /dev/kmsg
