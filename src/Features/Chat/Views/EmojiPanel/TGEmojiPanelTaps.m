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

static inline id TGGetButtonItemData(UIButton *button) {
	return objc_getAssociatedObject(button, &kTGItemDataKey);
}

static const NSInteger kItemTagBase = 1000;  // grid buttons carry their index



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
		if ([section[@"strip"] integerValue] != 1)
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
