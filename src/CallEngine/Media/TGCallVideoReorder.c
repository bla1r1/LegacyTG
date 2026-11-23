#include "TGCallVideoReorder.h"

#include <string.h>

static void TGVideoReorderDrain(TGVideoReorder *r, TGVideoReorderDeliver deliver, void *context) {
	for (;;){
		unsigned slot = r->expected % TGVideoReorderSlots;
		if (!r->held[slot] || r->seqs[slot] != r->expected)
			break;
		r->held[slot] = 0;
		deliver(context, r->data[slot], r->lengths[slot]);
		r->expected++;
	}
}

static int TGVideoReorderHolding(const TGVideoReorder *r) {
	for (unsigned i = 0; i < TGVideoReorderSlots; i++)
		if (r->held[i])
			return 1;
	return 0;
}

/// Hands on everything held, oldest first, stepping over the holes. A null
/// packet goes first: what follows a hole is a broken picture, and the
/// receiver has to know that before it sees any of it.
static void TGVideoReorderFlush(TGVideoReorder *r, TGVideoReorderDeliver deliver, void *context) {
	deliver(context, NULL, 0);
	uint16_t last = (uint16_t)(r->expected - 1);
	for (unsigned step = 0; step < TGVideoReorderSlots; step++){
		uint16_t seq = (uint16_t)(r->expected + step);
		unsigned slot = seq % TGVideoReorderSlots;
		if (r->held[slot] && r->seqs[slot] == seq){
			r->held[slot] = 0;
			deliver(context, r->data[slot], r->lengths[slot]);
			last = seq;
		}
	}
	memset(r->held, 0, sizeof(r->held));
	r->expected = (uint16_t)(last + 1);
	r->gapSince = 0;
}

TGVideoReorderResult TGVideoReorderPush(TGVideoReorder *r,
                                        const uint8_t *rtp, size_t length,
                                        double now, double patience,
                                        TGVideoReorderDeliver deliver, void *context,
                                        uint16_t *nackFrom, uint16_t *nackCount) {
	if (!rtp || length < 12 || length > TGVideoReorderSlotSize)
		return TGVideoReorderNothing;
	uint16_t seq = (uint16_t)((rtp[2] << 8) | rtp[3]);
	if (!r->started){
		r->started = 1;
		r->expected = seq;
		r->highest = (uint16_t)(seq - 1);
	}

	int16_t ahead = (int16_t)(seq - r->expected);
	if (ahead < 0)
		return TGVideoReorderNothing;       // a repeat, or too late to matter
	if (ahead == 0){
		deliver(context, rtp, length);
		r->expected++;
		if ((int16_t)(seq - r->highest) > 0)
			r->highest = seq;
		TGVideoReorderDrain(r, deliver, context);
		// The hole the clock ran for is filled; whatever is still held waits
		// behind a newer one, which gets its own full wait.
		r->gapSince = TGVideoReorderHolding(r) ? now : 0;
		return TGVideoReorderNothing;
	}

	if (ahead >= TGVideoReorderSlots){
		// Further ahead than can be held: the hole is too big to fill.
		TGVideoReorderFlush(r, deliver, context);
		r->expected = (uint16_t)(seq + 1);
		r->highest = seq;
		deliver(context, rtp, length);
		return TGVideoReorderGaveUp;
	}

	TGVideoReorderResult result = TGVideoReorderNothing;
	int16_t past = (int16_t)(seq - r->highest);
	if (past > 1){
		*nackFrom = (uint16_t)(r->highest + 1);
		*nackCount = (uint16_t)(past - 1);
		result = TGVideoReorderAskAgain;
	}
	if (past > 0)
		r->highest = seq;

	unsigned slot = seq % TGVideoReorderSlots;
	memcpy(r->data[slot], rtp, length);
	r->lengths[slot] = (uint16_t)length;
	r->seqs[slot] = seq;
	r->held[slot] = 1;
	if (r->gapSince == 0)
		r->gapSince = now;
	else if (now - r->gapSince > patience){
		TGVideoReorderFlush(r, deliver, context);
		return TGVideoReorderGaveUp;
	}
	return result;
}

int TGVideoReorderMissing(const TGVideoReorder *r, uint16_t *from, uint16_t *count) {
	if (!r->started || !TGVideoReorderHolding(r))
		return 0;
	uint16_t n = 0;
	while (n < TGVideoReorderSlots){
		uint16_t seq = (uint16_t)(r->expected + n);
		unsigned slot = seq % TGVideoReorderSlots;
		if (r->held[slot] && r->seqs[slot] == seq)
			break;
		n++;
	}
	if (!n || n == TGVideoReorderSlots)
		return 0;
	*from = r->expected;
	*count = n;
	return 1;
}
