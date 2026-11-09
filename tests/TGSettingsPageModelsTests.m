// TGSettingsPageModelsTests.m — the pages that are built from plain data.
//
// Power Saving, Folders and Proxy used to grow rows in the view controller,
// where a host test cannot reach them. These checks pin what official shows:
// the Options header, one add-folder row, and no proxy carrier console.
#import "TGTestRunner.h"
#import "TGSettingsPageModels.h"
#import "TGSettingsFormatting.h"

@interface TGSettingsPageModelsTests : XCTestCase @end

@implementation TGSettingsPageModelsTests

- (NSArray *)rowsInSection:(NSDictionary *)section {
	return section[TGPageModelRows];
}

- (NSArray *)titlesInSection:(NSDictionary *)section {
	NSMutableArray *titles = [NSMutableArray array];
	for (NSDictionary *row in section[TGPageModelRows])
		[titles addObject:row[TGPageModelRowTitle]];
	return titles;
}

- (void)testPowerSaving_OptionsHeaderIsNotThePollString {
	NSArray *model = TGPowerSavingPageModel(YES, YES, NO);
	XCTAssertEqual(model.count, (NSUInteger)1);
	NSDictionary *section = model[0];
	XCTAssertEqualObjects(section[TGPageModelHeader], @"Options");
	XCTAssertNil(section[TGPageModelFooter]);

	// "OPTIONS" is the poll answer key and became "ВАРИАНТЫ ОТВЕТА";
	// "Options" is the Power Saving section and is "Настройки".
	TGSetTelegramLanguageLookup(@{@"Options" : @"Настройки"});
	XCTAssertEqualObjects(TGSettingsHeaderText(section[TGPageModelHeader]),
			@"НАСТРОЙКИ");
	TGSetTelegramLanguageLookup(nil);
}

- (void)testPowerSaving_RowsFollowTheOfficialOrder {
	NSArray *model = TGPowerSavingPageModel(YES, NO, YES);
	NSArray *titles = [self titlesInSection:model[0]];
	XCTAssertEqualObjects(titles, (@[@"Autoplay GIFs",
			@"Loop Animated Stickers", @"Chat Wallpaper"]));
	// Every row is a switch with an icon: a section may not mix both shapes.
	for (NSDictionary *row in [self rowsInSection:model[0]]){
		XCTAssertEqualObjects(row[TGPageModelRowKind], @"switchinfo");
		XCTAssertNotNil(row[TGPageModelRowIcon]);
		XCTAssertNotNil(row[TGPageModelRowOn]);
	}
	XCTAssertEqualObjects([self rowsInSection:model[0]][0][TGPageModelRowOn],
			@(NO));
}

- (void)testFolders_OneAddRowAndTheEditFooter {
	NSArray *folders = @[
		@{@"id" : @(1), @"title" : @"News"},
		@{@"id" : @(2), @"title" : @"Work"},
	];
	NSArray *model = TGFoldersPageModel(folders, @[], @{@(1) : @(7)},
			YES, NO);
	NSDictionary *section = model[0];
	XCTAssertEqualObjects(section[TGPageModelHeader], @"Folders");
	XCTAssertEqualObjects(section[TGPageModelFooter],
			@"Tap 'Edit' to change the order or delete folders.");

	NSArray *titles = [self titlesInSection:section];
	XCTAssertEqualObjects(titles, (@[@"Create New Folder", @"News",
			@"Work"]));
	XCTAssertEqual([titles indexOfObject:@"Create New Folder"], (NSUInteger)0);
	XCTAssertEqual([titles indexOfObject:@"Add Folder"], NSNotFound);
	// The tag switch is its own section, after the list.
	XCTAssertEqual(model.count, (NSUInteger)2);
	XCTAssertEqualObjects([self titlesInSection:model[1]],
			(@[@"Show Folder Tags"]));
	// The folder count stays on the right, and a zero count is blank.
	NSArray *rows = [self rowsInSection:section];
	XCTAssertEqualObjects(rows[1][TGPageModelRowDetail], @"7");
}

- (void)testFolders_DevBuildKeepsTheInviteRow {
	NSArray *model = TGFoldersPageModel(@[], @[], @{}, YES, YES);
	NSArray *titles = [self titlesInSection:model[0]];
	XCTAssertEqualObjects(titles, (@[@"Create New Folder", @"Add Folder"]));
	XCTAssertEqual([titles indexOfObject:@"Add Folder"], (NSUInteger)1);
}

- (void)testProxy_AddProxyComesBeforeSavedServers {
	NSArray *proxies = @[
		@{@"id" : @(1), @"server" : @"1.2.3.4", @"port" : @(1080),
		  @"kind" : @"socks5", @"enabled" : @YES},
		@{@"id" : @(2), @"server" : @"5.6.7.8", @"port" : @(1081),
		  @"kind" : @"mtproto", @"enabled" : @NO},
	];
	NSArray *model = TGProxyPageModel(proxies, YES, YES, NO);
	XCTAssertEqual(model.count, (NSUInteger)2);
	XCTAssertEqualObjects([self titlesInSection:model[0]], (@[@"Use Proxy"]));
	XCTAssertEqualObjects(model[1][TGPageModelHeader], @"Saved Proxies");
	XCTAssertEqualObjects([self titlesInSection:model[1]],
			(@[@"Add Proxy", @"1.2.3.4:1080", @"5.6.7.8:1081"]));
	XCTAssertNil(model[1][TGPageModelFooter]);
}

- (void)testProxy_ReleaseHasNoCarrierConsole {
	NSArray *model = TGProxyPageModel(@[], NO, NO, NO);
	for (NSDictionary *section in model){
		NSString *header = section[TGPageModelHeader] ?: @"";
		XCTAssertFalse([header rangeOfString:@"WEB PROXY CARRIER"].location !=
				NSNotFound);
		for (NSString *title in [self titlesInSection:section])
			XCTAssertFalse([title rangeOfString:@"Web Proxy Carrier"].location !=
					NSNotFound);
	}
	// Even a dev state does not put the console back into the proxy list.
	NSArray *devModel = TGProxyPageModel(@[], NO, NO, YES);
	for (NSDictionary *section in devModel)
		XCTAssertFalse([(section[TGPageModelHeader] ?: @"")
				rangeOfString:@"CARRIER"].location != NSNotFound);
}

- (void)testCompactBytes_DropsTheZeroFraction {
	NSString *text = TGPageModelCompactBytes(120LL * 1024 * 1024);
	XCTAssertTrue([text hasPrefix:@"120 "]);
	XCTAssertFalse([text rangeOfString:@",0"].location != NSNotFound);
	XCTAssertFalse([text rangeOfString:@".0"].location != NSNotFound);
}

@end
