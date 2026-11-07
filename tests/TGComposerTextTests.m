//
// TGComposerTextTests.m - unit tests for composer text and custom emoji model.
//
#import "TGTestRunner.h"
#import "TGComposerText.h"

@interface TGComposerTextTests : XCTestCase @end

static NSDictionary *ctEmojiEntity(NSInteger offset, NSInteger length, id customEmojiId) {
	return @{
		@"@type"  : @"textEntity",
		@"offset" : @(offset),
		@"length" : @(length),
		@"type"   : @{
			@"@type"           : @"textEntityTypeCustomEmoji",
			@"custom_emoji_id" : customEmojiId,
		},
	};
}

static NSDictionary *ctBoldEntity(NSInteger offset, NSInteger length) {
	return @{
		@"@type"  : @"textEntity",
		@"offset" : @(offset),
		@"length" : @(length),
		@"type"   : @{
			@"@type" : @"textEntityTypeBold",
		},
	};
}

@implementation TGComposerTextTests

- (void)testInit_NilTextYieldsEmptyString {
	TGComposerText *c = [[TGComposerText alloc] initWithText:nil entities:nil];
	XCTAssertEqualObjects(c.text, @"");
	XCTAssertEqual(c.customEmoji.count, 0U);
}

- (void)testInit_EmptyEntitiesList {
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"hello" entities:@[]];
	XCTAssertEqualObjects(c.text, @"hello");
	XCTAssertEqual(c.customEmoji.count, 0U);
}

- (void)testInit_ValidCustomEmojiEntity {
	NSArray *ents = @[ctEmojiEntity(6, 2, @(123456789LL))];
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"hello 😀 world" entities:ents];
	XCTAssertEqual(c.customEmoji.count, 1U);
	NSDictionary *e = c.customEmoji[0];
	XCTAssertEqualObjects(e[@"offset"], @(6));
	XCTAssertEqualObjects(e[@"length"], @(2));
	XCTAssertEqualObjects(e[@"customEmojiId"], @(123456789LL));
}

- (void)testInit_CustomEmojiIdAsString {
	NSArray *ents = @[ctEmojiEntity(0, 2, @"9876543210123")];
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"😀 hello" entities:ents];
	XCTAssertEqual(c.customEmoji.count, 1U);
	NSDictionary *e = c.customEmoji[0];
	XCTAssertEqualObjects(e[@"customEmojiId"], @(9876543210123LL));
}

- (void)testInit_IgnoresNonCustomEmojiEntities {
	NSArray *ents = @[ctBoldEntity(0, 5), ctEmojiEntity(6, 2, @(555))];
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"hello 😀" entities:ents];
	XCTAssertEqual(c.customEmoji.count, 1U);
	XCTAssertEqualObjects(c.customEmoji[0][@"customEmojiId"], @(555));
}

- (void)testInit_IgnoresNullAndGarbageEntities {
	NSArray *ents = @[[NSNull null], @"garbage", @{}, @{@"type": [NSNull null]}, ctEmojiEntity(0, 2, @(111))];
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"😀" entities:ents];
	XCTAssertEqual(c.customEmoji.count, 1U);
	XCTAssertEqualObjects(c.customEmoji[0][@"customEmojiId"], @(111));
}

- (void)testInit_IgnoresNegativeOffset {
	NSArray *ents = @[ctEmojiEntity(-1, 2, @(111))];
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"😀" entities:ents];
	XCTAssertEqual(c.customEmoji.count, 0U);
}

- (void)testInit_IgnoresZeroOrNegativeLength {
	NSArray *ents = @[ctEmojiEntity(0, 0, @(111)), ctEmojiEntity(0, -2, @(222))];
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"😀" entities:ents];
	XCTAssertEqual(c.customEmoji.count, 0U);
}

- (void)testInit_IgnoresEntityExceedingTextBounds {
	NSArray *ents = @[ctEmojiEntity(0, 10, @(111))];
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"short" entities:ents];
	XCTAssertEqual(c.customEmoji.count, 0U);
}

- (void)testInit_SortsEntitiesByOffset {
	NSArray *ents = @[ctEmojiEntity(8, 2, @(222)), ctEmojiEntity(0, 2, @(111))];
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"😀 hello 😀" entities:ents];
	XCTAssertEqual(c.customEmoji.count, 2U);
	XCTAssertEqualObjects(c.customEmoji[0][@"offset"], @(0));
	XCTAssertEqualObjects(c.customEmoji[1][@"offset"], @(8));
}

- (void)testInit_IgnoresOverlappingEntities {
	NSArray *ents = @[ctEmojiEntity(0, 4, @(111)), ctEmojiEntity(2, 2, @(222))];
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"12345" entities:ents];
	XCTAssertEqual(c.customEmoji.count, 1U);
	XCTAssertEqualObjects(c.customEmoji[0][@"customEmojiId"], @(111));
}

- (void)testReplace_InsertBeforeEntityShiftsOffset {
	NSArray *ents = @[ctEmojiEntity(5, 2, @(100))];
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"hello😀" entities:ents];
	[c replaceCharactersInRange:NSMakeRange(0, 0) withString:@"abc"];
	XCTAssertEqualObjects(c.text, @"abchello😀");
	XCTAssertEqual(c.customEmoji.count, 1U);
	XCTAssertEqualObjects(c.customEmoji[0][@"offset"], @(8));
}

- (void)testReplace_InsertAtEntityStartBoundaryShiftsOffset {
	NSArray *ents = @[ctEmojiEntity(5, 2, @(100))];
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"hello😀" entities:ents];
	[c replaceCharactersInRange:NSMakeRange(5, 0) withString:@"!"];
	XCTAssertEqualObjects(c.text, @"hello!😀");
	XCTAssertEqual(c.customEmoji.count, 1U);
	XCTAssertEqualObjects(c.customEmoji[0][@"offset"], @(6));
}

- (void)testReplace_InsertInsideEntityDropsIt {
	NSArray *ents = @[ctEmojiEntity(5, 2, @(100))];
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"hello😀" entities:ents];
	[c replaceCharactersInRange:NSMakeRange(6, 0) withString:@"X"];
	XCTAssertEqual(c.customEmoji.count, 0U);
}

- (void)testReplace_InsertAtEntityEndBoundaryKeepsOffset {
	NSArray *ents = @[ctEmojiEntity(5, 2, @(100))];
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"hello😀" entities:ents];
	[c replaceCharactersInRange:NSMakeRange(7, 0) withString:@"!"];
	XCTAssertEqualObjects(c.text, @"hello😀!");
	XCTAssertEqual(c.customEmoji.count, 1U);
	XCTAssertEqualObjects(c.customEmoji[0][@"offset"], @(5));
}

- (void)testReplace_InsertAfterEntityKeepsOffset {
	NSArray *ents = @[ctEmojiEntity(0, 2, @(100))];
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"😀world" entities:ents];
	[c replaceCharactersInRange:NSMakeRange(7, 0) withString:@"!"];
	XCTAssertEqualObjects(c.text, @"😀world!");
	XCTAssertEqual(c.customEmoji.count, 1U);
	XCTAssertEqualObjects(c.customEmoji[0][@"offset"], @(0));
}

- (void)testReplace_InsertPastEndClampsToEnd {
	NSArray *ents = @[ctEmojiEntity(0, 2, @(100))];
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"😀" entities:ents];
	[c replaceCharactersInRange:NSMakeRange(100, 0) withString:@"!"];
	XCTAssertEqualObjects(c.text, @"😀!");
	XCTAssertEqual(c.customEmoji.count, 1U);
	XCTAssertEqualObjects(c.customEmoji[0][@"offset"], @(0));
}

- (void)testReplace_EmptyStringDoesNotChangeOffset {
	NSArray *ents = @[ctEmojiEntity(5, 2, @(100))];
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"hello😀" entities:ents];
	[c replaceCharactersInRange:NSMakeRange(2, 0) withString:@""];
	XCTAssertEqualObjects(c.text, @"hello😀");
	XCTAssertEqual(c.customEmoji.count, 1U);
	XCTAssertEqualObjects(c.customEmoji[0][@"offset"], @(5));
}

- (void)testDelete_StrictlyBeforeEntityShiftsOffset {
	NSArray *ents = @[ctEmojiEntity(5, 2, @(100))];
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"hello😀" entities:ents];
	[c replaceCharactersInRange:NSMakeRange(0, 2) withString:@""];
	XCTAssertEqualObjects(c.text, @"llo😀");
	XCTAssertEqual(c.customEmoji.count, 1U);
	XCTAssertEqualObjects(c.customEmoji[0][@"offset"], @(3));
}

- (void)testDelete_TouchingFirstUnitDropsEntity {
	NSArray *ents = @[ctEmojiEntity(5, 2, @(100))];
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"hello😀" entities:ents];
	[c replaceCharactersInRange:NSMakeRange(5, 1) withString:@""];
	XCTAssertEqual(c.customEmoji.count, 0U);
}

- (void)testDelete_TouchingLastUnitDropsEntity {
	NSArray *ents = @[ctEmojiEntity(5, 2, @(100))];
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"hello😀" entities:ents];
	[c replaceCharactersInRange:NSMakeRange(6, 1) withString:@""];
	XCTAssertEqual(c.customEmoji.count, 0U);
}

- (void)testDelete_TouchingBeforeAndFirstUnitDropsEntity {
	NSArray *ents = @[ctEmojiEntity(5, 2, @(100))];
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"hello😀" entities:ents];
	[c replaceCharactersInRange:NSMakeRange(4, 2) withString:@""];
	XCTAssertEqual(c.customEmoji.count, 0U);
}

- (void)testDelete_StrictlyAfterEntityLeavesOffsetIntact {
	NSArray *ents = @[ctEmojiEntity(0, 2, @(100))];
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"😀world" entities:ents];
	[c replaceCharactersInRange:NSMakeRange(2, 5) withString:@""];
	XCTAssertEqualObjects(c.text, @"😀");
	XCTAssertEqual(c.customEmoji.count, 1U);
	XCTAssertEqualObjects(c.customEmoji[0][@"offset"], @(0));
}

- (void)testReplace_AcrossTwoEntitiesDropsBoth {
	NSArray *ents = @[ctEmojiEntity(2, 2, @(100)), ctEmojiEntity(6, 2, @(200))];
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"aa😀bb😀cc" entities:ents];
	[c replaceCharactersInRange:NSMakeRange(3, 4) withString:@"xxx"];
	XCTAssertEqual(c.customEmoji.count, 0U);
}

- (void)testReplace_SpanningIntoEntityFromBeforeDropsIt {
	NSArray *ents = @[ctEmojiEntity(5, 2, @(100))];
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"hello😀" entities:ents];
	[c replaceCharactersInRange:NSMakeRange(3, 3) withString:@"foo"];
	XCTAssertEqual(c.customEmoji.count, 0U);
}

- (void)testReplace_SpanningFromInsideEntityToAfterDropsIt {
	NSArray *ents = @[ctEmojiEntity(5, 2, @(100))];
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"hello😀world" entities:ents];
	[c replaceCharactersInRange:NSMakeRange(6, 3) withString:@"foo"];
	XCTAssertEqual(c.customEmoji.count, 0U);
}

- (void)testReplace_EntireTextDropsAllEntities {
	NSArray *ents = @[ctEmojiEntity(0, 2, @(100)), ctEmojiEntity(4, 2, @(200))];
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"😀  😀" entities:ents];
	[c replaceCharactersInRange:NSMakeRange(0, 6) withString:@"clear"];
	XCTAssertEqualObjects(c.text, @"clear");
	XCTAssertEqual(c.customEmoji.count, 0U);
}

- (void)testReplace_RangePastEndClampsToEnd {
	NSArray *ents = @[ctEmojiEntity(0, 2, @(100))];
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"😀" entities:ents];
	[c replaceCharactersInRange:NSMakeRange(10, 5) withString:@"end"];
	XCTAssertEqualObjects(c.text, @"😀end");
	XCTAssertEqual(c.customEmoji.count, 1U);
}

- (void)testReplace_RangeLengthExtendingPastEndClamps {
	NSArray *ents = @[ctEmojiEntity(0, 2, @(100))];
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"😀hello" entities:ents];
	[c replaceCharactersInRange:NSMakeRange(2, 50) withString:@"world"];
	XCTAssertEqualObjects(c.text, @"😀world");
	XCTAssertEqual(c.customEmoji.count, 1U);
	XCTAssertEqualObjects(c.customEmoji[0][@"offset"], @(0));
}

- (void)testInsertCustomEmoji_StandardEmoji {
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"hello" entities:@[]];
	[c insertCustomEmoji:123 fallback:@"A" atIndex:5];
	XCTAssertEqualObjects(c.text, @"helloA");
	XCTAssertEqual(c.customEmoji.count, 1U);
	XCTAssertEqualObjects(c.customEmoji[0][@"offset"], @(5));
	XCTAssertEqualObjects(c.customEmoji[0][@"length"], @(1));
	XCTAssertEqualObjects(c.customEmoji[0][@"customEmojiId"], @(123));
}

- (void)testInsertCustomEmoji_SurrogatePairFallback {
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"msg: " entities:@[]];
	[c insertCustomEmoji:999 fallback:@"😀" atIndex:5];
	XCTAssertEqualObjects(c.text, @"msg: 😀");
	XCTAssertEqual(c.customEmoji.count, 1U);
	XCTAssertEqualObjects(c.customEmoji[0][@"length"], @(2));
	XCTAssertEqualObjects(c.customEmoji[0][@"offset"], @(5));
}

- (void)testInsertCustomEmoji_FlagEmojiFallback {
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"flag " entities:@[]];
	[c insertCustomEmoji:777 fallback:@"🇨🇦" atIndex:5];
	XCTAssertEqualObjects(c.text, @"flag 🇨🇦");
	XCTAssertEqual(c.customEmoji.count, 1U);
	XCTAssertEqualObjects(c.customEmoji[0][@"length"], @(4));
	XCTAssertEqualObjects(c.customEmoji[0][@"offset"], @(5));
}

- (void)testInsertCustomEmoji_AtBeginningShiftsExisting {
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"world" entities:@[]];
	[c insertCustomEmoji:200 fallback:@"😀" atIndex:5];
	[c insertCustomEmoji:100 fallback:@"😀" atIndex:0];
	XCTAssertEqualObjects(c.text, @"😀world😀");
	XCTAssertEqual(c.customEmoji.count, 2U);
	XCTAssertEqualObjects(c.customEmoji[0][@"offset"], @(0));
	XCTAssertEqualObjects(c.customEmoji[0][@"customEmojiId"], @(100));
	XCTAssertEqualObjects(c.customEmoji[1][@"offset"], @(7));
	XCTAssertEqualObjects(c.customEmoji[1][@"customEmojiId"], @(200));
}

- (void)testInsertCustomEmoji_PastEndClampsToEnd {
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"hi" entities:@[]];
	[c insertCustomEmoji:555 fallback:@"😀" atIndex:99];
	XCTAssertEqualObjects(c.text, @"hi😀");
	XCTAssertEqual(c.customEmoji.count, 1U);
	XCTAssertEqualObjects(c.customEmoji[0][@"offset"], @(2));
}

- (void)testInsertCustomEmoji_InsideExistingDropsExisting {
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"a😀b" entities:@[ctEmojiEntity(1, 2, @(100))]];
	[c insertCustomEmoji:200 fallback:@"😀" atIndex:2];
	XCTAssertEqual(c.customEmoji.count, 1U);
	XCTAssertEqualObjects(c.customEmoji[0][@"customEmojiId"], @(200));
}

- (void)testResetText_KeepsEntityWhenSubstringUnchanged {
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"hello 😀 world" entities:@[ctEmojiEntity(6, 2, @(123))]];
	[c resetText:@"hi... 😀 world"];
	XCTAssertEqual(c.customEmoji.count, 1U);
	XCTAssertEqualObjects(c.customEmoji[0][@"customEmojiId"], @(123));
	XCTAssertEqualObjects(c.customEmoji[0][@"offset"], @(6));
}

- (void)testResetText_DropsEntityWhenSubstringChanged {
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"hello 😀 world" entities:@[ctEmojiEntity(6, 2, @(123))]];
	[c resetText:@"hello 😁 world"];
	XCTAssertEqual(c.customEmoji.count, 0U);
}

- (void)testResetText_DropsEntityWhenTextTruncated {
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"hello 😀 world" entities:@[ctEmojiEntity(6, 2, @(123))]];
	[c resetText:@"short"];
	XCTAssertEqual(c.customEmoji.count, 0U);
	XCTAssertEqualObjects(c.text, @"short");
}

- (void)testResetText_NilTextResetsToEmpty {
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"hello 😀" entities:@[ctEmojiEntity(6, 2, @(123))]];
	[c resetText:nil];
	XCTAssertEqualObjects(c.text, @"");
	XCTAssertEqual(c.customEmoji.count, 0U);
}

- (void)testFormattedText_TrimsLeadingWhitespaceAndShiftsOffsets {
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"   hello 😀" entities:@[ctEmojiEntity(9, 2, @(777))]];
	NSDictionary *f = [c formattedText];
	XCTAssertEqualObjects(f[@"@type"], @"formattedText");
	XCTAssertEqualObjects(f[@"text"], @"hello 😀");
	NSArray *ents = f[@"entities"];
	XCTAssertEqual(ents.count, 1U);
	XCTAssertEqualObjects(ents[0][@"offset"], @(6));
	XCTAssertEqualObjects(ents[0][@"length"], @(2));
	XCTAssertEqualObjects(ents[0][@"type"][@"custom_emoji_id"], @(777));
}

- (void)testFormattedText_TrimsTrailingWhitespace {
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"hello 😀   \n\t" entities:@[ctEmojiEntity(6, 2, @(777))]];
	NSDictionary *f = [c formattedText];
	XCTAssertEqualObjects(f[@"text"], @"hello 😀");
	NSArray *ents = f[@"entities"];
	XCTAssertEqual(ents.count, 1U);
	XCTAssertEqualObjects(ents[0][@"offset"], @(6));
}

- (void)testFormattedText_DropsEntitiesInLeadingTrimmedWhitespace {
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"   😀" entities:@[ctEmojiEntity(0, 1, @(111)), ctEmojiEntity(3, 2, @(222))]];
	NSDictionary *f = [c formattedText];
	XCTAssertEqualObjects(f[@"text"], @"😀");
	NSArray *ents = f[@"entities"];
	XCTAssertEqual(ents.count, 1U);
	XCTAssertTrue(ents[0][@"custom_emoji_id"] == nil);
	XCTAssertEqualObjects(ents[0][@"type"][@"custom_emoji_id"], @(222));
	XCTAssertEqualObjects(ents[0][@"offset"], @(0));
}

- (void)testFormattedText_DropsEntitiesInTrailingTrimmedWhitespace {
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"😀   " entities:@[ctEmojiEntity(0, 2, @(222)), ctEmojiEntity(3, 1, @(333))]];
	NSDictionary *f = [c formattedText];
	XCTAssertEqualObjects(f[@"text"], @"😀");
	NSArray *ents = f[@"entities"];
	XCTAssertEqual(ents.count, 1U);
	XCTAssertEqualObjects(ents[0][@"type"][@"custom_emoji_id"], @(222));
}

- (void)testFormattedText_WhitespaceOnlyTextYieldsEmpty {
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"   \n\t  " entities:@[]];
	NSDictionary *f = [c formattedText];
	XCTAssertEqualObjects(f[@"@type"], @"formattedText");
	XCTAssertEqualObjects(f[@"text"], @"");
	XCTAssertEqual([f[@"entities"] count], 0U);
}

- (void)testFormattedText_TDLibShapeVerified {
	TGComposerText *c = [[TGComposerText alloc] initWithText:@"😀" entities:@[ctEmojiEntity(0, 2, @"8888888888888")]];
	NSDictionary *f = [c formattedText];
	NSArray *ents = f[@"entities"];
	XCTAssertEqual(ents.count, 1U);
	NSDictionary *ent = ents[0];
	XCTAssertEqualObjects(ent[@"@type"], @"textEntity");
	XCTAssertEqualObjects(ent[@"offset"], @(0));
	XCTAssertEqualObjects(ent[@"length"], @(2));
	NSDictionary *type = ent[@"type"];
	XCTAssertEqualObjects(type[@"@type"], @"textEntityTypeCustomEmoji");
	XCTAssertEqualObjects(type[@"custom_emoji_id"], @(8888888888888LL));
	XCTAssertTrue([type[@"custom_emoji_id"] isKindOfClass:[NSNumber class]]);
}

@end
