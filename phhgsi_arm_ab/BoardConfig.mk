include build/make/target/board/generic_arm_ab/BoardConfig.mk

BOARD_SYSTEMIMAGE_PARTITION_SIZE := 1073741824
TARGET_SYSTEM_PROP := device/phh/treble/system.prop $(TARGET_SYSTEM_PROP)
BOARD_BLUETOOTH_BDROID_BUILDCFG_INCLUDE_DIR := device/phh/treble/bluetooth
