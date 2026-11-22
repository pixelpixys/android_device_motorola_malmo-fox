#
# Copyright (C) 2026 The Android Open Source Project
# Copyright (C) 2026 SebaUbuntu's TWRP device tree generator
#
# SPDX-License-Identifier: Apache-2.0
#

LOCAL_PATH := device/motorola/malmo

# A/B
AB_OTA_POSTINSTALL_CONFIG += \
    RUN_POSTINSTALL_system=true \
    POSTINSTALL_PATH_system=system/bin/otapreopt_script \
    FILESYSTEM_TYPE_system=ext4 \
    POSTINSTALL_OPTIONAL_system=true

# Recovery root files
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery/root/init.recovery.qcom.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.qcom.rc \
    $(LOCAL_PATH)/recovery/root/system/bin/cargar_modulos.sh:$(TARGET_COPY_OUT_RECOVERY)/root/system/bin/cargar_modulos.sh \
    $(call find-copy-subdir-files,*,$(LOCAL_PATH)/recovery/root/vendor/lib/modules-recovery,$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib/modules-recovery)

# Boot control HAL & Recovery Libraries
PRODUCT_PACKAGES += \
    android.hardware.boot@1.0-impl \
    android.hardware.boot@1.0-service \
    bootctrl.blair \
    libsysutils
