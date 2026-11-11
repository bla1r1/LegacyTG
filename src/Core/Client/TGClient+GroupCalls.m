//
// TGClient+GroupCalls.m - group calls and video chats on the wire.
//
// Every request here names a group call id or the chat a video chat belongs
// to. TDLib answers a whole groupCall record, an opaque join payload, or
// bytes; the flattening below turns the record into the keys the two call
// screens read. Participants arrive as updates, so they are kept per call and
// handed to the screen through one notification instead of a polling loop.
//
#import "TGClient+GroupCalls.h"
#import "TGClientInternal.h"
#import "TGBase64.h"
#import <objc/runtime.h>

NSString * const TGGroupCallChangedNotification = @"TGGroupCallChanged";
NSString * const TGGroupCallParticipantsChangedNotification = @"TGGroupCallParticipantsChanged";
NSString * const TGGroupCallMessagesChangedNotification = @"TGGroupCallMessagesChanged";

NSString * const TGGroupCallIdKey = @"groupCallId";
NSString * const TGGroupCallValueKey = @"value";
NSString * const TGGroupCallErrorKey = @"error";

NSDictionary *TGGroupCallJoinParameters(int32_t audioSourceId, NSString *payload,
		BOOL muted, BOOL videoEnabled) {
	return @{
		@"@type" : @"groupCallJoinParameters",
		@"audio_source_id" : @(audioSourceId),
		@"payload" : payload ?: @"",
		@"is_muted" : @(muted),
		@"is_my_video_enabled" : @(videoEnabled),
	};
}

NSDictionary *TGGroupCallInput(int32_t groupCallId, int64_t accessHash) {
	return @{
		@"@type" : @"inputGroupCall",
		@"id" : @(groupCallId),
		@"access_hash" : @(accessHash),
	};
}

#pragma mark - helpers

static NSDictionary *TGGCDict(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : @{};
}

static NSArray *TGGCArray(id value) {
	return [value isKindOfClass:NSArray.class] ? value : @[];
}

/// The sender's identity as one dictionary key. Chat participants (a channel
/// posting into a group call) and users share the participant list, so the
/// type has to be part of the key or two id 42s would overwrite each other.
static NSString *TGGCSenderKey(NSDictionary *sender) {
	if ([sender[@"@type"] isEqualToString:@"messageSenderChat"])
		return [NSString stringWithFormat:@"c:%lld",
				[sender[@"chat_id"] longLongValue]];
	return [NSString stringWithFormat:@"u:%lld",
			[sender[@"user_id"] longLongValue]];
}

static NSDictionary *TGGCSenderOrNull(id sender) {
	return [sender isKindOfClass:NSDictionary.class] ? sender : (id)[NSNull null];
}

static NSDictionary *TGGCSenderFlatten(TGClient *client, NSDictionary *sender) {
	NSDictionary *raw = [sender isKindOfClass:NSDictionary.class] ? sender : @{};
	if ([raw[@"@type"] isEqualToString:@"messageSenderChat"]){
		int64_t chatId = [raw[@"chat_id"] longLongValue];
		NSString *name = [client titleForChat:chatId] ?: @"";
		return @{
			@"sender" : raw,
			@"senderKey" : TGGCSenderKey(raw),
			@"userId" : @(0),
			@"chatId" : @(chatId),
			@"kind" : @"chat",
			@"name" : name,
			@"photoFileId" : [client photoFileIdForChat:chatId] ?: [NSNull null],
		};
	}
	int64_t userId = [raw[@"user_id"] longLongValue];
	NSString *name = [client nameForUserId:userId] ?: @"";
	if (!name.length && [client.me[@"id"] longLongValue] == userId)
		name = [NSString stringWithFormat:@"%@ %@", client.me[@"first_name"] ?: @"",
				client.me[@"last_name"] ?: @""];
	return @{
		@"sender" : raw,
		@"senderKey" : TGGCSenderKey(raw),
		@"userId" : @(userId),
		@"chatId" : @(0),
		@"kind" : @"user",
		@"name" : [name stringByTrimmingCharactersInSet:
				[NSCharacterSet whitespaceCharacterSet]],
		@"photoFileId" : [client photoFileIdForUserId:userId] ?: [NSNull null],
	};
}

#pragma mark - the per-call state

static char TGGroupCallStateKey;

static NSMutableDictionary *TGGCState(TGClient *client) {
	NSMutableDictionary *state = objc_getAssociatedObject(client, &TGGroupCallStateKey);
	if (![state isKindOfClass:NSMutableDictionary.class]){
		state = [NSMutableDictionary dictionaryWithDictionary:@{
			@"calls" : [NSMutableDictionary dictionary],
			@"participants" : [NSMutableDictionary dictionary],
			@"messages" : [NSMutableDictionary dictionary],
		}];
		objc_setAssociatedObject(client, &TGGroupCallStateKey, state,
				OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	return state;
}

static NSMutableDictionary *TGGCCalls(TGClient *client) {
	return TGGCState(client)[@"calls"];
}

static NSMutableDictionary *TGGCParticipants(TGClient *client, int32_t callId) {
	NSMutableDictionary *all = TGGCState(client)[@"participants"];
	NSNumber *key = @(callId);
	NSMutableDictionary *rows = all[key];
	if (!rows){
		rows = [NSMutableDictionary dictionary];
		all[key] = rows;
	}
	return rows;
}

static NSMutableArray *TGGCMessages(TGClient *client, int32_t callId) {
	NSMutableDictionary *all = TGGCState(client)[@"messages"];
	NSNumber *key = @(callId);
	NSMutableArray *rows = all[key];
	if (!rows){
		rows = [NSMutableArray array];
		all[key] = rows;
	}
	return rows;
}

/// One groupCall record as the screens read it. The raw record is kept under
/// "raw" so a screen that needs a field this list has not grown yet does not
/// have to make a second request.
static NSDictionary *TGGCFlattenCall(NSDictionary *call) {
	NSDictionary *raw = [call isKindOfClass:NSDictionary.class] ? call : @{};
	NSMutableArray *speakers = [NSMutableArray array];
	for (NSDictionary *speaker in TGGCArray(raw[@"recent_speakers"])){
		NSDictionary *row = TGGCDict(speaker);
		[speakers addObject:@{
			@"sender" : TGGCSenderOrNull(row[@"participant_id"]),
			@"isSpeaking" : @([row[@"is_speaking"] boolValue]),
		}];
	}
	return @{
		@"callId" : @([raw[@"id"] intValue]),
		@"uniqueId" : @([raw[@"unique_id"] longLongValue]),
		@"title" : raw[@"title"] ?: @"",
		@"inviteLink" : raw[@"invite_link"] ?: @"",
		@"paidMessageStarCount" : @([raw[@"paid_message_star_count"] longLongValue]),
		@"scheduledStartDate" : @([raw[@"scheduled_start_date"] intValue]),
		@"enabledStartNotification" : @([raw[@"enabled_start_notification"] boolValue]),
		@"isActive" : @([raw[@"is_active"] boolValue]),
		@"isVideoChat" : @([raw[@"is_video_chat"] boolValue]),
		@"isLiveStory" : @([raw[@"is_live_story"] boolValue]),
		@"isRtmpStream" : @([raw[@"is_rtmp_stream"] boolValue]),
		@"isJoined" : @([raw[@"is_joined"] boolValue]),
		@"needRejoin" : @([raw[@"need_rejoin"] boolValue]),
		@"isOwned" : @([raw[@"is_owned"] boolValue]),
		@"canBeManaged" : @([raw[@"can_be_managed"] boolValue]),
		@"participantCount" : @([raw[@"participant_count"] intValue]),
		@"hasHiddenListeners" : @([raw[@"has_hidden_listeners"] boolValue]),
		@"loadedAllParticipants" : @([raw[@"loaded_all_participants"] boolValue]),
		@"messageSender" : TGGCSenderOrNull(raw[@"message_sender_id"]),
		@"recentSpeakers" : speakers,
		@"isMyVideoEnabled" : @([raw[@"is_my_video_enabled"] boolValue]),
		@"isMyVideoPaused" : @([raw[@"is_my_video_paused"] boolValue]),
		@"canEnableVideo" : @([raw[@"can_enable_video"] boolValue]),
		@"muteNewParticipants" : @([raw[@"mute_new_participants"] boolValue]),
		@"canToggleMuteNewParticipants" : @([raw[@"can_toggle_mute_new_participants"] boolValue]),
		@"canSendMessages" : @([raw[@"can_send_messages"] boolValue]),
		@"areMessagesAllowed" : @([raw[@"are_messages_allowed"] boolValue]),
		@"canToggleAreMessagesAllowed" : @([raw[@"can_toggle_are_messages_allowed"] boolValue]),
		@"canDeleteMessages" : @([raw[@"can_delete_messages"] boolValue]),
		@"recordDuration" : @([raw[@"record_duration"] intValue]),
		@"isVideoRecorded" : @([raw[@"is_video_recorded"] boolValue]),
		@"duration" : @([raw[@"duration"] intValue]),
		@"raw" : raw,
	};
}

static NSDictionary *TGGCVideoInfo(id value) {
	NSDictionary *info = [value isKindOfClass:NSDictionary.class] ? value : nil;
	if (!info)
		return @{@"hasVideo" : @NO, @"isPaused" : @NO, @"sources" : @[]};
	NSMutableArray *sources = [NSMutableArray array];
	for (NSDictionary *group in TGGCArray(info[@"source_groups"])){
		NSDictionary *row = TGGCDict(group);
		[sources addObject:@{
			@"semantics" : row[@"semantics"] ?: @"",
			@"sourceIds" : TGGCArray(row[@"source_ids"]),
		}];
	}
	return @{
		@"hasVideo" : @YES,
		@"isPaused" : @([info[@"is_paused"] boolValue]),
		@"endpointId" : info[@"endpoint_id"] ?: @"",
		@"sources" : sources,
	};
}

static NSDictionary *TGGCFlattenParticipant(TGClient *client, NSDictionary *participant) {
	NSDictionary *raw = [participant isKindOfClass:NSDictionary.class] ? participant : @{};
	NSDictionary *sender = TGGCSenderFlatten(client, TGGCDict(raw[@"participant_id"]));
	NSDictionary *video = TGGCVideoInfo(raw[@"video_info"]);
	NSDictionary *screen = TGGCVideoInfo(raw[@"screen_sharing_video_info"]);
	NSMutableDictionary *row = [NSMutableDictionary dictionaryWithDictionary:sender];
	row[@"audioSourceId"] = @([raw[@"audio_source_id"] intValue]);
	row[@"screenAudioSourceId"] = @([raw[@"screen_sharing_audio_source_id"] intValue]);
	row[@"bio"] = raw[@"bio"] ?: @"";
	row[@"isCurrentUser"] = @([raw[@"is_current_user"] boolValue]);
	row[@"isSpeaking"] = @([raw[@"is_speaking"] boolValue]);
	row[@"isHandRaised"] = @([raw[@"is_hand_raised"] boolValue]);
	row[@"canBeMutedForAllUsers"] = @([raw[@"can_be_muted_for_all_users"] boolValue]);
	row[@"canBeUnmutedForAllUsers"] = @([raw[@"can_be_unmuted_for_all_users"] boolValue]);
	row[@"canBeMutedForCurrentUser"] = @([raw[@"can_be_muted_for_current_user"] boolValue]);
	row[@"canBeUnmutedForCurrentUser"] = @([raw[@"can_be_unmuted_for_current_user"] boolValue]);
	row[@"isMutedForAllUsers"] = @([raw[@"is_muted_for_all_users"] boolValue]);
	row[@"isMutedForCurrentUser"] = @([raw[@"is_muted_for_current_user"] boolValue]);
	row[@"canUnmuteSelf"] = @([raw[@"can_unmute_self"] boolValue]);
	row[@"volumeLevel"] = @([raw[@"volume_level"] intValue]);
	row[@"order"] = raw[@"order"] ?: @"";
	row[@"hasVideo"] = video[@"hasVideo"];
	row[@"videoPaused"] = video[@"isPaused"];
	row[@"videoInfo"] = video;
	row[@"screenInfo"] = screen;
	row[@"raw"] = raw;
	return row;
}

static NSDictionary *TGGCFlattenMessage(TGClient *client, NSDictionary *message) {
	NSDictionary *raw = [message isKindOfClass:NSDictionary.class] ? message : @{};
	NSDictionary *sender = TGGCSenderFlatten(client, TGGCDict(raw[@"sender_id"]));
	NSDictionary *text = TGGCDict(raw[@"text"]);
	return @{
		@"messageId" : @([raw[@"message_id"] intValue]),
		@"sender" : sender[@"sender"],
		@"senderKey" : sender[@"senderKey"],
		@"senderName" : sender[@"name"],
		@"date" : @([raw[@"date"] intValue]),
		@"text" : text[@"text"] ?: @"",
		@"paidStarCount" : @([raw[@"paid_message_star_count"] longLongValue]),
		@"isFromOwner" : @([raw[@"is_from_owner"] boolValue]),
		@"canBeDeleted" : @([raw[@"can_be_deleted"] boolValue]),
	};
}

@implementation TGClient (GroupCalls)

#pragma mark - calls and participation

- (void)resetGroupCallState {
	objc_setAssociatedObject(self, &TGGroupCallStateKey, nil,
			OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - participants

#pragma mark - the call's own settings

#pragma mark - recording and screen sharing

#pragma mark - invite links and RTMP

#pragma mark - who a video chat is joined as

#pragma mark - messages in a call

#pragma mark - streams and the data channel

#pragma mark - state the screens read

- (NSDictionary *)groupCallSnapshot:(int32_t)groupCallId {
	NSDictionary *call = TGGCCalls(self)[@(groupCallId)];
	return [call isKindOfClass:NSDictionary.class] ? call : nil;
}

- (NSArray *)groupCallParticipantSnapshot:(int32_t)groupCallId {
	NSMutableDictionary *rows = TGGCState(self)[@"participants"][@(groupCallId)];
	if (![rows isKindOfClass:NSDictionary.class] || !rows.count)
		return @[];
	NSArray *sorted = [[rows allValues] sortedArrayUsingComparator:
			^NSComparisonResult(NSDictionary *a, NSDictionary *b){
		return [b[@"order"] compare:a[@"order"]];
	}];
	return sorted;
}

- (NSArray *)groupCallMessageSnapshot:(int32_t)groupCallId {
	NSMutableArray *rows = TGGCState(self)[@"messages"][@(groupCallId)];
	return [rows isKindOfClass:NSArray.class] ? [rows copy] : @[];
}

- (NSDictionary *)currentGroupCallParticipant:(int32_t)groupCallId {
	for (NSDictionary *row in [self groupCallParticipantSnapshot:groupCallId])
		if ([row[@"isCurrentUser"] boolValue])
			return row;
	return nil;
}

#pragma mark - updates

- (void)applyGroupCallUpdate:(NSDictionary *)update {
	NSDictionary *call = TGGCDict(update[@"group_call"]);
	int32_t callId = [call[@"id"] intValue];
	if (!callId)
		return;
	NSDictionary *flat = TGGCFlattenCall(call);
	TGGCCalls(self)[@(callId)] = flat;
	[[NSNotificationCenter defaultCenter] postNotificationName:TGGroupCallChangedNotification
			object:self userInfo:@{TGGroupCallIdKey : @(callId), TGGroupCallValueKey : flat}];
}

- (void)applyGroupCallParticipantUpdate:(NSDictionary *)update {
	int32_t callId = [update[@"group_call_id"] intValue];
	NSDictionary *raw = TGGCDict(update[@"participant"]);
	if (!callId || !raw.count)
		return;
	NSMutableDictionary *rows = TGGCParticipants(self, callId);
	NSDictionary *flat = TGGCFlattenParticipant(self, raw);
	NSString *key = flat[@"senderKey"];
	BOOL removed = ![(NSString *)flat[@"order"] length];
	if (removed)
		[rows removeObjectForKey:key];
	else
		rows[key] = flat;
	[[NSNotificationCenter defaultCenter] postNotificationName:
			TGGroupCallParticipantsChangedNotification object:self
			userInfo:@{TGGroupCallIdKey : @(callId),
					   TGGroupCallValueKey : removed ? [NSNull null] : flat}];
}

- (void)applyGroupCallMessagesDeleted:(NSDictionary *)update {
	int32_t callId = [update[@"group_call_id"] intValue];
	NSArray *ids = TGGCArray(update[@"message_ids"]);
	if (!callId || !ids.count)
		return;
	NSMutableArray *rows = TGGCMessages(self, callId);
	NSSet *deleted = [NSSet setWithArray:ids];
	NSMutableArray *kept = [NSMutableArray arrayWithCapacity:rows.count];
	for (NSDictionary *row in rows)
		if (![deleted containsObject:row[@"messageId"]])
			[kept addObject:row];
	[TGGCState(self)[@"messages"] setObject:kept forKey:@(callId)];
	[[NSNotificationCenter defaultCenter] postNotificationName:
			TGGroupCallMessagesChangedNotification object:self
			userInfo:@{TGGroupCallIdKey : @(callId), TGGroupCallValueKey : ids}];
}

- (void)applyGroupCallMessageSendFailed:(NSDictionary *)update {
	int32_t callId = [update[@"group_call_id"] intValue];
	NSDictionary *error = TGGCDict(update[@"error"]);
	NSString *message = error[@"message"];
	if (!callId)
		return;
	[[NSNotificationCenter defaultCenter] postNotificationName:
			TGGroupCallMessagesChangedNotification object:self
			userInfo:@{TGGroupCallIdKey : @(callId),
					   TGGroupCallErrorKey : message.length ? message : @"Your message was not sent. Tap \"Resend\" to send this message."}];
}

/// updateGroupCallMessage is not a td_api name in every schema this client
/// builds against; the group call message itself arrives as updateNewGroupCallMessage.
/// This accepts the update's message object.
- (void)applyNewGroupCallMessage:(NSDictionary *)update {
	int32_t callId = [update[@"group_call_id"] intValue];
	NSDictionary *message = TGGCDict(update[@"message"]);
	if (!callId || !message.count)
		return;
	NSMutableArray *rows = TGGCMessages(self, callId);
	NSDictionary *flat = TGGCFlattenMessage(self, message);
	int32_t messageId = [flat[@"messageId"] intValue];
	if (!messageId)
		return;
	for (NSUInteger i = 0; i < rows.count; i++){
		if ([rows[i][@"messageId"] intValue] == messageId){
			rows[i] = flat;
			[[NSNotificationCenter defaultCenter] postNotificationName:
					TGGroupCallMessagesChangedNotification object:self
					userInfo:@{TGGroupCallIdKey : @(callId), TGGroupCallValueKey : flat}];
			return;
		}
	}
	[rows addObject:flat];
	[rows sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b){
		return [a[@"date"] compare:b[@"date"]];
	}];
	[[NSNotificationCenter defaultCenter] postNotificationName:
			TGGroupCallMessagesChangedNotification object:self
			userInfo:@{TGGroupCallIdKey : @(callId), TGGroupCallValueKey : flat}];
}

- (void)applyGroupCallParticipantsUpdate:(NSDictionary *)update {
	int32_t callId = [update[@"group_call_id"] intValue];
	if (!callId)
		return;
	// TDLib sends the full participant rows as updateGroupCallParticipant
	// after this; the batch only names who to expect, so the screen reloads
	// the snapshot it already has rather than inventing rows.
	[[NSNotificationCenter defaultCenter] postNotificationName:
			TGGroupCallParticipantsChangedNotification object:self
			userInfo:@{TGGroupCallIdKey : @(callId),
					   TGGroupCallValueKey : TGGCArray(update[@"participant_user_ids"])}];
}

@end

// vim:ft=objc
