// TGProfileInfoRowsTests.m — the profile card's rows, out of UIKit.
//
// Official draws phone, username, birthday and the long text in that order,
// gives none of them a leading glyph, and keeps the community, the personal
// channel, the linked chat and similar channels out of the info card. These
// are the rules the table reads, so a reload cannot reorder them.
#import "TGTestRunner.h"
#import "TGProfileLogic.h"

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

@end
