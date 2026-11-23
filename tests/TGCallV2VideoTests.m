// TGCallV2VideoTests.m — what a 9.0.0 video call adds: H.264 channel
// negotiation, the SCTP data channel for MediaState, RTCP and SRTCP.
//
// scripts/call_bench.sh with CALL_BENCH_VIDEO=1 runs the same code against
// the real tgcalls; these pin the pieces that bench found wrong.
#import <openssl/hmac.h>
#import "TGTestRunner.h"
#import "TGCallMessages.h"
#import "TGCallRtcp.h"
#import "TGCallSctp.h"
#import "TGCallSrtp.h"
#import "TGCallV2Session.h"
#import "TGCallV2Signaling.h"
#import "TGCallVideoReorder.h"
#import "TGCallJitter.h"
#import "TGCallExpand.h"
#import "TGCallH264Config.h"
#import <VideoToolbox/VideoToolbox.h>
#import "TGCallVP8Codec.h"
#import "TGCallVP8Rtp.h"

static uint32_t v2vRead32(const uint8_t *b) {
    return ((uint32_t)b[0] << 24) | ((uint32_t)b[1] << 16) | ((uint32_t)b[2] << 8) | b[3];
}

static void v2vWrite32(uint8_t *b, uint32_t v) {
    b[0] = (uint8_t)(v >> 24); b[1] = (uint8_t)(v >> 16); b[2] = (uint8_t)(v >> 8); b[3] = (uint8_t)v;
}

static NSDictionary *v2vJson(NSData *message) {
    const uint8_t *bytes = message.bytes;
    if (message.length < 5 || bytes[0] != 0x7F)
        return nil;
    NSData *payload = [message subdataWithRange:NSMakeRange(5, v2vRead32(bytes + 1))];
    return [NSJSONSerialization JSONObjectWithData:payload options:0 error:nil];
}

#pragma mark - SCTP harness

typedef struct {
    uint8_t packets[8][TGSctpMaxPacket];
    size_t lengths[8];
    int count;
    char messages[4][256];
    int messageCount;
    int opened;
} TGSctpCapture;

static void captureSend(void *context, const uint8_t *packet, size_t length) {
    TGSctpCapture *capture = context;
    if (capture->count < 8){
        memcpy(capture->packets[capture->count], packet, length);
        capture->lengths[capture->count++] = length;
    }
}

static void captureMessage(void *context, const uint8_t *text, size_t length) {
    TGSctpCapture *capture = context;
    if (capture->messageCount < 4 && length < 256){
        memcpy(capture->messages[capture->messageCount], text, length);
        capture->messages[capture->messageCount++][length] = 0;
    }
}

static void captureOpen(void *context) {
    ((TGSctpCapture *)context)->opened++;
}

/// One packet from the peer: header, the chunks given, checksum.
static size_t buildPacket(uint8_t *out, uint32_t tag, const uint8_t *chunks, size_t length) {
    out[0] = 0x13; out[1] = 0x88; out[2] = 0x13; out[3] = 0x88;
    v2vWrite32(out + 4, tag);
    memcpy(out + 12, chunks, length);
    uint32_t crc = TGSctpChecksum(out, 12 + length);
    out[8] = (uint8_t)crc; out[9] = (uint8_t)(crc >> 8);
    out[10] = (uint8_t)(crc >> 16); out[11] = (uint8_t)(crc >> 24);
    return 12 + length;
}

static size_t dataChunk(uint8_t *out, uint32_t tsn, uint16_t ssn, uint32_t ppid,
                        const void *data, size_t length) {
    out[0] = 0; out[1] = 0x03;
    uint16_t chunkLength = (uint16_t)(16 + length);
    out[2] = (uint8_t)(chunkLength >> 8); out[3] = (uint8_t)chunkLength;
    v2vWrite32(out + 4, tsn);
    out[8] = 0; out[9] = 0;
    out[10] = (uint8_t)(ssn >> 8); out[11] = (uint8_t)ssn;
    v2vWrite32(out + 12, ppid);
    memcpy(out + 16, data, length);
    size_t padded = (chunkLength + 3) & ~(size_t)3;
    memset(out + chunkLength, 0, padded - chunkLength);
    return padded;
}

@interface TGCallV2VideoTests : XCTestCase
@end

@implementation TGCallV2VideoTests {
    TGSctp _sctp;
    TGSctpCapture _capture;
    uint8_t _cookie[16];
    size_t _cookieLength;
}

- (void)setUpSctpAsOpener:(BOOL)opener {
    memset(&_capture, 0, sizeof(_capture));
    memset(&_sctp, 0, sizeof(_sctp));
    _sctp.context = &_capture;
    _sctp.send = captureSend;
    _sctp.onMessage = captureMessage;
    _sctp.onOpen = captureOpen;
    TGSctpInit(&_sctp, opener, 0xAABBCCDD, 5000);

    // The peer's INIT: tag 0x11111111, TSN 100.
    uint8_t chunk[20] = { 1, 0, 0, 20 };
    v2vWrite32(chunk + 4, 0x11111111);
    v2vWrite32(chunk + 8, 131072);
    chunk[12] = 0; chunk[13] = 16; chunk[14] = 0; chunk[15] = 16;
    v2vWrite32(chunk + 16, 100);
    uint8_t packet[64];
    size_t length = buildPacket(packet, 0, chunk, sizeof(chunk));
    TGSctpReceive(&_sctp, packet, length, 1.0);

    XCTAssertEqual(_capture.count, 1, @"INIT gets one INIT ACK");
    const uint8_t *ack = _capture.packets[0];
    XCTAssertEqual(v2vRead32(ack + 4), 0x11111111u, @"INIT ACK carries the peer's tag");
    XCTAssertEqual(ack[12], 2);
    XCTAssertEqual(v2vRead32(ack + 16), 0xAABBCCDDu, @"our initiate tag");
    XCTAssertEqual(v2vRead32(ack + 28), 5000u, @"our initial TSN");
    // State cookie parameter follows the fixed part.
    XCTAssertEqual((ack[32] << 8) | ack[33], 7);
    _cookieLength = (size_t)((ack[34] << 8) | ack[35]) - 4;
    memcpy(_cookie, ack + 36, _cookieLength);
    _capture.count = 0;
}

- (size_t)cookieEcho:(uint8_t *)out {
    out[0] = 10; out[1] = 0;
    out[2] = 0; out[3] = (uint8_t)(4 + _cookieLength);
    memcpy(out + 4, _cookie, _cookieLength);
    return (4 + _cookieLength + 3) & ~(size_t)3;
}

- (void)testSctpChecksumIsCrc32c {
    // RFC 3720 B.4: 32 bytes of zeros.
    uint8_t zeros[32] = {0};
    XCTAssertEqual(TGSctpChecksum(zeros, sizeof(zeros)), 0x8A9136AAu);
}

- (void)testSctpOpenerSendsDcepOpenAfterCookieAck {
    [self setUpSctpAsOpener:YES];
    uint8_t chunks[64], packet[128];
    size_t length = buildPacket(packet, 0xAABBCCDD, chunks, [self cookieEcho:chunks]);
    TGSctpReceive(&_sctp, packet, length, 2.0);

    XCTAssertEqual(_capture.count, 2, @"COOKIE ACK, then the DCEP open");
    XCTAssertEqual(_capture.packets[0][12], 11, @"COOKIE ACK first");
    const uint8_t *open = _capture.packets[1];
    XCTAssertEqual(open[12], 0, @"DATA");
    XCTAssertEqual(v2vRead32(open + 16), 5000u, @"first TSN");
    XCTAssertEqual(v2vRead32(open + 24), 50u, @"PPID 50: DCEP");
    XCTAssertEqual(open[28], 0x03, @"DATA_CHANNEL_OPEN");
    XCTAssertTrue(memcmp(open + 40, "data", 4) == 0, @"label tgcalls opens");
    XCTAssertEqual(_capture.opened, 1);
}

- (void)testSctpAckerAnswersOpenAfterCookieAckAndDeliversText {
    [self setUpSctpAsOpener:NO];
    uint8_t chunks[256], packet[300];
    size_t at = [self cookieEcho:chunks];
    // dcsctp bundles the first DATA with the COOKIE ECHO.
    uint8_t open[] = { 0x03, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 'd', 'a', 't', 'a' };
    at += dataChunk(chunks + at, 100, 0, 50, open, sizeof(open));
    size_t length = buildPacket(packet, 0xAABBCCDD, chunks, at);
    TGSctpReceive(&_sctp, packet, length, 2.0);

    XCTAssertEqual(_capture.count, 2);
    XCTAssertEqual(_capture.packets[0][12], 11, @"COOKIE ACK before any DATA of ours");
    XCTAssertEqual(_capture.packets[0][16], 3, @"SACK bundled with it");
    XCTAssertEqual(v2vRead32(_capture.packets[0] + 20), 100u, @"cumulative TSN");
    XCTAssertEqual(_capture.packets[1][28], 0x02, @"DATA_CHANNEL_ACK");
    XCTAssertEqual(_capture.opened, 1);

    const char *text = "{\"@type\":\"MediaState\"}";
    at = dataChunk(chunks, 101, 1, 51, text, strlen(text));
    length = buildPacket(packet, 0xAABBCCDD, chunks, at);
    TGSctpReceive(&_sctp, packet, length, 3.0);
    TGSctpReceive(&_sctp, packet, length, 3.1);   // the peer resends it
    XCTAssertEqual(_capture.messageCount, 1, @"a repeated TSN is not delivered twice");
    XCTAssertEqual(strcmp(_capture.messages[0], text), 0);
}

- (void)testSctpResendsUntilSacked {
    [self setUpSctpAsOpener:YES];
    uint8_t chunks[64], packet[128];
    size_t length = buildPacket(packet, 0xAABBCCDD, chunks, [self cookieEcho:chunks]);
    TGSctpReceive(&_sctp, packet, length, 2.0);
    _capture.count = 0;

    XCTAssertEqual(TGSctpSendText(&_sctp, "x", 1, 2.0), 0);
    XCTAssertEqual(_capture.count, 1);
    TGSctpTick(&_sctp, 2.5);
    XCTAssertEqual(_capture.count, 1, @"not yet");
    TGSctpTick(&_sctp, 3.1);
    XCTAssertEqual(_capture.count, 3, @"the open and the text both go again");

    // SACK covering both TSNs (5000 open, 5001 text).
    uint8_t sack[16] = { 3, 0, 0, 16 };
    v2vWrite32(sack + 4, 5001);
    v2vWrite32(sack + 8, 131072);
    length = buildPacket(packet, 0xAABBCCDD, sack, sizeof(sack));
    TGSctpReceive(&_sctp, packet, length, 3.2);
    _capture.count = 0;
    TGSctpTick(&_sctp, 9.0);
    XCTAssertEqual(_capture.count, 0, @"nothing left to resend");
}

- (void)testSctpAnswersHeartbeatAndDropsBadChecksum {
    [self setUpSctpAsOpener:NO];
    uint8_t chunks[64], packet[128];
    size_t length = buildPacket(packet, 0xAABBCCDD, chunks, [self cookieEcho:chunks]);
    TGSctpReceive(&_sctp, packet, length, 2.0);
    _capture.count = 0;

    uint8_t heartbeat[12] = { 4, 0, 0, 12, 0, 1, 0, 8, 0xDE, 0xAD, 0xBE, 0xEF };
    length = buildPacket(packet, 0xAABBCCDD, heartbeat, sizeof(heartbeat));
    packet[13] ^= 0;   // untouched copy first
    TGSctpReceive(&_sctp, packet, length, 3.0);
    XCTAssertEqual(_capture.count, 1);
    XCTAssertEqual(_capture.packets[0][12], 5, @"HEARTBEAT ACK");
    XCTAssertTrue(memcmp(_capture.packets[0] + 16, heartbeat + 4, 8) == 0, @"echoes the info");

    packet[20] ^= 0xFF;
    TGSctpReceive(&_sctp, packet, length, 3.1);
    XCTAssertEqual(_capture.count, 1, @"a corrupted packet gets no answer");
}

#pragma mark - RTCP

- (void)testReceiverReportCountsLoss {
    TGRtpStats stats[2] = {{0}};
    XCTAssertEqual(TGRtpStatsUpdate(&stats[1], 77, 10), 0);
    XCTAssertEqual(TGRtpStatsUpdate(&stats[1], 77, 11), 0);
    XCTAssertEqual(TGRtpStatsUpdate(&stats[1], 77, 14), 1, @"12 and 13 skipped");
    uint8_t out[128];
    size_t length = TGRtcpWriteReceiverReport(out, sizeof(out), 5, stats, 2);
    XCTAssertEqual((int)length, 8 + 24, @"one block: only started streams report");
    XCTAssertEqual(out[0], 0x81);
    XCTAssertEqual(out[1], 201);
    XCTAssertEqual(v2vRead32(out + 8), 77u);
    XCTAssertEqual(out[13] << 16 | out[14] << 8 | out[15], 2, @"cumulative lost");
    XCTAssertEqual(v2vRead32(out + 16), 14u, @"highest sequence");

    uint8_t fraction = 0;
    uint32_t lost = 0;
    XCTAssertEqual(TGRtcpLossFor(out, length, 77, &fraction, &lost), 1);
    XCTAssertEqual(lost, 2u);
    XCTAssertEqual(fraction, (uint8_t)(2 * 256 / 5));
}

- (void)testSequenceWrapIsNotLoss {
    TGRtpStats stats = {0};
    TGRtpStatsUpdate(&stats, 1, 65534);
    TGRtpStatsUpdate(&stats, 1, 65535);
    XCTAssertEqual(TGRtpStatsUpdate(&stats, 1, 0), 0);
    XCTAssertEqual(stats.cycles, 0x10000u);
}

- (void)testPliAndFirAreSpottedForOurStreamOnly {
    uint8_t out[64];
    size_t length = TGRtcpWritePli(out, sizeof(out), 1, 0xCAFE);
    XCTAssertEqual((int)length, 12);
    XCTAssertEqual(TGRtcpAsksForKeyframe(out, length, 0xCAFE), 1);
    XCTAssertEqual(TGRtcpAsksForKeyframe(out, length, 0xBEEF), 0);

    // An RR then a FIR naming 0xCAFE in its FCI, the way WebRTC sends one.
    TGRtpStats none = {0};
    size_t at = TGRtcpWriteReceiverReport(out, sizeof(out), 1, &none, 1);
    uint8_t fir[20] = { 0x84, 206, 0, 4, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0xCA, 0xFE, 7, 0, 0, 0 };
    memcpy(out + at, fir, sizeof(fir));
    XCTAssertEqual(TGRtcpAsksForKeyframe(out, at + sizeof(fir), 0xCAFE), 1);
}

- (void)testNackRoundTripsThroughWriterAndParser {
    uint8_t out[64];
    size_t length = TGRtcpWriteNack(out, sizeof(out), 1, 0xCAFE, 65530, 20);
    XCTAssertEqual((int)length, 12 + 8, @"17 per FCI entry: two entries");
    uint16_t seqs[32];
    int count = TGRtcpNackedSequences(out, length, 0xCAFE, seqs, 32);
    XCTAssertEqual(count, 20);
    XCTAssertEqual(seqs[0], 65530);
    XCTAssertEqual(seqs[5], 65535);
    XCTAssertEqual(seqs[6], 0, @"across the wrap");
    XCTAssertEqual(seqs[19], 13);
    XCTAssertEqual(TGRtcpNackedSequences(out, length, 0xBEEF, seqs, 32), 0);
}

#pragma mark - Reorder

typedef struct {
    int delivered[64];
    int count;
    int losses;
} TGReorderLog;

static void reorderDeliver(void *context, const uint8_t *rtp, size_t length) {
    TGReorderLog *log = context;
    if (!rtp){
        log->losses++;
        return;
    }
    log->delivered[log->count++] = (rtp[2] << 8) | rtp[3];
}

static TGVideoReorderResult reorderPush(TGVideoReorder *r, TGReorderLog *log, uint16_t seq,
                                        double now, uint16_t *from, uint16_t *count) {
    uint8_t rtp[16] = { 0x80, 102, (uint8_t)(seq >> 8), (uint8_t)seq };
    return TGVideoReorderPush(r, rtp, sizeof(rtp), now, 0.3, reorderDeliver, log, from, count);
}

- (void)testReorderWaitsForTheNackedPacket {
    TGVideoReorder *r = calloc(1, sizeof(TGVideoReorder));
    TGReorderLog log = {{0}};
    uint16_t from = 0, count = 0;
    XCTAssertEqual(reorderPush(r, &log, 10, 0.0, &from, &count), TGVideoReorderNothing);
    XCTAssertEqual(reorderPush(r, &log, 13, 0.1, &from, &count), TGVideoReorderAskAgain);
    XCTAssertEqual(from, 11);
    XCTAssertEqual(count, 2);
    XCTAssertEqual(log.count, 1, @"13 is held behind the hole");
    reorderPush(r, &log, 12, 0.15, &from, &count);
    reorderPush(r, &log, 11, 0.2, &from, &count);   // the retransmission
    XCTAssertEqual(log.count, 4);
    XCTAssertEqual(log.delivered[1], 11);
    XCTAssertEqual(log.delivered[3], 13);
    XCTAssertEqual(log.losses, 0);
    free(r);
}

- (void)testReorderGivesUpAfterItsPatience {
    TGVideoReorder *r = calloc(1, sizeof(TGVideoReorder));
    TGReorderLog log = {{0}};
    uint16_t from = 0, count = 0;
    reorderPush(r, &log, 65534, 0.0, &from, &count);
    reorderPush(r, &log, 1, 0.1, &from, &count);    // 65535 and 0 lost
    XCTAssertEqual(reorderPush(r, &log, 2, 0.5, &from, &count), TGVideoReorderGaveUp);
    XCTAssertEqual(log.losses, 1, @"the receiver hears of the break before the rest");
    XCTAssertEqual(log.count, 3);
    XCTAssertEqual(log.delivered[1], 1);
    XCTAssertEqual(log.delivered[2], 2);
    reorderPush(r, &log, 0, 0.6, &from, &count);    // too late now
    XCTAssertEqual(log.count, 3);
    reorderPush(r, &log, 3, 0.7, &from, &count);
    XCTAssertEqual(log.count, 4, @"in order again");
    free(r);
}

- (void)testSrtpTakesALatePacketFromBeforeTheWrap {
    uint8_t key[16] = {1}, salt[14] = {2};
    TGSrtpContext sender, receiver;
    TGSrtpContextInit(&sender, key, salt);
    TGSrtpContextInit(&receiver, key, salt);
    uint8_t packets[4][64];
    size_t lengths[4];
    uint16_t seqs[4] = { 65534, 65535, 0, 1 };
    for (int i = 0; i < 4; i++){
        uint8_t *p = packets[i];
        memset(p, 0, 64);
        p[0] = 0x80; p[1] = 102; p[2] = (uint8_t)(seqs[i] >> 8); p[3] = (uint8_t)seqs[i];
        p[11] = 7;
        XCTAssertEqual(TGSrtpProtect(&sender, p, 20, 64, &lengths[i]), 0);
    }
    size_t plain = 0;
    XCTAssertEqual(TGSrtpUnprotect(&receiver, packets[0], lengths[0], &plain), 0);
    XCTAssertEqual(TGSrtpUnprotect(&receiver, packets[2], lengths[2], &plain), 0);
    XCTAssertEqual(TGSrtpUnprotect(&receiver, packets[3], lengths[3], &plain), 0);
    // 65535 comes back late, after the wrap: it belongs to the old ROC.
    XCTAssertEqual(TGSrtpUnprotect(&receiver, packets[1], lengths[1], &plain), 0);
    XCTAssertEqual(receiver.highestSeq, 1, @"a late packet does not pull the counter back");
}

#pragma mark - VP8

/// Encode a few pictures, cut them into RTP, join them back and decode: what
/// a VP8 call does on both phones, without the network.
- (void)testVP8RoundTripsThroughRtp {
    const int w = 288, h = 352;
    TGVP8Encoder *encoder = TGVP8EncoderOpen(w, h, 15, 250);
    XCTAssertTrue(encoder != NULL);
    TGVP8Decoder *decoder = TGVP8DecoderOpen(720 * 1280);
    uint8_t *luma = malloc(w * h), *chroma = malloc(w * h / 2);
    uint8_t *encoded = malloc(128 * 1024), *payloads = malloc(64 * 1100), *storage = malloc(512 * 1024);
    TGVP8Depacketizer depacketizer;
    TGVP8DepacketizerInit(&depacketizer, storage, 512 * 1024);
    uint16_t seq = 100;
    int decoded = 0, keyframes = 0;
    for (int frame = 0; frame < 10; frame++){
        for (int y = 0; y < h; y++)
            memset(luma + y * w, (y + frame * 8) & 0xFF, w);
        memset(chroma, 128, w * h / 2);
        int key = 0;
        size_t length = TGVP8EncodeNV12(encoder, luma, w, chroma, w, frame * 6000, frame == 0,
                                        encoded, 128 * 1024, &key);
        XCTAssertTrue(length > 0);
        keyframes += key;
        size_t lengths[64];
        int count = TGVP8Packetize(encoded, length, (uint16_t)frame, payloads, 1100, lengths, 64);
        XCTAssertTrue(count > 0);
        for (int i = 0; i < count; i++){
            uint8_t rtp[12 + 1100] = { 0x80, (uint8_t)((i == count - 1 ? 0x80 : 0) | 100),
                                       (uint8_t)(seq >> 8), (uint8_t)seq, 0, 0, 0, (uint8_t)frame };
            seq++;
            memcpy(rtp + 12, payloads + i * 1100, lengths[i]);
            int isKey = 0;
            if (TGVP8DepacketizerPush(&depacketizer, rtp, 12 + lengths[i], &isKey)){
                TGVP8Image image;
                XCTAssertEqual(TGVP8Decode(decoder, depacketizer.frame, depacketizer.length, &image), 1);
                XCTAssertEqual(image.width, w);
                XCTAssertEqual(image.height, h);
                decoded++;
            }
        }
    }
    XCTAssertEqual(decoded, 10);
    XCTAssertTrue(keyframes >= 1);
    TGVP8EncoderClose(encoder);
    TGVP8DecoderClose(decoder);
    free(luma); free(chroma); free(encoded); free(payloads); free(storage);
}

- (void)testVP8DescriptorAndKeyframeWait {
    // WebRTC's descriptor: X, I with a 15-bit picture id, S on the first.
    uint8_t payload[] = { 0x90, 0x80, 0x81, 0x23, 0x01, 0x02 };
    XCTAssertEqual((int)TGVP8DescriptorSize(payload, sizeof(payload)), 4);
    uint8_t shortId[] = { 0x90, 0x80, 0x23, 0xAA };
    XCTAssertEqual((int)TGVP8DescriptorSize(shortId, sizeof(shortId)), 3);
    uint8_t bare[] = { 0x10, 0xAA };
    XCTAssertEqual((int)TGVP8DescriptorSize(bare, sizeof(bare)), 1);

    uint8_t storage[256];
    TGVP8Depacketizer d;
    TGVP8DepacketizerInit(&d, storage, sizeof(storage));
    // An inter frame (P bit set) before any keyframe is held back.
    uint8_t inter[] = { 0x80, 0x80 | 100, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0x10, 0x01, 0x00, 0x00 };
    XCTAssertEqual(TGVP8DepacketizerPush(&d, inter, sizeof(inter), NULL), 0);
    uint8_t key[] = { 0x80, 0x80 | 100, 0, 2, 0, 0, 0, 2, 0, 0, 0, 1, 0x10, 0x00, 0x00, 0x00 };
    int isKey = 0;
    XCTAssertEqual(TGVP8DepacketizerPush(&d, key, sizeof(key), &isKey), 1);
    XCTAssertEqual(isKey, 1);
    inter[7] = 3;
    XCTAssertEqual(TGVP8DepacketizerPush(&d, inter, sizeof(inter), NULL), 1, @"after a keyframe it goes through");
}

#pragma mark - SRTCP

- (void)testSrtcpTagCoversPacketAndIndexWithNoRoc {
    uint8_t key[16], salt[14];
    for (int i = 0; i < 16; i++) key[i] = (uint8_t)i;
    for (int i = 0; i < 14; i++) salt[i] = (uint8_t)(0x40 + i);
    TGSrtpContext sender, receiver, srtp;
    TGSrtcpContextInit(&sender, key, salt);
    TGSrtcpContextInit(&receiver, key, salt);
    TGSrtpContextInit(&srtp, key, salt);
    XCTAssertTrue(memcmp(sender.authKey, srtp.authKey, sizeof(srtp.authKey)) != 0,
                  @"SRTCP keys come from labels 3-5, not SRTP's 0-2");

    uint8_t packet[64] = { 0x80, 201, 0, 1, 0, 0, 0, 5 };
    size_t protectedLength = 0;
    XCTAssertEqual(TGSrtcpProtect(&sender, packet, 8, sizeof(packet), 9, &protectedLength), 0);
    XCTAssertEqual((int)protectedLength, 8 + 4 + 10);

    // RFC 3711 3.4: HMAC over the packet and E||index, nothing appended.
    uint8_t digest[20];
    unsigned int digestLength = 0;
    HMAC(EVP_sha1(), sender.authKey, sizeof(sender.authKey), packet, 12, digest, &digestLength);
    XCTAssertTrue(memcmp(digest, packet + 12, 10) == 0, @"tag libsrtp accepts");

    size_t plainLength = 0;
    XCTAssertEqual(TGSrtcpUnprotect(&receiver, packet, protectedLength, &plainLength), 0);
    XCTAssertEqual((int)plainLength, 8);
    XCTAssertEqual(packet[1], 201);
}

#pragma mark - Negotiation

- (void)testOurVideoOfferNamesItsSsrcInAnFidGroup {
    NSDictionary *content = [TGCallV2Signaling videoContentWithSsrc:1234];
    XCTAssertEqualObjects(content[@"type"], @"video");
    XCTAssertEqualObjects(content[@"ssrc"], @"1234");
    // tgcalls builds the video receive stream from the groups alone.
    NSArray *groups = content[@"ssrcGroups"];
    XCTAssertEqual((int)groups.count, 1);
    XCTAssertEqualObjects(groups[0][@"semantics"], @"FID");
    XCTAssertEqualObjects(groups[0][@"ssrcs"][0], @"1234");
    NSDictionary *payload = content[@"payloadTypes"][0];
    XCTAssertEqualObjects(payload[@"name"], @"H264");
    XCTAssertEqualObjects(payload[@"parameters"][@"packetization-mode"], @"1");
    XCTAssertEqualObjects(payload[@"parameters"][@"profile-level-id"], @"42e01f");
}

- (void)testAnswerTakesConstrainedBaselineFromTheOfferedList {
    NSDictionary *offered = @{
        @"type" : @"video", @"ssrc" : @"99",
        @"ssrcGroups" : @[@{ @"semantics" : @"FID", @"ssrcs" : @[@"99", @"100"] }],
        @"payloadTypes" : @[
            @{ @"id" : @96, @"name" : @"VP8" },
            @{ @"id" : @97, @"name" : @"H264", @"parameters" : @{ @"packetization-mode" : @"1", @"profile-level-id" : @"640c1f" } },
            @{ @"id" : @98, @"name" : @"H264", @"parameters" : @{ @"packetization-mode" : @"0", @"profile-level-id" : @"42e01f" } },
            @{ @"id" : @102, @"name" : @"H264", @"parameters" : @{ @"packetization-mode" : @"1", @"profile-level-id" : @"42001f" } },
            @{ @"id" : @104, @"name" : @"H264", @"parameters" : @{ @"packetization-mode" : @"1", @"profile-level-id" : @"42e01f" } },
        ],
    };
    NSDictionary *answer = [TGCallV2Signaling answerContentFor:offered acceptVideo:YES];
    XCTAssertEqualObjects(answer[@"ssrc"], @"99");
    XCTAssertEqualObjects(answer[@"ssrcGroups"], offered[@"ssrcGroups"]);
    NSArray *payloads = answer[@"payloadTypes"];
    XCTAssertEqual((int)payloads.count, 1);
    XCTAssertEqual([payloads[0][@"id"] intValue], 104);

    XCTAssertNil([TGCallV2Signaling answerContentFor:offered acceptVideo:NO],
                 @"a device without video takes no video channel");
    // VP8 is the fallback: taken when no baseline H.264 is offered, and the
    // only choice on a device without VideoToolbox.
    NSDictionary *vp8Only = @{ @"type" : @"video", @"ssrc" : @"5",
                               @"payloadTypes" : @[@{ @"id" : @96, @"name" : @"VP8" }] };
    XCTAssertEqual([[[TGCallV2Signaling answerContentFor:vp8Only acceptVideo:YES][@"payloadTypes"] firstObject][@"id"] intValue], 96);
    NSDictionary *noVideoToolbox = [TGCallV2Signaling answerContentFor:offered acceptVideo:YES preferH264:NO];
    XCTAssertEqualObjects([noVideoToolbox[@"payloadTypes"] firstObject][@"name"], @"VP8");
    XCTAssertEqual([[noVideoToolbox[@"payloadTypes"] firstObject][@"id"] intValue], 96);
    NSDictionary *h264Only = @{ @"type" : @"video", @"ssrc" : @"6",
                                @"payloadTypes" : @[offered[@"payloadTypes"][4]] };
    XCTAssertNil([TGCallV2Signaling answerContentFor:h264Only acceptVideo:YES preferH264:NO],
                 @"no H.264 without VideoToolbox");
}

- (void)testOfferWithoutVideoToolboxIsVP8Only {
    NSArray *withH264 = [TGCallV2Signaling videoContentWithSsrc:9 h264:YES][@"payloadTypes"];
    XCTAssertEqualObjects(withH264[0][@"name"], @"H264");
    XCTAssertEqualObjects(withH264[1][@"name"], @"VP8");
    NSArray *vp8 = [TGCallV2Signaling videoContentWithSsrc:9 h264:NO][@"payloadTypes"];
    XCTAssertEqual((int)vp8.count, 1);
    XCTAssertEqualObjects(vp8[0][@"name"], @"VP8");
    XCTAssertEqual([vp8[0][@"id"] intValue], TGV2VP8PayloadType);
}

- (void)testAudioAnswerKeepsThePeersOpusId {
    NSDictionary *offered = @{ @"type" : @"audio", @"ssrc" : @"42",
                               @"payloadTypes" : @[@{ @"id" : @114, @"name" : @"opus" }] };
    NSDictionary *answer = [TGCallV2Signaling answerContentFor:offered acceptVideo:YES];
    XCTAssertEqualObjects(answer[@"ssrc"], @"42");
    XCTAssertEqual([answer[@"payloadTypes"][0][@"id"] intValue], 114);
}

- (void)testMediaStateIsWhatTgcallsParses {
    NSString *text = [TGCallV2Signaling mediaStateWithMuted:YES videoActive:YES];
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:[text dataUsingEncoding:NSUTF8StringEncoding]
                                                         options:0 error:nil];
    XCTAssertEqualObjects(json[@"@type"], @"MediaState");
    XCTAssertEqualObjects(json[@"muted"], @YES);
    XCTAssertEqualObjects(json[@"videoState"], @"active");
    XCTAssertEqualObjects(json[@"screencastState"], @"inactive");
    XCTAssertEqualObjects(json[@"videoRotation"], @0);
}

/// Signalling is resent until acked and bundled with what follows, so the
/// same offer and our own answer's echo arrive more than once. The bench
/// caught one answer per copy, each taken by the peer as a new offer.
- (void)testRepeatedOfferIsAnsweredOnce {
    TGCallV2Session *session = [[TGCallV2Session alloc] init];
    session.outgoing = NO;
    session.localUfrag = @"ufrg";
    session.localPwd = @"passwordpasswordpassword";
    session.localSsrc = 11;
    session.localVideoSsrc = 21;
    session.videoCapable = YES;
    NSMutableArray *sent = [NSMutableArray array];
    session.sendSignaling = ^(NSData *plaintext, uint32_t seq){
        NSDictionary *json = v2vJson(plaintext);
        if (json)
            [sent addObject:json];
    };
    [session start];

    NSData *offer = [TGCallV2Signaling negotiateWithExchangeId:@"777" contents:@[
        [TGCallV2Signaling audioContentWithSsrc:31],
        [TGCallV2Signaling videoContentWithSsrc:41],
    ]];
    [session handlePlaintext:offer packetSeq:[TGCallMessages markSeq:1 requiresAck:YES]];
    [session handlePlaintext:offer packetSeq:[TGCallMessages markSeq:1 requiresAck:YES]];

    XCTAssertEqual((int)sent.count, 2, @"one answer, then our own offer");
    NSDictionary *answer = sent[0];
    XCTAssertEqualObjects(answer[@"exchangeId"], @"777");
    XCTAssertEqual((int)[answer[@"contents"] count], 2, @"audio and video taken");
    NSDictionary *ours = sent[1];
    XCTAssertFalse([ours[@"exchangeId"] isEqual:@"777"]);
    XCTAssertEqual((int)[ours[@"contents"] count], 2, @"we offer audio and video");

    // The peer's answer to ours, delivered twice, starts nothing new.
    NSData *reply = [TGCallV2Signaling negotiateWithExchangeId:ours[@"exchangeId"] contents:@[
        [TGCallV2Signaling audioContentWithSsrc:11],
        [TGCallV2Signaling videoContentWithSsrc:21],
    ]];
    [session handlePlaintext:reply packetSeq:[TGCallMessages markSeq:2 requiresAck:YES]];
    [session handlePlaintext:reply packetSeq:[TGCallMessages markSeq:2 requiresAck:YES]];
    XCTAssertEqual((int)sent.count, 2);
    [session stop];
}


- (void)testReorderGivesASecondHoleItsOwnWait {
    // The clock used to start at the first hole and run on while a later one
    // was open, so the later hole was given up before its resend could come.
    TGVideoReorder *r = calloc(1, sizeof(TGVideoReorder));
    TGReorderLog log = {{0}};
    uint16_t from = 0, count = 0;
    reorderPush(r, &log, 10, 0.0, &from, &count);
    reorderPush(r, &log, 12, 0.01, &from, &count);   // 11 missing
    reorderPush(r, &log, 14, 0.25, &from, &count);   // 13 missing
    reorderPush(r, &log, 11, 0.28, &from, &count);   // 11 resent: 11, 12 out
    XCTAssertEqual(log.count, 3);
    XCTAssertEqual(reorderPush(r, &log, 15, 0.5, &from, &count), TGVideoReorderNothing,
                   @"13 has waited 0.22 s of its 0.3");
    XCTAssertEqual(log.losses, 0);
    XCTAssertTrue(TGVideoReorderMissing(r, &from, &count));
    XCTAssertEqual(from, 13, @"asked again for what playout is stuck behind");
    XCTAssertEqual(count, 1);
    free(r);
}

- (void)testSendRateFollowsReportedLoss {
    XCTAssertEqual(TGRateAfterLoss(300, 80, 350, 0), 325, @"under 2%: grow 8%");
    XCTAssertEqual(TGRateAfterLoss(340, 80, 350, 0), 350, @"never past the ceiling");
    XCTAssertEqual(TGRateAfterLoss(300, 80, 350, 20), 300, @"2-10%: hold");
    XCTAssertEqual(TGRateAfterLoss(300, 80, 350, 64), 262, @"25% lost: down 12.5%");
    XCTAssertEqual(TGRateAfterLoss(90, 80, 350, 255), 80, @"never under the floor");
}

#pragma mark - Playout buffer

static void jitterPut(TGJitter *j, uint16_t seq, int64_t ms) {
    uint8_t payload[2] = { (uint8_t)seq, 0xAA };
    TGJitterPut(j, seq, (uint32_t)seq * 960, 960, payload, sizeof(payload), ms);
}

- (void)testJitterFillsThenPlaysInOrder {
    TGJitter *j = TGJitterCreate();
    static TGJitterOut out;
    jitterPut(j, 100, 0);
    TGJitterPull(j, &out);
    XCTAssertEqual(out.action, TGJitterSilence, @"60 ms target, 20 ms in");
    jitterPut(j, 101, 20);
    jitterPut(j, 102, 40);
    for (int seq = 100; seq <= 102; seq++){
        TGJitterPull(j, &out);
        XCTAssertEqual(out.action, TGJitterPlay);
        XCTAssertEqual(out.payload[0], (uint8_t)seq);
        XCTAssertEqual(out.samples, 960);
    }
    TGJitterFree(j);
}

- (void)testJitterRebuildsALostPacketFromTheNextOnesFec {
    TGJitter *j = TGJitterCreate();
    static TGJitterOut out;
    jitterPut(j, 1, 0);
    jitterPut(j, 2, 20);
    jitterPut(j, 4, 60);                 // 3 lost
    jitterPut(j, 5, 80);
    TGJitterPull(j, &out);
    TGJitterPull(j, &out);
    XCTAssertEqual(out.payload[0], 2);
    TGJitterPull(j, &out);
    XCTAssertEqual(out.action, TGJitterFec, @"3's copy rides in 4");
    XCTAssertEqual(out.payload[0], 4);
    XCTAssertEqual(out.samples, 960);
    TGJitterPull(j, &out);
    XCTAssertEqual(out.action, TGJitterPlay, @"and 4 still plays itself");
    XCTAssertEqual(out.payload[0], 4);
    TGJitterStats stats = TGJitterGetStats(j);
    XCTAssertEqual(stats.fec, 1u);
    TGJitterFree(j);
}

- (void)testJitterConcealsALatePacketAndStillPlaysIt {
    TGJitter *j = TGJitterCreate();
    static TGJitterOut out;
    for (int seq = 1; seq <= 3; seq++)
        jitterPut(j, (uint16_t)seq, seq * 20);
    for (int i = 0; i < 3; i++)
        TGJitterPull(j, &out);
    TGJitterPull(j, &out);
    XCTAssertEqual(out.action, TGJitterConceal, @"4 is not here and nothing is behind it");
    jitterPut(j, 4, 120);
    TGJitterPull(j, &out);
    XCTAssertEqual(out.action, TGJitterPlay, @"late, not lost: it plays");
    XCTAssertEqual(out.payload[0], 4);
    XCTAssertEqual(TGJitterGetStats(j).late, 0u);
    TGJitterFree(j);
}

- (void)testJitterTargetFollowsArrivalSpread {
    TGJitter *j = TGJitterCreate();
    // Every fourth packet 120 ms late, the rest on time.
    for (int seq = 0; seq < 64; seq++)
        jitterPut(j, (uint16_t)seq, seq * 20 + (seq % 4 == 3 ? 120 : 0));
    int target = TGJitterTargetMs(j);
    XCTAssertTrue(target >= 120 && target <= 160, @"target %d ms", target);
    TGJitterFree(j);

    j = TGJitterCreate();
    for (int seq = 0; seq < 64; seq++)
        jitterPut(j, (uint16_t)seq, seq * 20);
    XCTAssertEqual(TGJitterTargetMs(j), 40, @"a steady stream sits at the floor");
    TGJitterFree(j);
}

- (void)testJitterIgnoresTheBurstWhileTheCallConnects {
    // Ten packets queued during setup land at once, then the stream is
    // steady: the target is the steady stream's, not the burst's.
    TGJitter *j = TGJitterCreate();
    for (int seq = 0; seq < 10; seq++)
        jitterPut(j, (uint16_t)seq, 500);
    for (int seq = 10; seq < 120; seq++)
        jitterPut(j, (uint16_t)seq, 500 + (seq - 10) * 20);
    XCTAssertEqual(TGJitterTargetMs(j), 40);
    TGJitterFree(j);
}

- (void)testJitterSkipsToCatchUpWhenFarBehind {
    TGJitter *j = TGJitterCreate();
    static TGJitterOut out;
    // A steady stream the player fell 600 ms behind (a fast peer clock, or
    // concealment that stretched playout): it skips until it is back near
    // the 40 ms target instead of keeping the call that much late.
    for (int seq = 0; seq < 30; seq++)
        jitterPut(j, (uint16_t)seq, seq * 20);
    int played = 0;
    for (int i = 0; i < 30; i++){
        TGJitterPull(j, &out);
        played += out.action == TGJitterPlay;
    }
    TGJitterStats stats = TGJitterGetStats(j);
    // One skip per 20 ms step, down to 80 ms over the target: 600 -> ~120.
    XCTAssertTrue(stats.dropped >= 10 && stats.dropped <= 14, @"skipped %u", stats.dropped);
    XCTAssertEqual(stats.dropped + (unsigned)played, 30u);
    TGJitterFree(j);
}


#pragma mark - Expand and Opus packets

static double expandRms(const int16_t *pcm, int count) {
    double sum = 0;
    for (int i = 0; i < count; i++)
        sum += (double)pcm[i] * pcm[i];
    return sqrt(sum / count);
}

- (void)testExpandCarriesAToneThroughALostPacket {
    // A 200 Hz voice-like tone (period 240 samples), then 60 ms missing.
    TGExpand e;
    TGExpandInit(&e);
    int16_t pcm[2880];
    for (int block = 0; block < 2; block++){
        for (int i = 0; i < 2880; i++)
            pcm[i] = (int16_t)(8000 * sin(2 * M_PI * 200 * (block * 2880 + i) / 48000.0));
        TGExpandGood(&e, pcm, 2880);
    }
    double level = expandRms(pcm, 2880);
    int16_t filled[2880];
    TGExpandFill(&e, filled, 2880);
    XCTAssertEqual(e.period % 240, 0, @"period %d is the tone's", e.period);
    XCTAssertTrue(expandRms(filled, 960) > level * 0.95, @"full level for 20 ms");
    double last = expandRms(filled + 1920, 960);
    XCTAssertTrue(last > level * 0.4 && last < level * 0.8, @"then falling, not gone: %.0f of %.0f", last, level);
    // The tone carries on in phase: the first filled sample follows the last real one.
    double next = 8000 * sin(2 * M_PI * 200 * 5760 / 48000.0);
    XCTAssertTrue(fabs(filled[0] - next) < 400, @"%d against %.0f", filled[0], next);
}

- (void)testExpandBlendsBackWithoutAJump {
    TGExpand e;
    TGExpandInit(&e);
    int16_t pcm[1920];
    for (int i = 0; i < 1920; i++)
        pcm[i] = (int16_t)(8000 * sin(2 * M_PI * 200 * i / 48000.0));
    TGExpandGood(&e, pcm, 1920);
    int16_t filled[960];
    TGExpandFill(&e, filled, 960);
    int16_t quiet[960] = {0};              // Opus fading its first frame in
    TGExpandGood(&e, quiet, 960);
    XCTAssertTrue(abs(quiet[0] - filled[959]) < 1500, @"the join follows the expand");
    XCTAssertTrue(expandRms(quiet, 480) > 2000, @"no dip where the decoder fades in");
    XCTAssertEqual(e.expanding, 0);
}

- (void)testExpandIsSilentWithNothingToRepeat {
    TGExpand e;
    TGExpandInit(&e);
    int16_t out[960];
    memset(out, 0x55, sizeof(out));
    TGExpandFill(&e, out, 960);
    XCTAssertEqual(expandRms(out, 960), 0.0);
}

- (void)testOpusPacketSamplesFromToc {
    uint8_t silk60[1] = { (3 << 3) | 0 };          // SILK NB 60 ms, one frame
    uint8_t hybrid20x3[2] = { (13 << 3) | 3, 3 };  // hybrid 20 ms, code 3, three frames
    uint8_t celt10x2[1] = { (30 << 3) | 1 };       // CELT FB 10 ms, two frames
    XCTAssertEqual(TGOpusPacketSamples(silk60, 1), 2880);
    XCTAssertEqual(TGOpusPacketSamples(hybrid20x3, 2), 2880);
    XCTAssertEqual(TGOpusPacketSamples(celt10x2, 1), 960);
    XCTAssertEqual(TGOpusPacketSamples(hybrid20x3, 1), 0, @"code 3 without its count byte");
}

- (void)testOpusFecShareFollowsLoss {
    XCTAssertEqual(TGOpusLossPercent(0), 2, @"a little FEC kept for the next burst");
    XCTAssertEqual(TGOpusLossPercent(20), 8);
    XCTAssertEqual(TGOpusLossPercent(128), 25, @"capped: past that it eats the voice");
}


#pragma mark - H.264 parameter sets without the iOS 7 calls

static CMSampleBufferRef sH264Sample;

static void h264Encoded(void *ref, void *frame, OSStatus status, VTEncodeInfoFlags flags, CMSampleBufferRef sample) {
    if (status == noErr && sample && !sH264Sample)
        sH264Sample = (CMSampleBufferRef)CFRetain(sample);
}

static int sH264Decoded;
static void h264Decoded(void *ref, void *frame, OSStatus status, VTDecodeInfoFlags flags,
                        CVImageBufferRef image, CMTime pts, CMTime duration) {
    if (status == noErr && image)
        sH264Decoded++;
}

- (void)testParameterSetsRoundTripThroughAvcCAsOnIOS6 {
    // What the iPod touch 4 on 6.1.6 has to do: no
    // CMVideoFormatDescriptionGetH264ParameterSetAtIndex, so the sets come
    // from the avcC atom, and the decoder's description is built from one.
    VTCompressionSessionRef encoder = NULL;
    XCTAssertEqual(VTCompressionSessionCreate(NULL, 288, 352, kCMVideoCodecType_H264, NULL, NULL, NULL,
                                              h264Encoded, NULL, &encoder), noErr);
    CVPixelBufferRef picture = NULL;
    CVPixelBufferCreate(NULL, 288, 352, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                        (__bridge CFDictionaryRef)@{ (id)kCVPixelBufferIOSurfacePropertiesKey : @{} }, &picture);
    CVPixelBufferLockBaseAddress(picture, 0);
    memset(CVPixelBufferGetBaseAddressOfPlane(picture, 0), 90, CVPixelBufferGetBytesPerRowOfPlane(picture, 0) * 352);
    memset(CVPixelBufferGetBaseAddressOfPlane(picture, 1), 128, CVPixelBufferGetBytesPerRowOfPlane(picture, 1) * 176);
    CVPixelBufferUnlockBaseAddress(picture, 0);
    VTCompressionSessionEncodeFrame(encoder, picture, CMTimeMake(0, 15), kCMTimeInvalid, NULL, NULL, NULL);
    VTCompressionSessionCompleteFrames(encoder, kCMTimeInvalid);
    XCTAssertTrue(sH264Sample != NULL);
    if (!sH264Sample)
        return;

    CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sH264Sample);
    CFDictionaryRef atoms = (CFDictionaryRef)CMFormatDescriptionGetExtension(
        format, kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms);
    CFDataRef avcc = atoms ? (CFDataRef)CFDictionaryGetValue(atoms, CFSTR("avcC")) : NULL;
    const uint8_t *sps = NULL, *pps = NULL;
    size_t spsLength = 0, ppsLength = 0;
    XCTAssertTrue(avcc && TGAvcCParse(CFDataGetBytePtr(avcc), (size_t)CFDataGetLength(avcc),
                                      &sps, &spsLength, &pps, &ppsLength));
    const uint8_t *apiSps = NULL;
    size_t apiLength = 0;
    CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &apiSps, &apiLength, NULL, NULL);
    XCTAssertEqual(spsLength, apiLength, @"the same SPS the iOS 7 call gives");
    XCTAssertTrue(apiSps && memcmp(sps, apiSps, spsLength) == 0);
    int width = 0, height = 0;
    XCTAssertTrue(TGH264SpsSize(sps, spsLength, &width, &height));
    XCTAssertEqual(width, 288);
    XCTAssertEqual(height, 352);

    uint8_t rebuilt[512];
    size_t rebuiltLength = TGAvcCBuild(sps, spsLength, pps, ppsLength, rebuilt, sizeof(rebuilt));
    XCTAssertTrue(rebuiltLength > 0);
    CMVideoFormatDescriptionRef decodeFormat = NULL;
    NSDictionary *extensions = @{ (id)kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms :
                                  @{ @"avcC" : [NSData dataWithBytes:rebuilt length:rebuiltLength] } };
    XCTAssertEqual(CMVideoFormatDescriptionCreate(NULL, kCMVideoCodecType_H264, width, height,
                                                  (__bridge CFDictionaryRef)extensions, &decodeFormat), noErr);
    VTDecompressionOutputCallbackRecord callback = { h264Decoded, NULL };
    VTDecompressionSessionRef decoder = NULL;
    XCTAssertEqual(VTDecompressionSessionCreate(NULL, decodeFormat, NULL, NULL, &callback, &decoder), noErr);
    // As the engine does: the frame's bytes under the rebuilt description.
    CMSampleBufferRef again = NULL;
    CMSampleBufferCreate(NULL, CMSampleBufferGetDataBuffer(sH264Sample), true, NULL, NULL,
                         decodeFormat, 1, 0, NULL, 0, NULL, &again);
    sH264Decoded = 0;
    VTDecompressionSessionDecodeFrame(decoder, again ?: sH264Sample, 0, NULL, NULL);
    VTDecompressionSessionWaitForAsynchronousFrames(decoder);
    XCTAssertEqual(sH264Decoded, 1, @"decoded from the rebuilt description");

    if (again) CFRelease(again);
    VTDecompressionSessionInvalidate(decoder);
    CFRelease(decoder);
    CFRelease(decodeFormat);
    VTCompressionSessionInvalidate(encoder);
    CFRelease(encoder);
    CVPixelBufferRelease(picture);
    CFRelease(sH264Sample);
    sH264Sample = NULL;
}

- (void)testAvcCParseRefusesTruncatedRecords {
    uint8_t sps[] = { 0x67, 0x42, 0xC0, 0x1E, 0xAB };
    uint8_t pps[] = { 0x68, 0xCE, 0x3C, 0x80 };
    uint8_t avcc[64];
    size_t n = TGAvcCBuild(sps, sizeof(sps), pps, sizeof(pps), avcc, sizeof(avcc));
    XCTAssertEqual(n, 11 + sizeof(sps) + sizeof(pps));
    const uint8_t *s = NULL, *p = NULL;
    size_t sl = 0, pl = 0;
    XCTAssertTrue(TGAvcCParse(avcc, n, &s, &sl, &p, &pl));
    XCTAssertEqual(sl, sizeof(sps));
    XCTAssertEqual(pl, sizeof(pps));
    for (size_t cut = 0; cut < n; cut++)
        XCTAssertFalse(TGAvcCParse(avcc, cut, &s, &sl, &p, &pl), @"cut at %zu", cut);
    XCTAssertEqual(TGAvcCBuild(sps, sizeof(sps), pps, sizeof(pps), avcc, 10), 0u);
}

@end
