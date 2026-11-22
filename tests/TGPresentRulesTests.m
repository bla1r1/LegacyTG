// TGPresentRulesTests.m - what a bar button says and where it sits, how a
// modal closes, where a menu hangs. Two screens asking for the same role must
// get the same button; these pin what that button is.
#import "TGTestRunner.h"
#import "TGPresentRules.h"
#import "TGIconPaths.h"
#import "TGStyle.h"

@interface TGPresentRulesTests : XCTestCase @end

@implementation TGPresentRulesTests

/// Official Common.* words, word for word, so the language pack translates.
- (void)testTextRoles_OfficialWords {
	XCTAssertEqualObjects(TGBarRoleTitle(TGBarRoleBack), @"Back");
	XCTAssertEqualObjects(TGBarRoleTitle(TGBarRoleCancel), @"Cancel");
	XCTAssertEqualObjects(TGBarRoleTitle(TGBarRoleDone), @"Done");
	XCTAssertEqualObjects(TGBarRoleTitle(TGBarRoleEdit), @"Edit");
	XCTAssertEqualObjects(TGBarRoleTitle(TGBarRoleClose), @"Close");
}

/// A glyph role has no words, a glyph the catalogue draws, and a label.
- (void)testGlyphRoles_DrawAGlyphTheCatalogueHas {
	TGBarRole glyphs[] = {TGBarRoleMore, TGBarRoleShare, TGBarRoleAddStory};
	for (size_t i = 0; i < 3; i++){
		TGBarRole r = glyphs[i];
		XCTAssertNil(TGBarRoleTitle(r), @"%@", TGBarRoleName(r));
		NSString *glyph = TGBarRoleGlyph(r);
		XCTAssertTrue(glyph.length && TGIconPathNamed(glyph.UTF8String) != NULL,
				@"%@", TGBarRoleName(r));
		XCTAssertTrue(TGBarRoleLabel(r).length > 0, @"%@", TGBarRoleName(r));
	}
}

/// Every role is exactly one of words, a glyph or the system's own item.
- (void)testEveryRole_WordsGlyphOrSystem {
	for (NSInteger i = 0; i < TGBarRoleCount; i++){
		TGBarRole r = (TGBarRole)i;
		int kinds = (TGBarRoleTitle(r) != nil) + (TGBarRoleGlyph(r) != nil)
				+ TGBarRoleIsSystemItem(r);
		XCTAssertEqual(kinds, 1, @"%@", TGBarRoleName(r));
		XCTAssertTrue(TGBarRoleName(r).length > 0);
	}
}

/// Only Done commits, so only Done is bold.
- (void)testPrimary_OnlyDone {
	for (NSInteger i = 0; i < TGBarRoleCount; i++)
		XCTAssertEqual(TGBarRoleIsPrimary((TGBarRole)i), i == TGBarRoleDone,
				@"%@", TGBarRoleName((TGBarRole)i));
}

/// Leaving is on the left, everything else on the right.
- (void)testSides_LeavingLeft {
	for (NSInteger i = 0; i < TGBarRoleCount; i++){
		TGBarRole r = (TGBarRole)i;
		BOOL leaves = r == TGBarRoleBack || r == TGBarRoleCancel || r == TGBarRoleClose;
		XCTAssertEqual(TGBarRoleSide(r), leaves ? TGBarSideLeft : TGBarSideRight,
				@"%@", TGBarRoleName(r));
	}
}

/// A role out of range falls back to Close rather than reading past the table.
- (void)testOutOfRange_FallsBack {
	XCTAssertEqualObjects(TGBarRoleTitle((TGBarRole)TGBarRoleCount), @"Close");
	XCTAssertEqualObjects(TGBarRoleTitle((TGBarRole)-1), @"Close");
}

/// Add, Search and Compose stay UIKit's own items the screens already show.
- (void)testSystemRoles_AddSearchCompose {
	for (NSInteger i = 0; i < TGBarRoleCount; i++){
		TGBarRole r = (TGBarRole)i;
		BOOL system = r == TGBarRoleAdd || r == TGBarRoleSearch || r == TGBarRoleCompose;
		XCTAssertEqual(TGBarRoleIsSystemItem(r), system, @"%@", TGBarRoleName(r));
	}
	XCTAssertNil(TGBarRoleGlyph(TGBarRoleAdd));
	XCTAssertEqualObjects(TGBarRoleLabel(TGBarRoleAdd), @"Add");
	XCTAssertEqualObjects(TGBarRoleLabel(TGBarRoleSearch), @"Search");
}

/// Only Add Story stands bare in the bar; every other glyph gets the border.
- (void)testBare_OnlyAddStory {
	for (NSInteger i = 0; i < TGBarRoleCount; i++)
		XCTAssertEqual(TGBarRoleIsBare((TGBarRole)i), i == TGBarRoleAddStory,
				@"%@", TGBarRoleName((TGBarRole)i));
}

- (void)testModal_FormCancelsInfoClosesBareHasNone {
	TGBarRole role = TGBarRoleDone;
	XCTAssertTrue(TGModalDismissRole(TGModalForm, &role));
	XCTAssertEqual(role, TGBarRoleCancel);
	XCTAssertTrue(TGModalDismissRole(TGModalInfo, &role));
	XCTAssertEqual(role, TGBarRoleClose);
	role = TGBarRoleDone;
	XCTAssertFalse(TGModalDismissRole(TGModalBare, &role));
	XCTAssertEqual(role, TGBarRoleDone, @"a bare modal leaves the role alone");
	XCTAssertTrue(TGModalDismissRole(TGModalForm, NULL));
}

/// The menu hangs from the middle of the source's bottom edge.
- (void)testMenuAnchor_UnderTheSource {
	CGPoint p = TGMenuAnchorUnder(CGRectMake(270, 20, 44, 44));
	XCTAssertEqual(p.x, (CGFloat)292);
	XCTAssertEqual(p.y, (CGFloat)64);
}

/// With no view to measure, the button is a bar-high square in the corner.
- (void)testFallbackRect_CornerOfTheBar {
	CGRect bar = CGRectMake(0, 20, 320, TGMetricNavigationBarHeight);
	CGRect right = TGBarItemFallbackRect(bar, TGBarSideRight);
	XCTAssertEqual(CGRectGetMaxX(right), (CGFloat)(320 - TGMetricPadSmall));
	XCTAssertEqual(right.origin.y, (CGFloat)20);
	XCTAssertEqual(right.size.width, TGMetricNavigationBarHeight);
	CGRect left = TGBarItemFallbackRect(bar, TGBarSideLeft);
	XCTAssertEqual(left.origin.x, TGMetricPadSmall);
	XCTAssertEqual(TGMenuAnchorUnder(right).y, (CGFloat)(20 + TGMetricNavigationBarHeight));
}

/// An action menu's rows take their glyph from their first word.
- (void)testMenuGlyph_FromTheFirstWord {
	XCTAssertEqualObjects(TGMenuGlyphForTitle(@"Delete Chat"), @"delete");
	XCTAssertEqualObjects(TGMenuGlyphForTitle(@"Remove from Recent"), @"delete");
	XCTAssertEqualObjects(TGMenuGlyphForTitle(@"Rename"), @"edit");
	XCTAssertEqualObjects(TGMenuGlyphForTitle(@"Copy Link"), @"copy");
	XCTAssertEqualObjects(TGMenuGlyphForTitle(@"Unpin"), @"unpin");
	XCTAssertNil(TGMenuGlyphForTitle(@"Jump to Date"));
	XCTAssertNil(TGMenuGlyphForTitle(@""));
	XCTAssertNil(TGMenuGlyphForTitle(nil));
	for (NSString *glyph in @[@"delete", @"edit", @"copy", @"pin", @"unpin", @"mute",
			@"unmute", @"archive", @"unarchive", @"reply", @"forward"])
		XCTAssertTrue(TGIconPathNamed(glyph.UTF8String) != NULL, @"%@", glyph);
}

/// Plain titles become menu items, the destructive one red.
- (void)testMenuItems_GlyphAndDestructive {
	NSArray *items = TGMenuItems(@[@"Edit", @"Info", @"Delete"], 2);
	XCTAssertEqual(items.count, (NSUInteger)3);
	XCTAssertEqualObjects(items[0][@"icon"], @"edit");
	XCTAssertNil(items[1][@"icon"]);
	XCTAssertNil(items[0][@"destructive"]);
	XCTAssertEqualObjects(items[2][@"destructive"], @YES);
	XCTAssertEqual(TGMenuItems(@[@"A"], -1).count, (NSUInteger)1);
}

/// A sheet's "Name · detail" line becomes a title and a grey detail.
- (void)testListEntries_SplitAtTheFirstDot {
	NSArray *e = TGListEntries(@[@"Anna · 2 votes · late", @"Bob", @" · x", @"Revoke"], 3);
	XCTAssertEqualObjects(e[0][@"title"], @"Anna");
	XCTAssertEqualObjects(e[0][@"detail"], @"2 votes · late");
	XCTAssertEqualObjects(e[1][@"title"], @"Bob");
	XCTAssertNil(e[1][@"detail"]);
	XCTAssertEqualObjects(e[2][@"title"], @" · x", @"a leading dot is not a split");
	XCTAssertEqualObjects(e[3][@"destructive"], @YES);
	XCTAssertNil(e[0][@"destructive"]);
}

/// iPad before iOS 8 raises on a full-screen library or share sheet.
- (void)testPopover_OnlyOldIPad {
	XCTAssertTrue(TGSystemPickerNeedsPopover(YES, 6));
	XCTAssertTrue(TGSystemPickerNeedsPopover(YES, 7));
	XCTAssertFalse(TGSystemPickerNeedsPopover(YES, 8));
	XCTAssertFalse(TGSystemPickerNeedsPopover(YES, 12));
	XCTAssertFalse(TGSystemPickerNeedsPopover(NO, 6));
}

@end
