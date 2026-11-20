//
// TGChatListRowGeometryTests.m - the trailing edge of a chat row.
//
// A pinned chat with unread messages used to lose one of its two marks: the
// cell put the count where the pin went and hid the pin when a count existed.
// The official row keeps both, so this pins the arithmetic before TGChatCell
// draws it. UIKit cannot answer the cell's own frames on this host; the pure
// helper can.
//
#import "TGTestRunner.h"
#import "TGChatListRowGeometry.h"
#include <math.h>

@interface TGChatListRowGeometryTests : XCTestCase
@end

@implementation TGChatListRowGeometryTests

static const CGFloat kRight = 320.0f;
static const CGFloat kTop = 42.0f;
static const CGFloat kBadgeW = 30.0f;
static const CGFloat kBadgeH = 18.0f;
static const CGFloat kPin = 16.0f;
static const CGFloat kGap = 8.0f;

/// The launch snapshot keeps the preview's custom emoji, so the first paint
/// can show pictures already on disk instead of the fallback characters.
- (void)testSnapshotKeepsPreviewCustomEmojiAsNumbers {
	NSArray *kept = TGSnapshotCustomEmoji(@[
		@{@"offset" : @0, @"length" : @2, @"customEmojiId" : @"5206607081334906820"},
		@[@2, @2, @5206607081334906820LL],
		@{@"offset" : @4, @"length" : @2},
		@"junk",
	]);
	XCTAssertEqual(kept.count, (NSUInteger)2);
	XCTAssertEqualObjects(kept[0][@"customEmojiId"], @5206607081334906820LL);
	XCTAssertEqualObjects(kept[1][@"offset"], @2);
	XCTAssertNil(TGSnapshotCustomEmoji(@"not an array"));
	XCTAssertTrue([NSPropertyListSerialization propertyList:kept
			isValidForFormat:NSPropertyListXMLFormat_v1_0]);
}

- (void)testPinnedUnreadRowKeepsBothMarksAndTheyDoNotOverlap {
	CGRect badge = CGRectZero, pin = CGRectZero;
	CGFloat previewRight = 0;
	TGChatListRowAccessories(kRight, kTop, YES, kBadgeW, kBadgeH,
			YES, kPin, kGap, &badge, &pin, &previewRight);

	XCTAssertTrue(fabs(CGRectGetMaxX(badge) - kRight) < 0.01,
			@"the unread count keeps the corner");
	XCTAssertTrue(fabs(CGRectGetMidY(pin) - CGRectGetMidY(badge)) < 0.01,
			@"the pin sits on the same line as the count");
	XCTAssertLessThanOrEqual(CGRectGetMaxX(pin), CGRectGetMinX(badge),
			@"the pin must be beside the count, not under it");
	XCTAssertLessThanOrEqual(previewRight, CGRectGetMinX(pin),
			@"the preview must stop before the first mark");
}

- (void)testPinnedRowWithoutUnreadPutsThePinAtTheEdge {
	CGRect badge = CGRectZero, pin = CGRectZero;
	CGFloat previewRight = 0;
	TGChatListRowAccessories(kRight, kTop, NO, 0, kBadgeH,
			YES, kPin, kGap, &badge, &pin, &previewRight);

	XCTAssertTrue(CGRectIsEmpty(badge), @"no count, no badge");
	XCTAssertTrue(fabs(CGRectGetMaxX(pin) - kRight) < 0.01);
	XCTAssertLessThanOrEqual(previewRight, CGRectGetMinX(pin));
}

- (void)testUnreadRowWithoutPinPutsTheBadgeAtTheEdge {
	CGRect badge = CGRectZero, pin = CGRectZero;
	CGFloat previewRight = 0;
	TGChatListRowAccessories(kRight, kTop, YES, kBadgeW, kBadgeH,
			NO, kPin, kGap, &badge, &pin, &previewRight);

	XCTAssertTrue(fabs(CGRectGetMaxX(badge) - kRight) < 0.01);
	XCTAssertTrue(CGRectIsEmpty(pin), @"no pin, no pin frame");
	XCTAssertTrue(fabs(previewRight - (CGRectGetMinX(badge) - kGap)) < 0.01);
}

- (void)testPlainRowUsesTheWholeLine {
	CGRect badge = CGRectZero, pin = CGRectZero;
	CGFloat previewRight = 0;
	TGChatListRowAccessories(kRight, kTop, NO, 0, kBadgeH,
			NO, kPin, kGap, &badge, &pin, &previewRight);

	XCTAssertTrue(CGRectIsEmpty(badge));
	XCTAssertTrue(CGRectIsEmpty(pin));
	XCTAssertTrue(fabs(previewRight - kRight) < 0.01,
			@"an unpinned, read row must not reserve room for either mark");
}

- (void)testZeroFlagsTolerateNilOutPointers {
	XCTAssertNoThrow(TGChatListRowAccessories(kRight, kTop, NO, 0, kBadgeH,
			NO, kPin, kGap, NULL, NULL, NULL),
			@"callers that only want the preview edge must not need three locals");
}

- (void)testArchiveSubtitleIsSingularForOneChat {
	XCTAssertEqualObjects(TGChatListArchiveSubtitle(1), @"1 chat");
	XCTAssertEqualObjects(TGChatListArchiveSubtitle(2), @"2 chats");
	XCTAssertEqualObjects(TGChatListArchiveSubtitle(0), @"0 chats");
}

- (void)testAvatarWindow_CoversTheScreenAndNotTheWholeList {
	NSRange top = TGAvatarWindow(0, 14, 176);
	XCTAssertEqual(top.location, (NSUInteger)0);
	XCTAssertEqual(top.length, (NSUInteger)14);
	NSRange middle = TGAvatarWindow(50, 14, 176);
	XCTAssertEqual(middle.location, (NSUInteger)49);
	XCTAssertEqual(middle.length, (NSUInteger)14);
}

- (void)testAvatarWindow_StopsAtTheEndOfTheList {
	NSRange end = TGAvatarWindow(170, 14, 176);
	XCTAssertEqual(end.location, (NSUInteger)169);
	XCTAssertEqual(end.length, (NSUInteger)7);
	NSRange past = TGAvatarWindow(500, 14, 176);
	XCTAssertEqual(past.length, (NSUInteger)0);
	XCTAssertEqual(TGAvatarWindow(0, 14, 0).length, (NSUInteger)0);
}

// Official ChatListNoticeItem: the password notice first and without a
// close button, the Premium one closable and opening TDLib's page.
- (void)testNotice_FromSuggestedActions {
	XCTAssertNil(TGChatListNotice(@[]));
	NSDictionary *premium = @{ @"action" : @{ @"@type" : @"suggestedActionExtendPremium",
			@"manage_premium_subscription_url" : @"https://t.me/premium" } };
	NSDictionary *password = @{ @"action" : @{ @"@type" : @"suggestedActionSetPassword", @"authorization_delay" : @7 } };
	NSDictionary *notice = TGChatListNotice(@[premium]);
	XCTAssertEqualObjects(notice[@"kind"], @"premiumGrace");
	XCTAssertEqualObjects(notice[@"url"], @"https://t.me/premium");
	XCTAssertTrue([notice[@"closable"] boolValue]);
	notice = TGChatListNotice(@[premium, password]);
	XCTAssertEqualObjects(notice[@"kind"], @"setupPassword");
	XCTAssertFalse([notice[@"closable"] boolValue]);
	XCTAssertEqualObjects(notice[@"title"], @"Protect Your Account");
}

- (void)testSwipeGestureShouldBegin_RejectsVerticalAndAcceptsHorizontal {
	// Zero translation and zero velocity -> rejected
	XCTAssertFalse(TGChatListSwipeGestureShouldBegin(CGPointZero, CGPointZero));
	// Zero translation but vertical velocity -> rejected
	XCTAssertFalse(TGChatListSwipeGestureShouldBegin(CGPointZero, CGPointMake(20.0f, 250.0f)));
	// Zero translation but strong horizontal velocity -> accepted
	XCTAssertTrue(TGChatListSwipeGestureShouldBegin(CGPointZero, CGPointMake(300.0f, 20.0f)));
	// Flatter than tall horizontal delta -> accepted
	XCTAssertTrue(TGChatListSwipeGestureShouldBegin(CGPointMake(25.0f, 5.0f), CGPointZero));
	XCTAssertTrue(TGChatListSwipeGestureShouldBegin(CGPointMake(-40.0f, 10.0f), CGPointZero));
	// Taller than flat delta -> rejected
	XCTAssertFalse(TGChatListSwipeGestureShouldBegin(CGPointMake(5.0f, 30.0f), CGPointZero));
	XCTAssertFalse(TGChatListSwipeGestureShouldBegin(CGPointMake(0.0f, 15.0f), CGPointZero));
}

- (void)testTouchInsideActionButton_DistinguishesButtonSubviewsFromContentView {
	UIView *cell = [UIView new];
	UIView *contentView = [UIView new];
	[cell addSubview:contentView];

	UILabel *titleLabel = [UILabel new];
	[contentView addSubview:titleLabel];

	UIButton *actionButton = [UIButton new];
	[cell addSubview:actionButton];

	UILabel *buttonTitle = [UILabel new];
	[actionButton addSubview:buttonTitle];

	// Direct button hit -> YES
	XCTAssertTrue(TGChatListIsTouchInsideActionButton(actionButton, contentView));
	// Subview of button (e.g. titleLabel of UIButton) -> YES
	XCTAssertTrue(TGChatListIsTouchInsideActionButton(buttonTitle, contentView));
	// Subview inside cell contentView -> NO
	XCTAssertFalse(TGChatListIsTouchInsideActionButton(titleLabel, contentView));
	// Cell background itself -> NO
	XCTAssertFalse(TGChatListIsTouchInsideActionButton(cell, contentView));
	// Nil view -> NO
	XCTAssertFalse(TGChatListIsTouchInsideActionButton(nil, contentView));
}

- (void)testSafeEmojiFallback_MapsModernEmojisToIOS6Equivalents {
	// Emojis from user bug report (custom emojis with modern fallback)
	XCTAssertEqualObjects(TGChatListSafeEmojiFallback(@"🥳"), @"🎉");
	XCTAssertEqualObjects(TGChatListSafeEmojiFallback(@"🥺"), @"😊");
	XCTAssertEqualObjects(TGChatListSafeEmojiFallback(@"🥑"), @"🍏");
	XCTAssertEqualObjects(TGChatListSafeEmojiFallback(@"🦖"), @"🐊");

	// Empty string
	XCTAssertEqualObjects(TGChatListSafeEmojiFallback(@""), @"");

	// Unmapped modern emoji falls back to ✨ instead of tofu
	XCTAssertEqualObjects(TGChatListSafeEmojiFallback(@"🪅"), @"✨");
}

@end
