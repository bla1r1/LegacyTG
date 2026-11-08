//
// TGGeometry.h - C-inline layout helpers for LegacyTG.
// Zero-allocation frame slicing and centering for 60 FPS manual layout.
//
#ifndef TGGeometry_h
#define TGGeometry_h

#import <UIKit/UIKit.h>
#import <math.h>

/// Slices `height` points from the top of *rect and moves *rect down by (height + spacing).
static inline CGRect TGFrameSliceTop(CGRect *rect, CGFloat height, CGFloat spacing) {
	if (!rect) return CGRectZero;
	CGRect slice = CGRectMake(rect->origin.x, rect->origin.y, rect->size.width, height);
	rect->origin.y += height + spacing;
	rect->size.height = (rect->size.height > height + spacing) ? (rect->size.height - height - spacing) : 0.0f;
	return slice;
}

/// Slices `height` points from the bottom of *rect and shrinks *rect.
static inline CGRect TGFrameSliceBottom(CGRect *rect, CGFloat height, CGFloat spacing) {
	if (!rect) return CGRectZero;
	CGFloat y = rect->origin.y + rect->size.height - height;
	CGRect slice = CGRectMake(rect->origin.x, y, rect->size.width, height);
	rect->size.height = (rect->size.height > height + spacing) ? (rect->size.height - height - spacing) : 0.0f;
	return slice;
}

/// Slices `width` points from the left of *rect and moves *rect right by (width + spacing).
static inline CGRect TGFrameSliceLeft(CGRect *rect, CGFloat width, CGFloat spacing) {
	if (!rect) return CGRectZero;
	CGRect slice = CGRectMake(rect->origin.x, rect->origin.y, width, rect->size.height);
	rect->origin.x += width + spacing;
	rect->size.width = (rect->size.width > width + spacing) ? (rect->size.width - width - spacing) : 0.0f;
	return slice;
}

/// Slices `width` points from the right of *rect and shrinks *rect.
static inline CGRect TGFrameSliceRight(CGRect *rect, CGFloat width, CGFloat spacing) {
	if (!rect) return CGRectZero;
	CGFloat x = rect->origin.x + rect->size.width - width;
	CGRect slice = CGRectMake(x, rect->origin.y, width, rect->size.height);
	rect->size.width = (rect->size.width > width + spacing) ? (rect->size.width - width - spacing) : 0.0f;
	return slice;
}

/// Centers a child size within a container rectangle aligned to integral pixels.
static inline CGRect TGFrameCenterInRect(CGSize size, CGRect container) {
	CGFloat x = (CGFloat)floor(container.origin.x + (container.size.width - size.width) * 0.5f);
	CGFloat y = (CGFloat)floor(container.origin.y + (container.size.height - size.height) * 0.5f);
	return CGRectMake(x, y, size.width, size.height);
}

#endif /* TGGeometry_h */
