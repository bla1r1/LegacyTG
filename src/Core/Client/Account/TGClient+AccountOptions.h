//
// TGClient+Account.h - the client surface for the account and its people: sessions, contacts, blocked users, storage stats.
//
#import "TGClient+Base.h"


@interface TGClient (AccountOptions)

/// A TDLib option by name, and the boolean setter for the handful of them the
/// settings screens expose ("disable_top_chats", "disable_animated_emoji", ...).
- (void)optionValue:(NSString *)name completion:(void (^)(id value))completion;
- (void)setOption:(NSString *)name boolValue:(BOOL)value;
/// Drop the phone contacts this account uploaded to Telegram.
- (void)clearImportedContacts;
/// How many contacts this account has uploaded from a device's address book.
- (void)importedContactCountWithCompletion:(void (^)(NSInteger count))completion;
/// Replaces the uploaded contact list with `contacts` (each "phone_number",
/// "first_name", "last_name"). `importerCount` is how many of the supplied
/// rows Telegram accepted; `userIds` is its answer, one id per row.
- (void)changeImportedContacts:(NSArray *)contacts
					completion:(void (^)(NSInteger importerCount,
										NSArray *userIds))completion;
/// The official client download page for this platform.
- (void)applicationDownloadLinkWithCompletion:(void (^)(NSString *url))completion;
/// Set the signed-in account's own picture from a local file.
- (void)setProfilePhotoAtPath:(NSString *)path completion:(void (^)(BOOL ok))completion;
/// The account's own birthday. Day 0 means it is not set; year 0 means it is
/// set but the year was left out, which Telegram allows.
- (void)myBirthdayWithCompletion:(void (^)(NSInteger day, NSInteger month,
                                           NSInteger year))completion;
- (void)setBirthdayDay:(NSInteger)day month:(NSInteger)month year:(NSInteger)year
			completion:(void (^)(BOOL ok, NSString *error))completion;
/// Stories on a profile: the ones kept on the page, or the ones still live if
/// none are kept. Each: "storyId", "date", "caption", "photoId" (a file id for
/// the picture or a video's poster frame), "isVideo", "viewers".
- (void)storiesForChat:(int64_t)chatId completion:(void (^)(NSArray *stories))completion;

@end
