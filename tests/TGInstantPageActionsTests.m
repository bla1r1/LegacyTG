// TGInstantPageActionsTests.m - what a tap in the Instant View reader does
// (official InstantPageUI: inline buttons, alignment, the feedback row).
#import "TGTestRunner.h"
#import "TGInstantPageActions.h"

@interface TGInstantPageActionsTests : XCTestCase @end

@implementation TGInstantPageActionsTests

- (void)testButtonAction_UrlAndCopy {
	XCTAssertEqualObjects(TGInstantButtonAction(@{ @"type" : @{ @"@type" : @"inlineKeyboardButtonTypeUrl",
			@"url" : @"https://example.com" } }), @"url:https://example.com");
	XCTAssertEqualObjects(TGInstantButtonAction(@{ @"type" : @{ @"@type" : @"inlineKeyboardButtonTypeCopyText",
			@"text" : @"PROMO" } }), @"copy:PROMO");
	XCTAssertNil(TGInstantButtonAction(@{ @"type" : @{ @"@type" : @"inlineKeyboardButtonTypeUser", @"user_id" : @1 } }));
}

- (void)testAlignment {
	XCTAssertEqual(TGInstantAlignment(@{ @"@type" : @"pageBlockHorizontalAlignmentLeft" }), 0);
	XCTAssertEqual(TGInstantAlignment(@{ @"@type" : @"pageBlockHorizontalAlignmentRight" }), 2);
	XCTAssertEqual(TGInstantAlignment(nil), 1);
}

- (void)testFeedbackURL {
	XCTAssertEqualObjects(TGInstantFeedbackURL(@{ @"@type" : @"internalLinkTypeBotStart",
			@"bot_username" : @"previews", @"start_parameter" : @"webpage42", @"autostart" : @NO }),
			@"https://t.me/previews?start=webpage42");
	XCTAssertNil(TGInstantFeedbackURL(@{ @"@type" : @"internalLinkTypePublicChat" }));
}

@end
