#import "TGClient+Base.h"

@interface TGClient (Communities)

#pragma mark - communities

/// Communities Telegram has told this client about, newest update first.
/// Each row is "id", "name", "haveAccess", "date", "status", "photoFileId"
/// and "canEditChatList".
@property (nonatomic, readonly) NSArray *communities;

/// The full record this account last read: "photoFileId", "chats" (each
/// "chatId", "title", "canViewHistory", "hidden"), "administratorCount",
/// "bannedCount" and "addChatRequestCount". Nil until getCommunityFullInfo
/// answers.
- (NSDictionary *)cachedCommunityFullInfo:(int64_t)communityId;

/// Creates a community around one owned chat. `communityId` is 0 and `error`
/// carries Telegram's sentence when the request is refused.
- (void)createCommunity:(NSString *)name
                 chatId:(int64_t)chatId
                 hidden:(BOOL)hidden
             completion:(void (^)(int64_t communityId, NSString *error))completion;

- (void)communityFullInfo:(int64_t)communityId
               completion:(void (^)(NSDictionary *info, NSString *error))completion;

- (void)setCommunityName:(int64_t)communityId
                    name:(NSString *)name
              completion:(void (^)(BOOL ok, NSString *error))completion;

/// `path` is a local picture, uploaded as a static chat photo. A nil path
/// asks Telegram to remove the photo.
- (void)setCommunityPhoto:(int64_t)communityId
                     path:(NSString *)path
               completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)setCommunityPermissions:(int64_t)communityId
                  canEditChatList:(BOOL)canEditChatList
                      completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)deleteCommunity:(int64_t)communityId
             completion:(void (^)(BOOL ok, NSString *error))completion;


@end
