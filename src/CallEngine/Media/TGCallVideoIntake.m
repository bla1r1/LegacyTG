#import "TGCallVideoIntake.h"

#import "TGCallV2Session.h"
#import "TGCallVideoEngine.h"

// Past this many packets waiting (~3 s of video at the A4's rates) the
// queue is skipped to the present; it is skipped down to kResumeBacklog,
// since packets keep coming and it is never empty.
static const int kStaleBacklog = 300;
static const int kResumeBacklog = 20;
static const int kSlowBacklog = 150;

@implementation TGCallVideoIntake {
	// A thread of its own rather than a GCD queue: on the iPod touch 4 a
	// high-priority global queue handled under 200 packets in 20 s of a call
	// with the CPU two-thirds idle, and the picture stopped after 50 frames.
	NSThread *_thread;
	NSCondition *_condition;
	NSMutableArray *_packets;   // NSData, or NSNull for a loss; under _condition
	BOOL _stopped;
	__weak TGCallV2Session *_session;
	TGCallVideoEngine *(^_engine)(void);
	int _ceiling;
	double _lastChange;
	BOOL _dropping;   // intake thread only
}

- (instancetype)initWithSession:(TGCallV2Session *)session
                         engine:(TGCallVideoEngine *(^)(void))engine
                    ceilingKbps:(int)ceilingKbps {
	if ((self = [super init])){
		_session = session;
		_engine = [engine copy];
		_ceiling = ceilingKbps;
		session.remoteVideoCapKbps = ceilingKbps;
		_condition = [[NSCondition alloc] init];
		_packets = [NSMutableArray array];
		_thread = [[NSThread alloc] initWithTarget:self selector:@selector(run) object:nil];
		_thread.name = @"tg.call.video.in";
		// Below the audio threads and the reader, above the interface.
		_thread.threadPriority = 0.75;
		[_thread start];
	}
	return self;
}

- (void)dealloc {
	[self stop];
}

- (void)stop {
	[_condition lock];
	_stopped = YES;
	[_condition signal];
	[_condition unlock];
}

- (void)adjustCeiling:(int)waiting {
	TGCallV2Session *session = _session;
	if (!_ceiling || !session)
		return;
	double now = [NSProcessInfo processInfo].systemUptime;
	int cap = session.remoteVideoCapKbps;
	if (waiting > kSlowBacklog && now - _lastChange > 2){
		_lastChange = now;
		session.remoteVideoCapKbps = MAX(150, cap * 3 / 4);
		NSLog(@"TGCallVideoIntake: %d packets waiting, peer capped at %d kbit/s", waiting,
		      session.remoteVideoCapKbps);
	} else if (waiting < 10 && cap < _ceiling && now - _lastChange > 5){
		_lastChange = now - 4;    // then a step a second
		session.remoteVideoCapKbps = MIN(_ceiling, cap + 50);
	}
}

- (void)enqueue:(id)item {
	[_condition lock];
	[_packets addObject:item];
	int waiting = (int)_packets.count;
	[_condition signal];
	[_condition unlock];
	[self adjustCeiling:waiting];
}

- (void)push:(const uint8_t *)rtp length:(size_t)length {
	[self enqueue:[NSData dataWithBytes:rtp length:length]];
}

- (void)lost {
	[self enqueue:[NSNull null]];
}

- (void)run {
	unsigned handled = 0;
	double busy = 0, windowStart = 0;
	for (;;){
		id item;
		int left;
		@autoreleasepool {
			[_condition lock];
			while (!_packets.count && !_stopped)
				[_condition wait];
			if (_stopped){
				[_condition unlock];
				return;
			}
			item = _packets[0];
			[_packets removeObjectAtIndex:0];
			left = (int)_packets.count;
			[_condition unlock];

			TGCallVideoEngine *engine = _engine();
			if (item == [NSNull null]){
				[engine remoteVideoLost];
				continue;
			}
			if (left > kStaleBacklog || (left > kResumeBacklog && _dropping)){
				if (!_dropping){
					_dropping = YES;
					NSLog(@"TGCallVideoIntake: %d packets behind, skipping to the next keyframe", left);
					[engine remoteVideoLost];
				}
				continue;
			}
			if (_dropping){
				_dropping = NO;
				[_session requestKeyframe];
			}
			NSData *packet = item;
			double t0 = [NSProcessInfo processInfo].systemUptime;
			[engine handleIncomingVideoRtp:(const uint8_t *)packet.bytes length:packet.length];
			double t1 = [NSProcessInfo processInfo].systemUptime;
			busy += t1 - t0;
			if (!windowStart)
				windowStart = t1;
			if (++handled % 200 == 0){
				double span = t1 - windowStart;
				NSLog(@"TGCallVideoIntake: 200 packets in %.1f s, %.1f ms each, busy %.0f%%, %d waiting",
				      span, busy * 1000 / 200, span > 0 ? busy * 100 / span : 0, left);
				busy = 0;
				windowStart = t1;
			}
		}
	}
}

@end
