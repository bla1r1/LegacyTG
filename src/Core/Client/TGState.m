//
// TGState.m - cache storage and its initial shapes.
//
#import "TGState.h"
#import "TGClientInternal.h"
#import "TGImageLruCache.h"

@implementation TGState

+ (instancetype)shared {
	static TGState *state = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		state = [[TGState alloc] init];
		state.chatsById = [NSMutableDictionary dictionary];
		state.usersById = [NSMutableDictionary dictionary];
		state.rawUsersById = [[TGObjectLruCache alloc] initWithCapacity:TGRawUserCacheCap];
		state.userPhotosById = [NSMutableDictionary dictionary];
		state.forumSupergroups = [NSMutableDictionary dictionary];
		state.archivedChats = @[];
		state.folders = @[];
		state.chats = @[];
		state.savedTopicsById = [NSMutableDictionary dictionary];
		state.userSubscriptionsById = [NSMutableDictionary dictionary];
		state.noteSendWaiters = [NSMutableDictionary dictionary];
		state.communitiesById = [NSMutableDictionary dictionary];
		state.communityOrder = [NSMutableArray array];
		state.communityFullInfoById = [NSMutableDictionary dictionary];
		state.quickReplyShortcutsById = [NSMutableDictionary dictionary];
		state.quickReplyShortcutOrder = [NSMutableArray array];
		state.quickReplyMessagesByShortcut = [NSMutableDictionary dictionary];
		state.directMessagesTopicsByChat = [NSMutableDictionary dictionary];
		state.checklistCache = [NSMutableDictionary dictionary];
		state.chatRevenueAmountByChat = [NSMutableDictionary dictionary];
		state.starRevenueStatusByOwner = [NSMutableDictionary dictionary];
	});
	return state;
}

/// In place, not by replacing the containers: handlers and stores hold on to
/// them across calls.
- (void)reset {
	[self.chatsById removeAllObjects];
	[self.usersById removeAllObjects];
	[self.rawUsersById removeAllObjects];
	[self.userPhotosById removeAllObjects];
	[self.forumSupergroups removeAllObjects];
	[self.savedTopicsById removeAllObjects];
	[self.userSubscriptionsById removeAllObjects];
	[self.noteSendWaiters removeAllObjects];
	[self.communitiesById removeAllObjects];
	[self.communityOrder removeAllObjects];
	[self.communityFullInfoById removeAllObjects];
	[self.quickReplyShortcutsById removeAllObjects];
	[self.quickReplyShortcutOrder removeAllObjects];
	[self.quickReplyMessagesByShortcut removeAllObjects];
	[self.directMessagesTopicsByChat removeAllObjects];
	[self.checklistCache removeAllObjects];
	[self.chatRevenueAmountByChat removeAllObjects];
	[self.starRevenueStatusByOwner removeAllObjects];
	self.archivedChats = @[];
	self.folders = @[];
	self.chats = @[];
	self.accentColorIds = @[];
	self.profileAccentColorIds = @[];
	self.accentColors = @[];
	self.profileAccentColors = @[];
	self.archiveSettings = nil;
	self.me = nil;
}

@end

// vim:ft=objc
