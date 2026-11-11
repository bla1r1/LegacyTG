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

@end

// vim:ft=objc
