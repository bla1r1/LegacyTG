//
// TGContactsStore.h - the Contacts feature's store surface.
//
// The address book, the count Telegram keeps of the numbers imported from a
// phone, the two ways a contact is made or renamed, and the member calls the
// picker sends when it finishes a group. Everything here owns its request.
//
#import <Foundation/Foundation.h>

@interface TGContactsStore : NSObject

+ (instancetype)shared;

/// Every contact as the row shape the list draws: id, names, phone, username,
/// photo file id and status.
- (void)contactsWithCompletion:(void (^)(NSArray *users))completion;

/// How many contacts this account uploaded from a phone's address book.
- (void)importedContactCountWithCompletion:(void (^)(NSInteger count))completion;

/// Adds someone to your Telegram contacts, or renames a contact the user id
/// already names. The phone number is what the server matches on.
- (void)addContactWithUserId:(int64_t)userId
				   firstName:(NSString *)firstName
					lastName:(NSString *)lastName
					   phone:(NSString *)phone
				  completion:(void (^)(BOOL ok))completion;

/// Imports a number Telegram has never met. The id it answers with is the
/// user the contact is then added to; zero when the import answered nothing.
- (void)importContactNamed:(NSString *)firstName
				  lastName:(NSString *)lastName
					 phone:(NSString *)phone
				completion:(void (^)(int64_t userId))completion;

/// The picker's one-member form: addChatMember.
- (void)addUser:(int64_t)userId
		 toChat:(int64_t)chatId
	 completion:(void (^)(BOOL ok, NSArray *refused))completion;

/// The picker's batch form: addChatMembers, one request for the whole pick.
- (void)addUsers:(NSArray *)userIds
		  toChat:(int64_t)chatId
	  completion:(void (^)(BOOL ok, NSArray *refused))completion;

/// A basic group made from the picker's ticked contacts.
- (void)createGroupNamed:(NSString *)title
			   withUsers:(NSArray *)userIds
			  completion:(void (^)(int64_t chatId, NSArray *failedUserIds))completion;

@end
