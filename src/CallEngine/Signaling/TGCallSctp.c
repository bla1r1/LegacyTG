#include "TGCallSctp.h"

#include <string.h>

enum {
	kChunkData         = 0,
	kChunkInit         = 1,
	kChunkInitAck      = 2,
	kChunkSack         = 3,
	kChunkHeartbeat    = 4,
	kChunkHeartbeatAck = 5,
	kChunkAbort        = 6,
	kChunkShutdown     = 7,
	kChunkShutdownAck  = 8,
	kChunkCookieEcho   = 10,
	kChunkCookieAck    = 11,
};

enum {
	kPpidControl     = 50,
	kPpidText        = 51,
	kPpidTextEmpty   = 56,
};

enum {
	kDcepAck  = 0x02,
	kDcepOpen = 0x03,
};

static const uint16_t kPort = 5000;
static const uint16_t kStreams = 16;
static const uint32_t kWindow = 131072;
static const double kResendAfter = 1.0;

static uint32_t TGRead32(const uint8_t *p) {
	return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) | ((uint32_t)p[2] << 8) | p[3];
}

static uint16_t TGRead16(const uint8_t *p) {
	return (uint16_t)(((uint16_t)p[0] << 8) | p[1]);
}

static void TGWrite32(uint8_t *p, uint32_t v) {
	p[0] = (uint8_t)(v >> 24); p[1] = (uint8_t)(v >> 16); p[2] = (uint8_t)(v >> 8); p[3] = (uint8_t)v;
}

static void TGWrite16(uint8_t *p, uint16_t v) {
	p[0] = (uint8_t)(v >> 8); p[1] = (uint8_t)v;
}

// Serial-number comparison, RFC 1982: a is after b.
static int TGTsnAfter(uint32_t a, uint32_t b) {
	return (int32_t)(a - b) > 0;
}

uint32_t TGSctpChecksum(const uint8_t *packet, size_t length) {
	static uint32_t table[256];
	static int ready;
	if (!ready){
		for (uint32_t i = 0; i < 256; i++){
			uint32_t c = i;
			for (int k = 0; k < 8; k++)
				c = (c & 1) ? (c >> 1) ^ 0x82F63B78u : c >> 1;
			table[i] = c;
		}
		ready = 1;
	}
	uint32_t crc = 0xFFFFFFFFu;
	for (size_t i = 0; i < length; i++){
		// The checksum field itself counts as zero.
		uint8_t byte = (i >= 8 && i < 12) ? 0 : packet[i];
		crc = table[(crc ^ byte) & 0xFF] ^ (crc >> 8);
	}
	return ~crc;
}

/// Fills in the common header and checksum and hands the packet out.
static void TGSctpFlush(TGSctp *sctp, uint8_t *packet, size_t length, uint32_t tag) {
	TGWrite16(packet, kPort);
	TGWrite16(packet + 2, kPort);
	TGWrite32(packet + 4, tag);
	uint32_t crc = TGSctpChecksum(packet, length);
	// Stored least significant byte first, as every SCTP stack does.
	packet[8] = (uint8_t)crc; packet[9] = (uint8_t)(crc >> 8);
	packet[10] = (uint8_t)(crc >> 16); packet[11] = (uint8_t)(crc >> 24);
	if (sctp->send)
		sctp->send(sctp->context, packet, length);
}

static size_t TGSctpPutChunk(uint8_t *at, uint8_t type, uint8_t flags,
                             const uint8_t *value, size_t valueLength) {
	at[0] = type;
	at[1] = flags;
	TGWrite16(at + 2, (uint16_t)(4 + valueLength));
	if (valueLength)
		memcpy(at + 4, value, valueLength);
	size_t length = 4 + valueLength;
	while (length & 3)
		at[length++] = 0;
	return length;
}

void TGSctpInit(TGSctp *sctp, int opener, uint32_t localTag, uint32_t initialTsn) {
	void *context = sctp->context;
	TGSctpSendFn send = sctp->send;
	TGSctpMessageFn onMessage = sctp->onMessage;
	TGSctpOpenFn onOpen = sctp->onOpen;
	memset(sctp, 0, sizeof(*sctp));
	sctp->context = context;
	sctp->send = send;
	sctp->onMessage = onMessage;
	sctp->onOpen = onOpen;
	sctp->opener = opener;
	sctp->localTag = localTag ? localTag : 1;
	sctp->nextTsn = initialTsn;
}

static void TGSctpResetAssociation(TGSctp *sctp) {
	sctp->established = 0;
	sctp->channelOpen = 0;
	sctp->sentOpen = 0;
	sctp->nextSsn = 0;
	sctp->outgoingCount = 0;
	sctp->reassembling = 0;
	sctp->reassemblyLength = 0;
}

static void TGSctpSendOutgoing(TGSctp *sctp, TGSctpOutgoing *entry, double now) {
	uint8_t *packet = sctp->scratch;
	memcpy(packet + 12, entry->chunk, entry->length);
	entry->sentAt = now;
	TGSctpFlush(sctp, packet, 12 + entry->length, sctp->peerTag);
}

static int TGSctpQueueData(TGSctp *sctp, uint32_t ppid, const uint8_t *data,
                           size_t length, double now) {
	if (!sctp->established || length > TGSctpMaxMessage ||
	    sctp->outgoingCount >= TGSctpOutgoingSlots)
		return -1;
	TGSctpOutgoing *entry = &sctp->outgoing[sctp->outgoingCount++];
	uint8_t value[12 + TGSctpMaxMessage];
	uint32_t tsn = sctp->nextTsn++;
	TGWrite32(value, tsn);
	TGWrite16(value + 4, 0);                 // stream 0
	TGWrite16(value + 6, sctp->nextSsn++);
	TGWrite32(value + 8, ppid);
	memcpy(value + 12, data, length);
	entry->tsn = tsn;
	entry->length = (uint16_t)TGSctpPutChunk(entry->chunk, kChunkData, 0x03, value, 12 + length);
	if (sctp->holding)
		entry->sentAt = -1;
	else
		TGSctpSendOutgoing(sctp, entry, now);
	return 0;
}

static void TGSctpOpenChannel(TGSctp *sctp, double now) {
	if (sctp->sentOpen)
		return;
	sctp->sentOpen = 1;
	// Reliable, ordered, label "data", no protocol: what tgcalls creates.
	static const uint8_t open[] = {
		kDcepOpen, 0x00, 0x00, 0x00, 0, 0, 0, 0,
		0x00, 0x04, 0x00, 0x00, 'd', 'a', 't', 'a',
	};
	TGSctpQueueData(sctp, kPpidControl, open, sizeof(open), now);
	// The open goes first on an ordered stream, so anything queued after it
	// reaches the peer's channel after the channel exists.
	sctp->channelOpen = 1;
	if (sctp->onOpen)
		sctp->onOpen(sctp->context);
}

static void TGSctpDeliver(TGSctp *sctp, uint32_t ppid, const uint8_t *data,
                          size_t length, double now) {
	if (ppid == kPpidControl){
		if (length >= 1 && data[0] == kDcepOpen && !sctp->opener){
			uint8_t ack = kDcepAck;
			TGSctpQueueData(sctp, kPpidControl, &ack, 1, now);
			if (!sctp->channelOpen){
				sctp->channelOpen = 1;
				if (sctp->onOpen)
					sctp->onOpen(sctp->context);
			}
		}
		return;
	}
	if (ppid == kPpidText && sctp->onMessage)
		sctp->onMessage(sctp->context, data, length);
	else if (ppid == kPpidTextEmpty && sctp->onMessage)
		sctp->onMessage(sctp->context, data, 0);
}

static void TGSctpHandleData(TGSctp *sctp, const uint8_t *value, size_t length,
                             uint8_t flags, double now) {
	if (length < 12)
		return;
	uint32_t tsn = TGRead32(value);
	uint32_t ppid = TGRead32(value + 8);
	// Only the next TSN in order is taken. A duplicate is acked again; one past
	// a gap is dropped and comes back on the peer's retransmission timer.
	if (tsn != sctp->peerCumulativeTsn + 1)
		return;
	sctp->peerCumulativeTsn = tsn;

	const uint8_t *data = value + 12;
	size_t dataLength = length - 12;
	int begin = (flags & 0x02) != 0, end = (flags & 0x01) != 0;
	if (begin && end){
		TGSctpDeliver(sctp, ppid, data, dataLength, now);
		return;
	}
	if (begin){
		sctp->reassembling = 1;
		sctp->reassemblyLength = 0;
		sctp->reassemblyPpid = ppid;
	}
	if (!sctp->reassembling)
		return;
	if (sctp->reassemblyLength + dataLength > sizeof(sctp->reassembly)){
		sctp->reassembling = 0;
		return;
	}
	memcpy(sctp->reassembly + sctp->reassemblyLength, data, dataLength);
	sctp->reassemblyLength += dataLength;
	if (end){
		sctp->reassembling = 0;
		TGSctpDeliver(sctp, sctp->reassemblyPpid, sctp->reassembly, sctp->reassemblyLength, now);
	}
}

static void TGSctpHandleSack(TGSctp *sctp, const uint8_t *value, size_t length) {
	if (length < 12)
		return;
	uint32_t cumulative = TGRead32(value);
	int kept = 0;
	for (int i = 0; i < sctp->outgoingCount; i++){
		if (TGTsnAfter(sctp->outgoing[i].tsn, cumulative)){
			if (kept != i)
				sctp->outgoing[kept] = sctp->outgoing[i];
			kept++;
		}
	}
	sctp->outgoingCount = kept;
}

static void TGSctpSendInitAck(TGSctp *sctp) {
	uint8_t value[16 + 12];
	TGWrite32(value, sctp->localTag);
	TGWrite32(value + 4, kWindow);
	TGWrite16(value + 8, kStreams);
	TGWrite16(value + 10, kStreams);
	TGWrite32(value + 12, sctp->nextTsn);
	// State Cookie: nothing the peer can use but our tag, which is all that
	// identifies the one association this side ever has.
	TGWrite16(value + 16, 7);
	TGWrite16(value + 18, 12);
	memcpy(value + 20, "TGCK", 4);
	TGWrite32(value + 24, sctp->localTag);
	uint8_t *packet = sctp->scratch;
	size_t length = 12 + TGSctpPutChunk(packet + 12, kChunkInitAck, 0, value, sizeof(value));
	TGSctpFlush(sctp, packet, length, sctp->peerTag);
}

void TGSctpReceive(TGSctp *sctp, const uint8_t *packet, size_t length, double now) {
	if (!packet || length < 16)
		return;
	uint32_t stored = (uint32_t)packet[8] | ((uint32_t)packet[9] << 8) |
	                  ((uint32_t)packet[10] << 16) | ((uint32_t)packet[11] << 24);
	if (stored != TGSctpChecksum(packet, length))
		return;
	uint32_t tag = TGRead32(packet + 4);
	uint8_t firstType = packet[12];
	if (firstType == kChunkInit){
		if (tag != 0)
			return;
	} else if (tag != sctp->localTag){
		return;
	}

	// Replies to this packet (COOKIE ACK, SACK, HEARTBEAT ACK) share one packet,
	// and DATA it causes (a DCEP ack, a message the owner answers with) goes
	// after it: dcsctp drops DATA that arrives before its COOKIE ACK.
	sctp->holding = 1;
	uint8_t reply[TGSctpMaxPacket];
	size_t replyLength = 12;
	int sawData = 0;
	int openAfterReply = 0;

	size_t at = 12;
	while (at + 4 <= length){
		uint8_t type = packet[at];
		uint8_t flags = packet[at + 1];
		uint16_t chunkLength = TGRead16(packet + at + 2);
		if (chunkLength < 4 || at + chunkLength > length)
			break;
		const uint8_t *value = packet + at + 4;
		size_t valueLength = chunkLength - 4;

		switch (type){
			case kChunkInit: {
				sctp->holding = 0;
				if (valueLength < 16)
					return;
				uint32_t peerTag = TGRead32(value);
				if (sctp->established && peerTag != sctp->peerTag)
					TGSctpResetAssociation(sctp);
				sctp->peerTag = peerTag;
				sctp->peerCumulativeTsn = TGRead32(value + 12) - 1;
				sctp->holding = 0;
				TGSctpSendInitAck(sctp);
				return;
			}
			case kChunkCookieEcho: {
				if (valueLength < 8 || memcmp(value, "TGCK", 4) ||
				    TGRead32(value + 4) != sctp->localTag){
					sctp->holding = 0;
					return;
				}
				if (!sctp->established){
					sctp->established = 1;
					if (sctp->opener)
						openAfterReply = 1;
				}
				if (replyLength + 4 <= sizeof(reply))
					replyLength += TGSctpPutChunk(reply + replyLength, kChunkCookieAck, 0, NULL, 0);
				break;
			}
			case kChunkData:
				if (sctp->established){
					sawData = 1;
					TGSctpHandleData(sctp, value, valueLength, flags, now);
				}
				break;
			case kChunkSack:
				TGSctpHandleSack(sctp, value, valueLength);
				break;
			case kChunkHeartbeat:
				if (replyLength + chunkLength + 3 <= sizeof(reply))
					replyLength += TGSctpPutChunk(reply + replyLength, kChunkHeartbeatAck, 0,
					                              value, valueLength);
				break;
			case kChunkShutdown:
				if (replyLength + 4 <= sizeof(reply))
					replyLength += TGSctpPutChunk(reply + replyLength, kChunkShutdownAck, 0, NULL, 0);
				TGSctpResetAssociation(sctp);
				break;
			case kChunkAbort:
				TGSctpResetAssociation(sctp);
				sctp->holding = 0;
				return;
			default:
				break;
		}
		at += (chunkLength + 3) & ~(size_t)3;
	}

	if (sawData && replyLength + 16 <= sizeof(reply)){
		uint8_t sack[12];
		TGWrite32(sack, sctp->peerCumulativeTsn);
		TGWrite32(sack + 4, kWindow);
		TGWrite16(sack + 8, 0);
		TGWrite16(sack + 10, 0);
		replyLength += TGSctpPutChunk(reply + replyLength, kChunkSack, 0, sack, sizeof(sack));
	}
	if (replyLength > 12)
		TGSctpFlush(sctp, reply, replyLength, sctp->peerTag);
	sctp->holding = 0;
	for (int i = 0; i < sctp->outgoingCount; i++)
		if (sctp->outgoing[i].sentAt < 0)
			TGSctpSendOutgoing(sctp, &sctp->outgoing[i], now);
	if (openAfterReply)
		TGSctpOpenChannel(sctp, now);
}

int TGSctpSendText(TGSctp *sctp, const char *text, size_t length, double now) {
	if (!sctp->channelOpen)
		return -1;
	if (!length){
		uint8_t zero = 0;
		return TGSctpQueueData(sctp, kPpidTextEmpty, &zero, 1, now);
	}
	return TGSctpQueueData(sctp, kPpidText, (const uint8_t *)text, length, now);
}

void TGSctpTick(TGSctp *sctp, double now) {
	if (!sctp->established)
		return;
	for (int i = 0; i < sctp->outgoingCount; i++)
		if (now - sctp->outgoing[i].sentAt >= kResendAfter)
			TGSctpSendOutgoing(sctp, &sctp->outgoing[i], now);
}
