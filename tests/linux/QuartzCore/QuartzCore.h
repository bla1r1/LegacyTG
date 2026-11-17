// tests/linux/QuartzCore/QuartzCore.h - CALayer as the host tests use it.
//
// GNUstep has no Core Animation. The tested code only sets a layer's
// corner, border and colours and reads them back; this layer holds them and
// draws nothing.
#pragma once
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@interface CALayer : NSObject
+ (instancetype)layer;
@property (nonatomic, assign) CGRect frame;
@property (nonatomic, assign) CGRect bounds;
@property (nonatomic, assign) CGFloat cornerRadius;
@property (nonatomic, assign) CGFloat borderWidth;
@property (nonatomic, assign) CGColorRef borderColor;
@property (nonatomic, assign) CGColorRef backgroundColor;
@property (nonatomic, assign) BOOL masksToBounds;
@property (nonatomic, assign) BOOL shouldRasterize;
@property (nonatomic, assign) CGFloat rasterizationScale;
@property (nonatomic, assign) float opacity;
@property (nonatomic, strong) id contents;
@property (nonatomic, copy) NSString *name;
@end
