#!/system/bin/sh

mount -o remount,rw /
mount -o remount,rw /system

touch /system/phh/secure
umount -l /system/xbin/su
rm /system/xbin/su
rm /system/bin/phh-su
rm /system/etc/init/su.rc
rm /system/bin/phh-securize.sh
rm -Rf /system/app/me.phh.superuser/
mount -o remount,ro /
mount -o remount,ro /system
sync
reboot
