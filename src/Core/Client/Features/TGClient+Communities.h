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
/// Creates a community around one owned chat. `communityId` is 0 and `error`
/// carries Telegram's sentence when the request is refused.
- (void)communityFullInfo:(int64_t)communityId
               completion:(void (^)(NSDictionary *info, NSString *error))completion;

/// `path` is a local picture, uploaded as a static chat photo. A nil path
/// asks Telegram to remove the photo.
@end
