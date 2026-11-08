//
// TGClient+Account.h - the client surface for the account and its people: sessions, contacts, blocked users, storage stats.
//
#import "TGClient+Base.h"


@interface TGClient (AccountProfileMedia)

/// Take one of this account's own profile photos off the account - the id a
/// chatPhoto carries, which the photo gallery is what reads back.
- (void)deleteProfilePhoto:(int64_t)photoId
				completion:(void (^)(BOOL ok))completion;
/// Every profile photo an account still has, oldest never first: each row
/// carries "photoId" (what deleteProfilePhoto answers to), "fileId" (the
/// small file to download) and "date" (when the photo was added).
- (void)userProfilePhotos:(int64_t)userId
			   completion:(void (^)(NSArray *photos))completion;
/// The t.me link of the signed-in account - Telegram answers for only the
/// current user, so there is no asking for someone else's.
- (void)myUserLink:(void (^)(NSString *link))completion;
/// The chats this account shares with another user, each as an ordinary chat
/// row ("id", "title"), so a tap opens it like any chat the list holds.
- (void)groupsInCommonWithUser:(int64_t)userId
					completion:(void (^)(NSArray *chats))completion;

@end
