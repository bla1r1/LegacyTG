#import "TGClient+Chats.h"
#import "TGClientInternal.h"
#import "TGChatPageCache.h"
#ifndef typeof
#define typeof __typeof__
#endif


@implementation TGClient (Chats)

#pragma mark - chats

- (void)loadChats {
	if (!self.chatsById.count) {
		int64_t slotKey = (int64_t)[TGClient activeAccountSlot] + 1;
		NSArray *cached = [TGChatPageCache chatsForAccount:slotKey];
		if (cached.count) {
			for (NSDictionary *row in cached) {
				NSNumber *cid = [row isKindOfClass:NSDictionary.class] ? row[@"id"] : nil;
				if (cid)
					self.chatsById[cid] = [row mutableCopy];
			}
			if (self.onChatsChanged)
				self.onChatsChanged();
		}
	}
	// TDLib only emits updateNewChat/updateChatPosition after the list is
	// asked for. One call is one batch, and the answer says what to do next:
	// ok means "ask again", error 404 means this list is complete. Each list
	// runs its own chain, so the archive finishing (usually on its first
	// call) no longer ends the main list, and a slow link no longer burns a
	// fixed number of attempts before the batches have arrived.
	if (self.chatListComplete)
		return;
	self.chatsAtLastLoad = self.chatsById.count;
	[self loadNextChatsInList:@"chatListMain"];
	[self loadNextChatsInList:@"chatListArchive"];

	// The Archive screen's three settings are preferences, not per-chat
	// state: one get at sync start, and whichever page needs it reads the
	// cached copy instead of blocking on TDLib.
	if (!self.archiveSettings)
		[self refreshArchiveChatListSettings:nil];
}

- (void)loadNextChatsInList:(NSString *)listType {
	BOOL isMain = [listType isEqualToString:@"chatListMain"];
	if (isMain)
		self.loadChatsAttempts++;
	__weak typeof(self) weakSelf = self;
	// An account switch empties pendingRequests, which ends the chain.
	[self request:@{
		@"@type"     : @"loadChats",
		@"chat_list" : @{@"@type" : listType},
		@"limit"     : @(100),
	} completion:^(NSDictionary *result){
		TGClient *me = weakSelf;
		if (!me)
			return;
		if ([result[@"@type"] isEqualToString:@"error"]){
			// 404 is "everything loaded". Any other error ends the chain as
			// well; the next authorizationStateReady starts it again.
			if (isMain && [result[@"code"] intValue] == 404){
				me.chatListComplete = YES;
				int64_t slotKey = (int64_t)[TGClient activeAccountSlot] + 1;
				[TGChatPageCache saveChats:me.chatsById.allValues account:slotKey];
				NSLog(@"TGClient: chat list complete (%lu)",
						(unsigned long)me.chatsById.count);
			}
			return;
		}
		[me loadNextChatsInList:listType];
	}];
}

@end
