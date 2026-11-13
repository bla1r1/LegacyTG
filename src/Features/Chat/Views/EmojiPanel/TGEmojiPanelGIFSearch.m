#import "TGEmojiPanel.h"
#import "TGEmojiData.h"
#import "TGCapabilities.h"
#import "TGEmojiStore.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGPopupMenu.h"
#import "TGStickerStore.h"
#import "TGMessageStore.h"
#import "UIImage+WebP.h"
#import <QuartzCore/QuartzCore.h>
#import "TGStyle.h"
#import "TGMessageLayout.h"
#import "TGAlertSheet.h"
#import "TGLottieView.h"
#import "TGCustomEmojiStore.h"
#import <objc/runtime.h>
#import "TGEmojiPanelInternal.h"





@implementation TGEmojiPanel (TGEmojiPanelGIFSearch)

#pragma mark - GIF search

/// A text field inside the panel would raise the keyboard the panel is
/// standing in for, so the query is asked for in a sheet of its own.
- (void)askForGifSearch {
	NSArray *suggested = [[TGStickerStore shared] animationSearchEmojis];
	NSString *hint = suggested.count
			? [NSString stringWithFormat:@"Try %@, or type a word.",
					[suggested componentsJoinedByString:@" "]]
			: nil;
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Search GIFs"
					message:hint
				placeholder:@"GIF"
					   text:self.gifQuery
					 action:@"Search"
					 inView:(self.window ?: self)
				   onSubmit:^(NSString *query){
		TGEmojiPanel *panel = weakSelf;
		panel.gifQuery = query.length ? query : nil;
		panel.stripIndex = panel.gifQuery ? 1 : 0;
		[panel updateStripHighlight];
		[panel loadItemsForStripIndex:panel.stripIndex];
	}];
}


@end
