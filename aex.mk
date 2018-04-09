$(call inherit-product, vendor/aosp/config/common.mk)
$(call inherit-product, device/aosp/sepolicy/common/sepolicy.mk)

# Overlays
DEVICE_PACKAGE_OVERLAYS += \
    $(LOCAL_PATH)/aex-overlay
