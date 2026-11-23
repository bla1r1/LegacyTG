//
// TGCallV2Session - one tgcalls 9.0.0 call: V2 signalling, DTLS, SRTP for the
// audio and video streams, RTCP, and the SCTP data channel that carries
// MediaState. TGCall owns one of these only when callStateReady names 9.0.0;
// the 5.0.0 path is untouched.
//
#ifndef TG_CALL_V2_SESSION_H
#define TG_CALL_V2_SESSION_H

#import <Foundation/Foundation.h>

@interface TGCallV2Session : NSObject

/// Caller = YES. Chooses the DTLS client role, the ICE role and actpass.
@property (nonatomic, assign) BOOL outgoing;

/// Must be the same ufrag the candidate line names.
@property (nonatomic, copy) NSString *localUfrag;
@property (nonatomic, copy) NSString *localPwd;
@property (nonatomic, assign) uint32_t localSsrc;

/// Our offer carries an H.264 channel and our answers take the peer's.
/// Set before -start; NO on devices that cannot encode and decode a call.
@property (nonatomic, assign) BOOL videoCapable;
@property (nonatomic, assign) uint32_t localVideoSsrc;
/// VideoToolbox is there (iOS 8+): H.264 is offered first and taken first.
/// Without it the call's video is VP8 both ways.
@property (nonatomic, assign) BOOL h264Capable;

/// Main queue: which codec each direction settled on, YES for VP8.
@property (nonatomic, copy) void (^onVideoCodecs)(BOOL sendVP8, BOOL receiveVP8);

/// Encrypts and sends one signalling plaintext with this packet sequence.
@property (nonatomic, copy) void (^sendSignaling)(NSData *plaintext, uint32_t seq);
/// Sends one DTLS record or SRTP datagram to the peer's reflector tag.
@property (nonatomic, copy) void (^sendMedia)(const uint8_t *bytes, size_t length);
/// Candidate strings from the peer, for the ICE layer.
@property (nonatomic, copy) void (^onRemoteCandidates)(NSArray *candidates);
/// ICE credentials from InitialSetup. Candidates in 9.0.0 do not carry them.
@property (nonatomic, copy) void (^onPeerCredentials)(NSString *ufrag, NSString *pwd);
@property (nonatomic, copy) void (^onEstablished)(void);
@property (nonatomic, copy) void (^onAudio)(const uint8_t *rtp, size_t length);
@property (nonatomic, copy) void (^onFailure)(NSString *reason);

/// Decrypted RTP of the peer's video stream. Reader thread.
@property (nonatomic, copy) void (^onVideo)(const uint8_t *rtp, size_t length);
/// The peer's stream skipped packets: drop the broken picture. Reader thread.
@property (nonatomic, copy) void (^onVideoLoss)(void);
/// The peer's report on our video: the share lost since the last one, of
/// 256. About once a second. Reader thread.
@property (nonatomic, copy) void (^onSendLoss)(uint8_t fraction);
/// The same for our audio. Reader thread.
@property (nonatomic, copy) void (^onAudioSendLoss)(uint8_t fraction);
/// The peer asked for a keyframe of our stream. Reader thread.
@property (nonatomic, copy) void (^onKeyframeRequest)(void);
/// Main queue, whenever the peer's MediaState arrives.
@property (nonatomic, copy) void (^onPeerMediaState)(BOOL muted, BOOL videoActive);

/// The most the peer's video may use, sent as REMB with every report; 0
/// sends none. Any thread.
@property (atomic, assign) int remoteVideoCapKbps;

/// NO until the peer has answered our video channel.
@property (nonatomic, readonly) BOOL canSendVideo;

- (void)start;
/// The reflector path is usable. DTLS starts here, not before: a ClientHello
/// sent into an unwritable path only buys a retransmission timer.
- (void)iceConnected;
- (void)handlePlaintext:(NSData *)plaintext packetSeq:(uint32_t)seq;
- (void)handlePacket:(const uint8_t *)bytes length:(size_t)length;
- (void)sendCandidates:(NSArray *)candidates;
- (void)sendOpusFrame:(NSData *)frame;
/// One RTP packet from the packetizer; ssrc and payload type are set here.
/// Encoder thread.
- (void)sendVideoRtp:(NSData *)rtp;
/// PLI for the peer's stream, at most twice a second.
- (void)requestKeyframe;
/// Sent now if the data channel is open, and again whenever it opens.
- (void)setMediaStateMuted:(BOOL)muted videoActive:(BOOL)videoActive;
- (void)tick;
- (void)stop;

@end

#endif
