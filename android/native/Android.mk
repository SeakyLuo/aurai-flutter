AURAI_BRIDGE_PATH := $(call my-dir)
TOP_PATH := $(AURAI_TUNNEL_PATH)
include $(TOP_PATH)/third-part/yaml/Android.mk
include $(TOP_PATH)/third-part/lwip/Android.mk
include $(TOP_PATH)/third-part/hev-task-system/Android.mk
LOCAL_PATH := $(AURAI_TUNNEL_PATH)
SRCDIR := $(LOCAL_PATH)/src
include $(LOCAL_PATH)/build.mk
include $(CLEAR_VARS)
LOCAL_MODULE := aurai-tunnel
LOCAL_SRC_FILES := $(SRCFILES) $(AURAI_BRIDGE_PATH)/tunnel_bridge.cpp
LOCAL_C_INCLUDES := $(LOCAL_PATH)/src $(LOCAL_PATH)/src/misc \
    $(LOCAL_PATH)/src/core/include $(LOCAL_PATH)/third-part/yaml/include \
    $(LOCAL_PATH)/third-part/lwip/src/include $(LOCAL_PATH)/third-part/lwip/src/ports/include \
    $(LOCAL_PATH)/third-part/hev-task-system/include
LOCAL_CFLAGS := -DFD_SET_DEFINED -DSOCKLEN_T_DEFINED -DENABLE_LIBRARY $(VERSION_CFLAGS)
LOCAL_CPPFLAGS := -std=c++17
LOCAL_STATIC_LIBRARIES := yaml lwip hev-task-system
LOCAL_LDFLAGS := -Wl,--wrap=hev_socks5_tunnel_run -Wl,-z,max-page-size=16384
include $(BUILD_SHARED_LIBRARY)
