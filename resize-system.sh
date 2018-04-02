#!/system/bin/sh

set -e

if [ "grep ' /system ' /proc/mounts  |cut -d ' ' -f 1 |wc -l" -ne 1 ];then
	exit 0
fi

mount -o remount,rw /system
resize2fs $(grep ' /system ' /proc/mounts |cut -d ' ' -f 1)
mount -o remount,ro /system
