#!/system/bin/sh

if [ -n "$(grep phh.device.namechanged /system/build.prop)" ]; then
    exit 0
fi

if [ ! -f /vendor/build.prop ]; then
    exit 0
fi

VENDOR_FINGERPRINT="$(grep ro.vendor.build.fingerprint /vendor/build.prop | cut -d'=' -f 2)"
echo "Vendor fingerprint: $VENDOR_FINGERPRINT"

modify_on_match() {
    match_result=`echo $VENDOR_FINGERPRINT | grep $1`
    brand=$2
    model=$3
    name=$4
    device=$5
    
    if [ -n "$match_result" ]; then
        sed -i "s/ro\.product\.brand=.*/ro.product.brand=${brand}/" /system/build.prop
        sed -i "s/ro\.product\.model=.*/ro.product.model=${model}/" /system/build.prop
        sed -i "s/ro\.product\.name=.*/ro.product.name=${name}/" /system/build.prop
        sed -i "s/ro\.product\.device=.*/ro.product.device=${device}/" /system/build.prop
        sed -i "s/ro\.lineage\.device=.*/ro.lineage.device=${device}/" /system/build.prop
        
        echo "Device name changed! Match: $2 $3 $4 $5"
    fi
}

mount -o remount,rw /system

# Add devices here, e.g.
# modify_on_match <pattern> <brand> <model> <name> <device>

modify_on_match "Xiaomi/polaris/polaris.*" "Xiaomi" "MIX 2S" "polaris" "polaris"
modify_on_match "Xiaomi/clover/clover.*" "Xiaomi" "MI PAD 4" "clover" "clover"

# End of devices

if [ -z "$(grep phh.device.namechanged /system/build.prop)" ]; then
    echo -e "\nphh.device.namechanged=true\n" >> /system/build.prop
fi

mount -o remount,ro /system
