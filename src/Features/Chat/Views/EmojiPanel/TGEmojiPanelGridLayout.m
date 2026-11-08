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



@implementation TGEmojiPanel (TGEmojiPanelGridLayout)

#pragma mark - grid layout
- (CGSize)cellSize {
	CGFloat w = self.grid.bounds.size.width;
	switch (self.tab){
		case TGEmojiPanelTabEmoji:
		case TGEmojiPanelTabCustomEmoji: {
			NSUInteger columns = MAX(1, (NSUInteger)floorf(w / kEmojiCell));
			CGFloat side = floorf(w / columns);
			return CGSizeMake(side, kEmojiCell);
		}
		case TGEmojiPanelTabStickers: {
			CGFloat side = floorf(w / 4);
			return CGSizeMake(side, side);
		}
		case TGEmojiPanelTabGIFs: {
			CGFloat side = floorf(w / 3);
			return CGSizeMake(side, floorf(side * TGMetricGIFCellAspect));
		}
	}
	return CGSizeMake(kEmojiCell, kEmojiCell);
}

/// Several sets answer in one run loop turn; lay out once for all of them.
- (void)setNeedsFeedRelayout {
	if (self.relayoutQueued)
		return;
	self.relayoutQueued = YES;
	__weak typeof(self) weakSelf = self;
	dispatch_async(dispatch_get_main_queue(), ^{
		TGEmojiPanel *me = weakSelf;
		if (!me)
			return;
		me.relayoutQueued = NO;
		[me reloadGrid];
	});
}

- (void)reloadGrid {
	for (UIView *view in [self.grid.subviews copy])
		if (view.tag == kHeaderTag)
			[view removeFromSuperview];
	for (UIButton *button in self.cells.allValues){
		[button removeFromSuperview];
		[self.pool addObject:button];
	}
	[self.cells removeAllObjects];
	[self.requested removeAllObjects];

	CGSize cell = [self cellSize];
	CGFloat w = self.grid.bounds.size.width;
	NSUInteger columns = MAX(1, (NSUInteger)floorf(w / cell.width));
	TGTheme *theme = [TGTheme shared];

	// Where each item lands. Without sections this is the plain grid; with
	// them every section starts on a fresh row under its own header.
	NSMutableArray *frames = [NSMutableArray arrayWithCapacity:self.items.count];
	CGFloat y = 0;
	if (self.sections.count){
		for (NSMutableDictionary *section in self.sections){
			section[@"headerY"] = @(y);
			UILabel *header = [[UILabel alloc] initWithFrame:
					CGRectMake(TGMetricPad, y + TGMetricPadSmall, w - TGDoubled(TGMetricPad),
					kHeaderHeight - TGDoubled(TGMetricBubbleRowInset))];
			header.tag = kHeaderTag;
			header.text = (self.tab == TGEmojiPanelTabCustomEmoji)
					? TGStripUndrawableScalars(section[@"title"] ?: @"")
					: TGStripUndrawableScalars([section[@"title"] uppercaseString]);
			header.font = (self.tab == TGEmojiPanelTabCustomEmoji)
					? TGFontCaption() : TGFontMicroStrong();
			header.textColor = [theme secondaryTextColour];
			header.backgroundColor = [UIColor clearColor];
			[self.grid addSubview:header];
			y += kHeaderHeight;

			NSUInteger length = [section[@"length"] unsignedIntegerValue];
			for (NSUInteger i = 0; i < length; i++)
				[frames addObject:[NSValue valueWithCGRect:CGRectMake(
						(i % columns) * cell.width, y + (i / columns) * cell.height,
						cell.width, cell.height)]];
			y += ((length + columns - 1) / columns) * cell.height;
		}
	} else {
		for (NSUInteger i = 0; i < self.items.count; i++)
			[frames addObject:[NSValue valueWithCGRect:CGRectMake(
					(i % columns) * cell.width, (i / columns) * cell.height,
					cell.width, cell.height)]];
		y = ((self.items.count + columns - 1) / columns) * cell.height;
	}
	self.frames = frames;

	CGFloat previous = self.grid.contentOffset.y;
	self.grid.contentSize = CGSizeMake(w, y);
	// The feed fills in set by set, so keep where they are reading; only a
	// fresh grid starts at the top.
	CGFloat keep = self.sections.count ? MAX(0, MIN(previous, y - self.grid.bounds.size.height)) : 0;
	self.grid.contentOffset = CGPointMake(0, keep);
	self.emptyLabel.hidden = self.items.count > 0 || !self.emptyLabel.text.length;
	[self updateVisibleCells];
	[self syncStripToScroll];
}

/// Build what is on screen and one screen beyond, hand the rest back to the
/// pool. Called on every scroll, so it only ever touches the few cells that
/// crossed the edge.
- (void)updateVisibleCells {
	if (!self.frames.count)
		return;
	CGRect visible = self.grid.bounds;
	visible.origin.y -= TGHalf(visible.size.height);
	visible.size.height *= 2;

	NSMutableArray *gone = [NSMutableArray array];
	for (NSNumber *key in self.cells){
		NSUInteger index = key.unsignedIntegerValue;
		if (index >= self.frames.count ||
			!CGRectIntersectsRect([self.frames[index] CGRectValue], visible))
			[gone addObject:key];
	}
	for (NSNumber *key in gone){
		UIButton *button = self.cells[key];
		[button removeFromSuperview];
		if (self.pool.count < 64)
			[self.pool addObject:button];
		[self.cells removeObjectForKey:key];
	}

	for (NSUInteger i = 0; i < self.frames.count; i++){
		CGRect frame = [self.frames[i] CGRectValue];
		if (!CGRectIntersectsRect(frame, visible))
			continue;
		if (self.cells[@(i)])
			continue;
		[self buildCellAtIndex:i frame:frame];
	}
	[self loadVisibleImages];
}

- (void)buildCellAtIndex:(NSUInteger)index frame:(CGRect)frame {
	TGTheme *theme = [TGTheme shared];
	UIButton *button = [self.pool lastObject];
	if (button){
		[self.pool removeLastObject];
	} else {
		button = [UIButton buttonWithType:UIButtonTypeCustom];
		[button addTarget:self action:@selector(itemTapped:)
			 forControlEvents:UIControlEventTouchUpInside];
		button.adjustsImageWhenHighlighted = YES;
		// On the button, not on the grid: a control inside a scroll view
		// takes the touch, and a recogniser on the scroller never saw it.
		[button addGestureRecognizer:[[UILongPressGestureRecognizer alloc]
				initWithTarget:self action:@selector(gridHeld:)]];
	}
	button.frame = frame;
	button.tag = kItemTagBase + (NSInteger)index;
	id item = (index < self.items.count) ? self.items[index] : nil;
	TGSetButtonItemData(button, item);
	[button setTitle:nil forState:UIControlStateNormal];
	[button setImage:nil forState:UIControlStateNormal];
	UIImageView *tile = (UIImageView *)[button viewWithTag:1];
	tile.hidden = YES;
	tile.image = nil;

	if (self.tab == TGEmojiPanelTabEmoji){
		button.titleLabel.font = TGFontEmoji();
		NSString *str = [item isKindOfClass:NSString.class] ? (NSString *)item : @"";
		[button setTitle:str forState:UIControlStateNormal];
	} else if (self.tab == TGEmojiPanelTabCustomEmoji){
		button.imageEdgeInsets = UIEdgeInsetsZero;
		button.imageView.contentMode = UIViewContentModeScaleAspectFit;
		int64_t emojiId = 0;
		if ([item isKindOfClass:NSDictionary.class]){
			id rawId = item[@"customEmojiId"];
			if ([rawId respondsToSelector:@selector(longLongValue)])
				emojiId = [rawId longLongValue];
		}
		if (emojiId > 0){
			UIImage *image = [[TGCustomEmojiStore shared] imageForId:emojiId side:TGMetricListAvatar];
			if (image)
				[button setImage:image forState:UIControlStateNormal];
		}
	} else if (self.tab == TGEmojiPanelTabStickers){
		button.imageEdgeInsets = UIEdgeInsetsMake(TGMetricAlertTextGap, TGMetricAlertTextGap, TGMetricAlertTextGap, TGMetricAlertTextGap);
		button.imageView.contentMode = UIViewContentModeScaleAspectFit;
		NSDictionary *dict = [item isKindOfClass:NSDictionary.class] ? (NSDictionary *)item : nil;
		UIImage *cached = dict[@"thumbId"] ? [TGPanelImageCache() objectForKey:dict[@"thumbId"]] : nil;
		if (cached)
			[button setImage:cached forState:UIControlStateNormal];
		else if (!dict[@"thumbId"] && [TGCapabilities canDrawEmoji:dict[@"emoji"]]){
			// Only a sticker with no still thumbnail keeps its emoji for good.
			// One that is loading stays blank: an emoji newer than this iOS
			// sent CoreText through every font on disk, 0.3-1.8 s per grid on
			// a 4S, before the picture replaced it anyway.
			button.titleLabel.font = TGFontEmojiLarge();
			[button setTitle:dict[@"emoji"] forState:UIControlStateNormal];
		}
	} else {
		if (!tile){
			tile = [[UIImageView alloc] initWithFrame:CGRectZero];
			tile.contentMode = UIViewContentModeScaleAspectFill;
			tile.clipsToBounds = YES;
			tile.userInteractionEnabled = NO;
			tile.tag = 1;
			[button addSubview:tile];
		}
		tile.frame = CGRectInset(button.bounds, 1, 1);
		tile.backgroundColor = [theme fileTileColour];
		tile.hidden = NO;
		NSDictionary *dict = [item isKindOfClass:NSDictionary.class] ? (NSDictionary *)item : nil;
		UIImage *cached = dict[@"thumbId"] ? [TGPanelImageCache() objectForKey:dict[@"thumbId"]] : nil;
		if (!cached && dict[@"minithumbnail"])
			cached = [UIImage imageWithData:dict[@"minithumbnail"]];
		tile.image = cached;
	}
	self.cells[@(index)] = button;
	[self.grid addSubview:button];
}

/// Which section the feed is showing now, lit up on the strip.
- (void)syncStripToScroll {
	if (!self.sections.count || self.syncingStrip)
		return;
	CGFloat top = self.grid.contentOffset.y + 1;
	NSInteger strip = self.stripIndex;
	for (NSDictionary *section in self.sections){
		if ([section[@"headerY"] floatValue] > top)
			break;
		strip = [section[@"strip"] integerValue];
	}
	if (strip == self.stripIndex)
		return;
	self.stripIndex = strip;
	[self updateStripHighlight];
}

/// Only the colours change as the feed scrolls. Rebuilding the strip for this
/// threw away the buttons the cover downloads were aimed at and asked for them
/// all over again - once per scroll event, which is what wedged the app.
- (void)updateStripHighlight {
	TGTheme *theme = [TGTheme shared];
	for (UIView *view in self.strip.subviews){
		if (![view isKindOfClass:UIButton.class])
			continue;
		UIButton *button = (UIButton *)view;
		BOOL on = button.tag == self.stripIndex;
		button.backgroundColor = on ? [theme actionTileBackgroundColour] : [UIColor clearColor];
		[button setTitleColor:on ? [theme accentColour] : [theme secondaryTextColour]
					 forState:UIControlStateNormal];
	}
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	if (scrollView == self.grid){
		[self updateVisibleCells];
		[self syncStripToScroll];
	}
}

/// Thumbnails for what is on screen and a screen beyond it; the rest wait
/// until scrolled to, so opening a set of a hundred does not start a hundred
/// downloads.

@end
