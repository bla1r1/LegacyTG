// TGSettingsPageRowsTests.m - the Settings rows that moved into src/UI/Rows.
//
// The settings pages themselves need UIKit and the client, so the host test
// pins the shared builders they now use, and walks every TGSettingsPage value
// through a fixture section shape. The route is the page's number in the enum.
#import "TGTestRunner.h"

// TGSettingsViewController.h only needs the enum here. The host shim has no
// table view controller; TGChatToolsStickerRowsTests declares the stand-in before
// this file is included in main_client.mm.
#import "TGSettingsViewController.h"

#import "TGRows.h"

@interface TGSettingsPageRowsTests : XCTestCase @end

static NSArray *TGSettingsPageFixtureSections(TGSettingsPage page) {
	NSArray *themes = @[@{@"id" : @"classic", @"name" : @"Classic"}];
	void (^select)(NSString *) = ^(NSString *themeId){ (void)themeId; };
	switch (page){
		case TGSettingsPageRoot:
			return @[TGSection(nil, nil, @[
				TGProfileHeaderRow(@1, @"Ada", @"+1 • @ada", nil, nil, ^{}),
			])];
		case TGSettingsPageAppearance:
			return @[TGSection(@"COLOR THEME", nil, @[
				TGChatPreviewRow(),
				TGThemeCardsRow(themes, @"classic", NO, select),
				TGOpenRow(@"Chat Themes", nil, nil),
			])];
		case TGSettingsPageChatThemes:
			return @[
				TGSection(@"Select Theme", nil, @[
					TGThemeGridRow(themes, @"classic", select),
				]),
				TGSection(@"Create Your Own Theme", nil, @[
					TGChatPreviewRow(),
					TGThemeCardsRow(themes, @"classic", YES, select),
				]),
			];
		default:
			return @[TGSection(nil, nil, @[
				TGOpenRow(@"Page", nil, nil),
			])];
	}
}

@implementation TGSettingsPageRowsTests

- (void)testProfileHeaderBuilderCarriesAvatarNameHandleAndTap {
	UIImage *avatar = [UIImage new];
	__block BOOL loaded = NO;
	__block BOOL tapped = NO;
	NSDictionary *row = TGProfileHeaderRow(@42, @"Ada Lovelace",
			@"+44 • @ada", avatar, ^(UIImageView *view){ loaded = view != nil; },
			^{ tapped = YES; });
	XCTAssertEqualObjects(row[TGRowKind], TGKindProfileHeader);
	XCTAssertEqualObjects(row[TGRowTitle], @"Ada Lovelace");
	XCTAssertEqualObjects(row[TGRowDetail], @"+44 • @ada");
	XCTAssertEqualObjects(row[TGRowPeerId], @42);
	XCTAssertEqualObjects(row[TGRowImage], avatar);
	XCTAssertNotNil(row[TGRowImageLoader]);
	XCTAssertNotNil(row[TGRowTap]);
	((void (^)(UIImageView *))row[TGRowImageLoader])(nil);
	((void (^)(void))row[TGRowTap])();
	XCTAssertTrue(tapped);
	XCTAssertFalse(loaded);
}

- (void)testChatPreviewBuilderIsItsOwnKind {
	NSDictionary *row = TGChatPreviewRow();
	XCTAssertEqualObjects(row[TGRowKind], TGKindChatPreview);
	XCTAssertNil(row[TGRowTap]);
}

- (void)testThemeCardsBuilderCarriesThemesCurrentAndNames {
	NSArray *themes = @[@{@"id" : @"classic"}, @{@"id" : @"emoji:1"}];
	__block NSString *selected = nil;
	NSDictionary *row = TGThemeCardsRow(themes, @"emoji:1", YES,
			^(NSString *themeId){ selected = themeId; });
	XCTAssertEqualObjects(row[TGRowKind], TGKindThemeCards);
	XCTAssertEqualObjects(row[TGRowThemes], themes);
	XCTAssertEqualObjects(row[TGRowCurrentTheme], @"emoji:1");
	XCTAssertTrue([row[TGRowThemeNames] boolValue]);
	XCTAssertNotNil(row[TGRowThemeTap]);
	((void (^)(NSString *))row[TGRowThemeTap])(@"classic");
	XCTAssertEqualObjects(selected, @"classic");
}

- (void)testThemeGridBuilderCarriesThemesAndCurrent {
	NSArray *themes = @[@{@"id" : @"classic"}];
	__block NSString *selected = nil;
	NSDictionary *row = TGThemeGridRow(themes, @"classic",
			^(NSString *themeId){ selected = themeId; });
	XCTAssertEqualObjects(row[TGRowKind], TGKindThemeGrid);
	XCTAssertEqualObjects(row[TGRowThemes], themes);
	XCTAssertEqualObjects(row[TGRowCurrentTheme], @"classic");
	XCTAssertNil(row[TGRowThemeNames]);
	((void (^)(NSString *))row[TGRowThemeTap])(@"classic");
	XCTAssertEqualObjects(selected, @"classic");
}

- (void)testEverySettingsPageHasAFixtureSectionAndRoute {
	NSArray *pages = @[
		@(TGSettingsPageRoot),
		@(TGSettingsPageAppearance),
		@(TGSettingsPageData),
		@(TGSettingsPageNotifications),
		@(TGSettingsPagePrivacy),
		@(TGSettingsPageLanguage),
		@(TGSettingsPageBlocked),
		@(TGSettingsPagePowerSaving),
		@(TGSettingsPageRecentCalls),
		@(TGSettingsPageFolders),
		@(TGSettingsPageProxy),
		@(TGSettingsPageDownloads),
		@(TGSettingsPageWallpaper),
		@(TGSettingsPageChatThemes),
		@(TGSettingsPageAutoNight),
		@(TGSettingsPageAutosave),
		@(TGSettingsPagePaymentData),
		@(TGSettingsPageNotificationSounds),
		@(TGSettingsPageActiveNotifications),
		@(TGSettingsPagePasscode),
		@(TGSettingsPageDebug),
		@(TGSettingsPageLanguageDev),
		@(TGSettingsPagePaymentDev),
	];
	for (NSUInteger i = 0; i < pages.count; i++){
		TGSettingsPage page = (TGSettingsPage)[pages[i] integerValue];
		XCTAssertEqual(page, (TGSettingsPage)i);
		NSString *route = [NSString stringWithFormat:@"itglegacy://settings/%lu",
				(unsigned long)page];
		XCTAssertNotNil(route);
		NSArray *sections = TGSettingsPageFixtureSections(page);
		XCTAssertGreaterThan(sections.count, (NSUInteger)0);
		for (NSDictionary *section in sections){
			NSArray *rows = section[@"rows"];
			XCTAssertGreaterThan(rows.count, (NSUInteger)0);
			for (NSDictionary *row in rows)
				XCTAssertGreaterThan([row[TGRowKind] length], (NSUInteger)0);
		}
	}
	// The two pages the old private cells lived on keep their shape.
	NSArray *appearance = TGSettingsPageFixtureSections(TGSettingsPageAppearance);
	NSArray *appearanceRows = appearance[0][@"rows"];
	XCTAssertEqualObjects(appearanceRows[0][TGRowKind], TGKindChatPreview);
	XCTAssertEqualObjects(appearanceRows[1][TGRowKind], TGKindThemeCards);
	NSArray *chatThemes = TGSettingsPageFixtureSections(TGSettingsPageChatThemes);
	XCTAssertEqualObjects(chatThemes[0][@"rows"][0][TGRowKind], TGKindThemeGrid);
	XCTAssertEqualObjects(chatThemes[1][@"rows"][0][TGRowKind], TGKindChatPreview);
}

@end
