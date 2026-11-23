//
// TGCallRinger - what a call sounds like before it is answered: the ring of
// an incoming one (with the phone vibrating every 2 s) and the ringback tone
// of an outgoing one once the peer's phone rings. Both are bundled 8 kHz
// mu-law WAVs (call_ring.wav, call_ringback.wav); the ring is also the
// sound of the incoming-call notification when the app is not in front.
//
#import <Foundation/Foundation.h>

@interface TGCallRinger : NSObject

+ (instancetype)shared;

/// Incoming: the ring on the speaker, honouring the mute switch, and the
/// vibration either way. Again while ringing does nothing, and so does a
/// call while the app is not in front (its notification rings).
- (void)ring;
/// Outgoing: the ringback in the earpiece (or the speaker, when it is on).
- (void)ringback;
- (void)stop;
/// 0 silent, 1 ringing, 2 ringback.
@property (nonatomic, readonly) NSInteger sounding;

@end
