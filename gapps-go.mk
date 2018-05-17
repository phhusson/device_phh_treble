DONT_DEXPREOPT_PREBUILTS := true
$(call inherit-product, build/make/target/product/go_defaults.mk)
$(call inherit-product, vendor/gapps-go/gapps-go.mk) 
