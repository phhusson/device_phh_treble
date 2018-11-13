#!/bin/bash

rom_script=''
if [ -n "$1" ];then
	if echo "$1" | grep -qF /;then
        rom_script=''
        for i in "$@";do
            rom_script="$rom_script"$'\n''$(call inherit-product, '$i')'
        done
    else
		rom_script='$(call inherit-product, device/phh/treble/'$1'.mk)'
	fi
fi

echo 'PRODUCT_MAKEFILES := \' > AndroidProducts.mk

for part in a ab;do
	for apps in vanilla gapps foss gapps-go;do
		for arch in arm64 arm a64;do
			for su in yes no;do
				apps_suffix=""
				apps_script=""
				apps_name=""
				extra_packages=""
                vndk="vndk.mk"
				if [ "$apps" == "gapps" ];then
					apps_suffix="g"
					apps_script='$(call inherit-product, device/phh/treble/gapps.mk)'
					apps_name="with GApps"
				fi
				if [ "$apps" == "gapps-go" ];then
					apps_suffix="o"
					apps_script='$(call inherit-product, device/phh/treble/gapps-go.mk)'
					apps_name="Go"
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
				if [ "$arch" == "arm" ];then
					vndk="vndk-binder32.mk"
				fi
				if [ "$arch" == "a64" ];then
					vndk="vndk32.mk"
				fi

				su_suffix='N'
				if [ "$su" == "yes" ];then
					su_suffix='S'
					extra_packages+=' phh-su me.phh.superuser'
				fi

				part_suffix='a'
				if [ "$part" == 'ab' ];then
					part_suffix='b'
				fi

				target="treble_${arch}_${part_suffix}${apps_suffix}${su_suffix}"

				cat > ${target}.mk << EOF
\$(call inherit-product, device/phh/treble/base-pre.mk)
include build/make/target/product/treble_common.mk
\$(call inherit-product, vendor/vndk/${vndk})
\$(call inherit-product, device/phh/treble/base.mk)
$apps_script
$rom_script

PRODUCT_NAME := $target
PRODUCT_DEVICE := phhgsi_${arch}_$part
PRODUCT_BRAND := Android
PRODUCT_MODEL := Phh-Treble $apps_name

PRODUCT_PACKAGES += $extra_packages
EOF
echo -e '\t$(LOCAL_DIR)/'$target.mk '\' >> AndroidProducts.mk
			done
		done
	done
done
echo >> AndroidProducts.mk
