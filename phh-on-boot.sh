#!/system/bin/sh


#Clear looping services
sleep 30
getprop | \
    grep restarting | \
    sed -nE -e 's/\[([^]]*).*/\1/g'  -e 's/init.svc.(.*)/\1/p' |
    while read svc ;do
        setprop ctl.stop $svc
    done

if grep -qF android.hardware.boot /vendor/manifest.xml;then
	bootctl mark-boot-successful
fi

if [ $FOUND_HUAWEI =  1];then
rm -rf /system/etc/libnfc-nci.conf
cp --symbolic-link /product/etc/nfc/* /system/etc/
setprop ro.hardware.nfc_nci pn54x.default
fi
