#!/system/bin/sh


vndk="$(getprop persist.sys.vndk)"
setprop sys.usb.ffs.aio_compat true

fixSPL() {
    if [ "$(getprop ro.product.cpu.abi)" == "armeabi-v7a" ];then
	    setprop ro.keymaster.mod 'AOSP on ARM32'
    else
	    setprop ro.keymaster.mod 'AOSP on ARM64'
    fi
    img="$(find /dev/block -type l -name kernel$(getprop ro.boot.slot_suffix) |grep by-name |head -n 1)"
    [ -z "$img" ] && img="$(find /dev/block -type l -name boot$(getprop ro.boot.slot_suffix) |grep by-name |head -n 1)"
    if [ -n "$img" ];then
        #Rewrite SPL/Android version if needed
        Arelease="$(getSPL $img android)"
        setprop ro.keymaster.xxx.release "$Arelease"
        setprop ro.keymaster.xxx.security_patch "$(getSPL $img spl)"

        for f in /vendor/lib64/hw/android.hardware.keymaster@3.0-impl-qti.so /vendor/lib/hw/android.hardware.keymaster@3.0-impl-qti.so /system/lib64/vndk-26/libsoftkeymasterdevice.so /vendor/bin/teed /system/lib64/vndk/libsoftkeymasterdevice.so /system/lib/vndk/libsoftkeymasterdevice.so /system/lib/vndk-26/libsoftkeymasterdevice.so;do
            [ ! -f $f ] && continue
            ctxt="$(ls -lZ $f |grep -oE 'u:object_r:[^:]*:s0')"
            b="$(echo "$f"|tr / _)"

            cp -a $f /mnt/phh/$b
            sed -i \
		    -e 's/ro.build.version.release/ro.keymaster.xxx.release/g' \
		    -e 's/ro.build.version.security_patch/ro.keymaster.xxx.security_patch/g' \
		    -e 's/ro.product.model/ro.keymaster.mod/g' \
		    /mnt/phh/$b
            chcon "$ctxt" /mnt/phh/$b
            mount -o bind /mnt/phh/$b $f
        done
        if [ "$(getprop init.svc.keymaster-3-0)" == "running" ];then
		setprop ctl.restart keymaster-3-0
	fi
        if [ "$(getprop init.svc.teed)" == "running" ];then
		setprop ctl.restart teed
	fi
    fi
}

changeKeylayout() {
    cp -a /system/usr/keylayout /mnt/phh/keylayout
    changed=false

    if getprop ro.vendor.build.fingerprint | \
        grep -qE -e ".*(crown|star)[q2]*lte.*"  -e ".*(SC-0[23]K|SCV3[89]).*";then
        changed=true

        cp /system/phh/samsung-gpio_keys.kl /mnt/phh/keylayout/gpio_keys.kl
        cp /system/phh/samsung-sec_touchscreen.kl /mnt/phh/keylayout/sec_touchscreen.kl
        chmod 0644 /mnt/phh/keylayout/gpio_keys.kl /mnt/phh/keylayout/sec_touchscreen.kl
    fi

    if getprop ro.vendor.build.fingerprint |grep -iq -e xiaomi/polaris -e xiaomi/sirius -e xiaomi/dipper -e xiaomi/wayne -e xiaomi/jasmine;then
        cp /system/phh/empty /mnt/phh/keylayout/uinput-goodix.kl
        chmod 0644 /mnt/phh/keylayout/uinput-goodix.kl
        cp /system/phh/empty /mnt/phh/keylayout/uinput-fpc.kl
        chmod 0644 /mnt/phh/keylayout/uinput-fpc.kl
        changed=true
    fi

    if getprop ro.vendor.build.fingerprint |grep -qi oneplus/oneplus6/oneplus6;then
        cp /system/phh/oneplus6-synaptics_s3320.kl /mnt/phh/keylayout/synaptics_s3320.kl
        chmod 0644 /mnt/phh/keylayout/synaptics_s3320.kl
        changed=true
    fi

    if [ "$changed" == true ];then
        mount -o bind /mnt/phh/keylayout /system/usr/keylayout
        restorecon -R /system/usr/keylayout
    fi
}

if mount -o remount,rw /system;then
	resize2fs $(grep ' /system ' /proc/mounts |cut -d ' ' -f 1) || true
elif mount -o remount,rw /;then
	resize2fs /dev/root || true
fi
mount -o remount,ro /system || true
mount -o remount,ro / || true

mkdir -p /mnt/phh/
mount -t tmpfs -o rw,nodev,relatime,mode=755,gid=0 none /mnt/phh || true
mkdir /mnt/phh/empty_dir
fixSPL

changeKeylayout

if grep vendor.huawei.hardware.biometrics.fingerprint /vendor/manifest.xml;then
    mount -o bind system/phh/huawei/fingerprint.kl /vendor/usr/keylayout/fingerprint.kl
fi

if ! grep android.hardware.biometrics.fingerprint /vendor/manifest.xml;then
    mount -o bind system/phh/empty /system/etc/permissions/android.hardware.fingerprint.xml
fi

if getprop ro.hardware |grep -qF qcom && [ -f /sys/class/backlight/panel0-backlight/max_brightness ] && \
        grep -qvE '^255$' /sys/class/backlight/panel0-backlight/max_brightness;then
    setprop persist.sys.qcom-brightness $(cat /sys/class/backlight/panel0-backlight/max_brightness)
fi

if getprop ro.vendor.build.fingerprint |grep -qi oneplus/oneplus6/oneplus6;then
	resize2fs /dev/block/platform/soc/1d84000.ufshc/by-name/userdata
fi

if getprop ro.vendor.build.fingerprint |grep -q full_k50v1_64 || getprop ro.hardware |grep -q mt6580 ;then
	setprop persist.sys.overlay.nightmode false
fi

if getprop ro.wlan.mtk.wifi.5g |grep -q 1;then
	setprop persist.sys.overlay.wifi5g true
fi

if grep -qF 'mkdir /data/.fps 0770 system fingerp' vendor/etc/init/hw/init.mmi.rc;then
    mkdir -p /data/.fps
    chmod 0770 /data/.fps
    chown system:9015 /data/.fps

    chown system:9015 /sys/devices/soc/soc:fpc_fpc1020/irq
    chown system:9015 /sys/devices/soc/soc:fpc_fpc1020/irq_cnt
fi

if getprop ro.vendor.build.fingerprint |grep -q -e Xiaomi/clover/clover -e iaomi/wayne/wayne;then
    setprop persist.sys.qcom-brightness $(cat /sys/class/leds/lcd-backlight/max_brightness)
fi

if getprop ro.vendor.build.fingerprint |grep -q \
	-e Xiaomi/beryllium/beryllium -e Xiaomi/sirius/sirius \
	-e Xiaomi/dipper/dipper -e Xiaomi/ursa/ursa -e Xiaomi/polaris/polaris \
	-e motorola/ali/ali ;then
    mount -o bind /mnt/phh/empty_dir /vendor/lib64/soundfx
    mount -o bind /mnt/phh/empty_dir /vendor/lib/soundfx
fi

if getprop ro.vendor.build.fingerprint |grep -q -i -e xiaomi/wayne -e xiaomi/jasmine;then
    setprop persist.imx376_sunny.low.lux 310
    setprop persist.imx376_sunny.light.lux 280
    setprop persist.imx376_ofilm.low.lux 310
    setprop persist.imx376_ofilm.light.lux 280
fi

for f in /vendor/lib/mtk-ril.so /vendor/lib64/mtk-ril.so;do
    [ ! -f $f ] && continue
    ctxt="$(ls -lZ $f |grep -oE 'u:object_r:[^:]*:s0')"
    b="$(echo "$f"|tr / _)"

    cp -a $f /mnt/phh/$b
    sed -i \
        -e 's/AT+EAIC=2/AT+EAIC=3/g' \
        /mnt/phh/$b
    chcon "$ctxt" /mnt/phh/$b
    mount -o bind /mnt/phh/$b $f
done

mount -o bind /system/phh/empty /vendor/overlay/SysuiDarkTheme/SysuiDarkTheme.apk || true
mount -o bind /system/phh/empty /vendor/overlay/SysuiDarkTheme/SysuiDarkThemeOverlay.apk || true

if grep -qF 'PowerVR Rogue GE8100' /vendor/lib/egl/GLESv1_CM_mtk.so;then
	setprop debug.hwui.renderer opengl
fi

#If we have both Samsung and AOSP power hal, take Samsung's
if [ -f /vendor/bin/hw/vendor.samsung.hardware.miscpower@1.0-service ];then
	mount -o bind /system/phh/empty /vendor/bin/hw/android.hardware.power@1.0-service
fi

if [ "$vndk" == 27 -o "$vndk" == 26 ];then
    mount -o bind /system/phh/libnfc-nci-oreo.conf /system/etc/libnfc-nci.conf
fi

if busybox_phh unzip -p /vendor/app/ims/ims.apk classes.dex |grep -qF -e Landroid/telephony/ims/feature/MmTelFeature -e Landroid/telephony/ims/feature/MMTelFeature;then
    mount -o bind /system/phh/empty /vendor/app/ims/ims.apk
fi
