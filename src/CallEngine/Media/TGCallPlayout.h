//
// TGCallPlayout - one step of call audio out: the next packet from the
// playout buffer, decoded, its FEC copy, or an expand standing in for it.
// Shared by the audio engine and the stand's replay, so the bench measures
// the code the phone runs.
//
#ifndef TG_CALL_PLAYOUT_H
#define TG_CALL_PLAYOUT_H

#include <stdint.h>
#include <opus.h>

#include "TGCallExpand.h"
#include "TGCallJitter.h"

#ifdef __cplusplus
extern "C" {
#endif

/// Writes at most 5760 samples to `out` and returns how many (always > 0).
/// `action` says what the step was, when not NULL.
int TGPlayoutStep(TGJitter *jitter, OpusDecoder *decoder, TGExpand *expand,
                  int16_t *out, TGJitterAction *action);

#ifdef __cplusplus
}
#endif

#endif
