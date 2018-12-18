PRODUCT_COPY_FILES += \
	device/phh/treble/empty-permission.xml:system/etc/permissions/com.google.android.camera2.xml \
	device/phh/treble/empty-permission.xml:system/etc/permissions/com.google.android.camera.experimental2015.xml \
	device/phh/treble/empty-permission.xml:system/etc/permissions/com.google.android.camera.experimental2016.xml \
	device/phh/treble/empty-permission.xml:system/etc/permissions/com.google.android.camera.experimental2017.xml

DEVICE_PACKAGE_OVERLAYS += device/phh/treble/overlay-gapps
GAPPS_VARIANT := nano
DONT_DEXPREOPT_PREBUILTS := true
WITH_DEXPREOPT_BOOT_IMG_AND_SYSTEM_SERVER_ONLY := true
GAPPS_FORCE_PACKAGE_OVERRIDES := true
GAPPS_FORCE_BROWSER_OVERRIDES := true
GAPPS_FORCE_WEBVIEW_OVERRIDES := true
PRODUCT_PACKAGES += \
       Chrome \
       CalculatorGoogle \
       PrebuiltDeskClockGoogle \
       CalendarGooglePrebuilt \
       GoogleNow \
       LatinImeGoogle \
       phh-overrides

$(call inherit-product, vendor/opengapps/build/opengapps-packages.mk)
