#import "TGStyle.h"
#import "TGEmojiPictures.h"
#import "TGCapabilities.h"
#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>
#import <VideoToolbox/VideoToolbox.h>
#include <stdlib.h>

@implementation TGCapability
@end

@implementation TGCapabilities

+ (double)systemVersion {
	static double version = 0;
	if (version == 0)
		version = [[UIDevice currentDevice].systemVersion doubleValue];
	return version;
}

+ (BOOL)is64Bit {
	return sizeof(void *) == 8;
}

+ (NSUInteger)memoryMB {
	return (NSUInteger)([NSProcessInfo processInfo].physicalMemory / (1024 * 1024));
}

+ (BOOL)canRunWebApps {
	return [self systemVersion] >= 9.0;
}

/// A Power Saving switch, defaulting to on when the user has never touched it.
static BOOL TGWanted(NSString *key) {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	return [defaults objectForKey:key] ? [defaults boolForKey:key] : YES;
}

static void TGSetWanted(NSString *key, BOOL wanted) {
	[[NSUserDefaults standardUserDefaults] setBool:wanted forKey:key];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

+ (BOOL)animatedStickersWanted { return TGWanted(@"TGWantAnimatedStickers"); }
+ (void)setAnimatedStickersWanted:(BOOL)wanted {
	TGSetWanted(@"TGWantAnimatedStickers", wanted);
}
/// Off until asked for on the oldest tier: a texture under every bubble is paid
/// for on each scrolled frame there, and the choice should be the user's.
+ (BOOL)wallpaperWanted {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if (![defaults objectForKey:@"TGWantWallpaper"])
		return [TGDevice tier] >= TGDeviceTierLegacy;
	return [defaults boolForKey:@"TGWantWallpaper"];
}
+ (void)setWallpaperWanted:(BOOL)wanted {
	TGSetWanted(@"TGWantWallpaper", wanted);
}
+ (BOOL)gifAutoplayWanted { return TGWanted(@"TGWantGifAutoplay"); }
+ (void)setGifAutoplayWanted:(BOOL)wanted {
	TGSetWanted(@"TGWantGifAutoplay", wanted);
}

+ (BOOL)canPlayAnimatedStickers {
	// TGLottieView renders vector animations with C++ optimization.
	// Dual-core runs at 18 fps, single-core (A4) throttles to 12 fps with model caching.
	// "Loop Animated Stickers" off is the official meaning, one loop and then
	// rest. Vintage shows the still: on the iPod touch 4 even one loop per
	// sticker took 12 points of a chat's first scroll (59% to 47% dropped
	// with loops off), the builds and rasters sharing its one core.
	return [TGDevice tier] > TGDeviceTierVintage;
}

+ (BOOL)canShowWallpaper {
	// Not on Vintage iPhone: backboardd blends the pattern under every bubble on each
	// scrolled frame, 5-7 points of a chat scroll on the iPod touch 4.
	// On iPad, always allow wallpaper as iPads running iOS 6 have dual-core GPU/CPU.
#if TARGET_OS_IPHONE
	BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
	if (isPad) return YES;
#endif
	return [TGDevice tier] > TGDeviceTierVintage && [self wallpaperWanted];
}

/// One TDLib client runs at a time and each account keeps its own database, so
/// a second account costs disk, not memory.
+ (BOOL)canHoldMultipleAccounts {
	return YES;
}

+ (BOOL)hasVideoCallHardware {
	// Dual-core A5 and later: enough CPU for VP8 in software when the peer
	// offers no H.264.
	return [TGDevice tier] > TGDeviceTierVintage;
}

+ (BOOL)canEncodeVideoCall {
	// Dual-core A5 and later on any iOS: H.264 through VideoToolbox, VP8 in
	// software when the peer offers no H.264. The single-core A4 only with
	// VideoToolbox: on an iPod touch 4 it encodes a 288x352 frame in 4.4 ms
	// and decodes one in 4.0, where VP8 took 16.4 and 5.6 of its one core.
	return [self hasVideoCallHardware] || [self hasHardwareH264];
}

+ (BOOL)hasHardwareH264 {
	// Public from iOS 8, but iOS 6 and 7 carry the same encoder and decoder:
	// on an iPod touch 4 with 6.1.6 both ran, 4.4 and 4.0 ms for a 288x352
	// frame, where VP8 in software took 16.4 and 5.6. The symbols are weak
	// imports, so their presence is the test.
#if !TARGET_OS_IPHONE
	// The host bench plays a phone without it (CALL_BENCH_CODEC=vp8).
	if (getenv("TG_SHIM_NO_VIDEOTOOLBOX"))
		return NO;
#endif
	return &VTCompressionSessionCreate != NULL && &VTDecompressionSessionCreate != NULL &&
	       &VTCompressionSessionEncodeFrame != NULL && &VTDecompressionSessionDecodeFrame != NULL;
}

+ (int)maxVideoSide {
	// ponytail: the 3GS tops out at 640 and shares the 720p answer here. A file it
	// refuses then falls to the viewer's failure path.
	TGDeviceTier tier = [TGDevice tier];
	return tier >= TGDeviceTierFull ? 3840 : (tier <= TGDeviceTierVintage ? 1280 : 1920);
}

+ (BOOL)canAutoplayGIFs {
	return [self gifAutoplayWanted];
}

+ (BOOL)canPlayVideoAvatars {
	return [TGDevice tier] >= TGDeviceTierModern && [self gifAutoplayWanted];
}

+ (BOOL)canPlayStickerEffects {
	return [TGDevice tier] >= TGDeviceTierFull && [self animatedStickersWanted];
}

+ (NSUInteger)maxConcurrentGIFs {
	switch ([TGDevice tier]){
		case TGDeviceTierVintage: return 1;
		case TGDeviceTierLegacy:  return 2;
		case TGDeviceTierModern:  return 3;
		case TGDeviceTierFull:    return 4;
	}
	return 2;
}

/// The system's own row actions. Below iOS 8 the chat list swipes with its own.
+ (BOOL)canSwipeRowActions {
	return NSClassFromString(@"UITableViewRowAction") != nil;
}

/// iOS 7's typesetter segfaults outright when it meets a character the emoji
/// font has no glyph for - 🏳️ (U+1F3F3) is one - so ask the font directly
/// before handing anything to CTLine. Selectors and joiners carry no glyph of
/// their own, and a surrogate pair answers on its lead unit.
static BOOL TGEmojiFontHasGlyphs(CTFontRef font, NSString *s) {
	NSUInteger len = s.length;
	if (!len || len > 64)
		return NO;
	unichar buf[64];
	[s getCharacters:buf range:NSMakeRange(0, len)];
	for (NSUInteger i = 0; i < len; i++){
		unichar c = buf[i];
		if (c == 0xFE0E || c == 0xFE0F || c == 0x200D)
			continue;
		unichar pair[2] = { c, 0 };
		CFIndex n = 1;
		if (c >= 0xD800 && c <= 0xDBFF && i + 1 < len){
			pair[1] = buf[++i];
			n = 2;
		}
		CGGlyph glyphs[2] = { 0, 0 };
		CTFontGetGlyphsForCharacters(font, pair, glyphs, n);
		if (glyphs[0] == 0)
			return NO;
	}
	return YES;
}

+ (BOOL)canDrawEmoji:(NSString *)emoji {
	if (!emoji.length)
		return NO;
	// iOS 7 draws what the bundled face has a picture for (TGEmojiPictures).
	if (TGEmojiPicturesActive())
		return TGEmojiPicturePNG(emoji) != nil;
	// Asked from the main thread and from the warm-up queue (TGWarmEmojiData),
	// so the cache is shared under a lock; the shaping itself runs outside it.
	static NSMutableDictionary *answers = nil;
	static CTFontRef font = NULL;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		answers = [NSMutableDictionary dictionary];
		font = CTFontCreateWithName((__bridge CFStringRef)TGEmojiFaceName(), 20, NULL);
		if (!font)
			font = CTFontCreateWithName(CFSTR("AppleColorEmoji"), 20, NULL);
	});
	NSNumber *known;
	@synchronized (answers){
		known = answers[emoji];
	}
	if (known)
		return known.boolValue;

	// Asking for each character's glyph is not enough: a flag is two letters
	// the font has on their own, and an unknown flag or joined sequence still
	// "draws" - as two boxes or a family taken apart. Shaping the whole thing
	// and wanting one glyph from the emoji font itself is what the screen
	// will actually show.
	BOOL ok = NO;
	if (font && TGEmojiFontHasGlyphs(font, emoji)){
		NSAttributedString *text = [[NSAttributedString alloc] initWithString:emoji
				attributes:@{(__bridge NSString *)kCTFontAttributeName : (__bridge id)font}];
		CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)text);
		if (line){
			CFArrayRef runs = CTLineGetGlyphRuns(line);
			if (CFArrayGetCount(runs) == 1){
				CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, 0);
				CTFontRef used = (CTFontRef)CFDictionaryGetValue(CTRunGetAttributes(run), kCTFontAttributeName);
				NSString *name = used ? (__bridge_transfer NSString *)CTFontCopyPostScriptName(used) : nil;
				CGGlyph glyph = 0;
				if (CTRunGetGlyphCount(run) == 1)
					CTRunGetGlyphs(run, CFRangeMake(0, 1), &glyph);
				ok = glyph != 0 && ([name isEqualToString:@"AppleColorEmoji"] || [name isEqualToString:@"AppleColorEmojiCompat"]);
			}
			CFRelease(line);
		}
	}
	@synchronized (answers){
		answers[emoji] = @(ok);
	}
	return ok;
}

/// Everything the app gates, each with what it is waiting for. The order is
/// the order a Device screen shows them in.
+ (NSArray *)all {
	NSArray *rows = @[
		@[@"Messages, media, groups", @YES,  @"every device"],
		@[@"WebP stickers",           @YES,  @"every device"],
		@[@"Voice notes",             @YES,  @"every device"],
		@[@"Animated stickers",       @([self canPlayAnimatedStickers]), @"Legacy+ - the A4 shows the still picture"],
		@[@"Recent photos in attach", @YES,  @"every device"],
		@[@"Swipe actions in chats",  @YES,  @"every device"],
		@[@"Chat wallpaper",          @([self canShowWallpaper]),      @"Legacy+ - the A4 blends it under every bubble on each scrolled frame"],
		@[@"GIF autoplay",            @([self canAutoplayGIFs]),       @"every device, one at a time on the oldest"],
		@[@"Video profile pictures",  @([self canPlayVideoAvatars]),   @"Modern+ - the A7's decoder; older devices show the still"],
		@[@"Premium sticker effects", @([self canPlayStickerEffects]), @"Full - a second, larger animation over the list"],
		@[@"Multiple accounts",       @([self canHoldMultipleAccounts]), @"every device, one active at a time"],
		@[@"Custom emoji",            @YES,  @"every device, static on Vintage"],
		@[@"Mini apps",               @([self canRunWebApps]),         @"iOS 9 or later"],
		@[@"H.264 High video",        @([TGDevice tier] > TGDeviceTierVintage), @"Legacy - the A4's decoder stops at Main Profile, 720p, 30 fps"],
		@[@"Video calls",             @([self canEncodeVideoCall]),    @"H.264 in hardware (VideoToolbox); VP8 in software on A5 and later"],
	];

	NSMutableArray *out = [NSMutableArray array];
	for (NSArray *row in rows){
		TGCapability *capability = [[TGCapability alloc] init];
		capability.name = row[0];
		capability.available = [row[1] boolValue];
		capability.requirement = row[2];
		[out addObject:capability];
	}
	return out;
}

@end

// vim:ft=objc
