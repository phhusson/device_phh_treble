LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := phh-gapps-go-overrides
PACKAGES.phh-gapps-go-overrides.OVERRIDES := \
	Wellbeing \
	GMailGo \
	YouTubeGo \
	DuoGo \
	Traceur \

LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH := $(TARGET_OUT_ETC)
LOCAL_SRC_FILES := nothing.txt
LOCAL_UNINSTALLABLE_MODULE := true
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE := phh-gapps-overrides
PACKAGES.phh-gapps-go-overrides.OVERRIDES := \
	Drive \
	YTMusic \
	Videos \
	Duo \
	Traceur \
	Weelbeing \

LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH := $(TARGET_OUT_ETC)
LOCAL_SRC_FILES := nothing.txt
LOCAL_UNINSTALLABLE_MODULE := true
include $(BUILD_PREBUILT)
