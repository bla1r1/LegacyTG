#include "TGCallExpand.h"

#include <string.h>

#define kMinPeriod 120     // 2.5 ms: 400 Hz voice is the highest pitch looked for
#define kMaxPeriod 720     // 15 ms: 67 Hz
#define kWindow 960        // 20 ms compared against the one a period earlier
// The first packet after a loss comes out of Opus faded in; blending from
// the expand over its whole 20 ms covers that. 2.5 ms left 102 ms of
// dropouts per 20 s on the stand at 8% loss, 20 ms left 42.
#define kBlend 960
#define kHold 960          // full level for the first 20 ms
// 3 dB per 20 ms: about -30 dB after 200 ms.
#define kDecay 0.99964f

void TGExpandInit(TGExpand *e) {
	memset(e, 0, sizeof(*e));
}

/// The lag at which the last 20 ms best matches what came before, searched
/// every second sample: ~150 k multiply-adds, once per loss.
static int TGExpandPeriod(const TGExpand *e) {
	const int16_t *h = e->history + TGExpandHistory - kWindow;
	long long best = 0;
	int period = kWindow;
	for (int lag = kMinPeriod; lag <= kMaxPeriod; lag += 2){
		long long sum = 0;
		for (int i = 0; i < kWindow; i += 2)
			sum += (long long)h[i] * h[i - lag];
		if (sum > best){
			best = sum;
			period = lag;
		}
	}
	// No pitch (noise, silence): repeat the whole window, which at least
	// keeps the level and colour.
	return best > 0 ? period : kWindow;
}

static void TGExpandRemember(TGExpand *e, const int16_t *pcm, int count) {
	if (count >= TGExpandHistory){
		memcpy(e->history, pcm + count - TGExpandHistory, sizeof(e->history));
	} else {
		memmove(e->history, e->history + count, sizeof(int16_t) * (size_t)(TGExpandHistory - count));
		memcpy(e->history + TGExpandHistory - count, pcm, sizeof(int16_t) * (size_t)count);
	}
	e->filled = e->filled + count > TGExpandHistory ? TGExpandHistory : e->filled + count;
}

static void TGExpandGenerate(TGExpand *e, int16_t *out, int count, int advance) {
	int position = e->position, held = e->held;
	float gain = e->gain;
	const int16_t *cycle = e->history + TGExpandHistory - e->period;
	for (int i = 0; i < count; i++){
		out[i] = (int16_t)(cycle[position] * gain);
		if (++position == e->period)
			position = 0;
		if (held < kHold)
			held++;
		else
			gain *= kDecay;
	}
	if (advance){
		e->position = position;
		e->held = held;
		e->gain = gain;
	}
}

void TGExpandFill(TGExpand *e, int16_t *out, int count) {
	if (e->filled < TGExpandHistory){
		memset(out, 0, sizeof(int16_t) * (size_t)count);
		return;
	}
	if (!e->expanding){
		e->expanding = 1;
		e->period = TGExpandPeriod(e);
		e->position = 0;
		e->gain = 1.0f;
		e->held = 0;
	}
	TGExpandGenerate(e, out, count, 1);
}

void TGExpandGood(TGExpand *e, int16_t *pcm, int count) {
	if (e->expanding){
		int16_t next[kBlend];
		int n = count < kBlend ? count : kBlend;
		TGExpandGenerate(e, next, n, 0);
		for (int i = 0; i < n; i++){
			float w = (float)(i + 1) / (float)(n + 1);
			pcm[i] = (int16_t)(next[i] * (1.0f - w) + pcm[i] * w);
		}
		e->expanding = 0;
	}
	TGExpandRemember(e, pcm, count);
}
