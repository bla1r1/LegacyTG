//
// TGCallVP8Rtp - VP8 over RTP (RFC 7741) for calls on devices without
// VideoToolbox: one encoded frame cut into payloads, payloads joined back into
// a frame.
//
// The descriptor we write is what WebRTC writes: X set, a 15-bit picture id,
// S on the first packet. Reading takes any descriptor the RFC allows.
//
#ifndef TG_CALL_VP8_RTP_H
#define TG_CALL_VP8_RTP_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define TGVP8DescriptorLength 4

/// Payloads for one frame. Writes at most `maxPackets` payloads of at most
/// `maxPayload` bytes each into `out` (maxPackets * maxPayload bytes), their
/// lengths into `lengths`. Returns the count, 0 when the frame does not fit.
/// The frame is cut into near-equal parts so no packet is a sliver.
int TGVP8Packetize(const uint8_t *frame, size_t length, uint16_t pictureId,
                   uint8_t *out, size_t maxPayload, size_t *lengths, int maxPackets);

typedef struct {
	uint8_t *frame;        // storage, owned by the caller
	size_t   capacity;
	size_t   length;
	uint32_t timestamp;
	int      inFrame;
	int      waitingForKeyframe;
} TGVP8Depacketizer;

void TGVP8DepacketizerInit(TGVP8Depacketizer *d, uint8_t *storage, size_t capacity);

/// Throw away the frame in progress and everything up to the next keyframe.
void TGVP8DepacketizerDrop(TGVP8Depacketizer *d);

/// One RTP packet (header included). Returns 1 when it completed a frame:
/// d->frame holds d->length bytes, *keyframe says whether it is one.
int TGVP8DepacketizerPush(TGVP8Depacketizer *d, const uint8_t *rtp, size_t length, int *keyframe);

/// Length of the payload descriptor at the start of `payload`, 0 if malformed.
size_t TGVP8DescriptorSize(const uint8_t *payload, size_t length);

#ifdef __cplusplus
}
#endif

#endif
