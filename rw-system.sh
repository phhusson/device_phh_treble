#!/system/bin/sh

#Uncomment me to output sh -x of this script to /cache/phh/logs
#if [ -z "$debug" ];then
#	mkdir -p /cache/phh
#	debug=1 exec sh -x "$(readlink -f -- "$0")" > /cache/phh/logs 2>&1
#fi

vndk="$(getprop persist.sys.vndk)"
[ -z "$vndk" ] && vndk="$(getprop ro.vndk.version |grep -oE '^[0-9]+')"

if [ "$vndk" = 26 ];then
	resetprop ro.vndk.version 26
fi

setprop sys.usb.ffs.aio_compat true
setprop persist.adb.nonblocking_ffs false

fixSPL() {
    if [ "$(getprop ro.product.cpu.abi)" = "armeabi-v7a" ]; then
        setprop ro.keymaster.mod 'AOSP on ARM32'
    else
        setprop ro.keymaster.mod 'AOSP on ARM64'
    fi
    img="$(find /dev/block -type l -name kernel"$(getprop ro.boot.slot_suffix)" | grep by-name | head -n 1)"
    [ -z "$img" ] && img="$(find /dev/block -type l -name boot"$(getprop ro.boot.slot_suffix)" | grep by-name | head -n 1)"
    if [ -n "$img" ]; then
        #Rewrite SPL/Android version if needed
        Arelease="$(getSPL "$img" android)"
        setprop ro.keymaster.xxx.release "$Arelease"
        setprop ro.keymaster.xxx.security_patch "$(getSPL "$img" spl)"
        setprop ro.keymaster.brn Android

        getprop ro.vendor.build.fingerprint | grep -qiE '^samsung/' && return 0
        for f in \
            /vendor/lib64/hw/android.hardware.keymaster@3.0-impl-qti.so /vendor/lib/hw/android.hardware.keymaster@3.0-impl-qti.so \
            /system/lib64/vndk-26/libsoftkeymasterdevice.so /vendor/bin/teed \
            /system/lib64/vndk/libsoftkeymasterdevice.so /system/lib/vndk/libsoftkeymasterdevice.so \
            /system/lib/vndk-26/libsoftkeymasterdevice.so \
            /system/lib/vndk-27/libsoftkeymasterdevice.so /system/lib64/vndk-27/libsoftkeymasterdevice.so \
	    /vendor/lib/libkeymaster3device.so /vendor/lib64/libkeymaster3device.so \
        /vendor/lib/libMcTeeKeymaster.so /vendor/lib64/libMcTeeKeymaster.so ; do
            [ ! -f "$f" ] && continue
            # shellcheck disable=SC2010
            ctxt="$(ls -lZ "$f" | grep -oE 'u:object_r:[^:]*:s0')"
            b="$(echo "$f" | tr / _)"

            cp -a "$f" "/mnt/phh/$b"
            sed -i \
                -e 's/ro.build.version.release/ro.keymaster.xxx.release/g' \
                -e 's/ro.build.version.security_patch/ro.keymaster.xxx.security_patch/g' \
                -e 's/ro.product.model/ro.keymaster.mod/g' \
                -e 's/ro.product.brand/ro.keymaster.brn/g' \
                "/mnt/phh/$b"
            chcon "$ctxt" "/mnt/phh/$b"
            mount -o bind "/mnt/phh/$b" "$f"
        done
        if [ "$(getprop init.svc.keymaster-3-0)" = "running" ]; then
            setprop ctl.restart keymaster-3-0
        fi
        if [ "$(getprop init.svc.teed)" = "running" ]; then
            setprop ctl.restart teed
        fi
    fi
}

changeKeylayout() {
    cp -a /system/usr/keylayout /mnt/phh/keylayout
    changed=false
    if grep -q vendor.huawei.hardware.biometrics.fingerprint /vendor/etc/vintf/manifest.xml; then
        changed=true
        cp /system/phh/huawei/fingerprint.kl /mnt/phh/keylayout/fingerprint.kl
        chmod 0644 /mnt/phh/keylayout/fingerprint.kl
    fi

    if getprop ro.vendor.build.fingerprint |
        grep -qE -e "^samsung"; then
        changed=true

        cp /system/phh/samsung-gpio_keys.kl /mnt/phh/keylayout/gpio_keys.kl
        cp /system/phh/samsung-sec_touchscreen.kl /mnt/phh/keylayout/sec_touchscreen.kl
        chmod 0644 /mnt/phh/keylayout/gpio_keys.kl /mnt/phh/keylayout/sec_touchscreen.kl
    fi

    if getprop ro.vendor.build.fingerprint | grep -iq \
        -e xiaomi/polaris -e xiaomi/sirius -e xiaomi/dipper \
        -e xiaomi/wayne -e xiaomi/jasmine -e xiaomi/jasmine_sprout \
        -e xiaomi/platina -e iaomi/perseus -e xiaomi/ysl -e Redmi/begonia\
        -e xiaomi/nitrogen -e xiaomi/daisy -e xiaomi/sakura -e xiaomi/andromeda \
        -e xiaomi/whyred -e xiaomi/tulip -e xiaomi/onc; then
        if [ ! -f /mnt/phh/keylayout/uinput-goodix.kl ]; then
          cp /system/phh/empty /mnt/phh/keylayout/uinput-goodix.kl
          chmod 0644 /mnt/phh/keylayout/uinput-goodix.kl
          changed=true
        fi
        if [ ! -f /mnt/phh/keylayout/uinput-fpc.kl ]; then
          cp /system/phh/empty /mnt/phh/keylayout/uinput-fpc.kl
          chmod 0644 /mnt/phh/keylayout/uinput-fpc.kl
          changed=true
        fi
    fi

    if getprop ro.vendor.build.fingerprint | grep -qi oneplus/oneplus6/oneplus6; then
        cp /system/phh/oneplus6-synaptics_s3320.kl /mnt/phh/keylayout/synaptics_s3320.kl
        chmod 0644 /mnt/phh/keylayout/synaptics_s3320.kl
        changed=true
    fi

    if getprop ro.vendor.build.fingerprint | grep -iq -e iaomi/perseus -e iaomi/cepheus; then
        cp /system/phh/mimix3-gpio-keys.kl /mnt/phh/keylayout/gpio-keys.kl
        chmod 0644 /mnt/phh/keylayout/gpio-keys.kl
        changed=true
    fi

    if getprop ro.vendor.build.fingerprint | grep -iq -E -e '^Sony/G834'; then
        cp /system/phh/sony-gpio-keys.kl /mnt/phh/keylayout/gpio-keys.kl
        chmod 0644 /mnt/phh/keylayout/gpio-keys.kl
        changed=true
    fi

    if getprop ro.vendor.build.fingerprint |grep -iq -E -e '^Nokia/Panther';then
        cp /system/phh/nokia-soc_gpio_keys.kl /mnt/phh/keylayout/soc_gpio_keys.kl
        chmod 0644 /mnt/phh/keylayout/soc_gpio_keys.kl
        changed=true
    fi

    if getprop ro.vendor.build.fingerprint |grep -iq -E -e '^Lenovo/' && [ -f /sys/devices/virtual/touch/tp_dev/gesture_on ];then
        cp /system/phh/lenovo-synaptics_dsx.kl /mnt/phh/keylayout/synaptics_dsx.kl
        chmod 0644 /mnt/phh/keylayout/synaptics_dsx.kl
        cp /system/phh/lenovo-synaptics_dsx.kl /mnt/phh/keylayout/fts_ts.kl
        chmod 0644 /mnt/phh/keylayout/fts_ts.kl
        changed=true
    fi

    if getprop ro.build.overlay.deviceid |grep -q -e RMX1931 -e CPH1859 -e CPH1861;then
        cp /system/phh/oppo-touchpanel.kl /mnt/phh/keylayout/touchpanel.kl
        chmod 0644 /mnt/phh/keylayout/touchpanel.kl
        changed=true
    fi

    if getprop ro.vendor.build.fingerprint |grep -q -e google/;then
        cp /system/phh/google-uinput-fpc.kl /mnt/phh/keylayout/uinput-fpc.kl
        chmod 0644 /mnt/phh/keylayout/uinput-fpc.kl
        changed=true
    fi

    if [ "$changed" = true ]; then
        mount -o bind /mnt/phh/keylayout /system/usr/keylayout
        restorecon -R /system/usr/keylayout
    fi
}

if mount -o remount,rw /system; then
    resize2fs "$(grep ' /system ' /proc/mounts | cut -d ' ' -f 1)" || true
elif mount -o remount,rw /; then
    major="$(stat -c '%D' /.|sed -E 's/^([0-9a-f]+)([0-9a-f]{2})$/\1/g')"
    minor="$(stat -c '%D' /.|sed -E 's/^([0-9a-f]+)([0-9a-f]{2})$/\2/g')"
    mknod /dev/tmp-phh b $((0x$major)) $((0x$minor))
    resize2fs /dev/root || true
    resize2fs /dev/tmp-phh || true
fi
mount -o remount,ro /system || true
mount -o remount,ro / || true

for part in /dev/block/bootdevice/by-name/oppodycnvbk  /dev/block/platform/bootdevice/by-name/nvdata;do
    if [ -b "$part" ];then
        oppoName="$(grep -aohE '(RMX|CPH)[0-9]{4}' "$part" |head -n 1)"
        if [ -n "$oppoName" ];then
            setprop ro.build.overlay.deviceid "$oppoName"
        fi
    fi
done


mkdir -p /mnt/phh/
mount -t tmpfs -o rw,nodev,relatime,mode=755,gid=0 none /mnt/phh || true
mkdir /mnt/phh/empty_dir
fixSPL

changeKeylayout

mount /system/phh/empty /vendor/bin/vendor.samsung.security.proca@1.0-service || true

if grep vendor.huawei.hardware.biometrics.fingerprint /vendor/manifest.xml; then
    mount -o bind system/phh/huawei/fingerprint.kl /vendor/usr/keylayout/fingerprint.kl
fi

foundFingerprint=false
for manifest in /vendor/manifest.xml /vendor/etc/vintf/manifest.xml;do
    if grep -q -e android.hardware.biometrics.fingerprint -e vendor.oppo.hardware.biometrics.fingerprint $manifest;then
        foundFingerprint=true
    fi
done

if [ "$foundFingerprint" = false ];then
    mount -o bind system/phh/empty /system/etc/permissions/android.hardware.fingerprint.xml
fi

if ! grep android.hardware.bluetooth /vendor/manifest.xml && ! grep android.hardware.bluetooth /vendor/etc/vintf/manifest.xml; then
    mount -o bind system/phh/empty /system/etc/permissions/android.hardware.bluetooth.xml
    mount -o bind system/phh/empty /system/etc/permissions/android.hardware.bluetooth_le.xml
fi

if getprop ro.hardware | grep -qF qcom && [ -f /sys/class/backlight/panel0-backlight/max_brightness ] &&
    grep -qvE '^255$' /sys/class/backlight/panel0-backlight/max_brightness; then
    setprop persist.sys.qcom-brightness "$(cat /sys/class/backlight/panel0-backlight/max_brightness)"
fi

#Sony don't use Qualcomm HAL, so they don't have their mess
if getprop ro.vendor.build.fingerprint | grep -qE 'Sony/'; then
    setprop persist.sys.qcom-brightness -1
fi

# Xiaomi MiA3 uses OLED display which works best with this setting
if getprop ro.vendor.build.fingerprint | grep -iq \
    -e iaomi/laurel_sprout;then
    setprop persist.sys.qcom-brightness -1
fi

# Lenovo Z5s brightness flickers without this setting
if getprop ro.vendor.build.fingerprint | grep -iq \
    -e Lenovo/jd2019; then
    setprop persist.sys.qcom-brightness -1
fi

if getprop ro.vendor.build.fingerprint | grep -qi oneplus/oneplus6/oneplus6; then
    resize2fs /dev/block/platform/soc/1d84000.ufshc/by-name/userdata
fi

if getprop ro.vendor.build.fingerprint | grep -q full_k50v1_64 || getprop ro.hardware | grep -q mt6580; then
    setprop persist.sys.overlay.nightmode false
fi

if getprop ro.wlan.mtk.wifi.5g | grep -q 1; then
    setprop persist.sys.overlay.wifi5g true
fi

if grep -qF 'mkdir /data/.fps 0770 system fingerp' vendor/etc/init/hw/init.mmi.rc; then
    mkdir -p /data/.fps
    chmod 0770 /data/.fps
    chown system:9015 /data/.fps

    chown system:9015 /sys/devices/soc/soc:fpc_fpc1020/irq
    chown system:9015 /sys/devices/soc/soc:fpc_fpc1020/irq_cnt
fi

if getprop ro.vendor.build.fingerprint | grep -q -i \
    -e xiaomi/clover -e xiaomi/wayne -e xiaomi/sakura \
    -e xiaomi/nitrogen -e xiaomi/whyred -e xiaomi/platina \
    -e xiaomi/ysl -e nubia/nx60 -e nubia/nx61 -e xiaomi/tulip -e Redmi/begonia\
    -e xiaomi/lavender -e xiaomi/olive -e xiaomi/olivelite -e xiaomi/pine; then
    setprop persist.sys.qcom-brightness "$(cat /sys/class/leds/lcd-backlight/max_brightness)"
fi

if getprop ro.vendor.product.device |grep -iq -e RMX1801 -e RMX1803 -e RMX1807;then	
    setprop persist.sys.qcom-brightness "$(cat /sys/class/leds/lcd-backlight/max_brightness)"
fi

if getprop ro.build.overlay.deviceid |grep -q -e CPH1859 -e CPH1861 -e RMX1811;then	
    setprop persist.sys.qcom-brightness "$(cat /sys/class/leds/lcd-backlight/max_brightness)"
fi

if getprop ro.vendor.build.fingerprint | grep -iq \
    -e Xiaomi/beryllium/beryllium -e Xiaomi/sirius/sirius \
    -e Xiaomi/dipper/dipper -e Xiaomi/ursa/ursa -e Xiaomi/polaris/polaris \
    -e motorola/ali/ali -e iaomi/perseus/perseus -e iaomi/platina/platina \
    -e iaomi/equuleus/equuleus -e motorola/nora -e xiaomi/nitrogen \
    -e motorola/hannah -e motorola/james -e motorola/pettyl -e iaomi/cepheus \
    -e iaomi/grus -e xiaomi/cereus -e iaomi/raphael -e iaomi/davinci \
    -e iaomi/ginkgo -e iaomi/laurel_sprout -e xiaomi/andromeda; then
    mount -o bind /mnt/phh/empty_dir /vendor/lib64/soundfx
    mount -o bind /mnt/phh/empty_dir /vendor/lib/soundfx
    setprop  ro.audio.ignore_effects true
fi

if getprop ro.build.fingerprint | grep -iq \
    -e motorola/channel; then
    mount -o bind /mnt/phh/empty_dir /vendor/lib64/soundfx
    mount -o bind /mnt/phh/empty_dir /vendor/lib/soundfx
    setprop ro.audio.ignore_effects true
fi

if [ "$(getprop ro.vendor.product.manufacturer)" = "motorola" ] || [ "$(getprop ro.product.vendor.manufacturer)" = "motorola" ]; then
    if getprop ro.vendor.product.device | grep -q -e nora -e ali -e hannah -e evert -e jeter -e deen -e james -e pettyl -e jater; then
        setprop  ro.audio.ignore_effects true
        if [ "$vndk" -ge 28 ]; then
            f="/vendor/lib/libeffects.so"
            # shellcheck disable=SC2010
            ctxt="$(ls -lZ $f | grep -oE 'u:object_r:[^:]*:s0')"
            b="$(echo "$f" | tr / _)"

            cp -a $f "/mnt/phh/$b"
            sed -i \
                's/%zu errors during loading of configuration: %s/%zu errors during loading of configuration: ss/g' \
                "/mnt/phh/$b"
            chcon "$ctxt" "/mnt/phh/$b"
            mount -o bind "/mnt/phh/$b" $f
        else
            mount -o bind /mnt/phh/empty_dir /vendor/lib64/soundfx
            mount -o bind /mnt/phh/empty_dir /vendor/lib/soundfx
        fi
    fi
fi

if getprop ro.vendor.build.fingerprint | grep -q -i -e xiaomi/wayne -e xiaomi/jasmine; then
    setprop persist.imx376_sunny.low.lux 310
    setprop persist.imx376_sunny.light.lux 280
    setprop persist.imx376_ofilm.low.lux 310
    setprop persist.imx376_ofilm.light.lux 280
    echo "none" > /sys/class/leds/led:torch_2/trigger
fi

for f in /vendor/lib/mtk-ril.so /vendor/lib64/mtk-ril.so /vendor/lib/libmtk-ril.so /vendor/lib64/libmtk-ril.so; do
    [ ! -f $f ] && continue
    # shellcheck disable=SC2010
    ctxt="$(ls -lZ "$f" | grep -oE 'u:object_r:[^:]*:s0')"
    b="$(echo "$f" | tr / _)"

    cp -a "$f" "/mnt/phh/$b"
    sed -i \
        -e 's/AT+EAIC=2/AT+EAIC=3/g' \
        "/mnt/phh/$b"
    chcon "$ctxt" "/mnt/phh/$b"
    mount -o bind "/mnt/phh/$b" "$f"

    setprop persist.sys.phh.radio.force_cognitive true
    setprop persist.sys.radio.ussd.fix true
done

if getprop ro.vendor.build.fingerprint | grep -iq -e iaomi/cactus -e iaomi/cereus \
    -e Redmi/begonia; then
    setprop debug.stagefright.omx_default_rank.sw-audio 1
    setprop debug.stagefright.omx_default_rank 0
fi

if getprop ro.vendor.build.fingerprint | grep -iq -e xiaomi/ginkgo -e  xiaomi/willow; then
    mount -o bind /system/phh/empty /vendor/lib/soundfx/libvolumelistener.so
fi

mount -o bind /system/phh/empty /vendor/lib/libpdx_default_transport.so
mount -o bind /system/phh/empty /vendor/lib64/libpdx_default_transport.so

mount -o bind /system/phh/empty /vendor/overlay/SysuiDarkTheme/SysuiDarkTheme.apk || true
mount -o bind /system/phh/empty /vendor/overlay/SysuiDarkTheme/SysuiDarkThemeOverlay.apk || true

if grep -qF 'PowerVR Rogue GE8100' /vendor/lib/egl/GLESv1_CM_mtk.so ||
    grep -qF 'PowerVR Rogue' /vendor/lib/egl/libGLESv1_CM_mtk.so ||
    ( (getprop ro.product.board; getprop ro.board.platform) | grep -qiE -e msm8917 -e msm8937 -e msm8940); then

    setprop debug.hwui.renderer opengl
    setprop ro.skia.ignore_swizzle true
    if [ "$vndk" = 26 ] || [ "$vndk" = 27 ];then
       setprop debug.hwui.use_buffer_age false

    fi
fi

#If we have both Samsung and AOSP power hal, take Samsung's
if [ -f /vendor/bin/hw/vendor.samsung.hardware.miscpower@1.0-service ] && [ "$vndk" -lt 28 ]; then
    mount -o bind /system/phh/empty /vendor/bin/hw/android.hardware.power@1.0-service
fi

if [ "$vndk" = 27 ] || [ "$vndk" = 26 ]; then
    mount -o bind /system/phh/libnfc-nci-oreo.conf /system/etc/libnfc-nci.conf
fi

if busybox_phh unzip -p /vendor/app/ims/ims.apk classes.dex | grep -qF -e Landroid/telephony/ims/feature/MmTelFeature -e Landroid/telephony/ims/feature/MMTelFeature; then
    mount -o bind /system/phh/empty /vendor/app/ims/ims.apk
fi

if getprop ro.hardware | grep -qF samsungexynos -e exynos; then
    setprop debug.sf.latch_unsignaled 1
fi

if getprop ro.product.model | grep -qF ANE; then
    setprop debug.sf.latch_unsignaled 1
fi
        
if getprop ro.vendor.product.device | grep -q -e nora -e rhannah; then
    setprop debug.sf.latch_unsignaled 1
fi

if getprop ro.vendor.build.fingerprint | grep -iq -e xiaomi/daisy; then
    setprop debug.sf.latch_unsignaled 1
    setprop debug.sf.enable_hwc_vds 1
fi

if getprop ro.vendor.build.fingerprint | grep -iq -E -e 'huawei|honor' || getprop persist.sys.overlay.huawei | grep -iq -E -e 'true'; then
    p=/product/etc/nfc/libnfc_nxp_*_*.conf
    mount -o bind "$p" /system/etc/libnfc-nxp.conf ||
        mount -o bind /product/etc/libnfc-nxp.conf /system/etc/libnfc-nxp.conf || true

    p=/product/etc/nfc/libnfc_brcm_*_*.conf
    mount -o bind "$p" /system/etc/libnfc-brcm.conf ||
        mount -o bind /product/etc/libnfc-nxp.conf /system/etc/libnfc-nxp.conf || true

    mount -o bind /system/phh/libnfc-nci-huawei.conf /system/etc/libnfc-nci.conf
fi

if getprop ro.vendor.build.fingerprint | grep -qE -e ".*(crown|star)[q2]*lte.*" -e ".*(SC-0[23]K|SCV3[89]).*" && [ "$vndk" -lt 28 ]; then
    for f in /vendor/lib/libfloatingfeature.so /vendor/lib64/libfloatingfeature.so; do
        [ ! -f "$f" ] && continue
        # shellcheck disable=SC2010
        ctxt="$(ls -lZ "$f" | grep -oE 'u:object_r:[^:]*:s0')"
        b="$(echo "$f" | tr / _)"

        cp -a "$f" "/mnt/phh/$b"
        sed -i \
            -e 's;/system/etc/floating_feature.xml;/system/ph/sam-9810-flo_feat.xml;g' \
            "/mnt/phh/$b"
        chcon "$ctxt" "/mnt/phh/$b"
        mount -o bind "/mnt/phh/$b" "$f"

	setprop ro.audio.monitorRotation true
    done
fi

# This matches both Razer Phone 1 & 2
if getprop ro.vendor.build.fingerprint |grep -qE razer/cheryl;then
	setprop ro.audio.monitorRotation true
fi

if getprop ro.vendor.build.fingerprint | grep -qiE '^samsung'; then
    if getprop ro.hardware | grep -q qcom; then
        setprop persist.sys.overlay.devinputjack false
    fi

    if getprop ro.hardware | grep -q -e samsungexynos7870 -e qcom; then
        if [ "$vndk" -le 27 ]; then
            setprop persist.sys.phh.sdk_override /vendor/bin/hw/rild=27
        fi
    fi
fi

if getprop ro.vendor.build.fingerprint | grep -qE '^xiaomi/wayne/wayne.*'; then
    # Fix camera on DND, ugly workaround but meh
    setprop audio.camerasound.force true
fi

mount -o bind /mnt/phh/empty_dir /vendor/etc/audio || true

for f in /vendor/lib{,64}/hw/com.qti.chi.override.so;do
    [ ! -f $f ] && continue
    # shellcheck disable=SC2010
    ctxt="$(ls -lZ "$f" | grep -oE 'u:object_r:[^:]*:s0')"
    b="$(echo "$f" | tr / _)"

    cp -a "$f" "/mnt/phh/$b"
    sed -i \
        -e 's/ro.product.manufacturer/sys.phh.xx.manufacturer/g' \
        -e 's/ro.product.brand/sys.phh.xx.brand/g' \
        "/mnt/phh/$b"
    chcon "$ctxt" "/mnt/phh/$b"
    mount -o bind "/mnt/phh/$b" "$f"

    setprop sys.phh.xx.manufacturer "$(getprop ro.product.vendor.manufacturer)"
    setprop sys.phh.xx.brand "$(getprop ro.product.vendor.brand)"
done

if [ -n "$(getprop ro.boot.product.hardware.sku)" ] && [ -z "$(getprop ro.hw.oemName)" ];then
	setprop ro.hw.oemName "$(getprop ro.boot.product.hardware.sku)"
fi

if getprop ro.vendor.build.fingerprint | grep -qiE '^samsung/' && [ "$vndk" -ge 28 ];then
	setprop persist.sys.phh.samsung_fingerprint 0
	#obviously broken perms
	if [ "$(stat -c '%U' /sys/class/sec/tsp/cmd)" == "root" ] &&
		[ "$(stat -c '%G' /sys/class/sec/tsp/cmd)" == "root" ];then

		chcon u:object_r:sysfs_ss_writable:s0 /sys/class/sec/tsp/ear_detect_enable
		chown system /sys/class/sec/tsp/ear_detect_enable

		chcon u:object_r:sysfs_ss_writable:s0 /sys/class/sec/tsp/cmd{,_list,_result,_status}
		chown system /sys/class/sec/tsp/cmd{,_list,_result,_status}

		chown system /sys/class/power_supply/battery/wc_tx_en
		chcon u:object_r:sysfs_app_writable:s0 /sys/class/power_supply/battery/wc_tx_en
	fi

	if [ "$(stat -c '%U' /sys/class/sec/tsp/input/enabled)" == "root" ] &&
		[ "$(stat -c '%G' /sys/class/sec/tsp/input/enabled)" == "root" ];then
			chown system:system /sys/class/sec/tsp/input/enabled
			chcon u:object_r:sysfs_ss_writable:s0 /sys/class/sec/tsp/input/enabled
			setprop ctl.restart sec-miscpower-1-0
	fi
fi

if [ -f /system/phh/secure ];then
    copyprop() {
        p="$(getprop "$2")"
        if [ "$p" ]; then
            resetprop "$1" "$(getprop "$2")"
        fi
    }

    copyprop ro.build.device ro.vendor.build.device
    copyprop ro.system.build.fingerprint ro.vendor.build.fingerprint
    copyprop ro.bootimage.build.fingerprint ro.vendor.build.fingerprint
    copyprop ro.build.fingerprint ro.vendor.build.fingerprint
    copyprop ro.build.device ro.vendor.product.device
    copyprop ro.product.system.device ro.vendor.product.device
    copyprop ro.product.device ro.vendor.product.device
    copyprop ro.product.system.device ro.product.vendor.device
    copyprop ro.product.device ro.product.vendor.device
    copyprop ro.product.system.name ro.vendor.product.name
    copyprop ro.product.name ro.vendor.product.name
    copyprop ro.product.system.name ro.product.vendor.device
    copyprop ro.product.name ro.product.vendor.device
    copyprop ro.system.product.brand ro.vendor.product.brand
    copyprop ro.product.brand ro.vendor.product.brand
    copyprop ro.product.system.model ro.vendor.product.model
    copyprop ro.product.model ro.vendor.product.model
    copyprop ro.product.system.model ro.product.vendor.model
    copyprop ro.product.model ro.product.vendor.model
    copyprop ro.build.product ro.vendor.product.model
    copyprop ro.build.product ro.product.vendor.model
    copyprop ro.system.product.manufacturer ro.vendor.product.manufacturer
    copyprop ro.product.manufacturer ro.vendor.product.manufacturer
    copyprop ro.system.product.manufacturer ro.product.vendor.manufacturer
    copyprop ro.product.manufacturer ro.product.vendor.manufacturer
    copyprop ro.build.version.security_patch ro.vendor.build.security_patch
    copyprop ro.build.version.security_patch ro.keymaster.xxx.security_patch
    resetprop ro.build.tags release-keys
    resetprop ro.boot.vbmeta.device_state locked
    resetprop ro.boot.verifiedbootstate green
    resetprop ro.boot.flash.locked 1
    resetprop ro.boot.veritymode enforcing
    resetprop ro.boot.warranty_bit 0
    resetprop ro.warranty_bit 0
    resetprop ro.debuggable 0
    resetprop ro.secure 1
    resetprop ro.build.type user
    resetprop ro.build.selinux 0

    resetprop ro.adb.secure 1
    setprop ctl.restart adbd
fi

for abi in "" 64;do
    f=/vendor/lib$abi/libstagefright_foundation.so
    if [ -f "$f" ];then
        for vndk in 26 27 28;do
            mount "$f" /system/lib$abi/vndk-$vndk/libstagefright_foundation.so
        done
    fi
done

setprop ro.product.first_api_level "$vndk"

if getprop ro.boot.boot_devices |grep -v , |grep -qE .;then
    ln -s /dev/block/platform/$(getprop ro.boot.boot_devices) /dev/block/bootdevice
fi

if [ -c /dev/dsm ];then
    # /dev/dsm is a magic device on Kirin chipsets that teecd needs to access.
    # Make sure that permissions are right.
    chown system:system /dev/dsm
    chmod 0660 /dev/dsm

    # The presence of /dev/dsm indicates that we have a teecd,
    # which needs /sec_storage and /data/sec_storage_data

    mkdir -p /data/sec_storage_data
    chown system:system /data/sec_storage_data
    chcon -R u:object_r:teecd_data_file:s0 /data/sec_storage_data

    if mount | grep -q " on /sec_storage " ; then
        # /sec_storage is already mounted by the vendor, don't try to create and mount it
        # ourselves. However, some devices have /sec_storage owned by root, which means that
        # the fingerprint daemon (running as system) cannot access it.
        chown -R system:system /sec_storage
        chmod -R 0660 /sec_storage
        chcon -R u:object_r:teecd_data_file:s0 /sec_storage
    else
        # No /sec_storage provided by vendor, mount /data/sec_storage_data to it
        mount /data/sec_storage_data /sec_storage
        chown system:system /sec_storage
        chcon u:object_r:teecd_data_file:s0 /sec_storage
    fi
fi

has_hostapd=false
for i in odm oem vendor product;do
    if grep -qF android.hardware.wifi.hostapd /$i/etc/vintf/manifest.xml;then
        has_hostapd=true
    fi
done

if [ "$has_hostapd" = false ];then
    setprop persist.sys.phh.system_hostapd true
fi

#Weird /odm/phone.prop Huawei stuff
HW_PRODID="$(sed -nE 's/.*productid=([0-9xa-f]*).*/\1/p' /proc/cmdline)"
[ -z "$HW_PRODID" ] && HW_PRODID="0x$(od -A none -t x1 /sys/firmware/devicetree/base/hisi,modem_id | sed s/' '//g)"
for part in odm vendor;do
    if [ -f /$part/phone.prop ];then
        if [ -n "$HW_PRODID" ];then
            eval "$(awk 'BEGIN { a=0 }; /\[.*\].*/ { a=0 }; tolower($0) ~ /.*'"$HW_PRODID"'.*/ { a=1 }; /.*=.*/ { if(a == 1) print $0 }' /$part/phone.prop |sed -nE 's/(.*)=(.*)/setprop \1 "\2";/p')"
        fi
    fi
done

# Fix sprd adf for surfaceflinger to start
# Somehow the names of the device nodes are incorrect on Android 10; fix them by mknod
if [ -e /dev/sprd-adf-dev ];then
    mknod -m666 /dev/adf0 c 250 0
    mknod -m666 /dev/adf-interface0.0 c 250 1
    mknod -m666 /dev/adf-overlay-engine0.0 c 250 2
    restorecon /dev/adf0 /dev/adf-interface0.0 /dev/adf-overlay-engine0.0

    # SPRD GL causes crashes in system_server (not currently observed in other processes)
    # Tell the system to avoid using hardware acceleration in system_server.
    setprop ro.config.avoid_gfx_accel true
fi

# Fix manual network selection with old modem
# https://github.com/LineageOS/android_hardware_ril/commit/e3d006fa722c02fc26acdfcaa43a3f3a1378eba9
if getprop ro.vendor.build.fingerprint | grep -iq \
    -e xiaomi/polaris -e xiaomi/whyred; then
    setprop persist.sys.phh.radio.use_old_mnc_format true
fi

if getprop ro.build.overlay.deviceid |grep -qE '^RMX';then
    setprop oppo.camera.packname com.oppo.camera
    setprop sys.phh.xx.brand realme
fi

if [ -f /sys/firmware/devicetree/base/oppo,prjversion ];then
    setprop ro.separate.soft $((0x$(od -w4 -j4  -An -tx1 /sys/firmware/devicetree/base/oppo,prjversion |tr -d ' ' |head -n 1)))
fi

if [ -f /proc/oppoVersion/prjVersion ];then
    setprop ro.separate.soft $(cat /proc/oppoVersion/prjVersion)
fi

echo 1 >  /proc/tfa98xx/oppo_tfa98xx_fw_update
echo 1 > /proc/touchpanel/tp_fw_update

if getprop ro.build.overlay.deviceid |grep -qE '^RMX';then
    chmod 0660 /sys/devices/platform/soc/soc:fpc_fpc1020/{irq,irq_enable,wakelock_enable}
    if [ "$(stat -c '%U' /sys/devices/platform/soc/soc:fpc_fpc1020/irq)" == "root" ] &&
		[ "$(stat -c '%G' /sys/devices/platform/soc/soc:fpc_fpc1020/irq)" == "root" ];then
            chown system:system /sys/devices/platform/soc/soc:fpc_fpc1020/{irq,irq_enable,wakelock_enable}
            setprop persist.sys.phh.fingerprint.nocleanup true
    fi
fi

if [ "$vndk" -le 28 ] && getprop ro.hardware |grep -q -e mt6761 -e mt6763 -e mt6765 -e mt6785;then
    setprop debug.stagefright.ccodec 0
fi

if getprop ro.omc.build.version |grep -qE .;then
	for f in $(find /odm -name \*.apk);do
		mount /system/phh/empty $f
	done
fi
