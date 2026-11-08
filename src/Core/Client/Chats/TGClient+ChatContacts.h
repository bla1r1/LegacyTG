#import "TGClient+Base.h"

@interface TGClient (ChatContacts)

/// A contact nobody here has met: the import makes the user, and the id it
/// hands back is what `addContactWithUserId:` is finished with.
- (void)importContactNamed:(NSString *)firstName
				  lastName:(NSString *)lastName
					 phone:(NSString *)phone
				completion:(void (^)(int64_t userId))completion;

/// A number back in the block list, spelled as a message sender.
- (void)blockUserWithUserId:(int64_t)userId;

/// Your phone number to a mutual contact, on their offer to share it.
- (void)sharePhoneNumberWithUser:(int64_t)userId;

/// Adds someone to your Telegram contacts. The phone number is what the
/// server matches on.
- (void)addContactWithUserId:(int64_t)userId
				   firstName:(NSString *)firstName
					lastName:(NSString *)lastName
					   phone:(NSString *)phone
				  completion:(void (^)(BOOL ok))completion;

/// Takes someone out of your contacts; the chat with them stays.
- (void)removeContactWithUserId:(int64_t)userId completion:(void (^)(BOOL ok))completion;

@end
