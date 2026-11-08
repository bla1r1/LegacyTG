//
// TGClient+Account.h - the client surface for the account and its people: sessions, contacts, blocked users, storage stats.
//
#import "TGClient+Base.h"


@interface TGClient (AccountPeople)

/// Block or unblock a user.
- (void)setUser:(int64_t)userId blocked:(BOOL)blocked;
/// Block or unblock a user; `completion` is told only when TDLib answers.
- (void)setUser:(int64_t)userId blocked:(BOOL)blocked completion:(void (^)(BOOL ok))completion;
/// Whether a user is blocked right now.
- (void)isUserBlocked:(int64_t)userId completion:(void (^)(BOOL blocked))completion;
/// Gifts a user has received and kept on their profile: "title", "starCount".
- (void)giftsForUser:(int64_t)userId completion:(void (^)(NSArray *gifts))completion;
/// Gifts an owner (user or chat sender) has received, paged by offset.
- (void)giftsForOwner:(NSDictionary *)ownerId
			   offset:(NSString *)offset
		   completion:(void (^)(NSArray *gifts, NSString *nextOffset, NSInteger totalCount))completion;
/// Premium state of the signed-in account: nil when it is not active.
- (void)premiumStateWithCompletion:(void (^)(NSString *summary))completion;

@end
