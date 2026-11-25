//
// TGDevBench.m - see TGDevBench.h.
//
#import "TGDevBench.h"
#import "TGPerf.h"
#import "TGSampler.h"
#import <QuartzCore/QuartzCore.h>
#import <dlfcn.h>
#include <math.h>
#include <stdlib.h>
#include "TGCallVP8Codec.h"
#import <VideoToolbox/VideoToolbox.h>
#import "TGCallVideoEngine.h"
#import "TGCallAudioEngine.h"
#import <AVFoundation/AVFoundation.h>

/// A thumb flick on a 3.5" screen moves content about this fast; slower hides
/// the cell-creation cost, faster than this nobody scrolls a chat.
static const CGFloat kFlingPointsPerSecond = 1600.0f;
static const double kFrameSeconds = 1.0 / 60.0;
enum { kMaxFrames = 4096 };
static const double kOpenWatchSeconds = 2.5;
static const double kPopWatchSeconds = 1.0;

@protocol TGDevBenchChatActions <NSObject>
@optional
- (void)playVoiceNoteForMessage:(NSDictionary *)m atRow:(NSInteger)row;
- (void)playVideoNoteForMessage:(NSDictionary *)m atRow:(NSInteger)row;
- (void)stopPlayback;
- (void)recordStart;
- (void)recordCancel;
- (void)showActionsForRow:(NSInteger)row;
- (void)cancelTapped;
@end

@interface TGDevBench ()
@property (nonatomic, strong) CADisplayLink *link;
@property (nonatomic, weak) UIScrollView *scroll;
@property (nonatomic, copy) NSString *what;
@property (nonatomic, assign) BOOL profile;
@property (nonatomic, assign) double duration;
@property (nonatomic, assign) double start;
@property (nonatomic, assign) double last;
@property (nonatomic, assign) CGFloat direction;
@property (nonatomic, copy) void (^afterWatch)(void);
@end

/// The result lines also go to Caches/bench-results.txt: idevicesyslog
/// drops a run's lines now and then, and a lost run costs a minute.
static void TGBenchKeep(NSString *line) {
	NSLog(@"%@", line);
	NSString *caches = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
			NSUserDomainMask, YES) firstObject];
	NSString *path = [caches stringByAppendingPathComponent:@"bench-results.txt"];
	NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:path];
	if (!file) {
		[[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
		file = [NSFileHandle fileHandleForWritingAtPath:path];
	}
	[file seekToEndOfFile];
	[file writeData:[[line stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]];
	[file closeFile];
}

@implementation TGDevBench {
	double _frames[kMaxFrames];     // intervals in seconds
	unsigned _count;
	double _firstFrameMs;
}

static TGDevBench *sCurrent;
static UIViewController *frontController(UIWindow *window) {
	UIViewController *vc = window.rootViewController;
	for (;;) {
		if (vc.presentedViewController)
			vc = vc.presentedViewController;
		else if ([vc isKindOfClass:UITabBarController.class])
			vc = ((UITabBarController *)vc).selectedViewController;
		else if ([vc isKindOfClass:UINavigationController.class])
			vc = ((UINavigationController *)vc).topViewController;
		else
			return vc;
	}
}

/// The biggest visible scroll view: the chat's table, not the input bar's text view.
static UIScrollView *largestScroll(UIView *view) {
	UIScrollView *best = nil;
	CGFloat bestArea = 0;
	NSMutableArray *queue = [NSMutableArray arrayWithObject:view];
	while (queue.count) {
		UIView *v = queue[0];
		[queue removeObjectAtIndex:0];
		if (v.hidden || v.alpha < 0.01f)
			continue;
		if ([v isKindOfClass:UIScrollView.class] && ![v isKindOfClass:UITextView.class]) {
			CGFloat area = v.bounds.size.width * v.bounds.size.height;
			if (area > bestArea) {
				bestArea = area;
				best = (UIScrollView *)v;
			}
		}
		[queue addObjectsFromArray:v.subviews];
	}
	return best;
}

static NSString *cachesPath(NSString *name) {
	NSString *dir = NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
			NSUserDomainMask, YES)[0];
	return [dir stringByAppendingPathComponent:name];
}

/// A camera-like picture: a gradient panning sideways, a bright block
/// moving across it and some noise, so motion search has work to do.
static void TGDevBenchPicture(uint8_t *y, uint8_t *uv, int w, int h, int n) {
	uint32_t seed = (uint32_t)n * 2654435761u;
	for (int row = 0; row < h; row++)
		for (int col = 0; col < w; col++){
			seed = seed * 1103515245u + 12345u;
			int v = ((col + n * 3) & 0xFF) / 2 + row / 4 + (int)((seed >> 24) & 7);
			int bx = (n * 4) % w, by = (n * 2) % h;
			if (col >= bx && col < bx + w / 4 && row >= by && row < by + h / 4)
				v = 220;
			y[row * w + col] = (uint8_t)(v > 255 ? 255 : v);
		}
	for (int i = 0; i < w * h / 2; i += 2){
		uv[i] = (uint8_t)(128 + ((i / 2 + n) & 31) - 16);
		uv[i + 1] = (uint8_t)(128 - ((i / 3) & 15));
	}
}

static int sVTFrames, sVTBytes, sVTKeys, sVTDecoded;
static OSStatus sVTStatus, sVTDecodeStatus;
static NSMutableArray *sVTSamples;

static void TGDevBenchVTDecoded(void *ref, void *frameRef, OSStatus status, VTDecodeInfoFlags flags,
                                CVImageBufferRef image, CMTime pts, CMTime duration) {
	if (status == noErr && image)
		sVTDecoded++;
	else
		sVTDecodeStatus = status;
}

static void TGDevBenchVTOutput(void *ref, void *frameRef, OSStatus status,
                               VTEncodeInfoFlags flags, CMSampleBufferRef sample) {
	if (status != noErr || !sample){
		sVTStatus = status;
		return;
	}
	sVTFrames++;
	[sVTSamples addObject:(__bridge id)sample];
	sVTBytes += (int)CMSampleBufferGetTotalSampleSize(sample);
	CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sample, false);
	CFDictionaryRef first = attachments && CFArrayGetCount(attachments)
		? (CFDictionaryRef)CFArrayGetValueAtIndex(attachments, 0) : NULL;
	if (!first || !CFDictionaryContainsKey(first, kCMSampleAttachmentKey_NotSync))
		sVTKeys++;
}

/// Whether VideoToolbox's H.264 encoder runs on this iOS, and what a frame
/// costs: before iOS 8 the API is there but not public.
+ (void)videoToolboxBenchWidth:(int)w height:(int)h frames:(int)frames kbps:(int)kbps {
	if (!&VTCompressionSessionCreate || !&VTCompressionSessionEncodeFrame || !&VTSessionSetProperty){
		NSLog(@"[bench] codec vt: VTCompressionSessionCreate not linked on this iOS");
		return;
	}
	VTCompressionSessionRef session = NULL;
	sVTFrames = sVTBytes = sVTKeys = sVTDecoded = 0;
	sVTDecodeStatus = noErr;
	sVTSamples = [NSMutableArray array];
	sVTStatus = noErr;
	OSStatus status = VTCompressionSessionCreate(NULL, w, h, kCMVideoCodecType_H264, NULL, NULL, NULL,
	                                             TGDevBenchVTOutput, NULL, &session);
	if (status != noErr || !session){
		NSLog(@"[bench] codec vt %dx%d: VTCompressionSessionCreate failed %d", w, h, (int)status);
		return;
	}
	VTSessionSetProperty(session, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
	VTSessionSetProperty(session, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);
	VTSessionSetProperty(session, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef)@(kbps * 1000));
	CVPixelBufferRef picture = NULL;
	CVPixelBufferCreate(NULL, (size_t)w, (size_t)h, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
	                    (__bridge CFDictionaryRef)@{ (id)kCVPixelBufferIOSurfacePropertiesKey : @{} }, &picture);
	if (!picture){
		NSLog(@"[bench] codec vt: no pixel buffer");
		VTCompressionSessionInvalidate(session);
		CFRelease(session);
		return;
	}
	double start = CACurrentMediaTime();
	for (int n = 0; n < frames; n++){
		CVPixelBufferLockBaseAddress(picture, 0);
		TGDevBenchPicture((uint8_t *)CVPixelBufferGetBaseAddressOfPlane(picture, 0),
		                  (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(picture, 1), w, h, n);
		CVPixelBufferUnlockBaseAddress(picture, 0);
		status = VTCompressionSessionEncodeFrame(session, picture, CMTimeMake(n, 15), kCMTimeInvalid, NULL, NULL, NULL);
		if (status != noErr)
			break;
	}
	// Not on every iOS that has the rest; without it, wait for the callbacks.
	if (&VTCompressionSessionCompleteFrames)
		VTCompressionSessionCompleteFrames(session, kCMTimeInvalid);
	else
		[NSThread sleepForTimeInterval:1.0];
	double elapsed = CACurrentMediaTime() - start;
	if (sVTSamples.count){
		CFDictionaryRef atoms = (CFDictionaryRef)CMFormatDescriptionGetExtension(
				CMSampleBufferGetFormatDescription((__bridge CMSampleBufferRef)sVTSamples[0]),
				kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms);
		CFDataRef avcc = atoms ? (CFDataRef)CFDictionaryGetValue(atoms, CFSTR("avcC")) : NULL;
		const uint8_t *a = avcc ? CFDataGetBytePtr(avcc) : NULL;
		NSLog(@"[bench] codec vt profile %d constraints %02x level %d; constants: ProfileLevel %d Baseline_AutoLevel %d Baseline_3_1 %d RealTime %d AllowFrameReordering %d MaxKeyFrameInterval %d AverageBitRate %d ForceKeyFrame %d",
		      a ? a[1] : -1, a ? a[2] : 0, a ? a[3] : -1,
		      &kVTCompressionPropertyKey_ProfileLevel != NULL, &kVTProfileLevel_H264_Baseline_AutoLevel != NULL,
		      &kVTProfileLevel_H264_Baseline_3_1 != NULL, &kVTCompressionPropertyKey_RealTime != NULL,
		      &kVTCompressionPropertyKey_AllowFrameReordering != NULL, &kVTCompressionPropertyKey_MaxKeyFrameInterval != NULL,
		      &kVTCompressionPropertyKey_AverageBitRate != NULL, &kVTEncodeFrameOptionKey_ForceKeyFrame != NULL);
	}
	NSLog(@"[bench] codec vt h264 %dx%d %d kbps: %d of %d frames out, %d key, %.1f ms a frame wall, %d bytes a frame, encode status %d, callback status %d",
	      w, h, kbps, sVTFrames, frames, sVTKeys, elapsed * 1000 / frames,
	      sVTFrames ? sVTBytes / sVTFrames : 0, (int)status, (int)sVTStatus);
	VTCompressionSessionInvalidate(session);
	CFRelease(session);
	CVPixelBufferRelease(picture);

	// And back: what the call would do with the peer's H.264.
	if (!sVTSamples.count || !&VTDecompressionSessionCreate || !&VTDecompressionSessionDecodeFrame)
		return;
	CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription((__bridge CMSampleBufferRef)sVTSamples[0]);
	VTDecompressionOutputCallbackRecord callback = { TGDevBenchVTDecoded, NULL };
	VTDecompressionSessionRef decoder = NULL;
	status = VTDecompressionSessionCreate(NULL, format, NULL,
	        (__bridge CFDictionaryRef)@{ (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) },
	        &callback, &decoder);
	if (status != noErr || !decoder){
		NSLog(@"[bench] codec vt decode: VTDecompressionSessionCreate failed %d", (int)status);
		return;
	}
	start = CACurrentMediaTime();
	for (id sample in sVTSamples)
		VTDecompressionSessionDecodeFrame(decoder, (__bridge CMSampleBufferRef)sample, 0, NULL, NULL);
	if (&VTDecompressionSessionWaitForAsynchronousFrames)
		VTDecompressionSessionWaitForAsynchronousFrames(decoder);
	elapsed = CACurrentMediaTime() - start;
	NSLog(@"[bench] codec vt decode %dx%d: %d of %lu frames, %.1f ms a frame wall, status %d",
	      w, h, sVTDecoded, (unsigned long)sVTSamples.count, elapsed * 1000 / sVTSamples.count, (int)sVTDecodeStatus);
	VTDecompressionSessionInvalidate(decoder);
	CFRelease(decoder);
	sVTSamples = nil;
}

+ (void)codecBenchWidth:(int)w height:(int)h frames:(int)frames kbps:(int)kbps {
	// VideoToolbox's compression API became public in iOS 8; whether the
	// framework already carries it before that decides if an A5 on iOS 6/7
	// could encode H.264 in hardware instead of VP8 in software.
	const char *paths[] = {
		"/System/Library/Frameworks/VideoToolbox.framework/VideoToolbox",
		"/System/Library/PrivateFrameworks/VideoToolbox.framework/VideoToolbox",
	};
	for (int i = 0; i < 2; i++){
		void *vt = dlopen(paths[i], RTLD_LAZY);
		NSLog(@"[bench] codec %s: %s, VTCompressionSessionCreate %s, VTDecompressionSessionCreate %s",
		      paths[i], vt ? "loads" : "absent",
		      vt && dlsym(vt, "VTCompressionSessionCreate") ? "yes" : "no",
		      vt && dlsym(vt, "VTDecompressionSessionCreate") ? "yes" : "no");
	}
	uint8_t *y = malloc((size_t)w * h), *uv = malloc((size_t)w * h / 2), *out = malloc(256 * 1024);
	TGVP8Encoder *encoder = TGVP8EncoderOpen(w, h, 15, kbps);
	TGVP8Decoder *decoder = TGVP8DecoderOpen(w * h);
	if (!encoder || !decoder || !y || !uv || !out){
		NSLog(@"[bench] codec vp8 %dx%d FAILED to open", w, h);
		TGVP8EncoderClose(encoder);
		TGVP8DecoderClose(decoder);
		free(y); free(uv); free(out);
		return;
	}
	double encodeTime = 0, decodeTime = 0, squared = 0;
	size_t bytes = 0;
	int decoded = 0, keyframes = 0;
	for (int n = 0; n < frames; n++){
		TGDevBenchPicture(y, uv, w, h, n);
		int key = 0;
		double t0 = CACurrentMediaTime();
		size_t length = TGVP8EncodeNV12(encoder, y, (size_t)w, uv, (size_t)w,
		                                (int64_t)n * 6000, n == 0, out, 256 * 1024, &key);
		double t1 = CACurrentMediaTime();
		encodeTime += t1 - t0;
		if (!length)
			continue;
		bytes += length;
		keyframes += key;
		TGVP8Image image;
		int ok = TGVP8Decode(decoder, out, length, &image);
		decodeTime += CACurrentMediaTime() - t1;
		if (!ok)
			continue;
		decoded++;
		for (int row = 0; row < h; row++)
			for (int col = 0; col < w; col++){
				int d = (int)image.plane[0][row * image.stride[0] + col] - y[row * w + col];
				squared += d * d;
			}
	}
	double mse = decoded ? squared / ((double)decoded * w * h) : 0;
	NSLog(@"[bench] codec vp8 %dx%d %d kbps: %d frames, %d decoded, %d key, encode %.1f ms, decode %.1f ms a frame, %lu bytes a frame, PSNR %.1f dB",
	      w, h, kbps, frames, decoded, keyframes, encodeTime * 1000 / frames,
	      decoded ? decodeTime * 1000 / decoded : 0, (unsigned long)(bytes / (size_t)frames),
	      mse > 0 ? 10 * log10(255.0 * 255.0 / mse) : 99.0);
	TGVP8EncoderClose(encoder);
	TGVP8DecoderClose(decoder);
	free(y); free(uv); free(out);
	[self videoToolboxBenchWidth:w height:h frames:frames kbps:kbps];
}

+ (void)callVideoLoopInWindow:(UIWindow *)window fullRange:(BOOL)fullRange {
	static TGCallVideoEngine *sender, *receiver;
	sender = [[TGCallVideoEngine alloc] initWithSsrc:1111];
	receiver = [[TGCallVideoEngine alloc] initWithSsrc:2222];
	sender.sendCodec = TGCallVideoCodecH264;
	receiver.receiveCodec = TGCallVideoCodecH264;
	TGCallVideoEngine *to = receiver;
	__block unsigned packets = 0;
	sender.sendVideoRtpBlock = ^(NSData *rtp){
		packets++;
		[to handleIncomingVideoRtp:(const uint8_t *)rtp.bytes length:rtp.length];
	};
	UIView *view = receiver.remoteVideoView;
	view.frame = window.bounds;
	[window addSubview:view];
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		const int w = 368, h = 640, frames = 150;
		CVPixelBufferRef picture = NULL;
		CVPixelBufferCreate(NULL, w, h, (fullRange ? kCVPixelFormatType_420YpCbCr8BiPlanarFullRange : kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
		                    (__bridge CFDictionaryRef)@{ (id)kCVPixelBufferIOSurfacePropertiesKey : @{} }, &picture);
		double start = CACurrentMediaTime();
		for (int n = 0; n < frames && picture; n++){
			CVPixelBufferLockBaseAddress(picture, 0);
			TGDevBenchPicture((uint8_t *)CVPixelBufferGetBaseAddressOfPlane(picture, 0),
			                  (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(picture, 1), w, h, n);
			CVPixelBufferUnlockBaseAddress(picture, 0);
			[sender encodePixelBuffer:picture presentationTime:CMTimeMake(n, 15)];
			[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:start + (n + 1) / 15.0 - CACurrentMediaTime()]];
		}
		[NSThread sleepForTimeInterval:0.5];
		NSLog(@"[bench] callvideo h264 %dx%d: %d frames encoded, %u RTP packets, %u decoded, remote video %d",
		      w, h, frames, packets, receiver.decodedFrames, receiver.hasRemoteVideo);
		CVPixelBufferRelease(picture);
	});
}

+ (void)runWithArguments:(NSArray *)args window:(UIWindow *)window {
	if (sCurrent) {
		NSLog(@"[bench] busy with %@", sCurrent.what);
		return;
	}
	NSString *mode = args.count > 0 ? args[0] : @"scroll";
	NSString *num = args.count > 1 ? args[1] : @"";
	BOOL prof = [args containsObject:@"prof"];
	if ([mode isEqualToString:@"memwarn"]) {
		// What the system posts first; jetsam comes after if nobody listens.
		[[NSNotificationCenter defaultCenter]
				postNotificationName:UIApplicationDidReceiveMemoryWarningNotification
							  object:[UIApplication sharedApplication]];
		return;
	}
	if ([mode isEqualToString:@"mem"]) {
		char line[512];
		TGMemoryBreakdown(line, sizeof(line));
		NSLog(@"[bench] mem %s %s", num.UTF8String, line);
		char big[1024];
		TGMallocBigBlocks(big, sizeof(big));
		NSLog(@"[bench] mem %s big %s", num.UTF8String, big);
		return;
	}
	if ([mode isEqualToString:@"pref"] && args.count > 2) {
		// A/B a setting without a rebuild: bench/pref/TGWantAnimatedStickers/0
		// A number, which boolForKey reads as before: 0/1 stay a switch.
		[[NSUserDefaults standardUserDefaults] setObject:@([args[2] doubleValue]) forKey:num];
		// A run usually ends in killall, which beats the periodic write.
		[[NSUserDefaults standardUserDefaults] synchronize];
		NSLog(@"[bench] pref %@ = %@", num, args[2]);
		return;
	}
	if ([mode isEqualToString:@"null"]) {
		// bench/null: the runtime on this iOS forwards to nil as the host's does.
		id null = [NSNull null];
		NSLog(@"[bench] null long=%lld count=%lu object=%@", [null longLongValue],
				(unsigned long)[null count], [null objectForKey:@"x"]);
		return;
	}
	if ([mode isEqualToString:@"codec"]) {
		// bench/codec/288x352/90/250: VP8 call encode and decode of a moving
		// picture, per-frame cost and PSNR. On the emulator it proves the
		// armv7 libvpx runs and decodes right; its timing is QEMU's, not an A5's.
		int w = 288, h = 352, frames = 90, kbps = 250;
		if (num.length)
			sscanf(num.UTF8String, "%dx%d", &w, &h);
		if (args.count > 2) frames = [args[2] intValue];
		if (args.count > 3) kbps = [args[3] intValue];
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
			[self codecBenchWidth:w height:h frames:frames kbps:kbps];
		});
		return;
	}
	if ([mode isEqualToString:@"audioloop"]) {
		// bench/audioloop: the call's audio engine alone for 12 s, microphone
		// into Opus into the speaker; its rate log says whether the unit keeps
		// real time outside a call.
		static TGCallAudioEngine *engine;
		// bench/audioloop/<opts>: bt (AllowBluetooth), spk (speaker), io (20 ms
		// cycles), plain (no VoiceChat mode), r48 (48 kHz asked for), joined by -.
		AVAudioSession *session = [AVAudioSession sharedInstance];
		BOOL bt = [num rangeOfString:@"bt"].location != NSNotFound;
		[session setCategory:AVAudioSessionCategoryPlayAndRecord
		         withOptions:bt ? AVAudioSessionCategoryOptionAllowBluetooth : 0 error:nil];
		if ([num rangeOfString:@"plain"].location == NSNotFound)
			[session setMode:AVAudioSessionModeVoiceChat error:nil];
		if ([num rangeOfString:@"io"].location != NSNotFound)
			[session setPreferredIOBufferDuration:0.02 error:nil];
		if ([num rangeOfString:@"r48"].location != NSNotFound)
			[session setPreferredSampleRate:48000 error:nil];
		[session setActive:YES error:nil];
		[session overrideOutputAudioPort:[num rangeOfString:@"spk"].location != NSNotFound
		         ? AVAudioSessionPortOverrideSpeaker : AVAudioSessionPortOverrideNone error:nil];
		AVAudioSessionPortDescription *port = session.currentRoute.outputs.firstObject;
		NSLog(@"[bench] audioloop route %@", port.portType);
		NSLog(@"[bench] audioloop %@: session %.0f Hz, io %.1f ms", num, session.sampleRate, session.IOBufferDuration * 1000);
		engine = [[TGCallAudioEngine alloc] init];
		engine.loopbackToSpeaker = YES;
		NSLog(@"[bench] audioloop start %d", [engine start]);
		if ([num rangeOfString:@"late"].location != NSNotFound)
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 2), dispatch_get_main_queue(), ^{
				// As the call does it: the route changes under a running unit.
				[session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
				NSLog(@"[bench] audioloop speaker on while running");
			});
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 12 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
			[engine stop];
			engine = nil;
			NSLog(@"[bench] audioloop done");
		});
		return;
	}
	if ([mode isEqualToString:@"callvideo"]) {
		// bench/callvideo: the call's own H.264 path end to end on this phone,
		// one engine into another: VideoToolbox encode, RTP packetizer,
		// depacketizer, VideoToolbox decode, the remote view on screen.
		// bench/callvideo/full: frames in full range, as official iOS sends.
		[self callVideoLoopInWindow:window fullRange:[num isEqualToString:@"full"]];
		return;
	}
	if ([mode isEqualToString:@"slow"]) {
		// bench/slow/0.25: every animation in the window at a quarter speed.
		window.layer.speed = num.length ? [num floatValue] : 1.0f;
		return;
	}
	if ([mode isEqualToString:@"record"]) {
		// bench/record/<seconds>: what an animation really does on screen. The
		// framebuffer is the only place that shows it, because render-server
		// animations never touch the app's own layers. Frames go to Caches/cap.
		double seconds = num.length ? [num doubleValue] : 3.0;
		[NSThread detachNewThreadSelector:@selector(recordFramesFor:) toTarget:self
							   withObject:@(seconds)];
		return;
	}
	// The iPod auto-locks after a minute, and with the screen off
	// CADisplayLink stops firing: a run would never end. Benching is a
	// developer session, so the screen stays on until the app quits.
	[UIApplication sharedApplication].idleTimerDisabled = YES;

	TGDevBench *b = [[TGDevBench alloc] init];
	b.profile = prof;
	if ([mode isEqualToString:@"watch"]) {
		// No input at all: what the screen costs while someone only reads it.
		b.duration = num.length ? [num doubleValue] : 8.0;
		b.what = [NSString stringWithFormat:@"watch-%@", NSStringFromClass(frontController(window).class)];
		[b begin];
	} else if ([mode isEqualToString:@"playvoice"] || [mode isEqualToString:@"playround"]) {
		BOOL round = [mode isEqualToString:@"playround"];
		UIViewController *vc = frontController(window);
		NSArray *msgs = [vc respondsToSelector:@selector(messages)] ? [vc valueForKey:@"messages"] : nil;
		NSString *want = round ? @"messageVideoNote" : @"messageVoiceNote";
		NSInteger row = NSNotFound;
		NSDictionary *target = nil;
		for (NSInteger i = (NSInteger)msgs.count - 1; i >= 0; i--) {
			NSDictionary *m = msgs[(NSUInteger)i];
			if ([m[@"kind"] isEqualToString:want]) { target = m; row = i; break; }
		}
		if (!target) {
			NSLog(@"[bench] %@ no %@ in front chat", mode, want);
			return;
		}
		UITableView *tbl = (UITableView *)largestScroll(vc.view);
		if ([tbl isKindOfClass:UITableView.class])
			[tbl scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]
					   atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
		id<TGDevBenchChatActions> chat = (id<TGDevBenchChatActions>)vc;
		if (round) [chat playVideoNoteForMessage:target atRow:row];
		else       [chat playVoiceNoteForMessage:target atRow:row];
		b.duration = num.length ? [num doubleValue] : 5.0;
		b.what = mode;
		b.afterWatch = ^{ [chat stopPlayback]; };
		TGPerfReportMemory("bench start");
		[b begin];
	} else if ([mode isEqualToString:@"recordvoice"] || [mode isEqualToString:@"recordround"]) {
		BOOL round = [mode isEqualToString:@"recordround"];
		UIViewController *vc = frontController(window);
		if (![vc respondsToSelector:@selector(recordStart)]) {
			NSLog(@"[bench] %@ front vc %@ cannot record", mode, vc.class);
			return;
		}
		[vc setValue:@(round) forKey:@"videoNoteMode"];
		id<TGDevBenchChatActions> chat = (id<TGDevBenchChatActions>)vc;
		[chat recordStart];
		b.duration = num.length ? [num doubleValue] : 4.0;
		b.what = mode;
		b.afterWatch = ^{
			if (round) {
				UIViewController *ov = [vc valueForKey:@"videoNoteOverlay"];
				if (ov && [ov respondsToSelector:@selector(cancelTapped)])
					[(id<TGDevBenchChatActions>)ov cancelTapped];
				else
					[ov dismissViewControllerAnimated:NO completion:nil];
			} else {
				[chat recordCancel];
			}
		};
		TGPerfReportMemory("bench start");
		[b begin];
	} else if ([mode isEqualToString:@"hold"]) {
		UIViewController *vc = frontController(window);
		if (![vc respondsToSelector:@selector(showActionsForRow:)]) {
			NSLog(@"[bench] hold front vc %@ has no showActionsForRow:", vc.class);
			return;
		}
		NSInteger row = num.length ? [num integerValue] : -1;
		id<TGDevBenchChatActions> chat = (id<TGDevBenchChatActions>)vc;
		[chat showActionsForRow:row];
		b.duration = 2.0;
		b.what = @"hold";
		b.afterWatch = ^{
			for (UIView *v in [window.subviews copy])
				if ([NSStringFromClass(v.class) isEqualToString:@"TGPopupMenu"])
					[v removeFromSuperview];
		};
		TGPerfReportMemory("bench start");
		[b begin];
	} else if ([mode isEqualToString:@"open"]) {
		// A beat first: uiopen, sshd and SpringBoard's openURL are still on the
		// single core when the URL lands, and inflated "first" by ~100 ms.
		NSInteger row = [num integerValue];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
				dispatch_get_main_queue(), ^{ [b openRow:row window:window]; });
	} else if ([mode isEqualToString:@"panel"]) {
		// The chat's sticker panel grid, not the chat behind it:
		// bench/panel/8 after stickers/stickers.
		b.duration = num.length ? [num doubleValue] : 8.0;
		[b scrollPanelIn:window];
	} else {
		b.duration = num.length ? [num doubleValue] : 8.0;
		[b scrollIn:window];
	}
}

+ (void)recordFramesFor:(NSNumber *)seconds {
	CGImageRef (*grab)(void) = (CGImageRef (*)(void))dlsym(RTLD_DEFAULT, "UIGetScreenImage");
	NSString *dir = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)
			objectAtIndex:0] stringByAppendingPathComponent:@"cap"];
	NSFileManager *files = [NSFileManager defaultManager];
	[files removeItemAtPath:dir error:nil];
	[files createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];

	// Held raw and encoded afterwards: a JPEG takes 250 ms on an A4, longer than
	// most of the animations this exists to look at. 2.4 MB each, hence the cap.
	NSMutableArray *held = [NSMutableArray array];
	NSDate *end = [NSDate dateWithTimeIntervalSinceNow:seconds.doubleValue];
	while (grab && [end timeIntervalSinceNow] > 0 && held.count < 30) {
		CGImageRef screen = grab();
		if (!screen)
			break;
		[held addObject:[UIImage imageWithCGImage:screen]];
		CGImageRelease(screen);
		[NSThread sleepForTimeInterval:MAX(0.02, seconds.doubleValue / 30.0 - 0.06)];
	}
	NSInteger frame = 0;
	for (UIImage *image in held) {
		@autoreleasepool {
			[UIImageJPEGRepresentation(image, 0.6f) writeToFile:[dir stringByAppendingPathComponent:
					[NSString stringWithFormat:@"frame_%04ld.jpg", (long)frame++]] atomically:NO];
		}
	}
	NSLog(@"[bench] record %ld frames in %.1f s", (long)frame, seconds.doubleValue);
}

- (void)begin {
	sCurrent = self;
	_count = 0;
	_firstFrameMs = -1;
	if (self.profile)
		TGSamplerStart(2000, 8000);
	char buf[8];
	TGCpuSplit(buf, sizeof(buf));
	self.start = self.last = CACurrentMediaTime();
	self.link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
	[self.link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)scrollIn:(UIWindow *)window {
	UIViewController *vc = frontController(window);
	self.scroll = largestScroll(vc.view);
	if (!self.scroll) {
		NSLog(@"[bench] no scroll view in %@", vc.class);
		return;
	}
	self.what = [NSString stringWithFormat:@"scroll-%@", NSStringFromClass(vc.class)];
	self.direction = 1;
	TGPerfReportMemory("bench start");
	[self begin];
}

- (void)scrollPanelIn:(UIWindow *)window {
	Class panelClass = NSClassFromString(@"TGEmojiPanel");
	NSMutableArray *queue = [NSMutableArray arrayWithObject:window];
	UIView *panel = nil;
	while (queue.count && !panel) {
		UIView *v = queue[0];
		[queue removeObjectAtIndex:0];
		if (panelClass && [v isKindOfClass:panelClass] && !v.hidden)
			panel = v;
		[queue addObjectsFromArray:v.subviews];
	}
	self.scroll = panel ? largestScroll(panel) : nil;
	if (!self.scroll) {
		NSLog(@"[bench] no sticker panel open");
		return;
	}
	self.what = @"scroll-TGEmojiPanel";
	self.direction = 1;
	TGPerfReportMemory("bench start");
	[self begin];
}

- (void)openRow:(NSInteger)row window:(UIWindow *)window {
	UIViewController *vc = frontController(window);
	UITableView *table = (UITableView *)largestScroll(vc.view);
	if (![table isKindOfClass:UITableView.class] || row >= [table numberOfRowsInSection:0]) {
		NSLog(@"[bench] %@ has no row %ld", vc.class, (long)row);
		return;
	}
	UINavigationController *nc = vc.navigationController;
	self.what = [NSString stringWithFormat:@"open-%ld", (long)row];
	self.duration = kOpenWatchSeconds;
	// Strong on purpose: sCurrent lets go before this runs, and the cycle
	// ends when the block clears afterWatch.
	TGDevBench *me = self;
	self.afterWatch = ^{
		// The way back is part of opening a chat too: the list redraws.
		me.what = [NSString stringWithFormat:@"pop-%ld", (long)row];
		me.duration = kPopWatchSeconds;
		me.afterWatch = nil;
		[me begin];
		double t0 = CACurrentMediaTime();
		[nc popViewControllerAnimated:YES];
		me.start = t0;
	};
	TGPerfReportMemory("bench start");
	[self begin];
	double t0 = CACurrentMediaTime();
	NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:0];
	[table selectRowAtIndexPath:path animated:NO scrollPosition:UITableViewScrollPositionNone];
	[table.delegate tableView:table didSelectRowAtIndexPath:path];
	self.start = t0;
}

- (void)tick:(CADisplayLink *)link {
	double now = CACurrentMediaTime();
	double dt = now - self.last;
	self.last = now;
	if (_firstFrameMs < 0)
		_firstFrameMs = (now - self.start) * 1000.0;
	else if (_count < kMaxFrames)
		_frames[_count++] = dt;

	UIScrollView *s = self.scroll;
	if (s) {
		// Time-based, so a dropped frame jumps further like a real fling does
		// instead of quietly slowing the scroll down to what the CPU manages.
		CGFloat maxY = MAX(0, s.contentSize.height - s.bounds.size.height + s.contentInset.bottom);
		CGFloat minY = -s.contentInset.top;
		CGFloat y = s.contentOffset.y + self.direction * kFlingPointsPerSecond * (CGFloat)MIN(dt, 0.25);
		if (y >= maxY) { y = maxY; self.direction = -1; }
		if (y <= minY) { y = minY; self.direction = 1; }
		[s setContentOffset:CGPointMake(0, y) animated:NO];
	}
	if (now - self.start >= self.duration)
		[self finish];
}

static int cmpDouble(const void *a, const void *b) {
	double x = *(const double *)a, y = *(const double *)b;
	return x < y ? -1 : x > y;
}

- (void)finish {
	[self.link invalidate];
	self.link = nil;
	int samples = 0;
	NSString *dump = nil;
	if (self.profile) {
		dump = cachesPath([NSString stringWithFormat:@"bench-%@.txt", self.what]);
		samples = TGSamplerStopAndWrite(dump.fileSystemRepresentation);
	}

	unsigned dropped = 0, janky = 0;
	double worst = 0, busy = 0;
	for (unsigned i = 0; i < _count; i++) {
		double f = _frames[i];
		long missed = lround(f / kFrameSeconds) - 1;
		if (missed > 0) {
			dropped += (unsigned)missed;
			janky++;
		}
		worst = MAX(worst, f);
		busy += f;
	}
	// Where in the run the frames went: the first scroll pays for new rows
	// at the start, history pages and pictures arriving later.
	char bySecond[256] = "";
	double clock = 0;
	unsigned bucketDropped = 0;
	int bucket = 0;
	size_t used = 0;
	for (unsigned i = 0; i < _count && used < sizeof(bySecond) - 8; i++) {
		long missed = lround(_frames[i] / kFrameSeconds) - 1;
		bucketDropped += missed > 0 ? (unsigned)missed : 0;
		clock += _frames[i];
		if (clock >= bucket + 1 || i + 1 == _count) {
			used += (size_t)snprintf(bySecond + used, sizeof(bySecond) - used, " %u", bucketDropped);
			bucketDropped = 0;
			bucket = (int)clock;
		}
	}
	qsort(_frames, _count, sizeof(double), cmpDouble);
	double p50 = _count ? _frames[_count / 2] : 0;
	double p95 = _count ? _frames[(_count * 95) / 100] : 0;
	unsigned expected = _count + dropped;
	TGBenchKeep([NSString stringWithFormat:@"[bench] %@ dropped by second:%s", self.what, bySecond]);
	TGBenchKeep([NSString stringWithFormat:@"[bench] %@ first=%.0fms frames=%u dropped=%u (%.0f%%) janky=%u worst=%.0fms p50=%.1fms p95=%.1fms fps=%.1f samples=%d",
			self.what, _firstFrameMs, _count, dropped,
			expected ? 100.0 * dropped / expected : 0.0, janky, worst * 1000.0,
			p50 * 1000.0, p95 * 1000.0, busy > 0 ? _count / busy : 0.0, samples]);
	// Layers per visible row, all and shown: backboardd's work tracks the
	// layer tree, hidden layers included, more than anything drawn.
	if ([self.scroll isKindOfClass:UITableView.class]) {
		unsigned all = 0, shown = 0, rows = 0;
		for (UITableViewCell *c in ((UITableView *)self.scroll).visibleCells) {
			rows++;
			NSMutableArray *q = [NSMutableArray arrayWithObject:c.layer];
			while (q.count) {
				CALayer *l = q.lastObject;
				[q removeLastObject];
				all++;
				BOOL hiddenUp = NO;
				for (CALayer *u = l; u && u != c.layer.superlayer; u = u.superlayer)
					if (u.hidden) { hiddenUp = YES; break; }
				if (!hiddenUp)
					shown++;
				[q addObjectsFromArray:l.sublayers];
			}
		}
		if (rows)
			NSLog(@"[bench] %@ layers/row all=%u shown=%u", self.what, all / rows, shown / rows);
		// What the shown layers of the busiest row are, to see which to merge.
		NSString *busiest = nil;
		NSUInteger most = 0;
		for (UITableViewCell *c in ((UITableView *)self.scroll).visibleCells) {
			NSMutableArray *names = [NSMutableArray array];
			NSMutableArray *q = [NSMutableArray arrayWithObject:c.layer];
			while (q.count) {
				CALayer *l = q.lastObject;
				[q removeLastObject];
				if (l.hidden)
					continue;
				[names addObject:[NSString stringWithFormat:@"%@%@%.0fx%.0f",
						NSStringFromClass([l.delegate class] ?: [l class]),
						l.contents ? @"*" : @"", l.bounds.size.width, l.bounds.size.height]];
				[q addObjectsFromArray:l.sublayers];
			}
			if (names.count > most) {
				most = names.count;
				busiest = [names componentsJoinedByString:@" "];
			}
		}
		if (busiest)
			TGBenchKeep([NSString stringWithFormat:@"[bench] %@ busiest row %lu: %@", self.what,
					(unsigned long)most, busiest]);
	}
	char cpu[512];
	if (TGCpuSplit(cpu, sizeof(cpu)))
		TGBenchKeep([NSString stringWithFormat:@"[bench] %@ cpu %s", self.what, cpu]);
	if (dump)
		NSLog(@"[bench] dump %@", dump);
	char mem[512];
	TGMemoryBreakdown(mem, sizeof(mem));
	NSLog(@"[bench] %@ mem %s", self.what, mem);

	void (^next)(void) = self.afterWatch;
	sCurrent = nil;
	if (next) {
		// A beat for the pushed screen to settle, as a person would read first.
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
				dispatch_get_main_queue(), next);
	}
}

@end
