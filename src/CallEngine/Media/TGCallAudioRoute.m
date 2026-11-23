#import "TGCallAudioRoute.h"

#import <AVFoundation/AVFoundation.h>

@implementation TGCallAudioRoute {
	BOOL _observing;
}

- (void)start {
	if (_observing)
		return;
	_observing = YES;
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center addObserver:self selector:@selector(interrupted:) name:AVAudioSessionInterruptionNotification object:nil];
	[center addObserver:self selector:@selector(routeChanged:) name:AVAudioSessionRouteChangeNotification object:nil];
}

- (void)stop {
	_observing = NO;
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)interrupted:(NSNotification *)note {
	NSUInteger type = [note.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
	NSLog(@"TGCallAudioRoute: interruption %@", type == AVAudioSessionInterruptionTypeBegan ? @"began" : @"ended");
	if (type != AVAudioSessionInterruptionTypeEnded)
		return;
	// The call's category again, then the unit: after a GSM call or an alarm
	// it is stopped and nothing starts it but us.
	AVAudioSession *session = [AVAudioSession sharedInstance];
	[session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionAllowBluetooth error:nil];
	[session setMode:AVAudioSessionModeVoiceChat error:nil];
	[session setActive:YES error:nil];
	dispatch_async(dispatch_get_main_queue(), ^{
		if (self.onResume)
			self.onResume();
	});
}

- (void)routeChanged:(NSNotification *)note {
	NSUInteger reason = [note.userInfo[AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue];
	if (reason != AVAudioSessionRouteChangeReasonNewDeviceAvailable &&
	    reason != AVAudioSessionRouteChangeReasonOldDeviceUnavailable)
		return;
	BOOL attached = [TGCallAudioRoute headsetAttached];
	NSLog(@"TGCallAudioRoute: headset %@", attached ? @"in" : @"out");
	dispatch_async(dispatch_get_main_queue(), ^{
		if (self.onHeadset)
			self.onHeadset(attached);
	});
}

+ (BOOL)headsetAttached {
	for (AVAudioSessionPortDescription *port in [AVAudioSession sharedInstance].currentRoute.outputs){
		NSString *type = port.portType;
		if ([type isEqualToString:AVAudioSessionPortHeadphones] ||
		    [type isEqualToString:AVAudioSessionPortBluetoothHFP] ||
		    [type isEqualToString:AVAudioSessionPortBluetoothA2DP] ||
		    [type isEqualToString:AVAudioSessionPortUSBAudio])
			return YES;
	}
	return NO;
}

+ (void)setSpeaker:(BOOL)speaker {
	[[AVAudioSession sharedInstance] overrideOutputAudioPort:speaker ? AVAudioSessionPortOverrideSpeaker
	                                                                 : AVAudioSessionPortOverrideNone error:nil];
}

@end
