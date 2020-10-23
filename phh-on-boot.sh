#!/system/bin/sh

vndk="$(getprop persist.sys.vndk)"
[ -z "$vndk" ] && vndk="$(getprop ro.vndk.version |grep -oE '^[0-9]+')"

[ "$(getprop vold.decrypt)" = "trigger_restart_min_framework" ] && exit 0

setprop ctl.start media.swcodec

for i in wpa p2p;do
	if [ ! -f /data/misc/wifi/${i}_supplicant.conf ];then
		cp /vendor/etc/wifi/wpa_supplicant.conf /data/misc/wifi/${i}_supplicant.conf
	fi
	chmod 0660 /data/misc/wifi/${i}_supplicant.conf
	chown wifi:system /data/misc/wifi/${i}_supplicant.conf
done

if [ -f /vendor/bin/mtkmal ];then
    if [ "$(getprop persist.mtk_ims_support)" = 1 ] || [ "$(getprop persist.mtk_epdg_support)" = 1 ];then
        setprop persist.mtk_ims_support 0
        setprop persist.mtk_epdg_support 0
        reboot
    fi
fi

if grep -qF android.hardware.boot /vendor/manifest.xml || grep -qF android.hardware.boot /vendor/etc/vintf/manifest.xml ;then
	bootctl mark-boot-successful
fi

setprop ctl.restart sec-light-hal-2-0
if find /sys/firmware -name support_fod |grep -qE .;then
	setprop ctl.restart vendor.fps_hal
fi

setprop ctl.stop storageproxyd

sleep 10
crashingProcess=$(getprop ro.init.updatable_crashing_process_name |grep media)
if [ "$vndk" = 27 ] && ( getprop init.svc.mediacodec |grep -q restarting || [ -n "$crashingProcess" ]);then
    mount /system/lib64/vndk-27/libminijail.so /vendor/lib64/libminijail_vendor.so
    mount /system/lib/vndk-27/libminijail.so /vendor/lib/libminijail_vendor.so
fi

if [ "$vndk" = 28 ] && ( getprop |grep init.svc | grep media |grep -q restarting || [ -n "$crashingProcess" ] );then
    mount /system/lib64/vndk-27/libminijail.so /vendor/lib64/libminijail_vendor.so
    mount /system/lib/vndk-27/libminijail.so /vendor/lib/libminijail_vendor.so
    mount /system/lib64/vndk-27/libminijail.so /system/lib64/vndk-28/libminijail.so
    mount /system/lib/vndk-27/libminijail.so /system/lib/vndk-28/libminijail.so
    mount /system/lib64/vndk-27/libminijail.so /vendor/lib64/libminijail.so
    mount /system/lib/vndk-27/libminijail.so /vendor/lib/libminijail.so
fi

#Clear looping services
sleep 30
getprop | \
    grep restarting | \
    sed -nE -e 's/\[([^]]*).*/\1/g'  -e 's/init.svc.(.*)/\1/p' |
    while read -r svc ;do
        setprop ctl.stop "$svc"
    done
