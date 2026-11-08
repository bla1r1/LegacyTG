#import "TGClient+Recents.h"
#import "TGClientInternal.h"
#ifndef typeof
#define typeof __typeof__
#endif


@implementation TGClient (Recents)

#pragma mark - recents

/// The people row in search: who this account talks to most, as Telegram
/// ranks it. Entries are the chat dictionaries the list already holds.
- (void)topChatsWithCompletion:(void (^)(NSArray *chats))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type"    : @"getTopChats",
					@"category" : @{@"@type" : @"topChatCategoryUsers"},
					@"limit"    : @(12)}
	   completion:^(NSDictionary *result){
		TGClient *me = weakSelf;
		NSMutableArray *out = [NSMutableArray array];
		for (NSNumber *chatId in result[@"chat_ids"]){
			NSDictionary *info = me.chatsById[chatId];
			if (info)
				[out addObject:info];
		}
		if (completion)
			completion(out);
	}];
}

@end
