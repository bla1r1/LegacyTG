#include "TGCallJitter.h"

#include <pthread.h>
#include <stdlib.h>
#include <string.h>

// ~4 s of 60 ms packets: long enough for a 95th percentile, short enough to
// forget a bad spell within a few seconds.
#define kDelayWindow 64
// What arrives in the first second is what queued up while the call was
// connecting, all at once; counted as jitter it held the target at its
// 400 ms ceiling for the first ~20 s of a call.
#define kWarmupMs 1000
#define kMinTargetMs 40
#define kMaxTargetMs 400
// Above target by this much, a packet is skipped to bring the delay back.
#define kTrimMs 80
// A gap this long with nothing behind it is the peer gone quiet (or a
// network outage), not jitter: stop concealing and fill up again.
#define kGiveUpMs 200

typedef struct {
	int used;
	uint16_t seq;
	uint32_t timestamp;
	int samples;
	size_t length;
	uint8_t data[TGJitterMaxPacket];
} TGJitterSlot;

struct TGJitter {
	pthread_mutex_t lock;
	TGJitterSlot slot[TGJitterSlots];
	int started;
	uint16_t next;
	int lastSamples;
	int missingSamples;
	int haveFirst;
	uint32_t firstTimestamp;
	int64_t firstArrivalMs;
	int64_t delays[kDelayWindow];
	int delayCount, delayAt, sinceEstimate;
	int targetMs;
	TGJitterStats stats;
};

static int TGSeqBefore(uint16_t a, uint16_t b) {
	return (int16_t)(a - b) < 0;
}

static int TGCompareDelay(const void *a, const void *b) {
	int64_t x = *(const int64_t *)a, y = *(const int64_t *)b;
	return x < y ? -1 : x > y;
}

TGJitter *TGJitterCreate(void) {
	TGJitter *j = calloc(1, sizeof(*j));
	if (!j)
		return NULL;
	pthread_mutex_init(&j->lock, NULL);
	j->lastSamples = 960;
	j->targetMs = 60;
	return j;
}

void TGJitterFree(TGJitter *j) {
	if (!j)
		return;
	pthread_mutex_destroy(&j->lock);
	free(j);
}

/// The target is how far the slowest packets lag the fastest over the last
/// 128: the 95th percentile of transit time minus the minimum, plus one
/// 20 ms frame of margin.
static void TGJitterEstimate(TGJitter *j) {
	int64_t sorted[kDelayWindow];
	int n = j->delayCount;
	memcpy(sorted, j->delays, sizeof(int64_t) * (size_t)n);
	qsort(sorted, (size_t)n, sizeof(int64_t), TGCompareDelay);
	int target = (int)(sorted[(n * 95) / 100] - sorted[0]) + 20;
	j->targetMs = target < kMinTargetMs ? kMinTargetMs : target > kMaxTargetMs ? kMaxTargetMs : target;
}

void TGJitterPut(TGJitter *j, uint16_t seq, uint32_t timestamp, int samples,
                 const uint8_t *payload, size_t length, int64_t nowMs) {
	if (!j || !payload || !length || length > TGJitterMaxPacket || samples <= 0)
		return;
	pthread_mutex_lock(&j->lock);
	if (j->started && TGSeqBefore(seq, j->next)){
		j->stats.late++;
		pthread_mutex_unlock(&j->lock);
		return;
	}
	TGJitterSlot *s = &j->slot[seq % TGJitterSlots];
	s->used = 1;
	s->seq = seq;
	s->timestamp = timestamp;
	s->samples = samples;
	s->length = length;
	memcpy(s->data, payload, length);

	if (!j->haveFirst){
		j->haveFirst = 1;
		j->firstTimestamp = timestamp;
		j->firstArrivalMs = nowMs;
	}
	if (nowMs - j->firstArrivalMs < kWarmupMs){
		pthread_mutex_unlock(&j->lock);
		return;
	}
	// Transit time up to a constant: arrival minus the time it was sent.
	j->delays[j->delayAt] = nowMs - (int32_t)(timestamp - j->firstTimestamp) / 48;
	j->delayAt = (j->delayAt + 1) % kDelayWindow;
	if (j->delayCount < kDelayWindow)
		j->delayCount++;
	if (++j->sinceEstimate >= 8 && j->delayCount >= 8){
		j->sinceEstimate = 0;
		TGJitterEstimate(j);
	}
	pthread_mutex_unlock(&j->lock);
}

static int TGJitterBuffered(TGJitter *j, int *lowest) {
	int samples = 0, found = 0;
	uint16_t low = 0;
	for (int i = 0; i < TGJitterSlots; i++){
		TGJitterSlot *s = &j->slot[i];
		if (!s->used)
			continue;
		if (j->started && TGSeqBefore(s->seq, j->next)){
			s->used = 0;          // played past it while it was in flight
			continue;
		}
		samples += s->samples;
		if (!found || TGSeqBefore(s->seq, low))
			low = s->seq;
		found = 1;
	}
	if (lowest)
		*lowest = found ? low : -1;
	return samples;
}

static TGJitterSlot *TGJitterAt(TGJitter *j, uint16_t seq) {
	TGJitterSlot *s = &j->slot[seq % TGJitterSlots];
	return s->used && s->seq == seq ? s : NULL;
}

static void TGJitterEmit(TGJitterOut *out, TGJitterAction action, TGJitterSlot *s, int samples) {
	out->action = action;
	out->samples = samples;
	out->length = 0;
	if (s){
		memcpy(out->payload, s->data, s->length);
		out->length = s->length;
	}
}

void TGJitterPull(TGJitter *j, TGJitterOut *out) {
	pthread_mutex_lock(&j->lock);
	int lowest;
	int buffered = TGJitterBuffered(j, &lowest);
	if (!j->started){
		if (lowest < 0 || buffered < j->targetMs * 48){
			TGJitterEmit(out, TGJitterSilence, NULL, 960);
			pthread_mutex_unlock(&j->lock);
			return;
		}
		j->started = 1;
		j->next = (uint16_t)lowest;
		j->missingSamples = 0;
	}

	TGJitterSlot *s = TGJitterAt(j, j->next);
	// Too far behind the live edge: skip one packet rather than keep the
	// whole call that much later. Happens when the peer's clock runs fast or
	// after concealment stretched the playout.
	if (s && buffered - s->samples > (j->targetMs + kTrimMs) * 48 && TGJitterAt(j, (uint16_t)(j->next + 1))){
		s->used = 0;
		j->next++;
		j->stats.dropped++;
		s = TGJitterAt(j, j->next);
	}
	if (s){
		TGJitterEmit(out, TGJitterPlay, s, s->samples);
		j->lastSamples = s->samples;
		s->used = 0;
		j->next++;
		j->missingSamples = 0;
		j->stats.played++;
	} else if (lowest >= 0){
		// Lost: packets behind it are already here. Opus carries a
		// low-rate copy of each frame in the one after it.
		TGJitterSlot *after = TGJitterAt(j, (uint16_t)(j->next + 1));
		if (after){
			TGJitterEmit(out, TGJitterFec, after, j->lastSamples);
			j->stats.fec++;
		} else {
			TGJitterEmit(out, TGJitterConceal, NULL, j->lastSamples);
			j->stats.concealed++;
		}
		j->next++;
	} else if ((j->missingSamples += j->lastSamples) <= kGiveUpMs * 48){
		// Nothing behind it: most likely late, not lost. Conceal without
		// moving on, so it still plays when it comes.
		TGJitterEmit(out, TGJitterConceal, NULL, j->lastSamples);
		j->stats.concealed++;
	} else {
		j->started = 0;
		j->stats.rebuffers++;
		TGJitterEmit(out, TGJitterSilence, NULL, 960);
	}
	pthread_mutex_unlock(&j->lock);
}

int TGJitterTargetMs(TGJitter *j) {
	pthread_mutex_lock(&j->lock);
	int target = j->targetMs;
	pthread_mutex_unlock(&j->lock);
	return target;
}

TGJitterStats TGJitterGetStats(TGJitter *j) {
	pthread_mutex_lock(&j->lock);
	TGJitterStats stats = j->stats;
	pthread_mutex_unlock(&j->lock);
	return stats;
}

int TGOpusPacketSamples(const uint8_t *p, size_t length) {
	if (!p || !length)
		return 0;
	int config = p[0] >> 3, frame;
	if (config < 12)
		frame = (int[]){480, 960, 1920, 2880}[config & 3];
	else if (config < 16)
		frame = (config & 1) ? 960 : 480;
	else
		frame = 120 << (config & 3);
	int code = p[0] & 3, frames = code == 0 ? 1 : code < 3 ? 2 : 0;
	if (code == 3){
		if (length < 2)
			return 0;
		frames = p[1] & 0x3F;
	}
	return frames * frame;
}

int TGOpusLossPercent(uint8_t fraction) {
	int percent = (fraction * 100 + 255) / 256;
	return percent < 2 ? 2 : percent > 25 ? 25 : percent;
}
