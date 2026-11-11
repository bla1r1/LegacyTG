//
// TGStoryStore+Live.m - copied from TGClient+StoriesLive.m.
//
#import "TGStoryStore.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGClient+StoriesSupport.h"

#import "TGClient+StoriesLive.h"
#import "TGClient+StoriesSupport.h"
#import "TGClientInternal.h"

@implementation TGStoryStore (StoriesLive)

#pragma mark - live stories

- (void)startLiveStoryInChat:(int64_t)chatId
					 privacy:(NSString *)privacy
					  userIds:(NSArray *)userIds
			   protectContent:(BOOL)protectContent
					   rtmp:(BOOL)rtmp
			 enableMessages:(BOOL)enableMessages
			  paidMessageStars:(NSInteger)paidMessageStars
				  completion:(void (^)(NSDictionary *))completion {
	[[TGClient shared] request:@{@"@type" : @"startLiveStory",
					@"chat_id" : @(chatId),
					@"privacy_settings" : TGStoryPrivacyObject(privacy, userIds),
					@"protect_content" : @(protectContent),
					@"is_rtmp_stream" : @(rtmp),
					@"enable_messages" : @(enableMessages),
					@"paid_message_star_count" : @(MAX(0, paidMessageStars))}
	   completion:^(NSDictionary *result){
		NSString *type = result[@"@type"];
		if ([type isEqualToString:@"startLiveStoryResultOk"]){
			NSDictionary *story = TGStoryFlatten(result[@"story"]);
			if (completion)
				completion(@{@"ok" : @YES, @"story" : story,
							 @"groupCallId" : story[@"groupCallId"] ?: @(0),
							 @"error" : @""});
			return;
		}
		if ([type isEqualToString:@"startLiveStoryResultFail"]){
			NSDictionary *reason = result[@"error_type"];
			NSString *kind = reason[@"@type"] ?: @"";
			NSString *say = @"An error occurred.";
			if ([kind isEqualToString:@"canPostStoryResultPremiumNeeded"])
				say = @"Telegram Premium is needed to start a live story.";
			else if ([kind isEqualToString:@"canPostStoryResultBoostNeeded"])
				say = @"This chat needs a boost before it can start a live story.";
			else if ([kind isEqualToString:@"canPostStoryResultActiveStoryLimitExceeded"])
				say = @"Too many active stories. Delete one first.";
			else if ([kind isEqualToString:@"canPostStoryResultLiveStoryIsActive"])
				say = @"A live story is already running.";
			if (completion)
				completion(@{@"ok" : @NO, @"error" : say,
							 @"errorType" : kind, @"storyId" :
								 reason[@"story_id"] ?: @(0)});
			return;
		}
		if (completion)
			completion(@{@"ok" : @NO, @"error" : TGStoryErrorText(result)});
	}];
}

- (void)joinLiveStoryCall:(int32_t)groupCallId
			   completion:(void (^)(NSString *, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"joinLiveStory",
					@"group_call_id" : @(groupCallId),
					@"join_parameters" : @{
						@"@type" : @"groupCallJoinParameters",
						@"audio_source_id" : @(0),
						@"payload" : @"",
						@"is_muted" : @YES,
						@"is_my_video_enabled" : @NO,
					}}
	   completion:^(NSDictionary *result){
		if (![result[@"@type"] isEqualToString:@"text"]){
			if (completion)
				completion(nil, TGStoryErrorText(result));
			return;
		}
		if (completion) completion(result[@"text"] ?: @"", nil);
	}];
}

- (void)liveStoryStreamerForCall:(int32_t)groupCallId
					  completion:(void (^)(NSDictionary *, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"getLiveStoryStreamer",
					@"group_call_id" : @(groupCallId)}
	   completion:^(NSDictionary *result){
		if (![result[@"@type"] isEqualToString:@"groupCallParticipant"]){
			if (completion)
				completion(nil, TGStoryErrorText(result));
			return;
		}
		NSDictionary *sender = TGStoryFlattenSender(result[@"participant_id"]);
		if (completion)
			completion(@{
				@"kind" : sender[@"kind"],
				@"id" : sender[@"id"],
				@"name" : sender[@"name"],
				@"isCurrentUser" : result[@"is_current_user"] ?: @NO,
				@"isSpeaking" : result[@"is_speaking"] ?: @NO,
				@"isMuted" : result[@"is_muted_for_all_users"] ?: @NO,
				@"bio" : result[@"bio"] ?: @"",
			}, nil);
	}];
}

- (void)liveStoryRtmpUrlForChat:(int64_t)chatId
					 completion:(void (^)(NSDictionary *, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"getLiveStoryRtmpUrl", @"chat_id" : @(chatId)}
	   completion:^(NSDictionary *result){
		if (![result[@"@type"] isEqualToString:@"rtmpUrl"]){
			if (completion)
				completion(nil, TGStoryErrorText(result));
			return;
		}
		if (completion)
			completion(@{@"url" : result[@"url"] ?: @"",
						 @"streamKey" : result[@"stream_key"] ?: @""}, nil);
	}];
}

- (void)replaceLiveStoryRtmpUrlForChat:(int64_t)chatId
							completion:(void (^)(NSDictionary *, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"replaceLiveStoryRtmpUrl", @"chat_id" : @(chatId)}
	   completion:^(NSDictionary *result){
		if (![result[@"@type"] isEqualToString:@"rtmpUrl"]){
			if (completion)
				completion(nil, TGStoryErrorText(result));
			return;
		}
		if (completion)
			completion(@{@"url" : result[@"url"] ?: @"",
						 @"streamKey" : result[@"stream_key"] ?: @""}, nil);
	}];
}

- (void)liveStoryAvailableMessageSendersForCall:(int32_t)groupCallId
									 completion:(void (^)(NSArray *, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"getLiveStoryAvailableMessageSenders",
					@"group_call_id" : @(groupCallId)}
	   completion:^(NSDictionary *result){
		NSArray *senders = result[@"senders"];
		if (![senders isKindOfClass:NSArray.class]){
			if (completion)
				completion(@[], TGStoryErrorText(result));
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *entry in senders){
			if (![entry isKindOfClass:NSDictionary.class])
				continue;
			NSDictionary *sender = TGStoryFlattenSender(entry[@"sender"]);
			[rows addObject:@{
				@"kind" : sender[@"kind"],
				@"id" : sender[@"id"],
				@"name" : sender[@"name"],
				@"needsPremium" : entry[@"needs_premium"] ?: @NO,
			}];
		}
		if (completion) completion(rows, nil);
	}];
}

- (void)setLiveStoryMessageSender:(NSDictionary *)sender
						  forCall:(int32_t)groupCallId
					   completion:(void (^)(BOOL, NSString *))completion {
	NSString *kind = [sender[@"kind"] isEqualToString:@"chat"] ? @"chat" : @"user";
	int64_t identifier = [sender[@"id"] longLongValue];
	NSDictionary *object = [kind isEqualToString:@"chat"]
			? @{@"@type" : @"messageSenderChat", @"chat_id" : @(identifier)}
			: @{@"@type" : @"messageSenderUser", @"user_id" : @(identifier)};
	[[TGClient shared] request:@{@"@type" : @"setLiveStoryMessageSender",
					@"group_call_id" : @(groupCallId),
					@"message_sender_id" : object}
	   completion:^(NSDictionary *result){
		BOOL ok = TGStorySucceeded(result);
		if (completion)
			completion(ok, ok ? nil : TGStoryErrorText(result));
	}];
}

- (void)liveStoryTopDonorsForCall:(int32_t)groupCallId
					   completion:(void (^)(NSDictionary *, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"getLiveStoryTopDonors",
					@"group_call_id" : @(groupCallId)}
	   completion:^(NSDictionary *result){
		if (![result[@"@type"] isEqualToString:@"liveStoryDonors"]){
			if (completion)
				completion(nil, TGStoryErrorText(result));
			return;
		}
		NSMutableArray *donors = [NSMutableArray array];
		for (NSDictionary *entry in TGStoryArray(result[@"top_donors"])){
			if (![entry isKindOfClass:NSDictionary.class])
				continue;
			NSDictionary *sender = TGStoryFlattenSender(entry[@"sender_id"]);
			[donors addObject:@{
				@"kind" : sender[@"kind"],
				@"id" : sender[@"id"],
				@"name" : sender[@"name"],
				@"stars" : entry[@"star_count"] ?: @(0),
				@"isTop" : entry[@"is_top"] ?: @NO,
				@"isMe" : entry[@"is_me"] ?: @NO,
				@"isAnonymous" : entry[@"is_anonymous"] ?: @NO,
			}];
		}
		if (completion)
			completion(@{@"totalStarCount" : result[@"total_star_count"] ?: @(0),
						 @"donors" : donors}, nil);
	}];
}

- (void)addPendingLiveStoryReactionInCall:(int32_t)groupCallId
								   stars:(NSInteger)stars
							  completion:(void (^)(BOOL, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"addPendingLiveStoryReaction",
					@"group_call_id" : @(groupCallId),
					@"star_count" : @(MAX(1, stars))}
	   completion:^(NSDictionary *result){
		BOOL ok = TGStorySucceeded(result);
		if (completion)
			completion(ok, ok ? nil : TGStoryErrorText(result));
	}];
}

- (void)commitPendingLiveStoryReactionsInCall:(int32_t)groupCallId
								   completion:(void (^)(BOOL, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"commitPendingLiveStoryReactions",
					@"group_call_id" : @(groupCallId)}
	   completion:^(NSDictionary *result){
		BOOL ok = TGStorySucceeded(result);
		if (completion)
			completion(ok, ok ? nil : TGStoryErrorText(result));
	}];
}

- (void)removePendingLiveStoryReactionsInCall:(int32_t)groupCallId
								   completion:(void (^)(BOOL, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"removePendingLiveStoryReactions",
					@"group_call_id" : @(groupCallId)}
	   completion:^(NSDictionary *result){
		BOOL ok = TGStorySucceeded(result);
		if (completion)
			completion(ok, ok ? nil : TGStoryErrorText(result));
	}];
}

@end

// vim:ft=objc
