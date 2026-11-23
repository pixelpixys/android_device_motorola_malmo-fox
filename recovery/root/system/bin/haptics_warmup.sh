#!/system/bin/sh
# AW86927 (awinic,haptic_hv): tras el probe el driver tarda ~8 s en subir
# /vendor/firmware/haptic_ram.bin. Hasta entonces activate/brightness responden
# "ram init failed, not allow to play!" y TWRP no vibra.
# TWRP copia todos los modulos de vendor_dlkm a /tmp/vendor/lib/modules; cargamos
# el de haptics aqui (por si no esta en TW_LOAD_VENDOR_MODULES) y forzamos
# ram_update en cuanto existe el LED class, para que la primera pulsacion vibre.
if ! grep -q '^aw_haptic_hv_v1_5 ' /proc/modules 2>/dev/null; then
    insmod /tmp/vendor/lib/modules/aw_haptic_hv_v1_5.ko 2>/dev/null
fi

i=0
while [ "$i" -lt 100 ]; do
    if [ -e /sys/class/leds/vibrator/ram_update ]; then
        echo 1 > /sys/class/leds/vibrator/ram_update
        exit 0
    fi
    sleep 0.1
    i=$((i + 1))
done
exit 0
