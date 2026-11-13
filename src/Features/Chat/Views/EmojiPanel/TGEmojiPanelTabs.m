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





@implementation TGEmojiPanel (TGEmojiPanelTabs)

#pragma mark - tabs

- (void)tabTapped:(UIButton *)button {
	[self selectTab:(TGEmojiPanelTab)button.tag];
}

- (void)selectTab:(TGEmojiPanelTab)tab {
	self.tab = tab;
	self.stripIndex = 0;
	self.gifQuery = nil;
	self.stickerQuery = nil;
	self.emojiQuery = nil;
	self.backspace.hidden = tab != TGEmojiPanelTabEmoji;
	self.items = @[];
	self.sections = nil;
	[self reloadGrid];
	TGTheme *theme = [TGTheme shared];
	for (UIButton *button in self.tabButtons){
		BOOL on = button.tag == tab;
		[button setTitleColor:on ? [theme accentColour] : [theme secondaryTextColour]
					 forState:UIControlStateNormal];
	}

	// Telegram's categories describe the strip better than the built-in list
	// when the file database has them. The first draw keeps the built-in set;
	// the answer rebuilds the strip when it lands.
	if (tab == TGEmojiPanelTabEmoji)
		[self loadEmojiCategoriesIfNeeded];

	// Asked for every time the tab is opened, not once: Favourites and the
	// installed sets change from other clients, and a latched list never
	// caught up. The feed is rebuilt once they land - the first build only
	// has Favourites and Recently Used, because the sets are not here yet.
	if (tab == TGEmojiPanelTabStickers){
		__weak typeof(self) weakSelf = self;
		[[TGStickerStore shared] installedStickerSetsWithCompletion:^(NSArray *sets){
			TGEmojiPanel *me = weakSelf;
			if (!me || me.tab != TGEmojiPanelTabStickers)
				return;
			me.stickerSets = sets;
			[me reloadStrip];
			[me loadStickerFeed];
		}];
	} else if (tab == TGEmojiPanelTabCustomEmoji){
		[self loadCustomEmojiSetsIfNeeded];
	} else {
		[self reloadStrip];
		[self loadItemsForStripIndex:0];
	}
}

- (void)loadCustomEmojiSetsIfNeeded {
	if (self.customEmojiLoaded){
		[self reloadStrip];
		[self loadCustomEmojiFeed];
		return;
	}
	self.emptyLabel.text = @"No Results";
	self.emptyLabel.textColor = [[TGTheme shared] secondaryTextColour];
	self.emptyLabel.hidden = NO;
	__weak typeof(self) weakSelf = self;
	[[TGStickerStore shared] installedCustomEmojiSetsWithCompletion:^(NSArray *sets){
		TGEmojiPanel *me = weakSelf;
		if (!me)
			return;
		me.customEmojiLoaded = YES;
		me.customEmojiSets = sets ?: @[];
		if (me.tab != TGEmojiPanelTabCustomEmoji)
			return;
		[me reloadStrip];
		[me loadCustomEmojiFeed];
	}];
}

- (void)loadCustomEmojiFeed {
	self.generation++;
	NSMutableArray *flat = [NSMutableArray array];
	NSMutableArray *sections = [NSMutableArray array];
	for (NSUInteger i = 0; i < self.customEmojiSets.count; i++){
		NSDictionary *set = self.customEmojiSets[i];
		if (![set isKindOfClass:NSDictionary.class])
			continue;
		NSArray *emojis = set[@"emojis"];
		if (![emojis isKindOfClass:NSArray.class] || !emojis.count)
			continue;
		NSString *title = [set[@"title"] isKindOfClass:NSString.class] ? set[@"title"] : @"";
		[sections addObject:[@{
			@"title"    : title,
			@"strip"    : @(i),
			@"location" : @(flat.count),
			@"length"   : @(emojis.count)
		} mutableCopy]];
		[flat addObjectsFromArray:emojis];
	}
	self.items = flat;
	self.sections = sections;
	self.emptyLabel.text = @"No Results";
	self.emptyLabel.textColor = [[TGTheme shared] secondaryTextColour];
	self.emptyLabel.hidden = flat.count > 0;
	[self reloadGrid];
}


@end
