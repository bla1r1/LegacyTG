//
// TGLottieRender.mm - Lottie layers to CoreGraphics; see TGLottieRender.h.
//
#import "TGLottieRender.h"
#import "TGLottieSupport.h"
#import "TGStyle.h"
#include <vector>
#include <cmath>
#include <algorithm>
#include <memory>
#include <unordered_map>
#include <string>
#import <objc/runtime.h>

#pragma mark - fast keyframed evaluation (zero-allocation C++ LottieProperty binary search)

struct LottieKeyframe {
	double t;
	float s[8];
	int s_count;
	float e[8];
	int e_count;
};

struct LottieProperty {
	enum Type { Empty, StaticNumber, StaticArray, Keyframed };
	Type type = Empty;
	float static_vals[8] = {0};
	int static_count = 0;
	std::vector<LottieKeyframe> keyframes;

	int evaluate(double frame, float *outVals, int maxVals) const {
		if (maxVals <= 0) return 0;
		switch (type) {
			case Empty:
				return 0;
			case StaticNumber:
			case StaticArray: {
				int n = std::min(static_count, maxVals);
				for (int i = 0; i < n; i++) {
					outVals[i] = static_vals[i];
				}
				return n;
			}
			case Keyframed: {
				if (keyframes.empty()) return 0;
				if (frame <= keyframes.front().t || keyframes.size() == 1) {
					const auto &first = keyframes.front();
					int n = std::min(first.s_count, maxVals);
					for (int i = 0; i < n; i++) {
						outVals[i] = first.s[i];
					}
					return n;
				}

				if (frame >= keyframes.back().t) {
					const auto &last = keyframes.back();
					int n = std::min(last.e_count > 0 ? last.e_count : last.s_count, maxVals);
					const float *vals = (last.e_count > 0) ? last.e : last.s;
					for (int i = 0; i < n; i++) {
						outVals[i] = vals[i];
					}
					return n;
				}

				if (!std::isfinite(frame))
					return 0;

				auto it = std::lower_bound(keyframes.begin(), keyframes.end(), frame,
					[](const LottieKeyframe &kf, double val) {
						return kf.t <= val;
					});

				if (it == keyframes.begin() || it == keyframes.end()) {
					const auto &kf = (it == keyframes.begin()) ? keyframes.front() : keyframes.back();
					int n = std::min(kf.s_count, maxVals);
					for (int i = 0; i < n; i++)
						outVals[i] = kf.s[i];
					return n;
				}

				const auto &after = *it;
				const auto &before = *(it - 1);

				double t0 = before.t;
				double t1 = after.t;
				double p = (t1 > t0) ? (frame - t0) / (t1 - t0) : 0.0;
				if (p < 0.0) p = 0.0;
				if (p > 1.0) p = 1.0;
				float pf = (float)p;

				int count = std::max(before.s_count, before.e_count);
				if (!count) return 0;
				count = std::min(count, maxVals);

				for (int i = 0; i < count; i++) {
					float a = (i < before.s_count) ? before.s[i] : (i < before.e_count ? before.e[i] : 0.0f);
					float b = (i < before.e_count) ? before.e[i] : a;
					outVals[i] = a + (b - a) * pf;
				}
				return count;
			}
		}
		return 0;
	}
};

static LottieProperty ParseLottieProperty(NSDictionary *prop) {
	LottieProperty lp;
	if (!prop) return lp;
	id k = prop[@"k"];
	if (!k) return lp;

	if ([k isKindOfClass:[NSNumber class]]) {
		lp.type = LottieProperty::StaticNumber;
		lp.static_vals[0] = (float)[(NSNumber *)k doubleValue];
		lp.static_count = 1;
		return lp;
	}

	if ([k isKindOfClass:[NSArray class]]) {
		NSArray *arr = (NSArray *)k;
		if (!arr.count || arr.count > 10000) return lp;
		id first = arr[0];
		if (![first isKindOfClass:[NSDictionary class]]) {
			lp.type = LottieProperty::StaticArray;
			lp.static_count = (int)MIN((NSUInteger)8, arr.count);
			for (int i = 0; i < lp.static_count; i++) {
				lp.static_vals[i] = (float)[arr[i] doubleValue];
			}
			return lp;
		}

		lp.type = LottieProperty::Keyframed;
		lp.keyframes.reserve(arr.count);
		for (NSUInteger idx = 0; idx < arr.count; idx++) {
			NSDictionary *kf = arr[idx];
			if (![kf isKindOfClass:[NSDictionary class]]) continue;
			LottieKeyframe lkf;
			lkf.t = [kf[@"t"] doubleValue];
			lkf.s_count = 0;
			lkf.e_count = 0;

			id s = kf[@"s"];
			if ([s isKindOfClass:[NSArray class]]) {
				NSArray *sArr = (NSArray *)s;
				lkf.s_count = (int)MIN((NSUInteger)8, sArr.count);
				for (int i = 0; i < lkf.s_count; i++) {
					lkf.s[i] = (float)[sArr[i] doubleValue];
				}
			} else if ([s isKindOfClass:[NSNumber class]]) {
				lkf.s[0] = (float)[(NSNumber *)s doubleValue];
				lkf.s_count = 1;
			}

			id e = kf[@"e"];
			if (!e && idx + 1 < arr.count && [arr[idx + 1] isKindOfClass:[NSDictionary class]]) {
				e = arr[idx + 1][@"s"];
			}
			if ([e isKindOfClass:[NSArray class]]) {
				NSArray *eArr = (NSArray *)e;
				lkf.e_count = (int)MIN((NSUInteger)8, eArr.count);
				for (int i = 0; i < lkf.e_count; i++) {
					lkf.e[i] = (float)[eArr[i] doubleValue];
				}
			} else if ([e isKindOfClass:[NSNumber class]]) {
				lkf.e[0] = (float)[(NSNumber *)e doubleValue];
				lkf.e_count = 1;
			} else if (lkf.s_count > 0) {
				lkf.e_count = lkf.s_count;
				for (int i = 0; i < lkf.s_count; i++) {
					lkf.e[i] = lkf.s[i];
				}
			}

			lp.keyframes.push_back(lkf);
		}
		return lp;
	}
	return lp;
}

@interface TGLottiePropertyBox : NSObject
@property (nonatomic, assign) std::shared_ptr<LottieProperty> prop;
@end
@implementation TGLottiePropertyBox
@end

static const char kLottiePropertyKey = 0;

static inline const LottieProperty *GetOrParseLottieProperty(NSDictionary *prop) {
	if (!prop) return nullptr;
	TGLottiePropertyBox *box = objc_getAssociatedObject(prop, &kLottiePropertyKey);
	if (!box) {
		box = [[TGLottiePropertyBox alloc] init];
		box.prop = std::make_shared<LottieProperty>(ParseLottieProperty(prop));
		objc_setAssociatedObject(prop, &kLottiePropertyKey, box, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	return box.prop.get();
}

static inline int TGValueAtFast(NSDictionary *prop, double frame, float *outVals, int maxVals) {
	if (!prop || !maxVals)
		return 0;
	const LottieProperty *lp = GetOrParseLottieProperty(prop);
	if (!lp)
		return 0;
	return lp->evaluate(frame, outVals, maxVals);
}

static inline float TGScalarAtFast(NSDictionary *prop, double frame, float fallback) {
	float val = 0;
	if (TGValueAtFast(prop, frame, &val, 1) > 0)
		return val;
	return fallback;
}


#pragma mark - C++ Vector Render Helpers (usable in background threads)

/// The matrix part of a transform. Opacity is read apart (TGOpacity): it
/// multiplies down a group or precomp, and does not pass through parenting,
/// so the caller decides whose alpha it joins.
static void TGApplyTransform(NSDictionary *ks, double frame, CGContextRef ctx) {
	if (![ks isKindOfClass:NSDictionary.class])
		return;

	float pos[2]    = {0};
	float anchor[2] = {0};
	float scale[2]  = {100.0f, 100.0f};

	int posCount = 0;
	id pObj = ks[@"p"];
	if ([pObj isKindOfClass:NSDictionary.class] && pObj[@"x"] && pObj[@"y"]) {
		pos[0] = TGScalarAtFast(pObj[@"x"], frame, 0.0f);
		pos[1] = TGScalarAtFast(pObj[@"y"], frame, 0.0f);
		posCount = 2;
	} else {
		posCount = TGValueAtFast(pObj, frame, pos, 2);
	}
	int anchorCount = TGValueAtFast(ks[@"a"], frame, anchor, 2);
	int scaleCount  = TGValueAtFast(ks[@"s"], frame, scale, 2);
	float rotation  = TGScalarAtFast(ks[@"r"], frame, 0.0f);

	if (posCount >= 2)
		CGContextTranslateCTM(ctx, pos[0], pos[1]);
	if (rotation != 0.0f)
		CGContextRotateCTM(ctx, rotation * (float)M_PI / 180.0f);
	if (scaleCount >= 2)
		CGContextScaleCTM(ctx, scale[0] / 100.0f, scale[1] / 100.0f);
	if (anchorCount >= 2)
		CGContextTranslateCTM(ctx, -anchor[0], -anchor[1]);
}

/// A transform's opacity, 0...1.
static float TGOpacity(NSDictionary *ks, double frame) {
	if (!ks)
		return 1.0f;
	float opacity = TGScalarAtFast(ks[@"o"], frame, 100.0f) / 100.0f;
	return std::max(0.0f, std::min(1.0f, opacity));
}

// ── bezier shapes, flattened once at load ───────────────────────────────────
// A shape's outline is three parallel NSArrays of two-element NSArrays of
// NSNumbers - vertices, in-tangents, out-tangents. Reading one point meant
// four objc_msgSends and two NSNumber unboxings, and the render loop did that
// for every point of every shape of every layer, sixty times a second, off a
// CADisplayLink. The geometry does not change between frames; only which
// keyframe is current does. So it is parsed once into flat vectors and cached
// on the property dictionary, exactly as the scalar properties already are.

struct LottieBezierPath {
	std::vector<CGPoint> v;
	std::vector<CGPoint> in;
	std::vector<CGPoint> out;
	bool closed = false;
};

struct LottieBezierFrame {
	double t = 0.0;
	std::vector<LottieBezierPath> shapes;
};

struct LottieBezierSet {
	/// One entry for a static shape, otherwise one per keyframe in order.
	std::vector<LottieBezierFrame> frames;
	bool keyframed = false;
};

static CGPoint ParseLottiePoint(id raw) {
	if (![raw isKindOfClass:NSArray.class])
		return CGPointZero;
	NSArray *pair = (NSArray *)raw;
	if (pair.count < 2)
		return CGPointZero;
	return CGPointMake([pair[0] doubleValue], [pair[1] doubleValue]);
}

/// One `{v, i, o, c}` outline into flat vectors. Shapes with fewer than two
/// vertices draw nothing and are dropped here rather than per frame.
static bool ParseLottieBezierPath(NSDictionary *shape, LottieBezierPath &out) {
	if (![shape isKindOfClass:NSDictionary.class])
		return false;
	NSArray *v   = shape[@"v"];
	NSArray *in  = shape[@"i"];
	NSArray *tan = shape[@"o"];
	NSUInteger count = [v isKindOfClass:NSArray.class] ? v.count : 0;
	if (count < 2 || count > 10000)
		return false;

	out.v.resize(count, CGPointZero);
	out.in.resize(count, CGPointZero);
	out.out.resize(count, CGPointZero);
	for (NSUInteger i = 0; i < count; i++){
		out.v[i] = ParseLottiePoint(v[i]);
		if ([in isKindOfClass:NSArray.class] && i < in.count)
			out.in[i] = ParseLottiePoint(in[i]);
		if ([tan isKindOfClass:NSArray.class] && i < tan.count)
			out.out[i] = ParseLottiePoint(tan[i]);
	}
	out.closed = [shape[@"c"] boolValue];
	return true;
}

static void ParseLottieShapeList(id value, std::vector<LottieBezierPath> &out) {
	if ([value isKindOfClass:NSDictionary.class]){
		LottieBezierPath path;
		if (ParseLottieBezierPath((NSDictionary *)value, path))
			out.push_back(std::move(path));
		return;
	}
	if (![value isKindOfClass:NSArray.class])
		return;
	for (id shape in (NSArray *)value){
		LottieBezierPath path;
		if (ParseLottieBezierPath(shape, path))
			out.push_back(std::move(path));
	}
}

static LottieBezierSet ParseLottieBezierSet(NSDictionary *ks) {
	LottieBezierSet set;
	id k = ks[@"k"];

	BOOL isKeyframeList = [k isKindOfClass:NSArray.class] &&
			[[k firstObject] isKindOfClass:NSDictionary.class] &&
			[[k firstObject] objectForKey:@"t"];

	if (isKeyframeList){
		set.keyframed = true;
		for (NSDictionary *kf in (NSArray *)k){
			if (![kf isKindOfClass:NSDictionary.class])
				continue;
			LottieBezierFrame entry;
			entry.t = [kf[@"t"] doubleValue];
			ParseLottieShapeList(kf[@"s"], entry.shapes);
			set.frames.push_back(std::move(entry));
		}
		if (set.frames.empty())
			set.frames.push_back(LottieBezierFrame());
		return set;
	}

	// A dictionary is one static shape; a plain array is a static list.
	LottieBezierFrame entry;
	ParseLottieShapeList(k, entry.shapes);
	set.frames.push_back(std::move(entry));
	return set;
}

@interface TGLottieBezierBox : NSObject
@property (nonatomic, assign) std::shared_ptr<LottieBezierSet> set;
@end
@implementation TGLottieBezierBox
@end

static const char kLottieBezierKey = 0;

static const LottieBezierSet *GetOrParseLottieBezier(NSDictionary *ks) {
	if (!ks) return nullptr;
	TGLottieBezierBox *box = objc_getAssociatedObject(ks, &kLottieBezierKey);
	if (!box){
		box = [[TGLottieBezierBox alloc] init];
		box.set = std::make_shared<LottieBezierSet>(ParseLottieBezierSet(ks));
		objc_setAssociatedObject(ks, &kLottieBezierKey, box,
				OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	return box.set.get();
}

static void TGAppendBezier(NSDictionary *ks, double frame, CGMutablePathRef path) {
	const LottieBezierSet *set = GetOrParseLottieBezier(ks);
	if (!set || set->frames.empty())
		return;

	// The keyframe in force is the last one that has started. Outlines are
	// not interpolated here, which is what the dictionary walk did too.
	const LottieBezierFrame *chosen = &set->frames.front();
	if (set->keyframed){
		for (const LottieBezierFrame &candidate : set->frames){
			if (candidate.t <= frame)
				chosen = &candidate;
		}
	}

	for (const LottieBezierPath &shape : chosen->shapes){
		size_t count = shape.v.size();
		if (count < 2)
			continue;

		CGPathMoveToPoint(path, NULL, shape.v[0].x, shape.v[0].y);
		for (size_t i = 1; i < count; i++){
			size_t p = i - 1;
			CGPathAddCurveToPoint(path, NULL,
				shape.v[p].x + shape.out[p].x, shape.v[p].y + shape.out[p].y,
				shape.v[i].x + shape.in[i].x,  shape.v[i].y + shape.in[i].y,
				shape.v[i].x, shape.v[i].y);
		}

		if (shape.closed){
			size_t last = count - 1;
			CGPathAddCurveToPoint(path, NULL,
				shape.v[last].x + shape.out[last].x,
				shape.v[last].y + shape.out[last].y,
				shape.v[0].x + shape.in[0].x, shape.v[0].y + shape.in[0].y,
				shape.v[0].x, shape.v[0].y);
			CGPathCloseSubpath(path);
		}
	}
}

static void TGFillPath(CGPathRef path, NSDictionary *shape, double frame, CGContextRef ctx) {
	float c[4] = {0};
	int cC = TGValueAtFast(shape[@"c"], frame, c, 4);
	if (cC < 3 || CGPathIsEmpty(path))
		return;

	float alpha = TGScalarAtFast(shape[@"o"], frame, 100.0f) / 100.0f;
	CGContextSetRGBFillColor(ctx, c[0], c[1], c[2], alpha);
	CGContextAddPath(ctx, path);
	CGContextEOFillPath(ctx);
}

static void TGStrokePath(CGPathRef path, NSDictionary *shape, double frame, CGContextRef ctx) {
	float c[4] = {0};
	int cC = TGValueAtFast(shape[@"c"], frame, c, 4);
	if (cC < 3 || CGPathIsEmpty(path))
		return;

	float alpha = TGScalarAtFast(shape[@"o"], frame, 100.0f) / 100.0f;
	float width = TGScalarAtFast(shape[@"w"], frame, 1.0f);
	CGContextSetRGBStrokeColor(ctx, c[0], c[1], c[2], alpha);
	CGContextSetLineWidth(ctx, width);
	CGContextAddPath(ctx, path);
	CGContextStrokePath(ctx);
}

static CGGradientRef TGGradientFromStops(NSArray *k, NSUInteger perStop, double alpha) {
	NSUInteger stops = k.count / perStop;
	if (stops > 64)
		return nil;

	CGFloat cLocations[64];
	CGFloat cComponents[256];

	for (NSUInteger i = 0; i < stops; i++){
		NSUInteger base = i * perStop;
		double offset = [k[base] doubleValue];
		double colourAlpha = (perStop == 5) ? [k[base + 4] doubleValue] : 1.0;

		cLocations[i] = (CGFloat)MAX(MIN(offset, 1.0), 0.0);
		cComponents[i * 4 + 0] = (CGFloat)[k[base + 1] doubleValue];
		cComponents[i * 4 + 1] = (CGFloat)[k[base + 2] doubleValue];
		cComponents[i * 4 + 2] = (CGFloat)[k[base + 3] doubleValue];
		cComponents[i * 4 + 3] = (CGFloat)(colourAlpha * alpha);
	}

	static CGColorSpaceRef space = NULL;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		space = CGColorSpaceCreateDeviceRGB();
	});
	return CGGradientCreateWithColorComponents(space, cComponents, cLocations, (size_t)stops);
}

static void TGGradientFillPath(CGPathRef path, NSDictionary *shape, double frame, CGContextRef ctx) {
	if (CGPathIsEmpty(path))
		return;
	// Telegram's files wrap the stops in {a, k} and may add opacity stops:
	// read as a bare array, every gradient fill was skipped.
	NSArray *k = TGLottieGradientStops(shape[@"g"], frame);
	if (!k.count)
		return;
	NSUInteger perStop = 5;

	float alpha = TGScalarAtFast(shape[@"o"], frame, 100.0f) / 100.0f;
	CGGradientRef gradient = TGGradientFromStops(k, perStop, alpha);
	if (!gradient)
		return;

	float from[2] = {0}, to[2] = {0};
	int fromC = TGValueAtFast(shape[@"s"], frame, from, 2);
	int toC   = TGValueAtFast(shape[@"e"], frame, to, 2);
	if (fromC < 2 || toC < 2){
		CGGradientRelease(gradient);
		return;
	}
	CGPoint start  = CGPointMake(from[0], from[1]);
	CGPoint finish = CGPointMake(to[0],   to[1]);

	CGContextSaveGState(ctx);
	CGContextAddPath(ctx, path);
	CGContextClip(ctx);
	if ([shape[@"t"] integerValue] == 2){
		double radius = sqrt(pow(finish.x - start.x, 2) +
							 pow(finish.y - start.y, 2));
		CGContextDrawRadialGradient(ctx, gradient, start, 0,
				finish, MAX(radius, 0.01), kCGGradientDrawsBeforeStartLocation |
										   kCGGradientDrawsAfterEndLocation);
	} else {
		CGContextDrawLinearGradient(ctx, gradient, start, finish,
				kCGGradientDrawsBeforeStartLocation |
				kCGGradientDrawsAfterEndLocation);
	}
	CGContextRestoreGState(ctx);
	CGGradientRelease(gradient);
}

static void TGCollectMaskPaths(NSArray *masks, double frame,
							   CGMutablePathRef inside,
							   CGMutablePathRef outside,
							   NSUInteger *counted) {
	for (NSDictionary *mask in masks){
		if (![mask isKindOfClass:NSDictionary.class])
			continue;
		NSString *mode = mask[@"mode"] ?: @"";
		if ([mode isEqualToString:@"n"] || !mode.length)
			continue;
		BOOL erase = [mode isEqualToString:@"s"] || [mode isEqualToString:@"d"];
		if ([mask[@"inv"] boolValue] && !erase)
			erase = YES;

		CGMutablePathRef sink = erase ? outside : inside;
		CGMutablePathRef maskPath = CGPathCreateMutable();
		TGAppendBezier(mask[@"pt"], frame, maskPath);
		CGPathAddPath(sink, NULL, maskPath);
		CGPathRelease(maskPath);
		(*counted)++;
	}
}

static void TGClipByMasks(NSArray *masks, double frame, CGContextRef ctx) {
	if (![masks isKindOfClass:NSArray.class] || !masks.count)
		return;

	NSUInteger counted = 0;
	CGMutablePathRef inside  = CGPathCreateMutable();
	CGMutablePathRef outside = CGPathCreateMutable();
	TGCollectMaskPaths(masks, frame, inside, outside, &counted);

	if (counted && !CGPathIsEmpty(inside)){
		CGContextAddPath(ctx, inside);
		CGContextClip(ctx);
	}
	CGPathRelease(inside);
	CGPathRelease(outside);
}

static void TGEraseByMasks(NSArray *masks, double frame, CGContextRef ctx) {
	if (![masks isKindOfClass:NSArray.class] || !masks.count)
		return;

	NSUInteger counted = 0;
	CGMutablePathRef inside  = CGPathCreateMutable();
	CGMutablePathRef outside = CGPathCreateMutable();
	TGCollectMaskPaths(masks, frame, inside, outside, &counted);

	if (!CGPathIsEmpty(outside)) {
		CGContextSetBlendMode(ctx, kCGBlendModeClear);
		CGContextSetRGBFillColor(ctx, 0, 0, 0, TGAlphaOpaque);
		CGContextAddPath(ctx, outside);
		CGContextFillPath(ctx);
		CGContextSetBlendMode(ctx, kCGBlendModeNormal);
	}

	CGPathRelease(inside);
	CGPathRelease(outside);
}

/// A rounded rectangle from arcs: CGPathAddRoundedRect is iOS 7, and
/// UIBezierPath would tie this file to UIKit.
static void TGAddRoundedRect(CGMutablePathRef path, CGRect r, CGFloat radius) {
	radius = MIN(radius, MIN(r.size.width, r.size.height) / 2.0f);
	CGFloat minX = CGRectGetMinX(r), maxX = CGRectGetMaxX(r);
	CGFloat minY = CGRectGetMinY(r), maxY = CGRectGetMaxY(r);
	CGPathMoveToPoint(path, NULL, minX + radius, minY);
	CGPathAddArcToPoint(path, NULL, maxX, minY, maxX, maxY, radius);
	CGPathAddArcToPoint(path, NULL, maxX, maxY, minX, maxY, radius);
	CGPathAddArcToPoint(path, NULL, minX, maxY, minX, minY, radius);
	CGPathAddArcToPoint(path, NULL, minX, minY, maxX, minY, radius);
	CGPathCloseSubpath(path);
}

/// `alpha` is what the layer, its precomps and the enclosing groups leave;
/// a group multiplies its own opacity in for its items.
static const int kTGLottieMaxShapeDepth = 16;

static void TGDrawShapesDepth(NSArray *shapes, double frame, CGContextRef ctx, float alpha, int depth) {
	if (depth >= kTGLottieMaxShapeDepth || ![shapes isKindOfClass:NSArray.class])
		return;

	CGMutablePathRef path = CGPathCreateMutable();

	for (NSDictionary *shape in shapes){
		if (![shape isKindOfClass:NSDictionary.class])
			continue;
		NSString *ty = shape[@"ty"];
		if (![ty isKindOfClass:NSString.class])
			continue;

		if ([ty isEqualToString:@"gr"]){
			NSArray *items = shape[@"it"];
			if (![items isKindOfClass:NSArray.class])
				continue;
			float groupAlpha = alpha;
			for (NSDictionary *item in items)
				if ([item isKindOfClass:NSDictionary.class] && [item[@"ty"] isEqualToString:@"tr"])
					groupAlpha *= TGOpacity(item, frame);
			if (groupAlpha <= 0.0f)
				continue;
			CGContextSaveGState(ctx);
			for (NSDictionary *item in items)
				if ([item isKindOfClass:NSDictionary.class] && [item[@"ty"] isEqualToString:@"tr"])
					TGApplyTransform(item, frame, ctx);
			CGContextSetAlpha(ctx, groupAlpha);
			TGDrawShapesDepth(items, frame, ctx, groupAlpha, depth + 1);
			CGContextRestoreGState(ctx);

		} else if ([ty isEqualToString:@"sh"]){
			TGAppendBezier(shape[@"ks"], frame, path);

		} else if ([ty isEqualToString:@"el"]){
			float p[2] = {0}, s[2] = {0};
			int pC = TGValueAtFast(shape[@"p"], frame, p, 2);
			int sC = TGValueAtFast(shape[@"s"], frame, s, 2);
			if (pC >= 2 && sC >= 2){
				CGRect r = CGRectMake(p[0] - s[0] / 2.0f,
									  p[1] - s[1] / 2.0f,
									  s[0], s[1]);
				CGPathAddEllipseInRect(path, NULL, r);
			}

		} else if ([ty isEqualToString:@"rc"]){
			float p[2] = {0}, s[2] = {0};
			int pC = TGValueAtFast(shape[@"p"], frame, p, 2);
			int sC = TGValueAtFast(shape[@"s"], frame, s, 2);
			float radius = TGScalarAtFast(shape[@"r"], frame, 0.0f);
			if (pC >= 2 && sC >= 2){
				CGRect r = CGRectMake(p[0] - s[0] / 2.0f,
									  p[1] - s[1] / 2.0f,
									  s[0], s[1]);
				if (radius > 0.0f){
					TGAddRoundedRect(path, r, radius);
				} else {
					CGPathAddRect(path, NULL, r);
				}
			}

		} else if ([ty isEqualToString:@"fl"]){
			TGFillPath(path, shape, frame, ctx);

		} else if ([ty isEqualToString:@"gf"]){
			TGGradientFillPath(path, shape, frame, ctx);

		} else if ([ty isEqualToString:@"st"]){
			TGStrokePath(path, shape, frame, ctx);
		}
	}

	CGPathRelease(path);
}

#pragma mark - scene

// One layer of a composition, its references resolved at load. The
// dictionaries stay the source of the animated values: their parsed
// keyframes are cached on them (GetOrParseLottieProperty).
struct TGLottieLayer {
	int type = -1;          // 0 precomp, 3 null, 4 shape; anything else is not drawn
	double ip = 0, op = 0;  // in the enclosing composition's frames, op exclusive
	double st = 0, sr = 1;  // a precomp's start and stretch
	int parent = -1;        // index in the same composition
	int comp = -1;          // a precomp's composition
	CGSize size = CGSizeZero;  // a precomp's clip
	NSDictionary *ks = nil;
	NSArray *shapes = nil;
	NSArray *masks = nil;
	NSDictionary *timeRemap = nil;
};

struct TGLottieComp {
	/// File order: the first is in front, so drawing walks it backwards.
	std::vector<TGLottieLayer> layers;
};

struct TGLottieScene {
	std::vector<TGLottieComp> comps;  // comps[0] is the root
	CGSize canvas = CGSizeZero;
	double frameRate = 60.0;
	double inPoint = 0, outPoint = 0;
};

/// Precomps inside precomps, and parent chains, past this depth are a broken
/// or looping file, not art.
static const int kTGLottieMaxDepth = 16;

static double TGNumber(id value, double fallback) {
	return [value isKindOfClass:NSNumber.class] ? [value doubleValue] : fallback;
}

static void TGBuildComp(NSArray *layers, const std::unordered_map<std::string, int> &assets,
		TGLottieComp &comp) {
	if (![layers isKindOfClass:NSArray.class])
		return;
	std::unordered_map<long long, int> byInd;
	comp.layers.reserve(layers.count);
	for (NSDictionary *raw in layers) {
		TGLottieLayer layer;
		if ([raw isKindOfClass:NSDictionary.class]) {
			layer.type = (int)TGNumber(raw[@"ty"], -1);
			layer.ip = TGNumber(raw[@"ip"], 0);
			layer.op = TGNumber(raw[@"op"], 0);
			layer.st = TGNumber(raw[@"st"], 0);
			layer.sr = TGNumber(raw[@"sr"], 1) ?: 1;
			layer.ks = [raw[@"ks"] isKindOfClass:NSDictionary.class] ? raw[@"ks"] : nil;
			layer.shapes = [raw[@"shapes"] isKindOfClass:NSArray.class] ? raw[@"shapes"] : nil;
			layer.masks = [raw[@"masksProperties"] isKindOfClass:NSArray.class] ? raw[@"masksProperties"] : nil;
			layer.timeRemap = [raw[@"tm"] isKindOfClass:NSDictionary.class] ? raw[@"tm"] : nil;
			layer.size = CGSizeMake(TGNumber(raw[@"w"], 0), TGNumber(raw[@"h"], 0));
			NSString *ref = [raw[@"refId"] isKindOfClass:NSString.class] ? raw[@"refId"] : nil;
			if (layer.type == 0 && ref) {
				auto found = assets.find(std::string(ref.UTF8String ?: ""));
				if (found != assets.end())
					layer.comp = found->second;
			}
			if ([raw[@"ind"] isKindOfClass:NSNumber.class])
				byInd[[raw[@"ind"] longLongValue]] = (int)comp.layers.size();
		}
		comp.layers.push_back(layer);
	}
	// Parents resolve once every layer of the composition has its index.
	NSUInteger i = 0;
	for (NSDictionary *raw in layers) {
		id parent = [raw isKindOfClass:NSDictionary.class] ? raw[@"parent"] : nil;
		if ([parent isKindOfClass:NSNumber.class]) {
			auto found = byInd.find([parent longLongValue]);
			if (found != byInd.end() && found->second != (int)i)
				comp.layers[i].parent = found->second;
		}
		i++;
	}
}

TGLottieScene *TGLottieSceneCreate(NSDictionary *animation) {
	if (![animation isKindOfClass:NSDictionary.class])
		return NULL;
	NSArray *layers = animation[@"layers"];
	CGSize canvas = CGSizeMake(TGNumber(animation[@"w"], 0), TGNumber(animation[@"h"], 0));
	if (![layers isKindOfClass:NSArray.class] || !layers.count ||
		canvas.width <= 0 || canvas.height <= 0 ||
		canvas.width > 4096 || canvas.height > 4096 ||
		(uint64_t)canvas.width * (uint64_t)canvas.height * 4ull > 16ull * 1024 * 1024)
		return NULL;

	if (layers.count > 2000)
		return NULL;

	// Precomp assets get their indices first, so a layer can point at one
	// listed after it, or at one that holds it.
	std::unordered_map<std::string, int> assetIndex;
	std::vector<NSArray *> assetLayers;
	NSArray *assets = animation[@"assets"];
	if ([assets isKindOfClass:NSArray.class]) {
		for (NSDictionary *asset in assets) {
			if (![asset isKindOfClass:NSDictionary.class] || ![asset[@"layers"] isKindOfClass:NSArray.class])
				continue;
			NSString *assetId = [asset[@"id"] isKindOfClass:NSString.class] ? asset[@"id"] : nil;
			if (!assetId)
				continue;
			assetIndex[std::string(assetId.UTF8String ?: "")] = (int)assetLayers.size() + 1;
			assetLayers.push_back(asset[@"layers"]);
		}
	}

	TGLottieScene *scene = new TGLottieScene();
	scene->canvas = canvas;
	scene->frameRate = TGNumber(animation[@"fr"], 60) ?: 60;
	scene->inPoint = TGNumber(animation[@"ip"], 0);
	scene->outPoint = TGNumber(animation[@"op"], 0);
	scene->comps.resize(assetLayers.size() + 1);
	TGBuildComp(layers, assetIndex, scene->comps[0]);
	for (size_t i = 0; i < assetLayers.size(); i++)
		TGBuildComp(assetLayers[i], assetIndex, scene->comps[i + 1]);
	return scene;
}

void TGLottieSceneFree(TGLottieScene *scene) {
	delete scene;
}

/// The parent's matrix first, then the layer's own, all at the composition's
/// frame (rlottie's LOTLayerItem::matrix).
static void TGApplyLayerChain(const TGLottieComp &comp, int index, double frame,
		CGContextRef ctx, int depth) {
	const TGLottieLayer &layer = comp.layers[(size_t)index];
	if (layer.parent >= 0 && depth < kTGLottieMaxDepth)
		TGApplyLayerChain(comp, layer.parent, frame, ctx, depth + 1);
	TGApplyTransform(layer.ks, frame, ctx);
}

/// The frame a precomp's own composition is at (tlottie's executor, rlottie's
/// timeRemap): the time remap in seconds, kept inside the animation's
/// 0 ... op - ip - 1, else the frame since the layer started; then the stretch.
static double TGPrecompFrame(const TGLottieScene &scene, const TGLottieLayer &layer, double frame) {
	double local = frame - layer.st;
	if (layer.timeRemap) {
		double duration = std::max(0.0, scene.outPoint - scene.inPoint - 1.0);
		local = TGScalarAtFast(layer.timeRemap, frame, 0.0f) * scene.frameRate;
		local = std::max(0.0, std::min(duration, local));
	}
	return local / layer.sr;
}

static void TGDrawComp(const TGLottieScene &scene, int compIndex, double frame,
		CGContextRef ctx, float alpha, int depth) {
	if (compIndex < 0 || (size_t)compIndex >= scene.comps.size() || depth > kTGLottieMaxDepth)
		return;
	const TGLottieComp &comp = scene.comps[(size_t)compIndex];
	for (size_t i = comp.layers.size(); i-- > 0;) {
		const TGLottieLayer &layer = comp.layers[i];
		if (layer.type != 0 && layer.type != 4)
			continue;
		if (frame < layer.ip || frame >= layer.op)
			continue;
		// Opacity is the layer's own and its precomps', not its parent's.
		float layerAlpha = alpha * TGOpacity(layer.ks, frame);
		if (layerAlpha <= 0.0f)
			continue;

		CGContextSaveGState(ctx);
		TGApplyLayerChain(comp, (int)i, frame, ctx, 0);
		TGClipByMasks(layer.masks, frame, ctx);
		if (layer.type == 0) {
			if (layer.size.width > 0 && layer.size.height > 0)
				CGContextClipToRect(ctx, CGRectMake(0, 0, layer.size.width, layer.size.height));
			TGDrawComp(scene, layer.comp, TGPrecompFrame(scene, layer, frame), ctx, layerAlpha, depth + 1);
		} else {
			CGContextSetAlpha(ctx, layerAlpha);
			TGDrawShapesDepth(layer.shapes, frame, ctx, layerAlpha, 0);
		}
		TGEraseByMasks(layer.masks, frame, ctx);
		CGContextRestoreGState(ctx);
	}
}

CGImageRef TGLottieSceneRender(const TGLottieScene *scene, double frame, CGSize pixelSize) {
	int w = (int)pixelSize.width;
	int h = (int)pixelSize.height;
	if (!scene || w <= 0 || h <= 0 || w > 4096 || h > 4096 ||
		(uint64_t)w * (uint64_t)h * 4ull > 16ull * 1024 * 1024)
		return NULL;
	if (scene->canvas.width <= 0 || scene->canvas.height <= 0)
		return NULL;

	CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
	CGContextRef ctx = CGBitmapContextCreate(NULL, (size_t)w, (size_t)h, 8, (size_t)w * 4, cs,
		kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
	CGColorSpaceRelease(cs);
	if (!ctx)
		return NULL;

	// Lottie's y runs down, a bitmap context's up: unflipped, every sticker
	// came out upside down (the slot machine's 7, its lamp under the body).
	CGContextTranslateCTM(ctx, 0, (CGFloat)h);
	CGContextScaleCTM(ctx, 1, -1);
	CGFloat scale = MIN((CGFloat)w / scene->canvas.width, (CGFloat)h / scene->canvas.height);
	CGFloat ox = TGCenteredOrigin((CGFloat)w, scene->canvas.width * scale);
	CGFloat oy = TGCenteredOrigin((CGFloat)h, scene->canvas.height * scale);
	CGContextTranslateCTM(ctx, ox, oy);
	CGContextScaleCTM(ctx, scale, scale);

	TGDrawComp(*scene, 0, frame, ctx, TGAlphaOpaque, 0);

	CGImageRef img = CGBitmapContextCreateImage(ctx);
	CGContextRelease(ctx);
	return img;
}
