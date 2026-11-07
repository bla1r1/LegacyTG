// TGMessageContentInteractiveTests.m — the structured half of a message.
//
// A poll, a shared contact card or a group call is not text; if its keys are
// read from the wrong place the bubble still draws, just empty. These tests
// pin the exact TDLib field names and the defaults that keep renderers away
// from NSNull.
#import "TGTestRunner.h"
#import "TGMessageContentInteractive.h"

@interface TGMessageContentInteractiveTests : XCTestCase @end

static NSDictionary *dcDiceSticker(id fileId, NSString *format) {
	return @{
		@"@type"   : @"sticker",
		@"sticker" : @{@"@type" : @"file", @"id" : fileId ?: [NSNull null]},
		@"format"  : @{@"@type" : format ?: [NSNull null]},
	};
}

static NSDictionary *dcDiceRegular(NSDictionary *sticker) {
	return @{@"@type" : @"diceStickersRegular", @"sticker" : sticker ?: @{}};
}

static NSDictionary *dcDiceSlotMachine(NSDictionary *background) {
	return @{@"@type" : @"diceStickersSlotMachine", @"background" : background ?: @{}};
}

@implementation TGMessageContentInteractiveTests

#pragma mark - poll

- (void)testPoll_QuizCarriesTheCorrectAnswerAndExplanation {
	NSDictionary *out = TGFlattenInteractiveContent(@{
		@"@type" : @"messagePoll",
		@"poll"  : @{
			@"@type"                 : @"poll",
			@"id"                    : @"5368324170671202286",
			@"question"              : @{@"@type" : @"formattedText", @"text" : @"Best language?"},
			@"options"               : @[
				@{@"@type" : @"pollOption", @"text" : @{@"text" : @"Objective-C"},
				  @"voter_count" : @3, @"vote_percentage" : @30,
				  @"is_chosen" : @NO, @"is_being_chosen" : @NO},
				@{@"@type" : @"pollOption", @"text" : @{@"text" : @"Swift"},
				  @"voter_count" : @7, @"vote_percentage" : @70,
				  @"is_chosen" : @YES, @"is_being_chosen" : @NO},
			],
			@"total_voter_count"     : @10,
			@"is_anonymous"          : @NO,
			@"is_closed"             : @YES,
			@"allows_multiple_answers": @NO,
			@"type"                  : @{
				@"@type"             : @"pollTypeQuiz",
				@"correct_option_ids": @[@1],
				@"explanation"       : @{@"@type" : @"formattedText", @"text" : @"Swift is newer."},
			},
			@"recent_voter_ids"      : @[
				@{@"@type" : @"messageSenderUser", @"user_id" : @"42"},
			],
			@"open_period"           : @0,
			@"close_date"            : @1700000100,
		},
	});

	XCTAssertTrue(out != nil);
	NSDictionary *poll = out[@"poll"];
	XCTAssertTrue([poll isKindOfClass:NSDictionary.class]);
	XCTAssertEqual([poll[@"pollId"] longLongValue], 5368324170671202286LL);
	XCTAssertEqualObjects(poll[@"question"], @"Best language?");
	XCTAssertEqual([poll[@"options"] count], (NSUInteger)2);
	XCTAssertEqual([poll[@"totalVoterCount"] integerValue], (NSInteger)10);
	XCTAssertFalse([poll[@"isAnonymous"] boolValue]);
	XCTAssertTrue([poll[@"isClosed"] boolValue]);
	XCTAssertTrue([poll[@"isQuiz"] boolValue]);
	XCTAssertFalse([poll[@"allowsMultiple"] boolValue]);
	XCTAssertEqual([poll[@"correctOption"] integerValue], (NSInteger)1);
	XCTAssertEqualObjects(poll[@"explanation"], @"Swift is newer.");
	XCTAssertEqual([poll[@"recentVoterIds"] count], (NSUInteger)1);
	XCTAssertEqual([poll[@"recentVoterIds"][0] longLongValue], 42LL);
	XCTAssertEqual([poll[@"closeDate"] longLongValue], 1700000100LL);

	NSDictionary *second = poll[@"options"][1];
	XCTAssertEqualObjects(second[@"text"], @"Swift");
	XCTAssertEqual([second[@"voterCount"] integerValue], (NSInteger)7);
	XCTAssertEqual([second[@"percent"] integerValue], (NSInteger)70);
	XCTAssertTrue([second[@"isChosen"] boolValue]);
	XCTAssertFalse([second[@"isBeingChosen"] boolValue]);
}

/// A poll still being typed into TDLib has no type object, no options and no
/// voters. Every key must still answer with the right empty value.
- (void)testPoll_RegularMinimalFillsDefaults {
	NSDictionary *out = TGFlattenInteractiveContent(@{
		@"@type" : @"messagePoll",
		@"poll"  : @{
			@"@type"    : @"poll",
			@"id"       : @7,
			@"question" : @{@"@type" : @"formattedText", @"text" : @"Lunch?"},
		},
	});

	NSDictionary *poll = out[@"poll"];
	XCTAssertEqual([poll[@"pollId"] longLongValue], 7LL);
	XCTAssertEqualObjects(poll[@"question"], @"Lunch?");
	XCTAssertEqual([poll[@"options"] count], (NSUInteger)0);
	XCTAssertEqual([poll[@"totalVoterCount"] integerValue], (NSInteger)0);
	XCTAssertFalse([poll[@"isAnonymous"] boolValue]);
	XCTAssertFalse([poll[@"isClosed"] boolValue]);
	XCTAssertFalse([poll[@"isQuiz"] boolValue]);
	XCTAssertFalse([poll[@"allowsMultiple"] boolValue]);
	XCTAssertEqual([poll[@"correctOption"] integerValue], (NSInteger)-1);
	XCTAssertEqualObjects(poll[@"explanation"], @"");
	XCTAssertEqual([poll[@"recentVoterIds"] count], (NSUInteger)0);
	XCTAssertEqual([poll[@"openPeriod"] integerValue], (NSInteger)0);
	XCTAssertEqual([poll[@"closeDate"] integerValue], (NSInteger)0);
}

/// Multiple answers are a property of the poll, not of its type, and a pending
/// request marks the option being chosen right now.
- (void)testPoll_MultipleAnswersAndPendingChoice {
	NSDictionary *out = TGFlattenInteractiveContent(@{
		@"@type" : @"messagePoll",
		@"poll"  : @{
			@"@type"                 : @"poll",
			@"id"                    : @8,
			@"options"               : @[
				@{@"@type" : @"pollOption", @"text" : @{@"text" : @"Tea"},
				  @"is_being_chosen" : @YES, @"vote_percentage" : @0},
				@{@"@type" : @"pollOption", @"text" : @{@"text" : @"Coffee"},
				  @"is_being_chosen" : @NO, @"vote_percentage" : @0},
			],
			@"is_anonymous"          : @YES,
			@"allows_multiple_answers": @YES,
			@"type"                  : @{@"@type" : @"pollTypeRegular"},
			@"open_period"           : @600,
		},
	});

	NSDictionary *poll = out[@"poll"];
	XCTAssertTrue([poll[@"allowsMultiple"] boolValue]);
	XCTAssertTrue([poll[@"isAnonymous"] boolValue]);
	XCTAssertFalse([poll[@"isQuiz"] boolValue]);
	XCTAssertTrue([poll[@"options"][0][@"isBeingChosen"] boolValue]);
	XCTAssertFalse([poll[@"options"][1][@"isBeingChosen"] boolValue]);
	XCTAssertEqual([poll[@"openPeriod"] integerValue], (NSInteger)600);
}

/// An unanswered quiz has an empty correct list; -1 is the value a renderer
/// checks before highlighting anything.
- (void)testPoll_UnansweredQuizHasNoCorrectOption {
	NSDictionary *out = TGFlattenInteractiveContent(@{
		@"@type" : @"messagePoll",
		@"poll"  : @{
			@"@type" : @"poll",
			@"id"    : @"9",
			@"type"  : @{@"@type" : @"pollTypeQuiz",
						 @"correct_option_ids" : @[]},
		},
	});

	NSDictionary *poll = out[@"poll"];
	XCTAssertTrue([poll[@"isQuiz"] boolValue]);
	XCTAssertEqual([poll[@"correctOption"] integerValue], (NSInteger)-1);
	XCTAssertEqualObjects(poll[@"explanation"], @"");
	XCTAssertEqual([poll[@"pollId"] longLongValue], 9LL);
}

/// Revoting is the poll's own flag, and the message, not the poll, carries the
/// description under the question.
- (void)testPoll_RevotingAndDescription {
	NSDictionary *out = TGFlattenInteractiveContent(@{
		@"@type"      : @"messagePoll",
		@"description": @{@"@type" : @"formattedText", @"text" : @"Choose one."},
		@"poll"       : @{
			@"@type"           : @"poll",
			@"id"              : @10,
			@"allows_revoting" : @YES,
			@"is_closed"       : @NO,
			@"options"         : @[],
		},
	});

	NSDictionary *poll = out[@"poll"];
	XCTAssertTrue([poll[@"allowsRevoting"] boolValue]);
	XCTAssertEqualObjects(poll[@"description"], @"Choose one.");
}

- (void)testPoll_RevotingAndDescriptionDefaultToOffAndEmpty {
	NSDictionary *out = TGFlattenInteractiveContent(@{
		@"@type" : @"messagePoll",
		@"poll"  : @{@"@type" : @"poll", @"id" : @11},
	});

	NSDictionary *poll = out[@"poll"];
	XCTAssertFalse([poll[@"allowsRevoting"] boolValue]);
	XCTAssertEqualObjects(poll[@"description"], @"");
}

#pragma mark - pinned message

- (void)testPin_StringMessageIdSurvivesTheTrip {
	NSDictionary *out = TGFlattenInteractiveContent(@{
		@"@type"     : @"messagePinMessage",
		@"message_id": @"5368324170671202286",
	});
	XCTAssertEqual([out[@"pinnedMessageId"] longLongValue], 5368324170671202286LL);
}

- (void)testPin_NumericMessageId {
	NSDictionary *out = TGFlattenInteractiveContent(@{
		@"@type"     : @"messagePinMessage",
		@"message_id": @77,
	});
	XCTAssertEqual([out[@"pinnedMessageId"] longLongValue], 77LL);
}

- (void)testPin_MissingIdDefaultsToZero {
	NSDictionary *out = TGFlattenInteractiveContent(@{@"@type" : @"messagePinMessage"});
	XCTAssertTrue([out[@"pinnedMessageId"] isKindOfClass:NSNumber.class]);
	XCTAssertEqual([out[@"pinnedMessageId"] longLongValue], 0LL);
}

#pragma mark - shared users

- (void)testUsersShared_FullListKeepsNamesAndSmallestPhoto {
	NSDictionary *out = TGFlattenInteractiveContent(@{
		@"@type"  : @"messageUsersShared",
		@"button_id": @12,
		@"users"  : @[
			@{@"@type" : @"sharedUser", @"user_id" : @"5368324170671202286",
			  @"first_name" : @"Ann", @"last_name" : @"Lee", @"username" : @"ann",
			  @"photo" : @{@"@type" : @"photo", @"sizes" : @[
				  @{@"photo" : @{@"id" : @111}},
				  @{@"photo" : @{@"id" : @222}},
			  ]}},
			@{@"@type" : @"sharedUser", @"user_id" : @43,
			  @"first_name" : @"Bob", @"last_name" : @"", @"username" : @""},
		],
	});

	XCTAssertEqual([out[@"sharedButtonId"] integerValue], (NSInteger)12);
	NSArray *users = out[@"sharedUsers"];
	XCTAssertEqual(users.count, (NSUInteger)2);
	XCTAssertEqual([users[0][@"userId"] longLongValue], 5368324170671202286LL);
	XCTAssertEqualObjects(users[0][@"firstName"], @"Ann");
	XCTAssertEqualObjects(users[0][@"lastName"], @"Lee");
	XCTAssertEqualObjects(users[0][@"username"], @"ann");
	XCTAssertEqual([users[0][@"photoFileId"] longLongValue], 111LL);
	XCTAssertEqual([users[1][@"userId"] longLongValue], 43LL);
	XCTAssertEqualObjects(users[1][@"username"], @"");
}

- (void)testUsersShared_UserWithoutOptionalFieldsGetsEmptyValues {
	NSDictionary *out = TGFlattenInteractiveContent(@{
		@"@type": @"messageUsersShared",
		@"users": @[@{@"@type" : @"sharedUser", @"user_id" : @5}],
	});
	NSDictionary *user = out[@"sharedUsers"][0];
	XCTAssertEqualObjects(user[@"firstName"], @"");
	XCTAssertEqualObjects(user[@"lastName"], @"");
	XCTAssertEqualObjects(user[@"username"], @"");
	XCTAssertEqual([user[@"photoFileId"] longLongValue], 0LL);
}

- (void)testUsersShared_EmptyListAndMissingButton {
	NSDictionary *out = TGFlattenInteractiveContent(@{@"@type" : @"messageUsersShared"});
	XCTAssertEqual([out[@"sharedUsers"] count], (NSUInteger)0);
	XCTAssertEqual([out[@"sharedButtonId"] longLongValue], 0LL);
}

#pragma mark - shared chat

- (void)testChatShared_FullChatKeepsTitleUsernameAndPhoto {
	NSDictionary *out = TGFlattenInteractiveContent(@{
		@"@type"    : @"messageChatShared",
		@"button_id": @"99",
		@"chat"     : @{
			@"@type"   : @"sharedChat",
			@"chat_id" : @"-1001234567890",
			@"title"   : @"LegacyTG News",
			@"username": @"legacytg",
			@"photo"   : @{@"@type" : @"photo", @"sizes" : @[
				@{@"photo" : @{@"id" : @31}},
				@{@"photo" : @{@"id" : @32}},
			]},
		},
	});

	XCTAssertEqual([out[@"sharedButtonId"] longLongValue], 99LL);
	NSDictionary *chat = out[@"sharedChat"];
	XCTAssertEqual([chat[@"chatId"] longLongValue], -1001234567890LL);
	XCTAssertEqualObjects(chat[@"title"], @"LegacyTG News");
	XCTAssertEqualObjects(chat[@"username"], @"legacytg");
	XCTAssertEqual([chat[@"photoFileId"] longLongValue], 31LL);
}

- (void)testChatShared_MinimalChatDefaults {
	NSDictionary *out = TGFlattenInteractiveContent(@{
		@"@type": @"messageChatShared",
		@"chat" : @{@"@type" : @"sharedChat", @"chat_id" : @17},
	});
	NSDictionary *chat = out[@"sharedChat"];
	XCTAssertEqual([chat[@"chatId"] longLongValue], 17LL);
	XCTAssertEqualObjects(chat[@"title"], @"");
	XCTAssertEqualObjects(chat[@"username"], @"");
	XCTAssertEqual([chat[@"photoFileId"] longLongValue], 0LL);
	XCTAssertEqual([out[@"sharedButtonId"] longLongValue], 0LL);
}

- (void)testChatShared_NoChatObjectStillBuildsEmptyCard {
	NSDictionary *out = TGFlattenInteractiveContent(@{@"@type" : @"messageChatShared"});
	NSDictionary *chat = out[@"sharedChat"];
	XCTAssertTrue([chat isKindOfClass:NSDictionary.class]);
	XCTAssertEqual([chat[@"chatId"] longLongValue], 0LL);
	XCTAssertEqualObjects(chat[@"title"], @"");
}

#pragma mark - group call

- (void)testGroupCall_FullCallUsesUniqueIdAndParticipants {
	NSDictionary *out = TGFlattenInteractiveContent(@{
		@"@type"                : @"messageGroupCall",
		@"unique_id"            : @"5368324170671202286",
		@"is_active"            : @YES,
		@"was_missed"           : @NO,
		@"is_video"             : @YES,
		@"duration"             : @75,
		@"other_participant_ids": @[
			@{@"@type" : @"messageSenderUser", @"user_id" : @"42"},
			@{@"@type" : @"messageSenderUser", @"user_id" : @7},
		],
	});

	NSDictionary *call = out[@"groupCall"];
	XCTAssertEqual([call[@"groupCallId"] longLongValue], 5368324170671202286LL);
	XCTAssertTrue([call[@"isActive"] boolValue]);
	XCTAssertFalse([call[@"wasMissed"] boolValue]);
	XCTAssertTrue([call[@"isVideo"] boolValue]);
	XCTAssertEqual([call[@"duration"] integerValue], (NSInteger)75);
	XCTAssertEqual([call[@"otherParticipantIds"] count], (NSUInteger)2);
	XCTAssertEqual([call[@"otherParticipantIds"][0] longLongValue], 42LL);
	XCTAssertEqual([call[@"otherParticipantIds"][1] longLongValue], 7LL);
}

- (void)testGroupCall_MinimalCallDefaults {
	NSDictionary *out = TGFlattenInteractiveContent(@{@"@type" : @"messageGroupCall"});
	NSDictionary *call = out[@"groupCall"];
	XCTAssertEqual([call[@"groupCallId"] longLongValue], 0LL);
	XCTAssertFalse([call[@"isActive"] boolValue]);
	XCTAssertFalse([call[@"isVideo"] boolValue]);
	XCTAssertFalse([call[@"wasMissed"] boolValue]);
	XCTAssertEqual([call[@"duration"] integerValue], (NSInteger)0);
	XCTAssertEqual([call[@"startDate"] integerValue], (NSInteger)0);
	XCTAssertEqual([call[@"otherParticipantIds"] count], (NSUInteger)0);
}

- (void)testGroupCall_ScheduledCallCarriesStartDate {
	NSDictionary *out = TGFlattenInteractiveContent(@{
		@"@type"        : @"messageVideoChatScheduled",
		@"group_call_id": @77,
		@"start_date"   : @1700000000,
	});
	NSDictionary *call = out[@"groupCall"];
	XCTAssertEqual([call[@"groupCallId"] longLongValue], 77LL);
	XCTAssertEqual([call[@"startDate"] longLongValue], 1700000000LL);
	XCTAssertFalse([call[@"isActive"] boolValue]);
	XCTAssertTrue([call[@"isVideo"] boolValue]);
}

- (void)testGroupCall_StartedCallIsActive {
	NSDictionary *out = TGFlattenInteractiveContent(@{
		@"@type"        : @"messageVideoChatStarted",
		@"group_call_id": @"88",
	});
	NSDictionary *call = out[@"groupCall"];
	XCTAssertEqual([call[@"groupCallId"] longLongValue], 88LL);
	XCTAssertTrue([call[@"isActive"] boolValue]);
	XCTAssertTrue([call[@"isVideo"] boolValue]);
}

- (void)testGroupCall_EndedCallKeepsDurationWithoutId {
	NSDictionary *out = TGFlattenInteractiveContent(@{
		@"@type"   : @"messageVideoChatEnded",
		@"duration": @125,
	});
	NSDictionary *call = out[@"groupCall"];
	XCTAssertEqual([call[@"duration"] integerValue], (NSInteger)125);
	XCTAssertEqual([call[@"groupCallId"] longLongValue], 0LL);
	XCTAssertFalse([call[@"isActive"] boolValue]);
	XCTAssertTrue([call[@"isVideo"] boolValue]);
}

#pragma mark - checklist

- (void)testChecklist_FullListCountsOnlyCompletedTasks {
	NSDictionary *out = TGFlattenInteractiveContent(@{
		@"@type": @"messageChecklist",
		@"list" : @{
			@"@type"                   : @"checklist",
			@"title"                   : @{@"text" : @"Groceries"},
			@"tasks"                   : @[
				@{@"@type" : @"checklistTask", @"id" : @"1",
				  @"text" : @{@"text" : @"Milk"},
				  @"completed_by" : @{@"@type" : @"messageSenderUser", @"user_id" : @"42"},
				  @"completion_date" : @1700000001},
				@{@"@type" : @"checklistTask", @"id" : @2,
				  @"text" : @{@"text" : @"Bread"},
				  @"completion_date" : @0},
			],
			@"others_can_add_tasks"        : @YES,
			@"others_can_mark_tasks_as_done": @NO,
			@"can_add_tasks"               : @YES,
			@"can_mark_tasks_as_done"      : @YES,
		},
	});

	NSDictionary *list = out[@"checklist"];
	XCTAssertEqualObjects(list[@"title"], @"Groceries");
	XCTAssertEqual([list[@"tasks"] count], (NSUInteger)2);
	XCTAssertTrue([list[@"othersCanAddTasks"] boolValue]);
	XCTAssertFalse([list[@"othersCanMarkTasksAsDone"] boolValue]);
	XCTAssertTrue([list[@"canAddTasks"] boolValue]);
	XCTAssertTrue([list[@"canMarkTasksAsDone"] boolValue]);
	XCTAssertEqual([list[@"doneCount"] integerValue], (NSInteger)1);
	XCTAssertEqual([list[@"totalCount"] integerValue], (NSInteger)2);

	NSDictionary *first = list[@"tasks"][0];
	XCTAssertEqual([first[@"taskId"] integerValue], (NSInteger)1);
	XCTAssertEqualObjects(first[@"text"], @"Milk");
	XCTAssertEqual([first[@"completedByUserId"] longLongValue], 42LL);
	XCTAssertEqual([first[@"completionDate"] longLongValue], 1700000001LL);

	XCTAssertEqual([list[@"tasks"][1][@"completedByUserId"] longLongValue], 0LL);
}

/// The task's id field is `id`, not `task_id`; reading the wrong one would
/// leave every task with id 0.
- (void)testChecklist_TaskIdsAreReadFromId {
	NSDictionary *out = TGFlattenInteractiveContent(@{
		@"@type": @"messageChecklist",
		@"list" : @{
			@"@type": @"checklist",
			@"tasks": @[@{@"@type" : @"checklistTask", @"id" : @9,
						   @"text" : @{@"text" : @"Call back"}}],
		},
	});
	XCTAssertEqual([out[@"checklist"][@"tasks"][0][@"taskId"] integerValue], (NSInteger)9);
	XCTAssertEqual([out[@"checklist"][@"doneCount"] integerValue], (NSInteger)0);
}

- (void)testChecklist_EmptyListDefaults {
	NSDictionary *out = TGFlattenInteractiveContent(@{@"@type" : @"messageChecklist"});
	NSDictionary *list = out[@"checklist"];
	XCTAssertEqualObjects(list[@"title"], @"");
	XCTAssertEqual([list[@"tasks"] count], (NSUInteger)0);
	XCTAssertFalse([list[@"othersCanAddTasks"] boolValue]);
	XCTAssertFalse([list[@"othersCanMarkTasksAsDone"] boolValue]);
	XCTAssertFalse([list[@"canAddTasks"] boolValue]);
	XCTAssertFalse([list[@"canMarkTasksAsDone"] boolValue]);
	XCTAssertEqual([list[@"doneCount"] integerValue], (NSInteger)0);
	XCTAssertEqual([list[@"totalCount"] integerValue], (NSInteger)0);
}

- (void)testChecklist_TaskCompletedByChatHasNoUserId {
	NSDictionary *out = TGFlattenInteractiveContent(@{
		@"@type": @"messageChecklist",
		@"list" : @{
			@"@type": @"checklist",
			@"tasks": @[@{@"@type" : @"checklistTask", @"id" : @3,
						   @"text" : @{@"text" : @"Done"},
						   @"completed_by" : @{@"@type" : @"messageSenderChat", @"chat_id" : @9}}],
		},
	});
	NSDictionary *task = out[@"checklist"][@"tasks"][0];
	XCTAssertEqual([task[@"completedByUserId"] longLongValue], 0LL);
	XCTAssertEqual([out[@"checklist"][@"doneCount"] integerValue], (NSInteger)1);
}

#pragma mark - story

- (void)testStory_FullStoryKeepsPosterAndChatIds {
	NSDictionary *out = TGFlattenInteractiveContent(@{
		@"@type"               : @"messageStory",
		@"story_poster_chat_id": @"-1001234567890",
		@"story_id"            : @5,
		@"via_mention"         : @YES,
	});
	NSDictionary *story = out[@"story"];
	XCTAssertEqual([story[@"posterChatId"] longLongValue], -1001234567890LL);
	XCTAssertEqual([story[@"storyId"] integerValue], (NSInteger)5);
	XCTAssertTrue([story[@"viaMention"] boolValue]);
}

- (void)testStory_MinimalStoryDefaults {
	NSDictionary *out = TGFlattenInteractiveContent(@{@"@type" : @"messageStory"});
	NSDictionary *story = out[@"story"];
	XCTAssertEqual([story[@"posterChatId"] longLongValue], 0LL);
	XCTAssertEqual([story[@"storyId"] integerValue], (NSInteger)0);
	XCTAssertFalse([story[@"viaMention"] boolValue]);
}

- (void)testStory_StringStoryIdAndNoMention {
	NSDictionary *out = TGFlattenInteractiveContent(@{
		@"@type"    : @"messageStory",
		@"story_id" : @"123",
	});
	XCTAssertEqual([out[@"story"][@"storyId"] integerValue], (NSInteger)123);
	XCTAssertFalse([out[@"story"][@"viaMention"] boolValue]);
}

#pragma mark - game

- (void)testGame_FullGameUsesLargestPhotoAndAnimationFile {
	NSDictionary *out = TGFlattenInteractiveContent(@{
		@"@type": @"messageGame",
		@"game" : @{
			@"@type"      : @"game",
			@"id"         : @"5368324170671202286",
			@"short_name" : @"tetris",
			@"title"      : @"Tetris",
			@"description": @"Stack the blocks",
			@"photo"      : @{@"@type" : @"photo", @"sizes" : @[
				@{@"photo" : @{@"id" : @11}},
				@{@"photo" : @{@"id" : @22}},
			]},
			@"animation"  : @{@"@type" : @"animation",
							  @"animation" : @{@"@type" : @"file", @"id" : @33}},
		},
	});
	NSDictionary *game = out[@"game"];
	XCTAssertEqual([game[@"gameId"] longLongValue], 5368324170671202286LL);
	XCTAssertEqualObjects(game[@"shortName"], @"tetris");
	XCTAssertEqualObjects(game[@"title"], @"Tetris");
	XCTAssertEqualObjects(game[@"description"], @"Stack the blocks");
	XCTAssertEqual([game[@"photoFileId"] longLongValue], 22LL);
	XCTAssertEqual([game[@"animationFileId"] longLongValue], 33LL);
}

- (void)testGame_GameWithoutMediaDefaultsToZero {
	NSDictionary *out = TGFlattenInteractiveContent(@{
		@"@type": @"messageGame",
		@"game" : @{@"@type" : @"game", @"id" : @1},
	});
	NSDictionary *game = out[@"game"];
	XCTAssertEqual([game[@"photoFileId"] longLongValue], 0LL);
	XCTAssertEqual([game[@"animationFileId"] longLongValue], 0LL);
	XCTAssertEqualObjects(game[@"description"], @"");
}

- (void)testGame_NoGameObjectStillBuildsEmptyGame {
	NSDictionary *out = TGFlattenInteractiveContent(@{@"@type" : @"messageGame"});
	NSDictionary *game = out[@"game"];
	XCTAssertTrue([game isKindOfClass:NSDictionary.class]);
	XCTAssertEqual([game[@"gameId"] longLongValue], 0LL);
	XCTAssertEqualObjects(game[@"title"], @"");
	XCTAssertEqual([game[@"animationFileId"] longLongValue], 0LL);
}

#pragma mark - dice

- (void)testDice_FullThrowKeepsValueAndSuccessFrame {
	NSDictionary *out = TGFlattenInteractiveContent(@{
		@"@type"                       : @"messageDice",
		@"emoji"                       : @"\U0001F3B2",
		@"value"                       : @6,
		@"success_animation_frame_number": @12,
	});
	NSDictionary *dice = out[@"dice"];
	XCTAssertEqualObjects(dice[@"emoji"], @"\U0001F3B2");
	XCTAssertEqual([dice[@"value"] integerValue], (NSInteger)6);
	XCTAssertEqual([dice[@"successAnimationFrame"] integerValue], (NSInteger)12);
}

- (void)testDice_MinimalThrowDefaults {
	NSDictionary *out = TGFlattenInteractiveContent(@{@"@type" : @"messageDice"});
	NSDictionary *dice = out[@"dice"];
	XCTAssertEqualObjects(dice[@"emoji"], @"");
	XCTAssertEqual([dice[@"value"] integerValue], (NSInteger)0);
	XCTAssertEqual([dice[@"successAnimationFrame"] integerValue], (NSInteger)0);
}

- (void)testDice_SuccessFrameIsIndependentOfValue {
	NSDictionary *out = TGFlattenInteractiveContent(@{
		@"@type"                       : @"messageDice",
		@"emoji"                       : @"\U0001F3AF",
		@"value"                       : @3,
		@"success_animation_frame_number": @0,
	});
	XCTAssertEqual([out[@"dice"][@"value"] integerValue], (NSInteger)3);
	XCTAssertEqual([out[@"dice"][@"successAnimationFrame"] integerValue], (NSInteger)0);
}

- (void)testDice_RegularStickerKeepsFileAndFormat {
	NSDictionary *out = TGFlattenInteractiveContent(@{
		@"@type"       : @"messageDice",
		@"emoji"       : @"\U0001F3B2",
		@"value"       : @5,
		@"final_state" : dcDiceRegular(dcDiceSticker(@7001, @"stickerFormatTgs")),
	});
	NSDictionary *dice = out[@"dice"];
	XCTAssertEqual([dice[@"stickerFileId"] longLongValue], 7001LL);
	XCTAssertEqualObjects(dice[@"stickerFormat"], @"tgs");
}

- (void)testDice_SlotMachineUsesBackgroundSticker {
	NSDictionary *out = TGFlattenInteractiveContent(@{
		@"@type"       : @"messageDice",
		@"final_state" : dcDiceSlotMachine(dcDiceSticker(@"9001", @"stickerFormatWebm")),
	});
	NSDictionary *dice = out[@"dice"];
	XCTAssertEqual([dice[@"stickerFileId"] longLongValue], 9001LL);
	XCTAssertEqualObjects(dice[@"stickerFormat"], @"webm");
}

- (void)testDice_MissingFinalStateUsesInitialState {
	NSDictionary *out = TGFlattenInteractiveContent(@{
		@"@type"         : @"messageDice",
		@"initial_state" : dcDiceRegular(dcDiceSticker(@8001, @"stickerFormatTgs")),
	});
	NSDictionary *dice = out[@"dice"];
	XCTAssertEqual([dice[@"stickerFileId"] longLongValue], 8001LL);
	XCTAssertEqualObjects(dice[@"stickerFormat"], @"tgs");
}

- (void)testDice_NullFinalStateFallsBackToInitialState {
	NSDictionary *out = TGFlattenInteractiveContent(@{
		@"@type"         : @"messageDice",
		@"final_state"   : [NSNull null],
		@"initial_state" : dcDiceRegular(dcDiceSticker(@8002, @"stickerFormatWebp")),
	});
	NSDictionary *dice = out[@"dice"];
	XCTAssertEqual([dice[@"stickerFileId"] longLongValue], 8002LL);
	XCTAssertEqualObjects(dice[@"stickerFormat"], @"webp");
}

- (void)testDice_NullStickerFieldsDefaultToZero {
	NSDictionary *out = TGFlattenInteractiveContent(@{
		@"@type"       : @"messageDice",
		@"emoji"       : [NSNull null],
		@"value"       : [NSNull null],
		@"final_state" : dcDiceRegular(@{
			@"@type"   : @"sticker",
			@"sticker" : [NSNull null],
			@"format"  : [NSNull null],
		}),
	});
	NSDictionary *dice = out[@"dice"];
	XCTAssertEqual([dice[@"stickerFileId"] longLongValue], 0LL);
	XCTAssertEqualObjects(dice[@"stickerFormat"], @"");
	XCTAssertEqualObjects(dice[@"emoji"], @"");
	XCTAssertEqual([dice[@"value"] integerValue], (NSInteger)0);
}

- (void)testDice_NoStatesDefaultsToZero {
	NSDictionary *out = TGFlattenInteractiveContent(@{@"@type" : @"messageDice"});
	NSDictionary *dice = out[@"dice"];
	XCTAssertEqual([dice[@"stickerFileId"] longLongValue], 0LL);
	XCTAssertEqualObjects(dice[@"stickerFormat"], @"");
}

- (void)testDice_NullBackgroundAndUnknownFormatDefaultToZero {
	NSDictionary *out = TGFlattenInteractiveContent(@{
		@"@type"       : @"messageDice",
		@"final_state" : @{@"@type" : @"diceStickersSlotMachine",
						   @"background" : [NSNull null]},
	});
	NSDictionary *dice = out[@"dice"];
	XCTAssertEqual([dice[@"stickerFileId"] longLongValue], 0LL);
	XCTAssertEqualObjects(dice[@"stickerFormat"], @"");
}

- (void)testDice_FinalStateWinsOverInitialState {
	NSDictionary *out = TGFlattenInteractiveContent(@{
		@"@type"         : @"messageDice",
		@"final_state"   : dcDiceRegular(dcDiceSticker(@8501, @"stickerFormatTgs")),
		@"initial_state" : dcDiceRegular(dcDiceSticker(@8502, @"stickerFormatWebm")),
	});
	NSDictionary *dice = out[@"dice"];
	XCTAssertEqual([dice[@"stickerFileId"] longLongValue], 8501LL);
	XCTAssertEqualObjects(dice[@"stickerFormat"], @"tgs");
}

#pragma mark - expired media

- (void)testExpired_Photo {
	NSDictionary *out = TGFlattenInteractiveContent(@{@"@type" : @"messageExpiredPhoto"});
	XCTAssertEqualObjects(out[@"expiredKind"], @"photo");
}

- (void)testExpired_Video {
	NSDictionary *out = TGFlattenInteractiveContent(@{@"@type" : @"messageExpiredVideo"});
	XCTAssertEqualObjects(out[@"expiredKind"], @"video");
}

- (void)testExpired_VideoNote {
	NSDictionary *out = TGFlattenInteractiveContent(@{@"@type" : @"messageExpiredVideoNote"});
	XCTAssertEqualObjects(out[@"expiredKind"], @"videoNote");
}

- (void)testExpired_VoiceNote {
	NSDictionary *out = TGFlattenInteractiveContent(@{@"@type" : @"messageExpiredVoiceNote"});
	XCTAssertEqualObjects(out[@"expiredKind"], @"voiceNote");
}

#pragma mark - everything else

- (void)testPlainContent_ReturnsNil {
	XCTAssertTrue(TGFlattenInteractiveContent(@{
		@"@type": @"messageText",
		@"text" : @{@"@type" : @"formattedText", @"text" : @"hello"},
	}) == nil);
}

- (void)testPhotoContent_ReturnsNil {
	XCTAssertTrue(TGFlattenInteractiveContent(@{
		@"@type": @"messagePhoto",
		@"photo": @{@"@type" : @"photo", @"sizes" : @[]},
	}) == nil);
}

@end
