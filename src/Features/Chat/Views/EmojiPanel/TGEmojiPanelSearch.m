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

/// The key that deletes backwards: a pentagon pointing left with a cross.
static UIImage *TGBackspaceImage(UIColor *colour) {
	CGSize size = CGSizeMake(kBackspaceGlyphW, kBackspaceGlyphH);
	UIGraphicsBeginImageContextWithOptions(size, NO, 0);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGContextSetStrokeColorWithColor(ctx, colour.CGColor);
	CGContextSetLineWidth(ctx, TGMetricStrokeIcon);
	CGContextSetLineJoin(ctx, kCGLineJoinRound);
	CGContextSetLineCap(ctx, kCGLineCapRound);
	CGContextMoveToPoint(ctx, 7, 1.5f);
	CGContextAddLineToPoint(ctx, 22.5f, 1.5f);
	CGContextAddLineToPoint(ctx, 22.5f, 16.5f);
	CGContextAddLineToPoint(ctx, 7, 16.5f);
	CGContextAddLineToPoint(ctx, 1, 9);
	CGContextClosePath(ctx);
	CGContextStrokePath(ctx);
	CGContextMoveToPoint(ctx, 11, 5.5f);
	CGContextAddLineToPoint(ctx, 18, 12.5f);
	CGContextMoveToPoint(ctx, 18, 5.5f);
	CGContextAddLineToPoint(ctx, 11, 12.5f);
	CGContextStrokePath(ctx);
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}



@implementation TGEmojiPanel (TGEmojiPanelSearch)

#pragma mark - search
- (void)loadEmojiSearch {
	self.generation++;
	NSUInteger generation = self.generation;
	NSString *query = self.emojiQuery;
	if (!query.length){
		self.items = @[];
		self.sections = nil;
		self.emptyLabel.text = @"Search emoji by word";
		[self reloadGrid];
		return;
	}

	self.items = @[];
	self.sections = nil;
	self.emptyLabel.text = @"Searching...";
	[self reloadGrid];

	__weak typeof(self) weakSelf = self;
	__block NSArray *suggested = @[];
	__block NSArray *found = @[];
	__block NSUInteger left = 2;

	void (^show)(void) = ^{
		TGEmojiPanel *me = weakSelf;
		if (!me || me.generation != generation || --left > 0)
			return;

		NSMutableArray *flat = [NSMutableArray array];
		NSMutableArray *sections = [NSMutableArray array];
		NSArray *parts = @[suggested, found];
		NSArray *titles = @[@"Suggested", @"Results"];
		for (NSUInteger i = 0; i < parts.count; i++){
			NSArray *part = parts[i];
			if (!part.count)
				continue;
			[sections addObject:[@{@"title"    : titles[i],
								   @"strip"    : @(-9),
								   @"location" : @(flat.count),
								   @"length"   : @(part.count)} mutableCopy]];
			[flat addObjectsFromArray:part];
		}
		me.items = flat;
		me.sections = sections;
		me.emptyLabel.text = flat.count
				? nil : [NSString stringWithFormat:@"No emoji for %@", query];
		[me setNeedsFeedRelayout];
	};

	[[TGEmojiStore shared] keywordEmojis:query completion:^(NSArray *emojis){
		suggested = emojis ?: @[];
		show();
	}];
	[[TGEmojiStore shared] searchEmojis:query completion:^(NSArray *emojis){
		found = emojis ?: @[];
		show();
	}];
}

/// The panel stands in for the keyboard, so a field would raise it. The
/// query is asked for in the app's own sheet, as the sticker and GIF tabs do.
- (void)askForEmojiSearch {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Search Emoji"
					message:@"A word, or an emoji to see what it is filed under."
				placeholder:@"\U0001F603"
					   text:self.emojiQuery
					 action:@"Search"
					 inView:(self.window ?: self)
				   onSubmit:^(NSString *query){
		TGEmojiPanel *panel = weakSelf;
		NSString *what = [query stringByTrimmingCharactersInSet:
				[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		panel.emojiQuery = what.length ? what : nil;
		panel.stripIndex = panel.emojiQuery ? 1 : 0;
		[panel updateStripHighlight];
		[panel loadItemsForStripIndex:panel.stripIndex];
	}];
}

/// Favourites, then Recently Used, then every installed set, in one scroll.
/// The sets are asked for one after another rather than all at once: a dozen
/// answers landing together rebuilt the feed a dozen times and froze the app.
/// Stickers for an emoji: the installed sets first, because those are the
/// ones already on the phone, then everything public under them.
- (void)loadStickerSearch {
	self.generation++;
	NSUInteger generation = self.generation;
	NSString *query = self.stickerQuery;

	self.items = @[];
	self.sections = nil;
	self.emptyLabel.text = @"Searching...";
	[self reloadGrid];

	__weak typeof(self) weakSelf = self;
	__block NSArray *mine = @[];
	__block NSArray *everywhere = @[];
	__block NSArray *packs = @[];
	__block NSArray *minePacks = @[];
	__block NSArray *trending = @[];
	__block NSUInteger left = 5;

	void (^show)(void) = ^{
		TGEmojiPanel *me = weakSelf;
		if (!me || me.generation != generation || --left > 0)
			return;

		NSMutableArray *flat = [NSMutableArray array];
		NSMutableArray *sections = [NSMutableArray array];
		// A pack tile carries a pack, not a sticker: it is its own section,
		// and strip -9 is no strip's slot, so the highlight stays on the pill
		// already lit. A query that finds no pack at all falls back to what
		// is popular, which is the only way the shelf advertises anything.
		NSArray *packRows = packs.count ? packs : trending;
		NSString *packTitle = packs.count ? @"Packs" : @"Trending";
		NSArray *parts = @[mine, everywhere, minePacks, packRows];
		NSArray *titles = @[@"Yours", @"All stickers", @"Your packs", packTitle];
		for (NSUInteger i = 0; i < parts.count; i++){
			NSArray *part = parts[i];
			if (!part.count)
				continue;
			[sections addObject:[@{@"title"    : titles[i],
								   @"strip"    : (i >= 2 ? @(-9) : @(0)),
								   @"location" : @(flat.count),
								   @"length"   : @(part.count)} mutableCopy]];
			[flat addObjectsFromArray:part];
		}
		me.items = flat;
		me.sections = sections;
		me.emptyLabel.text = [NSString stringWithFormat:@"No stickers for %@", query];
		[me setNeedsFeedRelayout];
	};

	[[TGStickerStore shared] stickersForEmoji:query completion:^(NSArray *stickers){
		mine = stickers ?: @[];
		show();
	}];
	[[TGStickerStore shared] searchStickersForEmoji:query completion:^(NSArray *stickers){
		// What is already in "Yours" is not worth a second tile.
		NSMutableSet *known = [NSMutableSet set];
		for (NSDictionary *sticker in mine)
			if (sticker[@"fileId"])
				[known addObject:sticker[@"fileId"]];
		NSMutableArray *rest = [NSMutableArray array];
		for (NSDictionary *sticker in (stickers ?: @[]))
			if (![known containsObject:sticker[@"fileId"]])
				[rest addObject:sticker];
		everywhere = rest;
		show();
	}];

	// The word side of the query finds packs: a search meant to install
	// something ends here, given the same query TDLib's set search also
	// takes. Each entry carries the whole record the install sheet needs -
	// id, count, covers, and whether it is already installed.
	[[TGStickerStore shared] searchStickerSetsNamed:query completion:^(NSArray *sets){
		packs = TGPackSearchTiles(sets);
		show();
	}];

	// The half of the search that answers "I already have this": the same
	// query over the installed shelf, shown before the public results.
	[[TGStickerStore shared] installedStickerSetsNamed:query completion:^(NSArray *sets){
		minePacks = TGPackSearchTiles(sets);
		show();
	}];

	[[TGStickerStore shared] trendingStickerSetsWithCompletion:^(NSArray *sets){
		trending = TGPackSearchTiles(sets);
		// The shelf is on screen now, so it is seen: Telegram drops what has
		// been viewed from the next recommendation. This is the write half of
		// the trending read, and it belongs where the read is drawn.
		NSMutableArray *ids = [NSMutableArray array];
		for (NSDictionary *set in (sets ?: @[]))
			if (set[@"id"])
				[ids addObject:set[@"id"]];
		[[TGStickerStore shared] viewTrendingStickerSets:ids];
		show();
	}];
}

/// An emoji rather than a word: that is what TDLib searches stickers by, and
/// saying so in the sheet saves a round of confusion.
- (void)askForStickerSearch {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Search Stickers"
					message:@"By emoji - the one a sticker is filed under."
				placeholder:@"\U0001F603"
					   text:self.stickerQuery
					 action:@"Search"
					 inView:(self.window ?: self)
				   onSubmit:^(NSString *query){
		TGEmojiPanel *panel = weakSelf;
		panel.stickerQuery = query.length ? query : nil;
		panel.stripIndex = 0;
		[panel updateStripHighlight];
		[panel loadItemsForStripIndex:0];
	}];
}

- (void)loadStickerFeed {
	self.generation++;
	NSUInteger generation = self.generation;

	// Strip slot 0 is the magnifier, so the feed's own sections start at 1.
	NSMutableArray *titles = [NSMutableArray arrayWithObjects:@"Favourites", @"Recently Used", nil];
	for (NSDictionary *set in self.stickerSets)
		[titles addObject:[set[@"title"] length] ? set[@"title"] : @"Stickers"];

	NSMutableArray *slots = [NSMutableArray array];
	for (NSUInteger i = 0; i < titles.count; i++)
		[slots addObject:@[]];

	self.items = @[];
	self.sections = nil;
	self.emptyLabel.text = @"No stickers yet";
	[self reloadGrid];

	__weak typeof(self) weakSelf = self;
	void (^fill)(NSUInteger, NSArray *) = ^(NSUInteger slot, NSArray *stickers){
		TGEmojiPanel *me = weakSelf;
		if (!me || me.generation != generation || slot >= slots.count)
			return;
		slots[slot] = stickers ?: @[];

		NSMutableArray *flat = [NSMutableArray array];
		NSMutableArray *sections = [NSMutableArray array];
		for (NSUInteger i = 0; i < slots.count; i++){
			NSArray *part = slots[i];
			if (!part.count)
				continue;   // an empty set keeps no header
			[sections addObject:[@{@"title"    : titles[i],
								   @"strip"    : @(i + 1),
								   @"location" : @(flat.count),
								   @"length"   : @(part.count)} mutableCopy]];
			[flat addObjectsFromArray:part];
		}
		me.items = flat;
		me.sections = sections;
		[me setNeedsFeedRelayout];
	};

	// One request at a time, walking the strip order. The block clears itself
	// at the end, which is what releases it and the slots it holds.
	__block void (^next)(NSUInteger);
	next = ^(NSUInteger slot){
		TGEmojiPanel *me = weakSelf;
		if (!me || me.generation != generation || slot >= titles.count){
			next = nil;
			return;
		}
		void (^got)(NSArray *) = ^(NSArray *stickers){
			fill(slot, stickers);
			if (next)
				next(slot + 1);
		};
		if (slot == 0)
			[[TGStickerStore shared] favoriteStickersWithCompletion:got];
		else if (slot == 1)
			[[TGStickerStore shared] recentStickersWithCompletion:got];
		else
			[[TGStickerStore shared] stickersInSet:me.stickerSets[slot - 2][@"id"] completion:got];
	};
	next(0);
}


@end
