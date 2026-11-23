#!/system/bin/sh
# TWRP malmo: brings USB up once the controller exists.
#
# TWRP loads the charger modules (TW_LOAD_VENDOR_MODULES, from /vendor_dlkm) after it starts.
# Only then (fw_devlink.strict=1) does qpnp-smb5 probe, then dwc3-msm (4e00000.ssusb) and the UDC.
# The init trigger (ro.boot.usbcontroller) runs much earlier: with "wait" it blocked init 5 s and
# failed anyway, so this goes in a service that waits without blocking anyone.

MODE=/sys/bus/platform/devices/4e00000.ssusb/mode
UDC=/config/usb_gadget/g1/UDC

i=0
while [ ! -e $MODE ] && [ $i -lt 600 ]; do      # up to 120 s
    sleep 0.2; i=$((i + 1))
done
echo peripheral > $MODE

C=$(getprop sys.usb.controller)
[ -n "$C" ] || C=4e00000.dwc3
i=0
while [ ! -e /sys/class/udc/$C ] && [ $i -lt 100 ]; do
    sleep 0.2; i=$((i + 1))
done

# If init tried to bind the gadget before the UDC existed, bind it now. If FunctionFS is not
# ready yet, init will do it itself when it is.
j=0
while [ $j -lt 30 ]; do
    if [ -z "$(cat $UDC 2>/dev/null)" ] && [ "$(getprop sys.usb.ffs.ready)" = 1 ]; then
        case "$(getprop sys.usb.config)" in
            ""|none) ;;
            *) echo "$C" > $UDC ;;
        esac
    fi
    [ -n "$(cat $UDC 2>/dev/null)" ] && break
    sleep 1; j=$((j + 1))
done

echo "usb_tardio: mode=$(cat $MODE 2>&1) udc=$(cat $UDC 2>&1) config=$(getprop sys.usb.config)" > /dev/kmsg
