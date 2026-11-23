//
// TGCall - 1:1 call controller: TDLib for signalling, tgcalls 9.0.0 (or
// libtgvoip for older peers) for audio and video.
//
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, TGCallState) {
    TGCallStateNone = 0,
    TGCallStatePending,        ///< ringing, either direction
    TGCallStateExchangingKeys,
    TGCallStateConnecting,
    TGCallStateEstablished,
    TGCallStateEnded,
    TGCallStateFailed
};

@class TGCallVideoEngine;

@interface TGCall : NSObject

+ (instancetype)shared;

@property (nonatomic, readonly) TGCallState state;
@property (nonatomic, readonly) int32_t callId;
/// The id the last call wore, kept after teardown so a rating can still name
/// the call it is about.
@property (nonatomic, readonly) int32_t lastCallId;
@property (nonatomic, readonly) int64_t peerUserId;
@property (nonatomic, readonly) BOOL outgoing;
@property (nonatomic, readonly) BOOL muted;
@property (nonatomic, readonly) BOOL videoActive;
/// The peer's camera is on and its first frame is decoded.
@property (nonatomic, readonly) BOOL peerVideoActive;
/// The call was placed or offered as a video call (TDLib is_video).
@property (nonatomic, readonly) BOOL isVideoCall;
/// The call runs on 9.0.0 and this device can do video: the camera can be
/// turned on.
@property (nonatomic, readonly) BOOL videoAvailable;
@property (nonatomic, strong, readonly) TGCallVideoEngine *videoEngine;
@property (nonatomic, readonly) NSData *callKey;
@property (nonatomic, readonly) NSArray *emojis;

- (void)setSpeaker:(BOOL)speaker;
- (void)setVideoEnabled:(BOOL)enabled;
- (void)switchCamera;
/// Camera on for the local preview only; nothing is sent until
/// -setVideoEnabled:YES. NO when camera access is denied or there is no video.
- (BOOL)startCameraPreview;
/// Undoes -startCameraPreview unless video was turned on meanwhile.
- (void)stopCameraPreview;

/// An outgoing call's progress before it is answered, as official words it:
/// "Contacting..." until the server made it, "Waiting..." until the other
/// phone has it, then "Ringing..." (callStatePending is_created, is_received).
@property (nonatomic, readonly) NSString *pendingStatus;

/// Telegram asked for a rating of the call that just ended
/// (callStateDiscarded need_rating); official asks only then.
@property (nonatomic, readonly) BOOL needsRating;

/// Why the last call ended, when the other side said. Nil otherwise.
@property (nonatomic, readonly) NSString *endReason;

/// Main queue, whenever the state changes.
@property (nonatomic, copy) void (^onStateChanged)(TGCallState state);
@property (nonatomic, copy) void (^onIncomingCall)(int64_t peerUserId, int32_t callId);
@property (nonatomic, copy) void (^onPeerVideoChanged)(BOOL active);

/// Ask TDLib to place a call. The rest arrives through -handleUpdate:.
/// Established, but nothing from the peer for 2 s: the screen says
/// Connecting... over the timer until it comes back, as official does.
@property (nonatomic, readonly) BOOL isReconnecting;
/// No call is up. Ended and Failed count: they stay until the next call,
/// and a check for None alone stopped every second call in one launch.
@property (nonatomic, readonly) BOOL canPlaceCall;
- (void)callUser:(int64_t)userId;
/// A video call starts with our camera on; the flag also reaches the peer,
/// whose phone then rings as a video call.
- (void)callUser:(int64_t)userId video:(BOOL)video;
- (void)accept;
#if TG_DEV
/// A call against tgcalls_cli --mode bridge with no account: signaling over a local
/// socket instead of TDLib. See scripts/call_bench_device.sh.
- (void)startBenchWithConfig:(NSDictionary *)config;
#endif
- (void)hangUp;
- (void)setMuted:(BOOL)muted;

/// Tears the call down locally and clears the call id, peer and key without
/// sending a discard - used when the account changes, because TDLib is already
/// closed and a discard would name a call that no longer exists.
- (void)reset;

/// Sends a rating (1..5) with optional comment and problem list to TDLib for the call.
- (void)sendRating:(int)rating comment:(NSString *)comment problems:(NSArray *)problems;

/// Fed every updateNewCallSignalingData from TGClient. This is the channel
/// tgcalls negotiates over - encrypted with the call key, JSON inside.
- (void)handleSignalingData:(NSData *)data;

/// Fed every updateCall from TGClient.
- (void)handleUpdate:(NSDictionary *)call;

/// Seconds since the call was established, for the screen to show.
- (NSTimeInterval)duration;

@end
