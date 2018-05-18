#!/system/bin/sh

set -e

fixSPL() {
    img="$(find /dev/block -type l |grep by-name |grep /kernel$(getprop ro.boot.slot_suffix) |head -n 1)"
    [ -z "$img" ] && img="$(find /dev/block -type l |grep by-name |grep /boot$(getprop ro.boot.slot_suffix) |head -n 1)"
    if [ -n "$img" ];then
        #Rewrite SPL/Android version if needed
        Arelease="$(getSPL $img android)"
        setprop ro.keymaster.xxx.release $Arelease
        setprop ro.keymaster.xxx.security_patch "$(getSPL $img spl)"

        #Only Android 8.0 needs this
        if ! echo "$Arelease" |grep -qF 8.0;then
            return 0
        fi

        for f in /vendor/lib64/hw/android.hardware.keymaster@3.0-impl-qti.so /system/lib64/vndk-26/libsoftkeymasterdevice.so;do
            [ ! -f $f ] && continue
            b="$(basename "$f")"

            mkdir -p /dev/phh/
            cp $f /dev/phh/$b
            sed -i -e 's/ro.build.version.release/ro.keymaster.xxx.release/g' -e 's/ro.build.version.security_patch/ro.keymaster.xxx.security_patch/g' /dev/phh/$b
            if echo $f |grep vendor;then
                chcon u:object_r:vendor_file:s0 /dev/phh/$b
            else
                chcon u:object_r:system_file:s0 /dev/phh/$b
            fi
            chmod 0644 /dev/phh/$b
            mount -o bind /dev/phh/$b $f
        done
        setprop ctl.restart keymaster-3-0
    fi
}

if mount -o remount,rw /system;then
	resize2fs $(grep ' /system ' /proc/mounts |cut -d ' ' -f 1)
elif mount -o remount,rw /;then
	resize2fs /dev/root
fi
mount -o remount,ro /system
mount -o remount,ro /

fixSPL

if grep vendor.huawei.hardware.biometrics.fingerprint /vendor/manifest.xml;then
    mount -o bind system/phh/huawei/fingerprint.kl /vendor/usr/keylayout/fingerprint.kl
fi

if ! grep android.hardware.biometrics.fingerprint /vendor/manifest.xml;then
    mount -o bind system/phh/empty /system/etc/permissions/android.hardware.fingerprint.xml
fi

#Disable trustkernel keystore, because it doesn't work for the moment
#Found on MTK devices
mount -o bind /system/phh/empty /vendor/lib/hw/keystore.trustkernel.so || true
mount -o bind /system/phh/empty /vendor/lib64/hw/keystore.trustkernel.so || true
