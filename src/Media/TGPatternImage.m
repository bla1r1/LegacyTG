//
// TGPatternImage.m - gzip + nanosvg + CoreGraphics for .tgv patterns.
//
// The official renderer (Svg.m renderShape) walks nanosvg's cubic paths into a
// CGContext and fills them white. The result is a mask; the colour and the
// blend mode belong to the wallpaper, not to the SVG. Keeping the mask neutral
// lets the light and dark variants share one decode.
//
#import "TGPatternImage.h"
#import "nanosvg.h"

#import <UIKit/UIKit.h>
#import <zlib.h>
#import <limits.h>
#import <math.h>

static const size_t TGPatternMaxInflated = 8 * 1024 * 1024;
static const CGFloat TGPatternMaxSide = 4096.0f;

static BOOL TGPatternHasPrefix(NSData *data, const uint8_t *bytes, NSUInteger count) {
	if (!data || data.length < count)
		return NO;
	const uint8_t *head = data.bytes;
	for (NSUInteger i = 0; i < count; i++)
		if (head[i] != bytes[i])
			return NO;
	return YES;
}

NSData *TGPatternGunzip(NSData *data) {
	if (!data.length)
		return nil;

	// A raw SVG is useful in fixtures and costs nothing to accept. A .tgv
	// always starts with the gzip magic; zlib's 0x78 is accepted too because
	// some tools produce a zlib stream without the gzip wrapper.
	static const uint8_t gzipMagic[] = {0x1f, 0x8b};
	static const uint8_t svgMagic[] = {'<', 's', 'v', 'g'};
	if (TGPatternHasPrefix(data, svgMagic, sizeof(svgMagic)))
		return data;
	BOOL wrapped = TGPatternHasPrefix(data, gzipMagic, sizeof(gzipMagic));
	if (!wrapped && data.length > 1){
		const uint8_t *head = data.bytes;
		wrapped = head[0] == 0x78;
	}
	if (!wrapped)
		return data;

	z_stream stream;
	memset(&stream, 0, sizeof(stream));
	if (inflateInit2(&stream, 15 + 32) != Z_OK)
		return nil;
	stream.next_in = (Bytef *)data.bytes;
	stream.avail_in = (uInt)MIN(data.length, (NSUInteger)UINT_MAX);

	NSMutableData *output = [NSMutableData data];
	uint8_t chunk[16384];
	int status = Z_OK;
	while (status == Z_OK){
		stream.next_out = chunk;
		stream.avail_out = (uInt)sizeof(chunk);
		status = inflate(&stream, Z_NO_FLUSH);
		NSUInteger produced = sizeof(chunk) - stream.avail_out;
		if (produced)
			[output appendBytes:chunk length:produced];
		if (output.length > TGPatternMaxInflated){
			status = Z_MEM_ERROR;
			break;
		}
		if (stream.avail_in == 0 && produced == 0)
			break;
	}
	inflateEnd(&stream);
	if (status != Z_OK && status != Z_STREAM_END)
		return nil;
	return output.length ? output : nil;
}

static NSString *TGPatternInlineStyles(NSString *svg) {
	if (!svg.length)
		return svg;
	NSError *error = nil;
	NSRegularExpression *regex = [NSRegularExpression
			regularExpressionWithPattern:@"\\.([a-zA-Z0-9_-]+)\\s*\\{([^}]+)\\}"
								 options:0 error:&error];
	if (error || !regex)
		return svg;

	NSMutableDictionary *styles = [NSMutableDictionary dictionary];
	NSArray *matches = [regex matchesInString:svg options:0
			range:NSMakeRange(0, svg.length)];
	for (NSTextCheckingResult *match in matches){
		if (match.numberOfRanges < 3)
			continue;
		NSString *name = [svg substringWithRange:[match rangeAtIndex:1]];
		NSString *body = [svg substringWithRange:[match rangeAtIndex:2]];
		styles[name] = [body stringByTrimmingCharactersInSet:
				[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	}
	NSMutableString *result = [svg mutableCopy];
	for (NSString *name in styles){
		NSString *needle = [NSString stringWithFormat:@"class=\"%@\"", name];
		NSString *replacement = [NSString stringWithFormat:@"style=\"%@\"",
				styles[name]];
		[result replaceOccurrencesOfString:needle withString:replacement
									options:NSLiteralSearch
									  range:NSMakeRange(0, result.length)];
	}
	return result;
}

static CGContextRef TGPatternCreateContext(CGSize size, BOOL opaque) {
	if (size.width <= 0 || size.height <= 0 ||
			size.width > TGPatternMaxSide || size.height > TGPatternMaxSide)
		return NULL;
	size_t width = (size_t)size.width;
	size_t height = (size_t)size.height;
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGBitmapInfo info = (CGBitmapInfo)(kCGImageAlphaPremultipliedLast |
			kCGBitmapByteOrder32Big);
	if (opaque)
		info = (CGBitmapInfo)(kCGImageAlphaNoneSkipLast |
				kCGBitmapByteOrder32Big);
	CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8,
			width * 4, space, info);
	CGColorSpaceRelease(space);
	if (context)
		CGContextClearRect(context, CGRectMake(0, 0, size.width, size.height));
	return context;
}

static void TGPatternAddShapePath(CGContextRef context, NSVGshape *shape) {
	BOOL first = YES;
	for (NSVGpath *path = shape->paths; path; path = path->next){
		if (!first && path->closed)
			CGContextBeginPath(context);
		CGContextMoveToPoint(context, path->pts[0], path->pts[1]);
		for (int i = 0; i < path->npts - 1; i += 3){
			float *point = &path->pts[i * 2];
			CGContextAddCurveToPoint(context, point[2], point[3],
					point[4], point[5], point[6], point[7]);
		}
		if (path->closed)
			CGContextClosePath(context);
		first = NO;
	}
}

static void TGPatternRenderShape(CGContextRef context, NSVGshape *shape) {
	if (shape->fill.type != NSVG_PAINT_NONE){
		CGContextSetRGBFillColor(context, 1.0f, 1.0f, 1.0f, shape->opacity);
		CGContextBeginPath(context);
		TGPatternAddShapePath(context, shape);
		if (shape->fillRule == NSVG_FILLRULE_EVENODD)
			CGContextEOFillPath(context);
		else
			CGContextFillPath(context);
	}
	if (shape->stroke.type != NSVG_PAINT_NONE && shape->strokeWidth > 0){
		CGContextSetRGBStrokeColor(context, 1.0f, 1.0f, 1.0f, shape->opacity);
		CGContextSetLineWidth(context, shape->strokeWidth);
		CGContextSetMiterLimit(context, shape->miterLimit);
		switch (shape->strokeLineCap){
			case NSVG_CAP_ROUND: CGContextSetLineCap(context, kCGLineCapRound); break;
			case NSVG_CAP_SQUARE: CGContextSetLineCap(context, kCGLineCapSquare); break;
			default: CGContextSetLineCap(context, kCGLineCapButt); break;
		}
		switch (shape->strokeLineJoin){
			case NSVG_JOIN_BEVEL: CGContextSetLineJoin(context, kCGLineJoinBevel); break;
			case NSVG_JOIN_ROUND: CGContextSetLineJoin(context, kCGLineJoinRound); break;
			default: CGContextSetLineJoin(context, kCGLineJoinMiter); break;
		}
		for (NSVGpath *path = shape->paths; path; path = path->next){
			CGContextBeginPath(context);
			CGContextMoveToPoint(context, path->pts[0], path->pts[1]);
			for (int i = 0; i < path->npts - 1; i += 3){
				float *point = &path->pts[i * 2];
				CGContextAddCurveToPoint(context, point[2], point[3],
						point[4], point[5], point[6], point[7]);
			}
			if (path->closed)
				CGContextClosePath(context);
			CGContextStrokePath(context);
		}
	}
}

CGImageRef TGPatternCreateMask(NSData *tgvData, CGSize size) {
	NSData *unpacked = TGPatternGunzip(tgvData);
	if (!unpacked.length)
		return NULL;
	NSString *svg = [[NSString alloc] initWithData:unpacked
										 encoding:NSUTF8StringEncoding];
	if (!svg.length)
		return NULL;
	svg = TGPatternInlineStyles(svg);

	NSMutableData *input = [[svg dataUsingEncoding:NSUTF8StringEncoding]
			mutableCopy];
	uint8_t terminator = 0;
	[input appendBytes:&terminator length:1];
	NSVGimage *image = nsvgParse((char *)input.bytes, "px", 96);
	if (!image || image->width < 1.0f || image->height < 1.0f){
		if (image)
			nsvgDelete(image);
		return NULL;
	}

	if (size.width <= 0 || size.height <= 0)
		size = CGSizeMake(image->width, image->height);
	CGContextRef context = TGPatternCreateContext(size, NO);
	if (!context){
		nsvgDelete(image);
		return NULL;
	}

	// Svg.m renders into a UIKit context (origin top-left). A bitmap context
	// is bottom-left, so flip once before applying nanosvg's own aspect fill.
	CGFloat scale = MAX(size.width / image->width, size.height / image->height);
	CGSize drawn = CGSizeMake(image->width * scale, image->height * scale);
	CGContextTranslateCTM(context, 0.0f, size.height);
	CGContextScaleCTM(context, 1.0f, -1.0f);
	CGContextScaleCTM(context, scale, scale);
	CGContextTranslateCTM(context,
			(size.width - drawn.width) / (2.0f * scale),
			(size.height - drawn.height) / (2.0f * scale));

	for (NSVGshape *shape = image->shapes; shape; shape = shape->next){
		if (!(shape->flags & NSVG_FLAGS_VISIBLE) || shape->opacity <= 0)
			continue;
		TGPatternRenderShape(context, shape);
	}

	CGImageRef mask = CGBitmapContextCreateImage(context);
	CGContextRelease(context);
	nsvgDelete(image);
	return mask;
}

static CGFloat TGPatternColourBrightness(id colour) {
	if (![colour isKindOfClass:[UIColor class]])
		return 0.5f;
	CGColorRef cg = [(UIColor *)colour CGColor];
	const CGFloat *parts = CGColorGetComponents(cg);
	size_t count = CGColorGetNumberOfComponents(cg);
	if (!parts)
		return 0.5f;
	if (count >= 3)
		return 0.299f * parts[0] + 0.587f * parts[1] + 0.114f * parts[2];
	if (count == 2)
		return parts[0];
	return 0.5f;
}

static void TGPatternBlend(const CGFloat *a, const CGFloat *b, CGFloat t,
						   CGFloat *out) {
	for (int i = 0; i < 4; i++)
		out[i] = a[i] + (b[i] - a[i]) * t;
}

static void TGPatternDrawFreeform(CGContextRef context, CGSize size,
								  NSArray *colours) {
	if (colours.count < 3)
		return;
	CGFloat corners[4][4];
	for (int i = 0; i < 4; i++){
		UIColor *colour = colours[(NSUInteger)MIN(i, (int)colours.count - 1)];
		CGColorRef cg = [colour CGColor];
		const CGFloat *parts = CGColorGetComponents(cg);
		size_t count = CGColorGetNumberOfComponents(cg);
		corners[i][0] = count >= 3 ? parts[0] : (count == 2 ? parts[0] : 0.0f);
		corners[i][1] = count >= 3 ? parts[1] : (count == 2 ? parts[0] : 0.0f);
		corners[i][2] = count >= 3 ? parts[2] : (count == 2 ? parts[0] : 0.0f);
		corners[i][3] = count >= 4 ? parts[3] : 1.0f;
	}

	// Bitmap rows are bottom-up; row 0 of the image is the visual bottom.
	uint8_t *bytes = CGBitmapContextGetData(context);
	size_t stride = CGBitmapContextGetBytesPerRow(context);
	size_t width = (size_t)size.width;
	size_t height = (size_t)size.height;
	if (!bytes)
		return;
	for (size_t y = 0; y < height; y++){
		CGFloat v = height > 1 ? (CGFloat)(height - 1 - y) / (CGFloat)(height - 1)
				: 0.0f;
		uint8_t *row = bytes + y * stride;
		for (size_t x = 0; x < width; x++){
			CGFloat u = width > 1 ? (CGFloat)x / (CGFloat)(width - 1) : 0.0f;
			CGFloat top[4], bottom[4], pixel[4];
			TGPatternBlend(corners[0], corners[1], u, top);
			TGPatternBlend(corners[2], corners[3], u, bottom);
			TGPatternBlend(top, bottom, v, pixel);
			row[x * 4 + 0] = (uint8_t)lroundf(MAX(0.0f, MIN(1.0f, pixel[0])) * 255.0f);
			row[x * 4 + 1] = (uint8_t)lroundf(MAX(0.0f, MIN(1.0f, pixel[1])) * 255.0f);
			row[x * 4 + 2] = (uint8_t)lroundf(MAX(0.0f, MIN(1.0f, pixel[2])) * 255.0f);
			row[x * 4 + 3] = 255;
		}
	}
}

static void TGPatternDrawFill(CGContextRef context, CGSize size,
							  NSArray *colours, NSString *kind,
							  CGFloat rotation) {
	(void)kind;
	CGRect rect = CGRectMake(0, 0, size.width, size.height);
	if (!colours.count){
		CGContextSetRGBFillColor(context, 0.0f, 0.0f, 0.0f, 1.0f);
		CGContextFillRect(context, rect);
		return;
	}
	if (colours.count == 1){
		CGColorRef cg = [colours[0] CGColor];
		CGContextSetFillColorWithColor(context, cg);
		CGContextFillRect(context, rect);
		return;
	}
	if (colours.count >= 3){
		TGPatternDrawFreeform(context, size, colours);
		return;
	}

	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	NSMutableArray *cgColours = [NSMutableArray arrayWithCapacity:colours.count];
	for (UIColor *colour in colours)
		[cgColours addObject:(__bridge id)[colour CGColor]];
	CGFloat locations[2] = {0.0f, 1.0f};
	CGGradientRef gradient = CGGradientCreateWithColors(space,
			(__bridge CFArrayRef)cgColours, locations);
	if (!gradient){
		CGColorSpaceRelease(space);
		return;
	}
	CGContextSaveGState(context);
	CGContextTranslateCTM(context, size.width / 2.0f, size.height / 2.0f);
	CGContextRotateCTM(context, rotation * (CGFloat)M_PI / 180.0f);
	CGContextTranslateCTM(context, -size.width / 2.0f, -size.height / 2.0f);
	CGContextDrawLinearGradient(context, gradient,
			CGPointMake(0.0f, 0.0f), CGPointMake(0.0f, size.height),
			kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
	CGContextRestoreGState(context);
	CGGradientRelease(gradient);
	CGColorSpaceRelease(space);
}

CGImageRef TGPatternCreateFill(CGSize size, NSArray *colours, NSString *kind,
							   CGFloat rotation) {
	CGContextRef context = TGPatternCreateContext(size, NO);
	if (!context)
		return NULL;
	TGPatternDrawFill(context, size, colours, kind, rotation);
	CGImageRef image = CGBitmapContextCreateImage(context);
	CGContextRelease(context);
	return image;
}

CGImageRef TGPatternCreateWallpaper(CGSize size, NSArray *colours, NSString *kind,
									CGFloat rotation, CGImageRef mask,
									CGFloat intensity, BOOL inverted) {
	CGContextRef context = TGPatternCreateContext(size, NO);
	if (!context)
		return NULL;
	CGRect rect = CGRectMake(0, 0, size.width, size.height);
	TGPatternDrawFill(context, size, colours, kind, rotation);

	if (mask){
		CGFloat alpha = MAX(0.0f, MIN(1.0f, fabs(intensity)));
		if (inverted){
			// The dark variant is an opaque black sheet with the pattern cut
			// down to `alpha`: outside a shape the fill is gone, inside it the
			// fill shows through by (1 - alpha).
			CGContextRef overlay = TGPatternCreateContext(size, NO);
			if (overlay){
				CGContextSetRGBFillColor(overlay, 0.0f, 0.0f, 0.0f, 1.0f);
				CGContextFillRect(overlay, rect);
				CGContextSaveGState(overlay);
				CGContextClipToMask(overlay, rect, mask);
				CGContextSetBlendMode(overlay, kCGBlendModeCopy);
				CGContextSetRGBFillColor(overlay, 0.0f, 0.0f, 0.0f,
						1.0f - alpha);
				CGContextFillRect(overlay, rect);
				CGContextRestoreGState(overlay);
				CGImageRef overlayImage = CGBitmapContextCreateImage(overlay);
				if (overlayImage){
					CGContextDrawImage(context, rect, overlayImage);
					CGImageRelease(overlayImage);
				}
				CGContextRelease(overlay);
			}
		} else {
			CGFloat brightness = 0.5f;
			if (colours.count){
				CGFloat total = 0.0f;
				for (UIColor *colour in colours)
					total += TGPatternColourBrightness(colour);
				brightness = total / (CGFloat)colours.count;
			}
			BOOL lightFill = brightness > 0.3f;
			CGContextSaveGState(context);
			CGContextClipToMask(context, rect, mask);
			CGContextSetBlendMode(context, kCGBlendModeSoftLight);
			CGContextSetAlpha(context, alpha);
			CGContextSetRGBFillColor(context, lightFill ? 0.0f : 1.0f,
					lightFill ? 0.0f : 1.0f, lightFill ? 0.0f : 1.0f, 1.0f);
			CGContextFillRect(context, rect);
			CGContextRestoreGState(context);
		}
	}

	CGImageRef image = CGBitmapContextCreateImage(context);
	CGContextRelease(context);
	return image;
}

dispatch_queue_t TGPatternWorkQueue(void) {
	static dispatch_queue_t queue;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		queue = dispatch_queue_create("org.legacy.itg.pattern", DISPATCH_QUEUE_SERIAL);
		dispatch_set_target_queue(queue,
				dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
	});
	return queue;
}
