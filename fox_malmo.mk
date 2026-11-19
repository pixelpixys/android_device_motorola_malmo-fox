#
# Copyright (C) 2026 The Android Open Source Project
# Copyright (C) 2026 SebaUbuntu's TWRP device tree generator
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit some common Omni/Fox stuff.
$(call inherit-product, vendor/omni/config/common.mk)

# Inherit from malmo device
$(call inherit-product, device/motorola/malmo/device.mk)

PRODUCT_DEVICE := malmo
PRODUCT_NAME := fox_malmo
PRODUCT_BRAND := motorola
PRODUCT_MODEL := Moto G85 5G
PRODUCT_MANUFACTURER := motorola

PRODUCT_GMS_CLIENTID_BASE := android-motorola

PRODUCT_BUILD_PROP_OVERRIDES += \
    PRIVATE_BUILD_DESC="malmo-user 14 U1UD34.2 1234 release-keys"

BUILD_FINGERPRINT := motorola/malmo/malmo:14/U1UD34.2/1234:user/release-keys
