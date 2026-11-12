// tests/shim/UIKit/UIKit.h — macOS test shim.
//
// The host test suite compiles real src code. Some src files import
// <UIKit/UIKit.h> even though what the tests exercise from them is pure
// text/geometry logic: font/colour bookkeeping, measure and wrap. On macOS
// those UIKit names map onto their AppKit counterparts, and the handful of
// view classes the tests actually touch get tiny stand-ins here.
//
// Must stay first on the include path (-I$(TESTS)/shim) so this header
// resolves instead of to the iOS SDK, which does not exist on the host.
//
// It is deliberately narrow: only what the suites under it need. Grow it
// only when a new suite can compile real src without faking behaviour.
#pragma once

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>

// ─── fonts and colours ───────────────────────────────────────────────────────
// AppKit's NSFont/NSColor carry the same surface the tested code uses
// (fontWithName:size:, systemFontOfSize:, boldSystemFontOfSize:,
// pointSize, fontName; blackColor, colorWithRed:green:blue:alpha:).
typedef NSFont UIFont;
typedef NSColor UIColor;
typedef NSImage UIImage;

// Host gaps AppKit does not cover. NSFont lacks the italic convenience and
// the geometry NSValue accessors only exist on iOS in this spelling.
@interface NSFont (UIKitHostShim)
+ (UIFont *)italicSystemFontOfSize:(CGFloat)size;
@end

@interface NSValue (UIKitHostShim)
+ (NSValue *)valueWithCGSize:(CGSize)size;
- (CGSize)CGSizeValue;
@end

// ─── UIDevice ────────────────────────────────────────────────────────────────
// TGClient +Account streams device_model/system_version into setTdlibParameters.
@interface UIDevice : NSObject
+ (UIDevice *)currentDevice;
@property (nonatomic, readonly) NSString *model;
@property (nonatomic, readonly) NSString *systemVersion;
@end

// ─── UIView ──────────────────────────────────────────────────────────────────
@interface UIView : NSObject
@property (nonatomic, assign) CGRect frame;
@property (nonatomic, assign) CGRect bounds;
@property (nonatomic, strong) CALayer *layer;
@property (nonatomic, strong) UIColor *backgroundColor;
@property (nonatomic, assign) BOOL hidden;
@property (nonatomic, assign) CGFloat alpha;
@property (nonatomic, readonly) UIView *superview;
- (void)addSubview:(UIView *)view;
- (void)removeFromSuperview;
@end

// ─── UILabel ─────────────────────────────────────────────────────────────────
// A data-holding stand-in: TGSetBodyText only ever reads and writes these.
@interface UILabel : UIView
@property (nonatomic, copy)   NSString *text;
@property (nonatomic, strong) UIFont *font;
@property (nonatomic, strong) UIColor *textColor;
@property (nonatomic, strong) NSAttributedString *attributedText;
@end

// ─── NSString UIKit additions ────────────────────────────────────────────────
@interface NSString (UIKitHostShim)
- (CGSize)sizeWithFont:(UIFont *)font;
- (CGSize)sizeWithFont:(UIFont *)font constrainedToSize:(CGSize)size
        lineBreakMode:(NSInteger)lineBreakMode;
@end

// ─── NSAttributedString UIKit additions ──────────────────────────────────────
// None needed: AppKit's NSStringDrawing.h provides the full
// boundingRectWithSize:options:context: surface the src code calls, and a
// shimmed duplicate of a selector AppKit owns would recurse through itself.

// ─── UITableView, UINavigationBar, UITabBar, UITableViewCell ─────────────────
// Minimal data-holding stand-ins for TGTheme styling tests (iOS 6 parity).
// These are NOT functional UIKit widgets — they carry only the properties the
// theme layer reads and writes so the styling methods can run on the host.

typedef NS_ENUM(NSInteger, UIBarStyle) {
    UIBarStyleDefault = 0,
    UIBarStyleBlack   = 2,
};

typedef NS_ENUM(NSInteger, UIBarMetrics) {
    UIBarMetricsDefault = 0,
};

typedef NS_ENUM(NSInteger, UITableViewCellSeparatorStyle) {
    UITableViewCellSeparatorStyleNone       = 0,
    UITableViewCellSeparatorStyleSingleLine = 1,
};

typedef NS_ENUM(NSInteger, UITableViewCellStyle) {
    UITableViewCellStyleDefault = 0,
    UITableViewCellStyleValue1  = 1,
    UITableViewCellStyleValue2  = 2,
    UITableViewCellStyleSubtitle = 3,
};

typedef NS_ENUM(NSInteger, UIControlState) {
    UIControlStateNormal   = 0,
    UIControlStateSelected = 1,
};

typedef NS_ENUM(NSInteger, UIImageRenderingMode) {
    UIImageRenderingModeAlwaysOriginal = 1,
};

// UIBarButtonItem — referenced by styleNavigationBar helpers.
@interface UIBarButtonItem : NSObject
@property (nonatomic, strong) UIColor *tintColor;
- (instancetype)initWithTitle:(NSString *)title style:(NSInteger)style
                       target:(id)target action:(SEL)action;
@end

// UITabBarItem — tab glyphs, associated via objc runtime in styleTabBar:.
@interface UITabBarItem : NSObject
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, assign) NSInteger tag;
- (void)setTitleTextAttributes:(NSDictionary *)attrs forState:(UIControlState)state;
@end

// UITableViewCell
@interface UITableViewCell : UIView
@property (nonatomic, strong) UIView *selectedBackgroundView;
@property (nonatomic, strong) UILabel *textLabel;
@property (nonatomic, strong) UILabel *detailTextLabel;
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)id;
@end

// UITableView — data-holding stub for stylePlainTable: / styleGroupedTable:.
@interface UITableView : UIView
@property (nonatomic, assign) UITableViewCellSeparatorStyle separatorStyle;
@property (nonatomic, strong) UIColor *separatorColor;
@property (nonatomic, strong) UIView *backgroundView;
@property (nonatomic, strong) NSArray *visibleCells;
@end

// UINavigationBar — stub for styleNavigationBar:.
@interface UINavigationBar : UIView
@property (nonatomic, assign) UIBarStyle barStyle;
@property (nonatomic, strong) UIColor *tintColor;
@property (nonatomic, assign) BOOL translucent;
@property (nonatomic, strong) NSDictionary *titleTextAttributes;
@end

// UISearchBar — stub for styleSearchBar:.
@interface UISearchBar : UIView
@property (nonatomic, assign) UIBarStyle barStyle;
@property (nonatomic, strong) UIColor *tintColor;
@end

// UITabBar — stub for styleTabBar:.
@interface UITabBar : UIView
@property (nonatomic, strong) UIColor *tintColor;
@property (nonatomic, strong) NSArray *items;
@end
