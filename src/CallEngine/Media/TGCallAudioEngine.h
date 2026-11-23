//
// TGCallAudioEngine - Opus audio playback and microphone capture using AudioQueue.
//
#ifndef TG_CALL_AUDIO_ENGINE_H
#define TG_CALL_AUDIO_ENGINE_H

#import <Foundation/Foundation.h>

@interface TGCallAudioEngine : NSObject

/// Mixes SOS in Morse into the outgoing stream. The phone under test sits in an
/// empty room, so silence on the far end proves nothing; this makes a working
/// path audible without anyone having to speak into it.
@property (nonatomic, assign) BOOL emitMorseSignal;

/// Feeds every encoded frame straight back into the decoder. Proves capture,
/// encoding, decoding and playback in one go, without the network.
@property (nonatomic, assign) BOOL loopbackToSpeaker;

@property (nonatomic, copy) void (^onOutgoingOpusFrame)(NSData *opusFrame);

/// The peer's loss report on our audio (of 256). The share of each packet
/// spent on the FEC copy of the one before follows it; any thread, applied
/// on the next packet. Without reports (5.0.0) it stays at 10%.
- (void)peerReportedLoss:(uint8_t)fraction;

- (BOOL)start;
- (void)stop;
/// Starts the unit again after an interruption stopped it.
- (void)resume;

/// Pass an incoming Opus audio frame to be decoded and played through the speaker/earpiece.
- (void)handleIncomingOpusFrame:(NSData *)opusFrame;

/// The same, straight off the decrypted packet buffer, with the RTP sequence
/// and timestamp the playout buffer orders and paces it by. Copied into the
/// buffer; decoded on the audio thread when its turn comes.
- (void)handleIncomingOpusBytes:(const uint8_t *)bytes length:(size_t)length
					   sequence:(uint16_t)sequence timestamp:(uint32_t)timestamp;

@end

#endif
