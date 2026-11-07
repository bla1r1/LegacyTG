//
// TGMessageContentInteractive.m - polls, shared chats, group calls, checklists,
// stories, games, dice and expired media, in the shape a screen can draw.
//
// TDLib nests these under their own objects, and every integer id may arrive
// as a JSON string. This file reads them once so callers never have to.
//
#import "TGMessageContentInteractive.h"

static NSString *TGInteractiveString(id value) {
	return [value isKindOfClass:NSString.class] ? value : @"";
}

/// A formattedText carries a plain string in `text`; rich text objects nest
/// their runs one level down. Recursing costs nothing and covers both.
static NSString *TGInteractiveText(id value) {
	if ([value isKindOfClass:NSString.class])
		return value;
	if (![value isKindOfClass:NSDictionary.class])
		return @"";
	id inner = value[@"text"];
	if ([inner isKindOfClass:NSString.class])
		return inner;
	if ([inner isKindOfClass:NSDictionary.class])
		return TGInteractiveText(inner);
	return @"";
}

/// Entities carried alongside formattedText, or nil when none are present.
static NSArray *TGInteractiveEntities(id value) {
	if (![value isKindOfClass:NSDictionary.class])
		return @[];
	id entities = value[@"entities"];
	if ([entities isKindOfClass:NSArray.class])
		return entities;
	id inner = value[@"text"];
	if ([inner isKindOfClass:NSDictionary.class]) {
		id innerEntities = inner[@"entities"];
		if ([innerEntities isKindOfClass:NSArray.class])
			return innerEntities;
	}
	return @[];
}

static NSNumber *TGInteractiveInt64(id value) {
	return @([value longLongValue]);
}

static NSNumber *TGInteractiveBool(id value) {
	return @([value boolValue]);
}

/// A dice throw carries the sticker Telegram plays in its final state, and the
/// rolling one in initial_state until the throw lands. A slot machine's
/// background is the sticker that stands for the whole machine.
static NSDictionary *TGInteractiveDiceSticker(id state) {
	NSDictionary *dice = [state isKindOfClass:NSDictionary.class] ? state : nil;
	NSString *kind = [dice[@"@type"] isKindOfClass:NSString.class] ? dice[@"@type"] : @"";
	NSDictionary *sticker = nil;
	if ([kind isEqualToString:@"diceStickersRegular"])
		sticker = dice[@"sticker"];
	else if ([kind isEqualToString:@"diceStickersSlotMachine"])
		sticker = dice[@"background"];
	return [sticker isKindOfClass:NSDictionary.class] ? sticker : nil;
}

static NSString *TGInteractiveStickerFormat(NSDictionary *sticker) {
	NSString *format = [sticker[@"format"][@"@type"] isKindOfClass:NSString.class]
			? sticker[@"format"][@"@type"] : @"";
	if ([format isEqualToString:@"stickerFormatTgs"])
		return @"tgs";
	if ([format isEqualToString:@"stickerFormatWebm"])
		return @"webm";
	if ([format isEqualToString:@"stickerFormatWebp"])
		return @"webp";
	return @"";
}

/// A photo's sizes are ordered smallest first, so either end is a direct
/// lookup. Missing photos still get a 0 so the key is never NSNull.
static NSNumber *TGInteractivePhotoFileId(id photo, BOOL largest) {
	NSArray *sizes = [photo isKindOfClass:NSDictionary.class] ? photo[@"sizes"] : nil;
	if (![sizes isKindOfClass:NSArray.class] || !sizes.count)
		return @0;
	NSDictionary *size = [sizes objectAtIndex:(largest ? sizes.count - 1 : 0)];
	id fileId = [size isKindOfClass:NSDictionary.class] ? size[@"photo"][@"id"] : nil;
	return fileId ? TGInteractiveInt64(fileId) : @0;
}

/// MessageSender is either a user or a chat; only user ids belong in these
/// lists, a chat sender contributes 0 rather than a wrong id.
static NSArray *TGInteractiveUserIds(id senders) {
	NSMutableArray *ids = [NSMutableArray array];
	if (![senders isKindOfClass:NSArray.class])
		return ids;
	for (id sender in senders) {
		if (![sender isKindOfClass:NSDictionary.class])
			continue;
		[ids addObject:TGInteractiveInt64(sender[@"user_id"])];
	}
	return ids;
}

static NSDictionary *TGInteractivePoll(id rawPoll, id rawDescription) {
	NSDictionary *poll = [rawPoll isKindOfClass:NSDictionary.class] ? rawPoll : @{};

	NSMutableArray *options = [NSMutableArray array];
	id rawOptions = poll[@"options"];
	if ([rawOptions isKindOfClass:NSArray.class]) {
		for (id raw in rawOptions) {
			if (![raw isKindOfClass:NSDictionary.class])
				continue;
			NSArray *optEntities = TGInteractiveEntities(raw[@"text"]);
			if (!optEntities.count)
				optEntities = TGInteractiveEntities(raw);
			[options addObject:@{
				@"text"          : TGInteractiveText(raw[@"text"]),
				@"entities"      : optEntities,
				@"voterCount"    : TGInteractiveInt64(raw[@"voter_count"]),
				@"percent"       : TGInteractiveInt64(raw[@"vote_percentage"]),
				@"isChosen"      : TGInteractiveBool(raw[@"is_chosen"]),
				@"isBeingChosen" : TGInteractiveBool(raw[@"is_being_chosen"]),
			}];
		}
	}

	NSDictionary *type = [poll[@"type"] isKindOfClass:NSDictionary.class] ? poll[@"type"] : @{};
	BOOL isQuiz = [type[@"@type"] isEqualToString:@"pollTypeQuiz"];
	NSNumber *correctOption = @(-1);
	NSString *explanation = @"";
	if (isQuiz) {
		// This schema lists correct answers as a vector; the first one is the
		// option the quiz screen highlights. -1 stays for an unanswered poll.
		NSArray *correctIds = type[@"correct_option_ids"];
		if ([correctIds isKindOfClass:NSArray.class] && correctIds.count)
			correctOption = TGInteractiveInt64([correctIds objectAtIndex:0]);
		explanation = TGInteractiveText(type[@"explanation"]);
	}

	return @{
		@"pollId"          : TGInteractiveInt64(poll[@"id"]),
		@"question"        : TGInteractiveText(poll[@"question"]),
		@"questionEntities": TGInteractiveEntities(poll[@"question"]),
		@"options"         : options,
		@"totalVoterCount": TGInteractiveInt64(poll[@"total_voter_count"]),
		@"isAnonymous"    : TGInteractiveBool(poll[@"is_anonymous"]),
		@"isClosed"       : TGInteractiveBool(poll[@"is_closed"]),
		@"isQuiz"         : @(isQuiz),
		@"allowsMultiple" : TGInteractiveBool(poll[@"allows_multiple_answers"]),
		@"allowsRevoting" : TGInteractiveBool(poll[@"allows_revoting"]),
		@"description"    : TGInteractiveText(rawDescription),
		@"correctOption"  : correctOption,
		@"explanation"    : explanation,
		@"recentVoterIds" : TGInteractiveUserIds(poll[@"recent_voter_ids"]),
		@"openPeriod"     : TGInteractiveInt64(poll[@"open_period"]),
		@"closeDate"      : TGInteractiveInt64(poll[@"close_date"]),
	};
}

static NSDictionary *TGInteractiveSharedUser(id rawUser) {
	NSDictionary *user = [rawUser isKindOfClass:NSDictionary.class] ? rawUser : @{};
	return @{
		@"userId"      : TGInteractiveInt64(user[@"user_id"]),
		@"firstName"   : TGInteractiveString(user[@"first_name"]),
		@"lastName"    : TGInteractiveString(user[@"last_name"]),
		@"username"    : TGInteractiveString(user[@"username"]),
		@"photoFileId" : TGInteractivePhotoFileId(user[@"photo"], NO),
	};
}

static NSDictionary *TGInteractiveSharedChat(id rawChat) {
	NSDictionary *chat = [rawChat isKindOfClass:NSDictionary.class] ? rawChat : @{};
	return @{
		@"chatId"      : TGInteractiveInt64(chat[@"chat_id"]),
		@"title"       : TGInteractiveString(chat[@"title"]),
		@"username"    : TGInteractiveString(chat[@"username"]),
		@"photoFileId" : TGInteractivePhotoFileId(chat[@"photo"], NO),
	};
}

/// The four call contents describe different moments of the same thing. Each
/// one fills what it knows and leaves the rest at a harmless default.
static NSDictionary *TGInteractiveGroupCall(NSDictionary *content, NSString *type) {
	NSNumber *callId = @0;
	NSNumber *isActive = @NO;
	NSNumber *isVideo = @NO;
	NSNumber *duration = @0;
	NSNumber *startDate = @0;
	NSNumber *wasMissed = @NO;
	NSArray *participants = @[];

	if ([type isEqualToString:@"messageGroupCall"]) {
		// This content has no group_call_id; unique_id is the persistent id
		// the call screen can pass back to TDLib.
		callId = TGInteractiveInt64(content[@"unique_id"]);
		isActive = TGInteractiveBool(content[@"is_active"]);
		isVideo = TGInteractiveBool(content[@"is_video"]);
		duration = TGInteractiveInt64(content[@"duration"]);
		wasMissed = TGInteractiveBool(content[@"was_missed"]);
		participants = TGInteractiveUserIds(content[@"other_participant_ids"]);
	} else if ([type isEqualToString:@"messageVideoChatScheduled"]) {
		callId = TGInteractiveInt64(content[@"group_call_id"]);
		startDate = TGInteractiveInt64(content[@"start_date"]);
		isVideo = @YES;
	} else if ([type isEqualToString:@"messageVideoChatStarted"]) {
		callId = TGInteractiveInt64(content[@"group_call_id"]);
		isActive = @YES;
		isVideo = @YES;
	} else if ([type isEqualToString:@"messageVideoChatEnded"]) {
		duration = TGInteractiveInt64(content[@"duration"]);
		isVideo = @YES;
	}

	return @{@"groupCall" : @{
		@"groupCallId"        : callId,
		@"isActive"           : isActive,
		@"isVideo"            : isVideo,
		@"duration"           : duration,
		@"startDate"          : startDate,
		@"wasMissed"          : wasMissed,
		@"otherParticipantIds": participants,
	}};
}

static NSDictionary *TGInteractiveChecklist(id rawList) {
	NSDictionary *list = [rawList isKindOfClass:NSDictionary.class] ? rawList : @{};
	NSMutableArray *tasks = [NSMutableArray array];
	NSArray *rawTasks = [list[@"tasks"] isKindOfClass:NSArray.class] ? list[@"tasks"] : @[];
	NSInteger doneCount = 0;

	for (id raw in rawTasks) {
		if (![raw isKindOfClass:NSDictionary.class])
			continue;
		// completion is stored as a MessageSender; 0 stays for a chat sender.
		NSDictionary *completedBy = [raw[@"completed_by"] isKindOfClass:NSDictionary.class]
				? raw[@"completed_by"] : nil;
		if (completedBy)
			doneCount++;
		NSArray *taskEntities = TGInteractiveEntities(raw[@"text"]);
		if (!taskEntities.count)
			taskEntities = TGInteractiveEntities(raw);
		[tasks addObject:@{
			@"taskId"            : TGInteractiveInt64(raw[@"id"]),
			@"text"              : TGInteractiveText(raw[@"text"]),
			@"entities"          : taskEntities,
			@"completedByUserId" : completedBy ? TGInteractiveInt64(completedBy[@"user_id"]) : @0,
			@"completionDate"    : TGInteractiveInt64(raw[@"completion_date"]),
		}];
	}

	return @{@"checklist" : @{
		@"title"                   : TGInteractiveText(list[@"title"]),
		@"titleEntities"           : TGInteractiveEntities(list[@"title"]),
		@"tasks"                   : tasks,
		@"othersCanAddTasks"       : TGInteractiveBool(list[@"others_can_add_tasks"]),
		@"othersCanMarkTasksAsDone": TGInteractiveBool(list[@"others_can_mark_tasks_as_done"]),
		@"canAddTasks"             : TGInteractiveBool(list[@"can_add_tasks"]),
		@"canMarkTasksAsDone"      : TGInteractiveBool(list[@"can_mark_tasks_as_done"]),
		@"doneCount"               : @(doneCount),
		@"totalCount"              : @(rawTasks.count),
	}};
}

static NSDictionary *TGInteractiveGame(id rawGame) {
	NSDictionary *game = [rawGame isKindOfClass:NSDictionary.class] ? rawGame : @{};
	NSNumber *animationFileId = @0;
	id animation = game[@"animation"];
	if ([animation isKindOfClass:NSDictionary.class]) {
		id fileId = animation[@"animation"][@"id"];
		if (fileId)
			animationFileId = TGInteractiveInt64(fileId);
	}
	return @{@"game" : @{
		@"gameId"         : TGInteractiveInt64(game[@"id"]),
		@"shortName"      : TGInteractiveString(game[@"short_name"]),
		@"title"          : TGInteractiveString(game[@"title"]),
		@"description"    : TGInteractiveString(game[@"description"]),
		@"photoFileId"    : TGInteractivePhotoFileId(game[@"photo"], YES),
		@"animationFileId": animationFileId,
	}};
}

NSDictionary *TGFlattenInteractiveContent(NSDictionary *content) {
	if (![content isKindOfClass:NSDictionary.class])
		return nil;
	NSString *type = content[@"@type"];
	if (![type isKindOfClass:NSString.class])
		return nil;

	if ([type isEqualToString:@"messagePoll"])
		return @{@"poll" : TGInteractivePoll(content[@"poll"], content[@"description"])};

	if ([type isEqualToString:@"messagePinMessage"])
		return @{@"pinnedMessageId" : TGInteractiveInt64(content[@"message_id"])};

	if ([type isEqualToString:@"messageUsersShared"]) {
		NSMutableArray *users = [NSMutableArray array];
		id rawUsers = content[@"users"];
		if ([rawUsers isKindOfClass:NSArray.class]) {
			for (id raw in rawUsers)
				[users addObject:TGInteractiveSharedUser(raw)];
		}
		return @{
			@"sharedUsers"    : users,
			@"sharedButtonId" : TGInteractiveInt64(content[@"button_id"]),
		};
	}

	if ([type isEqualToString:@"messageChatShared"])
		return @{
			@"sharedChat"     : TGInteractiveSharedChat(content[@"chat"]),
			@"sharedButtonId" : TGInteractiveInt64(content[@"button_id"]),
		};

	if ([type isEqualToString:@"messageGroupCall"] ||
		[type isEqualToString:@"messageVideoChatStarted"] ||
		[type isEqualToString:@"messageVideoChatScheduled"] ||
		[type isEqualToString:@"messageVideoChatEnded"])
		return TGInteractiveGroupCall(content, type);

	if ([type isEqualToString:@"messageChecklist"])
		return TGInteractiveChecklist(content[@"list"]);

	if ([type isEqualToString:@"messageStory"])
		return @{@"story" : @{
			@"posterChatId": TGInteractiveInt64(content[@"story_poster_chat_id"]),
			@"storyId"     : TGInteractiveInt64(content[@"story_id"]),
			@"viaMention"  : TGInteractiveBool(content[@"via_mention"]),
		}};

	if ([type isEqualToString:@"messageGame"])
		return TGInteractiveGame(content[@"game"]);

	if ([type isEqualToString:@"messageDice"]){
		NSDictionary *state = [content[@"final_state"] isKindOfClass:NSDictionary.class]
				? content[@"final_state"] : content[@"initial_state"];
		NSDictionary *sticker = TGInteractiveDiceSticker(state);
		id fileId = sticker[@"sticker"][@"id"];
		NSNumber *stickerFileId = ([fileId isKindOfClass:NSNumber.class] ||
				[fileId isKindOfClass:NSString.class])
				? TGInteractiveInt64(fileId) : @0;
		return @{@"dice" : @{
			@"emoji"                : TGInteractiveString(content[@"emoji"]),
			@"value"                : TGInteractiveInt64(content[@"value"]),
			@"successAnimationFrame": TGInteractiveInt64(content[@"success_animation_frame_number"]),
			@"stickerFileId"        : stickerFileId,
			@"stickerFormat"        : TGInteractiveStickerFormat(sticker),
		}};
	}

	if ([type isEqualToString:@"messageExpiredPhoto"])
		return @{@"expiredKind" : @"photo"};
	if ([type isEqualToString:@"messageExpiredVideo"])
		return @{@"expiredKind" : @"video"};
	if ([type isEqualToString:@"messageExpiredVideoNote"])
		return @{@"expiredKind" : @"videoNote"};
	if ([type isEqualToString:@"messageExpiredVoiceNote"])
		return @{@"expiredKind" : @"voiceNote"};

	return nil;
}
