#include "TGCallPlayout.h"

#include <string.h>

int TGPlayoutStep(TGJitter *jitter, OpusDecoder *decoder, TGExpand *expand,
                  int16_t *out, TGJitterAction *action) {
	static TGJitterOut step;   // one audio thread; 1.5 KB off its stack
	TGJitterPull(jitter, &step);
	int samples = step.samples > 0 && step.samples <= 5760 ? step.samples : 960;
	int n = 0;
	switch (step.action){
	case TGJitterPlay:
		n = opus_decode(decoder, step.payload, (opus_int32)step.length, out, 5760, 0);
		if (n > 0){
			TGExpandGood(expand, out, n);
			break;
		}
		TGExpandFill(expand, out, samples);
		n = samples;
		break;
	case TGJitterFec: {
		// Opus rebuilds only the next packet's first frame worth (20 ms of a
		// 60 ms loss) and conceals the rest; the rest is ours to fill.
		n = opus_decode(decoder, step.payload, (opus_int32)step.length, out, samples, 1);
		if (n <= 0){
			TGExpandFill(expand, out, samples);
			n = samples;
			break;
		}
		int real = opus_packet_get_samples_per_frame(step.payload, 48000);
		if (real <= 0 || real > n)
			real = n;
		TGExpandFill(expand, out, n - real);
		TGExpandGood(expand, out + n - real, real);
		break;
	}
	case TGJitterConceal:
		// Run Opus's concealment anyway: it keeps the decoder's state in step
		// for the packet that comes next. What plays is the expand.
		opus_decode(decoder, NULL, 0, out, samples, 0);
		TGExpandFill(expand, out, samples);
		n = samples;
		break;
	case TGJitterSilence:
		memset(out, 0, sizeof(int16_t) * (size_t)samples);
		TGExpandGood(expand, out, samples);
		n = samples;
		break;
	}
	if (action)
		*action = step.action;
	return n;
}
