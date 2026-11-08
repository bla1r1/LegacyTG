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



@implementation TGEmojiPanel (TGEmojiPanelGridImages)

#pragma mark - grid images
- (void)loadVisibleImages {
	if (self.tab == TGEmojiPanelTabEmoji)
		return;
	if (self.tab == TGEmojiPanelTabCustomEmoji){
		for (NSNumber *key in [self.cells allKeys]){
			NSUInteger index = key.unsignedIntegerValue;
			if (index >= self.items.count || [self.requested containsObject:key])
				continue;
			[self.requested addObject:key];
			id item = self.items[index];
			if (![item isKindOfClass:NSDictionary.class])
				continue;
			id rawId = item[@"customEmojiId"];
			if (![rawId respondsToSelector:@selector(longLongValue)])
				continue;
			int64_t emojiId = [rawId longLongValue];
			if (emojiId <= 0)
				continue;
			UIImage *image = [[TGCustomEmojiStore shared] imageForId:emojiId side:TGMetricListAvatar];
			if (image){
				UIButton *button = self.cells[key];
				button.imageView.contentMode = UIViewContentModeScaleAspectFit;
				[button setImage:image forState:UIControlStateNormal];
			}
		}
		return;
	}
	for (NSNumber *key in [self.cells allKeys]){
		NSUInteger index = key.unsignedIntegerValue;
		if (index >= self.items.count || [self.requested containsObject:key])
			continue;
		[self.requested addObject:key];
		id rawItem = self.items[index];
		if (![rawItem isKindOfClass:NSDictionary.class])
			continue;
		NSNumber *thumbId = rawItem[@"thumbId"];
		if ([thumbId integerValue] <= 0 || [TGPanelImageCache() objectForKey:thumbId])
			continue;
		[self loadImageForFile:thumbId.integerValue into:self.cells[key] generation:self.generation];
	}
}

- (void)customEmojiLoaded:(NSNotification *)note {
	if (self.tab != TGEmojiPanelTabCustomEmoji)
		return;
	id rawLoaded = [note.userInfo isKindOfClass:NSDictionary.class] ? note.userInfo[@"id"] : nil;
	int64_t loadedId = [rawLoaded respondsToSelector:@selector(longLongValue)] ? [rawLoaded longLongValue] : 0;
	for (NSNumber *key in [self.cells allKeys]){
		NSUInteger index = key.unsignedIntegerValue;
		if (index >= self.items.count)
			continue;
		id item = self.items[index];
		if (![item isKindOfClass:NSDictionary.class])
			continue;
		id rawId = item[@"customEmojiId"];
		if (![rawId respondsToSelector:@selector(longLongValue)])
			continue;
		int64_t emojiId = [rawId longLongValue];
		if (loadedId > 0 && emojiId != loadedId)
			continue;
		UIButton *button = self.cells[key];
		UIImage *image = [[TGCustomEmojiStore shared] imageForId:emojiId side:TGMetricListAvatar];
		if (image){
			button.imageView.contentMode = UIViewContentModeScaleAspectFit;
			[button setImage:image forState:UIControlStateNormal];
		}
	}
}

/// Download and decode a picture, then put it on the button (or the GIF
/// tile inside it). `generation` is NSNotFound for strip buttons, which do
/// not go stale with the grid.
- (void)loadImageForFile:(NSInteger)fileId into:(UIButton *)button generation:(NSUInteger)generation {
	UIImage *cached = [TGPanelImageCache() objectForKey:@(fileId)];
	__weak typeof(self) weakSelf = self;
	__weak UIButton *weakButton = button;
	// The cell this was asked for may have been recycled onto another sticker
	// by the time the picture arrives. Without this the wrong picture lands on
	// the button - and then tapping what you see sends something else.
	NSInteger expectedTag = button.tag;
	void (^apply)(UIImage *) = ^(UIImage *image){
		TGEmojiPanel *me = weakSelf;
		UIButton *target = weakButton;
		if (!me || !target || !image)
			return;
		if (generation != NSNotFound && generation != me.generation)
			return;
		if (target.tag != expectedTag)
			return;
		UIImageView *tile = (UIImageView *)[target viewWithTag:1];
		if ([tile isKindOfClass:UIImageView.class]){
			tile.image = image;
		} else {
			[target setTitle:nil forState:UIControlStateNormal];
			target.imageView.contentMode = UIViewContentModeScaleAspectFit;
			[target setImage:image forState:UIControlStateNormal];
		}
	};
	if (cached){
		apply(cached);
		return;
	}
	[[TGStickerStore shared] downloadFile:fileId completion:^(NSString *path){
		if (!path.length)
			return;
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
			UIImage *image = TGPanelDecode(path);
			if (!image)
				return;
			dispatch_async(dispatch_get_main_queue(), ^{
				[TGPanelImageCache() setObject:image forKey:@(fileId)];
				apply(image);
			});
		});
	}];
}

/// Holding a sticker or a GIF opens the same kind of card the rest of the
/// app uses, with the things that can be done to it from here.
- (void)gridHeld:(UILongPressGestureRecognizer *)hold {
	BOOL isSticker = self.tab == TGEmojiPanelTabStickers;
	BOOL isGif = self.tab == TGEmojiPanelTabGIFs;
	BOOL isEmoji = self.tab == TGEmojiPanelTabEmoji;
	if (hold.state != UIGestureRecognizerStateBegan ||
			(!isSticker && !isGif && !isEmoji))
		return;
	UIButton *button = (UIButton *)hold.view;
	id item = TGGetButtonItemData(button);
	NSInteger index = button.tag - kItemTagBase;
	if (!item && index >= 0 && index < (NSInteger)self.items.count)
		item = self.items[index];
	if (!item) return;

	// An emoji has no file of its own; holding it opens the metadata card
	// instead of the sticker actions below.
	if (isEmoji){
		NSString *glyph = [item isKindOfClass:NSString.class] ? (NSString *)item : @"";
		[self showEmojiCardForEmoji:glyph atButton:button];
		return;
	}

	NSInteger fileId = [item[@"fileId"] integerValue];
	if (fileId <= 0){
		NSLog(@"TGEmojiPanel: hold on item with no fileId");
		return;
	}

	// Which section it came from decides what can be done to it.
	NSDictionary *section = isSticker ? [self sectionForItemIndex:index] : nil;
	NSInteger strip = section ? [section[@"strip"] integerValue] : -1;

	NSMutableArray *items = [NSMutableArray array];
	NSMutableArray *actions = [NSMutableArray array];

	if (isGif){
		// The un-searched feed is the saved shelf; results of a query are
		// strangers until they are saved.
		BOOL inSaved = self.gifQuery.length == 0;
		[items addObject:(inSaved
				? @{@"title" : @"Remove", @"icon" : @"delete",
					@"destructive" : @YES}
				: @{@"title" : @"Save GIF", @"icon" : @"star"})];
		[actions addObject:inSaved ? @"unsavegif" : @"savegif"];
	}
	else {
		BOOL already = [self stickerIsFavourite:fileId];
		[items addObject:(already
				? @{@"title" : @"Remove from Favorites", @"icon" : @"unpin",
					@"destructive" : @YES}
				: @{@"title" : @"Add to Favorites", @"icon" : @"pin"})];
		[actions addObject:already ? @"unfav" : @"fav"];

		if (strip == 1){   // Recently Used
			[items addObject:@{@"title" : @"Remove from Recent", @"icon" : @"delete",
							   @"destructive" : @YES}];
			[actions addObject:@"unrecent"];
		}
		if (strip >= 2 && (NSUInteger)(strip - 2) < self.stickerSets.count){
			[items addObject:@{@"title" : @"Remove", @"icon" : @"delete",
							   @"destructive" : @YES}];
			[actions addObject:@"unset"];
			[items addObject:@{@"title" : @"Archived Stickers", @"icon" : @"folder"}];
			[actions addObject:@"archived"];
		}
		// Filing and outline are facts about the sticker, not about the set
		// it is in: both work wherever the card was opened.
		[items addObject:@{@"title" : @"Emoji Tags...", @"icon" : @"star"}];
		[actions addObject:@"emojis"];
		[items addObject:@{@"title" : @"Sticker Outline...", @"icon" : @"edit"}];
		[actions addObject:@"outline"];
	}

	UIView *host = self.window ?: (self.superview ?: self);
	CGPoint where = [self.grid convertPoint:button.center toView:host];
	self.menuOpenUntil = [NSDate timeIntervalSinceReferenceDate] + 1.0;

	// Floating preview card header inside TGPopupMenu
	UIView *header = [[UIView alloc] initWithFrame:CGRectMake(TGMetricZero, TGMetricZero, kPreviewHeaderWidth, kPreviewHeaderHeight)];
	header.backgroundColor = [UIColor clearColor];

	CGFloat pSide = kPreviewSide;
	CGRect pFrame = CGRectMake(TGCenteredOrigin(kPreviewHeaderWidth, pSide),
							   TGCenteredOrigin(kPreviewHeaderHeight, pSide),
							   pSide, pSide);

	BOOL isAnimated = [item[@"isAnimated"] boolValue] || [item[@"docName"] isEqualToString:@"tgs"];
	if (isAnimated) {
		TGLottieView *lottie = [[TGLottieView alloc] initWithFrame:pFrame];
		UIImageView *thumb = [[UIImageView alloc] initWithFrame:pFrame];
		thumb.contentMode = UIViewContentModeScaleAspectFit;
		UIImage *cached = item[@"thumbId"] ? [TGPanelImageCache() objectForKey:item[@"thumbId"]] : nil;
		if (cached) thumb.image = cached;
		[header addSubview:thumb];
		[header addSubview:lottie];

		[[TGStickerStore shared] downloadFile:fileId priority:TGDownloadPriorityOnScreen completion:^(NSString *path){
			if (!path) return;
			dispatch_async(dispatch_get_main_queue(), ^{
				if ([lottie loadTGSFile:path]) {
					thumb.hidden = YES;
					[lottie play];
				}
			});
		}];
	} else {
		UIImageView *preview = [[UIImageView alloc] initWithFrame:pFrame];
		preview.contentMode = UIViewContentModeScaleAspectFit;
		UIImage *cached = item[@"thumbId"] ? [TGPanelImageCache() objectForKey:item[@"thumbId"]] : nil;
		if (!cached && item[@"minithumbnail"])
			cached = [UIImage imageWithData:item[@"minithumbnail"]];
		if (cached) preview.image = cached;
		[header addSubview:preview];

		[[TGStickerStore shared] downloadFile:fileId priority:TGDownloadPriorityOnScreen completion:^(NSString *path){
			if (!path) return;
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				UIImage *img = TGPanelDecode(path);
				if (img) {
					dispatch_async(dispatch_get_main_queue(), ^{
						preview.image = img;
					});
				}
			});
		}];
	}

	id setId = (isSticker && strip >= 2 && (NSUInteger)(strip - 2) < self.stickerSets.count)
			? self.stickerSets[strip - 2][@"id"] : nil;
	__weak typeof(self) weakSelf = self;
	[TGPopupMenu showItems:items atPoint:where inView:host headerView:header
				  onChoice:^(NSInteger choice, NSString *title){
		NSLog(@"TGEmojiPanel: menu chose %ld (%@)", (long)choice, title);
		if (choice < 0 || choice >= (NSInteger)actions.count)
			return;
		NSString *action = actions[choice];
		if ([action isEqualToString:@"fav"])
			[[TGStickerStore shared] setSticker:fileId favourite:YES];
		else if ([action isEqualToString:@"unfav"])
			[[TGStickerStore shared] setSticker:fileId favourite:NO];
		else if ([action isEqualToString:@"unrecent"])
			[[TGStickerStore shared] removeRecentSticker:fileId];
		else if ([action isEqualToString:@"unset"])
			[[TGStickerStore shared] setStickerSet:setId installed:NO archived:NO];
		else if ([action isEqualToString:@"archived"]){
			[weakSelf showArchivedPacks];
			return;
		}
		else if ([action isEqualToString:@"emojis"]){
			[weakSelf showEmojiTagsOfStickerWithFileId:fileId title:item[@"emoji"]];
			return;
		}
		else if ([action isEqualToString:@"outline"]){
			[weakSelf showOutlineOfStickerWithFileId:fileId];
			return;
		}
		else if ([action isEqualToString:@"savegif"])
			[[TGStickerStore shared] saveAnimationFileId:fileId saved:YES];
		else if ([action isEqualToString:@"unsavegif"])
			[[TGStickerStore shared] saveAnimationFileId:fileId saved:NO];

		// The answers come back as updates the panel does not listen for, so
		// re-read the feed shortly after. A removed pack also changes the
		// strip, so the sets are asked for again with it.
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)),
				dispatch_get_main_queue(), ^{
			TGEmojiPanel *panel = weakSelf;
			if (panel && (panel.tab == TGEmojiPanelTabStickers ||
						  panel.tab == TGEmojiPanelTabGIFs))
				[panel selectTab:panel.tab];
		});
	}];
}

/// What a held emoji can say about itself. The card is the panel's own
/// version of the reaction picker's caption: the glyph, the reaction's title
/// and the animations Telegram publishes for it.

@end
