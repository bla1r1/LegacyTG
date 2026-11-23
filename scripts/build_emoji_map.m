// build_emoji_map.m - which glyph of the bundled emoji face draws each emoji
// sequence, for the iOS 7 picture path (TGEmojiPictures).
//
// iOS 7 crashed in ImageIO drawing this face through CoreText under load, so
// there the app reads the glyph's PNG itself. Single code points are in cmap,
// but flags, keycaps, skin tones and ZWJ families are put together by the
// face's morx table; macOS CoreText runs it here, once, and the app looks the
// answer up.
//
//   clang -fobjc-arc -framework Foundation -framework CoreText -framework CoreGraphics \
//       scripts/build_emoji_map.m -o build/build_emoji_map
//   build/build_emoji_map resources/fonts/AppleColorEmojiCompat.ttf emoji-test.txt \
//       resources/fonts/AppleColorEmojiCompat.map
//
// emoji-test.txt is Unicode's list (unicode.org/Public/emoji/15.1/). Output:
// one line per sequence, "1F3C3-200D-2642-27A1 838", code points in hex
// without U+FE0F, sorted. A single code point that is text by default
// (copyright sign, heart: its fully-qualified form ends in FE0F) gets a
// third field "t": it is an emoji only when U+FE0F follows it.
#import <Foundation/Foundation.h>
#import <CoreText/CoreText.h>

int main(int argc, char **argv) {
	@autoreleasepool {
		if (argc != 4) {
			fprintf(stderr, "usage: %s FONT.ttf emoji-test.txt OUT.map\n", argv[0]);
			return 2;
		}
		NSURL *url = [NSURL fileURLWithPath:@(argv[1])];
		CFArrayRef descriptors = CTFontManagerCreateFontDescriptorsFromURL((__bridge CFURLRef)url);
		if (!descriptors || CFArrayGetCount(descriptors) == 0) {
			fprintf(stderr, "cannot read %s\n", argv[1]);
			return 1;
		}
		CTFontRef font = CTFontCreateWithFontDescriptor(
				(CTFontDescriptorRef)CFArrayGetValueAtIndex(descriptors, 0), 32, NULL);
		CFRelease(descriptors);

		NSString *list = [NSString stringWithContentsOfFile:@(argv[2])
				encoding:NSUTF8StringEncoding error:nil];
		NSMutableDictionary *map = [NSMutableDictionary dictionary];
		NSMutableSet *textDefault = [NSMutableSet set];
		NSUInteger tried = 0, missed = 0;
		for (NSString *line in [list componentsSeparatedByString:@"\n"]) {
			NSRange semi = [line rangeOfString:@";"];
			if (!line.length || [line hasPrefix:@"#"] || semi.location == NSNotFound)
				continue;
			NSArray *hex = [[[line substringToIndex:semi.location]
					stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]
					componentsSeparatedByString:@" "];
			NSMutableString *text = [NSMutableString string];
			NSMutableArray *key = [NSMutableArray array];
			for (NSString *h in hex) {
				if (!h.length)
					continue;
				UTF32Char c = (UTF32Char)strtoul(h.UTF8String, NULL, 16);
				UTF32Char be = CFSwapInt32HostToLittle(c);
				[text appendString:[[NSString alloc] initWithBytes:&be length:4
						encoding:NSUTF32LittleEndianStringEncoding]];
				if (c != 0xFE0F)
					[key addObject:[NSString stringWithFormat:@"%X", c]];
			}
			NSString *k = [key componentsJoinedByString:@"-"];
			if (key.count == 1 && [line rangeOfString:@"; fully-qualified"].location != NSNotFound &&
					[hex containsObject:@"FE0F"])
				[textDefault addObject:k];
			if (!k.length || map[k])
				continue;
			tried++;
			NSAttributedString *s = [[NSAttributedString alloc] initWithString:text
					attributes:@{(__bridge id)kCTFontAttributeName : (__bridge id)font}];
			CTLineRef ctLine = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)s);
			CFArrayRef runs = CTLineGetGlyphRuns(ctLine);
			// One visible glyph is a drawn emoji; anything else (two letters
			// for an unknown flag, a ZWJ left between parts) is not.
			CGGlyph only = 0;
			NSUInteger visible = 0;
			for (CFIndex r = 0; r < CFArrayGetCount(runs); r++) {
				CTRunRef run = CFArrayGetValueAtIndex(runs, r);
				CFIndex n = CTRunGetGlyphCount(run);
				CGGlyph glyphs[64];
				CGSize advances[64];
				if (n > 64)
					n = 64;
				CTRunGetGlyphs(run, CFRangeMake(0, n), glyphs);
				CTRunGetAdvances(run, CFRangeMake(0, n), advances);
				for (CFIndex g = 0; g < n; g++)
					if (glyphs[g] && advances[g].width > 0) {
						visible++;
						only = glyphs[g];
					}
			}
			CFRelease(ctLine);
			if (visible == 1)
				map[k] = @(only);
			else
				missed++;
		}
		NSMutableString *out = [NSMutableString string];
		for (NSString *k in [map.allKeys sortedArrayUsingSelector:@selector(compare:)])
			[out appendFormat:@"%@ %@%@\n", k, map[k], [textDefault containsObject:k] ? @" t" : @""];
		[out writeToFile:@(argv[3]) atomically:YES encoding:NSUTF8StringEncoding error:nil];
		printf("%lu sequences mapped, %lu tried, %lu not one glyph\n",
				(unsigned long)map.count, (unsigned long)tried, (unsigned long)missed);
		CFRelease(font);
	}
	return 0;
}
