#import "TGChatListViewControllerInternal.h"
#import <QuartzCore/QuartzCore.h>

@implementation TGChatListViewController

/// The first search result replaces the chats with a different list, so a
/// transition on the table's layer makes those rows dissolve over the old
/// list instead of swapping in one frame.
- (void)setSearchResults:(NSArray *)searchResults {
	BOOL wasSearching = self.searchResults != nil;
	_searchResults = searchResults;
	if (!wasSearching && searchResults != nil && self.tableView.window){
		CATransition *fade = [CATransition animation];
		fade.type = kCATransitionFade;
		fade.duration = TGAnimationDurationFast;
		[self.tableView.layer addAnimation:fade forKey:@"tg.searchResults"];
	}
}

@end
