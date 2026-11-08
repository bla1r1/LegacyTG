#import "TGClient+Base.h"

@interface TGClient (Chats)

/// Ask TDLib to populate the main chat list. Only meaningful once authorized.
- (void)loadChats;

@end
