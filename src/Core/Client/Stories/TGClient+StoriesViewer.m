#import "TGClient+StoriesViewer.h"
#import "TGClient+StoriesSupport.h"
#import "TGClientInternal.h"

@implementation TGClient (StoriesViewer)

#pragma mark - viewing

- (void)openStory:(int32_t)storyId
		  fromChat:(int64_t)chatId
	   completion:(void (^)(BOOL, NSString *))completion {
	[self request:@{@"@type" : @"openStory",
					@"story_poster_chat_id" : @(chatId),
					@"story_id" : @(storyId)}
	   completion:^(NSDictionary *result){
		BOOL ok = TGStorySucceeded(result);
		if (completion)
			completion(ok, ok ? nil : TGStoryErrorText(result));
	}];
}

- (void)closeStory:(int32_t)storyId
		  fromChat:(int64_t)chatId
	   completion:(void (^)(BOOL, NSString *))completion {
	[self request:@{@"@type" : @"closeStory",
					@"story_poster_chat_id" : @(chatId),
					@"story_id" : @(storyId)}
	   completion:^(NSDictionary *result){
		BOOL ok = TGStorySucceeded(result);
		if (completion)
			completion(ok, ok ? nil : TGStoryErrorText(result));
	}];
}

- (void)storyAvailableReactionsWithCompletion:
		(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getStoryAvailableReactions", @"row_size" : @(25)}
	   completion:^(NSDictionary *result){
		if (![result[@"@type"] isEqualToString:@"availableReactions"]){
			if (completion) completion(nil);
			return;
		}
		NSString *reason = nil;
		NSDictionary *unavailable = result[@"unavailability_reason"];
		if ([unavailable isKindOfClass:NSDictionary.class]){
			reason = unavailable[@"@type"];
			if ([reason isEqualToString:@"reactionUnavailabilityReasonPremium"])
				reason = @"Telegram Premium is needed for story reactions.";
			else if ([reason isEqualToString:@"reactionUnavailabilityReasonAppNotUpdated"])
				reason = @"This Telegram version is too old for story reactions.";
			else if (reason.length)
				reason = @"Telegram is not offering story reactions right now.";
		}
		NSDictionary *out = @{
			@"emojis"    : TGStoryReactionEmojis(result[@"top_reactions"]),
			@"recent"    : TGStoryReactionEmojis(result[@"recent_reactions"]),
			@"popular"   : TGStoryReactionEmojis(result[@"popular_reactions"]),
			@"allowCustom" : result[@"allow_custom_emoji"] ?: @NO,
			@"unavailable" : reason ?: @"",
		};
		if (completion) completion(out);
	}];
}

- (void)setStoryReaction:(NSString *)emoji
				  onStory:(int32_t)storyId
				 fromChat:(int64_t)chatId
			  completion:(void (^)(BOOL, NSString *))completion {
	[self request:@{@"@type" : @"setStoryReaction",
					@"story_poster_chat_id" : @(chatId),
					@"story_id" : @(storyId),
					@"reaction_type" : TGStoryReactionObject(emoji),
					@"update_recent_reactions" : @YES}
	   completion:^(NSDictionary *result){
		BOOL ok = TGStorySucceeded(result);
		if (completion)
			completion(ok, ok ? nil : TGStoryErrorText(result));
	}];
}

@end
