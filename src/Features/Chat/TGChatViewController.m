#import "TGChatViewControllerInternal.h"

@implementation TGChatViewController

@synthesize isEditingMessages = _isEditingMessages;
@synthesize selectedMessageIds = _selectedMessageIds;

- (void)clearMemoryCaches {
	[self.images removeAllObjects];
	[self.senderAvatars removeAllObjects];
	[self.maps removeAllObjects];
	[self.imagesRequested removeAllObjects];
	[self.mapsRequested removeAllObjects];
	[self.quotesRequested removeAllObjects];
}

@end
