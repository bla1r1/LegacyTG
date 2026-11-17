// TGProfileInfoRowsTests.m — the profile card's rows, out of UIKit.
//
// Official draws phone, username, birthday and the long text in that order,
// gives none of them a leading glyph, and keeps the community, the personal
// channel, the linked chat and similar channels out of the info card. These
// are the rules the table reads, so a reload cannot reorder them.
#import "TGTestRunner.h"
#import "TGProfileLogic.h"
#import "TGRows.h"

@interface TGProfileInfoRowsTests : XCTestCase @end

static NSArray *Kinds(NSArray *rows) {
	NSMutableArray *out = [NSMutableArray array];
	for (NSDictionary *row in rows)
		[out addObject:row[@"kind"] ?: @""];
	return out;
}

static NSDictionary *RowOfKind(NSArray *rows, NSString *kind) {
	for (NSDictionary *row in rows)
		if ([row[@"kind"] isEqualToString:kind])
			return row;
	return nil;
}

@implementation TGProfileInfoRowsTests

- (void)testUserRowOrder_PlainRecord {
	NSArray *rows = TGProfileUserInfoRows(@{
		@"phoneNumber"      : @"15551234",
		@"activeUsernames"  : @[@"ada", @"ada_l"],
		@"birthday"         : @"10 December 1815",
		@"bio"              : @"Mathematician",
		@"note"             : @"met in London",
		@"businessLocation" : @"London",
		@"isContact"        : @NO,
		@"isOwnProfile"     : @NO,
		@"isBot"            : @NO,
		@"blocked"          : @NO,
	});
	XCTAssertEqualObjects(Kinds(rows),
			(@[@"phone", @"username", @"birthday", @"bio",
			   @"note", @"businessLocation", @"addContact", @"block"]));
	XCTAssertEqualObjects(RowOfKind(rows, @"username")[@"value"], @"@ada");
	// The other active username was read and dropped; official writes it
	// under the first.
	XCTAssertEqualObjects(RowOfKind(rows, @"username")[@"also"], @"also @ada_l");
	XCTAssertEqualObjects(RowOfKind(rows, @"phone")[@"value"], @"+15551234");
	XCTAssertEqualObjects(RowOfKind(rows, @"birthday")[@"value"], @"10 December 1815");
	XCTAssertEqualObjects(RowOfKind(rows, @"bio")[@"label"], @"Bio");
}

- (void)testUserRowOrder_WarningTakesTheAboutPlaceAfterBirthday {
	NSArray *rows = TGProfileUserInfoRows(@{
		@"phoneNumber" : @"15551234",
		@"birthday"    : @"1 January 2000",
		@"isScam"      : @YES,
		@"isContact"   : @YES,
	});
	NSArray *kinds = Kinds(rows);
	XCTAssertEqualObjects(kinds, (@[@"phone", @"birthday", @"warning"]));
}

- (void)testGroupRowOrder_CommunityLinkedAndSimilarAreNotInfoRows {
	NSArray *rows = TGProfileGroupInfoRows(@{
		@"communityId"          : @(77),
		@"communityName"        : @"Design",
		@"communitySubtitle"    : @"Community with 3 chats",
		@"username"             : @"design_group",
		@"description"          : @"A place to talk",
		@"canManage"            : @YES,
		@"isChannel"            : @NO,
		@"linkedChatTitle"      : @"Design Discussion",
		@"similarChannelsCount" : @(12),
		@"similarChannelsValue" : @"12 channels",
	});
	XCTAssertEqualObjects(Kinds(rows), (@[@"invite", @"about", @"settings"]));
	XCTAssertEqualObjects(RowOfKind(rows, @"invite")[@"label"], @"Link");
	XCTAssertEqualObjects(RowOfKind(rows, @"about")[@"label"], @"Description");
	XCTAssertEqualObjects(RowOfKind(rows, @"settings")[@"label"], @"Group Settings");
	XCTAssertNil(RowOfKind(rows, @"community"));
	XCTAssertNil(RowOfKind(rows, @"linkedChat"));
	XCTAssertNil(RowOfKind(rows, @"similarChannels"));
}

- (void)testChannelRowOrder_HasNoDiscussionOrSimilarRow {
	NSArray *rows = TGProfileGroupInfoRows(@{
		@"inviteLink"           : @"https://t.me/design_channel",
		@"description"          : @"Posts about design",
		@"canManage"            : @YES,
		@"isChannel"            : @YES,
		@"linkedChatTitle"      : @"Design Discussion",
		@"similarChannelsCount" : @(12),
		@"similarChannelsValue" : @"12 channels",
	});
	XCTAssertEqualObjects(Kinds(rows), (@[@"invite", @"about", @"settings"]));
	XCTAssertEqualObjects(RowOfKind(rows, @"invite")[@"value"],
			@"https://t.me/design_channel");
	XCTAssertEqualObjects(RowOfKind(rows, @"settings")[@"label"], @"Channel Settings");
}

- (void)testNoInfoRowKindDrawsALeadingGlyph {
	NSArray *kinds = @[@"phone", @"username", @"birthday", @"bio", @"about",
			@"note", @"invite", @"community", @"linkedChat", @"similarChannels",
			@"directMessages", @"businessLocation", @"addContact", @"warning"];
	for (NSString *kind in kinds)
		XCTAssertNil(TGProfileRowGlyphName(kind), @"%@ must not carry a glyph", kind);
	XCTAssertNil(TGProfileRowGlyphName(@"anything else"));
	XCTAssertNil(TGProfileRowGlyphName(nil));
}

- (void)testDisplayName_UsesTheNameAndFallsBackToPhone {
	XCTAssertEqualObjects(TGProfileDisplayName(
			(@{@"first_name" : @"Ada", @"last_name" : @"Lovelace"}), @""),
			@"Ada Lovelace");
	XCTAssertEqualObjects(TGProfileDisplayName(@{@"last_name" : @"Lovelace"}, @""),
			@"Lovelace");
	XCTAssertEqualObjects(TGProfileDisplayName(@{}, @"15551234"), @"+15551234");
	XCTAssertEqualObjects(TGProfileDisplayName(
			(@{@"phone_number" : @"+15559876"}), @""), @"+15559876");
	XCTAssertEqualObjects(TGProfileDisplayName(@{}, @""), @"");
}

// A bot that works in groups offered no way to add it; a verified bot
// showed nothing of its verifier.
- (void)testBot_AddToGroupOrVerification {
	NSArray *rows = TGProfileUserInfoRows(@{ @"isBot" : @YES, @"botCanJoinGroups" : @YES });
	XCTAssertEqualObjects(RowOfKind(rows, @"addBotToChat")[@"value"], @"Add to Group or Channel");
	rows = TGProfileUserInfoRows(@{ @"isBot" : @YES, @"botCanJoinGroups" : @YES, @"botVerification" : @"Verified by X" });
	XCTAssertNil(RowOfKind(rows, @"addBotToChat"));
	XCTAssertEqualObjects(RowOfKind(rows, @"verification")[@"value"], @"Verified by X");
}


// PeerInfoScreenBusinessHoursItem: status, today's hours or when it opens,
// and the week for the tap.
- (void)testBusinessHours_OpenClosedAndWeek {
	NSDictionary *open = @{@"local_opening_hours" : @{@"time_zone_id" : @"x",
		@"opening_hours" : @[@{@"start_minute" : @(9 * 60), @"end_minute" : @(18 * 60)}]},
		@"next_close_in" : @3600, @"next_open_in" : @80000};
	NSDictionary *row = TGBusinessHoursRow(open, 1763200000);
	XCTAssertEqualObjects(row[@"kind"], @"businessHours");
	XCTAssertTrue([row[@"value"] hasPrefix:@"Open"], @"%@", row[@"value"]);
	XCTAssertTrue([row[@"week"] hasPrefix:@"Monday: 09:00 – 18:00\nTuesday: closed"], @"%@", row[@"week"]);
	NSMutableDictionary *closed = [open mutableCopy];
	closed[@"next_close_in"] = @0;
	closed[@"next_open_in"] = @(2 * 3600 + 30);
	XCTAssertEqualObjects(TGBusinessHoursRow(closed, 1763200000)[@"value"], @"Closed · Opens in 2 hours");
	closed[@"next_open_in"] = @600;
	XCTAssertEqualObjects(TGBusinessHoursRow(closed, 1763200000)[@"value"], @"Closed · Opens in 10 minutes");
	XCTAssertNil(TGBusinessHoursRow(@{}, 0));
}

// Parity: official opens the card of someone on an unofficial client with
// a warning (PeerInfoProfileItems.swift, InfoSection.unofficial).
- (void)testUnofficialApp_WarningComesFirst {
	NSArray *rows = TGProfileUserInfoRows(@{ @"unofficialApp" : @YES, @"name" : @"Ann",
			@"phoneNumber" : @"15551234567" });
	XCTAssertEqualObjects(rows[0][@"kind"], @"unofficial");
	XCTAssertEqualObjects(rows[0][@"value"],
			@"Ann uses an unofficial Telegram client – messages to this user may be less secure.");
	XCTAssertEqualObjects(rows[1][@"kind"], @"phone");
	NSArray *plain = TGProfileUserInfoRows(@{ @"phoneNumber" : @"15551234567" });
	XCTAssertEqualObjects(plain[0][@"kind"], @"phone");
}

// Parity: a bot's open affiliate program, with official's badge and footer
// (PeerInfoProfileItems.swift, botAffiliateProgram).
- (void)testBotAffiliateProgram_RowAndFooter {
	NSArray *rows = TGProfileUserInfoRows(@{ @"isBot" : @YES, @"name" : @"Shop",
			@"affiliatePermille" : @125 });
	NSDictionary *row = RowOfKind(rows, @"affiliate");
	XCTAssertEqualObjects(row[@"value"], @"Affiliate Program");
	XCTAssertEqualObjects(row[@"badge"], @"12.5%");
	XCTAssertEqualObjects(RowOfKind(rows, @"affiliateInfo")[@"value"],
			@"Share a link to Shop with your friends and and earn 12.5% of their spending there.");
	XCTAssertNil(RowOfKind(TGProfileUserInfoRows(@{ @"isBot" : @YES, @"affiliatePermille" : @0 }), @"affiliate"));
	XCTAssertNil(RowOfKind(TGProfileUserInfoRows(@{ @"affiliatePermille" : @100 }), @"affiliate"));
}

- (void)testPermilleText {
	XCTAssertEqualObjects(TGProfilePermilleText(100), @"10");
	XCTAssertEqualObjects(TGProfilePermilleText(125), @"12.5");
	XCTAssertEqualObjects(TGProfilePermilleText(5), @"0.5");
}

// Parity: the bot member's line in the members list.
- (void)testMemberRow_BotAccessSubtitle {
	NSDictionary *reads = TGProfileMemberRowModel(@{ @"id" : @1, @"name" : @"Bot", @"botAccess" : @"reads" }, 0);
	XCTAssertEqualObjects(reads[TGRowDetail], @"has access to messages");
	NSDictionary *blind = TGProfileMemberRowModel(@{ @"id" : @2, @"name" : @"Bot", @"botAccess" : @"noReads" }, 0);
	XCTAssertEqualObjects(blind[TGRowDetail], @"has no access to messages");
	XCTAssertNil(TGProfileMemberRowModel(@{ @"id" : @3, @"name" : @"Ann" }, 0)[TGRowDetail]);
}

@end
