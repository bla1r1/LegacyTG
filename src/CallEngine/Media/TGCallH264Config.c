#include "TGCallH264Config.h"

#include <string.h>

int TGAvcCParse(const uint8_t *b, size_t length,
                const uint8_t **sps, size_t *spsLength,
                const uint8_t **pps, size_t *ppsLength) {
	if (!b || length < 7 || b[0] != 1)
		return 0;
	size_t at = 5;
	int spsCount = b[at++] & 0x1F;
	*sps = NULL;
	*pps = NULL;
	for (int i = 0; i < spsCount; i++){
		if (at + 2 > length)
			return 0;
		size_t n = ((size_t)b[at] << 8) | b[at + 1];
		at += 2;
		if (at + n > length)
			return 0;
		if (!*sps){
			*sps = b + at;
			*spsLength = n;
		}
		at += n;
	}
	if (at >= length)
		return 0;
	int ppsCount = b[at++];
	for (int i = 0; i < ppsCount; i++){
		if (at + 2 > length)
			return 0;
		size_t n = ((size_t)b[at] << 8) | b[at + 1];
		at += 2;
		if (at + n > length)
			return 0;
		if (!*pps){
			*pps = b + at;
			*ppsLength = n;
		}
		at += n;
	}
	return *sps && *pps;
}

size_t TGAvcCBuild(const uint8_t *sps, size_t spsLength,
                   const uint8_t *pps, size_t ppsLength,
                   uint8_t *out, size_t capacity) {
	size_t need = 11 + spsLength + ppsLength;
	if (!sps || !pps || spsLength < 4 || spsLength > 0xFFFF || ppsLength > 0xFFFF || need > capacity)
		return 0;
	uint8_t *p = out;
	*p++ = 1;
	*p++ = sps[1];            // profile
	*p++ = sps[2];            // constraint flags
	*p++ = sps[3];            // level
	*p++ = 0xFF;              // 4-byte NAL lengths
	*p++ = 0xE1;              // one SPS
	*p++ = (uint8_t)(spsLength >> 8);
	*p++ = (uint8_t)spsLength;
	memcpy(p, sps, spsLength);
	p += spsLength;
	*p++ = 1;                 // one PPS
	*p++ = (uint8_t)(ppsLength >> 8);
	*p++ = (uint8_t)ppsLength;
	memcpy(p, pps, ppsLength);
	return need;
}

typedef struct {
	const uint8_t *data;
	size_t length, bit;
	int zeros;            // emulation prevention: 00 00 03 drops the 03
	size_t byte;
	uint8_t current;
	int left;
	int failed;
} TGBits;

static int TGBitsNext(TGBits *r) {
	if (r->left == 0){
		for (;;){
			if (r->byte >= r->length){
				r->failed = 1;
				return 0;
			}
			uint8_t v = r->data[r->byte++];
			if (r->zeros >= 2 && v == 3){
				r->zeros = 0;
				continue;
			}
			r->zeros = v == 0 ? r->zeros + 1 : 0;
			r->current = v;
			r->left = 8;
			break;
		}
	}
	r->left--;
	return (r->current >> r->left) & 1;
}

static unsigned TGBitsRead(TGBits *r, int n) {
	unsigned v = 0;
	while (n--)
		v = (v << 1) | (unsigned)TGBitsNext(r);
	return v;
}

static unsigned TGBitsUe(TGBits *r) {
	int zeros = 0;
	while (!TGBitsNext(r) && !r->failed && zeros < 32)
		zeros++;
	if (zeros >= 32 || r->failed) {
		r->failed = 1;
		return 0;
	}
	return zeros ? ((1u << zeros) - 1) + TGBitsRead(r, zeros) : 0;
}

static int TGBitsSe(TGBits *r) {
	unsigned v = TGBitsUe(r);
	return (v & 1) ? (int)((v + 1) / 2) : -(int)(v / 2);
}

static void TGSkipScalingList(TGBits *r, int size) {
	int last = 8, next = 8;
	for (int i = 0; i < size && !r->failed; i++){
		if (next)
			next = (last + TGBitsSe(r) + 256) % 256;
		last = next ? next : last;
	}
}

int TGH264SpsSize(const uint8_t *sps, size_t length, int *width, int *height) {
	if (!sps || length < 4 || (sps[0] & 0x1F) != 7)
		return 0;
	TGBits r = { sps + 1, length - 1 };
	unsigned profile = TGBitsRead(&r, 8);
	TGBitsRead(&r, 16);                   // constraints, level
	TGBitsUe(&r);                         // sps id
	unsigned chroma = 1;
	if (profile == 100 || profile == 110 || profile == 122 || profile == 244 || profile == 44 ||
	    profile == 83 || profile == 86 || profile == 118 || profile == 128 || profile == 138 ||
	    profile == 139 || profile == 134 || profile == 135){
		chroma = TGBitsUe(&r);
		if (chroma == 3)
			TGBitsRead(&r, 1);
		TGBitsUe(&r);                     // luma bit depth
		TGBitsUe(&r);                     // chroma bit depth
		TGBitsRead(&r, 1);
		if (TGBitsRead(&r, 1))            // scaling matrices
			for (int i = 0; i < (chroma == 3 ? 12 : 8); i++)
				if (TGBitsRead(&r, 1))
					TGSkipScalingList(&r, i < 6 ? 16 : 64);
	}
	TGBitsUe(&r);                         // log2 max frame num
	unsigned pocType = TGBitsUe(&r);
	if (pocType == 0){
		TGBitsUe(&r);
	} else if (pocType == 1){
		TGBitsRead(&r, 1);
		TGBitsSe(&r);
		TGBitsSe(&r);
		unsigned cycle = TGBitsUe(&r);
		for (unsigned i = 0; i < cycle && !r.failed; i++)
			TGBitsSe(&r);
	}
	TGBitsUe(&r);                         // max ref frames
	TGBitsRead(&r, 1);
	unsigned mbWidth = TGBitsUe(&r) + 1, mapHeight = TGBitsUe(&r) + 1;
	unsigned frameMbsOnly = TGBitsRead(&r, 1);
	if (!frameMbsOnly)
		TGBitsRead(&r, 1);
	TGBitsRead(&r, 1);                    // direct 8x8
	unsigned left = 0, right = 0, top = 0, bottom = 0;
	if (TGBitsRead(&r, 1)){
		left = TGBitsUe(&r);
		right = TGBitsUe(&r);
		top = TGBitsUe(&r);
		bottom = TGBitsUe(&r);
	}
	if (r.failed)
		return 0;
	unsigned cropX = chroma == 0 || chroma == 3 ? 1 : 2;
	unsigned cropY = (chroma == 1 ? 2 : 1) * (2 - frameMbsOnly);
	long w = (long)mbWidth * 16 - (long)(left + right) * cropX;
	long h = (long)mapHeight * 16 * (2 - frameMbsOnly) - (long)(top + bottom) * cropY;
	if (w <= 0 || h <= 0 || w > 8192 || h > 8192)
		return 0;
	*width = (int)w;
	*height = (int)h;
	return 1;
}
