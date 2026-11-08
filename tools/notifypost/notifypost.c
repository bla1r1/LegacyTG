// notifypost - post one Darwin notification from a jailbroken iOS device.
//
// Built by scripts/screen.sh on demand. The app and the SpringBoard tweak use
// these notifications for screen control on a bench phone.
#include <CoreFoundation/CoreFoundation.h>

int main(int argc, char **argv) {
	if (argc < 2)
		return 2;
	CFStringRef name = CFStringCreateWithCString(NULL, argv[1],
			kCFStringEncodingUTF8);
	if (!name)
		return 2;
	CFNotificationCenterPostNotification(
			CFNotificationCenterGetDarwinNotifyCenter(), name, NULL, NULL, true);
	CFRelease(name);
	return 0;
}
