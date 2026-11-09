// TGChatToolsStickerRowsTests.m - the row lists of the settings-shaped screens.
//
// These screens used to decide their rows inside UITableView data source
// methods, where a host test cannot see them. The row titles now come from
// pure functions; these checks pin order, fallbacks and the values that change
// with state.
#import "TGTestRunner.h"

// The host shim stops at UIView. The screen headers below only need their
// controller classes to exist so the pure row models compile here.
@interface UITableViewController : NSObject @end
@interface UITabBarController : NSObject @end
@interface UIViewController : NSObject @end

#import "TGChatToolsViewController.h"
#import "TGDMTopicViewController.h"
#import "TGDMTopicsViewController.h"
#import "TGDiceViewController.h"
#import "TGDevModeViewController.h"
#import "TGStickerPacksViewController.h"
#import "TGRows.h"

@interface TGChatToolsStickerRowsTests : XCTestCase @end

static NSArray *ChatToolsTitles(NSArray *rows) {
	NSMutableArray *titles = [NSMutableArray arrayWithCapacity:rows.count];
	for (NSDictionary *row in rows)
		[titles addObject:row[@"title"]];
	return titles;
}

static NSArray *SBSectionTitles(NSArray *model) {
	NSMutableArray *sections = [NSMutableArray arrayWithCapacity:model.count];
	for (NSDictionary *section in model)
		[sections addObject:ChatToolsTitles(section[@"rows"])];
	return sections;
}

@implementation TGChatToolsStickerRowsTests

- (void)testButtonRowCarriesTheAccessoryTitleAndBothActions {
	__block BOOL rowTapped = NO;
	__block BOOL buttonTapped = NO;
	NSDictionary *row = TGButtonRow(@"Cats", @"2 stickers", @"Archive",
			^{ buttonTapped = YES; }, ^{ rowTapped = YES; });
	XCTAssertEqualObjects(row[TGRowKind], TGKindDisclosure);
	XCTAssertTrue([row[TGRowSubtitle] boolValue]);
	XCTAssertEqualObjects(row[TGRowAccessoryTitle], @"Archive");
	((void (^)(void))row[TGRowAccessoryTap])();
	((void (^)(void))row[TGRowTap])();
	XCTAssertTrue(buttonTapped);
	XCTAssertTrue(rowTapped);
}

- (void)testChatTools_OrderAndStateValues {
	NSArray *model = TGChatToolsSectionsModel(@{
		@"slowMode" : @30,
		@"reactionsAll" : @NO,
		@"protectedContent" : @YES,
		@"translatable" : @NO,
		@"defaultSilent" : @YES,
		@"accentId" : @2,
		@"profileAccentId" : @3,
		@"themeName" : @"🌊",
		@"discussionChatId" : @42,
		@"note" : @"local note",
	});
	XCTAssertEqual(model.count, (NSUInteger)7);
	XCTAssertEqualObjects(model[0][@"header"], @"Channels");
	XCTAssertEqualObjects(SBSectionTitles(model), (@[
		@[@"Suggested Chats"],
		@[@"Slow Mode", @"Available Reactions", @"Restrict Saving Content",
		  @"Translate", @"Send Without Sound"],
		@[@"Accent Color", @"Change Profile Color", @"Color Theme", @"Wallpaper",
		  @"Reset Chat Wallpapers"],
		@[@"Discussion Group", @"Location", @"Local Note",
		  @"Owner After Leaving"],
		@[@"Emoji", @"Report Profile Photo"],
		@[@"Approve", @"Decline All", @"Join Requests"],
		@[@"Add to Folder"],
	]));
	NSArray *moderation = model[1][@"rows"];
	XCTAssertEqualObjects(moderation[0][@"detail"], @"30s");
	XCTAssertEqualObjects(moderation[1][@"detail"], @"Some Reactions");
	XCTAssertEqualObjects(moderation[2][@"on"], @YES);
	XCTAssertEqualObjects(moderation[3][@"on"], @NO);
	XCTAssertEqualObjects(model[3][@"rows"][0][@"detail"], @"Linked");
	XCTAssertEqualObjects(model[3][@"rows"][2][@"detail"], @"local note");
}

- (void)testChatTools_OffAndEmptyStates {
	NSArray *model = TGChatToolsSectionsModel(@{});
	XCTAssertEqualObjects(model[1][@"rows"][0][@"detail"], @"Off");
	XCTAssertEqualObjects(model[1][@"rows"][1][@"detail"], @"Some Reactions");
	XCTAssertEqualObjects(model[3][@"rows"][0][@"detail"], @"None");
	XCTAssertEqualObjects(model[3][@"rows"][2][@"detail"], @"None");
}

- (void)testDMTopic_ActionOrderFollowsTheUnreadMark {
	XCTAssertEqualObjects(TGDMTopicActionTitles(NO), (@[
		@"Mark as Unread", @"Send Message", @"Jump to Date",
		@"Read All Reactions", @"Unpin All Messages", @"Delete Messages",
		@"Delete All Messages",
	]));
	XCTAssertEqualObjects(TGDMTopicActionTitles(YES), (@[
		@"Mark as Read", @"Send Message", @"Jump to Date",
		@"Read All Reactions", @"Unpin All Messages", @"Delete Messages",
		@"Delete All Messages",
	]));
}

- (void)testDMTopic_InfoPairsAndMessageTitles {
	NSArray *pairs = TGDMTopicInfoPairs(@{
		@"senderName" : @"Alice",
		@"unread" : @3,
		@"unreadReactions" : @1,
		@"isMarkedUnread" : @YES,
		@"canSendUnpaid" : @NO,
		@"lastMessage" : @{@"text" : @"hello"},
	});
	NSMutableArray *labels = [NSMutableArray arrayWithCapacity:pairs.count];
	for (NSArray *pair in pairs)
		[labels addObject:pair[0]];
	XCTAssertEqualObjects(labels, (@[
		@"Sender", @"Unread", @"Mark as Unread", @"Paid messages",
		@"Last message",
	]));
	XCTAssertEqualObjects(pairs[1][1], @"3 messages, 1 reactions");
	XCTAssertEqualObjects(pairs[2][1], @"Yes");
	XCTAssertEqualObjects(pairs[3][1], @"Paid only");
	XCTAssertEqualObjects(pairs[4][1], @"hello");
	XCTAssertEqualObjects(TGDMTopicMessageTitle(@{@"kind" : @"messagePhoto"}),
			@"Photo");
	XCTAssertEqualObjects(TGDMTopicMessageTitle(@{@"text" : @"body"}),
			@"body");
}

- (void)testDMTopics_RowTitlesAndUnreadDetail {
	NSArray *models = TGDMTopicsRowModels(@[
		@{@"senderName" : @"Alice", @"lastMessage" : @{@"text" : @"hi"},
		  @"unread" : @2},
		@{@"senderName" : @"", @"isMarkedUnread" : @YES},
	]);
	XCTAssertEqualObjects(ChatToolsTitles(models), (@[@"Alice", @"Topic"]));
	XCTAssertEqualObjects(models[0][@"detail"], @"2 unread messages · hi");
	XCTAssertEqualObjects(models[1][@"detail"],
			@"Unread · No messages here yet...");
	XCTAssertNil(TGDMTopicsFooter(YES, 2));
	XCTAssertEqualObjects(TGDMTopicsFooter(NO, 0), @"Loading...");
	XCTAssertEqualObjects(TGDMTopicsFooter(YES, 0), @"No topics here yet");
}

- (void)testDice_StatusSuggestedAndPrizeRows {
	NSArray *status = TGDiceStatusRows(@{
		@"stateHash" : @"abc",
		@"stakeGramAmount" : @5000000000,
		@"currentStreak" : @2,
		@"streakPrizePerMille" : @25,
	}, 77);
	XCTAssertEqualObjects(ChatToolsTitles(status), (@[
		@"State hash", @"Last stake", @"Current streak", @"Streak prize",
		@"Chat",
	]));
	XCTAssertEqualObjects(status[1][@"detail"], @"5.0000 TON");
	XCTAssertEqualObjects(status[2][@"detail"], @"2 of 3");
	XCTAssertEqualObjects(status[4][@"detail"], @"77");

	NSArray *suggested = TGDiceSuggestedRows(@[@(1000000000), @(2500000000)]);
	XCTAssertEqualObjects(ChatToolsTitles(suggested), (@[@"1.0000 TON",
			@"2.5000 TON"]));
	NSArray *prizes = TGDicePrizeRows(@[@(10), @(20)]);
	XCTAssertEqualObjects(ChatToolsTitles(prizes), (@[@"Face 1", @"Face 2"]));
	XCTAssertEqualObjects(prizes[1][@"detail"], @"20 per 1000 staked");
}

- (void)testDevChats_RowTitlesFollowTheFixtureList {
	XCTAssertEqualObjects(TGDevChatRowTitles(@[
		@{@"title" : @"Saved Messages"}, @{@"title" : @"Design"},
	]), (@[@"Saved Messages", @"Design"]));
	XCTAssertEqualObjects(TGDevChatRowTitles(@[]), @[]);
}

- (void)testStickerPacks_EmptySectionsKeepTheirPlaceholder {
	NSArray *titles = TGStickerPacksRowTitles(@[], @[], @[], @[], @[]);
	XCTAssertEqual(titles.count, (NSUInteger)7);
	XCTAssertEqualObjects(titles[0], (@[@"New Sticker Set",
			@"Search Stickers", @"Clear Recent Stickers"]));
	XCTAssertEqualObjects(titles[1], (@[@"No Stickers Found"]));
	XCTAssertEqualObjects(titles[2], (@[@"No Results"]));
	XCTAssertEqualObjects(titles[3], (@[@"Add Icons To Profile",
			@"Add Icons To Replies", @"Background Emoji", @"Search Emoji"]));
	XCTAssertEqualObjects(titles[4], (@[@"Stickers"]));
	XCTAssertEqualObjects(titles[5], (@[@"Recently Used", @"Favorites"]));
	XCTAssertEqualObjects(titles[6], (@[@"No Results"]));
}

- (void)testStickerPacks_OwnedAndArchivedRowsUseTheServerFallbacks {
	NSArray *owned = @[
		@{@"title" : @"Cats", @"shortName" : @"cats", @"count" : @2,
		  @"stickerType" : @"stickerTypeRegular"},
		@{@"shortName" : @"dogs", @"count" : @1,
		  @"stickerType" : @"stickerTypeMask"},
	];
	NSArray *archived = @[@{@"title" : @"Old", @"shortName" : @"old",
			@"count" : @4}];
	NSArray *titles = TGStickerPacksRowTitles(owned, @[], archived, @[@{}],
			@[]);
	XCTAssertEqualObjects(titles[1], (@[@"Cats", @"Stickers"]));
	XCTAssertEqualObjects(titles[6], (@[@"Old"]));
	XCTAssertEqualObjects(TGStickerPackOwnedDetail(owned[0]),
			@"cats  ·  2 stickers  ·  regular");
	XCTAssertEqualObjects(TGStickerPackOwnedDetail(owned[1]),
			@"dogs  ·  1 sticker  ·  masks");
	XCTAssertEqualObjects(TGStickerPackArchivedDetail(archived[0]),
			@"old  ·  4 stickers");
	XCTAssertEqualObjects(TGStickerPacksShelfDetail(@[@{}]),
			@"1 sticker");
	XCTAssertEqualObjects(TGStickerPacksShelfDetail(@[]), @"No Results");
}

@end
