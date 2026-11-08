#import "TGClient+StoriesInteractions.h"
#import "TGClient+StoriesSupport.h"
#import "TGClientInternal.h"

@implementation TGClient (StoriesInteractions)

#pragma mark - interactions and statistics

static NSDictionary *TGStoryInteractionPage(NSDictionary *result) {
	if (![result[@"@type"] isEqualToString:@"storyInteractions"])
		return nil;
	NSMutableArray *rows = [NSMutableArray array];
	NSArray *interactions = [result[@"interactions"] isKindOfClass:NSArray.class]
			? result[@"interactions"] : @[];
	for (NSDictionary *interaction in interactions){
		if (![interaction isKindOfClass:NSDictionary.class])
			continue;
		NSDictionary *actor = TGStoryFlattenSender(interaction[@"actor_id"]);
		NSDictionary *type = TGStoryDict(interaction[@"type"]);
		NSString *kind = @"view";
		NSString *reaction = @"";
		NSString *detail = @"";
		if ([type[@"@type"] isEqualToString:@"storyInteractionTypeForward"]){
			kind = @"forward";
			NSDictionary *message = TGStoryDict(type[@"message"]);
			detail = TGStoryDict(TGStoryDict(message[@"content"])[@"caption"])[@"text"]
					?: TGStoryDict(TGStoryDict(message[@"content"])[@"text"])[@"text"] ?: @"";
			if (!detail.length)
				detail = [[TGClient shared] titleForChat:
						[message[@"chat_id"] longLongValue]] ?: @"";
		} else if ([type[@"@type"] isEqualToString:@"storyInteractionTypeRepost"]){
			kind = @"repost";
			NSDictionary *story = TGStoryDict(type[@"story"]);
			detail = TGStoryDict(story[@"caption"])[@"text"] ?: @"";
		} else {
			reaction = TGStoryReactionEmojis(@[@{@"type" :
					TGStoryDict(type[@"chosen_reaction_type"])}]).firstObject ?: @"";
		}
		NSMutableDictionary *row = [@{
			@"kind" : kind,
			@"actorKind" : actor[@"kind"],
			@"actorId" : actor[@"id"],
			@"name" : actor[@"name"],
			@"date" : interaction[@"interaction_date"] ?: @(0),
			@"reaction" : reaction,
			@"detail" : detail,
		} mutableCopy];
		[rows addObject:row];
	}
	return @{
		@"totalCount" : result[@"total_count"] ?: @(0),
		@"totalForwardCount" : result[@"total_forward_count"] ?: @(0),
		@"totalReactionCount" : result[@"total_reaction_count"] ?: @(0),
		@"nextOffset" : result[@"next_offset"] ?: @"",
		@"interactions" : rows,
	};
}

- (void)storyInteractionsForStory:(int32_t)storyId
							query:(NSString *)query
					 onlyContacts:(BOOL)onlyContacts
					preferForwards:(BOOL)preferForwards
				preferWithReaction:(BOOL)preferWithReaction
							 offset:(NSString *)offset
							  limit:(NSInteger)limit
						 completion:(void (^)(NSDictionary *, NSString *))completion {
	[self request:@{@"@type" : @"getStoryInteractions",
					@"story_id" : @(storyId),
					@"query" : query ?: @"",
					@"only_contacts" : @(onlyContacts),
					@"prefer_forwards" : @(preferForwards),
					@"prefer_with_reaction" : @(preferWithReaction),
					@"offset" : offset ?: @"",
					@"limit" : @(limit > 0 ? limit : 20)}
	   completion:^(NSDictionary *result){
		NSDictionary *page = TGStoryInteractionPage(result);
		if (!page){
			if (completion)
				completion(nil, TGStoryErrorText(result));
			return;
		}
		if (completion) completion(page, nil);
	}];
}

- (void)chatStoryInteractionsForStory:(int32_t)storyId
							  fromChat:(int64_t)chatId
							reactionEmoji:(NSString *)emoji
						   preferForwards:(BOOL)preferForwards
								   offset:(NSString *)offset
									limit:(NSInteger)limit
							   completion:(void (^)(NSDictionary *, NSString *))completion {
	[self request:@{@"@type" : @"getChatStoryInteractions",
					@"story_poster_chat_id" : @(chatId),
					@"story_id" : @(storyId),
					@"reaction_type" : TGStoryReactionObject(emoji),
					@"prefer_forwards" : @(preferForwards),
					@"offset" : offset ?: @"",
					@"limit" : @(limit > 0 ? limit : 20)}
	   completion:^(NSDictionary *result){
		NSDictionary *page = TGStoryInteractionPage(result);
		if (!page){
			if (completion)
				completion(nil, TGStoryErrorText(result));
			return;
		}
		if (completion) completion(page, nil);
	}];
}

- (void)storyPublicForwards:(int32_t)storyId
					fromChat:(int64_t)chatId
					  offset:(NSString *)offset
					   limit:(NSInteger)limit
				  completion:(void (^)(NSDictionary *, NSString *))completion {
	[self request:@{@"@type" : @"getStoryPublicForwards",
					@"story_poster_chat_id" : @(chatId),
					@"story_id" : @(storyId),
					@"offset" : offset ?: @"",
					@"limit" : @(limit > 0 ? limit : 20)}
	   completion:^(NSDictionary *result){
		if (![result[@"@type"] isEqualToString:@"publicForwards"]){
			if (completion)
				completion(nil, TGStoryErrorText(result));
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *forward in TGStoryArray(result[@"forwards"])){
			if (![forward isKindOfClass:NSDictionary.class])
				continue;
			if ([forward[@"@type"] isEqualToString:@"publicForwardMessage"]){
				NSDictionary *message = TGStoryDict(forward[@"message"]);
				NSDictionary *content = TGStoryDict(message[@"content"]);
				NSString *text = TGStoryDict(content[@"text"])[@"text"]
						?: TGStoryDict(content[@"caption"])[@"text"] ?: @"";
				[rows addObject:@{
					@"kind" : @"message",
					@"chatId" : message[@"chat_id"] ?: @(0),
					@"messageId" : message[@"id"] ?: @(0),
					@"title" : [[TGClient shared] titleForChat:
							[message[@"chat_id"] longLongValue]] ?: @"",
					@"text" : text,
					@"date" : message[@"date"] ?: @(0),
				}];
			} else if ([forward[@"@type"] isEqualToString:@"publicForwardStory"]){
				NSDictionary *story = TGStoryFlatten(forward[@"story"]);
				[rows addObject:@{
					@"kind" : @"story",
					@"chatId" : story[@"chatId"] ?: @(0),
					@"storyId" : story[@"storyId"] ?: @(0),
					@"title" : story[@"title"] ?: @"",
					@"text" : story[@"caption"] ?: @"",
					@"date" : story[@"date"] ?: @(0),
					@"story" : story,
				}];
			}
		}
		if (completion)
			completion(@{@"totalCount" : result[@"total_count"] ?: @(0),
						 @"nextOffset" : result[@"next_offset"] ?: @"",
						 @"forwards" : rows}, nil);
	}];
}

- (void)storyStatistics:(int32_t)storyId
			   fromChat:(int64_t)chatId
				 isDark:(BOOL)isDark
			 completion:(void (^)(NSDictionary *, NSString *))completion {
	[self request:@{@"@type" : @"getStoryStatistics",
					@"chat_id" : @(chatId),
					@"story_id" : @(storyId),
					@"is_dark" : @(isDark)}
	   completion:^(NSDictionary *result){
		if (![result[@"@type"] isEqualToString:@"storyStatistics"]){
			if (completion)
				completion(nil, TGStoryErrorText(result));
			return;
		}
		if (completion)
			completion(@{
				@"interaction" : TGStoryGraph(result[@"story_interaction_graph"]),
				@"reaction" : TGStoryGraph(result[@"story_reaction_graph"]),
			}, nil);
	}];
}

- (void)reportStory:(int32_t)storyId
		   fromChat:(int64_t)chatId
		   optionId:(NSString *)optionId
			   text:(NSString *)text
		 completion:(void (^)(NSDictionary *, NSString *))completion {
	[self request:@{@"@type" : @"reportStory",
					@"story_poster_chat_id" : @(chatId),
					@"story_id" : @(storyId),
					@"option_id" : optionId ?: @"",
					@"text" : text ?: @""}
	   completion:^(NSDictionary *result){
		NSString *type = result[@"@type"];
		if ([type isEqualToString:@"error"]){
			if (completion)
				completion(nil, TGStoryErrorText(result));
			return;
		}
		if ([type isEqualToString:@"reportStoryResultOk"]){
			if (completion) completion(@{@"state" : @"ok"}, nil);
			return;
		}
		if ([type isEqualToString:@"reportStoryResultOptionRequired"]){
			NSMutableArray *options = [NSMutableArray array];
			for (NSDictionary *option in TGStoryArray(result[@"options"]))
				if ([option isKindOfClass:NSDictionary.class])
					[options addObject:@{@"id" : option[@"id"] ?: @"",
										 @"text" : option[@"text"] ?: @""}];
			if (completion)
				completion(@{@"state" : @"options",
							 @"title" : result[@"title"] ?: @"Report Story",
							 @"options" : options}, nil);
			return;
		}
		if ([type isEqualToString:@"reportStoryResultTextRequired"]){
			if (completion)
				completion(@{@"state" : @"text",
							 @"optionId" : result[@"option_id"] ?: @"",
							 @"optional" : result[@"is_optional"] ?: @NO}, nil);
			return;
		}
		if (completion)
			completion(@{@"state" : @"unknown"}, nil);
	}];
}

@end
