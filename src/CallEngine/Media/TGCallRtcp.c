#include "TGCallRtcp.h"

#include <string.h>

static void TGWrite32(uint8_t *p, uint32_t v) {
	p[0] = (uint8_t)(v >> 24); p[1] = (uint8_t)(v >> 16); p[2] = (uint8_t)(v >> 8); p[3] = (uint8_t)v;
}

static uint32_t TGRead32(const uint8_t *p) {
	return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) | ((uint32_t)p[2] << 8) | p[3];
}

int TGRtpStatsUpdate(TGRtpStats *stats, uint32_t ssrc, uint16_t seq) {
	if (!stats->started || stats->ssrc != ssrc){
		memset(stats, 0, sizeof(*stats));
		stats->ssrc = ssrc;
		stats->started = 1;
		stats->maxSeq = seq;
		stats->baseSeq = seq;
		stats->received = 1;
		return 0;
	}
	stats->received++;
	uint16_t delta = (uint16_t)(seq - stats->maxSeq);
	if (delta == 0 || delta >= 0x8000)
		return 0;            // duplicate or late: no news about loss
	if (seq < stats->maxSeq)
		stats->cycles += 0x10000;
	stats->maxSeq = seq;
	return delta > 1;
}

size_t TGRtcpWriteReceiverReport(uint8_t *out, size_t capacity, uint32_t senderSsrc,
                                 TGRtpStats *stats, int count) {
	int blocks = 0;
	for (int i = 0; i < count; i++)
		if (stats[i].started)
			blocks++;
	size_t length = 8 + 24 * (size_t)blocks;
	if (capacity < length || blocks > 31)
		return 0;
	out[0] = (uint8_t)(0x80 | blocks);
	out[1] = 201;
	out[2] = (uint8_t)((length / 4 - 1) >> 8);
	out[3] = (uint8_t)(length / 4 - 1);
	TGWrite32(out + 4, senderSsrc);
	uint8_t *block = out + 8;
	for (int i = 0; i < count; i++){
		TGRtpStats *s = &stats[i];
		if (!s->started)
			continue;
		uint32_t extendedMax = s->cycles + s->maxSeq;
		uint32_t expected = extendedMax - s->baseSeq + 1;
		int32_t lost = (int32_t)(expected - s->received);
		if (lost < 0)
			lost = 0;
		if (lost > 0x7FFFFF)
			lost = 0x7FFFFF;
		uint32_t expectedInterval = expected - s->expectedPrior;
		uint32_t receivedInterval = s->received - s->receivedPrior;
		s->expectedPrior = expected;
		s->receivedPrior = s->received;
		int32_t lostInterval = (int32_t)(expectedInterval - receivedInterval);
		uint8_t fraction = 0;
		if (expectedInterval && lostInterval > 0)
			fraction = (uint8_t)(((uint32_t)lostInterval << 8) / expectedInterval);
		TGWrite32(block, s->ssrc);
		block[4] = fraction;
		block[5] = (uint8_t)(lost >> 16);
		block[6] = (uint8_t)(lost >> 8);
		block[7] = (uint8_t)lost;
		TGWrite32(block + 8, extendedMax);
		TGWrite32(block + 12, 0);   // jitter: not measured
		TGWrite32(block + 16, 0);   // no sender report to quote
		TGWrite32(block + 20, 0);
		block += 24;
	}
	return length;
}

size_t TGRtcpWritePli(uint8_t *out, size_t capacity, uint32_t senderSsrc, uint32_t mediaSsrc) {
	if (capacity < 12)
		return 0;
	out[0] = 0x81;
	out[1] = 206;
	out[2] = 0;
	out[3] = 2;
	TGWrite32(out + 4, senderSsrc);
	TGWrite32(out + 8, mediaSsrc);
	return 12;
}

int TGRtcpAsksForKeyframe(const uint8_t *packet, size_t length, uint32_t mediaSsrc) {
	size_t at = 0;
	while (at + 4 <= length){
		uint8_t format = packet[at] & 0x1F;
		uint8_t type = packet[at + 1];
		size_t size = 4 * ((size_t)((packet[at + 2] << 8) | packet[at + 3]) + 1);
		if (at + size > length)
			break;
		if (type == 206 && size >= 12){
			if (format == 1 && TGRead32(packet + at + 8) == mediaSsrc)
				return 1;
			// FIR names its target in each 8-byte FCI entry, not in the header.
			if (format == 4)
				for (size_t fci = at + 12; fci + 8 <= at + size; fci += 8)
					if (TGRead32(packet + fci) == mediaSsrc)
						return 1;
		}
		at += size;
	}
	return 0;
}

int TGRtcpLossFor(const uint8_t *packet, size_t length, uint32_t ssrc,
                  uint8_t *fraction, uint32_t *cumulative) {
	size_t at = 0;
	while (at + 4 <= length){
		uint8_t count = packet[at] & 0x1F;
		uint8_t type = packet[at + 1];
		size_t size = 4 * ((size_t)((packet[at + 2] << 8) | packet[at + 3]) + 1);
		if (at + size > length)
			break;
		// SR carries 20 bytes of sender info before its report blocks; RR none.
		size_t blocks = type == 200 ? at + 28 : type == 201 ? at + 8 : 0;
		for (uint8_t i = 0; blocks && i < count && blocks + 24 * (i + 1) <= at + size; i++){
			const uint8_t *block = packet + blocks + 24 * i;
			if (TGRead32(block) != ssrc)
				continue;
			*fraction = block[4];
			*cumulative = ((uint32_t)block[5] << 16) | ((uint32_t)block[6] << 8) | block[7];
			return 1;
		}
		at += size;
	}
	return 0;
}

int TGRtcpNackedSequences(const uint8_t *packet, size_t length, uint32_t mediaSsrc,
                          uint16_t *out, int max) {
	int count = 0;
	size_t at = 0;
	while (at + 4 <= length){
		uint8_t format = packet[at] & 0x1F;
		uint8_t type = packet[at + 1];
		size_t size = 4 * ((size_t)((packet[at + 2] << 8) | packet[at + 3]) + 1);
		if (at + size > length)
			break;
		// Generic NACK (RFC 4585 6.2.1): one PID and a bitmask of the 16
		// sequence numbers after it, per FCI entry.
		if (type == 205 && format == 1 && size >= 16 && TGRead32(packet + at + 8) == mediaSsrc){
			for (size_t fci = at + 12; fci + 4 <= at + size; fci += 4){
				uint16_t pid = (uint16_t)((packet[fci] << 8) | packet[fci + 1]);
				uint16_t mask = (uint16_t)((packet[fci + 2] << 8) | packet[fci + 3]);
				if (count < max)
					out[count++] = pid;
				for (int bit = 0; bit < 16; bit++)
					if ((mask & (1 << bit)) && count < max)
						out[count++] = (uint16_t)(pid + bit + 1);
			}
		}
		at += size;
	}
	return count;
}

size_t TGRtcpWriteNack(uint8_t *out, size_t capacity, uint32_t senderSsrc,
                       uint32_t mediaSsrc, uint16_t first, uint16_t count) {
	size_t entries = (count + 16) / 17;
	size_t length = 12 + 4 * entries;
	if (!count || capacity < length)
		return 0;
	out[0] = 0x81;
	out[1] = 205;
	out[2] = (uint8_t)((length / 4 - 1) >> 8);
	out[3] = (uint8_t)(length / 4 - 1);
	TGWrite32(out + 4, senderSsrc);
	TGWrite32(out + 8, mediaSsrc);
	uint8_t *fci = out + 12;
	uint16_t left = count, pid = first;
	while (left){
		uint16_t mask = 0;
		uint16_t inEntry = left > 17 ? 17 : left;
		for (uint16_t bit = 0; bit + 1 < inEntry; bit++)
			mask |= (uint16_t)(1 << bit);
		fci[0] = (uint8_t)(pid >> 8); fci[1] = (uint8_t)pid;
		fci[2] = (uint8_t)(mask >> 8); fci[3] = (uint8_t)mask;
		fci += 4;
		pid = (uint16_t)(pid + inEntry);
		left = (uint16_t)(left - inEntry);
	}
	return length;
}

int TGRateAfterLoss(int kbps, int minKbps, int maxKbps, uint8_t fraction) {
	if (fraction < 5)
		kbps = kbps * 108 / 100 + 1;
	else if (fraction > 26)
		kbps = kbps * (512 - fraction) / 512;
	return kbps < minKbps ? minKbps : kbps > maxKbps ? maxKbps : kbps;
}

size_t TGRtcpWriteRemb(uint8_t *out, size_t capacity, uint32_t senderSsrc, uint32_t mediaSsrc, uint32_t bitsPerSecond) {
	if (capacity < 24)
		return 0;
	uint32_t exponent = 0, mantissa = bitsPerSecond;
	while (mantissa > 0x3FFFF){
		mantissa >>= 1;
		exponent++;
	}
	out[0] = 0x80 | 15;                 // PSFB, FMT 15: application layer feedback
	out[1] = 206;
	out[2] = 0;
	out[3] = 5;
	TGWrite32(out + 4, senderSsrc);
	TGWrite32(out + 8, 0);
	memcpy(out + 12, "REMB", 4);
	out[16] = 1;                        // one SSRC
	out[17] = (uint8_t)((exponent << 2) | (mantissa >> 16));
	out[18] = (uint8_t)(mantissa >> 8);
	out[19] = (uint8_t)mantissa;
	TGWrite32(out + 20, mediaSsrc);
	return 24;
}
