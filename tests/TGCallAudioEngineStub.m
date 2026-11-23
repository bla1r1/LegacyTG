// TGCallAudioEngineStub.m — test-only audio engine.
//
// The real engine opens a VoiceProcessingIO AudioUnit and needs libopus, which
// the command-line test build does not link. The call tests assert that frames
// reach the engine, not that they make sound, so this records them instead.
//
// The class name intentionally matches the production one: the test binary
// compiles this instead of src/TGCallAudioEngine.m.
#import "TGCallAudioEngine.h"

static NSMutableArray<NSData *> *TGIncomingFrames(void) {
	static NSMutableArray *frames = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ frames = [NSMutableArray array]; });
	return frames;
}

/// [sequence, timestamp, arrival ms] for each frame, in arrival order.
static NSMutableArray<NSArray *> *TGIncomingArrivals(void) {
	static NSMutableArray *arrivals = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ arrivals = [NSMutableArray array]; });
	return arrivals;
}

@interface TGCallAudioEngine ()
@property (nonatomic, assign) BOOL running;
@end

@implementation TGCallAudioEngine

- (BOOL)start {
	self.running = YES;
	return YES;
}

- (void)stop {
	self.running = NO;
}

- (void)peerReportedLoss:(uint8_t)fraction {
}

- (void)handleIncomingOpusFrame:(NSData *)opusFrame {
	if (opusFrame)
		[TGIncomingFrames() addObject:opusFrame];
}

- (void)handleIncomingOpusBytes:(const uint8_t *)bytes length:(size_t)length
					   sequence:(uint16_t)sequence timestamp:(uint32_t)timestamp {
	// The call path uses this one; copy here so a test can still compare the
	// frame after the packet buffer is gone. The bench replays arrivals
	// through the real playout buffer, so when each came is kept too.
	if (!bytes || !length)
		return;
	@synchronized (TGIncomingFrames()){
		[TGIncomingFrames() addObject:[NSData dataWithBytes:bytes length:length]];
		[TGIncomingArrivals() addObject:@[@(sequence), @(timestamp),
				@((int64_t)([NSProcessInfo processInfo].systemUptime * 1000.0))]];
	}
}

@end

@implementation TGCallAudioEngine (Testing)

+ (NSArray<NSData *> *)receivedFrames {
	return [TGIncomingFrames() copy];
}

+ (NSArray<NSArray *> *)receivedArrivals {
	return [TGIncomingArrivals() copy];
}

+ (void)resetReceivedFrames {
	[TGIncomingFrames() removeAllObjects];
	[TGIncomingArrivals() removeAllObjects];
}

@end
