#!/system/bin/sh

SYSTEM=/system
[ -d /sbin/.magisk/mirror/system ] && SYSTEM=/sbin/.magisk/mirror/system

for MOUNTPOINT in \
    /sbin/.magisk/mirror/system_root \
    /sbin/.magisk/mirror/system \
    /system \
    /
do
    [ -d $MOUNTPOINT ] && mountpoint -q $MOUNTPOINT && break
done

mount -o remount,rw $MOUNTPOINT
remount

touch $SYSTEM/phh/secure
umount -l $SYSTEM/xbin/su
rm $SYSTEM/xbin/su
rm $SYSTEM/bin/phh-su
rm $SYSTEM/etc/init/su.rc
rm $SYSTEM/bin/phh-securize.sh
rm -Rf $SYSTEM/{app,priv-app}/me.phh.superuser/
rm -Rf /data/su || true
mount -o remount,ro $MOUNTPOINT
sync
reboot
