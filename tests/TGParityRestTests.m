// TGParityRestTests.m - the QR payload parser the Rest group's parity work
// depends on: a post link must resolve to its chat, a login token to a token.
#import "TGTestRunner.h"
#import "TGQRCodeLink.h"
#import "TGPhoneNumberRules.h"
#import "TGLocalization.h"
#import "TGStoryText.h"
#import "TGStorySave.h"
#import "TGStarsTransactionText.h"
#import "TGGiftText.h"

@interface TGParityRestTests : XCTestCase @end
@implementation TGParityRestTests
/// A QR payload is either a chat link or a login token. A post link names the
/// chat, so the post id must not leak into the username - the old parser stopped
/// only at ? and #, turning t.me/name/123 into the nonexistent name/123.
- (void)testQRCodeUsernameTakesTheFirstPathComponent {
	XCTAssertEqualObjects(TGQRCodeUsername(@"t.me/name"), @"name");
	XCTAssertEqualObjects(TGQRCodeUsername(@"https://t.me/name"), @"name");
	XCTAssertEqualObjects(TGQRCodeUsername(@"t.me/name/123"), @"name");
	XCTAssertEqualObjects(TGQRCodeUsername(@"https://t.me/name/123?single"), @"name");
	XCTAssertEqualObjects(TGQRCodeUsername(@"tg://resolve?domain=name&post=123"), @"name");
	XCTAssertNil(TGQRCodeUsername(@"tg://login?token=abc"));
	XCTAssertNil(TGQRCodeUsername(@"not a link"));
	XCTAssertNil(TGQRCodeUsername(nil));
}

- (void)testQRCodeLoginTokenIsRecognised {
	XCTAssertTrue(TGQRCodeIsAuthTransferLink(@"tg://login?token=abc"));
	XCTAssertEqualObjects(TGQRCodeAuthToken(@"tg://login?token=abc"), @"abc");
	XCTAssertEqualObjects(TGQRCodeAuthToken(@"tg://login?token=abc&x=1"), @"abc");
	XCTAssertFalse(TGQRCodeIsAuthTransferLink(@"t.me/name"));
	XCTAssertNil(TGQRCodeAuthToken(@"t.me/name"));
}

/// The device and network country lookups race. A late device answer must not
/// replace the network's prefix, and a request from an earlier phone step must
/// not write into the current one.
- (void)testCountryGuessOnlyTheNetworkMayReplaceTheDevice {
	// Current request, nothing applied yet: both may answer.
	XCTAssertTrue(TGCountryGuessCanApply(4, 4, NO, NO, NO));
	XCTAssertTrue(TGCountryGuessCanApply(4, 4, NO, NO, YES));
	// The network already won: a device answer that lands later is ignored.
	XCTAssertFalse(TGCountryGuessCanApply(4, 4, NO, YES, NO));
	XCTAssertTrue(TGCountryGuessCanApply(4, 4, NO, YES, YES));
	// An answer from the previous phone step is stale.
	XCTAssertFalse(TGCountryGuessCanApply(3, 4, NO, NO, YES));
	// A typed prefix is never overwritten.
	XCTAssertFalse(TGCountryGuessCanApply(4, 4, YES, NO, YES));
}

/// The story info sheet shows nouns, not TDLib state names. Closing friends,
/// selected users and an unknown raw value, then the three interaction kinds.
- (void)testStoryInfoPrivacyAndInteractionNouns {
	XCTAssertEqualObjects(TGStoryPrivacyNoun(@"closeFriends"),
			TGLocalized(@"Close Friends"));
	XCTAssertEqualObjects(TGStoryPrivacyNoun(@"selected"),
			TGLocalized(@"Selected Users"));
	XCTAssertEqualObjects(TGStoryPrivacyNoun(@"contacts"),
			TGLocalized(@"My Contacts"));
	XCTAssertEqualObjects(TGStoryPrivacyNoun(@"nobody"), @"nobody");
	XCTAssertEqualObjects(TGStoryPrivacyNoun(nil), @"-");

	XCTAssertEqualObjects(TGStoryInteractionNoun(@"view"),
			TGLocalized(@"View"));
	XCTAssertEqualObjects(TGStoryInteractionNoun(@"forward"),
			TGLocalized(@"Forwarded Messages"));
	XCTAssertEqualObjects(TGStoryInteractionNoun(@"repost"),
			TGLocalized(@"Forwarded Messages"));
}

/// Saving a video story must save the movie file, not its poster frame.
- (void)testStorySaveUsesTheVideoFileForAVideoStory {
	NSNumber *fileId = nil;
	TGStorySaveKind kind = TGStorySaveKindForStory(
			@{@"videoId" : @(70), @"photoId" : @(90)}, &fileId);
	XCTAssertEqual(kind, TGStorySaveKindVideo);
	XCTAssertEqualObjects(fileId, @(70));

	fileId = nil;
	kind = TGStorySaveKindForStory(@{@"photoId" : @(90)}, &fileId);
	XCTAssertEqual(kind, TGStorySaveKindPhoto);
	XCTAssertEqualObjects(fileId, @(90));

	fileId = nil;
	kind = TGStorySaveKindForStory(@{@"thumbPhotoId" : @(91)}, &fileId);
	XCTAssertEqual(kind, TGStorySaveKindPhoto);
	XCTAssertEqualObjects(fileId, @(91));
}

/// A sale is income, a purchase is spending, and a refund says so. The old
/// line printed all three as the same positive "N Stars" with a raw type.
- (void)testStarsTransactionRowsKeepTheSignAndRefund {
	NSDictionary *sale = TGStarsTransactionRow(@{
		@"type" : @"giftSale", @"starCount" : @(25),
		@"dateText" : @"1 Jan",
	});
	XCTAssertEqualObjects(sale[@"title"], TGLocalized(@"Gift Sale"));
	XCTAssertTrue([sale[@"amount"] hasPrefix:@"+"]);
	XCTAssertFalse([sale[@"isOutgoing"] boolValue]);

	// TDLib signs star_amount: spending arrives negative.
	NSDictionary *purchase = TGStarsTransactionRow(@{
		@"type" : @"giftPurchase", @"starCount" : @(-25),
	});
	XCTAssertEqualObjects(purchase[@"title"], TGLocalized(@"Gift Purchase"));
	XCTAssertTrue([purchase[@"amount"] hasPrefix:@"-"]);
	XCTAssertFalse([purchase[@"amount"] hasPrefix:@"--"]);
	XCTAssertTrue([purchase[@"isOutgoing"] boolValue]);

	NSDictionary *refund = TGStarsTransactionRow(@{
		@"type" : @"giftPurchase", @"starCount" : @(25),
		@"isRefund" : @YES,
	});
	XCTAssertEqualObjects(refund[@"title"], TGLocalized(@"Refund"));
	XCTAssertTrue([refund[@"isRefund"] boolValue]);
	XCTAssertTrue([refund[@"amount"] hasPrefix:@"+"]);
}

/// A unique gift's Value comes from its fiat amount and currency, never from
/// sell_star_count; without both fields the row is dropped.
- (void)testGiftValueUsesTheFiatAmountAndDropsWithoutIt {
	NSDictionary *priced = @{
		@"valueAmount" : @(1234), @"valueCurrency" : @"USD",
		@"sellStarCount" : @(900),
	};
	XCTAssertTrue(TGGiftHasValue(priced));
	XCTAssertEqualObjects(TGGiftValueText(priced), @"$12.34");

	XCTAssertFalse(TGGiftHasValue(@{@"sellStarCount" : @(900)}));
	XCTAssertNil(TGGiftValueText(@{@"sellStarCount" : @(900)}));
	XCTAssertFalse(TGGiftHasValue(@{@"valueAmount" : @(12)}));
	XCTAssertNil(TGGiftValueText(@{@"valueAmount" : @(12)}));
	XCTAssertFalse(TGGiftHasValue(@{@"valueCurrency" : @"USD"}));
	XCTAssertNil(TGGiftValueText(@{@"valueCurrency" : @"USD"}));

	XCTAssertEqualObjects(TGGiftSenderText(@"Ann"), @"from Ann");
	TGSetTelegramLanguageLookup(@{@"from %@" : @"%@", @"From" : @"Из",
			@"@@Gift.View.From" : @"От"});
	NSString *russian = TGGiftSenderText(@"Ann");
	TGSetTelegramLanguageLookup(nil);
	XCTAssertEqualObjects(russian, @"от Ann");
	XCTAssertNil(TGGiftSenderText(nil));
}

@end
