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



@implementation TGEmojiPanel (TGEmojiPanelTaps)

#pragma mark - taps
- (NSDictionary *)sectionForItemIndex:(NSInteger)index {
	for (NSDictionary *section in self.sections){
		NSInteger location = [section[@"location"] integerValue];
		NSInteger length = [section[@"length"] integerValue];
		if (index >= location && index < location + length)
			return section;
	}
	return nil;
}

/// Favourites is the first section of the feed, so what is in it is known
/// here without asking the server again.
- (BOOL)stickerIsFavourite:(NSInteger)fileId {
	for (NSDictionary *section in self.sections){
		if ([section[@"strip"] integerValue] != 0)
			continue;
		NSUInteger location = [section[@"location"] unsignedIntegerValue];
		NSUInteger length = [section[@"length"] unsignedIntegerValue];
		for (NSUInteger i = location; i < location + length && i < self.items.count; i++)
			if ([self.items[i][@"fileId"] integerValue] == fileId)
				return YES;
		return NO;
	}
	return NO;
}

- (void)itemTapped:(UIButton *)button {
	// A held sticker opens the card; the touch that ends the hold must not
	// also send it.
	if ([NSDate timeIntervalSinceReferenceDate] < self.menuOpenUntil)
		return;
	NSInteger index = button.tag - kItemTagBase;
	id item = TGGetButtonItemData(button);
	if (!item && index >= 0 && index < (NSInteger)self.items.count)
		item = self.items[index];
	if (!item)
		return;
	switch (self.tab){
		case TGEmojiPanelTabEmoji:
			TGNoteEmojiUsed(item);
			[self.delegate emojiPanel:self didPickEmoji:item];
			break;
		case TGEmojiPanelTabStickers:
			// A pack tile installs the pack; picking a sticker sends it.
			if ([item isKindOfClass:NSDictionary.class] && item[@"pack"]){
				[self askInstallForStickerSet:item[@"pack"]];
				return;
			}
			[self.delegate emojiPanel:self didPickSticker:item];
			break;
		case TGEmojiPanelTabGIFs:
			[self.delegate emojiPanel:self didPickAnimation:item];
			break;
		case TGEmojiPanelTabCustomEmoji: {
			int64_t emojiId = 0;
			NSString *fallback = @"";
			if ([item isKindOfClass:NSDictionary.class]){
				id rawId = item[@"customEmojiId"];
				if ([rawId respondsToSelector:@selector(longLongValue)])
					emojiId = [rawId longLongValue];
				if ([item[@"emoji"] isKindOfClass:NSString.class])
					fallback = item[@"emoji"];
			}
			if (![[TGStickerStore shared] accountHasPremium] &&
				self.chatId != [[TGStickerStore shared] myUserId]){
				[TGAlertSheet showMessage:@"Custom emoji need Telegram Premium"
									title:nil
								   inView:(self.window ?: self)];
				return;
			}
			if ([self.delegate respondsToSelector:@selector(emojiPanel:didPickCustomEmoji:fallback:)]){
				[self.delegate emojiPanel:self didPickCustomEmoji:emojiId fallback:fallback];
			}
			break;
		}
	}
}

- (void)backspaceTapped {
	[self.delegate emojiPanelDidBackspace:self];
}


@end
