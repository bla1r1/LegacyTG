//
// TGCallVideoReorder - holds the peer's video packets behind a gap long enough
// for a NACKed packet to come back, then hands them on in order.
//
// Without it every lost packet cost the picture until the next keyframe: the
// depacketizer can only drop what follows a hole. With it a hole asks for the
// missing packets once and waits `patience` seconds; only if they do not come
// does the picture break and a PLI go out.
//
#ifndef TG_CALL_VIDEO_REORDER_H
#define TG_CALL_VIDEO_REORDER_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define TGVideoReorderSlots    64
#define TGVideoReorderSlotSize 1200

/// A null `rtp` means packets were given up on: drop the picture in progress.
typedef void (*TGVideoReorderDeliver)(void *context, const uint8_t *rtp, size_t length);

typedef enum {
	TGVideoReorderNothing = 0,
	TGVideoReorderAskAgain,    ///< new packets are missing: NACK *from, *count
	TGVideoReorderGaveUp,      ///< the hole stayed: the picture is broken
} TGVideoReorderResult;

typedef struct {
	int      started;
	uint16_t expected;     // next sequence number to hand on
	uint16_t highest;      // highest sequence number seen
	double   gapSince;     // 0 while nothing is held
	uint8_t  held[TGVideoReorderSlots];
	uint16_t seqs[TGVideoReorderSlots];
	uint16_t lengths[TGVideoReorderSlots];
	uint8_t  data[TGVideoReorderSlots][TGVideoReorderSlotSize];
} TGVideoReorder;

/// One decrypted RTP packet. Delivers whatever is now in order.
TGVideoReorderResult TGVideoReorderPush(TGVideoReorder *reorder,
                                        const uint8_t *rtp, size_t length,
                                        double now, double patience,
                                        TGVideoReorderDeliver deliver, void *context,
                                        uint16_t *nackFrom, uint16_t *nackCount);

/// The run of missing packets the playout is stuck behind, for asking again
/// when the first NACK or its resend was lost too. 0 when nothing is held.
int TGVideoReorderMissing(const TGVideoReorder *reorder, uint16_t *from, uint16_t *count);

#ifdef __cplusplus
}
#endif

#endif
