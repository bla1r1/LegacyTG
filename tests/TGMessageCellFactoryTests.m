// TGMessageCellFactoryTests.m - the message element family's choice.
//
// The message list is its own table, not TGRows: a row is a message. The
// factory therefore picks an element (bubble, service plate, day header,
// unread band) from the resolved layout flags. The choice is pure, so it is
// pinned here without a live table.
#import "TGTestRunner.h"
#import <CoreText/CoreText.h>
#import "TGMessageCellFactory.h"
#import "TGMessageLayout.h"

@interface TGMessageCellFactoryTests : XCTestCase @end

@interface TGFakeUIFont : NSObject
@property (nonatomic, readonly) NSString *fontName;
@property (nonatomic, readonly) CGFloat pointSize;
@end
@implementation TGFakeUIFont
- (NSString *)fontName { return @"Helvetica"; }
- (CGFloat)pointSize { return 19; }
@end

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

/// iOS 6's UIFont is not a CTFont, and CoreText ignored it: the emoji rects
/// came from a 12 pt layout of 13 pt text. A stand-in with a UIFont's
/// fontName and pointSize plays that UIFont here, where NSFont is bridged.
- (void)testCoreTextFonts_TurnsAForeignFontIntoACTFont {
	TGFakeUIFont *fake = [[TGFakeUIFont alloc] init];
	NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:@"ab cd"];
	[text addAttribute:NSFontAttributeName value:fake range:NSMakeRange(0, 2)];
	NSAttributedString *out = TGCoreTextFonts(text);
	id font = [out attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
	XCTAssertTrue(font && CFGetTypeID((__bridge CFTypeRef)font) == CTFontGetTypeID());
	XCTAssertEqual(CTFontGetSize((__bridge CTFontRef)font), (CGFloat)19);
	XCTAssertNil([out attribute:NSFontAttributeName atIndex:3 effectiveRange:NULL]);
	NSAttributedString *plain = [[NSAttributedString alloc] initWithString:@"x"];
	XCTAssertTrue(TGCoreTextFonts(plain) == plain);
}

/// The iOS 6 stand-in for a custom emoji is no space: UIKit hung a space at
/// a line's end past the margin while CoreText wrapped it, and every emoji
/// after it in Paul Durov's posts drew a line low on the iPod touch 4.
- (void)testCustomEmojiSpacer_IsNotWhitespace {
	UIFont *font = TGFontAtSize(13);
	NSAttributedString *spacer = TGCustomEmojiSpacer(42, font);
	XCTAssertEqual(spacer.length, (NSUInteger)1);
	unichar c = [spacer.string characterAtIndex:0];
	XCTAssertFalse([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:c]);
	XCTAssertEqualObjects([spacer attribute:@"TGCustomEmojiId" atIndex:0 effectiveRange:NULL], @42);
	NSMutableAttributedString *line = [[NSMutableAttributedString alloc] initWithString:@"aaaa "
			attributes:@{ NSFontAttributeName : font }];
	[line appendAttributedString:spacer];
	XCTAssertEqual(TGCustomEmojiRectsCoreText(line, 200).count, (NSUInteger)1);
}

/// A bubble's pool follows what it shows, so its cells keep the same views.
- (void)testBubblePool_ByWhatTheRowShows {
	TGMessageLayout *text = [[TGMessageLayout alloc] init];
	XCTAssertEqualObjects(TGBubbleReuseIdentifier(text), @"TGBubbleCell.text");
	TGMessageLayout *photo = [[TGMessageLayout alloc] init];
	photo.pictureFrame = CGRectMake(0, 0, 200, 150);
	XCTAssertEqualObjects(TGBubbleReuseIdentifier(photo), @"TGBubbleCell.media");
	TGMessageLayout *voice = [[TGMessageLayout alloc] init];
	voice.isVoice = YES;
	XCTAssertEqualObjects(TGBubbleReuseIdentifier(voice), @"TGBubbleCell.audio");
	TGMessageLayout *round = [[TGMessageLayout alloc] init];
	round.isRound = YES;
	round.pictureFrame = CGRectMake(0, 0, 200, 200);
	XCTAssertEqualObjects(TGBubbleReuseIdentifier(round), @"TGBubbleCell.sticker");
	TGMessageLayout *poll = [[TGMessageLayout alloc] init];
	poll.isPoll = YES;
	XCTAssertEqualObjects(TGBubbleReuseIdentifier(poll), @"TGBubbleCell.card");
}

@end
