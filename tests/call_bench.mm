// tests/call_bench.mm - our TGCall on this Mac against the real tgcalls library, over a
// real Telegram reflector. call_sim talks to TGCallPeer, our own copy of the protocol,
// which can only agree with us. This one talks to tgcalls_cli --mode bridge, the code the
// mobile client runs, and reports what each side heard. Run through scripts/call_bench.sh.
#import <Foundation/Foundation.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <opus.h>
#include <sys/socket.h>
#include <unistd.h>
#include <math.h>
#include <poll.h>
#include <pthread.h>

#include "TGCallPlayout.h"

#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>

#import "TGCall.h"
#import "TGCallAudioEngine.h"
#import "TGCallV2Session.h"
#import "TGCallVideoEngine.h"
#import "TGClient.h"

@interface TGCall ()
- (void)sendOutgoingAudioFrame:(NSData *)opusFrame;
- (void)handleSignalingData:(NSData *)data;
- (void)handleUpdate:(NSDictionary *)call;
@end

@interface TGCallAudioEngine (Testing)
+ (NSArray<NSData *> *)receivedFrames;
+ (NSArray<NSArray *> *)receivedArrivals;
@end

@interface TGClient (Testing)
+ (NSArray<NSDictionary *> *)sentRequests;
@end

static NSData *TGHexDecode(NSString *hex) {
	NSMutableData *out = [NSMutableData data];
	for (NSUInteger i = 0; i + 1 < hex.length; i += 2){
		unsigned value = 0;
		[[NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(i, 2)]] scanHexInt:&value];
		uint8_t byte = (uint8_t)value;
		[out appendBytes:&byte length:1];
	}
	return out;
}

static NSString *TGArgument(int argc, const char **argv, const char *name) {
	for (int i = 1; i + 1 < argc; i++)
		if (!strcmp(argv[i], name))
			return @(argv[i + 1]);
	return nil;
}

static int64_t TGNowMs(void) {
	return (int64_t)([NSProcessInfo processInfo].systemUptime * 1000.0);
}

// A bad phone network between us and the reflector, both ways: random loss,
// a fixed delay plus jitter (in order, as a cellular link delivers), and a
// rate cap with a 300 ms queue that drops what does not fit. The far side
// keeps its clean path, so whatever breaks is ours to handle.
typedef struct {
	double loss;
	int delayMs, jitterMs, rateKbps;
	// A phone moving from Wi-Fi to 3G: at switchAtMs into the call nothing
	// gets through for outageMs, then the reflector hears us from a new
	// address (a new socket, a new port).
	int switchAtMs, outageMs;
} TGImpairment;

typedef struct {
	int64_t due;
	int toReflector;
	size_t length;
	uint8_t data[1600];
} TGRelayPacket;

typedef struct {
	TGImpairment impairment;
	int clientFd, upstreamFd;
	struct sockaddr_in reflector, client;
	int haveClient;
	int64_t lastDue[2], linkFree[2];
	unsigned passed[2], dropped[2];
	TGRelayPacket queue[4096];
	int queued;
	int64_t startedMs;
	int switched;
} TGRelay;

/// In the outage: nothing through. At its end: a new upstream socket.
static int TGRelayInOutage(TGRelay *r, int64_t now) {
	TGImpairment *im = &r->impairment;
	if (!im->switchAtMs || r->switched == 2)
		return 0;
	int64_t at = r->startedMs + im->switchAtMs;
	if (now < at)
		return 0;
	if (now < at + im->outageMs){
		if (!r->switched){
			r->switched = 1;
			fprintf(stderr, "RELAY network switch: %d ms of nothing from now\n", im->outageMs);
		}
		return 1;
	}
	close(r->upstreamFd);
	r->upstreamFd = socket(AF_INET, SOCK_DGRAM, 0);
	r->switched = 2;
	r->queued = 0;
	fprintf(stderr, "RELAY network switch: back, from a new port\n");
	return 0;
}

static void TGRelayEnqueue(TGRelay *r, int toReflector, const uint8_t *data, size_t length) {
	TGImpairment *im = &r->impairment;
	if (TGRelayInOutage(r, TGNowMs())){
		r->dropped[toReflector]++;
		return;
	}
	if (im->loss > 0 && arc4random_uniform(10000) < im->loss * 100){
		r->dropped[toReflector]++;
		return;
	}
	int64_t now = TGNowMs();
	int64_t due = now + im->delayMs + (im->jitterMs ? arc4random_uniform((uint32_t)im->jitterMs + 1) : 0);
	if (im->rateKbps){
		int64_t start = r->linkFree[toReflector] > now ? r->linkFree[toReflector] : now;
		if (start - now > 300){
			r->dropped[toReflector]++;
			return;
		}
		r->linkFree[toReflector] = start + (int64_t)(length * 8) / im->rateKbps;
		if (due < r->linkFree[toReflector] + im->delayMs)
			due = r->linkFree[toReflector] + im->delayMs;
	}
	if (due < r->lastDue[toReflector])
		due = r->lastDue[toReflector];
	r->lastDue[toReflector] = due;
	if (r->queued == 4096 || length > sizeof(r->queue[0].data)){
		r->dropped[toReflector]++;
		return;
	}
	TGRelayPacket *p = &r->queue[r->queued++];
	p->due = due;
	p->toReflector = toReflector;
	p->length = length;
	memcpy(p->data, data, length);
}

static void *TGRelayRun(void *context) {
	TGRelay *r = (TGRelay *)context;
	uint8_t buffer[2048];
	for (;;){
		int64_t now = TGNowMs(), wait = 50;
		for (int i = 0; i < r->queued;){
			TGRelayPacket *p = &r->queue[i];
			if (p->due <= now){
				if (p->toReflector)
					sendto(r->upstreamFd, p->data, p->length, 0, (struct sockaddr *)&r->reflector, sizeof(r->reflector));
				else if (r->haveClient)
					sendto(r->clientFd, p->data, p->length, 0, (struct sockaddr *)&r->client, sizeof(r->client));
				r->passed[p->toReflector]++;
				*p = r->queue[--r->queued];
				continue;
			}
			if (p->due - now < wait)
				wait = p->due - now;
			i++;
		}
		struct pollfd fds[2] = {{r->clientFd, POLLIN, 0}, {r->upstreamFd, POLLIN, 0}};
		if (poll(fds, 2, (int)wait) <= 0)
			continue;
		if (fds[0].revents & POLLIN){
			socklen_t size = sizeof(r->client);
			ssize_t n = recvfrom(r->clientFd, buffer, sizeof(buffer), 0, (struct sockaddr *)&r->client, &size);
			r->haveClient = 1;
			if (n > 0)
				TGRelayEnqueue(r, 1, buffer, (size_t)n);
		}
		if (fds[1].revents & POLLIN){
			ssize_t n = recv(r->upstreamFd, buffer, sizeof(buffer), 0);
			if (n > 0)
				TGRelayEnqueue(r, 0, buffer, (size_t)n);
		}
	}
	return NULL;
}

/// Starts the relay and returns the local port that stands in for the reflector.
static int TGRelayStart(TGRelay *r, NSString *host, int port) {
	r->clientFd = socket(AF_INET, SOCK_DGRAM, 0);
	r->upstreamFd = socket(AF_INET, SOCK_DGRAM, 0);
	struct sockaddr_in local = {0};
	local.sin_family = AF_INET;
	local.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
	if (bind(r->clientFd, (struct sockaddr *)&local, sizeof(local)) != 0)
		return -1;
	socklen_t size = sizeof(local);
	getsockname(r->clientFd, (struct sockaddr *)&local, &size);
	r->reflector.sin_family = AF_INET;
	r->reflector.sin_port = htons((uint16_t)port);
	inet_pton(AF_INET, host.UTF8String, &r->reflector.sin_addr);
	r->startedMs = TGNowMs();
	pthread_t thread;
	pthread_create(&thread, NULL, TGRelayRun, r);
	return ntohs(local.sin_port);
}

/// What the speaker would have played: every arrival replayed at its own time
/// through the real playout buffer, pulled at 20 ms like the audio unit does,
/// decoded with FEC and concealment. Gaps are 10 ms blocks after playout
/// started whose energy fell under 1% of the median block: what a listener
/// hears as a dropout.
static void TGReportPlayout(int expandLoss) {
	NSArray *frames = [TGCallAudioEngine receivedFrames];
	NSArray *arrivals = [TGCallAudioEngine receivedArrivals];
	if (!arrivals.count){
		printf("OURS_PLAYOUT none\n");
		return;
	}
	if (getenv("CALL_BENCH_ARRIVALS") && expandLoss){
		int modes[3] = {0, 0, 0};
		for (NSData *f in frames){
			int config = ((const uint8_t *)f.bytes)[0] >> 3;
			modes[config < 12 ? 0 : config < 16 ? 1 : 2]++;
		}
		fprintf(stderr, "OPUS_MODES silk=%d hybrid=%d celt=%d\n", modes[0], modes[1], modes[2]);
	}
	if (getenv("CALL_BENCH_ARRIVALS") && expandLoss)
		for (NSArray *a in arrivals)
			fprintf(stderr, "ARRIVAL %d %u %lld\n", [a[0] intValue], [a[1] unsignedIntValue], [a[2] longLongValue]);
	int error = 0;
	OpusDecoder *decoder = opus_decoder_create(48000, 1, &error);
	TGJitter *jitter = TGJitterCreate();
	static TGJitterOut step;
	int64_t t = [arrivals[0][2] longLongValue], end = [arrivals.lastObject[2] longLongValue];
	// The engine before the playout buffer: decode on arrival into an
	// 8192-sample ring, play 20 ms every 20 ms, silence when it runs dry.
	unsigned naiveGaps = 0;
	{
		OpusDecoder *naive = opus_decoder_create(48000, 1, &error);
		long ring = 0, naiveStarted = 0;
		NSUInteger at = 0;
		for (int64_t now = t; now <= end; now += 20){
			for (; at < arrivals.count && [arrivals[at][2] longLongValue] <= now; at++){
				NSData *frame = frames[at];
				opus_int16 pcm[5760];
				int n = opus_decode(naive, (const unsigned char *)frame.bytes, (opus_int32)frame.length, pcm, 5760, 0);
				if (n > 0)
					ring = ring + n > 8192 ? 8192 : ring + n;
				naiveStarted = 1;
			}
			if (!naiveStarted)
				continue;
			long take = ring < 960 ? ring : 960;
			naiveGaps += (unsigned)((960 - take) / 480);
			ring -= take;
		}
		opus_decoder_destroy(naive);
	}
	NSUInteger next = 0;
	static TGExpand expand;
	TGExpandInit(&expand);
	NSMutableData *played = [NSMutableData data];
	NSMutableData *actions = [NSMutableData data];
	size_t residue = 0;
	int started = 0;
	long long targetSum = 0, targetSamples = 0;
	for (; t <= end; t += 20){
		for (; next < arrivals.count && [arrivals[next][2] longLongValue] <= t; next++){
			NSData *frame = frames[next];
			int samples = opus_packet_get_nb_samples((const unsigned char *)frame.bytes, (opus_int32)frame.length, 48000);
			TGJitterPut(jitter, (uint16_t)[arrivals[next][0] intValue], (uint32_t)[arrivals[next][1] unsignedIntValue],
			            samples, (const uint8_t *)frame.bytes, frame.length, [arrivals[next][2] longLongValue]);
		}
		while (residue < 960){
			opus_int16 pcm[5760];
			int n = 0;
			if (expandLoss){
				TGJitterAction action;
				n = TGPlayoutStep(jitter, decoder, &expand, pcm, &action);
				step.action = action;
			} else if ((TGJitterPull(jitter, &step), step.action == TGJitterPlay))
				n = opus_decode(decoder, step.payload, (opus_int32)step.length, pcm, 5760, 0);
			else if (step.action == TGJitterFec)
				n = opus_decode(decoder, step.payload, (opus_int32)step.length, pcm, step.samples, 1);
			else if (step.action == TGJitterConceal)
				n = opus_decode(decoder, NULL, 0, pcm, step.samples, 0);
			if (n <= 0){
				n = step.samples > 0 ? step.samples : 960;
				memset(pcm, 0, sizeof(opus_int16) * (size_t)n);
			}
			if (step.action == TGJitterPlay)
				started = 1;
			if (started){
				[played appendBytes:pcm length:sizeof(opus_int16) * (size_t)n];
				// What each stretch of the output was made from, for CALL_BENCH_PCM.
				for (int k = 0; k + 480 <= n; k += 480)
					[actions appendBytes:"SPFC" + step.action length:1];
			}
			residue += (size_t)n;
		}
		residue -= 960;
		targetSum += TGJitterTargetMs(jitter);
		targetSamples++;
	}
	const opus_int16 *pcm = (const opus_int16 *)played.bytes;
	size_t blocks = played.length / sizeof(opus_int16) / 480;
	double *energy = (double *)calloc(blocks ? blocks : 1, sizeof(double));
	for (size_t b = 0; b < blocks; b++)
		for (int i = 0; i < 480; i++)
			energy[b] += (double)pcm[b * 480 + i] * pcm[b * 480 + i];
	double *sorted = (double *)malloc(sizeof(double) * (blocks ? blocks : 1));
	memcpy(sorted, energy, sizeof(double) * blocks);
	qsort_b(sorted, blocks, sizeof(double), ^int(const void *a, const void *b){
		double x = *(const double *)a, y = *(const double *)b;
		return x < y ? -1 : x > y;
	});
	double floor = blocks ? sorted[blocks / 2] * 0.01 : 0;
	unsigned gaps = 0;
	for (size_t b = 0; b < blocks; b++)
		gaps += energy[b] < floor;
	if (getenv("CALL_BENCH_PCM") && expandLoss){
		// Raw s16le 48 kHz of what was played, and one letter per 10 ms block
		// for what made it: S silence, P played, F FEC, C concealed.
		[played writeToFile:@(getenv("CALL_BENCH_PCM")) atomically:NO];
		[actions writeToFile:[@(getenv("CALL_BENCH_PCM")) stringByAppendingString:@".steps"] atomically:NO];
	}
	TGJitterStats stats = TGJitterGetStats(jitter);
	printf("OURS_PLAYOUT%s packets=%lu played=%u fec=%u concealed=%u late=%u trimmed=%u rebuffers=%u gaps_ms=%u delay_ms=%lld old_engine_gaps_ms=%u\n",
	       expandLoss ? "" : "_OPUS_PLC", (unsigned long)arrivals.count, stats.played, stats.fec, stats.concealed, stats.late, stats.dropped,
	       stats.rebuffers, gaps * 10, targetSamples ? targetSum / targetSamples : 0, naiveGaps * 10);
	free(energy);
	free(sorted);
	TGJitterFree(jitter);
	opus_decoder_destroy(decoder);
}

int main(int argc, const char *argv[]) {
	@autoreleasepool {
		NSString *role = TGArgument(argc, argv, "--role");
		NSString *version = TGArgument(argc, argv, "--version");
		NSArray *reflector = [TGArgument(argc, argv, "--reflector") componentsSeparatedByString:@":"];
		int signalPort = [TGArgument(argc, argv, "--signal-port") intValue];
		int duration = [TGArgument(argc, argv, "--duration") intValue];
		NSData *key = TGHexDecode(TGArgument(argc, argv, "--key-hex"));
		NSData *tag = TGHexDecode(TGArgument(argc, argv, "--tag-hex"));
		BOOL outgoing = [role isEqualToString:@"caller"];
		// The negative control: what the far meter reads when we send nothing.
		BOOL silent = [TGArgument(argc, argv, "--silent") isEqualToString:@"1"];
		// Camera on from the start, fed with frames drawn here instead of the
		// Mac's camera, and every frame the far side sends us decoded.
		BOOL video = [TGArgument(argc, argv, "--video") isEqualToString:@"1"];
		// An iOS 7 phone either way: H.264 through VideoToolbox, which iOS 7
		// has though it is not public; --codec vp8 plays one without it.
		BOOL vp8 = [TGArgument(argc, argv, "--codec") isEqualToString:@"vp8"];
		if (video)
			setenv("TG_SHIM_IOS", "7.1.2", 1);
		if (vp8)
			setenv("TG_SHIM_NO_VIDEOTOOLBOX", "1", 1);
		static TGRelay relay;
		relay.impairment.loss = [TGArgument(argc, argv, "--loss") doubleValue];
		relay.impairment.delayMs = [TGArgument(argc, argv, "--delay") intValue];
		relay.impairment.jitterMs = [TGArgument(argc, argv, "--jitter") intValue];
		relay.impairment.rateKbps = [TGArgument(argc, argv, "--rate") intValue];
		relay.impairment.switchAtMs = [TGArgument(argc, argv, "--switch-at") intValue];
		relay.impairment.outageMs = [TGArgument(argc, argv, "--outage") intValue];
		NSString *reflectorHost = reflector[0];
		int reflectorPort = [reflector[1] intValue];
		if (relay.impairment.loss > 0 || relay.impairment.delayMs || relay.impairment.jitterMs || relay.impairment.rateKbps ||
		    relay.impairment.switchAtMs){
			reflectorPort = TGRelayStart(&relay, reflectorHost, reflectorPort);
			reflectorHost = @"127.0.0.1";
		}

		int fd = -1;
		struct sockaddr_in addr = {0};
		addr.sin_family = AF_INET;
		addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
		addr.sin_port = htons((uint16_t)signalPort);
		// A socket that failed to connect cannot be retried, so each attempt gets its own.
		for (int attempt = 0; ; attempt++){
			fd = socket(AF_INET, SOCK_STREAM, 0);
			if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) == 0)
				break;
			close(fd);
			if (attempt > 50){
				perror("bench: connect");
				return 1;
			}
			usleep(100000);
		}

		__block unsigned signalingIn = 0, signalingOut = 0;
		dispatch_async(dispatch_get_global_queue(0, 0), ^{
			for (;;){
				uint32_t size = 0;
				if (recv(fd, &size, sizeof(size), MSG_WAITALL) != sizeof(size))
					return;
				NSMutableData *data = [NSMutableData dataWithLength:ntohl(size)];
				if (recv(fd, data.mutableBytes, data.length, MSG_WAITALL) != (ssize_t)data.length)
					return;
				dispatch_async(dispatch_get_main_queue(), ^{
					signalingIn++;
					[[TGCall shared] handleSignalingData:data];
				});
			}
		});

		[[TGCall shared] handleUpdate:@{
			@"@type" : @"call", @"id" : @(1), @"user_id" : @(42LL), @"is_outgoing" : @(outgoing),
			@"state" : @{
				@"@type" : @"callStateReady",
				@"encryption_key" : [key base64EncodedStringWithOptions:0],
				@"servers" : @[@{
					@"ip_address" : reflectorHost, @"port" : @(reflectorPort),
					@"type" : @{@"@type" : @"callServerTypeTelegramReflector",
								@"peer_tag" : [tag base64EncodedStringWithOptions:0]},
				}],
				@"protocol" : @{@"@type" : @"callProtocol", @"library_versions" : @[version]},
				// CALL_BENCH_P2P=1: P2P allowed, as a user who has not turned it off.
				@"allow_p2p" : @(getenv("CALL_BENCH_P2P") != NULL),
			},
		}];

		int error = 0;
		OpusEncoder *encoder = opus_encoder_create(48000, 1, OPUS_APPLICATION_VOIP, &error);
		// As TGCallAudioEngine sets it, so the far side hears what a phone sends.
		opus_encoder_ctl(encoder, OPUS_SET_BITRATE(24000));
		opus_encoder_ctl(encoder, OPUS_SET_INBAND_FEC(1));
		opus_encoder_ctl(encoder, OPUS_SET_PACKET_LOSS_PERC(10));
		__block uint64_t phase = 0;
		int packetSamples = 48 * (getenv("CALL_BENCH_PTIME") ? atoi(getenv("CALL_BENCH_PTIME")) : 60);
		opus_int16 pending[2880];
		int pendingCount = 0;
		__block unsigned framesOut = 0;
		__block NSUInteger forwarded = 0;
		NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:duration];
		// On a schedule, not a sleep after each frame: running 30% slow made the far
		// jitter buffer stretch the tone and read as a protocol fault.
		NSDate *nextFrame = [NSDate date];
		TGCall *call = [TGCall shared];
		TGCallV2Session *session = [call valueForKey:@"v2"];
		// CALL_BENCH_REMB=kbps: the ceiling an old phone would ask for.
		if (getenv("CALL_BENCH_REMB"))
			session.remoteVideoCapKbps = atoi(getenv("CALL_BENCH_REMB"));
		if (video){
			[call setValue:@YES forKey:@"videoActive"];
			[session setMediaStateMuted:NO videoActive:YES];
		}
		CVPixelBufferRef picture = NULL;
		CVPixelBufferCreate(kCFAllocatorDefault, 480, 640, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
		                    (__bridge CFDictionaryRef)@{ (id)kCVPixelBufferIOSurfacePropertiesKey : @{} }, &picture);
		unsigned tick = 0, videoFramesOut = 0;
		// Freezes: the longest stretch with no new decoded picture after the
		// first, and how many stretches went past 300 ms.
		unsigned lastDecoded = 0, freezes = 0, reconnectingTicks = 0;
		int64_t lastPicture = 0, longestFreeze = 0;
		while ([deadline timeIntervalSinceNow] > 0){
			@autoreleasepool {
				NSArray *sent = [TGClient sentRequests];
				for (; forwarded < sent.count; forwarded++){
					NSDictionary *request = sent[forwarded];
					if (![request[@"@type"] isEqualToString:@"sendCallSignalingData"])
						continue;
					NSData *data = [[NSData alloc] initWithBase64EncodedString:request[@"data"] options:0];
					uint32_t size = htonl((uint32_t)data.length);
					(void)!write(fd, &size, sizeof(size));
					(void)!write(fd, data.bytes, data.length);
					signalingOut++;
				}
				// 20 ms of a 1 kHz tone, so what the far side hears cannot be its own
				// 440 Hz; sent in packets of CALL_BENCH_PTIME ms (60 as the app).
				for (int i = 0; i < 960; i++, phase++)
					pending[pendingCount++] = (opus_int16)(6000.0 * sin(2.0 * M_PI * 1000.0 * phase / 48000.0));
				uint8_t packet[1275];
				opus_int32 size = 0;
				if (pendingCount >= packetSamples){
					size = opus_encode(encoder, pending, packetSamples, packet, sizeof(packet));
					pendingCount = 0;
				}
				if (size > 0 && !silent){
					[[TGCall shared] sendOutgoingAudioFrame:[NSData dataWithBytes:packet length:(NSUInteger)size]];
					framesOut++;
				}
				// 20 frames a second: every other audio tick at 50 per second
				// gives 25, every fifth skipped gives 20.
				if (video && picture && (++tick % 5) && (tick % 2) == 0){
					CVPixelBufferLockBaseAddress(picture, 0);
					uint8_t *luma = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(picture, 0);
					size_t stride = CVPixelBufferGetBytesPerRowOfPlane(picture, 0);
					for (size_t y = 0; y < 640; y++)
						memset(luma + y * stride, (int)((y + tick * 4) & 0xFF), 480);
					uint8_t *chroma = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(picture, 1);
					memset(chroma, 128, CVPixelBufferGetBytesPerRowOfPlane(picture, 1) * 320);
					CVPixelBufferUnlockBaseAddress(picture, 0);
					[call.videoEngine encodePixelBuffer:picture presentationTime:CMTimeMake(tick * 20, 1000)];
					videoFramesOut++;
				}
				if (video){
					unsigned decoded = call.videoEngine.decodedFrames;
					int64_t now = TGNowMs();
					if (decoded != lastDecoded){
						if (lastPicture && now - lastPicture > 300)
							freezes++;
						if (lastPicture && now - lastPicture > longestFreeze)
							longestFreeze = now - lastPicture;
						lastPicture = now;
						lastDecoded = decoded;
					}
				}
				reconnectingTicks += call.isReconnecting;
				nextFrame = [nextFrame dateByAddingTimeInterval:0.02];
				[[NSRunLoop mainRunLoop] runUntilDate:nextFrame];
			}
		}

		OpusDecoder *decoder = opus_decoder_create(48000, 1, &error);
		double energy = 0, power1000 = 0, power440 = 0;
		long long failed = 0;
		const double c1000 = 2.0 * cos(2.0 * M_PI * 1000.0 / 48000.0);
		const double c440 = 2.0 * cos(2.0 * M_PI * 440.0 / 48000.0);
		NSArray *frames = [TGCallAudioEngine receivedFrames];
		for (NSData *frame in frames){
			opus_int16 pcm[5760];
			int count = opus_decode(decoder, (const unsigned char *)frame.bytes, (opus_int32)frame.length, pcm, 5760, 0);
			if (count <= 0){
				failed++;
				continue;
			}
			// In 10 ms blocks, the same measure the far side uses: power at a frequency
			// as a share of all the energy. 1.0 is a pure tone.
			for (int start = 0; start + 480 <= count; start += 480){
				double a[2] = {0, 0}, b[2] = {0, 0};
				for (int i = start; i < start + 480; i++){
					energy += (double)pcm[i] * pcm[i];
					double next = pcm[i] + c1000 * a[0] - a[1];
					a[1] = a[0];
					a[0] = next;
					next = pcm[i] + c440 * b[0] - b[1];
					b[1] = b[0];
					b[0] = next;
				}
				power1000 += (a[0] * a[0] + a[1] * a[1] - c1000 * a[0] * a[1]) * 2.0 / 480;
				power440 += (b[0] * b[0] + b[1] * b[1] - c440 * b[0] * b[1]) * 2.0 / 480;
			}
		}
		printf("OURS_RESULT state=%ld signaling_in=%u signaling_out=%u tx_frames=%u rx_frames=%lu rx_bad=%lld rx_energy=%.0f share_1000hz=%.2f share_440hz=%.2f\n",
				(long)[TGCall shared].state, signalingIn, signalingOut, framesOut, (unsigned long)frames.count, failed,
				energy / 1e6, energy > 0 ? power1000 / energy : 0.0, energy > 0 ? power440 / energy : 0.0);
		if (video)
			printf("OURS_VIDEO tx_video_frames=%u rx_video_frames=%u peer_video_active=%d can_send=%d longest_freeze_ms=%lld freezes=%u\n",
			       videoFramesOut, call.videoEngine.decodedFrames, call.peerVideoActive, session.canSendVideo,
			       longestFreeze, freezes);
		TGReportPlayout(1);
		printf("OURS_NET_STATE reconnecting_ms=%u\n", reconnectingTicks * 20);
		TGReportPlayout(0);
		if (relay.clientFd)
			printf("OURS_NET up_passed=%u up_dropped=%u down_passed=%u down_dropped=%u\n",
			       relay.passed[1], relay.dropped[1], relay.passed[0], relay.dropped[0]);
		fflush(stdout);
		_exit(0);
	}
}
