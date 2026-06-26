TARGET = iphone:clang:latest:12.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TOOL_NAME = LeitingBypass
LeitingBypass_FILES = LeitingBypass.m
LeitingBypass_CFLAGS = -fobjc-arc
LeitingBypass_FRAMEWORKS = Foundation CFNetwork
LeitingBypass_INSTALL_PATH = /var/jb/usr/lib

include $(THEOS_MAKE_PATH)/tool.mk
