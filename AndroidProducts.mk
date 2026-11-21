#
# Copyright (C) 2026 The Android Open Source Project
# Copyright (C) 2026 SebaUbuntu's TWRP device tree generator
#
# SPDX-License-Identifier: Apache-2.0
#

PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/fox_malmo.mk \
    $(LOCAL_DIR)/twrp_malmo.mk

COMMON_LUNCH_CHOICES := \
    fox_malmo-ap2a-eng \
    fox_malmo-ap2a-userdebug \
    twrp_malmo-ap2a-eng \
    twrp_malmo-ap2a-userdebug
