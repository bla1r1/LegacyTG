//
// TGCall+Internal.h - what TGCall's own files share and nothing else may use:
// the class's private state, and the methods one part calls in another.
// TGCall.mm is the call; TGCall+Candidates.mm builds and reads ICE candidates.
//
#import "TGCall.h"

@class TGCallIce, TGCallReflector, TGCallV2Session, TGCallVideoIntake, TGCallDirectPath,
       TGCallAudioRoute, TGCallAudioEngine, TGCallVideoEngine;

@interface TGCall ()
@property (nonatomic, assign) TGCallState state;
@property (nonatomic, copy) NSString *pendingStatus;
@property (nonatomic, assign) BOOL needsRating;
@property (nonatomic, assign) int32_t callId;
@property (nonatomic, assign) int32_t lastCallId;
@property (nonatomic, assign) int64_t peerUserId;
@property (nonatomic, assign) BOOL outgoing;
@property (nonatomic, assign) BOOL muted;
@property (nonatomic, assign) BOOL videoActive;
@property (nonatomic, assign) BOOL peerVideoActive;
@property (nonatomic, assign) BOOL peerCameraOn;
@property (nonatomic, assign) BOOL isVideoCall;
@property (nonatomic, strong) TGCallVideoEngine *videoEngine;
@property (nonatomic, strong) NSDate *establishedAt;
@property (nonatomic, strong) NSString *endReason;
@property (nonatomic, strong) TGCallReflector *reflector;      // the chosen one
@property (nonatomic, strong) NSMutableArray *reflectors;      // all of them
@property (nonatomic, strong) NSData *callKey;
@property (nonatomic, strong) NSString *localUfrag;
@property (nonatomic, strong) NSString *localPwd;
@property (nonatomic, strong) NSString *reflectorHost;
@property (nonatomic, assign) uint16_t reflectorPort;
@property (nonatomic, assign) int64_t reflectorId;
@property (nonatomic, assign) uint32_t signallingSeq;
@property (nonatomic, assign) BOOL sentCandidates;
@property (nonatomic, assign) BOOL sentVideoFormatsAnswer;
@property (nonatomic, assign) BOOL loggedHeader;
@property (nonatomic, assign) BOOL sentMediaState;
@property (nonatomic, strong) TGCallVideoIntake *videoIntake;
@property (nonatomic, strong) TGCallDirectPath *direct;
@property (nonatomic, assign) uint32_t videoParametersSeq;
@property (nonatomic, assign) uint32_t mediaStateSeq;
@property (nonatomic, strong) NSTimer *mediaStateTimer;
@property (nonatomic, assign) uint32_t audioProbeSeq;
@property (nonatomic, assign) BOOL audioFramingProven;
@property (nonatomic, assign) uint32_t currentSenderTag;
@property (nonatomic, assign) uint32_t nominatedSenderTag;
@property (nonatomic, assign) uint32_t verifiedMediaTag;
@property (nonatomic, strong) TGCallReflector *currentReflector;
@property (nonatomic, strong) TGCallReflector *verifiedReflector;
@property (nonatomic, strong) NSString *peerUfrag;
@property (nonatomic, strong) NSString *peerPwd;
@property (nonatomic, strong) TGCallIce *ice;
@property (nonatomic, strong) TGCallAudioEngine *audioEngine;
@property (nonatomic, strong) TGCallAudioRoute *audioRoute;
@property (nonatomic, strong) TGCallV2Session *v2;
@property (nonatomic, assign) BOOL isV2;
@property (nonatomic, assign) uint32_t mediaSeqOut;
@property (nonatomic, assign) uint16_t rtpSeqOut;
@property (nonatomic, assign) uint32_t rtpTimestampOut;
@property (nonatomic, assign) uint16_t transportSeqOut;
@property (nonatomic, strong) NSArray *emojis;
@property (nonatomic, strong) NSMutableArray *pendingSignalingData;
- (NSString *)randomIceStringOfLength:(NSInteger)length;
- (void)startAudioEngine;
- (void)sendSignalling:(NSData *)plaintext seq:(uint32_t)seq;
/// Our reflector (and, with P2P, direct) candidates, once, to the peer.
- (void)sendOurCandidates;
/// The peer's reflector tag, from a relay candidate's hostname.
- (void)readPeerTagFromCandidate:(NSString *)candidate;
@end
