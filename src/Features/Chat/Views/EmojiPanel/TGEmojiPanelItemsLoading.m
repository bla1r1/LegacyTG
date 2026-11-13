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





@implementation TGEmojiPanel (TGEmojiPanelItemsLoading)

#pragma mark - items loading
- (void)loadItemsForStripIndex:(NSInteger)index {
	self.generation++;
	NSUInteger generation = self.generation;
	__weak typeof(self) weakSelf = self;
	void (^show)(NSArray *, NSString *) = ^(NSArray *items, NSString *empty){
		TGEmojiPanel *me = weakSelf;
		if (!me || me.generation != generation)
			return;
		me.items = items ?: @[];
		me.sections = nil;
		me.emptyLabel.text = empty;
		[me reloadGrid];
	};

	switch (self.tab){
		case TGEmojiPanelTabEmoji: {
			NSArray *categories = [self emojiCategories];
			if (index == 0)
				show(TGRecentEmoji(), nil);
			else if (index == 1)
				[self loadEmojiSearch];
			else if (index - 2 < (NSInteger)categories.count){
				NSDictionary *category = categories[index - 2];
				// Telegram's rows carry "emojis"; the built-in set from
				// TGEmojiData calls the same list "emoji".
				NSArray *emojis = category[@"emojis"] ?: category[@"emoji"];
				show(emojis, nil);
			}
			break;
		}
		case TGEmojiPanelTabStickers:
			// One feed, not one set at a time: the strip only moves within it.
			// A search is the exception - it puts its results there instead.
			if (self.stickerQuery.length)
				[self loadStickerSearch];
			else
				[self loadStickerFeed];
			break;
		case TGEmojiPanelTabGIFs: {
			show(@[], nil);
			void (^got)(NSArray *) = ^(NSArray *gifs){
				show(gifs, weakSelf.gifQuery ? @"Nothing found" : @"GIFs you save show up here");
			};
			if (self.gifQuery)
				[[TGStickerStore shared] searchAnimations:self.gifQuery inChat:self.chatId completion:got];
			else
				[[TGStickerStore shared] savedAnimationsWithCompletion:got];
			break;
		}
		case TGEmojiPanelTabCustomEmoji: {
			[self loadCustomEmojiFeed];
			break;
		}
	}
}

/// Both halves of an emoji search: TDLib's keyword suggestions and the
/// emoji search itself. They land as two sections so the row that says why
/// an emoji matched stays visible instead of being flattened away.

@end
