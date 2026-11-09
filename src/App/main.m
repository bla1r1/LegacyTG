//
// LegacyTG - Telegram client for legacy iOS
// Copyright (C) 2026 Blair <dimazzzzz342@gmail.com>
// Licensed under GNU General Public License v3.0
//
#import <UIKit/UIKit.h>
#import "AppDelegate.h"
#import <sys/sysctl.h>
#import "TGSampler.h"
#import <sys/time.h>

static void TGLegacyExceptionHandler(NSException *exception) {
	NSLog(@"UNCAUGHT %@: %@\n%@", exception.name, exception.reason,
		  [exception.callStackSymbols componentsJoinedByString:@"\n"]);
}

/// Milliseconds from the kernel creating this process to main(): dyld, the
/// binary's rebases and binds, +load and static initialisers. Nothing in the
/// app's own launch timers can see this part.
static double TGMillisecondsSinceProcessStart(void) {
	struct kinfo_proc info;
	size_t size = sizeof(info);
	int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
	if (sysctl(mib, 4, &info, &size, NULL, 0) != 0)
		return -1;
	struct timeval start = info.kp_proc.p_starttime, now;
	gettimeofday(&now, NULL);
	return (now.tv_sec - start.tv_sec) * 1000.0 +
			(now.tv_usec - start.tv_usec) / 1000.0;
}

static double sConstructorMs = -1;
#if TG_DEV
/// Set when the launch sampler was started here, before main(): the gap
/// between our image's initialisers and main() is invisible to anything later.
int TGLaunchSampling = 0;
#endif
__attribute__((constructor)) static void TGMarkImageInitialised(void) {
	sConstructorMs = TGMillisecondsSinceProcessStart();
#if TG_DEV
	NSString *flag = [NSHomeDirectory()
			stringByAppendingPathComponent:@"Library/Caches/prof-launch"];
	if ([[NSFileManager defaultManager] fileExistsAtPath:flag]){
		[[NSFileManager defaultManager] removeItemAtPath:flag error:nil];
		TGLaunchSampling = TGSamplerStart(2000, 8000);
	}
#endif
}

int main(int argc, char *argv[]) {
	NSLog(@"[perf] premain took %.1f ms (our image initialised at %.1f ms)",
			TGMillisecondsSinceProcessStart(), sConstructorMs);
	NSSetUncaughtExceptionHandler(&TGLegacyExceptionHandler);
	@autoreleasepool {
		return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
	}
}
