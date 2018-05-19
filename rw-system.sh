#!/system/bin/sh

set -e

fixSPL() {
    if [ "$(getprop ro.product.cpu.abi)" == "armeabi-v7a" ];then
	    setprop ro.keymaster.mod 'AOSP on ARM32'
    else
	    setprop ro.keymaster.mod 'AOSP on ARM64'
    fi
    img="$(find /dev/block -type l |grep by-name |grep /kernel$(getprop ro.boot.slot_suffix) |head -n 1)"
    [ -z "$img" ] && img="$(find /dev/block -type l |grep by-name |grep /boot$(getprop ro.boot.slot_suffix) |head -n 1)"
    if [ -n "$img" ];then
        #Rewrite SPL/Android version if needed
        Arelease="$(getSPL $img android)"
        setprop ro.keymaster.xxx.release "$Arelease"
        setprop ro.keymaster.xxx.security_patch "$(getSPL $img spl)"

        for f in /vendor/lib64/hw/android.hardware.keymaster@3.0-impl-qti.so /system/lib64/vndk-26/libsoftkeymasterdevice.so /vendor/bin/teed;do
            [ ! -f $f ] && continue
            ctxt="$(ls -lZ $f |grep -oE 'u:object_r:[^:]*:s0')"
            b="$(basename "$f")"

            mkdir -p /mnt/phh/
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

if mount -o remount,rw /system;then
	resize2fs $(grep ' /system ' /proc/mounts |cut -d ' ' -f 1) || true
elif mount -o remount,rw /;then
	resize2fs /dev/root || true
fi
mount -o remount,ro /system || true
mount -o remount,ro / || true

fixSPL

if grep vendor.huawei.hardware.biometrics.fingerprint /vendor/manifest.xml;then
    mount -o bind system/phh/huawei/fingerprint.kl /vendor/usr/keylayout/fingerprint.kl
fi

if ! grep android.hardware.biometrics.fingerprint /vendor/manifest.xml;then
    mount -o bind system/phh/empty /system/etc/permissions/android.hardware.fingerprint.xml
fi

if ! grep android.hardware.ir /vendor/manifest.xml;then
    mount -o bind system/phh/empty /system/etc/permissions/android.hardware.consumerir.xml
fi
