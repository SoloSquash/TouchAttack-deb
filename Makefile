ARCHS = arm64 arm64e
TARGET = iphone:clang:16.5:14.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TouchAttack
TouchAttack_FILES = Tweak.x
TouchAttack_FRAMEWORKS = UIKit CoreGraphics Foundation GameController IOKit
TouchAttack_CFLAGS = -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/tweak.mk
