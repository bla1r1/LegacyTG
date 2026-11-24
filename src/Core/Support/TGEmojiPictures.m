//
// TGEmojiPictures.m
//
#import "TGEmojiPictures.h"

static NSString *sFontPath, *sMapPath;
static NSData *sFont;                     // the face, mapped
static NSDictionary *sGlyphs;             // "1F1FA-1F1E6" -> glyph id
static NSSet *sTextDefault;               // single code points that need FE0F
static NSUInteger sLongest;               // most code points in one sequence
static NSIndexSet *sFirsts;               // every sequence's first code point
static const uint8_t *sStrike;            // the sbix strike's start
static uint32_t sGlyphCount;
static NSLock *sLoadLock;

static uint32_t TGPicU32(const uint8_t *p) { return (uint32_t)p[0] << 24 | p[1] << 16 | p[2] << 8 | p[3]; }
static uint16_t TGPicU16(const uint8_t *p) { return (uint16_t)(p[0] << 8 | p[1]); }

void TGEmojiPicturesUseFiles(NSString *fontPath, NSString *mapPath) {
	sFontPath = [fontPath copy];
	sMapPath = [mapPath copy];
	sFont = nil;
	sGlyphs = nil;
}

BOOL TGEmojiPicturesActive(void) {
#if TARGET_OS_IPHONE
	return NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1 &&
			NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_8_0;
#else
	return NO;
#endif
}

/// Reads the table and finds the strike once. Any thread: the text is laid
/// out off the main thread too.
static BOOL TGEmojiPicturesLoad(void) {
	static dispatch_once_t once;
	dispatch_once(&once, ^{ sLoadLock = [[NSLock alloc] init]; });
	[sLoadLock lock];
	if (!sGlyphs){
		NSString *fontPath = sFontPath ?: [[NSBundle mainBundle]
				pathForResource:@"AppleColorEmojiCompat" ofType:@"ttf"];
		NSString *mapPath = sMapPath ?: [[NSBundle mainBundle]
				pathForResource:@"AppleColorEmojiCompat" ofType:@"map"];
		NSData *font = fontPath ? [NSData dataWithContentsOfFile:fontPath
				options:NSDataReadingMappedIfSafe error:NULL] : nil;
		NSString *map = mapPath ? [NSString stringWithContentsOfFile:mapPath
				encoding:NSUTF8StringEncoding error:NULL] : nil;
		const uint8_t *b = font.bytes;
		uint32_t sbix = 0, maxp = 0;
		if (font.length > 12)
			for (uint16_t i = 0; i < TGPicU16(b + 4) && 12 + 16 * (i + 1) <= font.length; i++){
				const uint8_t *record = b + 12 + 16 * i;
				if (!memcmp(record, "sbix", 4)) sbix = TGPicU32(record + 8);
				if (!memcmp(record, "maxp", 4)) maxp = TGPicU32(record + 8);
			}
		if (sbix && maxp && sbix + 12 < font.length && maxp + 6 < font.length && map.length){
			sGlyphCount = TGPicU16(b + maxp + 4);
			sStrike = b + sbix + TGPicU32(b + sbix + 8);
			NSMutableDictionary *glyphs = [NSMutableDictionary dictionaryWithCapacity:4096];
			NSMutableSet *textDefault = [NSMutableSet set];
			NSMutableIndexSet *firsts = [NSMutableIndexSet indexSet];
			NSUInteger longest = 1;
			for (NSString *line in [map componentsSeparatedByString:@"\n"]){
				NSArray *fields = [line componentsSeparatedByString:@" "];
				if (fields.count < 2)
					continue;
				NSString *key = fields[0];
				glyphs[key] = @([fields[1] integerValue]);
				[firsts addIndex:strtoul(key.UTF8String, NULL, 16)];
				if (fields.count > 2)
					[textDefault addObject:key];
				longest = MAX(longest, [key componentsSeparatedByString:@"-"].count);
			}
			sFont = font;
			sTextDefault = textDefault;
			sFirsts = firsts;
			sLongest = longest;
			sGlyphs = glyphs;
		}
	}
	BOOL ready = sGlyphs != nil;
	[sLoadLock unlock];
	return ready;
}

static NSString *TGEmojiKey(const UTF32Char *scalars, NSUInteger count) {
	NSMutableString *key = [NSMutableString string];
	for (NSUInteger i = 0; i < count; i++){
		if (scalars[i] == 0xFE0F)
			continue;
		[key appendFormat:key.length ? @"-%X" : @"%X", (unsigned)scalars[i]];
	}
	return key;
}

static NSData *TGEmojiPNGForKey(NSString *key) {
	if (!TGEmojiPicturesLoad())
		return nil;
	NSNumber *glyph = sGlyphs[key];
	uint32_t g = glyph.unsignedIntValue;
	if (!glyph || g >= sGlyphCount)
		return nil;
	const uint8_t *end = (const uint8_t *)sFont.bytes + sFont.length;
	if (sStrike + 8 + 4 * (g + 1) + 4 > end)
		return nil;
	uint32_t from = TGPicU32(sStrike + 4 + 4 * g), to = TGPicU32(sStrike + 8 + 4 * g);
	if (to <= from + 8 || sStrike + to > end)
		return nil;
	const uint8_t *data = sStrike + from;
	if (memcmp(data + 4, "png ", 4))
		return nil;
	// A copy: the picture must not point into the mapped face.
	return [NSData dataWithBytes:data + 8 length:to - from - 8];
}

/// The scalars of `text` and where each starts in UTF-16.
static NSUInteger TGEmojiScalars(NSString *text, UTF32Char *scalars, NSUInteger *starts, NSUInteger capacity) {
	NSUInteger n = 0, length = text.length;
	for (NSUInteger i = 0; i < length && n < capacity; ){
		unichar u = [text characterAtIndex:i];
		UTF32Char c = u;
		NSUInteger width = 1;
		if (CFStringIsSurrogateHighCharacter(u) && i + 1 < length){
			unichar low = [text characterAtIndex:i + 1];
			if (CFStringIsSurrogateLowCharacter(low)){
				c = CFStringGetLongCharacterForSurrogatePair(u, low);
				width = 2;
			}
		}
		scalars[n] = c;
		starts[n] = i;
		n++;
		i += width;
	}
	starts[n] = MIN(length, n ? starts[n - 1] + (scalars[n - 1] > 0xFFFF ? 2 : 1) : 0);
	return n;
}

NSData *TGEmojiPicturePNG(NSString *sequence) {
	if (!sequence.length)
		return nil;
	UTF32Char scalars[32];
	NSUInteger starts[33];
	NSUInteger n = TGEmojiScalars(sequence, scalars, starts, 32);
	return TGEmojiPNGForKey(TGEmojiKey(scalars, n));
}

#if TARGET_OS_IPHONE
static NSCache *TGEmojiPictureCache(void) {
	static NSCache *cache;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		cache = [[NSCache alloc] init];
		// ponytail: 4 MB of drawn pictures, ~250 at body size on a 2x screen.
		cache.totalCostLimit = 4 * 1024 * 1024;
	});
	return cache;
}

UIImage *TGEmojiPicture(NSString *sequence, CGFloat side) {
	if (!sequence.length || side <= 0)
		return nil;
	CGFloat quantised = ceilf(side);
	NSString *cacheKey = [NSString stringWithFormat:@"%@|%.0f", sequence, quantised];
	UIImage *hit = [TGEmojiPictureCache() objectForKey:cacheKey];
	if (hit)
		return hit;
	NSData *png = TGEmojiPicturePNG(sequence);
	UIImage *source = png ? [UIImage imageWithData:png] : nil;
	if (!source)
		return nil;
	// Drawn once at the size it is shown: a 32 px strike scaled on every
	// frame would be the same work CoreText did, again and again.
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(quantised, quantised), NO, 0);
	[source drawInRect:CGRectMake(0, 0, quantised, quantised)];
	UIImage *picture = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	if (picture)
		[TGEmojiPictureCache() setObject:picture forKey:cacheKey
				cost:(NSUInteger)(quantised * quantised * picture.scale * picture.scale * 4)];
	return picture;
}

#else
// The host suite checks the face and the matching; it has nothing to draw with.
UIImage *TGEmojiPicture(NSString *sequence, CGFloat side) { return nil; }
#endif

NSArray *TGEmojiPictureRanges(NSString *text) {
	if (!text.length || !TGEmojiPicturesLoad())
		return @[];
	NSUInteger capacity = text.length;
	UTF32Char *scalars = malloc(sizeof(UTF32Char) * capacity);
	NSUInteger *starts = malloc(sizeof(NSUInteger) * (capacity + 1));
	NSUInteger n = TGEmojiScalars(text, scalars, starts, capacity);
	NSMutableArray *ranges = nil;
	for (NSUInteger i = 0; i < n; ){
		// Most of a message is letters no sequence starts with; a digit, # or
		// * starts one only as a keycap, with U+20E3 (and maybe FE0F) after.
		UTF32Char c = scalars[i];
		BOOL couldStart = [sFirsts containsIndex:c] && (c >= 0xA9 ||
				(i + 1 < n && (scalars[i + 1] == 0x20E3 || scalars[i + 1] == 0xFE0F)));
		NSUInteger matched = 0;
		if (couldStart)
			for (NSUInteger len = MIN(sLongest + 4, n - i); len >= 1 && !matched; len--){
				NSString *key = TGEmojiKey(scalars + i, len);
				if (!key.length || !sGlyphs[key])
					continue;
				BOOL followedBySelector = i + len < n && scalars[i + len] == 0xFE0F;
				BOOL hasSelector = followedBySelector;
				for (NSUInteger k = i; k < i + len; k++)
					if (scalars[k] == 0xFE0F) hasSelector = YES;
				if ([sTextDefault containsObject:key] && !hasSelector)
					continue;
				matched = len;
				while (i + matched < n && scalars[i + matched] == 0xFE0F)
					matched++;
			}
		if (matched){
			if (!ranges)
				ranges = [NSMutableArray array];
			[ranges addObject:[NSValue valueWithRange:NSMakeRange(starts[i],
					starts[i + matched] - starts[i])]];
			i += matched;
		} else {
			i++;
		}
	}
	free(scalars);
	free(starts);
	return ranges ?: @[];
}

#if TARGET_OS_IPHONE
NSAttributedString *TGEmojiPictureText(NSAttributedString *text, UIFont *font) {
	// Inline pictures are iOS 7 TextKit: iOS 6 has a private NSTextAttachment
	// without bounds and no attachment string. TGEmojiPicturesActive() keeps
	// iOS 6 out already; this keeps the function safe on its own.
	Class attachmentClass = NSClassFromString(@"NSTextAttachment");
	if (!text.length || !font || !attachmentClass ||
			![attachmentClass instancesRespondToSelector:@selector(setBounds:)] ||
			![NSAttributedString respondsToSelector:@selector(attributedStringWithAttachment:)])
		return nil;
	NSArray *ranges = TGEmojiPictureRanges(text.string);
	if (!ranges.count)
		return nil;
	// One line high, sitting on the descender like the custom emoji do.
	CGFloat side = MAX(ceilf(font.ascender - font.descender), ceilf(font.pointSize * 1.2f));
	NSMutableAttributedString *out = [text mutableCopy];
	for (NSValue *value in ranges.reverseObjectEnumerator){
		NSRange range = value.rangeValue;
		// A spoiler hides its text by painting the letters the plate's
		// colour; a picture would show through it, so the emoji stays text.
		NSDictionary *around = [text attributesAtIndex:range.location effectiveRange:NULL];
		UIColor *ink = around[NSForegroundColorAttributeName];
		if (ink && [ink isEqual:around[NSBackgroundColorAttributeName]])
			continue;
		UIImage *picture = TGEmojiPicture([text.string substringWithRange:range], side);
		if (!picture)
			continue;
		// ios7-guarded: the respondsToSelector: checks at the top of this function.
		NSTextAttachment *attachment = [[attachmentClass alloc] init];
		attachment.image = picture;
		attachment.bounds = CGRectMake(0, font.descender, side, side);
		NSMutableAttributedString *glyph = [[NSAttributedString
				attributedStringWithAttachment:attachment] mutableCopy];
		// The text around it keeps its colour and links for copying and taps.
		[glyph addAttributes:around range:NSMakeRange(0, glyph.length)];
		[glyph addAttribute:@"TGEmojiPictureText" value:[text.string substringWithRange:range]
				range:NSMakeRange(0, glyph.length)];
		[out replaceCharactersInRange:range withAttributedString:glyph];
	}
	return out;
}
#else
NSAttributedString *TGEmojiPictureText(NSAttributedString *text, UIFont *font) { return nil; }
#endif
