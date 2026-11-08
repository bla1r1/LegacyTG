#import "TGClient+Base.h"

@interface TGClient (ChatSearch)

/// Everything the search field can find by name, from the three places a
/// chat can be: loaded here, on the server but not loaded, and public and
/// belonging to nobody yet. Deduplicated in that order, so a chat you are in
/// never ranks below a stranger with a similar name. A public chat the list
/// has never seen arrives as an "id"/"title" pair, which is enough to open.
- (void)searchChatsForQuery:(NSString *)query
				 completion:(void (^)(NSArray *chats))completion;

/// Contacts matched by Telegram - on the username and the phone number as
/// well as the name, which comparing strings here does not do. Entries carry
/// "id" and "name".
- (void)searchContactsForQuery:(NSString *)query
					completion:(void (^)(NSArray *users))completion;

/// The chats opened most recently - the other half of an empty search.
- (void)recentlyOpenedChatsWithCompletion:(void (^)(NSArray *chats))completion;

/// Opening a chat from search puts it in the recently-found list.
- (void)rememberFoundChat:(int64_t)chatId;

/// Takes someone out of the frequent-contacts ranking.
- (void)forgetTopChat:(int64_t)chatId;

@end
