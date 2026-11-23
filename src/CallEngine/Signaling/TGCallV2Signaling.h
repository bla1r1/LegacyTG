//
// TGCallV2Signaling - the tgcalls 9.0.0 (SignalingProtocolVersion::V2)
// signalling envelope and JSON messages.
//
// A decrypted packet is [seq][element] repeated. One element is either a raw
// message (0x7F, 4-byte length, JSON), an empty message (0xFE) or an ack
// (0xFF, whose preceding seq is the one being acknowledged).
//
#ifndef TG_CALL_V2_SIGNALING_H
#define TG_CALL_V2_SIGNALING_H

#import <Foundation/Foundation.h>

/// The payload type our own video offer names for H.264.
#define TGV2VideoPayloadType 102
/// ...and for VP8, offered after H.264, or alone where there is no VideoToolbox.
#define TGV2VP8PayloadType 100

typedef struct {
	uint8_t type;
	uint32_t seq;
	const uint8_t *body;
	size_t bodyLength;
} TGV2Slice;

#ifdef __cplusplus
extern "C" {
#endif
/// Parses every element, not just the first. Returns the number written.
size_t TGV2ParsePlaintext(const uint8_t *bytes, size_t length,
                          uint32_t packetSeq, TGV2Slice *out, size_t maxSlices);
#ifdef __cplusplus
}
#endif

@interface TGCallV2Signaling : NSObject

/// 0x7F + length + compact JSON.
+ (NSData *)messageWithJSONObject:(NSDictionary *)json;

/// An ack-only packet body: [0xFE][acked seq][0xFF]. The caller gives the
/// packet its own bare sequence number.
+ (NSData *)ackForSeq:(uint32_t)seq;

+ (NSData *)initialSetupWithUfrag:(NSString *)ufrag
                              pwd:(NSString *)pwd
                      fingerprint:(NSString *)fingerprint
                            setup:(NSString *)setup;

/// Our own send-only audio offer.
+ (NSData *)offerWithExchangeId:(NSString *)exchangeId ssrc:(uint32_t)ssrc;

/// The answer to their offer. It must echo their ssrc and exchangeId, or the
/// peer builds no outgoing audio channel and stays silent.
+ (NSData *)answerWithExchangeId:(NSString *)exchangeId ssrc:(uint32_t)ssrc;

+ (NSData *)candidatesWithStrings:(NSArray *)candidates;

+ (NSDictionary *)audioContentWithSsrc:(uint32_t)ssrc;
/// Our send-only video channel: H.264 constrained baseline (packetization
/// mode 1) then VP8, or VP8 alone when `h264` is NO.
+ (NSDictionary *)videoContentWithSsrc:(uint32_t)ssrc h264:(BOOL)h264;
+ (NSDictionary *)videoContentWithSsrc:(uint32_t)ssrc;
+ (NSData *)negotiateWithExchangeId:(NSString *)exchangeId contents:(NSArray *)contents;

/// The H.264 entry this client can decode from an offered video content, or nil.
+ (NSDictionary *)h264PayloadIn:(NSDictionary *)content;

/// Our receive-side half for one content of the peer's offer: same ssrc and
/// groups, the codec we take. Nil when we take nothing from it, and the peer
/// then builds no channel for it.
+ (NSDictionary *)answerContentFor:(NSDictionary *)offered acceptVideo:(BOOL)acceptVideo
                        preferH264:(BOOL)preferH264;
+ (NSDictionary *)answerContentFor:(NSDictionary *)offered acceptVideo:(BOOL)acceptVideo;
+ (NSDictionary *)vp8PayloadIn:(NSDictionary *)content;

/// What tgcalls reads off the data channel: mute and camera state.
+ (NSString *)mediaStateWithMuted:(BOOL)muted videoActive:(BOOL)videoActive;

@end

#endif
