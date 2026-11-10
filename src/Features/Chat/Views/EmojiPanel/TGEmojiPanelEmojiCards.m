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



@implementation TGEmojiPanel (TGEmojiPanelEmojiCards)

#pragma mark - emoji cards
- (void)showEmojiCardForEmoji:(NSString *)emoji atButton:(UIButton *)button {
	if (!emoji.length)
		return;

	UIView *host = self.window ?: (self.superview ?: self);
	CGPoint where = [self.grid convertPoint:button.center toView:host];
	self.menuOpenUntil = [NSDate timeIntervalSinceReferenceDate] + 1.0;

	UIView *header = [[UIView alloc] initWithFrame:
			CGRectMake(0, 0, kPreviewHeaderWidth, kEmojiCardHeaderHeight)];
	header.backgroundColor = [UIColor clearColor];
	UILabel *glyph = [[UILabel alloc] initWithFrame:header.bounds];
	glyph.text = emoji;
	glyph.font = TGFontEmojiLarge();
	glyph.textAlignment = NSTextAlignmentCenter;
	[header addSubview:glyph];

	NSArray *items = @[
		@{@"title" : @"Animated Preview", @"icon" : @"sticker"},
		@{@"title" : @"Reaction Info", @"icon" : @"react"},
		@{@"title" : @"Custom Reaction Animation", @"icon" : @"video"},
		@{@"title" : @"Suggest Replacement Link...", @"icon" : @"copy"},
	];
	__weak typeof(self) weakSelf = self;
	[TGPopupMenu showItems:items atPoint:where inView:host headerView:header
				  onChoice:^(NSInteger choice, NSString *title){
		TGEmojiPanel *me = weakSelf;
		if (!me)
			return;
		if (choice == 0)
			[me showAnimatedEmoji:emoji];
		else if (choice == 1)
			[me showReactionInfoForEmoji:emoji];
		else if (choice == 2)
			[me showCustomReactionAnimation];
		else if (choice == 3)
			[me showEmojiSuggestionLink];
	}];
}

/// The animated version of one emoji, which most of the plain set does not
/// have; a 404 is the normal answer rather than a failure worth a red sheet.
- (void)showAnimatedEmoji:(NSString *)emoji {
	__weak typeof(self) weakSelf = self;
	[[TGEmojiStore shared] animatedEmojiForEmoji:emoji completion:^(NSDictionary *animated){
		TGEmojiPanel *me = weakSelf;
		if (!me)
			return;
		if (!animated){
			[TGAlertSheet showMessage:
					[NSString stringWithFormat:@"Telegram has no animated %@.", emoji]
								 title:@"Animated Emoji"
								inView:(me.window ?: me)];
			return;
		}
		[me showStickerPreview:animated caption:emoji];
	}];
}

/// Title, availability, and the animation Telegram plays for the reaction.
/// A reaction that exists but carries no animation still gets its text card.
- (void)showReactionInfoForEmoji:(NSString *)emoji {
	__weak typeof(self) weakSelf = self;
	[[TGEmojiStore shared] reactionForEmoji:emoji completion:^(NSDictionary *reaction){
		TGEmojiPanel *me = weakSelf;
		if (!me)
			return;
		if (!reaction){
			[TGAlertSheet showMessage:
					[NSString stringWithFormat:@"%@ is not a reaction.", emoji]
								 title:@"Reaction"
								inView:(me.window ?: me)];
			return;
		}
		NSString *title = [reaction[@"title"] length] ? reaction[@"title"] : emoji;
		NSString *caption = [NSString stringWithFormat:@"%@ · %@", title,
				[reaction[@"active"] boolValue] ? @"Available" : @"Not available"];
		NSDictionary *animation = reaction[@"animation"];
		if (animation){
			[me showStickerPreview:animation caption:caption];
			return;
		}
		[TGAlertSheet showMessage:caption title:@"Reaction" inView:(me.window ?: me)];
	}];
}

/// The generic TGS set Telegram ships for custom-emoji reactions. The first
/// one is the sample: the panel has no custom reaction to name, so playing
/// the set's own preview is the honest reading.
- (void)showCustomReactionAnimation {
	__weak typeof(self) weakSelf = self;
	[[TGEmojiStore shared] customEmojiReactionAnimationsWithCompletion:^(NSArray *stickers){
		TGEmojiPanel *me = weakSelf;
		if (!me)
			return;
		NSDictionary *first = stickers.firstObject;
		if (!first){
			[TGAlertSheet showMessage:@"Telegram sent no custom reaction animations."
								 title:@"Custom Reactions"
								inView:(me.window ?: me)];
			return;
		}
		[me showStickerPreview:first caption:@"Custom reaction animation"];
	}];
}

/// The translation platform's link for proposing a better emoji keyword.
/// It expires after 30 seconds, so it is fetched when the card is opened and
/// never kept.
- (void)showEmojiSuggestionLink {
	__weak typeof(self) weakSelf = self;
	[[TGEmojiStore shared] suggestionsUrlForLanguage:nil completion:^(NSString *url){
		TGEmojiPanel *me = weakSelf;
		if (!me)
			return;
		if (!url.length){
			[TGAlertSheet showMessage:@"Telegram did not return a suggestion link."
								 title:@"Suggest Emoji"
								inView:(me.window ?: me)];
			return;
		}
		UIView *host = me.window ?: me;
		[TGAlertSheet showChoices:@[@"Copy Link", @"Open", @"Cancel"]
							title:@"Suggest Emoji Replacement"
						  message:url
				   destructiveIndex:-1
						   inView:host
						 onChoice:^(NSInteger index){
			if (index == 0){
				[UIPasteboard generalPasteboard].string = url;
			} else if (index == 1){
				NSURL *link = [NSURL URLWithString:url];
				if (link)
					[[UIApplication sharedApplication] openURL:link];
			}
		}];
	}];
}

/// A card with an animated sticker in its header and one line under it. The
/// renderer is the same one the sticker tab uses, so .tgs and .webm both play
/// without the card knowing which one it was handed.

@end
