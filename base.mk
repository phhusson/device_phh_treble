#Huawei devices don't declare fingerprint and telephony hardware feature
#TODO: Proper detection
PRODUCT_COPY_FILES := \
	frameworks/native/data/etc/android.hardware.fingerprint.xml:system/etc/permissions/android.hardware.fingerprint.xml \
	frameworks/native/data/etc/android.hardware.telephony.gsm.xml:system/etc/permissions/android.hardware.telephony.gsm.xml \
	frameworks/native/data/etc/android.hardware.telephony.ims.xml:system/etc/permissions/android.hardware.telephony.ims.xml \
	frameworks/native/data/etc/android.hardware.bluetooth.xml:system/etc/permissions/android.hardware.bluetooth.xml \
	frameworks/native/data/etc/android.hardware.bluetooth_le.xml:system/etc/permissions/android.hardware.bluetooth_le.xml \
	frameworks/native/data/etc/android.hardware.usb.host.xml:system/etc/permissions/android.hardware.usb.host.xml \

#Use a more decent APN config
PRODUCT_COPY_FILES += \
	device/sample/etc/apns-full-conf.xml:system/etc/apns-conf.xml

BOARD_PLAT_PRIVATE_SEPOLICY_DIR += device/phh/treble/sepolicy
PRODUCT_PACKAGE_OVERLAYS += device/phh/treble/overlay

$(call inherit-product, vendor/hardware_overlay/overlay.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/aosp_base_telephony.mk)

#Those overrides are here because Huawei's init read properties
#from /system/etc/prop.default, then /vendor/build.prop, then /system/build.prop
#So we need to set our props in prop.default
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
	ro.build.version.sdk=$(PLATFORM_SDK_VERSION) \
	ro.build.version.codename=$(PLATFORM_VERSION_CODENAME) \
	ro.build.version.all_codenames=$(PLATFORM_VERSION_ALL_CODENAMES) \
	ro.build.version.release=$(PLATFORM_VERSION) \
	ro.build.version.security_patch=$(PLATFORM_SECURITY_PATCH) \
	ro.adb.secure=0 \
	ro.logd.auditd=true
	
#Huawei HiSuite (also other OEM custom programs I guess) it's of no use in AOSP builds
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
	persist.sys.usb.config=adb \
	ro.cust.cdrom=/dev/null	

#VNDK config files
PRODUCT_COPY_FILES += \
	device/phh/treble/vndk-detect:system/bin/vndk-detect \
	device/phh/treble/vndk.rc:system/etc/init/vndk.rc \

#USB Audio
PRODUCT_COPY_FILES += \
	frameworks/av/services/audiopolicy/config/usb_audio_policy_configuration.xml:system/etc/usb_audio_policy_configuration.xml \
	device/phh/treble/files/fake_audio_policy_volume.xml:system/etc/fake_audio_policy_volume.xml \

# NFC:
#   Provide default libnfc-nci.conf file for devices that does not have one in
#   vendor/etc
PRODUCT_COPY_FILES += \
	device/phh/treble/nfc/libnfc-nci.conf:system/phh/libnfc-nci-oreo.conf \
	device/phh/treble/nfc/libnfc-nci-huawei.conf:system/phh/libnfc-nci-huawei.conf

# LineageOS build may need this to make NFC work
PRODUCT_PACKAGES += \
        NfcNci \

PRODUCT_COPY_FILES += \
	device/phh/treble/rw-system.sh:system/bin/rw-system.sh \
	device/phh/treble/phh-on-data.sh:system/bin/phh-on-data.sh \
	device/phh/treble/phh-prop-handler.sh:system/bin/phh-prop-handler.sh \
	device/phh/treble/fixSPL/getSPL.arm:system/bin/getSPL

PRODUCT_COPY_FILES += \
	device/phh/treble/empty:system/phh/empty \
	device/phh/treble/phh-on-boot.sh:system/bin/phh-on-boot.sh

PRODUCT_PACKAGES += \
	treble-environ-rc \

PRODUCT_PACKAGES += \
	bootctl \
	vintf \

# Fix Offline Charging on Huawmeme
PRODUCT_PACKAGES += \
	huawei-charger
PRODUCT_COPY_FILES += \
	$(call find-copy-subdir-files,*,device/phh/treble/huawei_charger/files,system/etc/charger)

PRODUCT_COPY_FILES += \
	device/phh/treble/twrp/twrp.rc:system/etc/init/twrp.rc \
	device/phh/treble/twrp/twrp.sh:system/bin/twrp.sh \
	device/phh/treble/twrp/busybox-armv7l:system/bin/busybox_phh

PRODUCT_PACKAGES += \
    simg2img_simple \
    lptools

ifneq (,$(wildcard external/exfat))
PRODUCT_PACKAGES += \
	mkfs.exfat \
	fsck.exfat
endif

PRODUCT_PACKAGES += \
	android.hidl.manager-V1.0-java \
	android.hardware.wifi.hostapd-V1.0-java \
	vendor.huawei.hardware.biometrics.fingerprint-V2.1-java \
	vendor.huawei.hardware.tp-V1.0-java \
	vendor.qti.hardware.radio.am-V1.0-java \
	vendor.qti.qcril.am-V1.0-java \

PRODUCT_COPY_FILES += \
	device/phh/treble/interfaces.xml:system/etc/permissions/interfaces.xml

PRODUCT_COPY_FILES += \
	device/phh/treble/files/samsung-gpio_keys.kl:system/phh/samsung-gpio_keys.kl \
	device/phh/treble/files/samsung-sec_touchscreen.kl:system/phh/samsung-sec_touchscreen.kl \
	device/phh/treble/files/samsung-sec_touchkey.kl:system/phh/samsung-sec_touchkey.kl \
	device/phh/treble/files/oneplus6-synaptics_s3320.kl:system/phh/oneplus6-synaptics_s3320.kl \
	device/phh/treble/files/huawei-fingerprint.kl:system/phh/huawei/fingerprint.kl \
	device/phh/treble/files/samsung-sec_e-pen.idc:system/usr/idc/sec_e-pen.idc \
	device/phh/treble/files/samsung-9810-floating_feature.xml:system/ph/sam-9810-flo_feat.xml \
	device/phh/treble/files/mimix3-gpio-keys.kl:system/phh/mimix3-gpio-keys.kl \
	device/phh/treble/files/nokia-soc_gpio_keys.kl:system/phh/nokia-soc_gpio_keys.kl \
	device/phh/treble/files/lenovo-synaptics_dsx.kl:system/phh/lenovo-synaptics_dsx.kl \
	device/phh/treble/files/oppo-touchpanel.kl:system/phh/oppo-touchpanel.kl \
	device/phh/treble/files/google-uinput-fpc.kl:system/phh/google-uinput-fpc.kl \
	device/phh/treble/files/moto-uinput-egis.kl:system/phh/moto-uinput-egis.kl \
	device/phh/treble/files/daisy-buttonJack.kl:system/phh/daisy-buttonJack.kl \
	device/phh/treble/files/daisy-uinput-fpc.kl:system/phh/daisy-uinput-fpc.kl \
	device/phh/treble/files/daisy-uinput-goodix.kl:system/phh/daisy-uinput-goodix.kl \
	device/phh/treble/files/nubia-nubia_synaptics_dsx.kl:system/phh/nubia-nubia_synaptics_dsx.kl \
	device/phh/treble/files/unihertz-mtk-kpd.kl:system/phh/unihertz-mtk-kpd.kl \
	device/phh/treble/files/unihertz-mtk-tpd.kl:system/phh/unihertz-mtk-tpd.kl \
	device/phh/treble/files/unihertz-mtk-tpd-kpd.kl:system/phh/unihertz-mtk-tpd-kpd.kl \
	device/phh/treble/files/unihertz-fingerprint_key.kl:system/phh/unihertz-fingerprint_key.kl \
	device/phh/treble/files/zf6-goodixfp.kl:system/phh/zf6-goodixfp.kl \
	device/phh/treble/files/zf6-googlekey_input.kl:system/phh/zf6-googlekey_input.kl \
	device/phh/treble/files/teracube2e-mtk-kpd.kl:system/phh/teracube2e-mtk-kpd.kl \

SELINUX_IGNORE_NEVERALLOWS := true

# Universal NoCutoutOverlay
PRODUCT_PACKAGES += \
    NoCutoutOverlay

PRODUCT_PACKAGES += \
    lightsctl \
    uevent

PRODUCT_COPY_FILES += \
	device/phh/treble/files/adbd.rc:system/etc/init/adbd.rc

#MTK incoming SMS fix
PRODUCT_PACKAGES += \
	mtk-sms-fwk-ready

# Helper to debug Xiaomi motorized camera
PRODUCT_PACKAGES += \
	xiaomi-motor \
	oneplus-motor

PRODUCT_PACKAGES += \
	Stk

PRODUCT_PACKAGES += \
	resetprop_phh

PRODUCT_COPY_FILES += \
	device/phh/treble/phh-securize.sh:system/bin/phh-securize.sh \
	device/phh/treble/files/ota.sh:system/bin/ota.sh \

PRODUCT_COPY_FILES += \
	device/phh/treble/remove-telephony.sh:system/bin/remove-telephony.sh \

PRODUCT_COPY_FILES += \
	frameworks/native/data/etc/android.software.secure_lock_screen.xml:system/etc/permissions/android.software.secure_lock_screen.xml \
	device/phh/treble/files/android.software.controls.xml:system/etc/permissions/android.software.controls.xml \

PRODUCT_COPY_FILES += \
        device/phh/treble/ld.config.26.txt:system/etc/ld.config.26.txt \

PRODUCT_PACKAGES += \
    asus-motor

# Privapp-permissions whitelist for PhhTrebleApp
PRODUCT_COPY_FILES += \
	device/phh/treble/privapp-permissions-me.phh.treble.app.xml:system/etc/permissions/privapp-permissions-me.phh.treble.app.xml

# Remote debugging
PRODUCT_COPY_FILES += \
	device/phh/treble/remote/dbclient:system/bin/dbclient \
	device/phh/treble/remote/phh-remotectl.rc:system/etc/init/phh-remotectl.rc \
	device/phh/treble/remote/phh-remotectl.sh:system/bin/phh-remotectl.sh \

PRODUCT_PACKAGES += \
	android.hardware.biometrics.fingerprint@2.1-service.oppo.compat \
	android.hardware.biometrics.fingerprint@2.1-service.oplus.compat \

PRODUCT_PACKAGES += \
	vr_hwc \
	curl \
	healthd \

PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
	debug.fdsan=warn_once \

# AOSP overlays
PRODUCT_PACKAGES += \
    NavigationBarMode2ButtonOverlay

PRODUCT_PACKAGES += \
	oplus-alert-slider
