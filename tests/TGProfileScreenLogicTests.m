// TGProfileScreenLogicTests.m - Profile and Settings rules that lived in
// their screens (phase 8d): the media tab choice, the profile's text
// formatters and the sessions list split.
#import "TGTestRunner.h"
#import "TGProfileTabs.h"
#import "TGProfileLogic.h"
#import "TGSettingsPageModels.h"
#import "TGSearchScope.h"
#import "TGGroupLogic.h"
#import "TGUIFormat.h"

@interface TGProfileScreenLogicTests : XCTestCase @end

@implementation TGProfileScreenLogicTests

#pragma mark - media tabs

- (void)testTabs_SimilarChannelsGoLast {
	NSArray *tabs = TGProfileMediaTabs(@[@"media", @"links"], YES);
	XCTAssertEqual(tabs.count, (NSUInteger)3);
	XCTAssertEqualObjects(tabs[0], (@{@"title" : @"Media", @"kind" : @"media"}));
	XCTAssertEqualObjects(tabs.lastObject[@"kind"], @"similar");
	XCTAssertEqualObjects(tabs.lastObject[@"title"], @"Similar Channels");
	XCTAssertEqual(TGProfileMediaTabs(@[@"media"], NO).count, (NSUInteger)1);
}

- (void)testTabs_StoredOldNamesMapToTodaysTabs {
	NSArray *tabs = TGProfileMediaTabs(@[@"stories", @"media", @"files"], NO);
	XCTAssertEqualObjects(TGProfileSelectedTabKind(@"posts", tabs), @"stories");
	XCTAssertEqualObjects(TGProfileSelectedTabKind(@"gifs", tabs), @"media");
	XCTAssertEqualObjects(TGProfileSelectedTabKind(@"files", tabs), @"files");
}

- (void)testTabs_AGoneTabFallsBackToTheFirst {
	// The stored tab was Groups on a profile that no longer has common groups.
	NSArray *tabs = TGProfileMediaTabs(@[@"media", @"files"], NO);
	XCTAssertEqualObjects(TGProfileSelectedTabKind(@"groups", tabs), @"media");
	XCTAssertEqualObjects(TGProfileSelectedTabKind(nil, tabs), @"media");
	XCTAssertNil(TGProfileSelectedTabKind(@"media", @[]));
}

- (void)testTabs_GridOrList {
	for (NSString *kind in @[@"media", @"stories", @"archive", @"gifts"])
		XCTAssertTrue(TGProfileTabIsGrid(kind), @"%@", kind);
	for (NSString *kind in @[@"files", @"music", @"voice", @"links", @"groups", @"similar"])
		XCTAssertFalse(TGProfileTabIsGrid(kind), @"%@", kind);
	XCTAssertTrue(TGProfileTabIsStories(@"archive"));
	XCTAssertFalse(TGProfileTabIsStories(@"gifts"));
}

#pragma mark - formatters

- (void)testFirstURL_TextLinkThenTypedLinkWithScheme {
	NSArray *entities = @[
		@{@"offset" : @0, @"length" : @2, @"type" : @{@"@type" : @"textEntityTypeBold"}},
		@{@"offset" : @4, @"length" : @6, @"type" : @{@"@type" : @"textEntityTypeUrl"}}];
	XCTAssertEqualObjects(TGProfileFirstURL(@"hi, t.me/x now", entities).absoluteString,
			@"http://t.me/x");
	NSArray *link = @[@{@"offset" : @0, @"length" : @4,
			@"type" : @{@"@type" : @"textEntityTypeTextUrl", @"url" : @"https://a.b/c"}}];
	XCTAssertEqualObjects(TGProfileFirstURL(@"here", link).host, @"a.b");
	// An entity past the end of the text is skipped, not a crash.
	NSArray *past = @[@{@"offset" : @3, @"length" : @9, @"type" : @{@"@type" : @"textEntityTypeUrl"}}];
	XCTAssertNil(TGProfileFirstURL(@"short", past));
	XCTAssertNil(TGProfileFirstURL(@"x", nil));
}

- (void)testDuration_MinutesAndPaddedSeconds {
	XCTAssertEqualObjects(TGProfileDurationText(@65), @"1:05");
	// An hour-long track gets its hours, as every other clock in the app.
	XCTAssertEqualObjects(TGProfileDurationText(@3600), @"1:00:00");
	XCTAssertNil(TGProfileDurationText(@0));
	XCTAssertNil(TGProfileDurationText(nil));
}

- (void)testBirthday_WithAndWithoutYear {
	XCTAssertEqualObjects(TGProfileBirthdayFieldText(5, 3, 1990), @"March 5, 1990");
	XCTAssertEqualObjects(TGProfileBirthdayFieldText(5, 3, 0), @"March 5");
	XCTAssertNil(TGProfileBirthdayFieldText(0, 3, 1990));
	// A month TDLib should never send must not index past the table.
	XCTAssertEqualObjects(TGProfileBirthdayFieldText(5, 13, 0), @" 5");
}

- (void)testPhotoDate_MediumStyleOrTheTitle {
	XCTAssertEqualObjects(TGProfilePhotoDateText(0, @"en"), @"Profile Photos");
	// Noon UTC keeps the day in every time zone.
	NSString *text = TGProfilePhotoDateText(1699963200, @"en_US");
	XCTAssertTrue([text containsString:@"Nov"] && [text containsString:@"14"] &&
			[text containsString:@"2023"], @"%@", text);
}

#pragma mark - sessions

- (void)testSessions_SplitAroundThisDevice {
	NSArray *sessions = @[
		@{@"id" : @1, @"isCurrent" : @YES},
		@{@"id" : @2, @"isUnconfirmed" : @YES},
		@{@"id" : @3},
		@{@"id" : @4, @"isCurrent" : @YES, @"isUnconfirmed" : @YES},
		@{@"id" : @5}];
	NSArray *(^ids)(NSArray *) = ^NSArray *(NSArray *list){ return [list valueForKey:@"id"]; };
	XCTAssertEqualObjects(ids(TGSessionsOtherThanCurrent(sessions, YES, YES)), (@[@2, @3, @5]));
	XCTAssertEqualObjects(ids(TGSessionsOtherThanCurrent(sessions, YES, NO)), (@[@2]));
	XCTAssertEqualObjects(ids(TGSessionsOtherThanCurrent(sessions, NO, YES)), (@[@3, @5]));
	XCTAssertEqual(TGSessionsOtherThanCurrent(nil, YES, YES).count, (NSUInteger)0);
}

#pragma mark - search scopes

- (void)testSearch_EachScopeKeepsItsKind {
	NSArray *hits = @[
		@{@"id" : @1, @"kind" : @"messagePhoto"},
		@{@"id" : @2, @"kind" : @"messageVideoNote"},
		@{@"id" : @3, @"kind" : @"messageDocument"},
		@{@"id" : @4, @"kind" : @"messageAudio"},
		@{@"id" : @5, @"kind" : @"messageVoiceNote"},
		@{@"id" : @6, @"kind" : @"messageText", @"text" : @"see T.me/x"},
		@{@"id" : @7, @"kind" : @"messageText", @"text" : @"no address"}];
	NSArray *(^ids)(TGSearchScope) = ^NSArray *(TGSearchScope scope){
		return [TGSearchScopedMessages(hits, scope) valueForKey:@"id"]; };
	XCTAssertEqualObjects(ids(TGSearchScopeMedia), (@[@1, @2]));
	XCTAssertEqualObjects(ids(TGSearchScopeFiles), (@[@3]));
	XCTAssertEqualObjects(ids(TGSearchScopeMusic), (@[@4]));
	XCTAssertEqualObjects(ids(TGSearchScopeVoice), (@[@5]));
	XCTAssertEqualObjects(ids(TGSearchScopeLinks), (@[@6]));
	XCTAssertEqual(TGSearchScopedMessages(hits, TGSearchScopeMessages).count, hits.count);
	XCTAssertEqual(TGSearchScopeTitles().count, (NSUInteger)(TGSearchScopeVoice + 1));
}

- (void)testSearch_WhichListsAScopeShows {
	XCTAssertTrue(TGSearchScopeShowsChats(TGSearchScopeAll));
	XCTAssertFalse(TGSearchScopeShowsChats(TGSearchScopeMedia));
	XCTAssertFalse(TGSearchScopeShowsMessages(TGSearchScopeChats));
	XCTAssertTrue(TGSearchScopeShowsMessages(TGSearchScopeVoice));
	XCTAssertTrue(TGSearchScopeShowsPublic(TGSearchScopeAll));
	XCTAssertFalse(TGSearchScopeShowsPublic(TGSearchScopeMessages));
}

- (void)testSearch_PublicPostLine {
	XCTAssertEqualObjects(TGPublicPostText(@{@"content" : @{@"@type" : @"messageText",
			@"text" : @{@"text" : @"  hi \n"}}}), @"hi");
	XCTAssertEqualObjects(TGPublicPostText(@{@"content" : @{@"@type" : @"messagePhoto",
			@"caption" : @{@"text" : @"cap"}}}), @"cap");
	XCTAssertEqualObjects(TGPublicPostText(@{@"content" : @{@"@type" : @"messagePoll"}}), @"Poll");
}

- (void)testSearch_PublicFooterNeverRepeatsNoResults {
	// Spent limit, no wait known: the screen's empty state says "No Results";
	// the footer said it again as a grey bar over Stories.
	XCTAssertNil(TGSearchPublicFooter(TGSearchScopeAll, YES, 0, 0));
	XCTAssertEqualObjects(TGSearchPublicFooter(TGSearchScopeAll, YES, 61, 0),
			@"free search unlocks in 2 minutes");
	XCTAssertEqualObjects(TGSearchPublicFooter(TGSearchScopeAll, NO, 0, 3),
			@"3 free searches remaining today.");
	XCTAssertNil(TGSearchPublicFooter(TGSearchScopeMessages, NO, 0, 3));
}

#pragma mark - helpers that had copies

- (void)testUserName_JoinsWhatIsThere {
	XCTAssertEqualObjects(TGProfileUserName((@{@"first_name" : @"Ann", @"last_name" : @"Lee"})), @"Ann Lee");
	XCTAssertEqualObjects(TGProfileUserName(@{@"last_name" : @"Lee"}), @"Lee");
	XCTAssertEqualObjects(TGProfileUserName(nil), @"");
}

#pragma mark - account and topic lines

- (void)testAccountValues {
	XCTAssertEqualObjects(TGFreezeDetail(nil), @"Unknown");
	XCTAssertEqualObjects(TGFreezeDetail(@{@"is_frozen" : @YES}), @"Frozen");
	XCTAssertEqualObjects(TGSubscriptionDetail((@{@"is_canceled" : @YES, @"is_payment_failed" : @YES})),
			@"Payment failed");
	XCTAssertEqualObjects(TGSubscriptionDetail(@{}), @"Active");
	XCTAssertEqualObjects(TGAgeVerificationDetail(@{@"min_age" : @18}), @"Age 18+");
	XCTAssertEqualObjects(TGAgeVerificationDetail(@{}), @"No minimum");
	XCTAssertEqualObjects(TGSoundName(@{@"id" : @7}), @"Sound 7");
	XCTAssertEqualObjects(TGNotificationGroupLabel(@"notificationGroupTypeMentions"), @"Mention");
	XCTAssertEqualObjects(TGNotificationGroupLabel(@""), @"Notifications");
}

- (void)testTopicLines {
	XCTAssertEqualObjects(TGTopicIconLine(@{@"colour" : @(0x6FB9F0)}), @"Colour 6FB9F0");
	XCTAssertEqualObjects(TGTopicIconLine((@{@"colour" : @(0x6FB9F0), @"iconEmojiId" : @5})),
			@"Custom emoji · colour 6FB9F0");
	XCTAssertEqualObjects(TGTopicStateLine((@{@"pinned" : @YES, @"closed" : @YES})), @"Pinned · Closed");
	XCTAssertEqualObjects(TGTopicStateLine(@{}), @"Open");
}

- (void)testPrivacyFooters_AreThePacksSentences {
	// The old sentences were not in the pack and stayed English in Russian.
	XCTAssertEqualObjects(TGPrivacyRuleFooterText(@"ShowProfilePhoto"),
			@"You can restrict who can see your profile photo with granular precision.");
	XCTAssertTrue([TGPrivacyRuleFooterText(@"ShowStatus") hasPrefix:@"Unless you are a Premium user"]);
	XCTAssertNil(TGPrivacyRuleFooterText(@"AllowCalls"));
	XCTAssertNil(TGPrivacyRuleFooterText(@"ShowLinkInForwardedMessages"));
}

@end
