// TGMessageCellFactoryTests.m - the message element family's choice.
//
// The message list is its own table, not TGRows: a row is a message. The
// factory therefore picks an element (bubble, service plate, day header,
// unread band) from the resolved layout flags. The choice is pure, so it is
// pinned here without a live table.
#import "TGTestRunner.h"
#import "TGMessageCellFactory.h"
#import "TGMessageLayout.h"

@interface TGMessageCellFactoryTests : XCTestCase @end

@implementation TGMessageCellFactoryTests

- (TGMessageLayout *)layout {
	return [[TGMessageLayout alloc] init];
}

- (void)testTextFixtureIsABubble {
	NSDictionary *message = @{@"kind" : @"messageText", @"text" : @"Hello"};
	TGMessageLayout *layout = [self layout];
	XCTAssertEqual(TGMessageCellKindForMessage(message, layout),
			TGMessageCellKindBubble);
	XCTAssertEqualObjects(TGMessageCellReuseIdentifierForKind(
			TGMessageCellKindBubble), @"TGBubbleCell");
}

- (void)testMediaFixtureKeepsTheBubbleElement {
	NSDictionary *message = @{@"kind" : @"messagePhoto",
			@"photoId" : @(42)};
	TGMessageLayout *layout = [self layout];
	XCTAssertEqual(TGMessageCellKindForMessage(message, layout),
			TGMessageCellKindBubble);
}

- (void)testServiceFixturePicksTheServiceElement {
	NSDictionary *message = @{@"service" : @YES,
			@"text" : @"Pinned a message"};
	TGMessageLayout *layout = [self layout];
	layout.isService = YES;
	XCTAssertEqual(TGMessageCellKindForMessage(message, layout),
			TGMessageCellKindService);
	XCTAssertEqualObjects(TGMessageCellReuseIdentifierForKind(
			TGMessageCellKindService), @"TGMessageServiceCell");
}

- (void)testDateHeaderFixturePicksTheDayElement {
	NSDictionary *message = @{@"service" : @YES, @"separator" : @"day",
			@"text" : @"Today"};
	TGMessageLayout *layout = [self layout];
	layout.isService = YES;
	layout.isDateHeader = YES;
	XCTAssertEqual(TGMessageCellKindForMessage(message, layout),
			TGMessageCellKindDateHeader);
	XCTAssertEqualObjects(TGMessageCellReuseIdentifierForKind(
			TGMessageCellKindDateHeader), @"TGMessageDateHeaderCell");
}

- (void)testUnreadFixturePicksTheSeparatorElement {
	NSDictionary *message = @{@"service" : @YES, @"separator" : @"unread",
			@"text" : @"Unread Messages"};
	TGMessageLayout *layout = [self layout];
	layout.isService = YES;
	layout.isUnreadSeparator = YES;
	XCTAssertEqual(TGMessageCellKindForMessage(message, layout),
			TGMessageCellKindUnreadSeparator);
	XCTAssertEqualObjects(TGMessageCellReuseIdentifierForKind(
			TGMessageCellKindUnreadSeparator),
			@"TGMessageUnreadSeparatorCell");
}

/// A card that arrived as a service update is still a bubble: the layout
/// resolves that, and the factory must not read the raw service flag.
- (void)testCardServiceUpdateStaysABubble {
	NSDictionary *message = @{@"service" : @YES, @"kind" : @"messageInvoice"};
	TGMessageLayout *layout = [self layout];
	layout.isService = NO;
	layout.isCard = YES;
	XCTAssertEqual(TGMessageCellKindForMessage(message, layout),
			TGMessageCellKindBubble);
}

/// The same custom emoji three times in a row has equal attributes, so
/// CoreText hands it back as one run. On iOS 6 that drew one picture in the
/// middle of the three.
- (void)testCustomEmojiRects_RepeatedEmojiGetsOneRectEach {
	NSMutableAttributedString *text = [[NSMutableAttributedString alloc]
			initWithString:@"\u2003\u2003\u2003"
				attributes:@{@"TGCustomEmojiId" : @(77), @"TGCustomEmojiSide" : @(17)}];
	[text appendAttributedString:[[NSAttributedString alloc] initWithString:@"\u2003"
			attributes:@{@"TGCustomEmojiId" : @(78), @"TGCustomEmojiSide" : @(17)}]];

	NSArray *rects = TGCustomEmojiRectsCoreText(text, 200);

	XCTAssertEqual(rects.count, (NSUInteger)4);
	CGFloat lastX = -CGFLOAT_MAX;
	for (NSDictionary *entry in rects) {
		CGRect rect = CGRectZero;
		[entry[@"rect"] getValue:&rect];
		XCTAssertTrue(rect.origin.x > lastX, @"each emoji sits to the right of the one before");
		// Snapped outward to whole points, so 17 or 18.
		XCTAssertTrue(rect.size.width >= 17 && rect.size.width <= 18);
		lastX = rect.origin.x;
	}
	XCTAssertEqualObjects([rects.lastObject objectForKey:@"id"], @(78));
}

@end
