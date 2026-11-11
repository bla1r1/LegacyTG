//
// TGState.h - the account's in-memory caches.
//
// TGClient updates this object from update*; stores read it. No TDLib and no
// UIKit: it is a plain data holder so the update handlers and the domain
// stores can share one state without owning it themselves.
//
#import <Foundation/Foundation.h>
#import "TGClientTypes.h"
#import "TGImageLruCache.h"

@interface TGState : NSObject

+ (instancetype)shared;

@property (nonatomic, strong) NSMutableDictionary *chatsById;
@property (nonatomic, strong) NSMutableDictionary *usersById;
@property (nonatomic, strong) TGObjectLruCache *rawUsersById;
@property (nonatomic, strong) NSMutableDictionary *userPhotosById;
@property (nonatomic, strong) NSMutableDictionary *forumSupergroups;
@property (nonatomic, strong) NSArray *archivedChats;
@property (nonatomic, strong) NSMutableDictionary *savedTopicsById;
@property (nonatomic, strong) NSArray *folders;
@property (nonatomic, strong) NSDictionary *archiveSettings;
@property (nonatomic, strong) NSArray *chats;
@property (nonatomic, strong) NSDictionary *me;
@property (nonatomic, strong) NSArray *accentColorIds;
@property (nonatomic, strong) NSArray *profileAccentColorIds;
@property (nonatomic, strong) NSArray *accentColors;
@property (nonatomic, strong) NSArray *profileAccentColors;
@property (nonatomic, strong) NSMutableDictionary *userSubscriptionsById;
@property (nonatomic, strong) NSMutableDictionary *noteSendWaiters;
@property (nonatomic, strong) NSMutableDictionary *communitiesById;
@property (nonatomic, strong) NSMutableArray *communityOrder;
@property (nonatomic, strong) NSMutableDictionary *communityFullInfoById;
@property (nonatomic, strong) NSMutableDictionary *quickReplyShortcutsById;
@property (nonatomic, strong) NSMutableArray *quickReplyShortcutOrder;
@property (nonatomic, strong) NSMutableDictionary *quickReplyMessagesByShortcut;
@property (nonatomic, strong) NSMutableDictionary *directMessagesTopicsByChat;
@property (nonatomic, strong) NSMutableDictionary *checklistCache;
@property (nonatomic, strong) NSMutableDictionary *chatRevenueAmountByChat;
@property (nonatomic, strong) NSMutableDictionary *starRevenueStatusByOwner;

@end
