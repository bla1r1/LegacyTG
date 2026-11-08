// TGPollPresentationTests.m - Telegram's poll wording and marks, pinned.
//
// The chat draws these strings and dots in a bubble; getting a word or a mark
// wrong is only visible on a device, so the pure functions are tested here.
#import "TGTestRunner.h"
#import "TGPollPresentation.h"

@interface TGPollPresentationTests : XCTestCase
@end

static NSDictionary *ppPoll(BOOL closed, BOOL quiz, BOOL anonymous,
		BOOL multiple, NSArray *options, long long total) {
	return @{
		@"isClosed"      : @(closed),
		@"isQuiz"        : @(quiz),
		@"isAnonymous"   : @(anonymous),
		@"allowsMultiple": @(multiple),
		@"options"       : options ?: @[],
		@"totalVoterCount": @(total),
	};
}

static NSDictionary *ppChosenOption(void) {
	return @{@"isChosen" : @YES, @"percent" : @60};
}

static NSDictionary *ppOtherOption(void) {
	return @{@"isChosen" : @NO, @"percent" : @40};
}

@implementation TGPollPresentationTests

#pragma mark - kind line

- (void)testKindLine_ClosedIsFinalResults {
	NSDictionary *poll = ppPoll(YES, YES, YES, NO, @[], 3);
	XCTAssertEqualObjects(TGPollKindLine(poll), @"Final results");
}

- (void)testKindLine_AnonymousQuiz {
	NSDictionary *poll = ppPoll(NO, YES, YES, NO, @[], 0);
	XCTAssertEqualObjects(TGPollKindLine(poll), @"Anonymous Quiz");
}

- (void)testKindLine_PublicQuiz {
	NSDictionary *poll = ppPoll(NO, YES, NO, NO, @[], 0);
	XCTAssertEqualObjects(TGPollKindLine(poll), @"Quiz");
}

- (void)testKindLine_AnonymousPoll {
	NSDictionary *poll = ppPoll(NO, NO, YES, NO, @[], 0);
	XCTAssertEqualObjects(TGPollKindLine(poll), @"Anonymous Poll");
}

- (void)testKindLine_PublicPoll {
	NSDictionary *poll = ppPoll(NO, NO, NO, NO, @[], 0);
	XCTAssertEqualObjects(TGPollKindLine(poll), @"Poll");
}

#pragma mark - votes line

- (void)testVotesLine_QuizNone {
	XCTAssertEqualObjects(TGPollVotesLine(ppPoll(NO, YES, YES, NO, @[], 0)),
			@"Nobody answered yet");
}

- (void)testVotesLine_QuizOne {
	XCTAssertEqualObjects(TGPollVotesLine(ppPoll(NO, YES, YES, NO, @[], 1)),
			@"1 answered");
}

- (void)testVotesLine_QuizMany {
	XCTAssertEqualObjects(TGPollVotesLine(ppPoll(NO, YES, YES, NO, @[], 7)),
			@"7 answered");
}

- (void)testVotesLine_PollNone {
	XCTAssertEqualObjects(TGPollVotesLine(ppPoll(NO, NO, YES, NO, @[], 0)),
			@"No votes");
}

- (void)testVotesLine_PollOne {
	XCTAssertEqualObjects(TGPollVotesLine(ppPoll(NO, NO, YES, NO, @[], 1)),
			@"1 vote");
}

- (void)testVotesLine_PollMany {
	XCTAssertEqualObjects(TGPollVotesLine(ppPoll(NO, NO, YES, NO, @[], 12)),
			@"12 votes");
}

#pragma mark - closing line

- (void)testClosesLine_MinutesAndSeconds {
	NSDictionary *poll = @{@"isClosed" : @NO, @"closeDate" : @300};
	XCTAssertEqualObjects(TGPollClosesLine(poll, 1), @"ends in 4:59");
}

- (void)testClosesLine_Hours {
	NSDictionary *poll = @{@"isClosed" : @NO, @"closeDate" : @3601};
	XCTAssertEqualObjects(TGPollClosesLine(poll, 1), @"ends in 1:00:00");
}

- (void)testClosesLine_Days {
	NSDictionary *poll = @{@"isClosed" : @NO, @"closeDate" : @(86400 * 3 + 1)};
	XCTAssertEqualObjects(TGPollClosesLine(poll, 1), @"ends in 3 days");
}

- (void)testClosesLine_NilWhenClosed {
	NSDictionary *poll = @{@"isClosed" : @YES, @"closeDate" : @300};
	XCTAssertTrue(TGPollClosesLine(poll, 1) == nil);
}

- (void)testClosesLine_NilWhenUnscheduled {
	NSDictionary *poll = @{@"isClosed" : @NO, @"closeDate" : @0};
	XCTAssertTrue(TGPollClosesLine(poll, 1) == nil);
}

- (void)testClosesLine_NilWhenPast {
	NSDictionary *poll = @{@"isClosed" : @NO, @"closeDate" : @100};
	XCTAssertTrue(TGPollClosesLine(poll, 100) == nil);
	XCTAssertTrue(TGPollClosesLine(poll, 101) == nil);
}

#pragma mark - results visibility

- (void)testShowsResults_ClosedAlways {
	XCTAssertTrue(TGPollShowsResults(ppPoll(YES, NO, YES, NO,
			@[ppOtherOption()], 4)));
}

- (void)testShowsResults_ChosenOption {
	XCTAssertTrue(TGPollShowsResults(ppPoll(NO, NO, YES, NO,
			@[ppChosenOption(), ppOtherOption()], 4)));
}

- (void)testShowsResults_HiddenBeforeVote {
	XCTAssertFalse(TGPollShowsResults(ppPoll(NO, NO, YES, NO,
			@[ppOtherOption(), ppOtherOption()], 0)));
}

#pragma mark - option marks

- (void)testMarkForOption_HiddenBeforeVote {
	NSDictionary *poll = ppPoll(NO, NO, YES, NO,
			@[ppOtherOption(), ppOtherOption()], 0);
	XCTAssertEqual(TGPollMarkForOption(poll, 0), TGPollMarkNone);
}

- (void)testMarkForOption_QuizCorrect {
	NSDictionary *poll = ppPoll(YES, YES, NO, NO,
			@[ppOtherOption(), ppChosenOption()], 4);
	NSMutableDictionary *withCorrect = [poll mutableCopy];
	withCorrect[@"correctOption"] = @1;
	XCTAssertEqual(TGPollMarkForOption(withCorrect, 1), TGPollMarkCorrect);
}

- (void)testMarkForOption_QuizWrong {
	NSDictionary *poll = ppPoll(YES, YES, NO, NO,
			@[ppChosenOption(), ppOtherOption()], 4);
	NSMutableDictionary *withCorrect = [poll mutableCopy];
	withCorrect[@"correctOption"] = @1;
	XCTAssertEqual(TGPollMarkForOption(withCorrect, 0), TGPollMarkWrong);
}

- (void)testMarkForOption_QuizUnchosen {
	NSDictionary *poll = ppPoll(YES, YES, NO, NO,
			@[ppOtherOption(), ppChosenOption()], 4);
	NSMutableDictionary *withCorrect = [poll mutableCopy];
	withCorrect[@"correctOption"] = @1;
	XCTAssertEqual(TGPollMarkForOption(withCorrect, 0), TGPollMarkNone);
}

- (void)testMarkForOption_PollChosen {
	NSDictionary *poll = ppPoll(NO, NO, YES, NO,
			@[ppChosenOption(), ppOtherOption()], 4);
	XCTAssertEqual(TGPollMarkForOption(poll, 0), TGPollMarkChosen);
}

- (void)testMarkForOption_PollUnchosen {
	NSDictionary *poll = ppPoll(NO, NO, YES, NO,
			@[ppChosenOption(), ppOtherOption()], 4);
	XCTAssertEqual(TGPollMarkForOption(poll, 1), TGPollMarkNone);
}

- (void)testMarkForOption_OutOfRange {
	NSDictionary *poll = ppPoll(NO, NO, YES, NO,
			@[ppChosenOption()], 4);
	XCTAssertEqual(TGPollMarkForOption(poll, 9), TGPollMarkNone);
}

#pragma mark - pending answers

- (void)testVoteIndexes_Sorted {
	NSMutableIndexSet *pending = [NSMutableIndexSet indexSet];
	[pending addIndex:4];
	[pending addIndex:1];
	[pending addIndex:2];
	NSArray *indexes = TGPollVoteIndexes(pending);
	XCTAssertEqual(indexes.count, (NSUInteger)3);
	XCTAssertEqual([indexes[0] unsignedIntegerValue], (NSUInteger)1);
	XCTAssertEqual([indexes[1] unsignedIntegerValue], (NSUInteger)2);
	XCTAssertEqual([indexes[2] unsignedIntegerValue], (NSUInteger)4);
}

- (void)testVoteIndexes_EmptySet {
	XCTAssertEqual(TGPollVoteIndexes([NSIndexSet indexSet]).count, (NSUInteger)0);
}

- (void)testVoteIndexes_Nil {
	XCTAssertEqual(TGPollVoteIndexes(nil).count, (NSUInteger)0);
}

#pragma mark - retracting

- (void)testCanRetract_WhenAllowed {
	NSDictionary *poll = ppPoll(NO, NO, YES, NO,
			@[ppChosenOption(), ppOtherOption()], 4);
	NSMutableDictionary *revoting = [poll mutableCopy];
	revoting[@"allowsRevoting"] = @YES;
	XCTAssertTrue(TGPollCanRetract(revoting));
}

- (void)testCanRetract_RevotingOff {
	NSDictionary *poll = ppPoll(NO, NO, YES, NO,
			@[ppChosenOption(), ppOtherOption()], 4);
	NSMutableDictionary *fixed = [poll mutableCopy];
	fixed[@"allowsRevoting"] = @NO;
	XCTAssertFalse(TGPollCanRetract(fixed));
}

- (void)testCanRetract_NotVoted {
	NSDictionary *poll = ppPoll(NO, NO, YES, NO,
			@[ppOtherOption(), ppOtherOption()], 0);
	NSMutableDictionary *revoting = [poll mutableCopy];
	revoting[@"allowsRevoting"] = @YES;
	XCTAssertFalse(TGPollCanRetract(revoting));
}

- (void)testCanRetract_Quiz {
	NSDictionary *poll = ppPoll(NO, YES, YES, NO,
			@[ppChosenOption(), ppOtherOption()], 4);
	NSMutableDictionary *revoting = [poll mutableCopy];
	revoting[@"allowsRevoting"] = @YES;
	XCTAssertFalse(TGPollCanRetract(revoting));
}

- (void)testCanRetract_Closed {
	NSDictionary *poll = ppPoll(YES, NO, YES, NO,
			@[ppChosenOption(), ppOtherOption()], 4);
	NSMutableDictionary *revoting = [poll mutableCopy];
	revoting[@"allowsRevoting"] = @YES;
	XCTAssertFalse(TGPollCanRetract(revoting));
}

@end
