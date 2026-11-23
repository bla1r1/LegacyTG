//
// TGCallDirectPath - the peer-to-peer half of a 9.0.0 call: our own UDP
// socket, host and server-reflexive candidates, ICE checks straight to the
// peer's host and srflx candidates, and the media on that path once a check
// is answered. The reflector stays up underneath; when the direct path goes
// quiet for 3 s the call is back on it, and checks go on in case the path
// comes back.
//
// Only for calls where TDLib says allow_p2p: the peer learns our addresses.
//
#import <Foundation/Foundation.h>

@interface TGCallDirectPath : NSObject

@property (atomic, copy) NSString *localUfrag;
@property (atomic, copy) NSString *localPwd;
@property (atomic, copy) NSString *peerUfrag;
@property (atomic, copy) NSString *peerPwd;
/// The caller controls and nominates (USE-CANDIDATE), as on the reflector.
@property (atomic, assign) BOOL controlling;

/// Anything that is not STUN from the peer's direct address: DTLS, SRTP.
/// Reader thread; the bytes are valid inside the call only.
@property (nonatomic, copy) void (^onMedia)(const uint8_t *bytes, size_t length);
/// A candidate line learnt after -start (our server-reflexive address).
/// Main queue.
@property (nonatomic, copy) void (^onCandidate)(NSString *candidate);
/// The media moved onto the direct path (YES) or back to the reflector.
/// Main queue.
@property (nonatomic, copy) void (^onPathChanged)(BOOL direct);

@property (atomic, readonly) BOOL active;

/// Started for a callStateReady, or nil when it does not allow P2P (the
/// user's privacy setting, or the peer's). STUN goes through the call's
/// WebRTC servers that support it.
+ (instancetype)pathForCallState:(NSDictionary *)state ufrag:(NSString *)ufrag pwd:(NSString *)pwd
                     controlling:(BOOL)controlling
                           media:(void (^)(const uint8_t *bytes, size_t length))media
                       candidate:(void (^)(NSString *line))candidate;

/// `stunServers`: [ip, port] pairs, from callStateReady's WebRTC servers.
- (BOOL)startWithStunServers:(NSArray *)stunServers;
/// One line per local IPv4 address, in the 9.0.0 candidate format.
- (NSArray *)hostCandidates;
/// A line as the peer sent it; relay and IPv6 lines are skipped.
- (void)addPeerCandidate:(NSString *)line;
/// NO when there is no direct path: the caller sends it on the reflector.
- (BOOL)send:(const uint8_t *)bytes length:(size_t)length;
- (void)stop;

@end
