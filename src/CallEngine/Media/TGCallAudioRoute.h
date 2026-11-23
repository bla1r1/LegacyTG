//
// TGCallAudioRoute - the call's audio session against the rest of the
// phone: a GSM call, an alarm or Siri taking the session (the unit stops and
// has to be started again after), headphones or Bluetooth arriving and
// leaving, and the speaker on top of them.
//
#import <Foundation/Foundation.h>

@interface TGCallAudioRoute : NSObject

/// The session is ours again after an interruption. Main queue.
@property (nonatomic, copy) void (^onResume)(void);
/// Headphones or Bluetooth arrived (YES) or went (NO). Main queue.
@property (nonatomic, copy) void (^onHeadset)(BOOL attached);

- (void)start;
- (void)stop;

/// Wired headphones, a headset or Bluetooth on the current route.
+ (BOOL)headsetAttached;
/// The loudspeaker over the earpiece, or back.
+ (void)setSpeaker:(BOOL)speaker;

@end
