#import "TGEmojiPanel.h"
#import "TGEmojiData.h"
#import "TGCapabilities.h"
#import "TGEmojiStore.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGPopupMenu.h"
#import "TGStickerStore.h"
#import "TGClientNotifications.h"
#import "UIImage+WebP.h"
#import <QuartzCore/QuartzCore.h>
#import "TGStyle.h"
#import "TGMessageLayout.h"
#import "TGAlertSheet.h"
#import "TGLottieView.h"
#import "TGCustomEmojiStore.h"
#import <objc/runtime.h>
#import "TGEmojiPanelInternal.h"


static const char kTGItemDataKey = 0;

static inline void TGSetButtonItemData(UIButton *button, id item) {
	objc_setAssociatedObject(button, &kTGItemDataKey, item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static inline id TGGetButtonItemData(UIButton *button) {
	return objc_getAssociatedObject(button, &kTGItemDataKey);
}

/// The first character a title can show for a set with no cover: a whole
/// composed character, never half a surrogate pair, and never one no font has.
static NSString *TGFirstDrawableCharacter(NSString *title) {
	NSString *shown = TGStripUndrawableScalars(title ?: @"");
	return shown.length
			? [shown substringWithRange:[shown rangeOfComposedCharacterSequenceAtIndex:0]] : @"?";
}

/// A set row as the search feed draws it: the tile carries the whole record
/// so the install sheet has the id and the count, and a cover to show.
static NSArray *TGPackSearchTiles(NSArray *sets) {
	NSMutableArray *found = [NSMutableArray array];
	for (NSDictionary *set in (sets ?: @[])){
		if (![set isKindOfClass:NSDictionary.class] || !set[@"id"])
			continue;
		NSMutableDictionary *tile = [NSMutableDictionary dictionary];
		tile[@"pack"] = set;
		NSDictionary *cover = set[@"cover"];
		NSString *icon = cover[@"emoji"];
		if ([icon length])
			tile[@"emoji"] = icon;
		else if ([set[@"title"] length])
			tile[@"emoji"] = TGFirstDrawableCharacter(set[@"title"]);
		NSNumber *thumbId = cover[@"thumbId"];
		if ([thumbId isKindOfClass:NSNumber.class])
			tile[@"thumbId"] = thumbId;
		[found addObject:tile];
	}
	return found;
}

static const CGFloat kStripHeight = TGMetricEmojiStripHeight;   // categories / sets along the top
static const CGFloat kTabsHeight  = TGMetricEmojiTabsHeight;   // Emoji | Stickers | GIFs
static const CGFloat kEmojiCell   = TGMetricEmojiCell;
/// The backspace key at the end of the tab row, and the arrow drawn on it.
static const CGFloat kBackspaceWidth  = 46.0f;
static const CGFloat kBackspaceGlyphW = TGMetricBubbleDiscColumn;
static const CGFloat kBackspaceGlyphH = TGMetricStampTicksRoom;

static const NSInteger kItemTagBase = 1000;  // grid buttons carry their index
static const NSInteger kHeaderTag   = 900;   // a section title in the feed
static const CGFloat   kHeaderHeight = TGMetricEmojiHeader;
static const CGFloat   kPreviewHeaderWidth = 240.0f;
static const CGFloat   kPreviewHeaderHeight = 130.0f;
static const CGFloat   kPreviewSide = 110.0f;
/// The emoji card's header is the glyph alone; an animation preview adds a
/// caption line under the renderer.
static const CGFloat   kEmojiCardHeaderHeight = 100.0f;
static const CGFloat   kEmojiPreviewHeaderHeight = 150.0f;
static const CGFloat   kEmojiPreviewCaptionHeight = 24.0f;

/// Pictures decoded for the grid and the strip, by file id; shared by every
/// panel so reopening one draws at once.
static NSCache *TGPanelImageCache(void) {
	static NSCache *cache = nil;
	if (!cache){
		cache = [[NSCache alloc] init];
		cache.countLimit = 160;
	}
	return cache;
}

/// A still picture from a file TDLib downloaded: JPEG and PNG through UIKit,
/// WebP through the decoder the app carries.
static UIImage *TGPanelDecode(NSString *path) {
	if (!path.length)
		return nil;
	UIImage *image = nil;
	if (![path.pathExtension.lowercaseString isEqualToString:@"webp"])
		image = [UIImage imageWithContentsOfFile:path];
	if (!image)
		image = [UIImage convertFromWebP:path compressedData:nil error:nil];
	return image;
}

/// The key that deletes backwards, from TGIconPaths.
static UIImage *TGBackspaceImage(UIColor *colour) {
	return [TGIcons glyphNamed:@"backspace" colour:colour side:kBackspaceGlyphW];
}



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
