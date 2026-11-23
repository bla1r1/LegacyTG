#include "TGCallVP8Rtp.h"

#include <string.h>

int TGVP8Packetize(const uint8_t *frame, size_t length, uint16_t pictureId,
                   uint8_t *out, size_t maxPayload, size_t *lengths, int maxPackets) {
	if (!frame || !length || maxPayload <= TGVP8DescriptorLength)
		return 0;
	size_t room = maxPayload - TGVP8DescriptorLength;
	size_t packets = (length + room - 1) / room;
	if (packets > (size_t)maxPackets)
		return 0;
	size_t base = length / packets, extra = length % packets, at = 0;
	for (size_t i = 0; i < packets; i++){
		size_t part = base + (i < extra ? 1 : 0);
		uint8_t *p = out + i * maxPayload;
		p[0] = (uint8_t)(0x80 | (i == 0 ? 0x10 : 0));   // X, S on the first, partition 0
		p[1] = 0x80;                                      // I: a picture id follows
		p[2] = (uint8_t)(0x80 | ((pictureId >> 8) & 0x7F)); // M: 15 bits
		p[3] = (uint8_t)pictureId;
		memcpy(p + TGVP8DescriptorLength, frame + at, part);
		lengths[i] = TGVP8DescriptorLength + part;
		at += part;
	}
	return (int)packets;
}

size_t TGVP8DescriptorSize(const uint8_t *p, size_t length) {
	if (length < 1)
		return 0;
	size_t size = 1;
	if (p[0] & 0x80){                       // X
		if (length < 2)
			return 0;
		uint8_t ext = p[1];
		size = 2;
		if (ext & 0x80){                    // I: picture id, 7 or 15 bits
			if (length < size + 1)
				return 0;
			size += (p[size] & 0x80) ? 2 : 1;
		}
		if (ext & 0x40)                     // L: TL0PICIDX
			size++;
		if (ext & 0x30)                     // T or K: TID/KEYIDX byte
			size++;
	}
	return size < length ? size : 0;
}

void TGVP8DepacketizerInit(TGVP8Depacketizer *d, uint8_t *storage, size_t capacity) {
	memset(d, 0, sizeof(*d));
	d->frame = storage;
	d->capacity = capacity;
	d->waitingForKeyframe = 1;
}

void TGVP8DepacketizerDrop(TGVP8Depacketizer *d) {
	d->inFrame = 0;
	d->length = 0;
	d->waitingForKeyframe = 1;
}

int TGVP8DepacketizerPush(TGVP8Depacketizer *d, const uint8_t *rtp, size_t length, int *keyframe) {
	if (!rtp || length < 12 || (rtp[0] >> 6) != 2)
		return 0;
	size_t header = 12 + 4 * (size_t)(rtp[0] & 0x0F);
	if ((rtp[0] & 0x10) && length >= header + 4)
		header += 4 + 4 * (size_t)((rtp[header + 2] << 8) | rtp[header + 3]);
	size_t padding = (rtp[0] & 0x20) ? rtp[length - 1] : 0;
	if (length <= header + padding)
		return 0;                           // padding only: a bandwidth probe
	const uint8_t *payload = rtp + header;
	size_t payloadLength = length - header - padding;
	size_t descriptor = TGVP8DescriptorSize(payload, payloadLength);
	if (!descriptor)
		return 0;
	int marker = (rtp[1] & 0x80) != 0;
	uint32_t timestamp = ((uint32_t)rtp[4] << 24) | ((uint32_t)rtp[5] << 16) |
	                     ((uint32_t)rtp[6] << 8) | rtp[7];
	int start = (payload[0] & 0x10) && (payload[0] & 0x07) == 0;
	const uint8_t *data = payload + descriptor;
	size_t dataLength = payloadLength - descriptor;

	if (start){
		d->inFrame = 1;
		d->length = 0;
		d->timestamp = timestamp;
	} else if (!d->inFrame || timestamp != d->timestamp){
		d->inFrame = 0;
		return 0;                           // the start of this frame never came
	}
	if (d->length + dataLength > d->capacity){
		TGVP8DepacketizerDrop(d);
		return 0;
	}
	memcpy(d->frame + d->length, data, dataLength);
	d->length += dataLength;
	if (!marker)
		return 0;

	d->inFrame = 0;
	// The frame tag's P bit is 0 on a keyframe (RFC 6386 9.1).
	int key = d->length >= 3 && (d->frame[0] & 0x01) == 0;
	if (d->waitingForKeyframe && !key)
		return 0;
	d->waitingForKeyframe = 0;
	if (keyframe)
		*keyframe = key;
	return 1;
}
