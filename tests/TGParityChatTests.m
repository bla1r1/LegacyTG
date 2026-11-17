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
#include <math.h>

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
	// "Find Quote" is the action key; the visible row is official's "Quote".
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

- (void)testMessageToolsNeverAppearsInAnyHoldMenu {
	NSArray *kinds = @[@"messageText", @"messagePhoto", @"messageVoiceNote",
			@"messageSticker"];
	for (NSString *kind in kinds){
		NSDictionary *message = @{
			@"id" : @10, @"text" : @"hello", @"outgoing" : @YES,
			@"kind" : kind, @"service" : @NO, @"failed" : @NO,
			@"photoId" : @55, @"docId" : @56,
		};
		NSArray *actions = TGMenuActions(message, TGMenuContext(YES, YES, NO));
		XCTAssertFalse([actions containsObject:@"Message Tools"],
				@"%@ must not grow a dev row", kind);
	}
}

- (void)testQuoteSpeakAndTranslateNeedRealTextOrACaption {
	NSDictionary *photo = @{
		@"id" : @11, @"text" : @"Photo", @"outgoing" : @NO,
		@"kind" : @"messagePhoto", @"photoId" : @5, @"caption" : @"",
	};
	NSDictionary *voice = @{
		@"id" : @12, @"text" : @"Voice message", @"outgoing" : @NO,
		@"kind" : @"messageVoiceNote", @"docId" : @6,
	};
	NSDictionary *sticker = @{
		@"id" : @13, @"text" : @"Sticker", @"outgoing" : @NO,
		@"kind" : @"messageSticker", @"photoId" : @7,
	};
	for (NSDictionary *message in @[photo, voice, sticker]){
		NSArray *actions = TGMenuActions(message, TGMenuContext(NO, NO, NO));
		XCTAssertFalse([actions containsObject:@"Find Quote"]);
		XCTAssertFalse([actions containsObject:@"Translate"]);
		XCTAssertFalse([actions containsObject:@"Speak"]);
	}
	NSArray *stickerActions = TGMenuActions(sticker, TGMenuContext(NO, NO, NO));
	XCTAssertTrue([stickerActions containsObject:@"Add to Favourites"]);
	NSArray *voiceActions = TGMenuActions(voice, TGMenuContext(NO, NO, NO));
	XCTAssertFalse([voiceActions containsObject:@"Transcribe"],
			@"official transcribes from the voice bubble, not the hold menu");
}

- (void)testReplacePhotoIsOnlyTheAuthorsEditablePhoto {
	NSDictionary *caption = @{
		@"id" : @14, @"text" : @"caption", @"caption" : @"caption",
		@"kind" : @"messagePhoto", @"photoId" : @8, @"outgoing" : @YES,
	};
	TGChatActionMenuContext own = TGMenuContext(YES, NO, NO);
	NSArray *ownActions = TGMenuActions(caption, own);
	XCTAssertTrue([ownActions containsObject:@"Replace Photo"]);
	XCTAssertTrue([ownActions containsObject:@"Find Quote"],
			@"a caption is a text the sender wrote");

	TGChatActionMenuContext other = TGMenuContext(NO, NO, NO);
	NSArray *otherActions = TGMenuActions(caption, other);
	XCTAssertFalse([otherActions containsObject:@"Replace Photo"],
			@"somebody else's photo is not yours to replace");
	XCTAssertFalse([otherActions containsObject:@"Edit"]);
}

- (void)testComposerHeightGrowsPerLineAndStopsAtTheCap {
	CGFloat one = TGChatComposerFieldHeightForLines(1);
	CGFloat two = TGChatComposerFieldHeightForLines(2);
	XCTAssertEqual(two - one, TGChatComposerLineHeight());
	XCTAssertEqual(TGChatComposerMaxLines(), 12);
	XCTAssertEqual(TGChatComposerFieldHeightForLines(13),
			TGChatComposerFieldHeightForLines(12),
			"past the cap the text view scrolls, the bar does not grow");
	XCTAssertEqual(TGChatComposerLineCount(@"a\nb\nc", 200), 3);
	XCTAssertEqual(TGChatComposerLineCount(@"", 200), 1);
}

- (void)testAIEntryAppearsAtTheThirdLineOnlyWithText {
	XCTAssertFalse(TGChatComposerShowsAIEntry(@"a\nb", 200));
	XCTAssertTrue(TGChatComposerShowsAIEntry(@"a\nb\nc", 200));
	XCTAssertFalse(TGChatComposerShowsAIEntry(@" \n\t\n ", 200),
			"whitespace alone is not a message");
}

- (void)testComposerFieldEndsBeforeTheSendButtonAtOneAndSixLines {
	for (NSInteger lines = 1; lines <= 6; lines += 5) {
		CGFloat fieldHeight = TGChatComposerFieldHeightForLines(lines);
		CGFloat barHeight = TGChatComposerBarHeightForLines(lines);
		CGRect field = TGChatComposerFieldFrame(320.0f, barHeight, fieldHeight);
		CGRect send = TGChatComposerSendFrame(320.0f, barHeight);
		XCTAssertGreaterThan(field.size.width, 0.0f);
		XCTAssertLessThanOrEqual(CGRectGetMaxX(field), CGRectGetMinX(send),
				"%ld lines: the field must end before the send control",
				(long)lines);
		XCTAssertTrue(fabs(CGRectGetMaxY(field) - CGRectGetMaxY(send)) < 0.01f,
				"%ld lines: the send control is bottom-aligned with the field",
				(long)lines);
		XCTAssertLessThanOrEqual(CGRectGetMaxX(send), 320.0f);
	}
}

- (void)testAIComposeRecipientIsTheOpenChat {
	NSDictionary *model = TGAiComposeInputModel(@"hello", 4242, @"en", @"en");
	XCTAssertEqual([model[@"chatId"] longLongValue], (int64_t)4242);
	XCTAssertEqualObjects(model[@"text"], @"hello");
	XCTAssertNil(model[@"recipient"],
			"the recipient is the chat, not a separately chosen row");
}

- (void)testAIComposeLanguageComesFromTextThenChat {
	XCTAssertEqualObjects(TGAiComposeSourceLanguage(@"Привет", @"en", @"de"),
			@"ru", "the text's script wins over the chat's language");
	XCTAssertEqualObjects(TGAiComposeSourceLanguage(@"hello", @"uk", @"en"),
			@"uk", "Latin text falls back to the chat's language");
	XCTAssertEqualObjects(TGAiComposeSourceLanguage(@"", @"", @"fr"),
			@"fr", "an empty draft uses the app language");
	XCTAssertEqualObjects(TGAiComposeSourceLanguage(@"hello", @"", @""),
			@"en", "English is the last resort");
}

- (void)testAIComposeTargetIsTheOtherLanguage {
	XCTAssertEqualObjects(TGAiComposeTargetLanguage(@"ru", @"en"), @"en");
	XCTAssertEqualObjects(TGAiComposeTargetLanguage(@"en", @"en"), @"ru");
	XCTAssertFalse([TGAiComposeLanguageName(@"en") isEqualToString:@"en"],
			"the UI shows a language name, never the raw code");
}

/// The target language comes from Translation.Language.<code> by key: by
/// English value "English" is the pack's own name and read "Русский".
- (void)testAIComposeLanguageNameUsesTheOfficialKeyNotTheValue {
	TGSetTelegramLanguageLookup(@{
		@"English" : @"Русский",
		@"@@Translation.Language.en" : @"английский",
	});
	XCTAssertEqualObjects(TGAiComposeLanguageName(@"en"), @"английский");
	TGSetTelegramLanguageLookup(@{@"English" : @"Русский"});
	XCTAssertFalse([TGAiComposeLanguageName(@"en") isEqualToString:@"Русский"],
			@"a missing key must not fall back to the colliding English value");
	TGSetTelegramLanguageLookup(nil);
}

- (void)testAIComposeModeAndStyleListsFollowOfficial {
	XCTAssertEqualObjects(TGAiComposeModeTitles(),
			(@[@"Translate", @"Style", @"Fix"]));
	NSArray *styles = TGAiComposeStyleChoices();
	XCTAssertEqual(styles.count, (NSUInteger)3);
	for (NSDictionary *style in styles) {
		XCTAssertFalse([style[@"title"] isEqualToString:style[@"key"]],
				"a style shows its title, not the request key");
		XCTAssertFalse([style[@"title"] isEqualToString:@"Neutral"],
				"official does not list neutral as a style chip");
	}
}

- (void)testDrawableSizeRejectsZeroAndNaN {
	XCTAssertFalse(TGChatDrawableSize(CGSizeZero));
	XCTAssertFalse(TGChatDrawableSize(CGSizeMake(0.0f, 20.0f)));
	XCTAssertFalse(TGChatDrawableSize(CGSizeMake(20.0f, 0.0f)));
	XCTAssertFalse(TGChatDrawableSize(CGSizeMake(NAN, 20.0f)));
	XCTAssertTrue(TGChatDrawableSize(CGSizeMake(1.0f, 1.0f)));
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

// Delete hung on "mine", so an incoming message in a private chat had no
// Delete at all, and Copy showed in chats that forbid copying.
- (void)testMenu_FollowsMessageProperties {
	NSDictionary *incoming = @{ @"id" : @5, @"text" : @"hello", @"outgoing" : @NO, @"kind" : @"messageText" };
	TGChatActionMenuContext context = TGMenuContext(NO, NO, NO);
	NSArray *(^actions)(TGChatActionMenuContext) = ^NSArray *(TGChatActionMenuContext c){
		return [TGChatActionMenuRows(incoming, c) valueForKey:@"action"];
	};
	XCTAssertFalse([actions(context) containsObject:@"Delete"]);
	TGChatActionMenuApplyProperties(&context, @{ @"@type" : @"messageProperties", @"can_be_replied" : @YES,
			@"can_be_deleted_only_for_self" : @YES, @"can_be_deleted_for_all_users" : @YES,
			@"can_be_copied" : @NO, @"can_be_pinned" : @YES });
	XCTAssertTrue([actions(context) containsObject:@"Delete"]);
	XCTAssertFalse([actions(context) containsObject:@"Copy"]);
}

- (void)testMessageDeleteChoices_OnlyWhatTDLibAllows {
	XCTAssertEqual(TGMessageDeleteChoices(NO, NO, nil).count, (NSUInteger)2);
	NSArray *selfOnly = TGMessageDeleteChoices(NO, YES, @{ @"@type" : @"messageProperties",
			@"can_be_deleted_only_for_self" : @YES, @"can_be_deleted_for_all_users" : @NO });
	XCTAssertEqual(selfOnly.count, (NSUInteger)1);
	XCTAssertFalse([selfOnly[0][@"revoke"] boolValue]);
	XCTAssertEqual(TGMessageDeleteChoices(YES, NO, nil).count, (NSUInteger)1);
}

// Parity: deleting a paid suggested post for everyone within a day loses
// its Stars, and official asks first (ChatControllerLoadDisplayNode.swift).
- (void)testDeleteLosesPaidPostStars_OnlyRecentRevokedPaidPosts {
	NSTimeInterval now = 1700100000;
	NSDictionary *fresh = @{ @"paidStarPost" : @YES, @"date" : @(now - 3600) };
	NSDictionary *old = @{ @"paidStarPost" : @YES, @"date" : @(now - 25 * 3600) };
	NSDictionary *plain = @{ @"paidStarPost" : @NO, @"date" : @(now - 60) };
	XCTAssertTrue(TGDeleteLosesPaidPostStars(@[plain, fresh], YES, now));
	XCTAssertFalse(TGDeleteLosesPaidPostStars(@[fresh], NO, now));
	XCTAssertFalse(TGDeleteLosesPaidPostStars(@[old, plain], YES, now));
}

// Parity: the ended giveaway sheet says who drew whom, naming the other
// channels (GiveawayInfoController .finished, Ended / EndedMany).
- (void)testGiveawayInfo_EndedNamesOtherChannels {
	NSString *many = TGGiveawayInfoText(@{ @"isEnded" : @YES, @"selectionDate" : @(1700000000),
			@"winnerCount" : @3, @"additionalChatCount" : @2 }, @"Cats");
	XCTAssertTrue([many rangeOfString:@"Telegram automatically selected 3 random subscribers of Cats and other listed channels."].location != NSNotFound);
	NSString *one = TGGiveawayInfoText(@{ @"isEnded" : @YES, @"selectionDate" : @(1700000000),
			@"winnerCount" : @1, @"additionalChatCount" : @0, @"isGroup" : @YES }, @"Cats");
	XCTAssertTrue([one rangeOfString:@"Telegram automatically selected 1 random member of Cats."].location != NSNotFound);
}

// Official moves a held bubble only as far as its menu needs; the old lift
// always threw it to the top, and the dim-only hold let the card run off.
- (void)testHoldLift_MovesOnlyAsFarAsTheMenuNeeds {
	CGRect middle = CGRectMake(10, 100, 200, 40);
	XCTAssertEqual(TGHoldLiftY(middle, 40, 100, 10, 470), (CGFloat)100);
	CGRect low = CGRectMake(10, 380, 200, 40);
	XCTAssertEqual(TGHoldLiftY(low, 40, 100, 10, 470), (CGFloat)330);
	CGRect high = CGRectMake(10, 0, 200, 40);
	XCTAssertEqual(TGHoldLiftY(high, 40, 100, 10, 470), (CGFloat)50);
	CGRect tall = CGRectMake(10, 200, 200, 400);
	XCTAssertEqual(TGHoldLiftY(tall, 40, 100, 10, 470), (CGFloat)50);
}

- (void)testSlowModeWait_ReadsLikeOfficial {
	XCTAssertEqualObjects(TGSlowModeWaitText(42), @"0:42");
	XCTAssertEqualObjects(TGSlowModeWaitText(59.2), @"1:00");
	XCTAssertEqualObjects(TGSlowModeWaitText(125), @"2:05");
}


// ChatButtonKeyboardInputNode: resize_keyboard fits the rows, without it
// the keys grow to the system keyboard's height. Before, both were sized
// to four rows at most.
- (void)testBotKeyboard_ResizeFitsRowsElseFillsTheKeyboard {
	CGFloat pitch = 40;
	XCTAssertEqual(TGBotKeyboardPanelHeight(3, YES, 216, 4, &pitch), (CGFloat)124);
	XCTAssertEqual(pitch, (CGFloat)40);
	pitch = 40;
	XCTAssertEqual(TGBotKeyboardPanelHeight(3, NO, 216, 4, &pitch), (CGFloat)216);
	XCTAssertEqual(pitch, (CGFloat)70);
	pitch = 40;
	XCTAssertEqual(TGBotKeyboardPanelHeight(8, YES, 216, 4, &pitch), (CGFloat)216);
	XCTAssertEqual(pitch, (CGFloat)40);
}

- (void)testNavigationButtons_StackOverTheDownArrow {
	CGFloat m, r, p;
	TGChatNavigationButtonOffsets(YES, 0, 2, 1, 50, &m, &r, &p);
	XCTAssertEqual(m, (CGFloat)-1);
	XCTAssertEqual(r, (CGFloat)50);
	XCTAssertEqual(p, (CGFloat)100);
	TGChatNavigationButtonOffsets(NO, 0, 0, 1, 50, &m, &r, &p);
	XCTAssertEqual(r, (CGFloat)-1);
	XCTAssertEqual(p, (CGFloat)0);
	// Mentions sit right over the down arrow, under the reactions.
	TGChatNavigationButtonOffsets(YES, 4, 2, 0, 50, &m, &r, &p);
	XCTAssertEqual(m, (CGFloat)50);
	XCTAssertEqual(r, (CGFloat)100);
	XCTAssertEqual(p, (CGFloat)-1);
}

- (void)testPaidResend_UsesOfficialConfirmation {
	XCTAssertEqualObjects(TGPaidResendConfirmText(@"Ann", 10),
			@"Ann charges 10 Stars per incoming message. Would you like to pay 10 Stars to send 1 message?");
}


#pragma mark - parity

// ChatDeleteMessageContextItem: the timer under Delete.
- (void)testAutoDeleteText_ClockThenDays {
	XCTAssertEqualObjects(TGAutoDeleteText(42), @"auto-deletes in 0:42");
	XCTAssertEqualObjects(TGAutoDeleteText(3729), @"auto-deletes in 1:02:09");
	XCTAssertEqualObjects(TGAutoDeleteText(2 * 86400 + 100), @"auto-deletes in 2 days");
}

- (void)testDeleteRow_CarriesTheTimer {
	TGChatActionMenuContext context = TGMenuContext(YES, NO, NO);
	NSDictionary *timed = @{@"id" : @1, @"text" : @"x", @"kind" : @"messageText", @"outgoing" : @YES,
		@"deleteAt" : @([[NSDate date] timeIntervalSince1970] + 100)};
	NSDictionary *deleteRow = nil;
	for (NSDictionary *row in TGChatActionMenuRows(timed, context))
		if ([row[@"action"] isEqualToString:@"Delete"])
			deleteRow = row;
	XCTAssertTrue([deleteRow[@"subtitle"] hasPrefix:@"auto-deletes in 1:"], @"%@", deleteRow);
	NSMutableDictionary *plain = [timed mutableCopy];
	[plain removeObjectForKey:@"deleteAt"];
	for (NSDictionary *row in TGChatActionMenuRows(plain, context))
		XCTAssertNil(row[@"subtitle"]);
}

- (void)testFreeTranscriptions_OfficialTooltip {
	XCTAssertEqualObjects(TGFreeTranscriptionsText(3),
			@"You have 3 free voice transcriptions left this week.");
	XCTAssertEqualObjects(TGFreeTranscriptionsText(1),
			@"You have 1 free voice transcription left this week.");
	XCTAssertNil(TGFreeTranscriptionsText(-1));
}


#pragma mark - parity

- (void)testNewContactCard_CountryMonthAndChanges {
	NSDictionary *account = @{@"registrationMonth" : @3, @"registrationYear" : @2021,
		@"country" : @"UA", @"nameChanged" : @(1000000 - 3 * 86400), @"photoChanged" : @0};
	NSArray *rows = TGNewContactCardRows(account, @"Ukraine", 1000000);
	XCTAssertEqualObjects(rows[0], (@[@"Phone Number", @"Ukraine"]));
	XCTAssertEqualObjects(rows[1], (@[@"Registration", @"March 2021"]));
	XCTAssertEqualObjects(rows[2], (@[@"User updated name 3 days ago"]));
	XCTAssertEqual(rows.count, (NSUInteger)3);
	XCTAssertEqual(TGNewContactCardRows(nil, nil, 0).count, (NSUInteger)0);
}

- (void)testJoinRequestAndPaidPlaceholder {
	XCTAssertEqualObjects(TGJoinRequestInfoText(@"Cats", @"Nov 3, 2026"),
			@"You received this message because you requested to join Cats on Nov 3, 2026.");
	XCTAssertEqualObjects(TGPaidMessagePlaceholder(10), @"Message for 10 Stars");
	XCTAssertNil(TGPaidMessagePlaceholder(0));
}


#pragma mark - the hold menu follows messageProperties

static NSDictionary *TGProps(NSDictionary *extra) {
	NSMutableDictionary *p = [@{@"@type" : @"messageProperties", @"can_be_replied" : @YES,
		@"can_be_copied" : @YES, @"can_be_deleted_only_for_self" : @YES} mutableCopy];
	[p addEntriesFromDictionary:extra];
	return p;
}

- (void)testProperties_DriveAuthorStatsReportAndThread {
	TGChatActionMenuContext context = TGMenuContext(NO, YES, NO);
	TGChatActionMenuApplyProperties(&context, TGProps(@{@"can_get_author" : @YES,
		@"need_show_statistics" : @YES, @"can_report_supergroup_spam" : @YES,
		@"can_get_message_thread" : @YES}));
	XCTAssertTrue(context.canViewAuthor);
	XCTAssertTrue(context.canViewStats);
	XCTAssertTrue(context.canReport);
	NSDictionary *m = @{@"id" : @1, @"text" : @"hi", @"kind" : @"messageText", @"replyCount" : @3};
	NSArray *actions = TGMenuActions(m, context);
	XCTAssertTrue([actions containsObject:@"View Thread"]);
	XCTAssertTrue([actions containsObject:@"Author"]);
	TGChatActionMenuContext plain = TGMenuContext(NO, YES, NO);
	TGChatActionMenuApplyProperties(&plain, TGProps(@{}));
	XCTAssertFalse(plain.canReport);
	XCTAssertFalse([TGMenuActions(m, plain) containsObject:@"View Thread"]);
}

- (void)testProperties_ReplacePhotoAndReportReaction {
	TGChatActionMenuContext context = TGMenuContext(YES, NO, NO);
	TGChatActionMenuApplyProperties(&context, TGProps(@{@"can_be_edited" : @YES}));
	NSDictionary *photo = @{@"id" : @1, @"text" : @"", @"kind" : @"messagePhoto", @"photoId" : @5};
	XCTAssertFalse([TGMenuActions(photo, context) containsObject:@"Replace Photo"]);
	TGChatActionMenuApplyProperties(&context, TGProps(@{@"can_be_edited" : @YES, @"can_edit_media" : @YES}));
	XCTAssertTrue([TGMenuActions(photo, context) containsObject:@"Replace Photo"]);
}

- (void)testCopyProtectionTipAndReadDate {
	TGChatActionMenuContext context = TGMenuContext(NO, NO, NO);
	TGChatActionMenuApplyProperties(&context, TGProps(@{@"has_protected_content_by_other_user" : @YES}));
	XCTAssertEqualObjects(TGCopyProtectionTip(context, @"Ann"), @"Ann disabled copying and forwarding in this chat.");
	TGChatActionMenuApplyProperties(&context, TGProps(@{@"has_protected_content_by_current_user" : @YES}));
	XCTAssertEqualObjects(TGCopyProtectionTip(context, @"Ann"), @"You disabled copying and forwarding in this chat.");
	XCTAssertTrue([TGReadDateText(1700000000) hasPrefix:@"read "]);
	XCTAssertNil(TGReadDateText(0));
}

- (void)testTranscriptionCooldown_OnlyWhenSpent {
	NSString *text = TGTranscriptionCooldownText(0, 2, 2000, 1000);
	XCTAssertTrue([text hasPrefix:@"You have used all your 2 free transcriptions this week. Wait until "], @"%@", text);
	XCTAssertTrue([text hasSuffix:@"to use it again or subscribe to Telegram Premium now."]);
	XCTAssertNil(TGTranscriptionCooldownText(1, 2, 2000, 1000));
	XCTAssertNil(TGTranscriptionCooldownText(0, 2, 500, 1000));
	XCTAssertNil(TGTranscriptionCooldownText(-1, 2, 2000, 1000));
}


#pragma mark - parity

- (void)testForwardHeader_PsaWording {
	XCTAssertEqualObjects(TGForwardHeaderLine(@"Ann", nil), @"Forwarded from: Ann");
	XCTAssertEqualObjects(TGForwardHeaderLine(@"Proxy", @"default"), @"Public Service Announcement From: Proxy");
	XCTAssertEqualObjects(TGForwardHeaderLine(@"Proxy", @"covid"), @"Covid-19 Notification From: Proxy");
}

- (void)testGiveawayInfo_EndedAndStatuses {
	XCTAssertEqualObjects(TGGiveawayInfoText(@{@"isEnded" : @YES, @"activationCount" : @3}, @"Cats"),
			@"You didn't win a prize in this giveaway.\n\n3 of the winners already used their gift links.");
	XCTAssertEqualObjects(TGGiveawayInfoText(@{@"status" : @"giveawayParticipantStatusDisallowedCountry"}, @"Cats"),
			@"You are not eligible to participate in this giveaway, because your country is not included in the terms of the giveaway.");
	XCTAssertEqualObjects(TGGiveawayInfoText(@{@"status" : @"giveawayParticipantStatusParticipating"}, @"Cats"),
			@"You are participating in this giveaway, because you have joined the channel Cats.");
}

- (void)testBusinessBotStatus {
	XCTAssertEqualObjects(TGBusinessBotStatus(@{@"canReply" : @YES, @"paused" : @NO}), @"bot manages this chat");
	XCTAssertEqualObjects(TGBusinessBotStatus(@{@"canReply" : @YES, @"paused" : @YES}), @"bot paused");
	XCTAssertEqualObjects(TGBusinessBotStatus(@{@"canReply" : @NO}), @"bot has access to this chat");
}

// td_api.tl: 36 bytes, two bits per pixel, low bits first, 12x12.
- (void)testSecretKeyPicture {
	uint8_t bytes[36] = {0};
	bytes[0] = 0xE4; // cells 0..3 = 0,1,2,3
	NSData *key = [NSData dataWithBytes:bytes length:36];
	NSArray *cells = TGSecretKeyCells(key);
	XCTAssertEqual(cells.count, (NSUInteger)144);
	XCTAssertEqualObjects([cells subarrayWithRange:NSMakeRange(0, 4)], (@[@0, @1, @2, @3]));
	XCTAssertTrue([TGSecretKeyHex(key) hasPrefix:@"E4 00 00"]);
	XCTAssertEqual([[TGSecretKeyHex(key) componentsSeparatedByString:@"\n"] count], (NSUInteger)4);
}

/// Someone else's open-answer poll takes a new option; your own closed-to-
/// additions poll does not. TDLib's can_add_option decides, not authorship.
- (void)testAddOptionFollowsCanAddOptionNotAuthorship {
	NSDictionary *option = @{@"text" : @"A"};
	NSDictionary *theirs = @{@"text" : @"", @"service" : @NO, @"pollOptions" : @[option],
							 @"pollOpen" : @YES,
							 @"poll" : @{@"options" : @[option], @"canAddOption" : @YES}};
	XCTAssertTrue([TGMenuActions(theirs, TGMenuContext(NO, YES, NO)) containsObject:@"Add Option"]);
	NSDictionary *mine = @{@"text" : @"", @"service" : @NO, @"pollOptions" : @[option],
						   @"pollOpen" : @YES, @"poll" : @{@"options" : @[option]}};
	XCTAssertFalse([TGMenuActions(mine, TGMenuContext(YES, YES, NO)) containsObject:@"Add Option"]);
}

@end
