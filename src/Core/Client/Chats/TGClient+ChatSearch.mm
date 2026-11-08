#import "TGClient+ChatSearch.h"
#import "TGClientInternal.h"
#ifndef typeof
#define typeof __typeof__
#endif


@implementation TGClient (ChatSearch)

#pragma mark - searching for chats and people

/// One answer for the search field, built from the three places a chat can
/// be found: the ones already here, the ones this account has on the server
/// but has not loaded, and public chats belonging to nobody yet.
///
/// Local first and deduplicated in that order, because a chat you are in
/// should never rank below a stranger with a similar name. Entries are chat
/// dictionaries where the list knows them, and a bare "id"/"title" pair for
/// a public chat it has never seen - which is enough to open one.
- (void)searchChatsForQuery:(NSString *)query
				 completion:(void (^)(NSArray *chats))completion {
	if (!query.length){
		if (completion) completion(@[]);
		return;
	}

	__weak typeof(self) weakSelf = self;
	NSMutableArray *found = [NSMutableArray array];
	NSMutableSet *seen = [NSMutableSet set];
	// Three answers, in a fixed order whichever arrives first.
	NSMutableArray *parts = [@[@[], @[], @[]] mutableCopy];
	__block NSUInteger waiting = 3;

	void (^collect)(NSUInteger, NSArray *) = ^(NSUInteger slot, NSArray *chats){
		TGClient *me = weakSelf;
		parts[slot] = chats ?: @[];
		if (--waiting > 0 || !me)
			return;
		for (NSArray *part in parts)
			for (NSDictionary *chat in part){
				NSNumber *chatId = chat[@"id"];
				if (!chatId || [seen containsObject:chatId])
					continue;
				[seen addObject:chatId];
				[found addObject:chat];
			}
		if (completion)
			completion(found);
	};

	/// chat_ids answered by any of the three, named off what is already known
	/// and asked for by id when it is not.
	void (^chatsFrom)(NSDictionary *, NSUInteger) = ^(NSDictionary *result, NSUInteger slot){
		TGClient *me = weakSelf;
		NSMutableArray *out = [NSMutableArray array];
		for (NSNumber *chatId in result[@"chat_ids"]){
			NSDictionary *info = me.chatsById[chatId];
			if (info){
				[out addObject:info];
				continue;
			}
			// A public chat nobody here has opened: its title has to be
			// asked for, and the row fills in when it lands.
			[out addObject:@{@"id" : chatId, @"title" : @""}];
			[me request:@{@"@type" : @"getChat", @"chat_id" : chatId}
			 completion:^(NSDictionary *chat){
				if ([chat[@"title"] length])
					[me chatsChanged];
			}];
		}
		collect(slot, out);
	};

	[self request:@{@"@type" : @"searchChats", @"query" : query, @"limit" : @(20)}
	   completion:^(NSDictionary *result){ chatsFrom(result, 0); }];
	[self request:@{@"@type" : @"searchChatsOnServer", @"query" : query,
					@"limit" : @(20)}
	   completion:^(NSDictionary *result){ chatsFrom(result, 1); }];
	[self request:@{@"@type" : @"searchPublicChats", @"query" : query}
	   completion:^(NSDictionary *result){ chatsFrom(result, 2); }];
}

/// People in this account's contacts, matched by Telegram rather than by
/// comparing strings here - it matches on the username and the phone number
/// as well as the name. Entries carry "id", "name" and "phone".
- (void)searchContactsForQuery:(NSString *)query
					completion:(void (^)(NSArray *users))completion {
	if (!query.length){
		if (completion) completion(@[]);
		return;
	}
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"searchContacts", @"query" : query,
					@"limit" : @(20)}
	   completion:^(NSDictionary *result){
		TGClient *me = weakSelf;
		NSMutableArray *out = [NSMutableArray array];
		for (NSNumber *userId in result[@"user_ids"]){
			if (![userId isKindOfClass:NSNumber.class])
				continue;
			NSString *name = [me nameForUserId:userId.longLongValue];
			[out addObject:@{@"id"   : userId,
							 @"name" : name ?: @""}];
		}
		if (completion)
			completion(out);
	}];
}

/// The chats opened most recently, which is the other half of what their
/// search shows when nothing is typed: who you talk to most, and where you
/// were last. Entries are the chat dictionaries the list already holds.
- (void)recentlyOpenedChatsWithCompletion:(void (^)(NSArray *chats))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getRecentlyOpenedChats", @"limit" : @(12)}
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

/// Opening a chat from search puts it in the recently-found list, which is
/// what their search shows before anything is typed.
- (void)rememberFoundChat:(int64_t)chatId {
	[self send:@{@"@type" : @"addRecentlyFoundChat", @"chat_id" : @(chatId)}];
}

/// Takes someone out of the frequent-contacts ranking.
- (void)forgetTopChat:(int64_t)chatId {
	[self send:@{@"@type" : @"removeTopChat",
				 @"category" : @{@"@type" : @"topChatCategoryUsers"},
				 @"chat_id"  : @(chatId)}];
}

@end
