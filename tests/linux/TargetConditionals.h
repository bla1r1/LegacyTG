// tests/linux/TargetConditionals.h - the Linux host run builds what the Mac
// host run builds: the code paths for a Mac, not for a phone.
#pragma once
#define TARGET_OS_MAC 1
#define TARGET_OS_OSX 1
#define TARGET_OS_IPHONE 0
#define TARGET_OS_IOS 0
#define TARGET_OS_SIMULATOR 0
#define TARGET_IPHONE_SIMULATOR 0
#define TARGET_OS_TV 0
#define TARGET_OS_WATCH 0
