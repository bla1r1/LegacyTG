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
#import "TGBitmapFile.h"


static const char kTGItemDataKey = 0;

static inline id TGGetButtonItemData(UIButton *button) {
	return objc_getAssociatedObject(button, &kTGItemDataKey);
}

static const NSInteger kItemTagBase = 1000;  // grid buttons carry their index
static const CGFloat   kPreviewHeaderWidth = 240.0f;
static const CGFloat   kPreviewHeaderHeight = 130.0f;
static const CGFloat   kPreviewSide = 110.0f;

/// A still picture from a file TDLib downloaded: JPEG and PNG through UIKit,
/// WebP through the decoder the app carries.
/// Decoded pictures on disk, raw (TGBitmapFile), at the size the cell shows
/// them: after a relaunch every tile asked TDLib for its file and decoded
/// WebP again. ~100 KB a tile at 160 px, so the oldest go past this many.
static const NSUInteger kTGPanelTilesKept = 240;

/// One decode at a time: on the global queue a screen of tiles decoded at
/// once and shared the A4's one core between a dozen of them.
static dispatch_queue_t TGPanelDecodeQueue(void) {
	static dispatch_queue_t queue;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		queue = dispatch_queue_create("org.legacy.itg.panel-decode", DISPATCH_QUEUE_SERIAL);
		dispatch_set_target_queue(queue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
	});
	return queue;
}

static NSString *TGPanelCachesDirectory(void) {
	return [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
}

static NSString *TGPanelTileDirectory(void) {
	return [TGPanelCachesDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:
			@"sticker-tiles/%lld", [[TGStickerStore shared] myUserId]]];
}

/// The picture at the cell's pixel size. Sticker thumbnails come 320 px
/// square (some 640): 400 KB to 1.6 MB of bitmap each, decoded, copied to
/// a layer and scaled down 2-4x on every frame of a scroll, for an 80 pt
/// cell. Scaled so its shorter side still covers `pixels`; never up.
static UIImage *TGPanelShrink(UIImage *image, CGFloat pixels) {
	CGImageRef source = image.CGImage;
	size_t w = source ? CGImageGetWidth(source) : 0, h = source ? CGImageGetHeight(source) : 0;
	if (!w || !h || pixels <= 0)
		return image;
	CGFloat factor = pixels / MIN(w, h);
	if (factor >= 1)
		return image;
	size_t tw = MAX((size_t)1, (size_t)ceilf(w * factor)), th = MAX((size_t)1, (size_t)ceilf(h * factor));
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGContextRef ctx = CGBitmapContextCreate(NULL, tw, th, 8, tw * 4, space, TGBitmapFileInfo());
	CGColorSpaceRelease(space);
	if (!ctx)
		return image;
	CGContextSetInterpolationQuality(ctx, kCGInterpolationMedium);
	CGContextDrawImage(ctx, CGRectMake(0, 0, tw, th), source);
	CGImageRef small = CGBitmapContextCreateImage(ctx);
	CGContextRelease(ctx);
	UIImage *out = small ? [UIImage imageWithCGImage:small] : image;
	if (small)
		CGImageRelease(small);
	return out;
}

/// Keeps the newest kTGPanelTilesKept tiles; runs on the decode queue.
static void TGPanelPruneTiles(NSString *dir) {
	NSFileManager *fm = [NSFileManager defaultManager];
	// Full-size tiles an earlier build kept (400 KB to 1.6 MB each).
	[fm removeItemAtPath:[TGPanelCachesDirectory() stringByAppendingPathComponent:@"panel-tiles"] error:NULL];
	NSArray *names = [fm contentsOfDirectoryAtPath:dir error:NULL];
	if (names.count <= kTGPanelTilesKept)
		return;
	NSMutableArray *files = [NSMutableArray arrayWithCapacity:names.count];
	for (NSString *name in names) {
		NSString *path = [dir stringByAppendingPathComponent:name];
		NSDate *date = [fm attributesOfItemAtPath:path error:NULL].fileModificationDate;
		if (date)
			[files addObject:@[ date, path ]];
	}
	[files sortUsingComparator:^NSComparisonResult(NSArray *a, NSArray *b) { return [b[0] compare:a[0]]; }];
	for (NSUInteger i = kTGPanelTilesKept; i < files.count; i++)
		[fm removeItemAtPath:files[i][1] error:NULL];
}

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
	static BOOL pruned;
	CGSize cell = [self cellSize];
	CGFloat pixels = ceilf(MAX(cell.width, cell.height) * [UIScreen mainScreen].scale);
	NSString *dir = TGPanelTileDirectory();
	NSString *tile = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%ld.bgra", (long)fileId]];
	BOOL prune = !pruned;
	pruned = YES;
	void (^show)(UIImage *) = ^(UIImage *image){
		dispatch_async(dispatch_get_main_queue(), ^{
			[TGPanelImageCache() setObject:image forKey:@(fileId)];
			apply(image);
		});
	};
	dispatch_async(TGPanelDecodeQueue(), ^{
		if (prune)
			TGPanelPruneTiles(dir);
		CGImageRef saved = TGBitmapCreate(tile);
		if (saved) {
			UIImage *image = [UIImage imageWithCGImage:saved];
			CGImageRelease(saved);
			show(image);
			return;
		}
		dispatch_async(dispatch_get_main_queue(), ^{
			[[TGStickerStore shared] downloadFile:fileId completion:^(NSString *path){
				if (!path.length)
					return;
				dispatch_async(TGPanelDecodeQueue(), ^{
					UIImage *image = TGPanelShrink(TGPanelDecode(path), pixels);
					if (!image)
						return;
					TGBitmapWrite(image.CGImage, tile);
					show(image);
				});
			}];
		});
	});
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
