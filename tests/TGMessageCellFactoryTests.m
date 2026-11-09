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

@end
