//
// TGPeerStore.h - users and chats as a screen sees them.
//
// One record for a person or a chat, one place for the picture, one change
// notification. The chat list, member rows, profiles and stories used to ask
// TGClient separately for each of those; this header is the whole surface a
// screen may use now.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#ifdef __cplusplus
extern "C" {
#endif

/// Posted on the main queue when peer records changed, with
/// userInfo[@"ids"] = NSArray of NSNumber peer ids. Bursts arrive as one post.
extern NSString *const TGPeerStoreChangedNotification;

#ifdef __cplusplus
}
#endif

/// One peer, immutable. Built from TGClient's user or chat record; a screen
/// reads it and does not patch it.
@interface TGPeer : NSObject

@property (nonatomic, assign, readonly) int64_t peerId;
@property (nonatomic, assign, readonly) BOOL isUser;
@property (nonatomic, assign, readonly) BOOL isChannel;
@property (nonatomic, assign, readonly) BOOL isGroup;
@property (nonatomic, assign, readonly) BOOL isSaved;
@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, copy, readonly) NSString *initials;
@property (nonatomic, copy, readonly) NSString *username;
@property (nonatomic, assign, readonly) BOOL verified;
@property (nonatomic, assign, readonly) int64_t emojiStatusId;
@property (nonatomic, assign, readonly) BOOL online;
@property (nonatomic, copy, readonly) NSString *lastSeenText;
@property (nonatomic, assign, readonly) NSInteger memberCount;

/// Builders for the two plain TDLib shapes, and for tests.
+ (instancetype)peerFromUser:(NSDictionary *)user;
+ (instancetype)peerFromChat:(NSDictionary *)chat;

@end

@interface TGPeerStore : NSObject

+ (TGPeerStore *)shared;

#pragma mark - records

/// The current record for a user id or a chat id, nil for id 0.
- (TGPeer *)peerForId:(int64_t)peerId;

/// Re-reads the volatile fields (presence for a user, member count for a
/// group) and answers the rebuilt record. The completion is on the main queue.
- (void)refreshPeerForId:(int64_t)peerId
              completion:(void (^)(TGPeer *peer))completion;

/// YES when the cached record already names a profile picture.
- (BOOL)peerHasAvatar:(int64_t)peerId;

#pragma mark - avatars

/// The picture if it has already been decoded at this side.
- (id)cachedAvatarForPeer:(int64_t)peerId side:(CGFloat)side;

/// Asks for the peer's profile picture, decoded off the main thread and
/// rounded to a square `side`. One download runs per file id however many
/// peers or sides wait for it; every completion runs on the main queue.
- (void)loadAvatarForPeer:(int64_t)peerId
                     side:(CGFloat)side
               completion:(void (^)(id image))completion;

/// Drops the decoded pictures and the waits in flight. Called when the
/// running account changes, because the same id is another person after it.
- (void)reset;

@end
