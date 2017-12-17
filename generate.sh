#!/bin/bash

echo 'PRODUCT_MAKEFILES := \' > AndroidProducts.mk

for part in a ab;do
	for apps in vanilla gapps foss;do
		for arch in arm64;do
			apps_suffix=""
			apps_script=""
			apps_name=""
			if [ "$apps" == "gapps" ];then
				apps_suffix="g"
				apps_script='$(call inherit-product, device/phh/treble/gapps.mk)'
				apps_name="with GApps"
			fi
			if [ "$apps" == "foss" ];then
				apps_suffix="f"
				apps_script='$(call inherit-product, vendor/foss/foss.mk)'
				apps_name="with FOSS apps"
			fi
			if [ "$apps" == "vanilla" ];then
				apps_suffix="v"
				apps_script=''
				apps_name="vanilla"
			fi

			target="treble_${arch}_${part}${apps_suffix}"

			cat > ${target}.mk << EOF
include build/make/target/product/treble_common.mk
\$(call inherit-product, device/phh/treble/base.mk)
$apps_script

PRODUCT_NAME := $target
PRODUCT_DEVICE := generic_arm64_$part
PRODUCT_BRAND := Android
PRODUCT_MODEL := Phh-Treble $apps_name
EOF
echo -e '\t$(LOCAL_DIR)/'$target.mk '\' >> AndroidProducts.mk
		done
	done
done
echo >> AndroidProducts.mk
