//
// TGCallExpand - what plays while a packet is missing. Opus's own concealment
// fades to silence within 20-40 ms; the peer sends 60 ms packets and FEC
// rebuilds only their last 20 ms, so every lost packet was a hole. This
// repeats the last pitch period of what was played, at full level for 20 ms
// and then falling 3 dB every 20 ms, and blends back into real audio over
// 20 ms when it returns: NetEq's expand, without its noise model.
//
#ifndef TG_CALL_EXPAND_H
#define TG_CALL_EXPAND_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define TGExpandHistory 1920   // 40 ms at 48 kHz

typedef struct {
	int16_t history[TGExpandHistory];
	int filled;
	int expanding;
	int period;
	int position;
	float gain;
	int held;
} TGExpand;

void TGExpandInit(TGExpand *expand);

/// Real decoded audio about to be played. After an expand its first 20 ms
/// are blended from the expanded signal: no click at the join, and no dip
/// where Opus fades its first frame after a loss back in.
void TGExpandGood(TGExpand *expand, int16_t *pcm, int count);

/// `count` samples to stand in for audio that is not there.
void TGExpandFill(TGExpand *expand, int16_t *out, int count);

#ifdef __cplusplus
}
#endif

#endif
