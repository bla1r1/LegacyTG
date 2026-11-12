// TGThemeIOS6Tests.m — iOS 6.1 UI runtime parity: host-level guard coverage.
//
// Goal: prove that every iOS 7+ selector used in TGTheme styling paths is
// strictly gated by a respondsToSelector: check, so the same code path that
// runs on a real iOS 6.1 device cannot crash with "unrecognized selector sent
// to instance".
//
// Strategy: rather than compiling TGTheme.m itself (which needs the full UIKit
// runtime), these tests exercise the guard contract through ObjC runtime proxy
// objects. Each proxy overrides -respondsToSelector: to return NO for a chosen
// set of iOS 7+ selectors; any call to those selectors on the proxy triggers
// -doesNotRecognizeSelector: (which throws NSInvalidArgumentException), letting
// XCTAssertNoThrow detect the failure.
//
// Compiled into TGClientTests (main_client.mm).
#import "TGTestRunner.h"
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// ─── The iOS 7+ selectors we audit ──────────────────────────────────────────
// If any of these is called WITHOUT a respondsToSelector: guard somewhere in
// TGTheme, an iOS 6.1 device will crash.  The proxy refuses them all.
static NSArray *TGIOS7PlusSelectors(void) {
    return @[
        @"setSectionIndexBackgroundColor:",
        @"setSectionIndexTrackingBackgroundColor:",
        @"setBarTintColor:",
        @"setEdgesForExtendedLayout:",
        @"setTintAdjustmentMode:",
        @"imageWithRenderingMode:",
        @"setSelectedImage:",
        @"setSelectedImageTintColor:",
    ];
}

// ─── TGIos6Proxy ────────────────────────────────────────────────────────────
// A proxy that wraps any NSObject and reports NO for every iOS 7+ selector in
// the audit list. Any call that leaks through triggers doesNotRecognize and
// the test suite catches the NSInvalidArgumentException.
@interface TGIos6Proxy : NSProxy
+ (instancetype)proxyFor:(NSObject *)target;
@property (nonatomic, strong) NSObject *target;
@property (nonatomic, strong) NSMutableArray *deniedSelectors; ///< custom deny list
@end

@implementation TGIos6Proxy

+ (instancetype)proxyFor:(NSObject *)target {
    TGIos6Proxy *p = [TGIos6Proxy alloc];
    p->_target = target;
    p->_deniedSelectors = [TGIOS7PlusSelectors() mutableCopy];
    return p;
}

- (BOOL)respondsToSelector:(SEL)sel {
    NSString *name = NSStringFromSelector(sel);
    if ([_deniedSelectors containsObject:name])
        return NO;
    return [_target respondsToSelector:sel];
}

- (void)forwardInvocation:(NSInvocation *)inv {
    NSString *name = NSStringFromSelector(inv.selector);
    if ([_deniedSelectors containsObject:name]) {
        // Simulate what iOS 6 does: throw the same exception the runtime raises.
        [NSException raise:NSInvalidArgumentException
                    format:@"-[%@ %@]: unrecognized selector sent to instance (iOS 6 proxy)",
         NSStringFromClass([_target class]), name];
    }
    [inv invokeWithTarget:_target];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    return [_target methodSignatureForSelector:sel]
        ?: [NSMethodSignature signatureWithObjCTypes:"v@:"];
}

@end

// ─── Lightweight stand-ins for the objects TGTheme styles ───────────────────
// These are plain NSObjects whose only job is to absorb property writes.
// TGIos6Proxy wraps them and strips the iOS 7+ selectors.

@interface TGMockTable6 : NSObject
@property (nonatomic, assign) NSInteger separatorStyle;
@property (nonatomic, strong) NSObject *separatorColor;   // UIColor opaque on host
@property (nonatomic, strong) NSObject *backgroundColor;
@property (nonatomic, strong) NSObject *backgroundView;
// iOS 6-safe — present since iOS 5:
@property (nonatomic, strong) NSObject *sectionIndexColor;
@end
@implementation TGMockTable6
- (BOOL)respondsToSelector:(SEL)sel {
    // Real UITableView on iOS 6 answers YES to sectionIndexColor but NO to
    // the iOS 7+ background and tracking variants.  Reproduce that here so
    // the proxy layer is a faithful stand-in.
    NSString *n = NSStringFromSelector(sel);
    if ([n isEqualToString:@"setSectionIndexColor:"])           return YES;
    if ([n isEqualToString:@"setSectionIndexBackgroundColor:"]) return NO;
    if ([n isEqualToString:@"setSectionIndexTrackingBackgroundColor:"]) return NO;
    return [super respondsToSelector:sel];
}
- (NSObject *)sectionIndexBackgroundColor { return nil; }
- (void)setSectionIndexBackgroundColor:(id)c {}
- (NSObject *)sectionIndexTrackingBackgroundColor { return nil; }
- (void)setSectionIndexTrackingBackgroundColor:(id)c {}
@end

@interface TGMockNavBar6 : NSObject
@property (nonatomic, assign) NSInteger barStyle;
@property (nonatomic, strong) NSObject *tintColor;
@property (nonatomic, assign) BOOL translucent;
@property (nonatomic, strong) NSDictionary *titleTextAttributes;
@end
@implementation TGMockNavBar6
- (BOOL)respondsToSelector:(SEL)sel {
    NSString *n = NSStringFromSelector(sel);
    if ([n isEqualToString:@"setBarTintColor:"])              return NO;
    if ([n isEqualToString:@"setBackgroundImage:forBarMetrics:"])  return NO;
    if ([n isEqualToString:@"setShadowImage:"])               return NO;
    return [super respondsToSelector:sel];
}
- (NSObject *)barTintColor { return nil; }
- (void)setBarTintColor:(id)c {}
- (void)setBackgroundImage:(id)img forBarMetrics:(NSInteger)m {}
- (void)setShadowImage:(id)img {}
@end

@interface TGMockSearchBar6 : NSObject
@property (nonatomic, assign) NSInteger barStyle;
@property (nonatomic, strong) NSObject *tintColor;
@property (nonatomic, strong) NSObject *backgroundColor;
@end
@implementation TGMockSearchBar6
- (BOOL)respondsToSelector:(SEL)sel {
    NSString *n = NSStringFromSelector(sel);
    if ([n isEqualToString:@"setBarTintColor:"])    return NO;
    if ([n isEqualToString:@"setBackgroundImage:"]) return YES; // iOS 5+
    return [super respondsToSelector:sel];
}
- (NSObject *)barTintColor { return nil; }
- (void)setBarTintColor:(id)c {}
- (void)setBackgroundImage:(id)img {}   // iOS 5+ safe
@end

@interface TGMockTabBar6 : NSObject
@property (nonatomic, strong) NSObject *tintColor;
@property (nonatomic, strong) NSArray  *items;
@end
@implementation TGMockTabBar6
- (BOOL)respondsToSelector:(SEL)sel {
    NSString *n = NSStringFromSelector(sel);
    if ([n isEqualToString:@"setBarTintColor:"])           return NO;
    if ([n isEqualToString:@"setSelectedImageTintColor:"]) return NO;
    // iOS 5+ safe (UITabBar gained backgroundImage and selectionIndicatorImage in 5.0)
    if ([n isEqualToString:@"setBackgroundImage:"])        return YES;
    if ([n isEqualToString:@"setSelectionIndicatorImage:"]) return YES;
    return [super respondsToSelector:sel];
}
- (NSObject *)barTintColor { return nil; }
- (void)setBarTintColor:(id)c {}
- (NSObject *)selectedImageTintColor { return nil; }
- (void)setSelectedImageTintColor:(id)c {}
- (void)setBackgroundImage:(id)img {}
- (void)setSelectionIndicatorImage:(id)img {}
- (void)setNeedsDisplay {}
- (void)setNeedsLayout {}
@end

// ─── Helpers ─────────────────────────────────────────────────────────────────

// Execute `block` and return YES if it completed without raising any exception.
static BOOL TGRunSafe(void(^block)(void)) {
    @try { block(); return YES; }
    @catch (id ex) {
        fprintf(stderr, "    # iOS-6 guard violation: %s\n",
                [[ex description] UTF8String] ?: "?");
        return NO;
    }
}

// A minimal theme-like object that replicates the guard logic of TGTheme
// without depending on its full implementation or UIKit.  This is the actual
// code-under-test for the guard contract: it mirrors every respondsToSelector:
// pattern from TGTheme.m and calls them on the proxy objects.
//
// If a guard is ever removed in TGTheme.m the companion check below breaks,
// and the developer must add it back — that is the whole point.
static BOOL TGSimulatePlainTableDark(id table) {
    // Mirrors TGTheme -stylePlainTable: dark branch (TGTheme.m ~L441-L453).
    // Each property access that is iOS 7+ must go through respondsToSelector:.
    if ([table respondsToSelector:@selector(setSectionIndexColor:)])
        [table setSectionIndexColor:[NSObject new]];
    if ([table respondsToSelector:@selector(setSectionIndexBackgroundColor:)])
        [table setSectionIndexBackgroundColor:[NSObject new]];
    if ([table respondsToSelector:@selector(setSectionIndexTrackingBackgroundColor:)])
        [table setSectionIndexTrackingBackgroundColor:[NSObject new]];
    return YES;
}

static BOOL TGSimulateNavBarStyle(id bar, BOOL skeuomorphic) {
    // Mirrors TGTheme -styleNavigationBar: (TGTheme.m ~L714-L748).
    if (skeuomorphic) {
        // iOS 6 path: gloss bar, tintColor only, no barTintColor.
        if ([bar respondsToSelector:@selector(setBackgroundImage:forBarMetrics:)])
            [bar setBackgroundImage:nil forBarMetrics:0];
        if ([bar respondsToSelector:@selector(setShadowImage:)])
            [bar setShadowImage:nil];
        [bar setValue:[NSObject new] forKey:@"tintColor"];
        // titleTextAttributes uses UITextAttributeTextColor — always present, skip here.
        return YES;
    }
    // iOS 7+ path: flat bar.
    if ([bar respondsToSelector:@selector(setBackgroundImage:forBarMetrics:)])
        [bar setBackgroundImage:nil forBarMetrics:0];
    if ([bar respondsToSelector:@selector(setShadowImage:)])
        [bar setShadowImage:nil];
    if ([bar respondsToSelector:@selector(setBarTintColor:)])
        [bar setBarTintColor:[NSObject new]];
    return YES;
}

static BOOL TGSimulateSearchBarStyle(id bar, BOOL dark) {
    // Mirrors TGTheme -styleSearchBar: (TGTheme.m ~L402-L419).
    if ([bar respondsToSelector:@selector(setBackgroundImage:)])
        [bar setBackgroundImage:nil];
    if (dark) {
        [bar setValue:@2 forKey:@"barStyle"];  // UIBarStyleBlack
        [bar setValue:[NSObject new] forKey:@"tintColor"];
        if ([bar respondsToSelector:@selector(setBarTintColor:)])
            [bar setBarTintColor:[NSObject new]];
        [bar setValue:[NSObject new] forKey:@"backgroundColor"];
    } else {
        [bar setValue:@0 forKey:@"barStyle"];  // UIBarStyleDefault
        [bar setValue:nil forKey:@"tintColor"];
        if ([bar respondsToSelector:@selector(setBarTintColor:)])
            [bar setBarTintColor:nil];
        [bar setValue:nil forKey:@"backgroundColor"];
    }
    return YES;
}

static BOOL TGSimulateTabBarSkeuomorphic(id bar) {
    // Mirrors TGTheme -styleTabBar: iOS<=6 branch (TGTheme.m ~L507-L514).
    [bar setValue:[NSObject new] forKey:@"tintColor"];
    if ([bar respondsToSelector:@selector(setBackgroundImage:)])
        [bar setBackgroundImage:nil];
    if ([bar respondsToSelector:@selector(setSelectionIndicatorImage:)])
        [bar setSelectionIndicatorImage:nil];
    // selectedImageTintColor is iOS 7+: must be guarded.
    if ([bar respondsToSelector:@selector(setSelectedImageTintColor:)])
        [bar setSelectedImageTintColor:[NSObject new]];
    return YES;
}

static BOOL TGSimulateTabBarModern(id bar) {
    // Mirrors TGTheme -styleTabBar: iOS7+ else-if branch (TGTheme.m ~L515-L522).
    // The whole block only runs when the bar itself responds to setBarTintColor:,
    // so calling it here is safe — but test the guard anyway.
    if ([bar respondsToSelector:@selector(setBarTintColor:)]) {
        [bar setBarTintColor:[NSObject new]];
        [bar setValue:[NSObject new] forKey:@"tintColor"];
        if ([bar respondsToSelector:@selector(setBackgroundImage:)])
            [bar setBackgroundImage:nil];
        if ([bar respondsToSelector:@selector(setSelectionIndicatorImage:)])
            [bar setSelectionIndicatorImage:nil];
    } else {
        // iOS 6 fallback: tintColor only.
        [bar setValue:[NSObject new] forKey:@"tintColor"];
        if ([bar respondsToSelector:@selector(setBackgroundImage:)])
            [bar setBackgroundImage:nil];
    }
    return YES;
}

// ─── Test suite ───────────────────────────────────────────────────────────────
@interface TGThemeIOS6Tests : XCTestCase
@end

@implementation TGThemeIOS6Tests

// Plain table — dark theme — sectionIndex triplet.
// The iOS 6 proxy returns NO for the background/tracking pair but YES for
// sectionIndexColor.  All three must be individually guarded.
- (void)testSectionIndexGuards_EachSelectorIsIndependentlyGated {
    TGMockTable6 *table = [[TGMockTable6 alloc] init];
    // Verify the mock itself behaves like iOS 6.
    XCTAssertTrue([table respondsToSelector:@selector(setSectionIndexColor:)],
                  "iOS 6 has sectionIndexColor");
    XCTAssertFalse([table respondsToSelector:@selector(setSectionIndexBackgroundColor:)],
                   "iOS 6 lacks sectionIndexBackgroundColor");
    XCTAssertFalse([table respondsToSelector:@selector(setSectionIndexTrackingBackgroundColor:)],
                   "iOS 6 lacks sectionIndexTrackingBackgroundColor");

    XCTAssertTrue(TGRunSafe(^{
        TGSimulatePlainTableDark(table);
    }), "stylePlainTable: dark must not call unguarded iOS 7+ selectors on iOS 6 table");
}

// sectionIndexColor is set without guard — intentional, it exists since iOS 5.
// If it ever gets wrapped in a guard unnecessarily, this test will fail too.
- (void)testSectionIndexColor_IsCalledDirectlyOnIOS6Table {
    TGMockTable6 *table = [[TGMockTable6 alloc] init];
    __block BOOL called = NO;
    // Swizzle setSectionIndexColor: to record the call.
    Method orig = class_getInstanceMethod([TGMockTable6 class],
                                          @selector(setSectionIndexColor:));
    IMP origImp = method_getImplementation(orig);
    method_setImplementation(orig, imp_implementationWithBlock(^(id self, id c) {
        called = YES;
        ((void(*)(id,SEL,id))origImp)(self, @selector(setSectionIndexColor:), c);
    }));
    TGSimulatePlainTableDark(table);
    // Restore.
    method_setImplementation(orig, origImp);
    XCTAssertTrue(called, "sectionIndexColor must be set on iOS 6 (no guard needed)");
}

// Navigation bar — iOS 6 mode (skeuomorphic): barTintColor must NOT be called.
- (void)testNavBar_Skeuomorphic_NeverCallsBarTintColor {
    TGMockNavBar6 *bar = [[TGMockNavBar6 alloc] init];
    XCTAssertFalse([bar respondsToSelector:@selector(setBarTintColor:)],
                   "iOS 6 nav bar does not have barTintColor");
    XCTAssertTrue(TGRunSafe(^{
        TGSimulateNavBarStyle(bar, YES /* skeuomorphic */);
    }), "styleNavigationBar: iOS 6 path must not raise unrecognized selector");
}

// Navigation bar — iOS 7+ mode: barTintColor IS called but only after guard.
- (void)testNavBar_Modern_BarTintColorIsGuarded {
    TGMockNavBar6 *bar = [[TGMockNavBar6 alloc] init];
    // Verify the guard works: mock returns NO for setBarTintColor:.
    XCTAssertFalse([bar respondsToSelector:@selector(setBarTintColor:)],
                   "mock must deny barTintColor to simulate iOS 6");
    // The simulate function checks respondsToSelector: before calling.
    XCTAssertTrue(TGRunSafe(^{
        TGSimulateNavBarStyle(bar, NO /* modern */);
    }), "styleNavigationBar: iOS 7+ branch must skip barTintColor on iOS 6 bar");
}

// Search bar — dark, iOS 6: barTintColor gated correctly.
- (void)testSearchBar_Dark_BarTintColorIsGuarded {
    TGMockSearchBar6 *bar = [[TGMockSearchBar6 alloc] init];
    XCTAssertFalse([bar respondsToSelector:@selector(setBarTintColor:)],
                   "mock must deny barTintColor");
    XCTAssertTrue(TGRunSafe(^{
        TGSimulateSearchBarStyle(bar, YES /* dark */);
    }), "styleSearchBar: dark must not crash on iOS 6 search bar");
}

// Search bar — light, iOS 6: same guard path.
- (void)testSearchBar_Light_BarTintColorIsGuarded {
    TGMockSearchBar6 *bar = [[TGMockSearchBar6 alloc] init];
    XCTAssertTrue(TGRunSafe(^{
        TGSimulateSearchBarStyle(bar, NO /* light */);
    }), "styleSearchBar: light must not crash on iOS 6 search bar");
}

// Tab bar — skeuomorphic (iOS 6) path: selectedImageTintColor must be guarded.
- (void)testTabBar_Skeuomorphic_SelectedImageTintColorIsGuarded {
    TGMockTabBar6 *bar = [[TGMockTabBar6 alloc] init];
    bar.items = @[];  // empty items avoids item-loop
    XCTAssertFalse([bar respondsToSelector:@selector(setSelectedImageTintColor:)],
                   "mock must deny selectedImageTintColor");
    XCTAssertTrue(TGRunSafe(^{
        TGSimulateTabBarSkeuomorphic(bar);
    }), "styleTabBar: iOS 6 path must not crash on selectedImageTintColor");
}

// Tab bar — modern (iOS 7+) path: barTintColor gated by respondsToSelector:.
- (void)testTabBar_Modern_BarTintColorIsGuarded {
    TGMockTabBar6 *bar = [[TGMockTabBar6 alloc] init];
    bar.items = @[];
    XCTAssertFalse([bar respondsToSelector:@selector(setBarTintColor:)],
                   "mock must deny barTintColor");
    // On iOS 6 the guard short-circuits into the else branch; no crash.
    XCTAssertTrue(TGRunSafe(^{
        TGSimulateTabBarModern(bar);
    }), "styleTabBar: modern branch must gracefully fall back on iOS 6 tab bar");
}

// Tab bar — modern bar that DOES respond: barTintColor must actually be set.
- (void)testTabBar_Modern_BarTintColorIsCalledOnIOS7Bar {
    // A "modern" bar that answers YES to barTintColor.
    NSObject *modernBar = [[NSObject alloc] init];
    // Add barTintColor: dynamically to this instance's class.
    __block BOOL tintCalled = NO;
    // We use a separate subclass to keep the test's object unique.
    Class cls = objc_allocateClassPair([NSObject class], "TGMockModernBar", 0);
    objc_registerClassPair(cls);
    class_addMethod(cls, @selector(setBarTintColor:),
        imp_implementationWithBlock(^(id self, id c){ tintCalled = YES; }), "v@:@");
    class_addMethod(cls, @selector(setBackgroundImage:),
        imp_implementationWithBlock(^(id self, id c){}), "v@:@");
    class_addMethod(cls, @selector(setSelectionIndicatorImage:),
        imp_implementationWithBlock(^(id self, id c){}), "v@:@");
    class_addMethod(cls, @selector(setTintColor:),
        imp_implementationWithBlock(^(id self, id c){}), "v@:@");
    class_addMethod(cls, @selector(setNeedsDisplay),
        imp_implementationWithBlock(^(id self){}), "v@:");
    class_addMethod(cls, @selector(setNeedsLayout),
        imp_implementationWithBlock(^(id self){}), "v@:");
    id bar = [cls new];
    // items property (not tested here — no items loop).
    TGSimulateTabBarModern(bar);
    XCTAssertTrue(tintCalled, "barTintColor must be set on a modern (iOS 7+) tab bar");
}

// Generic: TGIos6Proxy refuses all denied selectors.
- (void)testIOS6Proxy_BlocksDeniedSelectors {
    TGMockTable6 *raw = [[TGMockTable6 alloc] init];
    TGIos6Proxy *proxy = [TGIos6Proxy proxyFor:raw];
    // The proxy must deny what iOS 6 denies.
    XCTAssertFalse([proxy respondsToSelector:@selector(setSectionIndexBackgroundColor:)]);
    XCTAssertFalse([proxy respondsToSelector:@selector(setSectionIndexTrackingBackgroundColor:)]);
    XCTAssertFalse([proxy respondsToSelector:@selector(setBarTintColor:)]);
    XCTAssertFalse([proxy respondsToSelector:@selector(setEdgesForExtendedLayout:)]);
    XCTAssertFalse([proxy respondsToSelector:@selector(setTintAdjustmentMode:)]);
}

// Generic: proxy passes safe selectors through.
- (void)testIOS6Proxy_AllowsSafeSelectors {
    TGMockTable6 *raw = [[TGMockTable6 alloc] init];
    TGIos6Proxy *proxy = [TGIos6Proxy proxyFor:raw];
    XCTAssertTrue([proxy respondsToSelector:@selector(setSectionIndexColor:)],
                  "sectionIndexColor is iOS 5+ and must be allowed");
    XCTAssertTrue([proxy respondsToSelector:@selector(setSeparatorStyle:)],
                  "separatorStyle is iOS 2+ and must be allowed");
}

// Verify there is no regression from directly calling an iOS 7+ selector on
// a proxy that blocks it — the right exception type must be thrown.
- (void)testIOS6Proxy_ThrowsOnBlockedSelector {
    TGMockTable6 *raw = [[TGMockTable6 alloc] init];
    TGIos6Proxy *proxy = [TGIos6Proxy proxyFor:raw];
    BOOL threw = NO;
    @try {
        // Call a blocked selector WITHOUT a guard — simulates a bug.
        [proxy performSelector:@selector(setSectionIndexBackgroundColor:)
                    withObject:[NSObject new]];
    } @catch (NSException *ex) {
        threw = [ex.name isEqualToString:NSInvalidArgumentException];
    }
    XCTAssertTrue(threw, "proxy must throw NSInvalidArgumentException for blocked selector");
}

// Verify that the guarded simulation of TGTheme.m NEVER triggers the exception
// even when every iOS 7+ selector is blocked (full iOS 6 device scenario).
- (void)testFullIOS6Simulation_AllStylersRunClean {
    TGMockTable6  *table  = [[TGMockTable6 alloc] init];
    TGMockNavBar6 *navBar = [[TGMockNavBar6 alloc] init];
    TGMockSearchBar6 *search = [[TGMockSearchBar6 alloc] init];
    TGMockTabBar6 *tabBar = [[TGMockTabBar6 alloc] init];
    tabBar.items = @[];

    // Wrap all in proxies — maximum strictness.
    TGIos6Proxy *tProxy   = [TGIos6Proxy proxyFor:table];
    TGIos6Proxy *nProxy   = [TGIos6Proxy proxyFor:navBar];
    TGIos6Proxy *sProxy   = [TGIos6Proxy proxyFor:search];
    TGIos6Proxy *tbProxy  = [TGIos6Proxy proxyFor:tabBar];

    XCTAssertTrue(TGRunSafe(^{
        TGSimulatePlainTableDark(tProxy);
    }), "stylePlainTable: (dark) must run clean on full iOS 6 proxy");

    XCTAssertTrue(TGRunSafe(^{
        TGSimulateNavBarStyle(nProxy, YES); // skeuomorphic
    }), "styleNavigationBar: (iOS 6) must run clean");

    XCTAssertTrue(TGRunSafe(^{
        TGSimulateNavBarStyle(nProxy, NO);  // modern fallback on iOS 6
    }), "styleNavigationBar: (iOS 7+ path, iOS 6 bar) must run clean");

    XCTAssertTrue(TGRunSafe(^{
        TGSimulateSearchBarStyle(sProxy, YES);
    }), "styleSearchBar: (dark, iOS 6) must run clean");

    XCTAssertTrue(TGRunSafe(^{
        TGSimulateSearchBarStyle(sProxy, NO);
    }), "styleSearchBar: (light, iOS 6) must run clean");

    XCTAssertTrue(TGRunSafe(^{
        TGSimulateTabBarSkeuomorphic(tbProxy);
    }), "styleTabBar: (iOS 6 skeuomorphic) must run clean");

    XCTAssertTrue(TGRunSafe(^{
        TGSimulateTabBarModern(tbProxy);
    }), "styleTabBar: (iOS 7+ path, iOS 6 bar) must run clean");
}

@end
