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
