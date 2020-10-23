#!/system/bin/sh

vndk="$(getprop persist.sys.vndk)"
[ -z "$vndk" ] && vndk="$(getprop ro.vndk.version |grep -oE '^[0-9]+')"

if getprop persist.sys.phh.no_vendor_overlay |grep -q true;then
	for part in odm vendor;do
		mount /mnt/phh/empty_dir/ /$part/overlay
	done
fi

if getprop persist.sys.phh.caf.media_profile |grep -q true;then
    setprop media.settings.xml "/vendor/etc/media_profiles_vendor.xml"
fi


if [ "$vndk" = 27 ];then
    mount /system/lib64/vndk-27/libminijail.so /vendor/lib64/libminijail_vendor.so
    mount /system/lib/vndk-27/libminijail.so /vendor/lib/libminijail_vendor.so
fi

if [ "$vndk" = 28 ];then
    mount /system/lib64/vndk-27/libminijail.so /vendor/lib64/libminijail_vendor.so
    mount /system/lib/vndk-27/libminijail.so /vendor/lib/libminijail_vendor.so
    mount /system/lib64/vndk-27/libminijail.so /system/lib64/vndk-28/libminijail.so
    mount /system/lib/vndk-27/libminijail.so /system/lib/vndk-28/libminijail.so
    mount /system/lib64/vndk-27/libminijail.so /vendor/lib64/libminijail.so
    mount /system/lib/vndk-27/libminijail.so /vendor/lib/libminijail.so
fi
