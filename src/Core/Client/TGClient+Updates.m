//
// TGClient+Updates.m - the same two-request inline bot pattern as GIF search,
// with the update bot named by the caller.
//
#import "TGClient+Updates.h"

@implementation TGClient (Updates)

- (void)inlineQueryWithBotUsername:(NSString *)username
                            chatId:(int64_t)chatId
                             query:(NSString *)query
                        completion:(void (^)(NSArray *results))completion {
	void (^fail)(void) = ^{ if (completion) completion(nil); };
	if (!username.length || !chatId){
		fail();
		return;
	}
	[self request:@{@"@type" : @"searchPublicChat", @"username" : username}
	   completion:^(NSDictionary *bot){
		NSNumber *botUserId = bot[@"type"][@"user_id"];
		if (![botUserId isKindOfClass:NSNumber.class]){
			fail();
			return;
		}
		// No location: the bot's answer does not depend on where the phone is,
		// and the query never leaves the account's own Saved Messages.
		[self request:@{@"@type"       : @"getInlineQueryResults",
						@"bot_user_id" : botUserId,
						@"chat_id"     : @(chatId),
						@"query"       : query ?: @"",
						@"offset"      : @""}
		   completion:^(NSDictionary *result){
			NSArray *items = result[@"results"];
			if (![items isKindOfClass:NSArray.class]){
				fail();
				return;
			}
			if (completion) completion(items);
		}];
	}];
}

@end
