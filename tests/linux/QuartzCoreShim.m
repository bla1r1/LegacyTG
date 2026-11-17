// tests/linux/QuartzCoreShim.m - see QuartzCore/QuartzCore.h.
#import <QuartzCore/QuartzCore.h>

@implementation CALayer
+ (instancetype)layer { return [[self alloc] init]; }
@end
