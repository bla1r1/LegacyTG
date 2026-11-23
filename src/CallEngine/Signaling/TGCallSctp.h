//
// TGCallSctp - the one data channel tgcalls 9.0.0 opens over DTLS.
//
// tgcalls sends MediaState (mute, camera on/off, rotation) only over an SCTP
// data channel labelled "data" on stream 0, and treats a peer that never
// opens it as having no camera. This is the least of RFC 4960 that dcsctp
// accepts: we never send INIT (dcsctp always does), answer it with a cookie,
// SACK every DATA chunk, answer heartbeats, and resend our own messages until
// they are acknowledged. No PR-SCTP, no stream reset, no congestion control:
// the channel carries a few hundred bytes a minute.
//
// Pure C and no allocation, so the host tests run it as the device does.
//
#ifndef TG_CALL_SCTP_H
#define TG_CALL_SCTP_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define TGSctpMaxPacket        1200
#define TGSctpMaxMessage       1024
#define TGSctpOutgoingSlots    16

typedef void (*TGSctpSendFn)(void *context, const uint8_t *packet, size_t length);
typedef void (*TGSctpMessageFn)(void *context, const uint8_t *text, size_t length);
typedef void (*TGSctpOpenFn)(void *context);

typedef struct {
	uint32_t tsn;
	double   sentAt;
	uint16_t length;
	uint8_t  chunk[16 + TGSctpMaxMessage];
} TGSctpOutgoing;

typedef struct {
	int      opener;            // the caller sends DATA_CHANNEL_OPEN, the callee acks it
	uint32_t localTag;
	uint32_t peerTag;
	uint32_t nextTsn;
	uint32_t peerCumulativeTsn;
	uint16_t nextSsn;
	int      established;
	int      channelOpen;
	int      sentOpen;
	int      holding;           // inside a receive: DATA waits until the reply is out

	TGSctpOutgoing outgoing[TGSctpOutgoingSlots];
	int      outgoingCount;

	uint8_t  reassembly[TGSctpMaxMessage];
	size_t   reassemblyLength;
	uint32_t reassemblyPpid;
	int      reassembling;

	uint8_t  scratch[TGSctpMaxPacket];

	void            *context;
	TGSctpSendFn     send;
	TGSctpMessageFn  onMessage;
	TGSctpOpenFn     onOpen;
} TGSctp;

/// `localTag` and `initialTsn` are random in a call; tests pin them.
void TGSctpInit(TGSctp *sctp, int opener, uint32_t localTag, uint32_t initialTsn);

/// One SCTP packet out of a DTLS application-data record.
void TGSctpReceive(TGSctp *sctp, const uint8_t *packet, size_t length, double now);

/// Queues one string message (PPID 51) on stream 0. Returns 0 when queued,
/// -1 when the channel is not open, the text is too long or the queue is full.
int TGSctpSendText(TGSctp *sctp, const char *text, size_t length, double now);

/// Resends what is unacknowledged for a second. Call about every 500 ms.
void TGSctpTick(TGSctp *sctp, double now);

/// CRC32C of the packet with its checksum field taken as zero. The packet
/// stores it least significant byte first.
uint32_t TGSctpChecksum(const uint8_t *packet, size_t length);

#ifdef __cplusplus
}
#endif

#endif
