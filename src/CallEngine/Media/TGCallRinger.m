#import "TGCallRinger.h"

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

typedef NS_ENUM(NSInteger, TGRingKind) { TGRingNone, TGRingIncoming, TGRingBack };

@implementation TGCallRinger {
	AVAudioPlayer *_player;
	NSTimer *_vibration;
	TGRingKind _kind;
}

+ (instancetype)shared {
	static TGCallRinger *ringer;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ ringer = [[TGCallRinger alloc] init]; });
	return ringer;
}

- (void)playSound:(NSString *)name kind:(TGRingKind)kind {
	if (_kind == kind)
		return;
	[self stop];
	_kind = kind;
	NSURL *url = [[NSBundle mainBundle] URLForResource:name withExtension:@"wav"];
	_player = url ? [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil] : nil;
	_player.numberOfLoops = -1;
	[_player play];
	NSLog(@"TGCallRinger: %@ %@", name, _player ? @"playing" : @"missing");
}

- (void)ring {
	// Behind another app the notification rings; changing the session there
	// would stop the keep-alive's audio and get the app suspended mid-ring.
	if (_kind == TGRingIncoming)
		return;
#if TARGET_OS_IPHONE
	if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive)
		return;
#endif
	// SoloAmbient: the ring obeys the mute switch, as the phone's own does;
	// the vibration below does not.
	[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategorySoloAmbient error:nil];
	[[AVAudioSession sharedInstance] setActive:YES error:nil];
	[self playSound:@"call_ring" kind:TGRingIncoming];
	AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
	_vibration = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(vibrate)
	                                            userInfo:nil repeats:YES];
}

- (void)vibrate {
	AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}

- (void)ringback {
	if (_kind == TGRingBack)
		return;
	// The call's own category already, so the tone comes out where the voice
	// will and nothing has to change when the peer answers.
	AVAudioSession *session = [AVAudioSession sharedInstance];
	[session setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
	[session setMode:AVAudioSessionModeVoiceChat error:nil];
	[session setActive:YES error:nil];
	[self playSound:@"call_ringback" kind:TGRingBack];
}

- (NSInteger)sounding {
	return _kind;
}

- (void)stop {
	[_vibration invalidate];
	_vibration = nil;
	[_player stop];
	_player = nil;
	_kind = TGRingNone;
}

@end
