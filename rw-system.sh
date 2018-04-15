#!/system/bin/sh

set -e

if [ "grep ' /system ' /proc/mounts  |cut -d ' ' -f 1 |wc -l" -ne 1 ];then
	exit 0
fi

img="$(find /dev/block -type l |grep by-name |grep /kernel$(getprop ro.boot.slot_suffix) |head -n 1)"
[ -z "$img" ] && img="$(find /dev/block -type l |grep by-name |grep /boot$(getprop ro.boot.slot_suffix) |head -n 1)"

if mount -o remount,rw /system;then
	resize2fs $(grep ' /system ' /proc/mounts |cut -d ' ' -f 1)
elif mount -o remount,rw /;then
	resize2fs /dev/root
fi
if [ -n "$img" -a ! -f /system/rewrite-spl-done ];then
	done=1
	v="$(getSPL $img android)"
	if [ "$(getprop ro.build.version.release)" != "$v" ];then\
		sed -i -E "s/ro.build.version.release=.*/ro.build.version.release=$v/g" /system/build.prop
		sed -i -E "s/ro.build.version.release=.*/ro.build.version.release=$v/g" /system/etc/prop.default
		done=''
	fi

	v="$(getSPL $img spl)"
	if [ "$(getprop ro.build.version.security_patch)" != "$v)" ];then
		sed -i -E "s/ro.build.version.security_patch=.*/ro.build.version.security_patch=$v/g" /system/build.prop
		sed -i -E "s/ro.build.version.security_patch=.*/ro.build.version.security_patch=$v/g" /system/etc/prop.default
		done=''
	fi
	
	if touch /system/rewrite-spl-done && [ ! "$done" ];then
		mount -o remount,ro /system
		reboot
	fi
fi
mount -o remount,ro /system
mount -o remount,ro /
