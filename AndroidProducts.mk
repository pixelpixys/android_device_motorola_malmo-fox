#
# Copyright (C) 2026 The Android Open Source Project
# Copyright (C) 2026 SebaUbuntu's TWRP device tree generator
#
# SPDX-License-Identifier: Apache-2.0
#

PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/fox_malmo.mk \
    $(LOCAL_DIR)/omni_malmo.mk

COMMON_LUNCH_CHOICES := \
    fox_malmo-eng \
    fox_malmo-userdebug \
    omni_malmo-eng \
    omni_malmo-userdebug
