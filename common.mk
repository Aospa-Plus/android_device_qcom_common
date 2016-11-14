TARGET_USES_QCOM_BSP := $(call match-word,false,$(TARGET_USES_AOSP))

TARGET_COMPILE_WITH_MSM_KERNEL := true
TARGET_HAS_QC_KERNEL_SOURCE := true
TARGET_USES_QCOM_MM_AUDIO := true

BOARD_USES_ADRENO := true

# include additional build utilities
include device/qcom/common/utils.mk

# include definitions for SDCLANG
ifeq ($(HOST_OS),linux)
include device/qcom/common/sdclang/sdclang.mk
endif

# Qualcomm specific packages
PRODUCT_PACKAGES += SnapdragonCamera

TARGET_CRYPTFS_HW_PATH := device/qcom/common/cryptfs_hw

# Advanced DPM
ifeq ($(TARGET_WANTS_EXTENDED_DPM_PLATFORM),true)
PRODUCT_BOOT_JARS += tcmclient
PRODUCT_BOOT_JARS += com.qti.dpmframework
PRODUCT_BOOT_JARS += dpmapi
PRODUCT_BOOT_JARS += com.qti.location.sdk
endif

# Block Dash by default
TARGET_DISABLE_DASH ?= true

# Dash extension
ifeq ($(TARGET_DISABLE_DASH),false)
PRODUCT_BOOT_JARS += qcmediaplayer
endif

