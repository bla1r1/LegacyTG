//
// TGCallVideoIntake - the peer's video between the reader thread and the
// decoder. Each packet is copied onto a serial queue of its own, in order:
// assembled and decoded on the reader thread it held up the audio packets
// behind it, and an iPod touch 4 got 100 of ~500.
//
// The queue's length is the measure of a phone falling behind. It drives the
// REMB ceiling sent to the peer (a quarter less, back up a step a second) and,
// seconds behind, throws the stale packets away and asks for a keyframe.
//
#import <Foundation/Foundation.h>

@class TGCallV2Session;
@class TGCallVideoEngine;

@interface TGCallVideoIntake : NSObject

/// `ceilingKbps` 0 sends no REMB.
- (instancetype)initWithSession:(TGCallV2Session *)session
                         engine:(TGCallVideoEngine *(^)(void))engine
                    ceilingKbps:(int)ceilingKbps;

/// Reader thread. Copied before it returns.
- (void)push:(const uint8_t *)rtp length:(size_t)length;
/// Reader thread: a hole the session gave up on.
- (void)lost;
/// Ends the thread; the call is over.
- (void)stop;

@end
