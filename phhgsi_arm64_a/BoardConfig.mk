include build/make/target/board/generic_arm64_a/BoardConfig.mk

BOARD_SYSTEMIMAGE_PARTITION_SIZE := 1610612736
TARGET_SYSTEM_PROP := device/phh/treble/system.prop $(TARGET_SYSTEM_PROP)
BOARD_BLUETOOTH_BDROID_BUILDCFG_INCLUDE_DIR := device/phh/treble/bluetooth
