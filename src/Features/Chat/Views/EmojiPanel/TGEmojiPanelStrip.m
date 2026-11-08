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



@implementation TGEmojiPanel (TGEmojiPanelStrip)

#pragma mark - strip

/// The categories the emoji tab draws. Telegram's list is only useful when
/// its source carries emoji this account may search for; a premium shelf has
/// no list and would be an empty tab, so it stays out.
- (NSArray *)emojiCategories {
	if (!self.serverCategories.count)
		return TGEmojiCategories();
	NSMutableArray *out = [NSMutableArray array];
	for (NSDictionary *category in self.serverCategories){
		NSArray *emojis = category[@"emojis"];
		if (![emojis isKindOfClass:NSArray.class] || !emojis.count)
			continue;
		[out addObject:category];
	}
	return out.count ? out : TGEmojiCategories();
}

/// Asked on every visit to the tab, answered from the store's cache after the
/// first one. An empty answer keeps the built-in list on screen.
- (void)loadEmojiCategoriesIfNeeded {
	__weak typeof(self) weakSelf = self;
	[[TGEmojiStore shared] categoriesWithCompletion:^(NSArray *categories){
		TGEmojiPanel *me = weakSelf;
		if (!me || me.tab != TGEmojiPanelTabEmoji || !categories.count)
			return;
		me.serverCategories = categories;
		[me reloadStrip];
		if (!me.emojiQuery.length)
			[me loadItemsForStripIndex:me.stripIndex];
	}];
}

/// The strip entries for the current tab: each is @{"title" or "emoji" or
/// "thumbId"}. Emoji: Recent, the search, then the categories. Stickers:
/// Recent, Favourites, then each installed set. GIFs: Saved and Search.
- (NSArray *)stripEntries {
	switch (self.tab){
		case TGEmojiPanelTabEmoji: {
			// Recent and the magnifier stay put; the categories after them are
			// Telegram's when it answered and the built-in set until then.
			NSMutableArray *out = [NSMutableArray arrayWithObjects:
					@{@"glyph" : @"recent"}, @{@"glyph" : @"search"}, nil];
			for (NSDictionary *category in [self emojiCategories])
				[out addObject:@{@"emoji" : category[@"icon"] ?: @""}];
			return out;
		}
		case TGEmojiPanelTabStickers: {
			// The magnifier first, as their panel has it: the sets that
			// follow are an index into one feed, and a search replaces it.
			NSMutableArray *out = [NSMutableArray arrayWithObjects:
					@{@"glyph" : @"search"}, @{@"glyph" : @"star"},
					@{@"glyph" : @"recent"}, nil];
			for (NSDictionary *set in self.stickerSets){
				NSDictionary *cover = set[@"cover"];
				NSMutableDictionary *entry = [NSMutableDictionary dictionary];
				entry[@"emoji"] = [cover[@"emoji"] length] ? cover[@"emoji"]
						: TGFirstDrawableCharacter(set[@"title"]);
				if ([cover[@"thumbId"] integerValue] > 0)
					entry[@"thumbId"] = cover[@"thumbId"];
				[out addObject:entry];
			}
			return out;
		}
		case TGEmojiPanelTabGIFs:
			return @[@{@"title" : @"Saved"}, @{@"title" : @"Search"}];
		case TGEmojiPanelTabCustomEmoji: {
			NSMutableArray *out = [NSMutableArray array];
			for (NSDictionary *set in self.customEmojiSets){
				NSString *title = [set isKindOfClass:NSDictionary.class] &&
						[set[@"title"] isKindOfClass:NSString.class] ? set[@"title"] : @"";
				if (title.length)
					[out addObject:@{@"title" : title}];
			}
			return out;
		}
	}
	return @[];
}

- (void)reloadStrip {
	for (UIView *view in [self.strip.subviews copy])
		[view removeFromSuperview];

	TGTheme *theme = [TGTheme shared];
	NSArray *entries = [self stripEntries];
	CGFloat x = 4;
	for (NSUInteger i = 0; i < entries.count; i++){
		NSDictionary *entry = entries[i];
		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		CGFloat width = entry[@"title"] ? 80 : 38;
		button.frame = CGRectMake(x, TGMetricBubbleRowInset, width,
				kStripHeight - TGDoubled(TGMetricBubbleRowInset));
		button.tag = (NSInteger)i;
		button.layer.cornerRadius = TGMetricCornerMedium;
		button.backgroundColor = (NSInteger)i == self.stripIndex
				? [theme actionTileBackgroundColour] : [UIColor clearColor];
		if (entry[@"title"]){
			button.titleLabel.font = TGFontSubhead();
			[button setTitle:entry[@"title"] forState:UIControlStateNormal];
			[button setTitleColor:(NSInteger)i == self.stripIndex ? [theme accentColour]
																 : [theme secondaryTextColour]
						 forState:UIControlStateNormal];
		} else if (entry[@"glyph"]){
			// Recent and Favourites are drawn, not set as emoji: iOS 7 has no
			// colour glyph for some of these on every device.
			[button setImage:[TGIcons glyphNamed:entry[@"glyph"]
										  colour:((NSInteger)i == self.stripIndex
												  ? [theme accentColour] : [theme secondaryTextColour])
											side:TGMetricMenuGlyph]
					forState:UIControlStateNormal];
		} else if (!entry[@"thumbId"] || self.tab == TGEmojiPanelTabEmoji){
			// A set with a cover waits for it blank, for the same reason the
			// sticker cells do; the emoji tab's category icons are all drawable.
			button.titleLabel.font = TGFontEmojiSmall();
			[button setTitle:entry[@"emoji"] forState:UIControlStateNormal];
		}
		[button addTarget:self action:@selector(stripTapped:) forControlEvents:UIControlEventTouchUpInside];
		// A set can be picked up and put elsewhere: held, it follows the
		// finger, and a drop right of its neighbours is the new installed
		// order. Favourites, recents, the magnifier stay put - they are
		// panels of the strip, not part of the installed order.
		if (self.tab == TGEmojiPanelTabStickers && (NSInteger)i >= 3){
			UILongPressGestureRecognizer *drag = [[UILongPressGestureRecognizer alloc]
					initWithTarget:self action:@selector(stickerSetDragged:)];
			drag.minimumPressDuration = 0.45;
			[button addGestureRecognizer:drag];
		}
		[self.strip addSubview:button];

		NSNumber *thumbId = entry[@"thumbId"];
		if (thumbId)
			[self loadImageForFile:thumbId.integerValue into:button generation:NSNotFound];
		x += width + 2;
	}
	self.strip.contentSize = CGSizeMake(x + TGMetricPadSmall, kStripHeight);
}

- (void)stripTapped:(UIButton *)button {
	if (self.tab == TGEmojiPanelTabGIFs && button.tag == 1){
		[self askForGifSearch];
		return;
	}
	if (self.tab == TGEmojiPanelTabStickers && button.tag == 0){
		[self askForStickerSearch];
		return;
	}
	if (self.tab == TGEmojiPanelTabEmoji && button.tag == 1){
		[self askForEmojiSearch];
		return;
	}
	if (self.tab == TGEmojiPanelTabEmoji && button.tag != 1)
		self.emojiQuery = nil;   // a category leaves the search behind
	if (self.tab == TGEmojiPanelTabGIFs)
		self.gifQuery = nil;   // "Saved"

	// Stickers and custom emoji are feeds: the strip moves within them rather than swapping
	// what the grid holds. A set still loading has no section yet.
	if ((self.tab == TGEmojiPanelTabStickers || self.tab == TGEmojiPanelTabCustomEmoji) && self.sections.count){
		for (NSDictionary *section in self.sections){
			if ([section[@"strip"] integerValue] != button.tag)
				continue;
			CGFloat limit = MAX(0, self.grid.contentSize.height - self.grid.bounds.size.height);
			self.syncingStrip = YES;
			[self.grid setContentOffset:
					CGPointMake(0, MIN([section[@"headerY"] floatValue], limit)) animated:YES];
			self.syncingStrip = NO;
			self.stripIndex = button.tag;
			[self updateStripHighlight];
			return;
		}
		return;
	}

	self.stripIndex = button.tag;
	[self updateStripHighlight];
	[self loadItemsForStripIndex:button.tag];
}

/// A held set pill follows the finger along the strip; where it drops is
/// its slot in the installed order. The strip's own scrolling is pinned
/// shut while the pill is up, one finger cannot steer a pill and pan a
/// scrollview at once - the same school of geometry the folder strip's
/// drag learned the hard way.
- (void)stickerSetDragged:(UILongPressGestureRecognizer *)gesture {
	UIButton *pill = (UIButton *)gesture.view;
	UIScrollView *strip = (UIScrollView *)pill.superview;
	if (![strip isKindOfClass:UIScrollView.class] ||
			self.tab != TGEmojiPanelTabStickers || pill.tag < 3)
		return;

	if (gesture.state == UIGestureRecognizerStateBegan){
		CGPoint here = [gesture locationInView:pill];
		self.stickerDragOffset = here.x - TGHalf(pill.bounds.size.width);
		self.stickerDragFrame = pill.frame;
		self.strip.scrollEnabled = NO;
		pill.transform = CGAffineTransformMakeScale(TGTransformScalePillActive, TGTransformScalePillActive);
		pill.alpha = TGAlphaPillInactive;
	}
	else if (gesture.state == UIGestureRecognizerStateChanged){
		CGPoint here = [gesture locationInView:strip];
		// Content coordinates, the strip's own currency: the frame lives
		// in them and the finger's press point rides along.
		CGFloat x = here.x - strip.contentOffset.x - self.stickerDragOffset;
		CGFloat first = TGMetricPadSmall, last = strip.contentSize.width
				- self.stickerDragFrame.size.width - TGMetricPadSmall;
		if (x < first) x = first;
		if (x > last)  x = last;
		pill.frame = CGRectMake(x, self.stickerDragFrame.origin.y,
				self.stickerDragFrame.size.width,
				self.stickerDragFrame.size.height);
	}
	else if (gesture.state == UIGestureRecognizerStateEnded ||
			 gesture.state == UIGestureRecognizerStateCancelled){
		strip.scrollEnabled = YES;
		pill.transform = CGAffineTransformIdentity;
		pill.alpha = TGAlphaOpaque;

		NSInteger from = pill.tag - 3;
		NSArray *sets = self.stickerSets;
		if (gesture.state == UIGestureRecognizerStateCancelled ||
				from < 0 || from >= (NSInteger)sets.count)
			return;   // reloadStrip puts the pill back where the data says

		// The slot is what the pill's centre cleared on the way over:
		// every other set pill it passed counts one slot ahead.
		CGPoint here = [gesture locationInView:strip];
		CGFloat centre = here.x - strip.contentOffset.x;
		NSInteger slot = 0;
		for (UIView *view in strip.subviews){
			if (![view isKindOfClass:UIButton.class])
				continue;
			NSInteger tag = view.tag;
			if (tag < 3 || tag - 3 == from)
				continue;
			if (view.center.x < centre)
				slot++;
		}
		if (slot == from)
			return;   // a hand back down on its own slot

		// Whatever pill is lit stays lit, even after the tags have moved
		// underneath it: the selection belongs to the set, not the index.
		NSDictionary *selected = nil;
		NSInteger selectedSet = self.stripIndex - 3;
		if (selectedSet >= 0 && selectedSet < (NSInteger)sets.count)
			selected = sets[selectedSet];

		NSMutableArray *order = [NSMutableArray array];
		[sets enumerateObjectsUsingBlock:^(NSDictionary *set, NSUInteger idx,
										   BOOL *stop __unused){
			if ((NSInteger)idx != from)
				[order addObject:set];
		}];
		[order insertObject:sets[from] atIndex:MIN(slot, (NSInteger)order.count)];

		// Local first: the strip re-renders off stickerSets, so a change
		// that only went to TDLib would snap the pills back mid-flight.
		self.stickerSets = order;
		if (selected){
			NSInteger found = (NSInteger)[order indexOfObject:selected];
			if (found != NSNotFound)
				self.stripIndex = found + 3;
		}
		[self reloadStrip];

		NSMutableArray *ids = [NSMutableArray array];
		for (NSDictionary *set in order)
			if (set[@"id"])
				[ids addObject:set[@"id"]];
		[[TGStickerStore shared] reorderInstalledStickerSets:ids];
	}
}


@end
