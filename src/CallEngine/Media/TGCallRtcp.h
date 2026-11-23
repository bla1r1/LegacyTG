//
// TGCallRtcp - the RTCP a 9.0.0 call needs from us: receiver reports so the
// peer's loss-based rate control sees what arrives, PLI when our decoder has
// lost the picture, and spotting the peer's PLI/FIR for our own stream.
//
#ifndef TG_CALL_RTCP_H
#define TG_CALL_RTCP_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
	uint32_t ssrc;
	int      started;
	uint16_t maxSeq;
	uint32_t cycles;
	uint32_t baseSeq;
	uint32_t received;
	uint32_t expectedPrior;
	uint32_t receivedPrior;
} TGRtpStats;

/// Counts one packet. Returns 1 when it skipped ahead of the next expected
/// sequence number, which for video means a picture is broken.
int TGRtpStatsUpdate(TGRtpStats *stats, uint32_t ssrc, uint16_t seq);

/// RR with one report block per started stats entry. Returns bytes written.
size_t TGRtcpWriteReceiverReport(uint8_t *out, size_t capacity, uint32_t senderSsrc,
                                 TGRtpStats *stats, int count);

/// Picture Loss Indication (RFC 4585 PSFB FMT 1) for mediaSsrc.
size_t TGRtcpWritePli(uint8_t *out, size_t capacity, uint32_t senderSsrc, uint32_t mediaSsrc);

/// 1 when a compound RTCP packet holds a PLI or FIR aimed at mediaSsrc.
int TGRtcpAsksForKeyframe(const uint8_t *packet, size_t length, uint32_t mediaSsrc);

/// The peer's report on our stream `ssrc`, from an SR or RR. 1 when found.
int TGRtcpLossFor(const uint8_t *packet, size_t length, uint32_t ssrc,
                  uint8_t *fraction, uint32_t *cumulative);

/// REMB (draft-alvestrand-rmcat-remb): the most the peer may send on
/// mediaSsrc. WebRTC's sender takes it as a ceiling on its estimate and
/// scales the picture down to fit.
size_t TGRtcpWriteRemb(uint8_t *out, size_t capacity, uint32_t senderSsrc, uint32_t mediaSsrc,
                       uint32_t bitsPerSecond);

/// The next send rate after a report: the loss-based rule WebRTC uses with no
/// delay estimate. Under 2% lost (fraction < 5/256) it grows 8%, over 10%
/// (26/256) it drops by half the loss, in between it holds.
int TGRateAfterLoss(int kbps, int minKbps, int maxKbps, uint8_t fraction);

/// The sequence numbers a generic NACK asks to be sent again for mediaSsrc.
/// Returns how many were written to `out`, at most `max`.
int TGRtcpNackedSequences(const uint8_t *packet, size_t length, uint32_t mediaSsrc,
                          uint16_t *out, int max);

/// Generic NACK for `count` packets from `first` of mediaSsrc.
size_t TGRtcpWriteNack(uint8_t *out, size_t capacity, uint32_t senderSsrc,
                       uint32_t mediaSsrc, uint16_t first, uint16_t count);

#ifdef __cplusplus
}
#endif

#endif
