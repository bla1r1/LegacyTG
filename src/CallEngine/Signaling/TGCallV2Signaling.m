#import "TGCallV2Signaling.h"

#include <string.h>

static uint32_t TGReadU32(const uint8_t *bytes) {
	return ((uint32_t)bytes[0] << 24) | ((uint32_t)bytes[1] << 16) |
	       ((uint32_t)bytes[2] << 8) | (uint32_t)bytes[3];
}

size_t TGV2ParsePlaintext(const uint8_t *bytes, size_t length,
                          uint32_t packetSeq, TGV2Slice *out, size_t maxSlices) {
	size_t at = 0, count = 0;
	uint32_t currentSeq = packetSeq;
	while (at < length && count < maxSlices){
		uint8_t type = bytes[at++];
		const uint8_t *body = NULL;
		size_t bodyLength = 0;
		if (type == 0x7F){
			if (length - at < 4)
				break;
			bodyLength = TGReadU32(bytes + at);
			at += 4;
			if (bodyLength > length - at)
				break;
			body = bytes + at;
			at += bodyLength;
		} else if (type == 0xFE || type == 0xFF){
			// An empty message carries nothing; an ack names its target in the
			// sequence number in front of it.
		} else {
			break;
		}
		out[count].type = type;
		out[count].seq = currentSeq;
		out[count].body = body;
		out[count].bodyLength = bodyLength;
		count++;
		if (length - at < 4)
			break;
		currentSeq = TGReadU32(bytes + at);
		at += 4;
	}
	return count;
}

@implementation TGCallV2Signaling

+ (NSData *)messageWithJSONObject:(NSDictionary *)json {
	NSData *payload = [NSJSONSerialization dataWithJSONObject:json options:0 error:nil];
	if (!payload)
		return nil;
	NSMutableData *out = [NSMutableData dataWithCapacity:payload.length + 5];
	uint8_t header[5];
	header[0] = 0x7F;
	uint32_t length = (uint32_t)payload.length;
	header[1] = (uint8_t)(length >> 24);
	header[2] = (uint8_t)(length >> 16);
	header[3] = (uint8_t)(length >> 8);
	header[4] = (uint8_t)length;
	[out appendBytes:header length:5];
	[out appendData:payload];
	return out;
}

+ (NSData *)ackForSeq:(uint32_t)seq {
	uint8_t bytes[6] = {
		0xFE,
		(uint8_t)(seq >> 24), (uint8_t)(seq >> 16),
		(uint8_t)(seq >> 8), (uint8_t)seq,
		0xFF,
	};
	return [NSData dataWithBytes:bytes length:sizeof(bytes)];
}

+ (NSData *)initialSetupWithUfrag:(NSString *)ufrag
                              pwd:(NSString *)pwd
                      fingerprint:(NSString *)fingerprint
                            setup:(NSString *)setup {
	NSDictionary *json = @{
		@"@type" : @"InitialSetup",
		@"fingerprints" : @[@{
			@"fingerprint" : fingerprint ?: @"",
			@"hash" : @"sha-256",
			@"setup" : setup ?: @"actpass",
		}],
		@"pwd" : pwd ?: @"",
		@"renomination" : @YES,
		@"ufrag" : ufrag ?: @"",
	};
	return [self messageWithJSONObject:json];
}

// No rtpExtensions anywhere: the peer then sends bare RTP, expects no
// transport-cc feedback, and without the video-orientation extension WebRTC
// rotates frames itself before encoding, so every picture arrives upright.
+ (NSDictionary *)audioContentWithSsrc:(uint32_t)ssrc payloadType:(int)payloadType {
	return @{
		@"type" : @"audio",
		@"ssrc" : [NSString stringWithFormat:@"%u", ssrc],
		@"payloadTypes" : @[@{
			@"id" : @(payloadType),
			@"name" : @"opus",
			@"clockrate" : @48000,
			@"channels" : @2,
		}],
	};
}

+ (NSDictionary *)audioContentWithSsrc:(uint32_t)ssrc {
	return [self audioContentWithSsrc:ssrc payloadType:111];
}

/// Keyframe requests, on top of NACK where the caller adds it. No REMB or
/// transport-cc: this client has no bandwidth estimate to report.
+ (NSArray *)videoFeedbackTypes {
	return @[
		@{ @"type" : @"nack", @"subtype" : @"pli" },
		@{ @"type" : @"ccm", @"subtype" : @"fir" },
	];
}

+ (NSArray *)ourVideoFeedback {
	// Our own stream also takes NACK: we keep what we sent and send it again.
	// Without it the peer waits up to 3 s for a keyframe after every lost
	// packet.
	return [@[@{ @"type" : @"nack", @"subtype" : @"" }]
	        arrayByAddingObjectsFromArray:[self videoFeedbackTypes]];
}

+ (NSDictionary *)videoContentWithSsrc:(uint32_t)ssrc {
	return [self videoContentWithSsrc:ssrc h264:YES];
}

+ (NSDictionary *)videoContentWithSsrc:(uint32_t)ssrc h264:(BOOL)h264 {
	// tgcalls builds the receive stream for video from ssrcGroups alone and
	// ignores "ssrc"; with no group it waits for an unsignalled stream that
	// never binds. Official always sends FID (media, retransmission), so we do
	// too. Nothing is ever sent on the second ssrc: no rtx payload is offered.
	NSString *media = [NSString stringWithFormat:@"%u", ssrc];
	NSString *rtx = [NSString stringWithFormat:@"%u", ssrc ^ 0x5A5A5A5Au];
	NSDictionary *vp8 = @{
		@"id" : @(TGV2VP8PayloadType),
		@"name" : @"VP8",
		@"clockrate" : @90000,
		@"channels" : @0,
		@"feedbackTypes" : [self ourVideoFeedback],
		@"parameters" : @{},
	};
	NSDictionary *h264Payload = @{
		@"id" : @(TGV2VideoPayloadType),
		@"name" : @"H264",
		@"clockrate" : @90000,
		@"channels" : @0,
		@"feedbackTypes" : [self ourVideoFeedback],
		@"parameters" : @{
			@"level-asymmetry-allowed" : @"1",
			@"packetization-mode" : @"1",
			@"profile-level-id" : @"42e01f",
		},
	};
	// In preference order: the answer keeps the ones the peer can decode, and
	// we send the first of those. Without VideoToolbox there is no H.264 to
	// offer at all.
	return @{
		@"type" : @"video",
		@"ssrc" : media,
		@"ssrcGroups" : @[@{ @"semantics" : @"FID", @"ssrcs" : @[media, rtx] }],
		@"payloadTypes" : h264 ? @[h264Payload, vp8] : @[vp8],
	};
}

+ (NSData *)negotiateWithExchangeId:(NSString *)exchangeId contents:(NSArray *)contents {
	return [self messageWithJSONObject:@{
		@"@type" : @"NegotiateChannels",
		@"contents" : contents ?: @[],
		@"exchangeId" : exchangeId ?: @"",
	}];
}

+ (NSData *)offerWithExchangeId:(NSString *)exchangeId ssrc:(uint32_t)ssrc {
	return [self negotiateWithExchangeId:exchangeId
	                            contents:@[[self audioContentWithSsrc:ssrc]]];
}

+ (NSData *)answerWithExchangeId:(NSString *)exchangeId ssrc:(uint32_t)ssrc {
	return [self negotiateWithExchangeId:exchangeId
	                            contents:@[[self audioContentWithSsrc:ssrc]]];
}

+ (NSDictionary *)h264PayloadIn:(NSDictionary *)content {
	NSArray *payloadTypes = content[@"payloadTypes"];
	if (![payloadTypes isKindOfClass:[NSArray class]])
		return nil;
	// Hardware decoders on every device this runs on take baseline; 42e0 is
	// constrained baseline, 4200 plain baseline. High profile (64..) and
	// packetization-mode 0 are left to the peer's other entries.
	NSDictionary *best = nil;
	for (NSDictionary *payload in payloadTypes){
		if (![payload isKindOfClass:[NSDictionary class]] ||
		    [[payload[@"name"] description] caseInsensitiveCompare:@"H264"] != NSOrderedSame)
			continue;
		NSDictionary *parameters = payload[@"parameters"];
		if (![parameters isKindOfClass:[NSDictionary class]])
			parameters = @{};
		NSString *mode = [parameters[@"packetization-mode"] description] ?: @"0";
		NSString *profile = [[parameters[@"profile-level-id"] description] lowercaseString] ?: @"42001f";
		if (![mode isEqualToString:@"1"] || ![profile hasPrefix:@"42"])
			continue;
		if (!best || [profile hasPrefix:@"42e0"])
			best = payload;
		if ([profile hasPrefix:@"42e0"])
			break;
	}
	return best;
}

+ (NSDictionary *)vp8PayloadIn:(NSDictionary *)content {
	NSArray *payloadTypes = content[@"payloadTypes"];
	if (![payloadTypes isKindOfClass:[NSArray class]])
		return nil;
	for (NSDictionary *payload in payloadTypes)
		if ([payload isKindOfClass:[NSDictionary class]] &&
		    [[payload[@"name"] description] caseInsensitiveCompare:@"VP8"] == NSOrderedSame)
			return payload;
	return nil;
}

+ (NSDictionary *)answerContentFor:(NSDictionary *)offered acceptVideo:(BOOL)acceptVideo {
	return [self answerContentFor:offered acceptVideo:acceptVideo preferH264:YES];
}

+ (NSDictionary *)answerContentFor:(NSDictionary *)offered acceptVideo:(BOOL)acceptVideo
                        preferH264:(BOOL)preferH264 {
	if (![offered isKindOfClass:[NSDictionary class]])
		return nil;
	id ssrc = offered[@"ssrc"];
	if (!ssrc)
		return nil;
	NSString *ssrcString = [ssrc description];
	NSString *type = offered[@"type"];
	if ([type isEqualToString:@"audio"]){
		int payloadType = 111;
		for (NSDictionary *payload in offered[@"payloadTypes"]){
			if ([payload isKindOfClass:[NSDictionary class]] &&
			    [[payload[@"name"] description] caseInsensitiveCompare:@"opus"] == NSOrderedSame){
				payloadType = [payload[@"id"] intValue];
				break;
			}
		}
		NSMutableDictionary *content = [[self audioContentWithSsrc:0 payloadType:payloadType] mutableCopy];
		content[@"ssrc"] = ssrcString;
		return content;
	}
	if (![type isEqualToString:@"video"] || !acceptVideo)
		return nil;
	// With VideoToolbox, H.264 first and VP8 if the peer has no baseline
	// H.264; without it, VP8 only.
	NSDictionary *chosen = preferH264 ? [self h264PayloadIn:offered] : nil;
	if (!chosen)
		chosen = [self vp8PayloadIn:offered];
	if (!chosen)
		return nil;
	NSMutableDictionary *payload = [chosen mutableCopy];
	// NACK makes the peer keep what it sent, so a hole can be filled before
	// the picture breaks; TGCallVideoReorder waits for it.
	// goog-remb: the peer takes our REMB as a ceiling, which is how an old
	// phone keeps it from sending a picture bigger than it can decode.
	payload[@"feedbackTypes"] = [@[@{ @"type" : @"nack", @"subtype" : @"" },
	                               @{ @"type" : @"goog-remb", @"subtype" : @"" }]
	                             arrayByAddingObjectsFromArray:[self videoFeedbackTypes]];
	NSMutableDictionary *content = [@{
		@"type" : @"video",
		@"ssrc" : ssrcString,
		@"payloadTypes" : @[payload],
	} mutableCopy];
	if ([offered[@"ssrcGroups"] isKindOfClass:[NSArray class]])
		content[@"ssrcGroups"] = offered[@"ssrcGroups"];
	return content;
}

+ (NSString *)mediaStateWithMuted:(BOOL)muted videoActive:(BOOL)videoActive {
	NSDictionary *json = @{
		@"@type" : @"MediaState",
		@"muted" : @(muted),
		@"lowBattery" : @NO,
		@"videoState" : videoActive ? @"active" : @"inactive",
		@"videoRotation" : @0,
		@"screencastState" : @"inactive",
	};
	NSData *data = [NSJSONSerialization dataWithJSONObject:json options:0 error:nil];
	return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

+ (NSData *)candidatesWithStrings:(NSArray *)candidates {
	NSMutableArray *items = [NSMutableArray arrayWithCapacity:candidates.count];
	for (NSString *candidate in candidates)
		[items addObject:@{ @"sdpString" : candidate }];
	return [self messageWithJSONObject:@{
		@"@type" : @"Candidates",
		@"candidates" : items,
	}];
}

@end
