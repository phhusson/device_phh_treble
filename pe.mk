$(call inherit-product, vendor/aosp/config/common_full_phone.mk)
$(call inherit-product, device/custom/sepolicy/common/sepolicy.mk)
-include vendor/aosp/build/core/config.mk
TARGET_BOOT_ANIMATION_RES := 1080
