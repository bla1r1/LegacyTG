//
// TGEmojiFontTests.m - the bundled AppleColorEmojiCompat.ttf, read as bytes.
//
// iOS 7 reads every sbix glyph as a PNG. A 'flip' glyph (a pointer to another
// glyph, mirrored; iOS 9 and later) went to ImageIO as image data and the app
// died in memmove under CoreText when the emoji panel drew a person walking
// right (iPhone 4S, iOS 7.1, 23 November). The same ImageIO crash came back
// on other glyphs once the panel drew pictures: Apple's PNGs carry gAMA,
// cHRM, sRGB, eXIf and iCCP blocks iOS 7 copies past their end. Only the
// blocks a PNG needs to be drawn stay.
//
#import "TGTestRunner.h"

@interface TGEmojiFontTests : XCTestCase @end

static uint32_t TGFontU32(const uint8_t *p) { return (uint32_t)p[0] << 24 | p[1] << 16 | p[2] << 8 | p[3]; }
static uint16_t TGFontU16(const uint8_t *p) { return (uint16_t)(p[0] << 8 | p[1]); }

@implementation TGEmojiFontTests

- (void)testEveryEmojiGlyphIsAPlainPNGWithOnlyItsDrawingBlocks {
	NSData *font = [NSData dataWithContentsOfFile:@"resources/fonts/AppleColorEmojiCompat.ttf"];
	XCTAssertTrue(font.length > 1024);
	const uint8_t *b = (const uint8_t *)font.bytes;
	uint32_t sbix = 0, maxp = 0;
	for (uint16_t i = 0; i < TGFontU16(b + 4); i++){
		const uint8_t *record = b + 12 + 16 * i;
		if (!memcmp(record, "sbix", 4)) sbix = TGFontU32(record + 8);
		if (!memcmp(record, "maxp", 4)) maxp = TGFontU32(record + 8);
	}
	XCTAssertTrue(sbix && maxp);
	uint16_t glyphs = TGFontU16(b + maxp + 4);
	NSUInteger notPNG = 0, drawn = 0, extraBlocks = 0;
	for (uint32_t s = 0; s < TGFontU32(b + sbix + 4); s++){
		const uint8_t *strike = b + sbix + TGFontU32(b + sbix + 8 + 4 * s);
		for (uint16_t g = 0; g < glyphs; g++){
			uint32_t from = TGFontU32(strike + 4 + 4 * g), to = TGFontU32(strike + 8 + 4 * g);
			if (to - from <= 8)
				continue;
			const uint8_t *glyph = strike + from;
			if (memcmp(glyph + 4, "png ", 4) || memcmp(glyph + 8, "\x89PNG", 4)){
				notPNG++;
				continue;
			}
			drawn++;
			// Walk the PNG's blocks: length, four-letter type, data, CRC.
			for (uint32_t at = 8 + 8; at + 8 <= to - from; ){
				uint32_t length = TGFontU32(glyph + at);
				const char *type = (const char *)glyph + at + 4;
				if (memcmp(type, "IHDR", 4) && memcmp(type, "PLTE", 4) && memcmp(type, "tRNS", 4) &&
						memcmp(type, "IDAT", 4) && memcmp(type, "IEND", 4))
					extraBlocks++;
				at += 12 + length;
			}
		}
	}
	XCTAssertTrue(drawn > 3000);
	XCTAssertEqual(notPNG, (NSUInteger)0);
	XCTAssertEqual(extraBlocks, (NSUInteger)0);
}

@end
