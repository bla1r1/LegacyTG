//
// TGClient+Peers.h - the narrow client seam TGPeerStore reads.
//
// Users and chats are kept in two different maps inside TGClient. A store that
// speaks about "a peer" should not have to know that, so the union is named
// here once. Nothing else is added: screens use TGPeerStore, not this header.
//
#import "TGClient+Base.h"

@interface TGClient (Peers)

/// The cached raw TDLib user record, or nil.
- (NSDictionary *)peerUserRecordForId:(int64_t)userId;

/// The cached chat row (the shape TGClient.chats uses), or nil.
- (NSDictionary *)peerChatRecordForId:(int64_t)chatId;

/// The cached profile photo file id for a user or a chat.
- (NSNumber *)peerPhotoFileIdForId:(int64_t)peerId;

/// The same, asking Telegram when the record is not cached. The completion
/// runs on the main queue. One lookup per peer is the caller's problem; the
/// store keeps that promise.
- (void)peerPhotoFileIdForId:(int64_t)peerId
                  completion:(void (^)(NSNumber *fileId))completion;

/// The status line for a user, cached or fetched.
- (void)peerStatusForUserId:(int64_t)userId
                 completion:(void (^)(NSString *text))completion;

/// "ada" from the account's active usernames, or nil.
- (NSString *)peerUsernameForUserId:(int64_t)userId;

/// Members in a group or channel; completion gets 0 for anything else.
- (void)peerMemberCountForChatId:(int64_t)chatId
                      completion:(void (^)(NSInteger count))completion;

@end
