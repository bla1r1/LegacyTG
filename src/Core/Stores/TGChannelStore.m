//
// TGChannelStore.m - the Channels requests, in one place.
//
#import "TGChannelStore.h"
#import "TGClient.h"

@implementation TGChannelStore

+ (instancetype)shared {
	static TGChannelStore *store = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ store = [[TGChannelStore alloc] init]; });
	return store;
}

- (void)chatInfoForId:(int64_t)chatId
		   completion:(void (^)(NSDictionary *))completion {
	[[TGClient shared] request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
	   completion:^(NSDictionary *chat){
		if (completion)
			completion([chat[@"@type"] isEqualToString:@"chat"] ? chat : nil);
	}];
}

- (void)openSimilarChat:(int64_t)openedChatId fromChat:(int64_t)chatId {
	[[TGClient shared] send:@{@"@type" : @"openChatSimilarChat",
				 @"chat_id" : @(chatId),
				 @"opened_chat_id" : @(openedChatId)}];
}

@end
