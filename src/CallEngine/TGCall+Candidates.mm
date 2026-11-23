#import "TGCall+Internal.h"

#import "TGCallDirectPath.h"
#import "TGCallIce.h"
#import "TGCallReflector.h"
#import "TGCallV2Session.h"
#import "TGCallMessages.h"

@implementation TGCall (Candidates)

/// Our only route is the reflector, so that is the one candidate we offer -
/// a relay candidate pointing at it. The peer will send its checks there and
/// the reflector will hand them to us, because both ends share the tag.
- (void)sendOurCandidates {
	if (self.sentCandidates || !self.reflectorHost.length)
		return;
	self.sentCandidates = YES;

	self.localUfrag = self.localUfrag ?: [self randomIceStringOfLength:4];
	self.localPwd = self.localPwd ?: [self randomIceStringOfLength:24];

	self.ice = [[TGCallIce alloc] init];
	self.ice.controlling = !self.isV2 || self.outgoing;
	self.ice.localUfrag = self.localUfrag;
	self.ice.localPwd = self.localPwd;
	__weak __typeof__(self) weakSelf = self;
	self.ice.transport = ^(NSData *packet){
		TGCall *me = weakSelf;
		// An answer goes to the port that asked; anything else - our own
		// checks - goes to every tag the peer has shown us.
		uint32_t targetTag = me.nominatedSenderTag ?: me.currentSenderTag;
		if (targetTag){
			[me.currentReflector ?: me.reflector sendPayload:packet
													   toTag:targetTag];
			return;
		}
		for (TGCallReflector *reflector in me.reflectors)
			[reflector sendPayload:packet];
	};
	self.ice.onConnected = ^(NSString *address, uint16_t port){
		NSLog(@"TGCall: media path is %@:%u", address, port);
		// 9.0.0 is not usable until DTLS has produced SRTP keys; the session
		// calls back when that happens. Starting the engine here would play
		// audio before there is a key to decrypt it with.
		if (weakSelf.isV2){
			[weakSelf.v2 iceConnected];
			return;
		}
		weakSelf.state = TGCallStateEstablished;
		[weakSelf startAudioEngine];
	};
	[self.ice start];

	if (self.isV2){
		// 9.0.0 patches every relay candidate to component 1 and priority
		// 41877760 before serializing, and carries the candidate as JSON.
		NSMutableArray *v2Candidates = [NSMutableArray array];
		NSInteger v2Index = 0;
		for (TGCallReflector *reflector in self.reflectors){
			v2Index++;
			uint32_t serverId = reflector.serverId ?: (uint32_t)v2Index;
			NSString *hostname = [NSString stringWithFormat:@"reflector-%u-%u.reflector",
					serverId, reflector.localTag];
			[v2Candidates addObject:[NSString stringWithFormat:
					@"candidate:%u 1 udp 41877760 %@ %u typ relay generation 0 "
					@"ufrag %@ network-id 9 network-cost 50",
					reflector.localTag, hostname, reflector.port, self.localUfrag]];
		}
		[v2Candidates addObjectsFromArray:[self.direct hostCandidates] ?: @[]];
		[self.v2 sendCandidates:v2Candidates];
		NSLog(@"TGCallV2: sent our candidates, ufrag=%@", self.localUfrag);
		return;
	}

	// The address is a name rather than an IP: the peer reads our four-byte
	// tag out of it and uses that to address us through the reflector.
	NSMutableArray *candidates = [NSMutableArray array];
	NSInteger index = 0;
	for (TGCallReflector *reflector in self.reflectors){
		index++;
		uint32_t serverId = reflector.serverId ?: (uint32_t)index;
		NSString *hostname = [NSString stringWithFormat:@"reflector-%u-%u.reflector",
				serverId, reflector.localTag];
		// Written exactly the way the peer writes its own: component 0, no
		// raddr or rport. A line their parser rejects takes the whole message
		// with it, and then they never learn our credentials at all.
		[candidates addObject:[NSString stringWithFormat:
				@"candidate:%u 0 udp 41878272 %@ %u typ relay generation 0 "
				@"ufrag %@ network-id 9 network-cost 50",
				reflector.localTag, hostname, reflector.port, self.localUfrag]];
	}

	NSData *body = [TGCallMessages candidatesBody:candidates
											ufrag:self.localUfrag
											  pwd:self.localPwd];
	NSData *message = [TGCallMessages messageWithType:TGCallMessageCandidates body:body];
	[self sendSignalling:message
					 seq:[TGCallMessages markSeq:++self.signallingSeq requiresAck:YES]];
	NSLog(@"TGCall: sent our candidates, ufrag=%@", self.localUfrag);

	// Video runs over 9.0.0 only. An empty format list still has to go out:
	// the 5.0.0 peer waits for one before it moves on.
	uint8_t formats[2] = { 0, 0 };
	NSData *videoFormats = [TGCallMessages messageWithType:TGCallMessageVideoFormats
													  body:[NSData dataWithBytes:formats length:2]];
	[self sendSignalling:videoFormats
					 seq:[TGCallMessages markSeq:++self.signallingSeq requiresAck:YES]];
}

- (void)readPeerTagFromCandidate:(NSString *)candidate {
	NSRange marker = [candidate rangeOfString:@"reflector-"];
	if (marker.location == NSNotFound)
		return;

	NSString *tail = [candidate substringFromIndex:marker.location + marker.length];
	NSArray *parts = [[tail componentsSeparatedByString:@".reflector"][0]
			componentsSeparatedByString:@"-"];
	if (parts.count < 2)
		return;

	NSInteger reflectorIndex = [parts[0] integerValue] - 1;
	uint32_t tag = (uint32_t)[parts[1] longLongValue];
	if (!tag)
		return;

	if (reflectorIndex >= 0 && reflectorIndex < (NSInteger)self.reflectors.count){
		TGCallReflector *reflector = self.reflectors[reflectorIndex];
		reflector.remoteTag = tag;
	} else {
		for (TGCallReflector *reflector in self.reflectors)
			reflector.remoteTag = tag;
	}
	if (!self.currentSenderTag)
		self.currentSenderTag = tag;
	NSLog(@"TGCall: peer reflector tag %u (reflector %ld)", tag, (long)(reflectorIndex + 1));
}

@end
