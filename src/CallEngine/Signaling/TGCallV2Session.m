#import "TGCallV2Session.h"

#import "TGCallDtls.h"
#import "TGCallMessages.h"
#import "TGCallRtcp.h"
#import "TGCallSctp.h"
#import "TGCallSrtp.h"
#import "TGCallV2Signaling.h"
#import "TGCallVideoReorder.h"
#import "TGCallJitter.h"

static const NSTimeInterval kResendInterval = 3.0;
static const NSTimeInterval kGiveUpInterval = 25.0;
static const NSTimeInterval kReportInterval = 1.0;
static const NSTimeInterval kKeyframeRequestInterval = 0.5;
/// How long a hole in the peer's video waits for its NACKed packets: a
/// reflector round trip is 100-200 ms.
// How long a hole in the peer's video waits for the NACKed packet: two and a
// half round trips, measured from our NACKs to the resends they bring, so a
// second NACK fits when the first or its resend was lost too; never under
// 0.3 s or over 1 s. A fixed 0.3 s gave up on every resend over 3G, where the
// round trip alone is 0.3 s or more. Waiting costs no more than giving up:
// the picture is frozen either way, and a keyframe is a round trip and a
// big frame away.
static const NSTimeInterval kVideoPatienceMin = 0.3;
static const NSTimeInterval kVideoPatienceMax = 1.0;
static const uint32_t kAudioPayloadType = 111;
/// Sent video kept for NACKs: 2 to 4 s at the rates this sends.
enum { kVideoHistory = 128, kVideoHistorySlot = 1200 };

@interface TGCallV2Session ()
@property (nonatomic, strong) TGCallDtls *dtls;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSMutableArray *pending;
@property (nonatomic, strong) NSString *peerUfrag;
@property (nonatomic, strong) NSString *peerPwd;
@property (nonatomic, strong) NSString *peerFingerprint;
@property (nonatomic, strong) NSString *offerExchangeId;
/// Every exchange either side started. Signalling arrives more than once
/// (resent until acked, and bundled with what follows), so a repeat of an
/// offer or a late answer must change nothing.
@property (nonatomic, strong) NSMutableSet *seenExchanges;
@property (nonatomic, assign) BOOL sentInitialSetup;
@property (nonatomic, assign) BOOL sentOffer;
@property (nonatomic, assign) BOOL havePeerSetup;
@property (nonatomic, assign) BOOL iceIsConnected;
@property (nonatomic, assign) BOOL haveKeys;
@property (nonatomic, assign) BOOL failed;
@property (nonatomic, assign) NSTimeInterval startedAt;
@end

static void TGV2SctpSend(void *context, const uint8_t *packet, size_t length);
static void TGV2SctpMessage(void *context, const uint8_t *text, size_t length);
static void TGV2SctpOpen(void *context);

@implementation TGCallV2Session {
	uint32_t _seq;
	uint16_t _audioSeq;
	uint32_t _audioTimestamp;
	uint32_t _srtcpIndex;

	// One context per stream and direction: each keeps its own rollover
	// counter, and each is touched by one thread only.
	TGSrtpContext _sendAudio;
	TGSrtpContext _sendVideo;
	TGSrtpContext _receiveAudio;
	TGSrtpContext _receiveVideo;
	TGSrtpContext _sendRtcp;
	TGSrtpContext _receiveRtcp;

	// The peer's streams, from its offer. Written on the main queue, read on
	// the reflector thread; a stale read only drops a packet.
	volatile uint32_t _peerAudioSsrc;
	volatile uint32_t _peerVideoSsrc;
	volatile uint8_t _videoPayloadType;

	TGRtpStats _stats[2];        // audio, video; under _rtcpLock
	NSObject *_rtcpLock;
	NSTimeInterval _lastReport;
	NSTimeInterval _lastKeyframeRequest;

	NSObject *_dtlsLock;         // DTLS and SCTP both
	TGSctp _sctp;
	BOOL _sendVP8;
	BOOL _receiveVP8;
	BOOL _stateMuted;
	BOOL _stateVideo;

	uint32_t _srtpPacketsIn;
	uint64_t _srtpBytesIn;
	uint32_t _srtpFailuresIn;
	uint32_t _srtcpFailuresIn;
	uint32_t _videoLostReported;
	uint32_t _videoGapsIn;
	uint32_t _nacksSent;
	uint32_t _audioFramesSent;
	uint32_t _videoPacketsSent;
	uint8_t _audioOut[2048];
	uint8_t _videoOut[2048];
	// Each packet as it went out, SRTP and all, so a NACK resends the same
	// bytes: no second encryption, no rollover counter to get wrong at a wrap.
	uint8_t *_videoHistory;
	uint16_t _videoHistoryLength[kVideoHistory];
	uint16_t _videoHistorySeq[kVideoHistory];
	double _videoResentAt[kVideoHistory];
	// Bytes of the last whole second, first sends and resends: resends are
	// held to half the first sends.
	double _videoWindowStart;
	size_t _videoSentBytes, _videoResentBytes;
	NSObject *_videoLock;
	TGVideoReorder *_reorder;    // reflector thread only, like the three below
	double _nackAt[64];
	uint16_t _nackSeq[64];
	double _videoRtt;
	uint32_t _videoResent;
	uint8_t _receive[2048];
	uint8_t _rtcpOut[256];
}

- (instancetype)init {
	if ((self = [super init])){
		_pending = [NSMutableArray array];
		_seenExchanges = [NSMutableSet set];
		_startedAt = [NSDate timeIntervalSinceReferenceDate];
		_rtcpLock = [[NSObject alloc] init];
		_videoLock = [[NSObject alloc] init];
		_videoHistory = calloc(kVideoHistory, kVideoHistorySlot);
		_reorder = calloc(1, sizeof(TGVideoReorder));
		_dtlsLock = [[NSObject alloc] init];
	}
	return self;
}

- (void)dealloc {
	free(_videoHistory);
	free(_reorder);
}

static void TGV2DeliverVideo(void *context, const uint8_t *rtp, size_t length) {
	TGCallV2Session *session = (__bridge TGCallV2Session *)context;
	if (!rtp){
		if (session.onVideoLoss)
			session.onVideoLoss();
		return;
	}
	if (session.onVideo)
		session.onVideo(rtp, length);
}

- (BOOL)canSendVideo {
	return self.haveKeys && _videoPayloadType != 0;
}

- (void)start {
	self.dtls = [[TGCallDtls alloc] initWithClient:self.outgoing];
	NSString *error = nil;
	if (![self.dtls setupWithError:&error]){
		[self fail:error ?: @"DTLS setup failed"];
		return;
	}
	if (self.videoCapable && !self.localVideoSsrc)
		self.localVideoSsrc = (arc4random() | 1);

	_sctp.context = (__bridge void *)self;
	_sctp.send = TGV2SctpSend;
	_sctp.onMessage = TGV2SctpMessage;
	_sctp.onOpen = TGV2SctpOpen;
	TGSctpInit(&_sctp, self.outgoing, arc4random(), arc4random());

	__weak __typeof__(self) weakSelf = self;
	self.dtls.sendRecord = ^(const uint8_t *bytes, size_t length){
		if (weakSelf.sendMedia)
			weakSelf.sendMedia(bytes, length);
	};
	self.dtls.onConnected = ^{
		[weakSelf keysReady];
	};
	self.dtls.onFailure = ^(NSString *reason){
		[weakSelf fail:reason];
	};
	self.dtls.onApplicationData = ^(const uint8_t *bytes, size_t length){
		[weakSelf sctpPacket:bytes length:length];
	};

	if (self.outgoing){
		[self sendInitialSetup];
		[self sendOffer];
	}

	self.timer = [NSTimer scheduledTimerWithTimeInterval:0.5
	                                              target:self
	                                            selector:@selector(tick)
	                                            userInfo:nil
	                                             repeats:YES];
}

- (void)iceConnected {
	// Either path may say so first, the reflector's ICE or the direct one;
	// the handshake starts once.
	if (self.iceIsConnected)
		return;
	self.iceIsConnected = YES;
	if (self.havePeerSetup){
		@synchronized (_dtlsLock){
			[self.dtls beginHandshake];
		}
	}
}

#pragma mark - Signalling

- (void)sendWithPlaintext:(NSData *)plaintext requiresAck:(BOOL)requiresAck {
	if (!plaintext.length || !self.sendSignaling || self.failed)
		return;
	uint32_t seq = requiresAck
		? [TGCallMessages markSeq:++_seq requiresAck:YES]
		: ++_seq;
	if (requiresAck){
		[self.pending addObject:@{
			@"seq" : @(seq),
			@"data" : plaintext,
			@"time" : @([NSDate timeIntervalSinceReferenceDate]),
		}];
	}
	self.sendSignaling(plaintext, seq);
}

- (void)sendInitialSetup {
	if (self.sentInitialSetup || !self.dtls.fingerprint.length)
		return;
	self.sentInitialSetup = YES;
	NSData *message = [TGCallV2Signaling initialSetupWithUfrag:self.localUfrag
	                                                      pwd:self.localPwd
	                                              fingerprint:self.dtls.fingerprint
	                                                    setup:self.outgoing ? @"actpass" : @"passive"];
	[self sendWithPlaintext:message requiresAck:YES];
}

- (NSArray *)offerContents {
	NSMutableArray *contents = [NSMutableArray arrayWithObject:
		[TGCallV2Signaling audioContentWithSsrc:self.localSsrc]];
	// Offered from the start, camera on or not: the peer shows our picture by
	// MediaState, so an idle channel costs nothing and needs no renegotiation
	// when the camera comes on.
	if (self.videoCapable)
		[contents addObject:[TGCallV2Signaling videoContentWithSsrc:self.localVideoSsrc
		                                                       h264:self.h264Capable]];
	return contents;
}

- (void)sendOffer {
	self.sentOffer = YES;
	self.offerExchangeId = [NSString stringWithFormat:@"%u", (uint32_t)(arc4random() | 1)];
	[self.seenExchanges addObject:self.offerExchangeId];
	NSData *message = [TGCallV2Signaling negotiateWithExchangeId:self.offerExchangeId
	                                                    contents:[self offerContents]];
	[self sendWithPlaintext:message requiresAck:YES];
}

- (void)sendCandidates:(NSArray *)candidates {
	if (!candidates.count)
		return;
	NSData *message = [TGCallV2Signaling candidatesWithStrings:candidates];
	[self sendWithPlaintext:message requiresAck:YES];
}

- (void)ackSeq:(uint32_t)seq {
	NSData *ack = [TGCallV2Signaling ackForSeq:seq];
	[self sendWithPlaintext:ack requiresAck:NO];
}

- (void)handlePlaintext:(NSData *)plaintext packetSeq:(uint32_t)seq {
	TGV2Slice slices[16];
	size_t count = TGV2ParsePlaintext(plaintext.bytes, plaintext.length, seq,
	                                  slices, 16);
	for (size_t i = 0; i < count; i++){
		uint8_t type = slices[i].type;
		if (type == 0x7F){
			NSDictionary *json = [NSJSONSerialization
				JSONObjectWithData:[NSData dataWithBytes:slices[i].body
				                                 length:slices[i].bodyLength]
				           options:0 error:nil];
			if ([json isKindOfClass:[NSDictionary class]])
				[self handleJSON:json];
			if ([TGCallMessages seqRequiresAck:slices[i].seq])
				[self ackSeq:slices[i].seq];
		} else if (type == 0xFF){
			[self acknowledgeSeq:slices[i].seq];
		}
	}
}

- (void)acknowledgeSeq:(uint32_t)seq {
	for (NSUInteger i = 0; i < self.pending.count; i++){
		NSDictionary *entry = self.pending[i];
		if ([entry[@"seq"] unsignedIntValue] == seq){
			[self.pending removeObjectAtIndex:i];
			return;
		}
	}
}

- (uint32_t)uint32Value:(id)value {
	if ([value isKindOfClass:[NSString class]])
		return (uint32_t)[value longLongValue];
	if ([value isKindOfClass:[NSNumber class]])
		return [value unsignedIntValue];
	return 0;
}

- (void)handleJSON:(NSDictionary *)json {
	NSString *type = json[@"@type"];
	if ([type isEqualToString:@"InitialSetup"]){
		NSArray *fingerprints = json[@"fingerprints"];
		NSDictionary *first = [fingerprints isKindOfClass:[NSArray class]] &&
		                      [fingerprints count] ? fingerprints[0] : nil;
		NSString *fingerprint = first[@"fingerprint"];
		self.peerUfrag = json[@"ufrag"];
		self.peerPwd = json[@"pwd"];
		self.peerFingerprint = fingerprint;
		NSLog(@"TGCallV2: peer InitialSetup ufrag=%@ pwd=%d setup=%@ fingerprint=%d",
		      self.peerUfrag, self.peerPwd.length > 0,
		      first[@"setup"], fingerprint.length > 0);
		if (!self.havePeerSetup){
			self.havePeerSetup = YES;
			if (self.onPeerCredentials)
				self.onPeerCredentials(self.peerUfrag, self.peerPwd);
			// The callee stays silent until the caller's InitialSetup arrives,
			// then answers with its own.
			[self sendInitialSetup];
			if (self.iceIsConnected){
				@synchronized (_dtlsLock){
					[self.dtls beginHandshake];
				}
			}
		}
	} else if ([type isEqualToString:@"NegotiateChannels"]){
		[self handleNegotiation:json];
	} else if ([type isEqualToString:@"Candidates"]){
		NSArray *items = json[@"candidates"];
		NSMutableArray *candidates = [NSMutableArray array];
		for (NSDictionary *item in items){
			NSString *sdp = item[@"sdpString"];
			if (sdp.length)
				[candidates addObject:sdp];
		}
		if (candidates.count && self.onRemoteCandidates)
			self.onRemoteCandidates(candidates);
	} else if ([type isEqualToString:@"MediaState"]){
		// The library sends this over the data channel; older builds used
		// signalling. Either way it means the same.
		[self handleMediaState:json];
	} else {
		NSLog(@"TGCallV2: ignoring signalling type %@", type);
	}
}

/// tgcalls' ContentNegotiationContext: an offer lists the sender's own
/// send-only channels, the answer echoes each one it will receive with the
/// codec it picked. An answer is told apart by carrying our exchangeId.
- (void)handleNegotiation:(NSDictionary *)json {
	id rawExchange = json[@"exchangeId"];
	NSString *exchangeId = rawExchange ? [rawExchange description] : nil;
	NSArray *contents = [json[@"contents"] isKindOfClass:[NSArray class]] ? json[@"contents"] : @[];
	if (!exchangeId.length)
		return;

	if ([exchangeId isEqualToString:self.offerExchangeId]){
		uint8_t videoPayloadType = 0;
		BOOL vp8 = NO;
		for (NSDictionary *content in contents){
			if (![content isKindOfClass:[NSDictionary class]] ||
			    ![content[@"type"] isEqual:@"video"] ||
			    [self uint32Value:content[@"ssrc"]] != self.localVideoSsrc)
				continue;
			NSDictionary *chosen = self.h264Capable ? [TGCallV2Signaling h264PayloadIn:content] : nil;
			if (!chosen){
				chosen = [TGCallV2Signaling vp8PayloadIn:content];
				vp8 = chosen != nil;
			}
			videoPayloadType = (uint8_t)[chosen[@"id"] intValue];
		}
		_videoPayloadType = videoPayloadType;
		_sendVP8 = vp8;
		[self reportVideoCodecs];
		NSLog(@"TGCallV2: peer answered exchange %@, video pt %u", exchangeId, videoPayloadType);
		self.offerExchangeId = nil;
		[self videoMayHaveBecomeSendable];
		return;
	}
	if ([self.seenExchanges containsObject:exchangeId])
		return;
	[self.seenExchanges addObject:exchangeId];

	// Their offer. A callee whose own offer is still out gives way: tgcalls'
	// rule is that the caller wins, and the caller ignores our offer now.
	BOOL resendOffer = !self.outgoing && self.offerExchangeId != nil && self.sentOffer;
	if (resendOffer){
		[self dropPendingOffer];
		self.offerExchangeId = nil;
	}

	NSMutableArray *answer = [NSMutableArray array];
	uint32_t audioSsrc = 0, videoSsrc = 0;
	for (NSDictionary *content in contents){
		NSDictionary *mine = [TGCallV2Signaling answerContentFor:content
		                                             acceptVideo:self.videoCapable
		                                              preferH264:self.h264Capable];
		if (!mine)
			continue;
		[answer addObject:mine];
		uint32_t ssrc = [self uint32Value:content[@"ssrc"]];
		if ([content[@"type"] isEqual:@"audio"]){
			audioSsrc = ssrc;
		} else {
			videoSsrc = ssrc;
			NSString *name = [mine[@"payloadTypes"] firstObject][@"name"];
			_receiveVP8 = [[name description] caseInsensitiveCompare:@"VP8"] == NSOrderedSame;
		}
	}
	NSLog(@"TGCallV2: peer offer exchange=%@ audio=%u video=%u", exchangeId, audioSsrc, videoSsrc);
	if (audioSsrc)
		_peerAudioSsrc = audioSsrc;
	_peerVideoSsrc = videoSsrc;
	[self reportVideoCodecs];
	[self sendWithPlaintext:[TGCallV2Signaling negotiateWithExchangeId:exchangeId contents:answer]
	            requiresAck:YES];

	// The callee's first offer follows its first answer; that is what starts
	// the other direction.
	if (!self.sentOffer || resendOffer)
		[self sendOffer];
}

- (void)reportVideoCodecs {
	if (self.onVideoCodecs)
		self.onVideoCodecs(_sendVP8, _receiveVP8);
}

- (void)dropPendingOffer {
	NSMutableArray *kept = [NSMutableArray array];
	for (NSDictionary *entry in self.pending){
		NSData *data = entry[@"data"];
		NSRange range = [data rangeOfData:[self.offerExchangeId dataUsingEncoding:NSUTF8StringEncoding]
		                          options:0 range:NSMakeRange(0, data.length)];
		if (range.location == NSNotFound)
			[kept addObject:entry];
	}
	self.pending = kept;
}

#pragma mark - Media state

- (void)handleMediaState:(NSDictionary *)json {
	BOOL muted = [json[@"muted"] boolValue];
	BOOL video = [json[@"videoState"] isEqual:@"active"];
	NSLog(@"TGCallV2: peer MediaState muted=%d video=%@", muted, json[@"videoState"]);
	dispatch_async(dispatch_get_main_queue(), ^{
		if (self.onPeerMediaState)
			self.onPeerMediaState(muted, video);
	});
}

- (void)setMediaStateMuted:(BOOL)muted videoActive:(BOOL)videoActive {
	@synchronized (_dtlsLock){
		_stateMuted = muted;
		_stateVideo = videoActive;
		[self sendMediaStateLocked];
	}
}

- (void)sendMediaStateLocked {
	if (!_sctp.channelOpen)
		return;
	NSString *text = [TGCallV2Signaling mediaStateWithMuted:_stateMuted videoActive:_stateVideo];
	const char *bytes = text.UTF8String;
	TGSctpSendText(&_sctp, bytes, strlen(bytes), [NSDate timeIntervalSinceReferenceDate]);
}

- (void)sctpPacket:(const uint8_t *)bytes length:(size_t)length {
	// Already under _dtlsLock: application data only comes out of a feed.
	TGSctpReceive(&_sctp, bytes, length, [NSDate timeIntervalSinceReferenceDate]);
}

static void TGV2SctpSend(void *context, const uint8_t *packet, size_t length) {
	TGCallV2Session *session = (__bridge TGCallV2Session *)context;
	[session.dtls sendApplicationData:packet length:length];
}

static void TGV2SctpMessage(void *context, const uint8_t *text, size_t length) {
	TGCallV2Session *session = (__bridge TGCallV2Session *)context;
	NSData *data = [NSData dataWithBytes:text length:length];
	NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
	if ([json isKindOfClass:[NSDictionary class]] && [json[@"@type"] isEqual:@"MediaState"])
		[session handleMediaState:json];
}

static void TGV2SctpOpen(void *context) {
	TGCallV2Session *session = (__bridge TGCallV2Session *)context;
	NSLog(@"TGCallV2: data channel open");
	[session sendMediaStateLocked];
}

#pragma mark - Keys

- (void)keysReady {
	if (self.haveKeys)
		return;
	uint8_t exporter[60];
	if (![self.dtls exportKeyingMaterial:exporter length:sizeof(exporter)]){
		[self fail:@"SRTP key export failed"];
		return;
	}
	uint8_t sendKey[TGSrtpKeyLength], sendSalt[TGSrtpSaltLength];
	uint8_t receiveKey[TGSrtpKeyLength], receiveSalt[TGSrtpSaltLength];
	TGSrtpSplitExporter(exporter, self.outgoing ? 1 : 0,
	                    sendKey, sendSalt, receiveKey, receiveSalt);
	TGSrtpContextInit(&_sendAudio, sendKey, sendSalt);
	TGSrtpContextInit(&_sendVideo, sendKey, sendSalt);
	TGSrtpContextInit(&_receiveAudio, receiveKey, receiveSalt);
	TGSrtpContextInit(&_receiveVideo, receiveKey, receiveSalt);
	TGSrtcpContextInit(&_sendRtcp, sendKey, sendSalt);
	TGSrtcpContextInit(&_receiveRtcp, receiveKey, receiveSalt);
	self.haveKeys = YES;
	NSLog(@"TGCallV2: DTLS done, SRTP keys installed (client %d)", self.outgoing);
	[self videoMayHaveBecomeSendable];
	dispatch_async(dispatch_get_main_queue(), ^{
		if (self.onEstablished)
			self.onEstablished();
	});
}

#pragma mark - Sending

/// Whatever the camera encoded before the channel existed was dropped, the
/// keyframe with it; the first picture the peer can decode is the next one.
- (void)videoMayHaveBecomeSendable {
	if (self.canSendVideo && self.onKeyframeRequest)
		self.onKeyframeRequest();
}

- (void)sendOpusFrame:(NSData *)frame {
	if (!self.haveKeys || !frame.length || self.failed)
		return;
	size_t length = 12 + frame.length;
	if (length + TGSrtpTagLength > sizeof(_audioOut))
		return;
	_audioOut[0] = 0x80;
	_audioOut[1] = kAudioPayloadType;
	_audioOut[2] = (uint8_t)(_audioSeq >> 8);
	_audioOut[3] = (uint8_t)_audioSeq;
	_audioOut[4] = (uint8_t)(_audioTimestamp >> 24);
	_audioOut[5] = (uint8_t)(_audioTimestamp >> 16);
	_audioOut[6] = (uint8_t)(_audioTimestamp >> 8);
	_audioOut[7] = (uint8_t)_audioTimestamp;
	_audioOut[8]  = (uint8_t)(self.localSsrc >> 24);
	_audioOut[9]  = (uint8_t)(self.localSsrc >> 16);
	_audioOut[10] = (uint8_t)(self.localSsrc >> 8);
	_audioOut[11] = (uint8_t)self.localSsrc;
	memcpy(_audioOut + 12, frame.bytes, frame.length);
	_audioSeq++;
	// The packet's own length: the engine sends 60 ms, the bench may not.
	int samples = TGOpusPacketSamples((const uint8_t *)frame.bytes, frame.length);
	_audioTimestamp += (uint32_t)(samples > 0 ? samples : 960);

	size_t protectedLength = 0;
	if (TGSrtpProtect(&_sendAudio, _audioOut, length, sizeof(_audioOut),
	                  &protectedLength) != 0)
		return;
	if (self.sendMedia)
		self.sendMedia(_audioOut, protectedLength);
	if (++_audioFramesSent % 500 == 0)
		NSLog(@"TGCallV2: %u audio frames sent", _audioFramesSent);
}

- (void)sendVideoRtp:(NSData *)rtp {
	uint8_t payloadType = _videoPayloadType;
	if (!self.haveKeys || !payloadType || self.failed || rtp.length < 12 ||
	    rtp.length + TGSrtpTagLength > kVideoHistorySlot)
		return;
	@synchronized (_videoLock){
		memcpy(_videoOut, rtp.bytes, rtp.length);
		_videoOut[1] = (uint8_t)((_videoOut[1] & 0x80) | payloadType);
		uint32_t ssrc = self.localVideoSsrc;
		_videoOut[8]  = (uint8_t)(ssrc >> 24);
		_videoOut[9]  = (uint8_t)(ssrc >> 16);
		_videoOut[10] = (uint8_t)(ssrc >> 8);
		_videoOut[11] = (uint8_t)ssrc;
		uint16_t seq = (uint16_t)((_videoOut[2] << 8) | _videoOut[3]);
		size_t protectedLength = 0;
		if (TGSrtpProtect(&_sendVideo, _videoOut, rtp.length, sizeof(_videoOut),
		                  &protectedLength) != 0)
			return;
		unsigned slot = seq % kVideoHistory;
		memcpy(_videoHistory + slot * kVideoHistorySlot, _videoOut, protectedLength);
		_videoHistoryLength[slot] = (uint16_t)protectedLength;
		_videoHistorySeq[slot] = seq;
		_videoResentAt[slot] = 0;
		[self rollVideoWindow:[NSDate timeIntervalSinceReferenceDate]];
		_videoSentBytes += protectedLength;
		if (self.sendMedia)
			self.sendMedia(_videoOut, protectedLength);
	}
	if (++_videoPacketsSent == 1 || _videoPacketsSent % 300 == 0)
		NSLog(@"TGCallV2: %u video packets sent", _videoPacketsSent);
}

/// WebRTC asks again every round trip until the packet comes, up to ten times.
/// Answering each ask on a link that already drops for want of room filled
/// it with copies: 1950 resends for 600 packets at 8% loss and 300 kbit/s on
/// the stand. So one resend per packet per round trip, and resends at most
/// half of what goes out first.
- (void)resendVideo:(const uint16_t *)sequences count:(int)count {
	double now = [NSDate timeIntervalSinceReferenceDate];
	double spacing = MAX(_videoRtt, 0.1);
	@synchronized (_videoLock){
		[self rollVideoWindow:now];
		for (int i = 0; i < count; i++){
			unsigned slot = sequences[i] % kVideoHistory;
			if (_videoHistorySeq[slot] != sequences[i] || !_videoHistoryLength[slot])
				continue;
			if (now - _videoResentAt[slot] < spacing ||
			    _videoResentBytes + _videoHistoryLength[slot] > _videoSentBytes / 2 + kVideoHistorySlot)
				continue;
			_videoResentAt[slot] = now;
			_videoResentBytes += _videoHistoryLength[slot];
			if (self.sendMedia)
				self.sendMedia(_videoHistory + slot * kVideoHistorySlot, _videoHistoryLength[slot]);
			_videoResent++;
		}
	}
	if (_videoResent && (_videoResent < 4 || _videoResent % 50 == 0))
		NSLog(@"TGCallV2: %u video packets sent again on NACK", _videoResent);
}

- (void)rollVideoWindow:(double)now {
	if (now - _videoWindowStart < 1.0)
		return;
	_videoWindowStart = now;
	_videoSentBytes = _videoResentBytes = 0;
}

/// One compound RTCP packet: our receiver report, then a PLI when asked.
- (void)sendRtcpWithPli:(BOOL)pli {
	if (!self.haveKeys || self.failed)
		return;
	@synchronized (_rtcpLock){
		size_t length = TGRtcpWriteReceiverReport(_rtcpOut, sizeof(_rtcpOut) - 32,
		                                          self.localSsrc, _stats, 2);
		if (!length)
			return;
		uint32_t videoSsrc = _peerVideoSsrc;
		if (pli && videoSsrc)
			length += TGRtcpWritePli(_rtcpOut + length, sizeof(_rtcpOut) - 32 - length,
			                         self.localSsrc, videoSsrc);
		int cap = self.remoteVideoCapKbps;
		if (cap > 0 && videoSsrc)
			length += TGRtcpWriteRemb(_rtcpOut + length, sizeof(_rtcpOut) - 32 - length,
			                          self.localSsrc, videoSsrc, (uint32_t)cap * 1000);
		size_t protectedLength = 0;
		if (TGSrtcpProtect(&_sendRtcp, _rtcpOut, length, sizeof(_rtcpOut),
		                   ++_srtcpIndex, &protectedLength) != 0)
			return;
		if (self.sendMedia)
			self.sendMedia(_rtcpOut, protectedLength);
	}
}

- (void)sendNackFrom:(uint16_t)first count:(uint16_t)count {
	uint32_t videoSsrc = _peerVideoSsrc;
	if (!self.haveKeys || self.failed || !videoSsrc)
		return;
	if (count > 64)
		count = 64;
	@synchronized (_rtcpLock){
		size_t length = TGRtcpWriteReceiverReport(_rtcpOut, sizeof(_rtcpOut) - 32,
		                                          self.localSsrc, _stats, 2);
		size_t nack = TGRtcpWriteNack(_rtcpOut + length, sizeof(_rtcpOut) - 32 - length,
		                              self.localSsrc, videoSsrc, first, count);
		if (!length || !nack)
			return;
		size_t protectedLength = 0;
		if (TGSrtcpProtect(&_sendRtcp, _rtcpOut, length + nack, sizeof(_rtcpOut),
		                   ++_srtcpIndex, &protectedLength) != 0)
			return;
		if (self.sendMedia)
			self.sendMedia(_rtcpOut, protectedLength);
	}
	double now = [NSDate timeIntervalSinceReferenceDate];
	for (uint16_t i = 0; i < count; i++){
		uint16_t seq = (uint16_t)(first + i);
		_nackSeq[seq % 64] = seq;
		_nackAt[seq % 64] = now;
	}
	if (++_nacksSent < 4 || _nacksSent % 20 == 0)
		NSLog(@"TGCallV2: NACK %u for %u packets from %u, round trip %.0f ms",
		      _nacksSent, count, first, _videoRtt * 1000);
}

- (void)requestKeyframe {
	NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
	@synchronized (_rtcpLock){
		// The keyframe needs a round trip and then its own packets to come
		// in; asking again sooner only gets a second big frame on a link
		// already short of room.
		if (now - _lastKeyframeRequest < MAX(kKeyframeRequestInterval, _videoRtt * 2))
			return;
		_lastKeyframeRequest = now;
	}
	[self sendRtcpWithPli:YES];
}

#pragma mark - Receiving

- (void)handlePacket:(const uint8_t *)bytes length:(size_t)length {
	if (!bytes || length < 1 || self.failed)
		return;
	uint8_t first = bytes[0];
	if (first >= 20 && first <= 25){
		// A DTLS record. The handshake runs on this thread, the reflector
		// reader, never the main thread.
		@synchronized (_dtlsLock){
			[self.dtls feed:bytes length:length];
		}
		return;
	}
	if ((first & 0xC0) != 0x80 || !self.haveKeys || length < 12 ||
	    length > sizeof(_receive))
		return;

	uint8_t payloadType = bytes[1] & 0x7F;
	memcpy(_receive, bytes, length);
	size_t plainLength = 0;
	if (payloadType >= 64 && payloadType <= 95){
		// RTCP (192..223 with the marker bit folded in by the mask).
		if (TGSrtcpUnprotect(&_receiveRtcp, _receive, length, &plainLength) != 0){
			if (++_srtcpFailuresIn == 1)
				NSLog(@"TGCallV2: SRTCP did not authenticate (len %lu)", (unsigned long)length);
			return;
		}
		uint8_t fraction = 0;
		uint32_t lost = 0;
		if (TGRtcpLossFor(_receive, plainLength, self.localSsrc, &fraction, &lost) && self.onAudioSendLoss)
			self.onAudioSendLoss(fraction);
		if (self.localVideoSsrc &&
		    TGRtcpLossFor(_receive, plainLength, self.localVideoSsrc, &fraction, &lost)){
			if (self.onSendLoss)
				self.onSendLoss(fraction);
			if (lost != _videoLostReported){
				_videoLostReported = lost;
				NSLog(@"TGCallV2: peer lost %u of our video packets (%u/256 lately)", lost, fraction);
			}
		}
		uint16_t nacked[64];
		int nackCount = self.localVideoSsrc
			? TGRtcpNackedSequences(_receive, plainLength, self.localVideoSsrc, nacked, 64) : 0;
		if (nackCount)
			[self resendVideo:nacked count:nackCount];
		if (self.localVideoSsrc &&
		    TGRtcpAsksForKeyframe(_receive, plainLength, self.localVideoSsrc)){
			NSLog(@"TGCallV2: peer asked for a keyframe");
			if (self.onKeyframeRequest)
				self.onKeyframeRequest();
		}
		return;
	}

	uint32_t ssrc = ((uint32_t)bytes[8] << 24) | ((uint32_t)bytes[9] << 16) |
	                ((uint32_t)bytes[10] << 8) | bytes[11];
	uint16_t seq = (uint16_t)((bytes[2] << 8) | bytes[3]);
	uint32_t videoSsrc = _peerVideoSsrc;
	uint32_t audioSsrc = _peerAudioSsrc;
	BOOL isVideo = videoSsrc && ssrc == videoSsrc;
	if (!isVideo && audioSsrc && ssrc != audioSsrc)
		return;   // a stream we did not take: retransmissions, probes

	TGSrtpContext *context = isVideo ? &_receiveVideo : &_receiveAudio;
	if (TGSrtpUnprotect(context, _receive, length, &plainLength) != 0){
		if (++_srtpFailuresIn == 1 || _srtpFailuresIn % 50 == 0)
			NSLog(@"TGCallV2: %u SRTP packets did not authenticate (len %lu pt %u ssrc %u)",
			      _srtpFailuresIn, (unsigned long)length, payloadType, ssrc);
		return;
	}
	_srtpBytesIn += length;
	if (++_srtpPacketsIn == 1 || _srtpPacketsIn % 100 == 0)
		NSLog(@"TGCallV2: %u SRTP packets in, %llu KB", _srtpPacketsIn, _srtpBytesIn / 1024);

	@synchronized (_rtcpLock){
		TGRtpStatsUpdate(&_stats[isVideo ? 1 : 0], ssrc, seq);
	}
	if (isVideo){
		uint16_t nackFrom = 0, nackCount = 0;
		double now = [NSDate timeIntervalSinceReferenceDate];
		unsigned slot = seq % 64;
		// A resend we asked for: the time since the NACK is one round trip,
		// counted even when it came too late to use.
		if (_nackAt[slot] > 0 && _nackSeq[slot] == seq){
			double sample = now - _nackAt[slot];
			_nackAt[slot] = 0;
			_videoRtt = _videoRtt > 0 ? _videoRtt * 0.875 + sample * 0.125 : sample;
		}
		double patience = _videoRtt * 2.5 + 0.05;
		patience = patience < kVideoPatienceMin ? kVideoPatienceMin
		         : patience > kVideoPatienceMax ? kVideoPatienceMax : patience;
		TGVideoReorderResult result = TGVideoReorderPush(_reorder, _receive, plainLength,
				now, patience,
				TGV2DeliverVideo, (__bridge void *)self, &nackFrom, &nackCount);
		if (result == TGVideoReorderAskAgain)
			[self sendNackFrom:nackFrom count:nackCount];
		else if (result == TGVideoReorderNothing && _videoRtt > 0 &&
		         TGVideoReorderMissing(_reorder, &nackFrom, &nackCount) &&
		         now - _nackAt[nackFrom % 64] > MAX(_videoRtt * 1.2, 0.08) && _nackAt[nackFrom % 64] > 0)
			[self sendNackFrom:nackFrom count:nackCount];
		else if (result == TGVideoReorderGaveUp){
			if (++_videoGapsIn == 1 || _videoGapsIn % 10 == 0)
				NSLog(@"TGCallV2: %u holes in the peer's video were not filled", _videoGapsIn);
			[self requestKeyframe];
		}
	} else if (self.onAudio){
		self.onAudio(_receive, plainLength);
	}
}

#pragma mark - Timer

- (void)tick {
	if (self.failed)
		return;
	NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
	@synchronized (_dtlsLock){
		if (!self.haveKeys)
			[self.dtls handleTimeout];
		else
			TGSctpTick(&_sctp, now);
	}
	if (self.haveKeys && now - _lastReport >= kReportInterval){
		_lastReport = now;
		[self sendRtcpWithPli:NO];
	}
	for (NSUInteger i = 0; i < self.pending.count; ){
		NSDictionary *entry = self.pending[i];
		NSTimeInterval sent = [entry[@"time"] doubleValue];
		if (now - sent < kResendInterval){
			i++;
			continue;
		}
		uint32_t seq = [entry[@"seq"] unsignedIntValue];
		NSData *data = entry[@"data"];
		if (self.sendSignaling)
			self.sendSignaling(data, seq);
		[self.pending replaceObjectAtIndex:i withObject:@{
			@"seq" : @(seq),
			@"data" : data,
			@"time" : @(now),
		}];
		i++;
	}
	if (!self.haveKeys && now - self.startedAt > kGiveUpInterval)
		[self fail:@"no DTLS after 25 s"];
}

- (void)fail:(NSString *)reason {
	if (self.failed)
		return;
	self.failed = YES;
	NSLog(@"TGCallV2: failed: %@", reason);
	[self.timer invalidate];
	self.timer = nil;
	dispatch_async(dispatch_get_main_queue(), ^{
		if (self.onFailure)
			self.onFailure(reason);
	});
}

- (void)stop {
	self.failed = YES;
	[self.timer invalidate];
	self.timer = nil;
	[self.pending removeAllObjects];
	@synchronized (_dtlsLock){
		_sctp.send = NULL;
		_sctp.onMessage = NULL;
		_sctp.onOpen = NULL;
		[self.dtls stop];
		self.dtls = nil;
	}
	self.haveKeys = NO;
	self.onEstablished = nil;
	self.onFailure = nil;
	self.onAudio = nil;
	self.onVideo = nil;
	self.onVideoLoss = nil;
	self.onKeyframeRequest = nil;
	self.onPeerMediaState = nil;
	self.onVideoCodecs = nil;
	self.sendSignaling = nil;
	self.sendMedia = nil;
	self.onRemoteCandidates = nil;
	self.onPeerCredentials = nil;
}

@end
