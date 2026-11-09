#import "TGIconsInternal.h"

static NSMutableDictionary *sSettingsIconCache = nil;

void TGIconsClearSettingsIconCache(void) {
	[sSettingsIconCache removeAllObjects];
}

@implementation TGIcons (Menu)

/// The line art beside each row of their pop-up menu, by catalogue name. Every
/// glyph is a path in TGIconPaths; a name it does not know answers nil, so a
/// row with no glyph is better than a row with a hole where one should be.
+ (UIImage *)menuGlyphNamed:(NSString *)name {
	if ([name isEqualToString:@"contact"])
		name = @"contacts";
	return [self pathIconNamed:name];
}

+ (UIImage *)glyphNamed:(NSString *)name colour:(UIColor *)colour side:(CGFloat)side {
	// A nil role used to leave the context's own fill, which on an empty
	// bitmap is transparent: the glyph silently disappeared. A caller that
	// could not resolve a colour still gets readable text.
	if (!colour)
		colour = [[TGTheme shared] primaryTextColour];
	NSString *key = [NSString stringWithFormat:@"glyph-%@-%.0f-%@", name, side, colour];
	UIImage *cached = TGIconsGetCached(key);
	if (cached) return cached;

	UIImage *glyph = [self menuGlyphNamed:name];
	if (!glyph) return nil;

	UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), NO, 0);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGContextTranslateCTM(ctx, 0, side);
	CGContextScaleCTM(ctx, 1.0, -1.0);
	CGContextClipToMask(ctx, CGRectMake(0, 0, side, side), glyph.CGImage);
	[colour setFill];
	CGContextFillRect(ctx, CGRectMake(0, 0, side, side));
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

	if (image) TGIconsSetCached(key, image);
	return image;
}

+ (UIImage *)settingsIconNamed:(NSString *)name color:(UIColor *)color {
	// Every settings row asks for its icon in cellForRow, and the list reloads
	// on every appearance - redrawing sixteen of these each time is what made
	// the screen crawl on a 4S.
	if (!color)
		color = [[TGTheme shared] accentColour];
	if (!sSettingsIconCache) sSettingsIconCache = [NSMutableDictionary dictionary];
	NSString *cacheKey = [NSString stringWithFormat:@"%@|%@", name, color];
	UIImage *hit = sSettingsIconCache[cacheKey];
	if (hit) return hit;

	CGFloat side = 29.0;
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), NO, 0);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	(void)ctx;

	// Draw rounded square background
	UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, side, side) cornerRadius:6.0];
	[color setFill];
	[path fill];

	// Get line glyph and draw it centered in white
	UIImage *glyph = [self menuGlyphNamed:name];

	if (glyph) {
		// Draw white glyph centered on the colored background plate.
		CGFloat w = glyph.size.width;
		CGFloat h = glyph.size.height;
		CGRect rect = CGRectMake((side - w) / 2.0, (side - h) / 2.0, w, h);
		
		// To tint the template image in the on-accent role
		UIGraphicsBeginImageContextWithOptions(glyph.size, NO, 0);
		CGContextRef tintCtx = UIGraphicsGetCurrentContext();
		CGContextTranslateCTM(tintCtx, 0, h);
		CGContextScaleCTM(tintCtx, 1.0, -1.0);
		CGContextClipToMask(tintCtx, CGRectMake(0, 0, w, h), glyph.CGImage);
		[[[TGTheme shared] onAccentColour] setFill];
		CGContextFillRect(tintCtx, CGRectMake(0, 0, w, h));
		UIImage *tintedGlyph = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();
		
		[tintedGlyph drawInRect:rect];
	}

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	if (image) sSettingsIconCache[cacheKey] = image;
	return image;
}

@end
