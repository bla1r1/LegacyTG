#import "TGLottieSupport.h"

/// Shape items TGDrawShapes handles; "tr" is a group's transform.
static BOOL TGLottieShapeDrawn(NSString *ty) {
	static NSSet *drawn;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		drawn = [NSSet setWithObjects:@"gr", @"sh", @"el", @"rc", @"fl", @"gf", @"st", @"tr", nil];
	});
	return [drawn containsObject:ty];
}

static NSString *TGLottieShapeName(NSString *ty) {
	NSDictionary *names = @{ @"tm": @"trim path", @"rp": @"repeater", @"rd": @"round corners",
			@"sr": @"star", @"mm": @"merge paths", @"gs": @"gradient stroke",
			@"op": @"offset path", @"pb": @"pucker", @"tw": @"twist", @"zz": @"zig zag" };
	return names[ty] ?: [@"shape " stringByAppendingString:ty];
}

static NSString *TGLottieUnsupportedShape(NSArray *shapes) {
	if (![shapes isKindOfClass:NSArray.class])
		return nil;
	for (NSDictionary *shape in shapes) {
		if (![shape isKindOfClass:NSDictionary.class])
			continue;
		NSString *ty = shape[@"ty"];
		if (![ty isKindOfClass:NSString.class])
			continue;
		if (!TGLottieShapeDrawn(ty))
			return TGLottieShapeName(ty);
		if ([ty isEqualToString:@"gr"]) {
			NSString *inner = TGLottieUnsupportedShape(shape[@"it"]);
			if (inner)
				return inner;
		}
	}
	return nil;
}

static NSString *TGLottieUnsupportedLayer(NSArray *layers) {
	if (![layers isKindOfClass:NSArray.class])
		return nil;
	for (NSDictionary *layer in layers) {
		if (![layer isKindOfClass:NSDictionary.class])
			continue;
		// 4 is a shape layer, 3 a null that only parents others.
		switch ([layer[@"ty"] intValue]) {
			case 3: continue;
			case 4: break;
			case 0: return @"precomp layer";
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
	NSArray *k = TGLottieArrayAtFrame(g[@"k"], frame);
	if (count < 2 || k.count < (NSUInteger)count * 4)
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
