#!/system/bin/sh
# Lineage recovery (malmo): loads the vendor_dlkm modules that only Android loads.
#
# The kernel runs with fw_devlink.strict=1: a device does not probe until ALL its
# suppliers have a driver. In recovery only the vendor_boot modules get loaded, so the
# bq25960 charge pump (i2c 2-006a, module sc8541_mmi_iio) had no driver, and qpnp-smb5
# deferred forever, taking with it:
#   - USB: 4e00000.ssusb (dwc3-msm) never probed, so no UDC and adb/sideload never
#     showed up ("Timeout waiting for messages from minadbd").
#   - battery: the "battery" power_supply that recovery reads comes from mmi-smbcharger-iio.
#   - touch: goodix_brl_mmi + touchscreen_mmi (+ mmi_info, sensors_class, mmi_relay).
#
# They are the stripped copies from /vendor_dlkm (same srcversion as the tree). The
# recovery ramdisk has to be lz4 and about 19 MB at most, so only the essentials go in (no
# FocalTech: the malmo panel is tm-goodix).
#
# Runs as a service (not insmod from init): synchronous insmod in "on init" froze boot.

DIR=/vendor/lib/modules-recovery

# Same relative order as /vendor_dlkm/lib/modules/modules.load
for m in sc8541_mmi_iio mmi_annotate mmi_info mmi_charger mmi-smbcharger-iio \
         mmi_parallel_charger_iio sensors_class mmi_relay touchscreen_mmi goodix_brl_mmi; do
    insmod $DIR/$m.ko || echo "cargar_modulos: insmod $m failed" > /dev/kmsg
done

# dwc3-msm (glue 4e00000.ssusb on blair) in peripheral mode
i=0
while [ ! -e /sys/bus/platform/devices/4e00000.ssusb/mode ] && [ $i -lt 50 ]; do
    sleep 0.2; i=$((i + 1))
done
echo peripheral > /sys/bus/platform/devices/4e00000.ssusb/mode

# If init already tried to bind the gadget before the UDC existed, bind it now.
C=$(getprop sys.usb.controller)
[ -n "$C" ] || C=4e00000.dwc3
i=0
while [ ! -e /sys/class/udc/$C ] && [ $i -lt 50 ]; do
    sleep 0.2; i=$((i + 1))
done

# Wait for ffs if adbd is starting
i=0
while [ "$(getprop sys.usb.ffs.ready)" != "1" ] && [ $i -lt 30 ]; do
    sleep 0.2; i=$((i + 1))
done

if [ -z "$(cat /config/usb_gadget/g1/UDC 2>/dev/null)" ]; then
    case "$(getprop sys.usb.config)" in
        *adb*|*sideload*|*fastboot*|*mtp*)
            echo "$C" > /config/usb_gadget/g1/UDC 2>/dev/null || true
            setprop sys.usb.state "$(getprop sys.usb.config)"
            ;;
    esac
fi

echo "cargar_modulos: done, udc=$(ls /sys/class/udc 2>/dev/null)" > /dev/kmsg
