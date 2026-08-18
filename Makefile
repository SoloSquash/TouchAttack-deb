ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TouchAttack
TouchAttack_FILES = Tweak.x
TouchAttack_FRAMEWORKS = UIKit CoreGraphics Foundation

include $(THEOS_MAKE_PATH)/tweak.mk