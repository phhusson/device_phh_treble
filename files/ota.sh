#!/bin/bash

set -e

latestVersion=$(curl -L --silent https://api.github.com/repos/phhusson/treble_experimentations/releases |grep -oE 'v2[0-9]*' |sort -V |sort -u |tail -n 1)
if [ -n "$1" ];then
    echo "Forcing dl of version $1 instead of $latestVersion"
    latestVersion="$1"
fi

flavor=$(getprop ro.build.flavor)
fileName=""

fileName="system-quack"
if echo "$flavor" |grep -E '^treble_arm64';then
    fileName="${fileName}-arm64"
elif echo "$flavor" | grep -E '^treble_arm_';then
    fileName="${fileName}-arm"
elif echo "$flavor" | grep -E '^treble_a64_';then
    fileName="${fileName}-arm32_binder64"
fi

if echo "$flavor" |grep -E '^treble_[^_]*_b';then
    fileName="${fileName}-ab"
elif echo "$flavor" |grep -E '^treble_[^_]*_a';then
    fileName="${fileName}-aonly"
fi

if echo "$flavor" |grep -E '^treble_[^_]*_.g';then
    fileName="${fileName}-gapps"
elif echo "$flavor" |grep -E '^treble_[^_]*_.o';then
    fileName="${fileName}-go"
elif echo "$flavor" |grep -E '^treble_[^_]*_.f';then
    fileName="${fileName}-floss"
elif echo "$flavor" |grep -E '^treble_[^_]*_.v';then
    fileName="${fileName}-floss"
fi

fileName="${fileName}.img.xz"
url=https://github.com/phhusson/treble_experimentations/releases/download/"$latestVersion"/"${fileName}"
echo "Downloading from ${url}..."
#This path is really NOT ideal.
out=/sdcard/sys.img.xz
curl -L "$url" > $out

if [ "$(getprop ro.boot.dynamic_partitions)" = true ];then
    #Having to decompress twice is pretty stupid, but how do I get the size otherwise?
    size=$(busybox_phh xz -d -c < $out | simg2img_simple |wc -c)
    lptools remove system_phh
    lptools create system_phh "$size"
    lptools unmap system_phh
    dmDevice=$(lptools map system_phh|grep -oE '/dev/block/[^ ]*')
    busybox_phh xz -d -c < $out | simg2img_simple > $dmDevice
    lptools replace system_phh system
    reboot
    exit 0
else
    #Use twrp.sh
    mkdir -p /cache/phh
    uncrypt /data/media/0/sys.img.xz /cache/phh/block.map
    touch /cache/phh/flash
    reboot
    exit 0
fi

