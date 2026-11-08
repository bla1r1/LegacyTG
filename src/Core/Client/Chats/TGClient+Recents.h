#import "TGClient+Base.h"

@interface TGClient (Recents)

/// Who this account talks to most, as Telegram ranks it - the people row in
/// search. Entries are the same chat dictionaries the chat list holds.
- (void)topChatsWithCompletion:(void (^)(NSArray *chats))completion;

@end
