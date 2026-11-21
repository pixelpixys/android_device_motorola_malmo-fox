#
# Copyright (C) 2026 The Android Open Source Project
# Copyright (C) 2026 SebaUbuntu's TWRP device tree generator
#
# SPDX-License-Identifier: Apache-2.0
#

PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/fox_malmo.mk \
    $(LOCAL_DIR)/twrp_malmo.mk \
    $(LOCAL_DIR)/omni_malmo.mk

COMMON_LUNCH_CHOICES := \
    fox_malmo-ap2a-eng \
    fox_malmo-ap2a-userdebug \
    twrp_malmo-ap2a-eng \
    twrp_malmo-ap2a-userdebug \
    omni_malmo-ap2a-eng \
    omni_malmo-ap2a-userdebug \
    fox_malmo-trunk_staging-eng \
    fox_malmo-trunk_staging-userdebug \
    twrp_malmo-trunk_staging-eng \
    twrp_malmo-trunk_staging-userdebug \
    omni_malmo-trunk_staging-eng \
    omni_malmo-trunk_staging-userdebug \
    fox_malmo-eng \
    fox_malmo-userdebug \
    twrp_malmo-eng \
    twrp_malmo-userdebug \
    omni_malmo-eng \
    omni_malmo-userdebug
