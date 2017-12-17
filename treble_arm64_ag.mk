include build/make/target/product/treble_common.mk

#Need to be called first to be able to override later rules,
#but after treble_common which would override PRODUCT_PACKAGES
$(call inherit-product, device/phh/treble/base.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/aosp_base_telephony.mk)

$(call inherit-product, vendor/hardware_overlay/overlay.mk)
$(call inherit-product, device/phh/treble/gapps.mk)

PRODUCT_NAME := treble_arm64_ag
PRODUCT_DEVICE := generic_arm64_a
PRODUCT_BRAND := Android
PRODUCT_MODEL := Phh-Treble
