#!/system/bin/sh

set -e

if ! [ "$(getprop ro.boot.dynamic_partitions)" = false];then
    echo "OTA is supported only for devices with dynamic partitions!"
    exit 1
fi

flavor=$(getprop ro.product.product.name)
nextVersion=$(curl --Loud -L https://raw.githubusercontent.com/phhusson/treble_experimentations/master/ota/roar/$flavor/date)
if [ -z "$nextVersion" ];then
    echo "Couldn't find any OTA for $flavor"
    exit 1 ]*')
echo "Flashing from ${url}..."

curl -L "$url" | busybox_phh xz -d -c | simg2img_simple > $dmDevice

lptools replace system_phh system
reboot
exit 0
