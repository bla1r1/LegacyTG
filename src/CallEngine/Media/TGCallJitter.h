//
// TGCallJitter - playout buffer for the peer's Opus packets. The network hands
// packets in as they arrive; the audio thread takes them out at the pace it
// plays, one packet at a time, and is told what to do when the next one is
// not there: decode the FEC copy carried by the packet after it, or conceal.
//
// Codec-free on purpose: the caller owns the decoder, so this compiles and
// tests without libopus.
//
#ifndef TG_CALL_JITTER_H
#define TG_CALL_JITTER_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define TGJitterSlots 64
#define TGJitterMaxPacket 1500

typedef enum {
	TGJitterSilence,   // still filling: play `samples` of silence
	TGJitterPlay,      // decode `payload` normally
	TGJitterFec,       // decode `payload` with decode_fec=1 for `samples`
	TGJitterConceal,   // packet lost, no FEC: PLC for `samples`
} TGJitterAction;

typedef struct {
	TGJitterAction action;
	uint8_t payload[TGJitterMaxPacket];
	size_t length;
	int samples;       // 48 kHz samples this step covers
} TGJitterOut;

typedef struct {
	unsigned played, fec, concealed, late, dropped, rebuffers;
} TGJitterStats;

typedef struct TGJitter TGJitter;

TGJitter *TGJitterCreate(void);
void TGJitterFree(TGJitter *jitter);

/// Network thread. `samples` is the packet's duration at 48 kHz (from
/// opus_packet_get_nb_samples), `nowMs` a monotonic clock.
void TGJitterPut(TGJitter *jitter, uint16_t seq, uint32_t timestamp, int samples,
                 const uint8_t *payload, size_t length, int64_t nowMs);

/// Audio thread: the next step of playout.
void TGJitterPull(TGJitter *jitter, TGJitterOut *out);

/// An Opus packet's duration at 48 kHz from its TOC byte (RFC 6716 3.1),
/// for RTP timestamps where libopus is not linked. 0 if malformed.
int TGOpusPacketSamples(const uint8_t *packet, size_t length);

/// OPUS_SET_PACKET_LOSS_PERC for a reported loss fraction (of 256): the loss
/// with a 2-point floor, so a clean spell keeps a little FEC for the next
/// burst, and a 25 ceiling, past which the copy eats the voice's own bits.
int TGOpusLossPercent(uint8_t fraction);

/// Current playout delay target in ms.
int TGJitterTargetMs(TGJitter *jitter);
TGJitterStats TGJitterGetStats(TGJitter *jitter);

#ifdef __cplusplus
}
#endif

#endif
