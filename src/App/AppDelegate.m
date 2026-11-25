//
// LegacyTG - Telegram client for legacy iOS
// Copyright (C) 2026 Blair <dimazzzzz342@gmail.com>
// Licensed under GNU General Public License v3.0
//
#import "AppDelegate.h"
#import "TGSampler.h"
#import "AppDelegate+URL.h"
#import "RootViewController.h"
#import "TGNavController.h"
#import "TGClient.h"
#import "TGLocalization.h"
#import "TGCallRinger.h"
#import "TGLocalizationUIKit.h"
#import "TGTheme.h"
#import "TGCall.h"
#import "TGMemberAvatarStore.h"
#import "TGEmojiStore.h"
#import "TGCustomEmojiStore.h"
#import "TGMessageLayout.h"
#import "TGMusicPlayer.h"
#import "TGVoiceRecorder.h"
#import "TGVideoNoteRecorder.h"
#import "TGCallViewController.h"
#import "TGLoginViewController.h"
#import "TGAuthRoute.h"
#import "TGChatViewController.h"
#import "TGInAppNotificationBanner.h"
#import "TGClientInternal.h"
#import "TGTermsViewController.h"
#import "TGPasscode.h"
#import "TGPasscodeViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGPerf.h"
#import "TGTextDraw.h"
#import "TGDevFeedback.h"
#import "TGiPadSimulator.h"
#import "TGiPadSplitViewController.h"
#import "TGUpdateStore.h"
#import "TGUpdateInfoViewController.h"
#import "TGAccountStore.h"
#import "TGAccountSession.h"
#import "TGSettingsStore.h"
#import "TGBackgroundKeeper.h"
#import "TGAppActivity.h"
#import "TGPeerStore.h"
#import "TGChatListStore.h"
#import "TGMediaStore.h"
#import "TGIcons.h"
#import "TGChatListViewController.h"
#import "TGDevice.h"
#include <dlfcn.h>
#if defined(__APPLE__)
#import <malloc/malloc.h>
#import <mach/mach.h>
#endif
#include <stdio.h>

@interface AppDelegate ()
@property (nonatomic, assign) BOOL updateInfoPresented;
@property (nonatomic, strong) UIView *privacyCoverView;
/// TDLib logged out or closed (Log Out, a revoked session) and no account has
/// signed in since. Kept across launches, or a relaunch went back to the
/// showcase instead of login.
@property (nonatomic, assign) BOOL signedOutOfAccount;
@property (nonatomic, assign) int64_t pendingNotificationChatId;
- (void)presentUpdateInfo:(TGUpdateInfo *)info;
@end

@implementation AppDelegate

static NSString *const TGSignedOutKey = @"TGSignedOutOfAccount";

- (BOOL)signedOutOfAccount {
	return [[NSUserDefaults standardUserDefaults] boolForKey:TGSignedOutKey];
}

- (void)setSignedOutOfAccount:(BOOL)signedOut {
	if (signedOut == self.signedOutOfAccount)
		return;
	[[NSUserDefaults standardUserDefaults] setBool:signedOut forKey:TGSignedOutKey];
}

+ (AppDelegate *)sharedDelegate {
	return (AppDelegate *)[UIApplication sharedApplication].delegate;
}

+ (void)openChatWithId:(int64_t)chatId {
	AppDelegate *app = [AppDelegate sharedDelegate];
	if (!app || !app.rootViewController || ![app.rootViewController isKindOfClass:[RootViewController class]])
		return;
	RootViewController *tabs = (RootViewController *)app.rootViewController;
	UINavigationController *nc = [tabs chatsNavigationController];
	if (!nc) return;
	[tabs switchToTab:[tabs chatsTabIndex] popToRoot:NO];

	NSDictionary *c = [[TGClient shared].chatsById objectForKey:@(chatId)];
	NSString *title = c[@"title"] ?: @"";
	BOOL isGroup = [c[@"isGroup"] boolValue];
	BOOL isForum = [c[@"isForum"] boolValue];

#if TG_DEV
	if ([[TGiPadSimulator shared] isActive]) {
		[[TGiPadSplitViewController shared] showChatWithId:chatId
		                                             title:title
		                                           isGroup:isGroup
		                                           isForum:isForum];
		return;
	}
#endif
	if (TGIsPad()) {
		[[TGiPadSplitViewController shared] showChatWithId:chatId
		                                             title:title
		                                           isGroup:isGroup
		                                           isForum:isForum];
		return;
	}

	if ([nc.topViewController isKindOfClass:[TGChatViewController class]]) {
		TGChatViewController *current = (TGChatViewController *)nc.topViewController;
		if (current.chatId == chatId) return;
	}
	TGChatViewController *vc = [[TGChatViewController alloc] init];
	vc.chatId = chatId;
	vc.chatTitle = title;
	vc.isGroup = isGroup;
	vc.hidesBottomBarWhenPushed = YES;
	[nc pushViewController:vc animated:YES];
}

/// The call that is ringing, on screen: on an incoming call in front, and
/// when the app comes to the front (its notification tapped, or opened) while
/// one still rings.
static void TGPresentRingingCall(void) {
	TGCall *call = [TGCall shared];
	if (call.state != TGCallStatePending || call.outgoing || !call.peerUserId)
		return;
	[[TGCallRinger shared] ring];
	[TGCallViewController presentForUserId:call.peerUserId
									  name:[[TGClient shared] nameForUserId:call.peerUserId]
								  outgoing:NO];
}

/// An incoming call is the one thing that takes over the screen on its own.
/// Behind another app (kept running by the keep-alive) it can only ask: a
/// notification with the ring, once per call, taken back when the call
/// stops ringing.
static void TGWatchForIncomingCalls(void) {
	static UILocalNotification *ringing;
	static int32_t notifiedCallId;
	[TGCall shared].onIncomingCall = ^(int64_t userId, int32_t callId){
		if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive){
			TGPresentRingingCall();
			return;
		}
		if (notifiedCallId == callId)
			return;
		notifiedCallId = callId;
		UILocalNotification *local = [[UILocalNotification alloc] init];
		NSString *what = [TGCall shared].isVideoCall ? TGLocalized(@"Incoming Video Call") : TGLocalized(@"Incoming Call");
		local.alertBody = [NSString stringWithFormat:@"%@: %@", [[TGClient shared] nameForUserId:userId], what];
		local.alertAction = TGLocalized(@"Answer");
		local.soundName = @"call_ring.wav";
		local.userInfo = @{ @"call" : @(callId) };
		[[UIApplication sharedApplication] presentLocalNotificationNow:local];
		ringing = local;
	};
	[[NSNotificationCenter defaultCenter] addObserverForName:TGCallStateDidChangeNotification object:nil
			queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note){
		TGCallState state = [TGCall shared].state;
		// A call that ended behind another app gives the session back: the
		// keep-alive deferred to it and has to start again, or iOS suspends us.
		if ((state == TGCallStateEnded || state == TGCallStateFailed) &&
		    [UIApplication sharedApplication].applicationState != UIApplicationStateActive &&
		    [TGSettingsStore shared].keepAliveEnabled)
			[[TGBackgroundKeeper shared] start];
		if (state == TGCallStatePending || !ringing)
			return;
		[[UIApplication sharedApplication] cancelLocalNotification:ringing];
		ringing = nil;
	}];
}

/// The per-slot "this account has signed in" flag. Slot 0 keeps the original
/// key so an existing install's YES survives the update; later slots get their
/// own so switching never reads another account's answer.
static NSString *TGAuthorizedSessionKey(void) {
	NSInteger slot = [TGClient activeAccountSlot];
	return slot > 0
			? [NSString stringWithFormat:@"hasAuthorizedSession-%ld", (long)slot]
			: @"hasAuthorizedSession";
}

static void TGSetAuthorizedSession(BOOL authorized) {
	[[NSUserDefaults standardUserDefaults] setBool:authorized forKey:TGAuthorizedSessionKey()];
}

static BOOL TGHasAuthorizedSession(void) {
	return [[NSUserDefaults standardUserDefaults] boolForKey:TGAuthorizedSessionKey()];
}

static BOOL TGDevShowcaseBuild(void) {
#if TG_DEV
	return YES;
#else
	return NO;
#endif
}

#if TG_DEV
static void TGDevCommandNotifyCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	NSString *cmd = [NSString stringWithContentsOfFile:@"/tmp/itg_cmd.txt" encoding:NSUTF8StringEncoding error:nil];
	if (!cmd.length) return;
	cmd = [cmd stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSURL *url = [NSURL URLWithString:([cmd hasPrefix:@"itglegacy://"] ? cmd : [NSString stringWithFormat:@"itglegacy://%@", cmd])];
	if (url) {
		dispatch_async(dispatch_get_main_queue(), ^{
			AppDelegate *app = (AppDelegate *)[UIApplication sharedApplication].delegate;
			[app application:[UIApplication sharedApplication] handleOpenURL:url];
		});
	}
}
#endif

/// Message text asks for custom emoji pictures through this. The store is
/// main-thread only; a measure made off it draws the same-size stand-in.
static UIImage *TGCustomEmojiFromStore(int64_t emojiId, CGFloat side) {
	if (![NSThread isMainThread])
		return nil;
	return [[TGCustomEmojiStore shared] imageForId:emojiId side:side];
}

- (BOOL)application:(UIApplication *)application
		didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	TGSetCustomEmojiProvider(TGCustomEmojiFromStore);
	NSFileManager *fm = [NSFileManager defaultManager];
#if TG_DEV
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
	NSString *cacheDir = paths.firstObject;

	// Direct diagnostics log to file so crashes persist for analysis
	NSString *logPath = [cacheDir stringByAppendingPathComponent:@"log.txt"];
	NSString *prevLogPath = [cacheDir stringByAppendingPathComponent:@"lastlog.txt"];
	[fm removeItemAtPath:prevLogPath error:nil];
	[fm copyItemAtPath:logPath toPath:prevLogPath error:nil];
	[fm removeItemAtPath:logPath error:nil];
	self.log = freopen(logPath.UTF8String, "a+", stderr);
	NSDictionary *logProt = @{NSFileProtectionKey : NSFileProtectionCompleteUntilFirstUserAuthentication};
	[fm setAttributes:logProt ofItemAtPath:logPath error:nil];
	[fm setAttributes:logProt ofItemAtPath:prevLogPath error:nil];
#endif

	TGDeviceTier tier = [TGDevice tier];
	if (tier <= TGDeviceTierLegacy) {
		int64_t (*setLimit)(int64_t) = (int64_t (*)(int64_t))dlsym(RTLD_DEFAULT, "tdsqlite3_soft_heap_limit64");
		if (!setLimit) setLimit = (int64_t (*)(int64_t))dlsym(RTLD_DEFAULT, "sqlite3_soft_heap_limit64");
		if (setLimit) {
			setLimit(tier == TGDeviceTierVintage ? (4 * 1024 * 1024) : (8 * 1024 * 1024));
		}
	}

	NSLog(@"[LegacyTG] Starting application...");
	double launchStart = TGPerfNow();
#if TG_DEV
	// ssh: touch <container>/Library/Caches/prof-launch, relaunch, then pull
	// Caches/bench-launch.txt for scripts/bench_report.py.
	// Resident memory by kind a little after launch, and once settled.
	for (int seconds = 3; seconds <= 9; seconds += 6){
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)),
				dispatch_get_main_queue(), ^{
			char line[1024];
			TGMemoryBreakdown(line, sizeof(line));
			NSLog(@"[perf] memory at %ds: %s", seconds, line);
		});
	}
	// main.m starts the sampler from a constructor, before main().
	extern int TGLaunchSampling;
	if (TGLaunchSampling){
		NSString *dump = [cacheDir stringByAppendingPathComponent:@"bench-launch.txt"];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6 * NSEC_PER_SEC)),
				dispatch_get_main_queue(), ^{
			NSLog(@"[perf] launch samples %d", TGSamplerStopAndWrite(dump.fileSystemRepresentation));
		});
	}
#endif
	double stepStart = TGPerfNow();
	TGTheme *launchTheme = [TGTheme shared];
	TGPerfReport("launch", "theme", stepStart, 50.0);
	TGWarmEmojiFont(launchTheme.messageFontSize);
	// The first bundled-emoji check opens Apple Color Emoji for its coverage
	// test; done here, it is not paid in the first chat row's preview.
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		TGTextHasUndrawableEmoji(@"\u2604");
	});
	TGWatchForIncomingCalls();

	// The pack arrives after the first screen exists. When it does, repaint
	// the chrome that was built while the lookup was still empty.
	[[NSNotificationCenter defaultCenter]
			addObserverForName:TGAppLanguageChangedNotification
						object:nil
						 queue:[NSOperationQueue mainQueue]
					usingBlock:^(NSNotification *note) {
		TGLocalizeInterface();
	}];

	// A bench phone can stay dark: the flag is set with itglegacy://stand/on
	// and cleared with stand/off. The SpringBoard tweak owns the panel.
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"TGStandScreenOff"]){
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
				dispatch_get_main_queue(), ^{
			CFNotificationCenterPostNotification(
					CFNotificationCenterGetDarwinNotifyCenter(),
					CFSTR("org.legacy.itg.screenoff"), NULL, NULL, true);
		});
	}

#if TG_DEV
	// Listen for developer automation commands via Darwin notification
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, TGDevCommandNotifyCallback, CFSTR("org.legacy.itg.cmd"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
#endif

	application.applicationIconBadgeNumber = 0;
	self.showNotifications = [[NSUserDefaults standardUserDefaults] boolForKey:@"showNotifications"];

	// The server moves the unread total while we are backgrounded; the badge
	// follows the update instead of waiting for the next foreground list read.
	[[NSNotificationCenter defaultCenter]
			addObserverForName:TGUnreadTotalChangedNotification
						object:nil queue:nil
			usingBlock:^(NSNotification *n){
		int count = [n.userInfo[@"count"] intValue];
		dispatch_async(dispatch_get_main_queue(), ^{
			[UIApplication sharedApplication].applicationIconBadgeNumber = count;
		});
	}];

	// Service notifications belong to no chat: TDLib asks for a popup, and
	// the window is the only surface that is not somebody's conversation.
	__weak AppDelegate *weakSelf = self;

	// The update screen is presented from here, once per launch, like the
	// official client does from ApplicationContext.
	[[NSNotificationCenter defaultCenter]
			addObserverForName:TGUpdateAvailableNotification
						object:nil
						 queue:[NSOperationQueue mainQueue]
					usingBlock:^(NSNotification *n){
		[weakSelf presentUpdateInfo:n.userInfo[@"info"]];
	}];

	[[NSNotificationCenter defaultCenter]
			addObserverForName:TGInAppNotificationReceivedNotification
						object:nil
						 queue:[NSOperationQueue mainQueue]
					usingBlock:^(NSNotification *n){
		NSNumber *chatIdNum = n.userInfo[@"chatId"];
		if (!chatIdNum) return;
		int64_t chatId = [chatIdNum longLongValue];
		BOOL inBackground = ([UIApplication sharedApplication].applicationState != UIApplicationStateActive);
		if (!inBackground && chatId == [TGChatViewController activeChatId])
			return;
		NSDictionary *m = n.userInfo[@"message"];
		NSDictionary *chat = [[TGClient shared].chatsById objectForKey:chatIdNum];
		NSString *title = chat[@"title"] ?: @"Telegram";
		NSString *text = TGMessagePreview(m) ?: @"";

		if (inBackground) {
			[weakSelf presentLocalNotificationForChatId:chatId
												  title:title
												   text:text
											  messageId:[m[@"id"] longLongValue]];
			return;
		}

		[TGInAppNotificationBanner showForChatId:chatId
										  title:title
										   text:text
										 avatar:nil
									   onTapped:^(int64_t targetChatId){
			[AppDelegate openChatWithId:targetChatId];
		}];
	}];

	[[NSNotificationCenter defaultCenter]
			addObserverForName:TGServiceNotificationReceivedNotification
						object:nil queue:nil
			usingBlock:^(NSNotification *n){
		NSString *text = n.userInfo[@"text"];
		if (!text.length)
			return;
		dispatch_async(dispatch_get_main_queue(), ^{
			[weakSelf showMessage:text];
		});
	}];

	// Terms that arrive after sign-in have to be accepted before the account
	// goes on; the screen owns that and the id comes with it.
	[[NSNotificationCenter defaultCenter]
			addObserverForName:TGTermsOfServiceReceivedNotification
						object:nil queue:nil
			usingBlock:^(NSNotification *n){
		dispatch_async(dispatch_get_main_queue(), ^{
			[weakSelf showTermsOfService:n.userInfo];
		});
	}];

	// Switching accounts drops the old account's screens; the resumed client's
	// next auth state is what decides login versus the chat list.
	[[NSNotificationCenter defaultCenter]
			addObserverForName:TGAccountDidSwitchNotification
						object:nil queue:nil
			usingBlock:^(NSNotification *n){
		dispatch_async(dispatch_get_main_queue(), ^{
			AppDelegate *me = weakSelf;
			if (!me)
				return;
			// Keyed by this account's user ids, or playing its media.
			[[TGMemberAvatarStore shared] reset];
			[[TGEmojiStore shared] reset];
			[[TGCustomEmojiStore shared] reset];
			[[TGMusicPlayer shared] stop];
			[[TGVoiceRecorder shared] cancel];
			[[TGVideoNoteRecorder shared] cancel];
			[[TGCall shared] reset];
			me.rootViewController = nil;
			me.loginVC = nil;
			me.currentPhoneNumber = nil;
			[me showLoadingUI];
		});
	}];

	[fm changeCurrentDirectoryPath:[[NSBundle mainBundle] bundlePath]];

	stepStart = TGPerfNow();
	self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	self.window.backgroundColor = [[TGTheme shared] listBackgroundColour];
	// Signed out, the auth state picks login; the chat list waits for one
	// that was signed in before.
	[self showScreen:TGLaunchScreenForSession(TGHasAuthorizedSession(),
			TGAuthShowcaseStandsIn(TGDevShowcaseBuild(), self.signedOutOfAccount))];
	TGPerfReport("launch", "showMainUI", stepStart, 100.0);
	stepStart = TGPerfNow();
	[self.window makeKeyAndVisible];
	TGPerfReport("launch", "makeKeyAndVisible", stepStart, 100.0);
#if TG_DEV
	[TGDevFeedback installInWindow:self.window];
	id savedPad = [[NSUserDefaults standardUserDefaults] objectForKey:@"TGiPadOrientation"];
	TGiPadOrientation padOrientation = savedPad ? (TGiPadOrientation)[savedPad integerValue] : TGiPadOrientationPortrait;
	if (padOrientation != TGiPadOrientationOff) {
		[[TGiPadSimulator shared] setOrientation:padOrientation inWindow:self.window];
	}
#endif

	[[NSNotificationCenter defaultCenter]
			addObserverForName:TGPasscodeDidUnlockNotification
						object:nil
						 queue:[NSOperationQueue mainQueue]
					usingBlock:^(NSNotification *note) {
		int64_t chatId = self.pendingNotificationChatId;
		if (chatId != 0) {
			self.pendingNotificationChatId = 0;
			[AppDelegate openChatWithId:chatId];
		}
	}];

	if ([TGPasscode hasPasscode]) {
		[TGPasscode setLocked:YES];
		[TGPasscodeViewController presentUnlockIfLocked];
	}

	stepStart = TGPerfNow();
	[self startTDLib];
	TGPerfReport("launch", "startTDLib", stepStart, 50.0);
	TGWarmFonts([TGTheme shared].messageFontSize);
	[TGUpdateStore sessionDidStart];
	// One line if the launch itself misbehaves; silent when it is healthy.
	TGPerfReport("launch", "didFinishLaunching", launchStart, 300.0);
#if TG_DEV
	[self tg_runBundledWalk];
#endif

	UILocalNotification *launchNotif = launchOptions[UIApplicationLaunchOptionsLocalNotificationKey];
	if (launchNotif) {
		NSNumber *chatIdNum = launchNotif.userInfo[@"chatId"];
		if (chatIdNum && [chatIdNum longLongValue] != 0) {
			int64_t launchChatId = [chatIdNum longLongValue];
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(500 * NSEC_PER_MSEC)),
					dispatch_get_main_queue(), ^{
				[AppDelegate openChatWithId:launchChatId];
			});
		}
	}

	return YES;
}

static void TGRecursivePurgeVC(UIViewController *vc) {
	if (!vc) return;
	if ([vc respondsToSelector:@selector(clearMemoryCaches)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
		[vc performSelector:@selector(clearMemoryCaches)];
#pragma clang diagnostic pop
	}
	if ([vc isKindOfClass:[UINavigationController class]]) {
		for (UIViewController *child in [(UINavigationController *)vc viewControllers]) {
			TGRecursivePurgeVC(child);
		}
	} else if ([vc isKindOfClass:[UITabBarController class]]) {
		for (UIViewController *child in [(UITabBarController *)vc viewControllers]) {
			TGRecursivePurgeVC(child);
		}
	}
	if (vc.presentedViewController) {
		TGRecursivePurgeVC(vc.presentedViewController);
	}
}

+ (void)purgeMemoryCaches {
	[[TGPeerStore shared] clearMemoryCaches];
	[[TGChatListStore shared] clearMemoryCaches];
	[[TGCustomEmojiStore shared] clearMemoryCaches];
	[[TGMediaStore shared] clearMemoryCaches];
	[TGIcons flush];

	UIWindow *window = [UIApplication sharedApplication].keyWindow;
	if (window.rootViewController) {
		TGRecursivePurgeVC(window.rootViewController);
	}

	[[TGClient shared] trimMemory];

#if defined(__APPLE__)
	vm_address_t *zones = NULL;
	unsigned zoneCount = 0;
	if (malloc_get_all_zones(mach_task_self(), NULL, &zones, &zoneCount) == KERN_SUCCESS) {
		for (unsigned i = 0; i < zoneCount; i++) {
			malloc_zone_pressure_relief((malloc_zone_t *)zones[i], 0);
		}
	} else {
		malloc_zone_pressure_relief(malloc_default_zone(), 0);
	}
#endif
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
	[AppDelegate purgeMemoryCaches];
}

#pragma mark - TDLib

- (void)showPrivacyCoverIfNeeded {
	if (![TGPasscode hasPasscode] || !self.window)
		return;
	if (!self.privacyCoverView) {
		UIView *cover = [[UIView alloc] initWithFrame:self.window.bounds];
		cover.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		self.privacyCoverView = cover;
	}
	self.privacyCoverView.backgroundColor = [[TGTheme shared] chatBackgroundColour];
	self.privacyCoverView.frame = self.window.bounds;
	[self.window addSubview:self.privacyCoverView];
	[self.window bringSubviewToFront:self.privacyCoverView];
}

- (void)hidePrivacyCover {
	[self.privacyCoverView removeFromSuperview];
}

- (void)applicationWillResignActive:(UIApplication *)application {
	[self showPrivacyCoverIfNeeded];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
	[self hidePrivacyCover];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
	[self showPrivacyCoverIfNeeded];
	[TGPasscode noteAppBackgrounded];
	[TGUpdateStore sessionDidEnd];
	[AppDelegate purgeMemoryCaches];
	TGAppSetInBackground(YES);
	[[TGClient shared] send:TGOnlineOptionRequest(NO)];

	if ([TGSettingsStore shared].keepAliveEnabled) {
		[[TGBackgroundKeeper shared] start];
		return;
	}

	// B13: the close has to finish before iOS suspends us.
	__block UIBackgroundTaskIdentifier task = UIBackgroundTaskInvalid;
	void (^finish)(void) = ^{
		if (task == UIBackgroundTaskInvalid)
			return;
		[application endBackgroundTask:task];
		task = UIBackgroundTaskInvalid;
	};
	task = [application beginBackgroundTaskWithExpirationHandler:finish];
	[[TGClient shared] pauseForBackground:finish];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
	dispatch_async(dispatch_get_main_queue(), ^{ TGPresentRingingCall(); });
	[[TGBackgroundKeeper shared] stop];
	TGAppSetInBackground(NO);
	// A paused TDLib is not running yet; it says online once it is ready.
	[[TGClient shared] send:TGOnlineOptionRequest(YES)];
	[TGUpdateStore sessionDidStart];
	if ([TGPasscode shouldLockOnForeground]) {
		[TGPasscodeViewController presentUnlockIfLocked];
	}
	[[TGClient shared] resumeFromBackground];
	// Resume reconnects TDLib on the main queue; the check waits a moment so
	// it does not race that restart on an old device.
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)NSEC_PER_SEC),
			dispatch_get_main_queue(), ^{
		if ([TGClient shared].authState == TGAuthStateReady)
			[[TGUpdateStore shared] checkIfDue:NO];
	});
}

- (void)startTDLib {
	TGClient *tg = [TGClient shared];
	__weak typeof(self) weakSelf = self;

	tg.onAuthState = ^(TGAuthState state){
		dispatch_async(dispatch_get_main_queue(), ^{
			AppDelegate *me = weakSelf;
			if (!me)
				return;

			switch (state){
				case TGAuthStateWaitPhoneNumber:
					TGSetAuthorizedSession(NO);
					[me routeForAuthState:state];
					[me.loginVC setBusy:NO];
					[me.loginVC showPhoneStep];
					break;
				case TGAuthStateWaitCode: {
					TGSetAuthorizedSession(NO);
					[me routeForAuthState:state];
					NSString *phone = me.currentPhoneNumber;
					if (!phone.length) {
						phone = [[TGClient shared].codeInfo objectForKey:@"phone_number"];
					}
					if (!phone.length) {
						NSLog(@"AppDelegate: WaitCode but phone is empty! Showing phone step.");
						[me.loginVC showPhoneStep];
					} else {
						[me.loginVC showCodeStepWithPhoneNumber:phone];
					}
					break;
				}
				case TGAuthStateWaitPassword:
					TGSetAuthorizedSession(NO);
					[me routeForAuthState:state];
					[me.loginVC showPasswordStep];
					break;
				case TGAuthStateWaitEmailAddress:
					TGSetAuthorizedSession(NO);
					[me routeForAuthState:state];
					[me.loginVC showEmailStep];
					break;
				case TGAuthStateWaitEmailCode:
					TGSetAuthorizedSession(NO);
					[me routeForAuthState:state];
					[me.loginVC showEmailCodeStep];
					break;
				case TGAuthStateWaitRegistration:
					TGSetAuthorizedSession(NO);
					[me routeForAuthState:state];
					[me.loginVC showRegisterStep];
					break;
				case TGAuthStateWaitOtherDeviceConfirmation:
					TGSetAuthorizedSession(NO);
					[me routeForAuthState:state];
					[me.loginVC showQRCodeStepWithLink:[TGClient shared].qrCodeLink];
					break;
				case TGAuthStateReady:
					// Telegram only takes a token for a signed-in account, so
					// the ask waits until there is one.
					[[TGSettingsStore shared] loadAppLanguagePack:TGAppLanguage() completion:nil];
					[me askForPushToken];
					TGSetAuthorizedSession(YES);
					me.signedOutOfAccount = NO;
					[me.loginVC setBusy:NO];
					[me showMainUI];
					[[TGUpdateStore shared] checkIfDue:NO];
					break;
				case TGAuthStateClosed:
				case TGAuthStateLoggingOut:
					me.signedOutOfAccount = YES;
					TGSetAuthorizedSession(NO);
					[me routeForAuthState:state];
					break;
				default:
					break;
			}
		});
	};

	// The caches belong to the account that just signed out; the new client
	// starts at WaitPhoneNumber and must not draw them.
	[TGAccountSession shared].onSignedOut = ^{
		[[TGAccountStore shared] resetStateForAccountSwitch];
		[[NSNotificationCenter defaultCenter]
				postNotificationName:TGAccountDidSwitchNotification object:[TGClient shared]];
	};

	tg.onError = ^(NSString *msg){
		dispatch_async(dispatch_get_main_queue(), ^{
			AppDelegate *me = weakSelf;
			[me.loginVC setBusy:NO];
			if ([msg isEqualToString:@"Unauthorized"] || [msg hasPrefix:@"Unauthorized"]) {
				return;
			}
			// This channel carries errors no completion claimed. During
			// sign-in that is the answer to the step on screen - a wrong
			// code, a flood wait - and the alert is how the user learns it.
			// Once signed in it is the answer to some request sent without a
			// completion (a draft cleared in a channel, a read receipt for a
			// deleted chat): a modal with TDLib's raw text over whatever the
			// user was doing. It is in the log; a request whose failure
			// matters asks with request:completion: and says so itself.
#if !TG_DEV
			if ([TGClient shared].authState == TGAuthStateReady)
				return;
#endif
			[me showMessage:msg];
		});
	};

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		if (![tg start])
			NSLog(@"TDLib unavailable - libtdjson.dylib missing or unloadable");
	});
}

#pragma mark - screens

/// The login screen is put up before its step is set: a step sent to a nil
/// loginVC is lost, which left a fresh release install on an empty chat list.
- (void)routeForAuthState:(TGAuthState)state {
	[self showScreen:TGAuthScreenForState(state, self.loginVC != nil,
			TGAuthShowcaseStandsIn(TGDevShowcaseBuild(), self.signedOutOfAccount))];
}

- (void)showScreen:(TGAuthScreen)screen {
	switch (screen){
		case TGAuthScreenLoading:
			[self showLoadingUI];
			break;
		case TGAuthScreenLogin:
			[self showLoginUI];
			break;
		case TGAuthScreenMain:
			[self showMainUI];
			break;
		case TGAuthScreenKeep:
			break;
	}
}

- (void)showLoadingUI {
	UIViewController *vc = [[UIViewController alloc] init];
	TGTheme *theme = [TGTheme shared];
	vc.view.backgroundColor = [theme listBackgroundColour];

	UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
			initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	spinner.center = CGPointMake(TGHalf(vc.view.bounds.size.width),
								 TGHalf(vc.view.bounds.size.height));
	spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
			UIViewAutoresizingFlexibleRightMargin |
			UIViewAutoresizingFlexibleTopMargin |
			UIViewAutoresizingFlexibleBottomMargin;
	[spinner startAnimating];
	[vc.view addSubview:spinner];

	// The login screen leaves the window here; kept, showLoginUI would see it
	// as still up and the spinner would stay (Reset Session from login).
	self.loginVC = nil;
#if TG_DEV
	if ([[TGiPadSimulator shared] isActive]) {
		[[TGiPadSimulator shared] updateContentViewController:vc inWindow:self.window];
		return;
	}
#endif
	[self.window setRootViewController:vc];
}

- (void)showMainUI {
	if (!self.rootViewController)
		self.rootViewController = [[RootViewController alloc] init];
#if TG_DEV
	if ([[TGiPadSimulator shared] isActive]) {
		self.loginVC = nil;
		TGiPadSplitViewController *split = [TGiPadSplitViewController shared];
		split.masterViewController = self.rootViewController;
		[[TGiPadSimulator shared] updateContentViewController:split inWindow:self.window];
		return;
	}
#endif
	if (TGIsPad()) {
		self.loginVC = nil;
		TGiPadSplitViewController *split = [TGiPadSplitViewController shared];
		split.masterViewController = self.rootViewController;
		if (self.window.rootViewController != split) {
			[self.window setRootViewController:split];
		}
		return;
	}
	if (self.window.rootViewController != self.rootViewController){
		self.loginVC = nil;
		[self.window setRootViewController:self.rootViewController];
	}
}

- (void)showLoginUI {
	if (self.loginVC)
		return;

	TGLoginViewController *loginVC = [[TGLoginViewController alloc] init];
	self.loginVC = loginVC;

	__weak typeof(self) weakSelf = self;
	loginVC.onPhoneSubmitted = ^(NSString *phoneNumber) {
		weakSelf.currentPhoneNumber = phoneNumber;
		[[TGAccountStore shared] sendPhoneNumber:phoneNumber];
	};
	loginVC.onCodeSubmitted = ^(NSString *code) {
		[[TGAccountStore shared] sendCode:code];
	};
	loginVC.onPasswordSubmitted = ^(NSString *password) {
		[[TGAccountStore shared] sendPassword:password];
	};
	loginVC.onResendCode = ^{
		[[TGAccountStore shared] resendAuthenticationCode];
	};
	loginVC.onRequestQRCode = ^{
		// Already waiting on a scan: TDLib refuses a second request with
		// "unexpected", so the code it gave is shown again instead.
		TGClient *tg = [TGClient shared];
		if (tg.authState == TGAuthStateWaitOtherDeviceConfirmation && tg.qrCodeLink.length) {
			[weakSelf.loginVC showQRCodeStepWithLink:tg.qrCodeLink];
			return;
		}
		[[TGAccountStore shared] requestQrCodeAuthentication];
	};
	loginVC.onResetSession = ^{
		weakSelf.currentPhoneNumber = nil;
		[[TGAccountStore shared] destroySession];
	};

	UINavigationController *nav =
		[[TGNavController alloc] initWithRootViewController:loginVC];
	[[TGTheme shared] styleNavigationBar:nav.navigationBar];
#if TG_DEV
	if ([[TGiPadSimulator shared] isActive]) {
		[[TGiPadSimulator shared] updateContentViewController:nav inWindow:self.window];
		self.rootViewController = nil;
		return;
	}
#endif
	[self.window setRootViewController:nav];
	self.rootViewController = nil;
}

#pragma mark - push

/// Notifications were never set up at all: the app asked iOS for nothing and
/// handed Telegram nothing, so a closed app was silent however the
/// certificate was configured.
- (void)askForPushToken {
	UIApplication *app = [UIApplication sharedApplication];
	// iOS 8 moved this; on 6 and 7 the types are registered directly.
	if ([app respondsToSelector:@selector(registerForRemoteNotifications)]){
		[app performSelector:@selector(registerForRemoteNotifications)];
		return;
	}
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	[app registerForRemoteNotificationTypes:
			(UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeBadge |
			 UIRemoteNotificationTypeSound)];
#pragma clang diagnostic pop
}

- (void)application:(UIApplication *)application
		didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
	// TDLib wants the token as hex, which is what their own clients send.
	const unsigned char *bytes = deviceToken.bytes;
	NSMutableString *hex = [NSMutableString stringWithCapacity:deviceToken.length * 2];
	for (NSUInteger i = 0; i < deviceToken.length; i++)
		[hex appendFormat:@"%02x", bytes[i]];

	// A production token registered as sandbox is silently never delivered
	// to, so the flag follows the build rather than being guessed.
#ifdef DEBUG
	BOOL sandbox = YES;
#else
	BOOL sandbox = NO;
#endif
	NSLog(@"[LegacyTG] push token %lu bytes, sandbox=%d",
			(unsigned long)deviceToken.length, sandbox);
	[[TGAccountStore shared] registerPushToken:hex sandbox:sandbox completion:^(BOOL ok){
		NSLog(@"[LegacyTG] registerDevice %@", ok ? @"accepted" : @"refused");
	}];
}

- (void)application:(UIApplication *)application
		didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
	// No certificate, no entitlement, or no network: the app works without
	// notifications and says so in the log rather than to the user.
	NSLog(@"[LegacyTG] no push token: %@", error.localizedDescription);
}

/// A notification that arrives while the app is running goes to TDLib, which
/// turns it into the ordinary updates - so the chat list moves at once
/// instead of waiting for the next poll.
- (void)application:(UIApplication *)application
		didReceiveRemoteNotification:(NSDictionary *)userInfo {
	// The blob names the account it was addressed to. One signed in on this
	// phone handles the notification; a payload for another account is not
	// this client's to process, and the id says so before the updates land.
	[[TGAccountStore shared] pushReceiverOfPayload:userInfo
								  completion:^(BOOL ok, int64_t receiverId){
		int64_t mine = [TGClient shared].pushReceiverId;
		// Only a definite answer for a different account skips the payload;
		// an id TDLib could not read is still worth handing over.
		if (ok && mine && receiverId && mine != receiverId)
			return;
		[[TGAccountStore shared] processPushPayload:userInfo];
	}];
}

#pragma mark - local notifications

- (void)presentLocalNotificationForChatId:(int64_t)chatId
                                    title:(NSString *)title
                                     text:(NSString *)text
                                messageId:(int64_t)messageId {
#if TG_DEV
	NSLog(@"[AppDelegate] local notification: chatId=%lld msgId=%lld", chatId, messageId);
#endif
	UILocalNotification *local = [[UILocalNotification alloc] init];
	if (!local)
		return;
	if ([TGPasscode hasPasscode]) {
		local.alertBody = TGLocalized(@"New message");
	} else {
		local.alertBody = text.length ? [NSString stringWithFormat:@"%@: %@", title, text] : title;
	}
	local.soundName = UILocalNotificationDefaultSoundName;
	local.userInfo = @{
		@"chatId" : @(chatId),
		@"messageId" : @(messageId),
	};
	local.applicationIconBadgeNumber = [UIApplication sharedApplication].applicationIconBadgeNumber + 1;
	[[UIApplication sharedApplication] presentLocalNotificationNow:local];
#if TG_DEV
	NSLog(@"[AppDelegate] presentLocalNotificationNow sent");
#endif
}

- (void)application:(UIApplication *)application
		didReceiveLocalNotification:(UILocalNotification *)notification {
	if (notification.userInfo[@"call"]){
		TGPresentRingingCall();
		return;
	}
	NSNumber *chatIdNum = notification.userInfo[@"chatId"];
	if (chatIdNum && [chatIdNum longLongValue] != 0) {
		int64_t chatId = [chatIdNum longLongValue];
		if ([TGPasscode hasPasscode] && [TGPasscode isLocked]) {
			self.pendingNotificationChatId = chatId;
			return;
		}
		[AppDelegate openChatWithId:chatId];
	}
}

/// Official presents the update controller from the account context as soon
/// as AppUpdateInfo arrives. Here it waits for the main UI, never covers the
/// login flow or a call, and only one screen is shown per launch.
- (void)presentUpdateInfo:(TGUpdateInfo *)info {
	if (!info || self.updateInfoPresented)
		return;
	if (self.loginVC || [TGClient shared].authState != TGAuthStateReady)
		return;
	if ([TGPasscode hasPasscode] && [TGPasscode isLocked])
		return;
	if (![self.rootViewController isKindOfClass:[RootViewController class]])
		return;

	TGCallState callState = [TGCall shared].state;
	if (callState == TGCallStatePending ||
		callState == TGCallStateExchangingKeys ||
		callState == TGCallStateConnecting ||
		callState == TGCallStateEstablished)
		return;

	UIViewController *top = self.rootViewController;
	while (top.presentedViewController)
		top = top.presentedViewController;
	if ([top isKindOfClass:[UINavigationController class]] &&
		[((UINavigationController *)top).topViewController
				isKindOfClass:[TGUpdateInfoViewController class]])
		return;

	TGUpdateInfoViewController *screen = [[TGUpdateInfoViewController alloc]
			initWithUpdateInfo:info];
	UINavigationController *nav = [[TGNavController alloc]
			initWithRootViewController:screen];
	[top presentViewController:nav animated:YES completion:nil];
	self.updateInfoPresented = YES;
}

- (void)showMessage:(NSString *)msg {
	if (!msg.length) return;
	dispatch_async(dispatch_get_main_queue(), ^{
		[TGAlertSheet showMessage:msg title:@"LegacyTG" inView:self.window];
	});
}

/// The terms popup: one screen, one Accept, and the id Telegram sent goes
/// back so the restriction lifts.
- (void)showTermsOfService:(NSDictionary *)info {
	NSString *termsId = info[@"id"];
	if (![termsId isKindOfClass:NSString.class] || !termsId.length)
		return;
	// The update can beat the window by a moment at launch; one retry is
	// enough, and dropping the terms would leave the account restricted.
	if (!self.window){
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)NSEC_PER_SEC),
				dispatch_get_main_queue(), ^{
			[[AppDelegate sharedDelegate] showTermsOfService:info];
		});
		return;
	}
	UIViewController *top = self.window.rootViewController;
	while (top.presentedViewController)
		top = top.presentedViewController;
	if (!top)
		return;
	// A second update while the sheet is up must not stack another one.
	if ([top isKindOfClass:[UINavigationController class]] &&
		[((UINavigationController *)top).topViewController
				isKindOfClass:[TGTermsViewController class]])
		return;

	TGTermsViewController *terms = [[TGTermsViewController alloc] init];
	terms.termsText = info[@"text"] ?: @"";
	terms.minUserAge = [info[@"minAge"] integerValue];
	terms.onAccept = ^{
		[[TGClient shared] acceptTermsOfService:termsId completion:nil];
	};
	UINavigationController *nav = [[UINavigationController alloc]
			initWithRootViewController:terms];
	[top presentViewController:nav animated:YES completion:nil];
}

#if TG_DEV
/// A device with no shell to send URLs through (the emulator) gets them from
/// devwalk.txt in the bundle: one "seconds itglegacy://route" per line, the
/// seconds counted from launch. scripts/emu walks inject the file.
- (void)tg_runBundledWalk {
	NSString *path = [[NSBundle mainBundle] pathForResource:@"devwalk" ofType:@"txt"];
	NSString *text = path ? [NSString stringWithContentsOfFile:path
			encoding:NSUTF8StringEncoding error:NULL] : nil;
	for (NSString *line in [text componentsSeparatedByString:@"\n"]){
		NSArray *parts = [line componentsSeparatedByString:@" "];
		if (parts.count < 2 || [line hasPrefix:@"#"])
			continue;
		double at = [parts[0] doubleValue];
		NSURL *url = [NSURL URLWithString:parts[1]];
		if (!url)
			continue;
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(at * NSEC_PER_SEC)),
				dispatch_get_main_queue(), ^{
			NSLog(@"devwalk: %@", url);
			[self application:[UIApplication sharedApplication] handleOpenURL:url];
		});
	}
}

#endif

@end
