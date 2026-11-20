//
// TGTextRender.mm - see TGTextRender.h.
//
#import "TGTextRender.h"
#import <UIKit/UIKit.h>
#import "TGMessageLayout.h"
#import "TGPerf.h"
#import "TGStyle.h"
#import "TGCapabilities.h"
#import <CoreText/CoreText.h>
#include <list>
#include <pthread.h>
#include <unordered_map>
#include <vector>

// CoreText fills a frame only as far down as its box: a box exactly as tall
// as UIKit measured the text dropped the last line whenever CoreText needed a
// point more. The layout gets this much room below; the bitmap keeps the box.
static const CGFloat kTGTextOverflow = 4096;

// Under these names the decorations travel past CoreText, which would draw
// an underline itself in some versions and never a strikethrough or a plate.
static NSString *const kTGUnderline = @"TGTextUnderline";
static NSString *const kTGStrike = @"TGTextStrike";

BOOL TGTextRenderCan(NSAttributedString *text) {
	if (!text.length)
		return NO;
	__block BOOL attachment = NO;
	[text enumerateAttribute:@"NSAttachment" inRange:NSMakeRange(0, text.length) options:0
			usingBlock:^(id value, NSRange range, BOOL *stop) {
		if (value) {
			attachment = YES;
			*stop = YES;
		}
	}];
	return !attachment;
}

/// The string CoreText is given: CTFonts (iOS 6 ignores a UIFont), the fill
/// colour taken from the context so each run's own colour applies, and the
/// decorations renamed so only this file draws them.
static NSAttributedString *TGTextPrepared(NSAttributedString *text) {
	NSMutableAttributedString *out = [TGCoreTextFonts(text) mutableCopy];
	NSRange all = NSMakeRange(0, out.length);
	[out addAttribute:(__bridge NSString *)kCTForegroundColorFromContextAttributeName value:@YES range:all];
	// UILabel's own paragraph style is a UIKit object, not a CTParagraphStyle.
	[out removeAttribute:NSParagraphStyleAttributeName range:all];
	NSDictionary *renames = @{ NSUnderlineStyleAttributeName : kTGUnderline,
							   NSStrikethroughStyleAttributeName : kTGStrike };
	for (NSString *from in renames) {
		NSMutableArray *ranges = [NSMutableArray array];
		NSMutableArray *values = [NSMutableArray array];
		[out enumerateAttribute:from inRange:all options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
			if ([value integerValue]) {
				[ranges addObject:[NSValue valueWithRange:range]];
				[values addObject:value];
			}
		}];
		[out removeAttribute:from range:all];
		for (NSUInteger i = 0; i < ranges.count; i++)
			[out addAttribute:renames[from] value:values[i] range:[ranges[i] rangeValue]];
	}
	return out;
}

/// The layout, top of the text at the top of a box `width` wide and
/// `kTGTextOverflow` taller than `height`. +1.
static CTFrameRef TGTextFrameCreate(NSAttributedString *prepared, CGFloat width, CGFloat height) {
	CTFramesetterRef setter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)prepared);
	if (!setter)
		return NULL;
	CGPathRef path = CGPathCreateWithRect(CGRectMake(0, 0, width, height + kTGTextOverflow), NULL);
	CTFrameRef frame = CTFramesetterCreateFrame(setter, CFRangeMake(0, 0), path, NULL);
	CGPathRelease(path);
	CFRelease(setter);
	return frame;
}

static CGColorRef TGTextColour(id value) {
	if (!value)
		return NULL;
	if (CFGetTypeID((__bridge CFTypeRef)value) == CGColorGetTypeID())
		return (__bridge CGColorRef)value;
	if ([value respondsToSelector:@selector(CGColor)])
		return (CGColorRef)[value CGColor];
	return NULL;
}

static CTFontRef TGRunFont(NSDictionary *attributes) {
	id font = attributes[(__bridge NSString *)kCTFontAttributeName];
	if (font && CFGetTypeID((__bridge CFTypeRef)font) == CTFontGetTypeID())
		return (__bridge CTFontRef)font;
	return NULL;
}

/// One laid-out line drawn at `origin` (CoreText coordinates): plates
/// first, then each run in its own colour with its own decorations.
static void TGDrawLine(CGContextRef ctx, CTLineRef line, CGPoint origin, CGFloat ascent, CGFloat descent,
		CGFloat scale) {
	CFArrayRef runs = CTLineGetGlyphRuns(line);
	CFIndex runCount = runs ? CFArrayGetCount(runs) : 0;
	for (int pass = 0; pass < 2; pass++) {
		for (CFIndex j = 0; j < runCount; j++) {
			CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, j);
			NSDictionary *attributes = (__bridge NSDictionary *)CTRunGetAttributes(run);
			CFRange range = CTRunGetStringRange(run);
			CGFloat x = CTLineGetOffsetForStringIndex(line, range.location, NULL);
			CGFloat runAscent = 0, runDescent = 0, runLeading = 0;
			CGFloat width = (CGFloat)CTRunGetTypographicBounds(run, CFRangeMake(0, 0),
					&runAscent, &runDescent, &runLeading);
			if (pass == 0) {
				CGColorRef plate = TGTextColour(attributes[NSBackgroundColorAttributeName]);
				if (plate) {
					CGContextSetFillColorWithColor(ctx, plate);
					CGContextFillRect(ctx, CGRectMake(origin.x + x, origin.y - descent, width, ascent + descent));
				}
				continue;
			}
			CGColorRef fill = TGTextColour(attributes[NSForegroundColorAttributeName]);
			if (fill)
				CGContextSetFillColorWithColor(ctx, fill);
			else
				CGContextSetGrayFillColor(ctx, 0, 1);
			CGContextSetTextPosition(ctx, origin.x, origin.y);
			CTRunDraw(run, ctx, CFRangeMake(0, 0));
			CTFontRef font = TGRunFont(attributes);
			CGFloat thickness = font ? MAX(CTFontGetUnderlineThickness(font), 1 / scale) : 1 / scale;
			if ([attributes[kTGUnderline] integerValue]) {
				CGFloat y = origin.y + (font ? CTFontGetUnderlinePosition(font) : -1);
				CGContextFillRect(ctx, CGRectMake(origin.x + x, y - thickness / 2, width, thickness));
			}
			if ([attributes[kTGStrike] integerValue]) {
				CGFloat y = origin.y + (font ? CTFontGetXHeight(font) / 2 : runAscent / 3);
				CGContextFillRect(ctx, CGRectMake(origin.x + x, y - thickness / 2, width, thickness));
			}
		}
	}
}

CGImageRef TGTextRenderCreateImage(NSAttributedString *text, CGSize size, CGFloat scale) {
	if (!text.length || size.width <= 0 || size.height <= 0 || scale <= 0)
		return NULL;
	size_t pixelsWide = (size_t)ceil(size.width * scale);
	size_t pixelsHigh = (size_t)ceil(size.height * scale);
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGContextRef ctx = CGBitmapContextCreate(NULL, pixelsWide, pixelsHigh, 8, 0, space,
			kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
	CGColorSpaceRelease(space);
	if (!ctx)
		return NULL;
	CGContextScaleCTM(ctx, scale, scale);
	CGContextSetTextMatrix(ctx, CGAffineTransformIdentity);

	CTFrameRef frame = TGTextFrameCreate(TGTextPrepared(text), size.width, size.height);
	CFArrayRef lines = frame ? CTFrameGetLines(frame) : NULL;
	CFIndex count = lines ? CFArrayGetCount(lines) : 0;
	if (count > 0) {
		std::vector<CGPoint> origins((size_t)count);
		CTFrameGetLineOrigins(frame, CFRangeMake(0, count), origins.data());
		// The box CoreText filled is kTGTextOverflow taller than the bitmap:
		// its top goes to the bitmap's top.
		const CGFloat shift = -kTGTextOverflow;
		for (CFIndex i = 0; i < count; i++) {
			CTLineRef line = (CTLineRef)CFArrayGetValueAtIndex(lines, i);
			CGPoint origin = CGPointMake(origins[(size_t)i].x, origins[(size_t)i].y + shift);
			CGFloat ascent = 0, descent = 0, leading = 0;
			CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
			if (origin.y - descent < 0)
				origin.y = descent;
			if (origin.y + ascent < 0)
				break;
			if (origin.y - descent > size.height)
				continue;
			TGDrawLine(ctx, line, origin, ascent, descent, scale);
		}
	}
	if (frame)
		CFRelease(frame);
	CGImageRef image = CGBitmapContextCreateImage(ctx);
	CGContextRelease(ctx);
	return image;
}

NSUInteger TGTextRenderLineCount(NSAttributedString *text, CGFloat width) {
	if (!text.length || width <= 0)
		return 0;
	CTFrameRef frame = TGTextFrameCreate(TGTextPrepared(text), width, 0);
	CFArrayRef lines = frame ? CTFrameGetLines(frame) : NULL;
	NSUInteger count = lines ? (NSUInteger)CFArrayGetCount(lines) : 0;
	if (frame)
		CFRelease(frame);
	return count;
}

void TGTextRenderDrawLabel(CGContextRef ctx, NSAttributedString *text, CGRect bounds, NSInteger maxLines,
		NSTextAlignment alignment, CGFloat lineHeight, CGFloat faceAscent, CGFloat scale) {
	if (!ctx || !text.length || bounds.size.width <= 0 || bounds.size.height <= 0)
		return;
	NSAttributedString *prepared = TGTextPrepared(text);
	CTFrameRef frame = TGTextFrameCreate(prepared, bounds.size.width, bounds.size.height);
	CFArrayRef lines = frame ? CTFrameGetLines(frame) : NULL;
	CFIndex count = lines ? CFArrayGetCount(lines) : 0;
	if (count > 0) {
		CFIndex shown = maxLines > 0 ? MIN(count, (CFIndex)maxLines) : count;
		std::vector<CGPoint> origins((size_t)count);
		CTFrameGetLineOrigins(frame, CFRangeMake(0, count), origins.data());
		std::vector<CTLineRef> drawn((size_t)shown);
		for (CFIndex i = 0; i < shown; i++)
			drawn[(size_t)i] = (CTLineRef)CFRetain(CFArrayGetValueAtIndex(lines, i));
		// Text left over past the last line shown ends it in an ellipsis,
		// as UILabel's own truncation does.
		CTLineRef last = drawn[(size_t)shown - 1];
		CFRange range = CTLineGetStringRange(last);
		if (range.location + range.length < (CFIndex)prepared.length) {
			NSAttributedString *rest = [prepared attributedSubstringFromRange:
					NSMakeRange((NSUInteger)range.location, prepared.length - (NSUInteger)range.location)];
			NSDictionary *style = [rest attributesAtIndex:0 effectiveRange:NULL];
			NSAttributedString *dots = [[NSAttributedString alloc] initWithString:@"\u2026" attributes:style];
			CTLineRef full = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)rest);
			CTLineRef ellipsis = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)dots);
			CTLineRef cut = (full && ellipsis)
					? CTLineCreateTruncatedLine(full, bounds.size.width, kCTLineTruncationEnd, ellipsis) : NULL;
			if (cut) {
				CFRelease(last);
				drawn[(size_t)shown - 1] = cut;
			}
			if (full)
				CFRelease(full);
			if (ellipsis)
				CFRelease(ellipsis);
		}
		// UILabel centres its text vertically in its bounds.
		CGFloat a0 = 0, d0 = 0, l0 = 0, aN = 0, dN = 0, lN = 0;
		CTLineGetTypographicBounds(drawn[0], &a0, &d0, &l0);
		CTLineGetTypographicBounds(drawn[(size_t)shown - 1], &aN, &dN, &lN);
		CGFloat top = origins[0].y + a0;
		CGFloat textHeight = lineHeight > 0 ? shown * lineHeight : top - (origins[(size_t)shown - 1].y - dN);
		CGFloat inset = MAX((CGFloat)0, TGCenteredOrigin(bounds.size.height, textHeight));
		CGContextSaveGState(ctx);
		// UIKit's context is top-down; CoreText draws bottom-up.
		CGContextTranslateCTM(ctx, bounds.origin.x, bounds.origin.y + bounds.size.height);
		CGContextScaleCTM(ctx, 1, -1);
		CGContextSetTextMatrix(ctx, CGAffineTransformIdentity);
		for (CFIndex i = 0; i < shown; i++) {
			CTLineRef line = drawn[(size_t)i];
			CGFloat ascent = 0, descent = 0, leading = 0;
			double width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
					- CTLineGetTrailingWhitespaceWidth(line);
			CGFloat x = 0;
			if (alignment == NSTextAlignmentCenter)
				x = TGCenteredOrigin(bounds.size.width, (CGFloat)width);
			else if (alignment == NSTextAlignmentRight)
				x = bounds.size.width - (CGFloat)width;
			// With a pitch the baselines are the label face's, one pitch
			// apart: CoreText put the first under the emoji face's taller
			// ascent and the last line's foot out of the frame.
			CGFloat baselineDown = lineHeight > 0 ? inset + i * lineHeight + faceAscent
					: inset + (top - origins[(size_t)i].y);
			TGDrawLine(ctx, line, CGPointMake(x, bounds.size.height - baselineDown), ascent, descent, scale);
			CFRelease(line);
		}
		CGContextRestoreGState(ctx);
	}
	if (frame)
		CFRelease(frame);
}

NSUInteger TGTextRenderIndexAtPoint(NSAttributedString *text, CGSize size, CGPoint point) {
	if (!text.length || size.width <= 0 || size.height <= 0)
		return NSNotFound;
	CTFrameRef frame = TGTextFrameCreate(TGTextPrepared(text), size.width, size.height);
	if (!frame)
		return NSNotFound;
	NSUInteger found = NSNotFound;
	CFArrayRef lines = CTFrameGetLines(frame);
	CFIndex count = lines ? CFArrayGetCount(lines) : 0;
	std::vector<CGPoint> origins((size_t)MAX(count, (CFIndex)1));
	if (count > 0)
		CTFrameGetLineOrigins(frame, CFRangeMake(0, count), origins.data());
	// CoreText counts up from the bottom of its (taller) box.
	CGPoint flipped = CGPointMake(point.x, size.height + kTGTextOverflow - point.y);
	for (CFIndex i = 0; i < count; i++) {
		CTLineRef line = (CTLineRef)CFArrayGetValueAtIndex(lines, i);
		CGFloat ascent = 0, descent = 0, leading = 0;
		double width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
		CGPoint origin = origins[(size_t)i];
		if (flipped.y > origin.y + ascent || flipped.y < origin.y - descent)
			continue;
		// Past the last glyph is on no character: the run-off after a link
		// must not open it.
		if (flipped.x < origin.x || flipped.x > origin.x + width)
			break;
		CFIndex index = CTLineGetStringIndexForPosition(line, CGPointMake(flipped.x - origin.x, 0));
		// The index is the caret nearest the touch; the character is the
		// one whose box holds it.
		if (index != kCFNotFound && index > 0 &&
				CTLineGetOffsetForStringIndex(line, index, NULL) > flipped.x - origin.x)
			index--;
		if (index != kCFNotFound && index >= 0 && (NSUInteger)index < text.length)
			found = (NSUInteger)index;
		break;
	}
	CFRelease(frame);
	return found;
}

#pragma mark - cache

namespace {

struct TGKeyHash {
	size_t operator()(NSString *key) const { return (size_t)key.hash; }
};
struct TGKeyEqual {
	bool operator()(NSString *a, NSString *b) const { return [a isEqualToString:b]; }
};

struct TGTextEntry {
	NSString *key;
	CGImageRef image;
	size_t bytes;
	NSArray *emojiRects;
};

// Main thread only: the render queue hands its pictures back there.
std::list<TGTextEntry> gEntries;
std::unordered_map<NSString *, std::list<TGTextEntry>::iterator, TGKeyHash, TGKeyEqual> gIndex;
size_t gBytes = 0;
NSMutableSet *gInFlight = nil;

/// Room for the pictures of about two screens of long posts at 2x: a body
/// 228 x 400 pt is 730 KB. The 32-bit ceiling for one cache is 16 MB; on a
/// 256 MB device (iPod touch 4, 3GS) the chat grew by 12-17 MB with 8, so
/// there it holds about one screen.
size_t TGTextCacheLimit(void) {
	static size_t limit;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		limit = ([TGCapabilities memoryMB] <= 256 ? 4u : 8u) * 1024 * 1024;
	});
	return limit;
}

void TGTextEvict(void) {
	while (gBytes > TGTextCacheLimit() && !gEntries.empty()) {
		TGTextEntry &last = gEntries.back();
		gBytes -= last.bytes;
		gIndex.erase(last.key);
		CGImageRelease(last.image);
		gEntries.pop_back();
	}
}

dispatch_queue_t TGTextRenderQueue(void) {
	static dispatch_queue_t queue;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		// One at a time and below the main thread: the A4 has one core.
		queue = dispatch_queue_create("org.legacy.itg.text-render", DISPATCH_QUEUE_SERIAL);
		dispatch_set_target_queue(queue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
	});
	return queue;
}

/// Tall bodies, never held (TGMetricTextHoldMaxHeight): the main thread
/// would draw one whole when its row came in.
dispatch_queue_t TGTextRenderTallQueue(void) {
	static dispatch_queue_t queue;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		queue = dispatch_queue_create("org.legacy.itg.text-render-tall", DISPATCH_QUEUE_SERIAL);
		dispatch_set_target_queue(queue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
	});
	return queue;
}

}

CGImageRef TGTextRenderCached(NSString *key) {
	if (!key)
		return NULL;
	auto hit = gIndex.find(key);
	if (hit == gIndex.end())
		return NULL;
	gEntries.splice(gEntries.begin(), gEntries, hit->second);
	return hit->second->image;
}

static void TGTextRenderStoreWithRects(NSString *key, CGImageRef image, NSArray *rects);

void TGTextRenderStore(NSString *key, CGImageRef image) {
	TGTextRenderStoreWithRects(key, image, nil);
}

NSArray *TGTextRenderCachedEmojiRects(NSString *key) {
	auto hit = key ? gIndex.find(key) : gIndex.end();
	return hit == gIndex.end() ? nil : hit->second->emojiRects;
}

static void TGTextRenderStoreWithRects(NSString *key, CGImageRef image, NSArray *rects) {
	if (!key || !image)
		return;
	static dispatch_once_t once;
	static id memoryObserver;
	dispatch_once(&once, ^{
		// The pictures are redrawn on demand; under pressure they go first.
		// Held for the life of the process, as the cache is.
		memoryObserver = [[NSNotificationCenter defaultCenter] addObserverForName:@"UIApplicationDidReceiveMemoryWarningNotification"
				object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
			TGTextRenderClearCache();
		}];
	});
	auto hit = gIndex.find(key);
	if (hit != gIndex.end()) {
		gBytes -= hit->second->bytes;
		CGImageRelease(hit->second->image);
		gEntries.erase(hit->second);
		gIndex.erase(hit);
	}
	size_t bytes = CGImageGetBytesPerRow(image) * CGImageGetHeight(image);
	gEntries.push_front(TGTextEntry{ [key copy], CGImageRetain(image), bytes, rects });
	gIndex[gEntries.front().key] = gEntries.begin();
	gBytes += bytes;
	TGTextEvict();
}

void TGTextRenderPrefetch(NSString *key, CGSize size, CGFloat scale, NSAttributedString *(^build)(void)) {
	if (!key || !build || gIndex.count(key))
		return;
	if (!gInFlight)
		gInFlight = [NSMutableSet set];
	if ([gInFlight containsObject:key])
		return;
	[gInFlight addObject:key];
	NSString *name = [key copy];
	dispatch_queue_t queue = size.height > TGMetricTextHoldMaxHeight ? TGTextRenderTallQueue() : TGTextRenderQueue();
	dispatch_async(queue, ^{
		pthread_setname_np("tg.text-render");
		double start = TGPerfNow();
		NSAttributedString *text = build();
		CGImageRef image = TGTextRenderCan(text) ? TGTextRenderCreateImage(text, size, scale) : NULL;
		// The same layout places the custom emoji: worked out here, the cell
		// does not lay the text out again on the main thread to find them.
		NSArray *rects = image ? TGCustomEmojiRectsCoreText(text, size.width) : nil;
		TGPerfReport("text render", "background", start, 50.0);
		dispatch_async(dispatch_get_main_queue(), ^{
			[gInFlight removeObject:name];
			TGTextRenderStoreWithRects(name, image, rects);
			if (image)
				CGImageRelease(image);
		});
	});
}

void TGTextRenderHold(BOOL held) {
	static BOOL sHeld;
	if (held == sHeld)
		return;
	sHeld = held;
	if (held)
		dispatch_suspend(TGTextRenderQueue());
	else
		dispatch_resume(TGTextRenderQueue());
}

void TGTextRenderClearCache(void) {
	for (TGTextEntry &entry : gEntries)
		CGImageRelease(entry.image);
	gEntries.clear();
	gIndex.clear();
	gBytes = 0;
}

size_t TGTextRenderCacheBytes(void) {
	return gBytes;
}
