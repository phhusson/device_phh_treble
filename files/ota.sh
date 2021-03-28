#!/system/bin/sh

set -e

if ! [ "$(getprop ro.boot.dynamic_partitions)" = true ];then
    echo "OTA is supported only for devices with dynamic partitions!"
    exit 1
fi

flavor=$(getprop ro.product.product.name)
nextVersion=$(curl --silent -L https://raw.githubusercontent.com/phhusson/treble_experimentations/master/ota/roar/$flavor/date)
if [ -z "$nextVersion" ];then
    echo "Couldn't find any OTA for $flavor"
    exit 1
fi

url=$(curl --silent -L https://raw.githubusercontent.com/phhusson/treble_experimentations/master/ota/roar/$flavor/url)
size=$(curl --silent -L https://raw.githubusercontent.com/phhusson/treble_experimentations/master/ota/roar/$flavor/size)

if [ "$(getprop ro.product.build.date.utc)" = "$nextVersion" ];then
    echo "Installing $nextVersion onto itself, aborting"
    exit 1
fi

if ! curl --silent -L https://raw.githubusercontent.com/phhusson/treble_experimentations/master/ota/roar/$flavor/known_releases |grep -q $(getprop ro.product.build.date.utc);then
    echo "Warning! The build you are currently running is unknown. Type YES to confirm you want to apply OTA from $url"
    read answer
    if ! [ "$answer" = YES ];then
        exit 1
    fi
fi

if [ -b /dev/tmp-phh ] && ! tune2fs -l /dev/tmp-phh  |grep 'Last mount time' |grep -q n/a;then
    echo "Warning! It looks like you modified your system image! Flashing this OTA will revert this!"
    echo "Type YES to acknowledge"
    read answer
    if ! [ "$answer" = YES ];then
        exit 1
    fi
fi

lptools remove system_phh
free=$(lptools free |grep -oE '[0-9]+$')
if [ "$free" -le "$size" ];then
    echo "Warning! There doesn't seem to be enough space on super partition."
    echo "Do you want me to try to make more space? Type YES"
    read answer
    if ! [ "$answer" = YES ];then
        exit 1
    fi
    lptools clear-cow || true
    lptools unlimited-group || true
    lptools remove product || true
    lptools remove product$(getprop ro.boot.slot_suffix) || true
    free=$(lptools free |grep -oE '[0-9]+$')
    if [ "$free" -le "$size" ];then
        echo "Sorry, there is still not enough space available. OTA requires $size, you have $free available"
        exit 1
    fi
fi


lptools create system_phh "$size"
lptools unmap system_phh
dmDevice=$(lptools map system_phh|grep -oE '/dev/block/[^ ]*')
echo "Flashing from ${url}..."

curl -L "$url" | busybox_phh xz -d -c | simg2img_simple > $dmDevice

lptools replace system_phh system
reboot
exit 0
