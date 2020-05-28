ifeq ($(TARGET_ARCH), arm64)
	TARGET_GAPPS_ARCH := arm64
else
	TARGET_GAPPS_ARCH := arm
endif
$(call inherit-product, vendor/aosp/config/common_full_phone.mk) 
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk) 
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk) 
TARGET_BOOT_ANIMATION_RES := 1080
