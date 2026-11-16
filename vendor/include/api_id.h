#ifndef API_ID_H
#define API_ID_H

// tg_api_key.h is made from tg_config.h by scripts/gen_api_key.py: the keys
// XOR-ed with a per-build mask, so `strings` on the app does not print them.
#include "tg_api_key.h"

static inline int TGApiId(void) {
	return (int)(kTGApiIdMasked ^ kTGApiIdMask);
}

/// `out` holds TG_API_HASH_LEN + 1 bytes.
static inline void TGApiHash(char *out) {
	for (int i = 0; i < TG_API_HASH_LEN; i++)
		out[i] = (char)(kTGApiHashMasked[i] ^ kTGApiHashMask[i]);
	out[TG_API_HASH_LEN] = '\0';
}

#endif
