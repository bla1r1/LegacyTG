// TGParityChatTests.m - chat-area parity with the official client, pinned.
//
// These are the pure presentation helpers behind the screens the Chat group
// owns; a wording or plural regression is otherwise only visible on a device.
#import "TGTestRunner.h"
#import "TGLocalization.h"
#import "TGPollPresentation.h"
#import "TGChatParityModel.h"
#import "TGChatActionMenuModel.h"
#import "TGClientNotifications.h"

static TGChatActionMenuContext TGMenuContext(BOOL mine, BOOL group, BOOL channel) {
	TGChatActionMenuContext context = {0};
	context.mine = mine;
	context.isGroup = group;
	context.isChannel = channel;
	context.canReply = YES;
	context.canEdit = YES;
	context.canPin = YES;
	context.canTranslate = YES;
	context.canSpeak = YES;
	context.canSelect = YES;
	context.canReport = !mine;
	return context;
}

static NSArray *TGMenuActions(NSDictionary *message, TGChatActionMenuContext context) {
	NSMutableArray *actions = [NSMutableArray array];
	for (NSDictionary *row in TGChatActionMenuRows(message, context))
		[actions addObject:row[@"action"] ?: @""];
	return actions;
}

@interface TGParityChatTests : XCTestCase
@end

@implementation TGParityChatTests

- (void)testPollKindIsPollNotPublicPoll {
	NSDictionary *poll = @{
		@"isClosed" : @NO, @"isAnonymous" : @NO, @"isQuiz" : @NO,
	};
	XCTAssertEqualObjects(TGPollKindLine(poll), @"Poll");
}

- (void)testQuizEmptyUsesOfficialSentence {
	NSDictionary *poll = @{
		@"isClosed" : @NO, @"isAnonymous" : @YES, @"isQuiz" : @YES,
		@"totalVoterCount" : @0,
	};
	XCTAssertEqualObjects(TGPollVotesLine(poll), @"Nobody answered yet");
}

- (void)testQuizCountUsesAnsweredTemplate {
	NSDictionary *poll = @{
		@"isClosed" : @NO, @"isAnonymous" : @YES, @"isQuiz" : @YES,
		@"totalVoterCount" : @5,
	};
	XCTAssertEqualObjects(TGPollVotesLine(poll), @"5 answered");
}

- (void)testPollClosesInDaysUsesPackTemplate {
	NSDictionary *poll = @{@"isClosed" : @NO, @"closeDate" : @(86400 * 2 + 1)};
	XCTAssertEqualObjects(TGPollClosesLine(poll, 1), @"ends in 2 days");
}

- (void)testPollClosesTodayKeepsLowerCaseSentence {
	NSDictionary *poll = @{@"isClosed" : @NO, @"closeDate" : @301};
	XCTAssertEqualObjects(TGPollClosesLine(poll, 1), @"ends in 5:00");
}

#pragma mark - message context menu

- (void)testMessageMenuUsesOfficialOneCardOrder {
	NSDictionary *message = @{
		@"id" : @7, @"text" : @"hello", @"outgoing" : @YES,
		@"canComment" : @NO, @"failed" : @NO, @"service" : @NO,
	};
	NSArray *actions = TGMenuActions(message, TGMenuContext(YES, YES, NO));
	NSArray *expected = @[@"Reply", @"Copy", @"Find Quote", @"Translate",
			@"Speak", @"Edit", @"Pin", @"Forward", @"Delete", @"Select"];
	XCTAssertTrue(actions.count >= expected.count);
	XCTAssertEqualObjects([actions subarrayWithRange:NSMakeRange(0, expected.count)],
			expected, @"the one card must follow official's row order");
	XCTAssertFalse([actions containsObject:@"More"],
			@"the second card is gone");
	XCTAssertFalse([actions containsObject:@"Who Read This"],
			@"the read summary replaces the Who Read This row");
	XCTAssertFalse([actions containsObject:@"Message Info"],
			@"the Info row is gone");
}

- (void)testIncomingGroupReportSitsBeforeSelect {
	NSDictionary *message = @{
		@"id" : @8, @"text" : @"spam", @"outgoing" : @NO,
		@"canComment" : @NO, @"failed" : @NO, @"service" : @NO,
	};
	NSArray *actions = TGMenuActions(message, TGMenuContext(NO, YES, NO));
	NSUInteger report = [actions indexOfObject:@"Report Spam"];
	NSUInteger select = [actions indexOfObject:@"Select"];
	XCTAssertNotEqual(report, (NSUInteger)NSNotFound);
	XCTAssertNotEqual(select, (NSUInteger)NSNotFound);
	XCTAssertTrue(report < select);
	XCTAssertFalse([actions containsObject:@"Report"],
			@"a group reports spam, not a private-chat user");
	XCTAssertFalse([actions containsObject:@"Delete"],
			@"somebody else's message is not yours to delete");
}

- (void)testMenuNeverShowsTheSameTitleTwice {
	NSDictionary *message = @{
		@"id" : @9, @"text" : @"#tag hello", @"outgoing" : @YES,
		@"canComment" : @YES, @"replyCount" : @4, @"failed" : @NO,
		@"service" : @NO, @"channelPost" : @YES, @"photoId" : @55,
		@"pollOptions" : @[@{@"text" : @"one"}], @"pollClosed" : @YES,
		@"pollOpen" : @YES, @"pollDeletable" : @YES,
		@"pollVoters" : @YES, @"pollStats" : @YES,
		@"reactionGroups" : @[@{@"emoji" : @"👍", @"count" : @3}],
		@"reactionReport" : @{@"sender" : @{}},
		@"inlineRows" : @[@{@"text" : @"ok"}],
		@"kind" : @"messagePhoto",
	};
	TGChatActionMenuContext context = TGMenuContext(YES, NO, YES);
	context.canAddToFavorites = YES;
	NSArray *rows = TGChatActionMenuRows(message, context);
	NSMutableSet *titles = [NSMutableSet set];
	for (NSDictionary *row in rows){
		XCTAssertFalse([titles containsObject:row[@"title"]],
				@"%@ appears twice in one card", row[@"title"]);
		[titles addObject:row[@"title"]];
	}
}

- (void)testReadSummaryBelongsToOwnGroupOrChannelOnly {
	NSDictionary *message = @{@"text" : @"hi", @"service" : @NO};
	TGChatActionMenuContext group = TGMenuContext(YES, YES, NO);
	XCTAssertTrue(TGChatActionMenuShowsReadSummary(message, group));
	XCTAssertTrue(TGChatActionMenuShowsReadSummary(message,
			TGMenuContext(YES, NO, YES)));
	XCTAssertFalse(TGChatActionMenuShowsReadSummary(message,
			TGMenuContext(YES, NO, NO)),
			@"a private chat has no viewer list line");
	XCTAssertFalse(TGChatActionMenuShowsReadSummary(message,
			TGMenuContext(NO, YES, NO)),
			@"somebody else's message is not your read report");
	TGChatActionMenuContext saved = TGMenuContext(YES, NO, YES);
	saved.isSavedMessages = YES;
	XCTAssertFalse(TGChatActionMenuShowsReadSummary(message, saved));
}

- (void)testReadSummaryUsesPackWording {
	XCTAssertEqualObjects(TGChatActionMenuSeenText(12), @"12 Seen");
	XCTAssertEqualObjects(TGChatActionMenuSeenText(0), @"No views");
	XCTAssertEqualObjects(TGChatActionMenuReactionText(3), @"3 reactions");
	XCTAssertEqualObjects(TGChatActionMenuReactionText(0), @"");
}

#pragma mark - layout cache

- (void)testChangedMessageIdsKeepsUnchangedRows {
	NSDictionary *same = @{@"id" : @1, @"text" : @"hello"};
	NSDictionary *oldEdited = @{@"id" : @2, @"text" : @"before"};
	NSDictionary *newEdited = @{@"id" : @2, @"text" : @"after"};
	NSArray *old = @[same, oldEdited];
	NSArray *now = @[same, newEdited, @{@"id" : @3, @"text" : @"new"}];
	XCTAssertEqualObjects(TGChangedMessageIds(old, now), (@[@2, @3]),
			@"an unchanged row must keep its cached geometry");
}

#pragma mark - dates

- (void)testDateSeparatorUsesPackMonthBeforeDay {
	struct tm value;
	memset(&value, 0, sizeof(value));
	value.tm_year = 125;   // 2025
	value.tm_mon = 10;     // November
	value.tm_mday = 5;
	value.tm_hour = 12;
	value.tm_isdst = -1;
	NSTimeInterval stamp = (NSTimeInterval)mktime(&value);
	NSTimeInterval now = stamp + 40 * 86400;
	XCTAssertEqualObjects(TGChatDateSeparatorTitle(stamp, now), @"November 5");
}

- (void)testDateSeparatorKeepsThePackOrderForASharedTemplate {
	struct tm value;
	memset(&value, 0, sizeof(value));
	value.tm_year = 125;
	value.tm_mon = 10;
	value.tm_mday = 5;
	value.tm_hour = 12;
	value.tm_isdst = -1;
	NSTimeInterval stamp = (NSTimeInterval)mktime(&value);
	// "%1$@ %2$@" by English belongs to another key; only the keyed entry
	// carries the date header's Russian order.
	TGSetTelegramLanguageLookup(@{
		@"%1$@ %2$@" : @"%1$@ %2$@",
		@"November" : @"ноябрь",
		@"@@Date.ChatDateHeader" : @"%2$@ %1$@",
		@"@@Month.GenNovember" : @"ноября",
	});
	NSString *title = TGChatDateSeparatorTitle(stamp, stamp + 40 * 86400);
	TGSetTelegramLanguageLookup(nil);
	XCTAssertEqualObjects(title, @"5 ноября");
}

- (void)testChannelMuteWordComesFromTheConversationKey {
	XCTAssertEqualObjects(TGChatChannelMuteTitle(NO), @"Mute");
	XCTAssertEqualObjects(TGChatChannelMuteTitle(YES), @"Unmute");
	// "Mute" alone maps to the call screen's microphone word.
	TGSetTelegramLanguageLookup(@{@"Mute" : @"Выкл. микрофон",
			@"@@Conversation.Mute" : @"Выкл. звук"});
	NSString *russian = TGChatChannelMuteTitle(NO);
	TGSetTelegramLanguageLookup(nil);
	XCTAssertEqualObjects(russian, @"Выкл. звук");
}

- (void)testDateSeparatorToday {
	NSTimeInterval now = 1700000000;
	XCTAssertEqualObjects(TGChatDateSeparatorTitle(now, now), @"Today");
}

#pragma mark - composer

- (void)testComposerPlaceholderKinds {
	XCTAssertEqualObjects(TGChatComposerPlaceholder(NO, NO, NO), @"Message");
	XCTAssertEqualObjects(TGChatComposerPlaceholder(YES, NO, NO), @"Broadcast");
	XCTAssertEqualObjects(TGChatComposerPlaceholder(YES, YES, NO), @"Silent Broadcast");
	XCTAssertEqualObjects(TGChatComposerPlaceholder(NO, NO, YES), @"Send anonymously");
}

#pragma mark - chat list

- (void)testPrivateDeleteOffersBothScopes {
	XCTAssertEqualObjects(TGChatDeleteChoices(YES, 1),
			(@[@"Delete for All", @"Delete for me"]));
}

- (void)testGroupDeleteOffersOnlyLocalCount {
	XCTAssertEqualObjects(TGChatDeleteChoices(NO, 3), (@[@"Delete 3 Chats"]));
}

- (void)testEditingRowIsSelectableWithoutSwipeSupport {
	XCTAssertTrue(TGChatRowIsSelectable(YES, NO, YES),
			@"iOS 6/7 has no row actions but still has the left check control");
	XCTAssertFalse(TGChatRowIsSelectable(NO, NO, YES));
	XCTAssertFalse(TGChatRowIsSelectable(YES, YES, NO));
}

- (void)testStoryRowsStayInTheirList {
	NSDictionary *archived = @{@"chatId" : @1, @"list" : @"archive"};
	NSDictionary *main = @{@"chatId" : @2, @"list" : @"main"};
	NSArray *merged = TGStoryRowsForList(@[archived], @[main], @"archive");
	XCTAssertEqual(merged.count, (NSUInteger)1);
	XCTAssertEqualObjects(merged.firstObject[@"chatId"], @1);
}

- (void)testLateFolderAnswerIsDropped {
	XCTAssertTrue(TGChatFolderAnswerStillWanted(7, 7));
	XCTAssertFalse(TGChatFolderAnswerStillWanted(7, 0),
			@"an answer for a folder the user left must not fill the next one");
}

#pragma mark - forward picker

- (void)testForwardSelectionKeepsListOrderNotTapOrder {
	NSArray *chats = @[@{@"id" : @10}, @{@"id" : @20}, @{@"id" : @30}];
	NSArray *ids = TGSelectedChatIdsInOrder(chats, [NSSet setWithObjects:@30, @10, nil]);
	XCTAssertEqualObjects(ids, (@[@10, @30]));
}

- (void)testSearchHitCarriesMessageId {
	XCTAssertTrue(TGChatSearchHitOpensMessage(@{@"id" : @77, @"chatId" : @5}));
	XCTAssertFalse(TGChatSearchHitOpensMessage(@{@"id" : @5, @"text" : @"chat row"}));
}

- (void)testDeleteForMeWaitsForUndoCommit {
	XCTAssertTrue(TGChatDeleteDefersToCommit(NO));
	XCTAssertFalse(TGChatDeleteDefersToCommit(YES),
			@"a delete for everyone is already gone and has nothing to undo");
}

- (void)testStatusNotificationRefreshesOnlyPrivatePresence {
	XCTAssertTrue(TGChatStatusNotificationRefreshesPresence(
			TGUserStatusChangedNotification, NO, NO));
	XCTAssertFalse(TGChatStatusNotificationRefreshesPresence(
			TGUserStatusChangedNotification, YES, NO));
	XCTAssertFalse(TGChatStatusNotificationRefreshesPresence(
			TGUserStatusChangedNotification, NO, YES));
	XCTAssertFalse(TGChatStatusNotificationRefreshesPresence(@"Other", NO, NO));
}

@end
