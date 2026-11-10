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
#import "TGLocalization.h"


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



@implementation TGEmojiPanel (TGEmojiPanelStickerSheets)

#pragma mark - sticker sheets
- (void)showStickerPreview:(NSDictionary *)info caption:(NSString *)caption {
	NSInteger fileId = [info[@"fileId"] integerValue];
	if (fileId <= 0){
		[TGAlertSheet showMessage:@"Telegram sent no animation for this."
							 title:caption
							inView:(self.window ?: self)];
		return;
	}

	UIView *host = self.window ?: (self.superview ?: self);
	UIView *header = [[UIView alloc] initWithFrame:
			CGRectMake(0, 0, kPreviewHeaderWidth, kEmojiPreviewHeaderHeight)];
	header.backgroundColor = [UIColor clearColor];

	CGRect picture = CGRectMake(TGCenteredOrigin(kPreviewHeaderWidth, kPreviewSide),
			TGMetricPadSmall, kPreviewSide, kPreviewSide);
	TGLottieView *lottie = [[TGLottieView alloc] initWithFrame:picture];
	[header addSubview:lottie];

	UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0,
			CGRectGetMaxY(picture), kPreviewHeaderWidth, kEmojiPreviewCaptionHeight)];
	label.text = caption;
	label.font = TGFontBody();
	label.textAlignment = NSTextAlignmentCenter;
	label.textColor = [[TGTheme shared] secondaryTextColour];
	label.backgroundColor = [UIColor clearColor];
	[header addSubview:label];

	[[TGStickerStore shared] downloadFile:fileId
							 priority:TGDownloadPriorityOnScreen
						   completion:^(NSString *path){
		if (!path.length)
			return;
		dispatch_async(dispatch_get_main_queue(), ^{
			__weak TGLottieView *weakLottie = lottie;
			weakLottie.onStickerReady = ^{ [weakLottie play]; };
			if ([weakLottie loadStickerFile:path])
				[weakLottie play];
		});
	}];

	CGPoint where = [self convertPoint:CGPointMake(CGRectGetMidX(self.bounds),
			CGRectGetMidY(self.bounds)) toView:host];
	self.menuOpenUntil = [NSDate timeIntervalSinceReferenceDate] + 1.0;
	[TGPopupMenu showItems:@[@{@"title" : @"Close", @"icon" : @"close"}]
				   atPoint:where
					inView:host
				headerView:header
				  onChoice:^(NSInteger index, NSString *title){}];
}

/// The tags a sticker is filed under, straight from Telegram: the sticker's
/// own list, and every emoji in the installed sets that matches the first of
/// them. The second list is how the shelf is explorable from one sticker.
- (void)showEmojiTagsOfStickerWithFileId:(NSInteger)fileId title:(NSString *)emoji {
	__weak typeof(self) weakSelf = self;
	[[TGStickerStore shared] stickerEmojisForFileId:fileId completion:^(NSArray *own){
		TGEmojiPanel *me = weakSelf;
		if (!me)
			return;
		NSString *query = own.count ? own.firstObject : (emoji ?: @"");
		[[TGStickerStore shared] allStickerEmojisForQuery:query completion:^(NSArray *all){
			TGEmojiPanel *panel = weakSelf;
			if (!panel)
				return;
			NSString *first = own.count
					? [own componentsJoinedByString:@" "] : @"none";
			NSString *rest = all.count
					? [all componentsJoinedByString:@" "] : @"none";
			NSString *message = [NSString stringWithFormat:
					@"Filed under: %@\n\nEvery tag matching %@:\n%@",
					first, query.length ? query : @"this sticker", rest];
			[TGAlertSheet showMessage:message
								  title:@"Emoji Tags"
								 inView:(panel.window ?: panel)];
		}];
	}];
}

/// The outline the vector pipeline publishes, plus the SVG path for it.
/// This card shows what Telegram sent rather than a guessed shape, which is
/// the honest reading on a device with no general vector fill.
- (void)showOutlineOfStickerWithFileId:(NSInteger)fileId {
	__weak typeof(self) weakSelf = self;
	[[TGStickerStore shared] stickerOutlineForFileId:fileId completion:
			^(NSArray *paths, NSInteger points){
		TGEmojiPanel *me = weakSelf;
		if (!me)
			return;
		[[TGStickerStore shared] stickerOutlineSvgPathForFileId:fileId
				completion:^(NSString *svg){
			TGEmojiPanel *panel = weakSelf;
			if (!panel)
				return;
			NSString *path = svg ?: @"";
			NSString *shown = path.length > 240
					? [[path substringToIndex:240] stringByAppendingString:@"..."]
					: path;
			NSString *message = [NSString stringWithFormat:
					@"%lu closed paths, %ld points.\n\n%@",
					(unsigned long)paths.count, (long)points,
					shown.length ? shown : @"Telegram sent no SVG path."];
			UIView *host = panel.window ?: panel;
			if (!path.length){
				[TGAlertSheet showMessage:message title:@"Sticker Outline" inView:host];
				return;
			}
			[TGAlertSheet showChoices:@[@"Copy SVG Path", @"Done"]
								title:@"Sticker Outline"
								message:message
					 destructiveIndex:-1
							   inView:host
							 onChoice:^(NSInteger index){
				if (index == 0){
					[UIPasteboard generalPasteboard].string = path;
				}
			}];
		}];
	}];
}

/// A pack found by search, installed on one confirm. The answer comes back
/// as an update the panel does not listen for, so the shelf is re-read
/// shortly after - one highlight's length, the same beat the hold menu uses.
- (void)askInstallForStickerSet:(NSDictionary *)set {
	NSString *title = [set[@"title"] length] ? set[@"title"] : @"Stickers";
	NSString *counted = [NSString stringWithFormat:@"%@ - %lu stickers",
			title, (unsigned long)[set[@"count"] unsignedIntegerValue]];
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:@[@"Install", @"Not now"]
						title:counted
			  destructiveIndex:-1
						inView:(self.window ?: self)
					  onChoice:^(NSInteger index){
		TGEmojiPanel *panel = weakSelf;
		if (index != 0 || !panel)
			return;
		[[TGStickerStore shared] setStickerSet:set[@"id"] installed:YES archived:NO];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
				(int64_t)(TGAnimationDurationHighlight * NSEC_PER_SEC)),
				dispatch_get_main_queue(), ^{
			[weakSelf selectTab:TGEmojiPanelTabStickers];
		});
	}];
}

/// The shelf a removed pack lands on. A pack comes back by installing it
/// again from here; that is the whole reason the list is kept.
- (void)showArchivedPacks {
	__weak typeof(self) weakSelf = self;
	[[TGStickerStore shared] archivedStickerSetsWithCompletion:^(NSArray *sets){
		TGEmojiPanel *me = weakSelf;
		if (!me)
			return;
		NSArray *list = [sets isKindOfClass:NSArray.class] ? sets : @[];
		if (!list.count){
			[TGAlertSheet showMessage:@"None"
								  title:@"Archived"
								 inView:(me.window ?: me)];
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *set in list){
			NSString *title = [set[@"title"] length] ? set[@"title"] : @"Stickers";
			[rows addObject:[NSString stringWithFormat:@"%@  ·  %lu stickers",
					title, (unsigned long)[set[@"count"] unsignedIntegerValue]]];
		}
		UIView *host = me.window ?: me;
		[TGAlertSheet showChoices:rows
							title:@"Archived"
						  message:nil
				   destructiveIndex:-1
						   inView:host
						 onChoice:^(NSInteger index){
			NSDictionary *set = list[(NSUInteger)index];
			[[TGStickerStore shared] setStickerSet:set[@"id"] installed:YES archived:NO];
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
					(int64_t)(TGAnimationDurationHighlight * NSEC_PER_SEC)),
					dispatch_get_main_queue(), ^{
				[weakSelf selectTab:TGEmojiPanelTabStickers];
			});
		}];
	}];
}

/// The section a flat index falls in, so a hold knows where it was made.

@end
