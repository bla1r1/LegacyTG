#import "TGClient+Chats.h"
#import "TGClientInternal.h"
#ifndef typeof
#define typeof __typeof__
#endif


@implementation TGClient (Chats)

#pragma mark - chats

- (void)loadChats {
	// TDLib only emits updateNewChat/updateChatPosition after the list is
	// asked for; without loadChats nothing about chats ever arrives. It also
	// loads in batches - one call is one batch, and it answers with error 404
	// once everything is loaded - so this has to be repeated until the list
	// stops growing.
	if (self.chatListComplete)
		return;
	self.chatsAtLastLoad = self.chatsById.count;
	NSLog(@"TGClient: loadChats attempt %lu (have %lu)",
			(unsigned long)self.loadChatsAttempts + 1,
			(unsigned long)self.chatsById.count);
	[self send:@{
		@"@type"     : @"loadChats",
		@"chat_list" : @{@"@type" : @"chatListMain"},
		@"limit"     : @(100),
	}];
	[self send:@{
		@"@type"     : @"loadChats",
		@"chat_list" : @{@"@type" : @"chatListArchive"},
		@"limit"     : @(100),
	}];

	// The Archive screen's three settings are preferences, not per-chat
	// state: one get at sync start, and whichever page needs it reads the
	// cached copy instead of blocking on TDLib.
	if (!self.archiveSettings)
		[self refreshArchiveChatListSettings:nil];

	// A batch beyond the first needs a server round trip, so silence for a
	// second or two means nothing. Keep asking on a timer and stop only when
	// TDLib says 404 (everything loaded) or after a sane number of tries.
	self.loadChatsAttempts++;
	if (self.loadChatsAttempts > 12)
		return;

	__weak typeof(self) weakSelf = self;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)),
			dispatch_get_main_queue(), ^{
		TGClient *me = weakSelf;
		if (me && !me.chatListComplete)
			[me loadChats];
	});
}

@end
