//
// TGMessageLayout.mm - Geometry, sizing and C++ LRU layout cache for chat bubbles.
//
#import "TGMessageLayout.h"
#import "TGLocalization.h"
#import "TGStyle.h"
#import "TGEmojiPictures.h"
#import <CoreText/CoreText.h>
#import "TGLruCache.hpp"
#import "TGPerf.h"
#import "TGUIFormat.h"
#include <time.h>
#include <string.h>
#include <pthread.h>

#ifndef typeof
#define typeof __typeof__
#endif

@interface TGMessageLayoutCache () {
	TGLruCache<int64_t, TGMessageLayout *> _lru;
}
@end

@implementation TGMessageLayoutCache

- (instancetype)init {
	return [self initWithCapacity:500];
}

- (instancetype)initWithCapacity:(NSUInteger)capacity {
	if ((self = [super init])) {
		_lru.set_capacity(capacity ? capacity : 500);
	}
	return self;
}

- (TGMessageLayout *)layoutForMessageId:(int64_t)msgId {
	TGMessageLayout *hit = nil;
	if (_lru.get(msgId, hit)) {
		return hit;
	}
	return nil;
}

- (void)setLayout:(TGMessageLayout *)layout forMessageId:(int64_t)msgId {
	TGMessageLayout *old = nil;
	if (_lru.get(msgId, old))
		_generation++;
	if (layout) {
		_lru.put(msgId, layout);
	} else {
		_lru.remove(msgId);
	}
}

- (void)removeLayoutForMessageId:(int64_t)msgId {
	_lru.remove(msgId);
	_generation++;
}

- (void)clear {
	_lru.clear();
	_generation++;
}

- (NSUInteger)count {
	return _lru.size();
}

- (TGMessageLayout *)objectForKeyedSubscript:(id)key {
	if ([key respondsToSelector:@selector(longLongValue)]) {
		return [self layoutForMessageId:[key longLongValue]];
	}
	return nil;
}

- (void)setObject:(TGMessageLayout *)obj forKeyedSubscript:(id)key {
	if ([key respondsToSelector:@selector(longLongValue)]) {
		[self setLayout:obj forMessageId:[key longLongValue]];
	}
}

- (void)removeAllObjects {
	[self clear];
}

- (void)removeObjectForKey:(id)key {
	if ([key respondsToSelector:@selector(longLongValue)]) {
		[self removeLayoutForMessageId:[key longLongValue]];
	}
}

@end

// ─── Key hashing ──────────────────────────────────────────────────────────────

static inline uint64_t TGFNV1a64(NSString *str) {
	if (!str.length) return 0;
	uint64_t hash = 14695981039346656037ULL;
	NSUInteger len = str.length;
	const UniChar *direct = CFStringGetCharactersPtr((__bridge CFStringRef)str);
	UniChar buf[128];
	NSUInteger offset = 0;
	while (offset < len) {
		const UniChar *p;
		NSUInteger count;
		if (direct) {
			p = direct + offset;
			count = len - offset;
		} else {
			count = MIN((NSUInteger)128, len - offset);
			[str getCharacters:buf range:NSMakeRange(offset, count)];
			p = buf;
		}
		for (NSUInteger i = 0; i < count; i++) {
			hash ^= (uint64_t)(p[i]);
			hash *= 1099511628211ULL;
		}
		offset += count;
	}
	return hash;
}

struct EmojiKey {
	uint64_t textHash;
	uint32_t fontSizeInt;

	bool operator==(const EmojiKey &o) const {
		return textHash == o.textHash && fontSizeInt == o.fontSizeInt;
	}
};

namespace std {
	template <>
	struct hash<EmojiKey> {
		size_t operator()(const EmojiKey &k) const {
			return (size_t)(k.textHash ^ ((uint64_t)k.fontSizeInt << 32));
		}
	};
}

struct TextSizeKey {
	uint64_t textHash;
	uint16_t widthInt;
	uint16_t fontSizeInt;
	uint16_t entitiesCount;

	bool operator==(const TextSizeKey &o) const {
		return textHash == o.textHash &&
			   widthInt == o.widthInt &&
			   fontSizeInt == o.fontSizeInt &&
			   entitiesCount == o.entitiesCount;
	}
};

namespace std {
	template <>
	struct hash<TextSizeKey> {
		size_t operator()(const TextSizeKey &k) const {
			return (size_t)(k.textHash ^ ((uint64_t)k.widthInt << 48) ^ ((uint64_t)k.fontSizeInt << 32) ^ k.entitiesCount);
		}
	};
}

static TGLruCache<EmojiKey, id> sEmojiCache(500);
static TGLruCache<TextSizeKey, CGSize> sTextSizeCache(1000);
// The chat measures a page of history on a background queue before the table
// reloads (TGMeasureMessageTexts), so both caches are read from two threads.
// Only the lookups hold it: a measure takes up to 300 ms on the A4 and the
// main thread must not wait for one.
static pthread_mutex_t sTextCachesLock = PTHREAD_MUTEX_INITIALIZER;

// ─── Font & Emoji helpers ─────────────────────────────────────────────────────

UIFont *TGEmojiFontOfSize(CGFloat size) {
	static BOOL logged = NO;
	UIFont *font = [UIFont fontWithName:TGEmojiFaceName() size:size];
	if (!font) font = [UIFont fontWithName:@"AppleColorEmoji" size:size];
	if (!font) font = [UIFont fontWithName:@"Apple Color Emoji" size:size];
	if (!font) font = [UIFont fontWithName:@"OpenMojiColor" size:size];
	if (!font) font = [UIFont fontWithName:@"OpenMoji Color" size:size];
	if (!font) font = [UIFont fontWithName:@"OpenMoji" size:size];
	if (!font) font = [UIFont systemFontOfSize:size];
	if (!logged){
		logged = YES;
		NSLog(@"emoji font: %@", font ? font.fontName
				: @"NOT REGISTERED - check UIAppFonts in Info.plist");
	}
	return font;
}

BOOL TGIsEmojiScalar(UTF32Char c) {
	return (c >= 0x1F000 && c <= 0x1FAFF) ||   // pictographs, faces, flags, symbols
		   (c >= 0x2600  && c <= 0x27BF)  ||   // misc symbols and dingbats
		   (c >= 0x2B00  && c <= 0x2BFF)  ||   // arrows and stars
		   (c >= 0x2000  && c <= 0x23FF)  ||   // technical symbols, watch, hourglass
		   (c >= 0x2900  && c <= 0x297F)  ||   // supplemental arrows
		   (c >= 0x3000  && c <= 0x32FF)  ||   // CJK symbols / ideographs
		   c == 0x00A9   || c == 0x00AE   ||   // copyright, registered
		   c == 0x203C   || c == 0x2049   ||   // !!, !?
		   c == 0x2122   || c == 0x2139;       // TM, info
}

/// Joiners, variation selectors, combining marks and tags have no glyph of
/// their own; they shape the character before them and must stay.
static BOOL TGIsShapingScalar(UTF32Char c) {
	return (c >= 0x0300 && c <= 0x036F) || (c >= 0x200B && c <= 0x206F) ||
		   c == 0x20E3 || (c >= 0xFE00 && c <= 0xFE0F) ||
		   (c >= 0xE0000 && c <= 0xE007F);
}

NSString *TGStripScalars(NSString *text, BOOL (*drawable)(UTF32Char)) {
	NSUInteger len = text.length;
	if (!len)
		return text;
	NSMutableString *out = nil;
	NSUInteger i = 0;
	while (i < len){
		unichar unit = [text characterAtIndex:i];
		NSUInteger width = 1;
		UTF32Char c = unit;
		if (CFStringIsSurrogateHighCharacter(unit) && i + 1 < len &&
				CFStringIsSurrogateLowCharacter([text characterAtIndex:i + 1])){
			c = CFStringGetLongCharacterForSurrogatePair(unit, [text characterAtIndex:i + 1]);
			width = 2;
		}
		// Emoji are asked like the rest: one newer than the device's emoji
		// font sends CoreText to disk exactly as a hieroglyph does.
		BOOL keep = c < 0x0250 || TGIsShapingScalar(c) || drawable(c);
		if (!keep && !out)
			out = [[text substringToIndex:i] mutableCopy];
		else if (keep && out)
			[out appendString:[text substringWithRange:NSMakeRange(i, width)]];
		i += width;
	}
	return out ?: text;
}

/// The system font and the fallback list UIKit itself walks, created once.
/// A character none of them has is the one that made CoreText open every
/// font on disk; asking these few directly costs a glyph lookup each.
static NSArray *TGFallbackFonts(void) {
	static NSArray *fonts = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		NSMutableArray *list = [NSMutableArray array];
		UIFont *body = TGFontBody();
		CTFontRef base = CTFontCreateWithName((__bridge CFStringRef)body.fontName,
				body.pointSize, NULL);
		if (base){
			[list addObject:(__bridge_transfer id)base];
			if (&CTFontCopyDefaultCascadeListForLanguages != NULL){
				CFArrayRef cascade = CTFontCopyDefaultCascadeListForLanguages(base, NULL);
				for (CFIndex k = 0; cascade && k < CFArrayGetCount(cascade); k++){
					CTFontDescriptorRef d = (CTFontDescriptorRef)CFArrayGetValueAtIndex(cascade, k);
					CTFontRef f = CTFontCreateWithFontDescriptor(d, body.pointSize, NULL);
					if (f)
						[list addObject:(__bridge_transfer id)f];
				}
				if (cascade)
					CFRelease(cascade);
			}
		}
		CTFontRef emoji = CTFontCreateWithName((__bridge CFStringRef)TGEmojiFaceName(), body.pointSize, NULL);
		if (!emoji)
			emoji = CTFontCreateWithName(CFSTR("AppleColorEmoji"), body.pointSize, NULL);
		if (emoji)
			[list addObject:(__bridge_transfer id)emoji];
		fonts = list;
	});
	return fonts;
}

static BOOL TGFontsHaveScalar(UTF32Char c) {
	static NSMutableDictionary *answers = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ answers = [NSMutableDictionary dictionary]; });
	NSNumber *key = @(c), *known;
	@synchronized (answers){
		known = answers[key];
	}
	if (known)
		return known.boolValue;
	UniChar units[2];
	CFIndex count = CFStringGetSurrogatePairForLongCharacter(c, units) ? 2 : 1;
	if (count == 1)
		units[0] = (UniChar)c;
	BOOL found = NO;
	for (id font in TGFallbackFonts()){
		CGGlyph glyphs[2] = {0, 0};
		if (CTFontGetGlyphsForCharacters((__bridge CTFontRef)font, units, glyphs, count) && glyphs[0]){
			found = YES;
			break;
		}
	}
	@synchronized (answers){
		answers[key] = @(found);
	}
	return found;
}

NSString *TGStripUndrawableScalars(NSString *text) {
	return TGStripScalars(text, TGFontsHaveScalar);
}

NSString *TGFirstDrawableCharacter(NSString *title) {
	NSString *shown = TGStripUndrawableScalars(title ?: @"");
	return shown.length
			? [shown substringWithRange:[shown rangeOfComposedCharacterSequenceAtIndex:0]] : @"?";
}

/// Whether Apple Color Emoji itself has the scalar. A face elsewhere in the
/// cascade may draw it as a plain symbol (U+2604 COMET on iOS 7), but then the
/// U+FE0F after it has no face at all and CoreText scans every font on disk.
static BOOL TGAppleEmojiHasScalar(UTF32Char c) {
	static NSMutableDictionary *answers = nil;
	static CTFontRef emoji = NULL;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		answers = [NSMutableDictionary dictionary];
		emoji = CTFontCreateWithName((__bridge CFStringRef)TGEmojiFaceName(), TGFontBody().pointSize, NULL);
		if (!emoji)
			emoji = CTFontCreateWithName(CFSTR("AppleColorEmoji"), TGFontBody().pointSize, NULL);
	});
	NSNumber *key = @(c), *known;
	@synchronized (answers){
		known = answers[key];
	}
	if (known)
		return known.boolValue;
	UniChar units[2];
	CFIndex count = CFStringGetSurrogatePairForLongCharacter(c, units) ? 2 : 1;
	if (count == 1)
		units[0] = (UniChar)c;
	CGGlyph glyphs[2] = {0, 0};
	BOOL found = emoji && CTFontGetGlyphsForCharacters(emoji, units, glyphs, count) && glyphs[0];
	@synchronized (answers){
		answers[key] = @(found);
	}
	return found;
}

/// An emoji scalar Apple Color Emoji lacks; message bubbles draw these from
/// the bundled OpenMoji.
static BOOL TGNeedsBundledEmoji(UTF32Char c) {
	return TGIsEmojiScalar(c) && !TGAppleEmojiHasScalar(c);
}

/// U+FE0F after an emoji Apple Color Emoji lacks has no face on iOS 7 at all:
/// the symbol itself comes from the system cascade, its selector from nowhere,
/// and CoreText searched every font on disk for it. A Saved Messages preview
/// of four comets (U+2604 U+FE0F) cost 2.4 s cold and 0.48 s warm in the first
/// chat row's layout. The selector only asks for colour presentation, which
/// that face cannot give, so dropping it changes nothing drawn.
BOOL TGMarkUndrawableEmoji(NSMutableAttributedString *text, CGFloat size) {
	(void)size;
	return TGDropEmojiSelectors(text, TGNeedsBundledEmoji);
}

BOOL TGDropEmojiSelectors(NSMutableAttributedString *text, BOOL (*lacking)(UTF32Char)) {
	NSString *string = text.string;
	BOOL changed = NO;
	NSUInteger i = string.length;
	while (i > 0){
		i--;
		if ([string characterAtIndex:i] != 0xFE0F || i == 0)
			continue;
		NSUInteger base = i - 1;
		UTF32Char c = [string characterAtIndex:base];
		if (CFStringIsSurrogateLowCharacter((UniChar)c) && base > 0){
			UniChar high = [string characterAtIndex:base - 1];
			if (CFStringIsSurrogateHighCharacter(high))
				c = CFStringGetLongCharacterForSurrogatePair(high, (UniChar)c);
		}
		if (lacking(c)){
			[text deleteCharactersInRange:NSMakeRange(i, 1)];
			string = text.string;
			changed = YES;
		}
	}
	return changed;
}

BOOL TGTextHasUndrawableEmoji(NSString *text) {
	NSUInteger length = text.length;
	for (NSUInteger i = 1; i < length; i++){
		if ([text characterAtIndex:i] != 0xFE0F)
			continue;
		UTF32Char c = [text characterAtIndex:i - 1];
		if (CFStringIsSurrogateLowCharacter((UniChar)c) && i >= 2){
			UniChar high = [text characterAtIndex:i - 2];
			if (CFStringIsSurrogateHighCharacter(high))
				c = CFStringGetLongCharacterForSurrogatePair(high, (UniChar)c);
		}
		if (TGNeedsBundledEmoji(c))
			return YES;
	}
	return NO;
}

static inline BOOL TGTextContainsEmoji(NSString *text) {
	NSUInteger len = text.length;
	if (len == 0) return NO;

	const UniChar *direct = CFStringGetCharactersPtr((__bridge CFStringRef)text);
	UniChar stackBuf[256];
	if (!direct) {
		for (NSUInteger offset = 0; offset < len; offset += 256) {
			NSUInteger chunk = MIN((NSUInteger)256, len - offset);
			[text getCharacters:stackBuf range:NSMakeRange(offset, chunk)];
			for (NSUInteger i = 0; i < chunk; i++) {
				UniChar c = stackBuf[i];
				if (c >= 0xD800 && c <= 0xDBFF && (i + 1 < chunk)) {
					UniChar low = stackBuf[i + 1];
					if (low >= 0xDC00 && low <= 0xDFFF) {
						UTF32Char cp = (((c - 0xD800) << 10) | (low - 0xDC00)) + 0x10000;
						if (TGIsEmojiScalar(cp)) return YES;
						i++;
						continue;
					}
				}
				if (TGIsEmojiScalar(c)) return YES;
			}
		}
		return NO;
	}

	for (NSUInteger i = 0; i < len; i++) {
		UniChar c = direct[i];
		if (c >= 0xD800 && c <= 0xDBFF && (i + 1 < len)) {
			UniChar low = direct[i + 1];
			if (low >= 0xDC00 && low <= 0xDFFF) {
				UTF32Char cp = (((c - 0xD800) << 10) | (low - 0xDC00)) + 0x10000;
				if (TGIsEmojiScalar(cp)) return YES;
				i++;
				continue;
			}
		}
		if (TGIsEmojiScalar(c)) return YES;
	}
	return NO;
}

NSAttributedString *TGEmojiAttributedText(NSString *text, UIFont *base) {
	if (!text.length)
		return nil;

	EmojiKey key = { TGFNV1a64(text), (uint32_t)(base.pointSize * 10.0f) };
	id hit = nil;
	pthread_mutex_lock(&sTextCachesLock);
	BOOL known = sEmojiCache.get(key, hit);
	pthread_mutex_unlock(&sTextCachesLock);
	if (known)
		return (hit == [NSNull null]) ? nil : (NSAttributedString *)hit;

	if (!TGTextContainsEmoji(text)) {
		pthread_mutex_lock(&sTextCachesLock);
		sEmojiCache.put(key, [NSNull null]);
		pthread_mutex_unlock(&sTextCachesLock);
		return nil;
	}

	UIFont *emojiFont = TGEmojiFontOfSize(base.pointSize);
	__block NSMutableAttributedString *styled = nil;
	if (emojiFont){
		[text enumerateSubstringsInRange:NSMakeRange(0, text.length)
								 options:NSStringEnumerationByComposedCharacterSequences
							  usingBlock:^(NSString *piece, NSRange range,
										   NSRange enclosing, BOOL *stop){
			UTF32Char first = [piece characterAtIndex:0];
			if (piece.length >= 2 && CFStringIsSurrogateHighCharacter(first))
				first = (UTF32Char)CFStringGetLongCharacterForSurrogatePair(
						first, [piece characterAtIndex:1]);
			if (!TGIsEmojiScalar(first))
				return;
			if (!styled)
				styled = [[NSMutableAttributedString alloc] initWithString:text
						attributes:@{NSFontAttributeName : base}];
			[styled addAttribute:NSFontAttributeName value:emojiFont range:range];
		}];
	}

	pthread_mutex_lock(&sTextCachesLock);
	sEmojiCache.put(key, styled ?: (id)[NSNull null]);
	pthread_mutex_unlock(&sTextCachesLock);
	return styled;
}

/// The bundled face's size for a flag against the text's.
static const CGFloat kTGFlagFaceScale = 1.0f;

static BOOL TGIsRegionalIndicator(UTF32Char c) {
	return c >= 0x1F1E6 && c <= 0x1F1FF;
}

NSArray *TGUnsupportedFlagRanges(NSString *text, BOOL (*has)(UTF32Char, UTF32Char)) {
	NSUInteger length = text.length;
	if (length < 4)
		return @[];
	// Most strings have no flag: one pass for the high surrogate all regional
	// indicators share (U+1F1E6-1F1FF are D83C DDE6-DDFF) before any work.
	const UniChar *units = CFStringGetCharactersPtr((__bridge CFStringRef)text);
	NSMutableData *copy = nil;
	if (!units) {
		copy = [NSMutableData dataWithLength:length * sizeof(UniChar)];
		[text getCharacters:(UniChar *)copy.mutableBytes range:NSMakeRange(0, length)];
		units = (const UniChar *)copy.bytes;
	}
	NSMutableArray *ranges = nil;
	for (NSUInteger i = 0; i + 3 < length; i++) {
		if (units[i] != 0xD83C || units[i + 2] != 0xD83C)
			continue;
		UTF32Char first = CFStringGetLongCharacterForSurrogatePair(units[i], units[i + 1]);
		UTF32Char second = CFStringGetLongCharacterForSurrogatePair(units[i + 2], units[i + 3]);
		if (!TGIsRegionalIndicator(first) || !TGIsRegionalIndicator(second))
			continue;
		if (!has(first, second)) {
			if (!ranges)
				ranges = [NSMutableArray array];
			[ranges addObject:[NSValue valueWithRange:NSMakeRange(i, 4)]];
		}
		i += 3;
	}
	return ranges ?: @[];
}

BOOL TGAppleEmojiHasFlag(UTF32Char first, UTF32Char second) {
	// 2 bits per pair of the 26 x 26: known, and the answer.
	static uint8_t answers[26 * 26];
	static CTFontRef emoji = NULL;
	if (!TGIsRegionalIndicator(first) || !TGIsRegionalIndicator(second))
		return NO;
	size_t pair = (first - 0x1F1E6) * 26 + (second - 0x1F1E6);
	if (answers[pair])
		return answers[pair] == 2;
	if (!emoji)
		emoji = CTFontCreateWithName((__bridge CFStringRef)TGEmojiFaceName(), 20, NULL);
	if (!emoji)
		emoji = CTFontCreateWithName(CFSTR("AppleColorEmoji"), 20, NULL);
	UniChar units[4];
	CFStringGetSurrogatePairForLongCharacter(first, units);
	CFStringGetSurrogatePairForLongCharacter(second, units + 2);
	BOOL drawn = NO;
	if (emoji) {
		NSString *flag = [NSString stringWithCharacters:units length:4];
		NSAttributedString *shaped = [[NSAttributedString alloc] initWithString:flag
				attributes:@{ (__bridge NSString *)kCTFontAttributeName : (__bridge id)emoji }];
		CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)shaped);
		// One glyph from the emoji face is the flag; two are the letters.
		drawn = line && CTLineGetGlyphCount(line) == 1;
		if (line)
			CFRelease(line);
	}
	answers[pair] = drawn ? 2 : 1;
	return drawn;
}

NSAttributedString *TGFlagFallbackText(NSString *text, UIFont *base, UIColor *colour) {
	// iOS 7: every emoji, not only flags, as a picture from the bundled face.
	if (TGEmojiPicturesActive()){
		if (!text.length || !base)
			return nil;
		NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithObject:base
				forKey:NSFontAttributeName];
		if (colour)
			attributes[NSForegroundColorAttributeName] = colour;
		return TGEmojiPictureText([[NSAttributedString alloc] initWithString:text
				attributes:attributes], base);
	}
	NSArray *ranges = TGUnsupportedFlagRanges(text, TGAppleEmojiHasFlag);
	if (!ranges.count || !base)
		return nil;
	// OpenMoji fills its whole em; at the text's size the flag stood well
	// above the letters and the system emoji around it.
	UIFont *emojiFont = TGEmojiFontOfSize(roundf(base.pointSize * kTGFlagFaceScale));
	if (!emojiFont)
		return nil;
	NSMutableAttributedString *out = [[NSMutableAttributedString alloc] initWithString:text
			attributes:@{ NSFontAttributeName : base }];
	if (colour)
		[out addAttribute:NSForegroundColorAttributeName value:colour range:NSMakeRange(0, out.length)];
	for (NSValue *range in ranges)
		[out addAttribute:NSFontAttributeName value:emojiFont range:range.rangeValue];
	return out;
}

static TGCustomEmojiProvider sCustomEmojiProvider = NULL;

void TGSetCustomEmojiProvider(TGCustomEmojiProvider provider) {
	sCustomEmojiProvider = provider;
}

/// An empty picture standing in until the real one arrives. The attachment's
/// bounds hold the size, so the bubble keeps the size it was measured at and
/// nothing is drawn in the gap. A nil image would draw iOS's file icon.
static UIImage *TGEmptyPicture(void) {
	static UIImage *empty = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ empty = [[UIImage alloc] init]; });
	return empty;
}

NSAttributedString *TGCustomEmojiSpacer(int64_t emojiId, UIFont *font) {
	// A clear symbol, not a space: UIKit hangs a space at the end of a line
	// past the margin, CoreText (which places the pictures) wraps it to the
	// next line, and every custom emoji after one that ended a line drew a
	// line low. "@" breaks no line; kern expands the advance to match the
	// full emoji side so consecutive emoji in a row do not collide.
	CGFloat side = TGCustomEmojiSide(font);
	CGFloat charW = [@"@" sizeWithFont:font].width;
	CGFloat kern = MAX(0.0f, side - charW);

	NSMutableAttributedString *spacer = [[NSMutableAttributedString alloc] initWithString:@"@"];
	NSRange all = NSMakeRange(0, 1);
	[spacer addAttribute:@"TGCustomEmojiId" value:@(emojiId) range:all];
	[spacer addAttribute:@"TGCustomEmojiSide" value:@(side) range:all];
	[spacer addAttribute:NSFontAttributeName value:font range:all];
	[spacer addAttribute:NSForegroundColorAttributeName value:[UIColor clearColor] range:all];
	if (kern > 0.0f) {
		[spacer addAttribute:NSKernAttributeName value:@(kern) range:all];
		[spacer addAttribute:(__bridge NSString *)kCTKernAttributeName value:@(kern) range:all];
	}
	return spacer;
}

CGFloat TGCustomEmojiSide(UIFont *font) {
	CGFloat natural = ceilf(font.ascender - font.descender);
	CGFloat emojiScale = ceilf(font.pointSize * 1.35f);
	return MAX(natural, emojiScale);
}

BOOL TGEntitiesHaveSpoiler(NSArray *entities) {
	if (![entities isKindOfClass:[NSArray class]])
		return NO;
	for (id ent in entities) {
		if (![ent isKindOfClass:[NSDictionary class]])
			continue;
		NSDictionary *entity = (NSDictionary *)ent;
		id typeObj = entity[@"type"];
		NSString *type = nil;
		if ([typeObj isKindOfClass:[NSDictionary class]]) {
			id inner = ((NSDictionary *)typeObj)[@"@type"];
			if ([inner isKindOfClass:[NSString class]])
				type = inner;
		} else if ([typeObj isKindOfClass:[NSString class]]) {
			type = (NSString *)typeObj;
		}
		if (!type && [entity[@"@type"] isKindOfClass:[NSString class]])
			type = entity[@"@type"];
		if ([type isEqualToString:@"textEntityTypeSpoiler"] || [type isEqualToString:@"messageEntitySpoiler"])
			return YES;
	}
	return NO;
}

NSAttributedString *TGAttributedMessageTextRevealing(NSString *text, NSArray *entities, UIFont *baseFont, UIColor *textColor, BOOL revealSpoilers) {
	if (!text.length)
		return nil;
	if (!baseFont)
		baseFont = TGFontBody();
	if (!textColor)
		textColor = [UIColor blackColor];
	// A date entity reads in the reader's clock; its words replace the
	// sender's before anything is measured, so layout and drawing agree.
	NSArray *datedEntities = nil;
	NSString *dated = TGApplyDateEntities(text, entities, [[NSDate date] timeIntervalSince1970],
			&datedEntities);
	if (dated){
		text = dated;
		entities = datedEntities;
	}

	// 1. Emoji font substitution on base text
	NSMutableAttributedString *str = nil;
	NSAttributedString *emojiStr = TGEmojiAttributedText(text, baseFont);
	if (emojiStr) {
		str = [emojiStr mutableCopy];
	} else {
		str = [[NSMutableAttributedString alloc] initWithString:text attributes:@{
			NSFontAttributeName : baseFont,
			NSForegroundColorAttributeName : textColor
		}];
	}
	[str addAttribute:NSForegroundColorAttributeName value:textColor range:NSMakeRange(0, str.length)];

	if (!entities.count)
		return str;

	CGFloat size = baseFont.pointSize;
	UIColor *linkColour = TGColourLink();
	NSMutableArray *customEmoji = [NSMutableArray array];

	for (NSDictionary *ent in entities) {
		if (![ent isKindOfClass:[NSDictionary class]])
			continue;
		NSInteger offset = [ent[@"offset"] integerValue];
		NSInteger length = [ent[@"length"] integerValue];
		if (offset < 0 || length <= 0 || (offset + length) > (NSInteger)str.length)
			continue;

		NSRange range = NSMakeRange(offset, length);
		id typeObj = ent[@"type"];
		NSString *type = nil;
		if ([typeObj isKindOfClass:[NSDictionary class]]) {
			type = typeObj[@"@type"];
		} else if ([typeObj isKindOfClass:[NSString class]]) {
			type = (NSString *)typeObj;
		}
		if (!type && [ent[@"@type"] isKindOfClass:[NSString class]]) {
			type = ent[@"@type"];
		}

		if ([type isEqualToString:@"textEntityTypeBold"] || [type isEqualToString:@"messageEntityBold"] || [type isEqualToString:@"bold"]) {
			[str addAttribute:NSFontAttributeName value:TGFontBoldAtSize(size) range:range];
		} else if ([type isEqualToString:@"textEntityTypeItalic"] || [type isEqualToString:@"messageEntityItalic"] || [type isEqualToString:@"italic"]) {
			[str addAttribute:NSFontAttributeName value:TGFontItalicAtSize(size) range:range];
		} else if ([type isEqualToString:@"textEntityTypeUnderline"] || [type isEqualToString:@"messageEntityUnderline"] || [type isEqualToString:@"underline"]) {
			[str addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:range];
		} else if ([type isEqualToString:@"textEntityTypeStrikethrough"] || [type isEqualToString:@"messageEntityStrikethrough"] || [type isEqualToString:@"strikethrough"]) {
			[str addAttribute:NSStrikethroughStyleAttributeName value:@(NSUnderlineStyleSingle) range:range];
		} else if ([type isEqualToString:@"textEntityTypeCode"] || [type isEqualToString:@"messageEntityCode"] ||
				   [type isEqualToString:@"textEntityTypePre"]  || [type isEqualToString:@"messageEntityPre"] ||
				   [type isEqualToString:@"textEntityTypePreCode"] || [type isEqualToString:@"code"]) {
			UIFont *mono = TGFontCodeAtSize(MAX(TGFontSizeMicro, size - TGMetricTextPadV));
			if (mono)
				[str addAttribute:NSFontAttributeName value:mono range:range];
			[str addAttribute:NSBackgroundColorAttributeName value:TGColourCodeBackground() range:range];
		} else if ([type isEqualToString:@"textEntityTypeTextUrl"] || [type isEqualToString:@"messageEntityTextUrl"]) {
			// A bare URL is the next branch: it has no url of its own, and
			// caught here it was left black and dead.
			NSString *urlStr = nil;
			if ([typeObj isKindOfClass:[NSDictionary class]]) {
				urlStr = typeObj[@"url"];
			}
			if (!urlStr.length) {
				urlStr = ent[@"url"];
			}
			if (urlStr.length) {
				[str addAttribute:NSForegroundColorAttributeName value:linkColour range:range];
				[str addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:range];
				[str addAttribute:@"TGLinkURL" value:urlStr range:range];
			}
		} else if ([type isEqualToString:@"textEntityTypeUrl"] || [type isEqualToString:@"messageEntityUrl"] || [type isEqualToString:@"url"]) {
			NSString *urlStr = [text substringWithRange:range];
			[str addAttribute:NSForegroundColorAttributeName value:linkColour range:range];
			[str addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:range];
			[str addAttribute:@"TGLinkURL" value:urlStr range:range];
		} else if ([type isEqualToString:@"textEntityTypeEmailAddress"] || [type isEqualToString:@"textEntityTypePhoneNumber"]) {
			NSString *link = [text substringWithRange:range];
			[str addAttribute:NSForegroundColorAttributeName value:linkColour range:range];
			[str addAttribute:@"TGLinkURL" value:link range:range];
		} else if ([type isEqualToString:@"textEntityTypeMediaTimestamp"] && [typeObj isKindOfClass:NSDictionary.class]) {
			// "0:42" plays the message's video from there.
			[str addAttribute:NSForegroundColorAttributeName value:linkColour range:range];
			[str addAttribute:@"TGLinkURL"
						value:TGMediaTimestampLink([typeObj[@"media_timestamp"] intValue]) range:range];
		} else if ([type isEqualToString:@"textEntityTypeDateTime"]) {
			[str addAttribute:NSForegroundColorAttributeName value:linkColour range:range];
		} else if ([type isEqualToString:@"textEntityTypeMention"] || [type isEqualToString:@"textEntityTypeHashtag"] ||
				   [type isEqualToString:@"textEntityTypeBotCommand"]) {
			[str addAttribute:NSForegroundColorAttributeName value:linkColour range:range];
		} else if ([type isEqualToString:@"textEntityTypeSpoiler"] || [type isEqualToString:@"messageEntitySpoiler"]) {
			// The same colour in both roles makes the glyphs disappear into a
			// solid plate without changing the run's width or height.
			if (!revealSpoilers) {
				UIColor *plate = TGColourCodeBlockBackground();
				[str addAttribute:NSBackgroundColorAttributeName value:plate range:range];
				[str addAttribute:NSForegroundColorAttributeName value:plate range:range];
			}
		} else if ([type isEqualToString:@"textEntityTypeCustomEmoji"] || [type isEqualToString:@"messageEntityCustomEmoji"]) {
			int64_t emojiId = 0;
			if ([typeObj isKindOfClass:NSDictionary.class]) {
				emojiId = [typeObj[@"custom_emoji_id"] longLongValue];
			}
			if (emojiId == 0) {
				id eid = ent[@"customEmojiId"] ?: ent[@"custom_emoji_id"];
				if ([eid respondsToSelector:@selector(longLongValue)])
					emojiId = [eid longLongValue];
			}
			if (emojiId)
				[customEmoji addObject:@[@(offset), @(length), @(emojiId)]];
		}
	}

	// Entities above (bold, italic, code) apply text fonts across their whole range,
	// which overwrites the emoji font on any emoji in that range. Re-apply the
	// system emoji font to any emoji character runs without changing the string.
	UIFont *emojiFont = TGEmojiFontOfSize(size);
	if (emojiFont) {
		NSString *stringVal = str.string;
		[stringVal enumerateSubstringsInRange:NSMakeRange(0, stringVal.length)
									  options:NSStringEnumerationByComposedCharacterSequences
								   usingBlock:^(NSString *piece, NSRange r, NSRange enclosing, BOOL *stop) {
			UTF32Char first = [piece characterAtIndex:0];
			if (piece.length >= 2 && CFStringIsSurrogateHighCharacter(first))
				first = (UTF32Char)CFStringGetLongCharacterForSurrogatePair(first, [piece characterAtIndex:1]);
			if (TGIsEmojiScalar(first)) {
				[str addAttribute:NSFontAttributeName value:emojiFont range:r];
			}
		}];
	}

	// Custom emoji last, from the end backwards: each one turns its fallback
	// characters into a single attachment, which moves everything after it.
	// No NSTextAttachment before iOS 7, so there the fallback emoji stays.
	if (customEmoji.count) {
		[customEmoji sortUsingComparator:^NSComparisonResult(NSArray *a, NSArray *b){
			return [b[0] compare:a[0]];
		}];
		CGFloat side = TGCustomEmojiSide(baseFont);
		if (TGCustomEmojiInlineSupported()) {
			for (NSArray *entry in customEmoji) {
				NSRange range = NSMakeRange([entry[0] unsignedIntegerValue], [entry[1] unsignedIntegerValue]);
				int64_t emojiId = [entry[2] longLongValue];
				// Off the main thread the text is only being measured
				// (TGMeasureMessageTexts): the attachment's bounds decide
				// the size, and the store that has the pictures lives on main.
				UIImage *picture = sCustomEmojiProvider && [NSThread isMainThread]
						? sCustomEmojiProvider(emojiId, side) : nil;
				NSTextAttachment *attachment = [[NSClassFromString(@"NSTextAttachment") alloc] init];
				attachment.image = picture ?: TGEmptyPicture();
				// Sat on the baseline like a glyph, its bottom at the descender.
				attachment.bounds = CGRectMake(0, baseFont.descender, side, side);
				NSMutableAttributedString *glyph = [[NSAttributedString attributedStringWithAttachment:attachment] mutableCopy];
				[glyph addAttribute:@"TGCustomEmojiId" value:@(emojiId) range:NSMakeRange(0, glyph.length)];
				[str replaceCharactersInRange:range withAttributedString:glyph];
			}
		} else {
			// iOS 6: attachments have no bounds, so replace the fallback color emoji
			// with an em-space spacer. This completely prevents the AppleColorEmoji
			// bitmap glyph from drawing underneath or overlapping the custom emoji view.
			for (NSArray *entry in customEmoji) {
				NSRange range = NSMakeRange([entry[0] unsignedIntegerValue], [entry[1] unsignedIntegerValue]);
				int64_t emojiId = [entry[2] longLongValue];
				[str replaceCharactersInRange:range withAttributedString:TGCustomEmojiSpacer(emojiId, baseFont)];
			}
		}
	}

	// iOS 7 last of all, once every entity has its range: the emoji become
	// pictures read from the bundled face (TGEmojiPictures).
	if (TGEmojiPicturesActive()){
		NSAttributedString *pictures = TGEmojiPictureText(str, baseFont);
		if (pictures)
			return pictures;
	}
	return str;
}

BOOL TGCustomEmojiInlineSupported(void) {
	static BOOL sSupported = NO;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		// The whole attachment story is iOS 7 and later: iOS 6 has a private
		// NSTextAttachment without -setBounds:, and its UIKit string drawing
		// lays the picture out at its own size. Ask about the methods
		// themselves rather than trusting the class lookup, the way
		// TGCustomEmojiRectsInText asks about the TextKit stack.
		Class attachmentClass = NSClassFromString(@"NSTextAttachment");
		sSupported = attachmentClass &&
				[attachmentClass instancesRespondToSelector:@selector(setBounds:)] &&
				[attachmentClass instancesRespondToSelector:@selector(setImage:)] &&
				[NSAttributedString respondsToSelector:
						@selector(attributedStringWithAttachment:)];
	});
	return sSupported;
}

// iOS 6 has no TextKit, so the rects come from CoreText, whose framesetter
// the bubble's tap hit-testing already runs on that OS. CoreText counts y
// upward from the frame's bottom while the label draws downward, so a line's
// top sits at frameH - origin.y - ascent; the frame is made tall enough that
// the first line still lands at the top.
#import <pthread.h>

static id TGCachedCTFont(id font) {
	if (![font respondsToSelector:@selector(fontName)] || ![font respondsToSelector:@selector(pointSize)])
		return nil;
	NSString *name = [font fontName];
	CGFloat size = [font pointSize];
	if (!name.length)
		return nil;
	NSString *key = [NSString stringWithFormat:@"%@/%.2f", name, size];
	static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
	static NSMutableDictionary *cache = nil;
	pthread_mutex_lock(&lock);
	if (!cache)
		cache = [[NSMutableDictionary alloc] init];
	id ctFont = cache[key];
	pthread_mutex_unlock(&lock);
	if (ctFont)
		return ctFont;
	ctFont = CFBridgingRelease(CTFontCreateWithName((__bridge CFStringRef)name, size, NULL));
	if (ctFont) {
		pthread_mutex_lock(&lock);
		if (cache.count > 64)
			[cache removeAllObjects];
		cache[key] = ctFont;
		pthread_mutex_unlock(&lock);
	}
	return ctFont;
}

NSAttributedString *TGCoreTextFonts(NSAttributedString *text) {
	if (!text.length)
		return text;
	NSMutableAttributedString *out = nil;
	NSRange all = NSMakeRange(0, text.length);
	NSRange range;
	for (NSUInteger i = 0; i < text.length; i = NSMaxRange(range)) {
		id font = [text attribute:NSFontAttributeName atIndex:i longestEffectiveRange:&range inRange:all];
		if (!font || CFGetTypeID((__bridge CFTypeRef)font) == CTFontGetTypeID())
			continue;
		id ctFont = TGCachedCTFont(font);
		if (!ctFont)
			continue;
		if (!out)
			out = [text mutableCopy];
		[out addAttribute:(__bridge NSString *)kCTFontAttributeName value:ctFont range:range];
	}
	return out ?: text;
}

static BOOL TGHasCustomEmojiAttribute(NSAttributedString *text) {
	NSUInteger len = text.length;
	if (!len)
		return NO;
	NSRange all = NSMakeRange(0, len);
	NSRange range;
	for (NSUInteger i = 0; i < len; i = NSMaxRange(range)) {
		id val = [text attribute:@"TGCustomEmojiId" atIndex:i longestEffectiveRange:&range inRange:all];
		if ([val isKindOfClass:NSNumber.class] && [val longLongValue] != 0)
			return YES;
	}
	return NO;
}

NSArray *TGCustomEmojiRectsCoreText(NSAttributedString *text, CGFloat width) {
	if (!TGHasCustomEmojiAttribute(text))
		return @[];
	// iOS 6 has no toll-free UIFont/CTFont bridge: handed the label's string
	// as is, CoreText laid it out in its default 12 pt face, wrapped it in
	// other places than the label did, and every custom emoji after the first
	// few lines landed a line or more off its fallback characters.
	text = TGCoreTextFonts(text);
	CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString(
			(__bridge CFAttributedStringRef)text);
	if (!framesetter)
		return @[];
	CGFloat frameHeight = 10000.0f;
	CGPathRef path = CGPathCreateWithRect(
			CGRectMake(0.0f, 0.0f, width, frameHeight), NULL);
	CTFrameRef frame = CTFramesetterCreateFrame(
			framesetter, CFRangeMake(0, 0), path, NULL);

	NSMutableArray *results = [NSMutableArray array];
	CFArrayRef lines = CTFrameGetLines(frame);
	NSInteger lineCount = lines ? CFArrayGetCount(lines) : 0;
	if (lineCount > 0) {
		CGPoint origins[lineCount];
		CTFrameGetLineOrigins(frame, CFRangeMake(0, lineCount), origins);
		for (NSInteger i = 0; i < lineCount; i++) {
			CTLineRef line = (CTLineRef)CFArrayGetValueAtIndex(lines, i);
			CFArrayRef runs = CTLineGetGlyphRuns(line);
			NSInteger runCount = runs ? CFArrayGetCount(runs) : 0;
			if (!runCount)
				continue;
			CGFloat ascent = 0.0f, descent = 0.0f, leading = 0.0f;
			CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
			CGFloat lineTop = frameHeight - origins[i].y - ascent;
			CGFloat lineHeight = ascent + descent;
			CGFloat prevEmojiMaxX = -CGFLOAT_MAX;
			for (NSInteger j = 0; j < runCount; j++) {
				CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, j);
				NSDictionary *attributes = (__bridge NSDictionary *)CTRunGetAttributes(run);
				NSNumber *emojiId = attributes[@"TGCustomEmojiId"];
				if (![emojiId isKindOfClass:[NSNumber class]] || [emojiId longLongValue] == 0)
					continue;
				CFRange runRange = CTRunGetStringRange(run);
				if (runRange.length <= 0)
					continue;
				CGFloat runAscent = 0.0f, runDescent = 0.0f, runLeading = 0.0f;
				CTRunGetTypographicBounds(run,
						CFRangeMake(0, CTRunGetGlyphCount(run)),
						&runAscent, &runDescent, &runLeading);
				// The picture was decoded at the square the string builder
				// asked for; centre it over the fallback glyph.
				CGFloat side = runAscent + runDescent;
				NSNumber *sideAttr = attributes[@"TGCustomEmojiSide"];
				if ([sideAttr isKindOfClass:[NSNumber class]] && [sideAttr doubleValue] > 0)
					side = [sideAttr doubleValue];
				// One rect per character, not per run: the same emoji three
				// times in a row has equal attributes and comes back as one
				// run, which drew a single picture in the middle of the three.
				for (CFIndex k = runRange.location; k < runRange.location + runRange.length; k++) {
					CGFloat x = CTLineGetOffsetForStringIndex(line, k, NULL);
					CGFloat width = CTLineGetOffsetForStringIndex(line, k + 1, NULL) - x;
					if (width <= 0)
						continue;
					CGFloat emojiX = (width >= side) ? (x + TGHalf(width - side)) : x;
					if (emojiX < prevEmojiMaxX)
						emojiX = prevEmojiMaxX;
					CGRect emojiRect = CGRectIntegral(CGRectMake(emojiX,
							lineTop + TGHalf(lineHeight - side), side, side));
					prevEmojiMaxX = CGRectGetMaxX(emojiRect);
					NSValue *rectVal = nil;
#if TARGET_OS_IPHONE
					rectVal = [NSValue valueWithCGRect:emojiRect];
#else
					rectVal = [NSValue valueWithBytes:&emojiRect objCType:@encode(CGRect)];
#endif
					[results addObject:@{
						@"id"   : emojiId,
						@"rect" : rectVal
					}];
				}
			}
		}
	}

	CFRelease(frame);
	CGPathRelease(path);
	CFRelease(framesetter);
	return results;
}

NSArray *TGCustomEmojiRectsInText(NSAttributedString *text, CGFloat width) {
	if (!text.length || width <= 0 || !TGHasCustomEmojiAttribute(text))
		return @[];

	Class lmClass = NSClassFromString(@"NSLayoutManager");
	Class tcClass = NSClassFromString(@"NSTextContainer");
	Class tsClass = NSClassFromString(@"NSTextStorage");
	// The whole layout stack is iOS 7 and later. iOS 6 has private classes
	// with these names but without -initWithSize:, so ask about the methods
	// themselves rather than trusting the class lookup.
	if (!lmClass || !tcClass || !tsClass ||
		![tcClass instancesRespondToSelector:@selector(initWithSize:)] ||
		![lmClass instancesRespondToSelector:@selector(addTextContainer:)] ||
		![tsClass instancesRespondToSelector:@selector(addLayoutManager:)])
		return TGCustomEmojiRectsCoreText(text, width);

	NSTextStorage *storage = [[tsClass alloc] initWithAttributedString:text];
	NSLayoutManager *layoutManager = [[lmClass alloc] init];
	CGSize containerSize = CGSizeMake(width, CGFLOAT_MAX);
	NSTextContainer *container = [[tcClass alloc] initWithSize:containerSize];
	container.lineFragmentPadding = 0;
	[layoutManager addTextContainer:container];
	[storage addLayoutManager:layoutManager];
	[layoutManager ensureLayoutForTextContainer:container];

	NSMutableArray *results = [NSMutableArray array];
	[text enumerateAttribute:@"TGCustomEmojiId"
					 inRange:NSMakeRange(0, text.length)
					 options:0
				  usingBlock:^(id value, NSRange run, BOOL *stop) {
		if (!value || ![value isKindOfClass:NSNumber.class])
			return;
		int64_t emojiId = [value longLongValue];
		if (emojiId == 0)
			return;

		// Each attachment is one character; equal neighbours arrive as one run.
		for (NSUInteger k = run.location; k < NSMaxRange(run); k++) {
		NSRange range = NSMakeRange(k, 1);
		NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:range actualCharacterRange:NULL];
		if (glyphRange.location == NSNotFound || glyphRange.length == 0)
			continue;

		CGRect glyphRect = [layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:container];
		if (CGRectIsEmpty(glyphRect))
			continue;

		CGFloat side = glyphRect.size.width;
		id attachment = [text attribute:NSAttachmentAttributeName atIndex:range.location effectiveRange:NULL];
		if ([attachment respondsToSelector:@selector(bounds)]) {
			CGRect b = [attachment bounds];
			if (b.size.width > 0)
				side = b.size.width;
		}
		CGRect emojiRect = CGRectMake(glyphRect.origin.x,
									  glyphRect.origin.y + TGHalf(glyphRect.size.height - side),
									  side,
									  side);
		emojiRect = CGRectIntegral(emojiRect);

		NSValue *rectVal = nil;
#if TARGET_OS_IPHONE
		rectVal = [NSValue valueWithCGRect:emojiRect];
#else
		rectVal = [NSValue valueWithBytes:&emojiRect objCType:@encode(CGRect)];
#endif

		[results addObject:@{
			@"id"   : @(emojiId),
			@"rect" : rectVal ?: [NSNull null]
		}];
		}
	}];

	return results;
}

NSAttributedString *TGAttributedMessageText(NSString *text, NSArray *entities, UIFont *baseFont, UIColor *textColor) {
	return TGAttributedMessageTextRevealing(text, entities, baseFont, textColor, NO);
}

void TGSetBodyText(UILabel *label, NSString *text, UIColor *colour) {
	NSAttributedString *rich = TGEmojiAttributedText(text, label.font);
	if (!rich){
		label.textColor = colour;
		label.text = text;
		return;
	}
	NSMutableAttributedString *coloured = [rich mutableCopy];
	[coloured addAttribute:NSForegroundColorAttributeName value:colour
					 range:NSMakeRange(0, coloured.length)];
	label.attributedText = coloured;
}

CGSize TGTextSizeWithEntities(NSString *text, NSArray *entities, UIFont *font, CGFloat width) {
	if (!text.length)
		return CGSizeZero;

	TextSizeKey key = {
		TGFNV1a64(text),
		(uint16_t)(width > 0 ? (uint16_t)width : 0),
		(uint16_t)(font ? (uint16_t)(font.pointSize * 10.0f) : 0),
		(uint16_t)entities.count
	};

	CGSize cachedSize;
	pthread_mutex_lock(&sTextCachesLock);
	BOOL known = sTextSizeCache.get(key, cachedSize);
	pthread_mutex_unlock(&sTextCachesLock);
	if (known)
		return cachedSize;

	CGSize size = CGSizeZero;
	// Over budget, the measure itself says it was the cost: text measures
	// are made per unique string on the first appearance of a line.
	double measureStart = TGPerfNow();
	// Plain text goes on the label as a plain string (TGSetBodyText), so it is
	// measured as one: the attributed boundingRect took 72-93 ms for 60
	// bubbles on an iPod touch 4, sizeWithFont: 7 ms, for the same heights.
	BOOL plain = !entities.count && !TGTextContainsEmoji(text);
	NSAttributedString *rich = plain ? nil
			: TGAttributedMessageText(text, entities, font, [UIColor blackColor]);

	if (width > 0) {
		if (rich) {
			CTFramesetterRef setter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)TGCoreTextFonts(rich));
			CGSize ctSize = CGSizeZero;
			if (setter) {
				CFRange fitRange;
				ctSize = CTFramesetterSuggestFrameSizeWithConstraints(
						setter, CFRangeMake(0, 0), NULL,
						CGSizeMake(width, CGFLOAT_MAX), &fitRange);
				CFRelease(setter);
			}
			CGRect rect = CGRectZero;
			// On iOS 6 (!TGCustomEmojiInlineSupported()), TGRenderedLabel draws
			// via CoreText directly; boundingRectWithSize: would run WebCore's
			// string drawing a second time for every rich post.
			if (TGCustomEmojiInlineSupported() &&
					[rich respondsToSelector:@selector(boundingRectWithSize:options:context:)]) {
				rect = [rich boundingRectWithSize:CGSizeMake(width, TGMetricTextMeasureHeight)
										 options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
										 context:nil];
			}
			CGFloat w = MAX(ceilf(rect.size.width), ceilf(ctSize.width));
			CGFloat h = MAX(ceilf(rect.size.height), ceilf(ctSize.height));
			size = CGSizeMake(w + TGMetricTextPadH, h + TGMetricTextPadV);
		} else {
			size = [text sizeWithFont:font
					constrainedToSize:CGSizeMake(width, TGMetricTextMeasureHeight)
						lineBreakMode:NSLineBreakByWordWrapping];
			size = CGSizeMake(ceilf(size.width) + TGMetricTextPadH, ceilf(size.height) + TGMetricTextPadV);
		}
	} else {
		if (rich) {
			CTFramesetterRef setter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)TGCoreTextFonts(rich));
			CGSize ctSize = CGSizeZero;
			if (setter) {
				CFRange fitRange;
				ctSize = CTFramesetterSuggestFrameSizeWithConstraints(
						setter, CFRangeMake(0, 0), NULL,
						CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX), &fitRange);
				CFRelease(setter);
			}
			CGSize rSize = CGSizeZero;
			if ([rich respondsToSelector:@selector(size)])
				rSize = [rich size];
			CGFloat w = MAX(ceilf(rSize.width), ceilf(ctSize.width));
			CGFloat h = MAX(ceilf(rSize.height), ceilf(ctSize.height));
			size = CGSizeMake(w + TGMetricTextPadH, h + TGMetricTextPadV);
		} else {
			size = [text sizeWithFont:font];
			size = CGSizeMake(ceilf(size.width) + TGMetricTextPadH, ceilf(size.height) + TGMetricTextPadV);
		}
	}

	pthread_mutex_lock(&sTextCachesLock);
	sTextSizeCache.put(key, size);
	pthread_mutex_unlock(&sTextCachesLock);
	TGPerfReport("text measure", NULL, measureStart, 10.0);
	return size;
}

CGFloat TGInlineStampY(CGRect bodyFrame) {
	return CGRectGetMaxY(bodyFrame) - TGMetricLineMicro;
}

CGSize TGTextSize(NSString *text, UIFont *font, CGFloat width) {
	return TGTextSizeWithEntities(text, nil, font, width);
}

NSString *TGDescribeMessageContent(NSDictionary *m) {
	if (!m || ![m isKindOfClass:NSDictionary.class]) return @"...";
	NSString *text = m[@"text"];
	if (text.length) return text;

	NSString *kind = m[@"kind"] ?: @"";
	if ([kind isEqualToString:@"messageVideoNote"])
		return @"Video message";
	if ([kind isEqualToString:@"messageVoiceNote"])
		return @"Voice message";
	if ([kind isEqualToString:@"messageSticker"] || [kind isEqualToString:@"messageAnimatedEmoji"]) {
		NSString *emoji = m[@"extra"] ?: m[@"emoji"];
		return emoji.length ? [NSString stringWithFormat:@"Sticker %@", emoji] : @"Sticker";
	}
	if ([kind isEqualToString:@"messagePhoto"])
		return @"Photo";
	if ([kind isEqualToString:@"messageVideo"])
		return @"Video";
	if ([kind isEqualToString:@"messageAnimation"])
		return @"GIF";
	if ([kind isEqualToString:@"messageDocument"]) {
		NSString *docName = m[@"docName"];
		return docName.length ? docName : @"Document";
	}
	if ([kind isEqualToString:@"messageAudio"]) {
		NSString *title = m[@"audioTitle"];
		return title.length ? title : @"Audio";
	}
	if ([kind isEqualToString:@"messageLocation"] || [kind isEqualToString:@"messageLiveLocation"])
		return @"Location";
	if ([kind isEqualToString:@"messageContact"])
		return @"Contact";
	if ([kind isEqualToString:@"messagePoll"])
		return @"Poll";
	if ([kind isEqualToString:@"messageCall"])
		return @"Call";
	if ([kind isEqualToString:@"messageDice"])
		return @"Dice";
	if ([kind isEqualToString:@"messageGame"])
		return @"Game";
	if ([kind isEqualToString:@"messageStory"])
		return @"Story";

	if ([kind hasPrefix:@"message"]) {
		NSString *shortKind = [kind substringFromIndex:7];
		if (shortKind.length) {
			NSMutableString *spaced = [NSMutableString stringWithString:[shortKind substringToIndex:1]];
			for (NSUInteger i = 1; i < shortKind.length; i++) {
				unichar c = [shortKind characterAtIndex:i];
				if (c >= 'A' && c <= 'Z')
					[spaced appendFormat:@" %c", (char)(c - 'A' + 'a')];
				else
					[spaced appendFormat:@"%C", c];
			}
			return spaced;
		}
	}
	return @"...";
}

NSString *TGMessageStamp(NSTimeInterval timestamp, BOOL edited) {
	if (timestamp <= 0)
		return @"";
	NSDate *date = [NSDate dateWithTimeIntervalSince1970:timestamp];
	// The app's own clock: the device's 12/24-hour choice and separator, not
	// a hand-written %02d:%02d that ignored both.
	// One formatter for every bubble: building one costs ~1 ms on the A4.
	// Row layouts of a history page run on a background queue as well as on
	// main, and an iOS 6 formatter is not thread-safe: one at a time.
	static NSDateFormatter *clock = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		clock = [[NSDateFormatter alloc] init];
		clock.dateStyle = NSDateFormatterNoStyle;
		clock.timeStyle = NSDateFormatterShortStyle;
	});
	NSString *time;
	@synchronized (clock) {
		time = [clock stringFromDate:date] ?: @"";
	}
	if (edited)
		return [NSString stringWithFormat:@"%@ %@", TGLocalized(@"edited"), time];
	return time;
}

void TGVideoNoteLayoutBottomBar(CGRect bubbleFrame,
								CGFloat durWidth,
								CGFloat clockWidth,
								bool mine,
								bool unplayed,
								CGRect *outDurFrame,
								CGRect *outTimeFrame,
								CGRect *outTicksFrame,
								CGRect *outDotFrame) {
	CGFloat clockY = CGRectGetMaxY(bubbleFrame) + TGMetricPadSmall;

	// Duration on the left side under the circle
	if (outDurFrame) {
		*outDurFrame = CGRectMake(CGRectGetMinX(bubbleFrame) + TGMetricPadSmall,
								  clockY,
								  durWidth,
								  TGMetricStampHeight);
	}

	// Time group on the right side under the circle: clock + ticks + unplayed dot
	CGFloat ticksW = mine ? (TGMetricPadSmall + TGMetricTicksWidth) : 0.0f;
	CGFloat dotW = unplayed ? (TGMetricPadSmall + TGMetricUnreadDotSide) : 0.0f;
	CGFloat groupW = clockWidth + ticksW + dotW;
	CGFloat groupX = CGRectGetMaxX(bubbleFrame) - groupW - TGMetricPadSmall;

	if (outTimeFrame) {
		*outTimeFrame = CGRectMake(groupX, clockY, clockWidth, TGMetricStampHeight);
	}
	if (outTicksFrame) {
		*outTicksFrame = CGRectMake(groupX + clockWidth + TGMetricPadSmall,
									clockY + TGCenteredOrigin(TGMetricStampHeight, TGMetricTicksHeight),
									TGMetricTicksWidth,
									TGMetricTicksHeight);
	}
	if (outDotFrame) {
		*outDotFrame = CGRectMake(groupX + clockWidth + ticksW + TGMetricPadSmall,
								  clockY + TGCenteredOrigin(TGMetricStampHeight, TGMetricUnreadDotSide),
								  TGMetricUnreadDotSide,
								  TGMetricUnreadDotSide);
	}
}

@implementation TGMessageLayout
@end
