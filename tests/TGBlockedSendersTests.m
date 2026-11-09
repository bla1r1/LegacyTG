//
// TGBlockedSendersTests.m - the blocked list kept "Deleted Account" rows that
// nobody could act on; a deleted user is now told apart from a live one.
//
#import "TGClient+AccountRest.h"

@interface TGBlockedSendersTests : XCTestCase
@end

@implementation TGBlockedSendersTests

- (void)testDeletedUser_IsLeftOut {
	NSDictionary *deleted = @{@"@type" : @"user", @"first_name" : @"",
			@"type" : @{@"@type" : @"userTypeDeleted"}};
	XCTAssertTrue(TGBlockedSenderIsDeleted(deleted));
}

- (void)testLiveUserAndBot_AreKept {
	XCTAssertFalse(TGBlockedSenderIsDeleted(@{@"@type" : @"user",
			@"first_name" : @"Ann", @"type" : @{@"@type" : @"userTypeRegular"}}));
	XCTAssertFalse(TGBlockedSenderIsDeleted(@{@"@type" : @"user",
			@"first_name" : @"Bot", @"type" : @{@"@type" : @"userTypeBot"}}));
}

- (void)testChatAndError_AreKept {
	XCTAssertFalse(TGBlockedSenderIsDeleted(@{@"@type" : @"chat", @"title" : @"Spam"}));
	XCTAssertFalse(TGBlockedSenderIsDeleted(@{@"@type" : @"error"}));
	XCTAssertFalse(TGBlockedSenderIsDeleted(nil));
}

- (void)testName_FromUserRecord {
	XCTAssertEqualObjects(TGBlockedSenderName(@{@"@type" : @"user",
			@"first_name" : @"Ann", @"last_name" : @"Lee"}), @"Ann Lee");
}

@end
