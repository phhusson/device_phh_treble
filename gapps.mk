GAPPS_VARIANT := nano
DONT_DEXPREOPT_PREBUILTS := true
GAPPS_FORCE_PACKAGE_OVERRIDES := true
GAPPS_FORCE_BROWSER_OVERRIDES := true
GAPPS_FORCE_WEBVIEW_OVERRIDES := true
PRODUCT_PACKAGES += \
       Chrome \
       CalculatorGoogle \
       PrebuiltDeskClockGoogle \
       CalendarGooglePrebuilt \
       GoogleHome \
       LatinImeGoogle \
       phh-overrides

$(call inherit-product, vendor/opengapps/build/opengapps-packages.mk)
