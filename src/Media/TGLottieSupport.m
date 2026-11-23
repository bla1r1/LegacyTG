#import "TGLottieSupport.h"
#import <zlib.h>

static const size_t kTGLottieMaxDecompressed = 4 * 1024 * 1024;
static const int kTGLottieMaxGroupDepth = 16;

NSData *TGLottieGunzip(NSData *data) {
	if (!data.length)
		return nil;

	const uint8_t *bytes = (const uint8_t *)data.bytes;
	BOOL isGzip = (data.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b);
	BOOL isZlib = (data.length >= 2 && bytes[0] == 0x78);
	if (!isGzip && !isZlib) {
		if (bytes[0] == '{')
			return data.length <= kTGLottieMaxDecompressed ? data : nil;
		return nil;
	}

	z_stream stream;
	memset(&stream, 0, sizeof(stream));
	if (inflateInit2(&stream, 15 + 32) != Z_OK)
		return nil;

	stream.next_in = (Bytef *)data.bytes;
	stream.avail_in = (uInt)MIN(data.length, (NSUInteger)UINT_MAX);

	NSMutableData *output = [NSMutableData data];
	uint8_t chunk[16384];
	int status = Z_OK;
	while (status == Z_OK) {
		stream.next_out = chunk;
		stream.avail_out = (uInt)sizeof(chunk);
		status = inflate(&stream, Z_NO_FLUSH);
		NSUInteger produced = sizeof(chunk) - stream.avail_out;
		if (produced)
			[output appendBytes:chunk length:produced];
		if (output.length > kTGLottieMaxDecompressed) {
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

/// Shape items TGDrawShapes handles; "tr" is a group's transform. "mm"
/// (merge paths) is skipped: both of the official client's renderers skip it
/// (tlottie, the default, parses it as ignored; rlottie warns "Merge Path is
/// not supported yet"), so the files are drawn without it there too.
static BOOL TGLottieShapeDrawn(NSString *ty) {
	static NSSet *drawn;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		drawn = [NSSet setWithObjects:@"gr", @"sh", @"el", @"rc", @"fl", @"gf", @"st", @"tr", @"mm", nil];
	});
	return [drawn containsObject:ty];
}

static NSString *TGLottieShapeName(NSString *ty) {
	NSDictionary *names = @{ @"tm": @"trim path", @"rp": @"repeater", @"rd": @"round corners",
			@"sr": @"star", @"gs": @"gradient stroke",
			@"op": @"offset path", @"pb": @"pucker", @"tw": @"twist", @"zz": @"zig zag" };
	return names[ty] ?: [@"shape " stringByAppendingString:ty];
}

static NSString *TGLottieUnsupportedShapeDepth(NSArray *shapes, int depth) {
	if (![shapes isKindOfClass:NSArray.class] || depth > kTGLottieMaxGroupDepth)
		return depth > kTGLottieMaxGroupDepth ? @"group recursion limit" : nil;
	for (NSDictionary *shape in shapes) {
		if (![shape isKindOfClass:NSDictionary.class])
			continue;
		NSString *ty = shape[@"ty"];
		if (![ty isKindOfClass:NSString.class])
			continue;
		if (!TGLottieShapeDrawn(ty))
			return TGLottieShapeName(ty);
		if ([ty isEqualToString:@"gr"]) {
			NSString *inner = TGLottieUnsupportedShapeDepth(shape[@"it"], depth + 1);
			if (inner)
				return inner;
		}
	}
	return nil;
}

static NSString *TGLottieUnsupportedShape(NSArray *shapes) {
	return TGLottieUnsupportedShapeDepth(shapes, 0);
}

static NSString *TGLottieUnsupportedLayer(NSArray *layers) {
	if (![layers isKindOfClass:NSArray.class])
		return nil;
	for (NSDictionary *layer in layers) {
		if (![layer isKindOfClass:NSDictionary.class])
			continue;
		// 4 is a shape layer, 3 a null that only parents others, 0 a precomp
		// whose asset's layers are checked with the assets.
		switch ([layer[@"ty"] intValue]) {
			case 3: continue;
			case 0:
			case 4: break;
			case 1: return @"solid layer";
			case 2: return @"image layer";
			case 5: return @"text layer";
			default: return @"layer type";
		}
		if ([layer[@"tt"] intValue] != 0 || [layer[@"td"] intValue] != 0)
			return @"track matte";
		NSString *shape = TGLottieUnsupportedShape(layer[@"shapes"]);
		if (shape)
			return shape;
	}
	return nil;
}

NSString *TGLottieUnsupportedFeature(NSDictionary *animation) {
	if (![animation isKindOfClass:NSDictionary.class])
		return nil;
	NSString *missing = TGLottieUnsupportedLayer(animation[@"layers"]);
	if (missing)
		return missing;
	NSArray *assets = animation[@"assets"];
	if (![assets isKindOfClass:NSArray.class])
		return nil;
	for (NSDictionary *asset in assets)
		if ([asset isKindOfClass:NSDictionary.class] &&
				(missing = TGLottieUnsupportedLayer(asset[@"layers"])))
			return missing;
	return nil;
}

/// The array a Lottie property holds at `frame`: itself when static, the
/// "s" value of the last keyframe at or before `frame` when animated.
static NSArray *TGLottieArrayAtFrame(id property, double frame) {
	if ([property isKindOfClass:NSArray.class])
		return property;
	if (![property isKindOfClass:NSDictionary.class])
		return nil;
	id k = property[@"k"];
	if (![property[@"a"] boolValue])
		return [k isKindOfClass:NSArray.class] ? k : nil;
	if (![k isKindOfClass:NSArray.class])
		return nil;
	NSArray *chosen = nil;
	for (NSDictionary *key in (NSArray *)k){
		if (![key isKindOfClass:NSDictionary.class])
			continue;
		NSArray *s = key[@"s"];
		if (![s isKindOfClass:NSArray.class])
			continue;
		if (!chosen || [key[@"t"] doubleValue] <= frame)
			chosen = s;
		if ([key[@"t"] doubleValue] > frame)
			break;
	}
	return chosen;
}

NSArray *TGLottieGradientStops(NSDictionary *g, double frame) {
	if (![g isKindOfClass:NSDictionary.class])
		return nil;
	NSInteger count = [g[@"p"] integerValue];
	if (count < 2 || count > 256)
		return nil;
	NSArray *k = TGLottieArrayAtFrame(g[@"k"], frame);
	if (k.count < (NSUInteger)count * 4 || k.count > 4096)
		return nil;
	NSUInteger colourEnd = (NSUInteger)count * 4;
	NSUInteger opacityCount = (k.count - colourEnd) / 2;
	NSMutableArray *out = [NSMutableArray arrayWithCapacity:(NSUInteger)count * 5];
	for (NSUInteger i = 0; i < (NSUInteger)count; i++){
		double offset = [k[i * 4] doubleValue];
		double alpha = 1.0;
		if (opacityCount){
			// Interpolate the opacity stops at this colour stop's offset.
			double prevX = [k[colourEnd] doubleValue], prevA = [k[colourEnd + 1] doubleValue];
			alpha = prevA;
			for (NSUInteger j = 0; j < opacityCount; j++){
				double x = [k[colourEnd + j * 2] doubleValue];
				double a = [k[colourEnd + j * 2 + 1] doubleValue];
				if (offset <= x){
					alpha = (x > prevX && j > 0)
							? prevA + (a - prevA) * (offset - prevX) / (x - prevX) : a;
					break;
				}
				prevX = x;
				prevA = a;
				alpha = a;
			}
		}
		[out addObjectsFromArray:@[@(offset), k[i * 4 + 1], k[i * 4 + 2], k[i * 4 + 3], @(alpha)]];
	}
	return out;
}
