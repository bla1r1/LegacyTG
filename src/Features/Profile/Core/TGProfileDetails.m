#import "TGProfileViewControllerInternal.h"
#import "TGClientInternal.h"
#import "TGNameWithStatus.h"
#import "TGCustomEmojiStore.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGMemberCell.h"
#import "TGGroupMemberActions.h"
#import "TGProfileAudioViewController.h"
#import "TGMusicPlayer.h"
#import "TGChatViewController.h"
#import "TGSimilarChannelsViewController.h"
#import "TGDMTopicsViewController.h"
#import "UIImage+WebP.h"
#import <AVFoundation/AVFoundation.h>
#import "TGProfileViewController.h"
#import "TGProfileLogic.h"




/// Flattened messages carry a unix date, not a formatted stamp; the shared
/// lists want a short one beside each row.
/// A file's size as the row prints it. The file info sheet has its own copy;
/// this one is only the compact line under a name here.
static NSString *TGProfileFileSize(NSNumber *bytes) {
	long long value = [bytes longLongValue];
	if (value <= 0)
		return nil;
	if (value < 1024)
		return [NSString stringWithFormat:@"%lld B", value];
	if (value < 1024 * 1024)
		return [NSString stringWithFormat:@"%.0f KB", value / 1024.0];
	return [NSString stringWithFormat:@"%.1f MB", value / (1024.0 * 1024.0)];
}

static NSString *TGProfileDurationText(NSNumber *seconds) {
	NSInteger value = [seconds integerValue];
	if (value <= 0)
		return nil;
	return [NSString stringWithFormat:@"%ld:%02ld", (long)(value / 60), (long)(value % 60)];
}

static NSString *TGProfileShortDate(NSNumber *date) {
	if (![date isKindOfClass:NSNumber.class] || !date.doubleValue)
		return nil;
	static NSDateFormatter *formatter = nil;
	if (!formatter){
		formatter = [[NSDateFormatter alloc] init];
		formatter.dateStyle = NSDateFormatterMediumStyle;
		formatter.timeStyle = NSDateFormatterNoStyle;
	}
	return [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:date.doubleValue]];
}

/// The gift glyph: the sticker's own emoji drawn large. Every gift cell
/// starts here, and the sticker thumbnail replaces the image once the
/// download lands - until then the row is never blank (B5).
static UIImage *TGGiftGlyph(NSString *emoji) {
	if (!emoji.length || ![TGCapabilities canDrawEmoji:emoji])
		return nil;
	static NSCache *cache = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ cache = [[NSCache alloc] init]; });
	NSString *key = [emoji stringByAppendingFormat:@"@40"];
	UIImage *cached = [cache objectForKey:key];
	if (cached)
		return cached;

	UIGraphicsBeginImageContextWithOptions(CGSizeMake(kGiftTile, kGiftTile), NO, 0);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	[emoji drawInRect:CGRectMake(kGiftTileInset, kGiftTileInset,
								 kGiftTile - TGDoubled(kGiftTileInset),
								 kGiftTile - TGDoubled(kGiftTileInset))
			 withFont:TGFontEmoji()
		lineBreakMode:NSLineBreakByClipping
		   alignment:NSTextAlignmentCenter];
#pragma clang diagnostic pop
	UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	[cache setObject:img forKey:key];
	return img;
}

/// The bar under the selected tab, and the room a text row leaves at its sides.
static const CGFloat kMediaTabLine = 2.0f;
static NSString *TGProfileUserName(NSDictionary *user) {
	if (!user) return @"";
	NSString *first = user[@"first_name"] ?: @"";
	NSString *last = user[@"last_name"] ?: @"";
	if (first.length && last.length)
		return [NSString stringWithFormat:@"%@ %@", first, last];
	return first.length ? first : last;
}

static const CGFloat kDetailInset = TGMetricPadWide;

static const CGFloat kMusicStripInset = TGMetricPadMedium;
static const CGFloat kMusicTitleTop   = TGMetricPadSmall;
static const CGFloat kMusicArtistTop  = TGMetricPadSmall + TGMetricLineMicro;
static const CGFloat kMusicChevronSide = TGMetricGiftStar;

static const CGFloat kMinDetailTextWidth = TGMetricActionRow;
static const CGFloat kSimilarChannelsOverlapRatio = 2.0f / 3.0f;

static int64_t TGProfileChatIdFromItem(id item) {
	if ([item isKindOfClass:[NSDictionary class]]) {
		id rawId = item[@"id"];
		if ([rawId respondsToSelector:@selector(longLongValue)])
			return [rawId longLongValue];
	} else if ([item respondsToSelector:@selector(longLongValue)]) {
		return [item longLongValue];
	}
	return 0;
}

/// Overlaps up to three avatars with CoreGraphics into a single bitmap.
/// Each circular face is clipped in the context, separated from its neighbour
/// by a ring cut into the prior face using cardBackgroundColour.
static UIImage *TGProfileCompositeSimilarAvatars(NSArray *images, UIColor *ringColour) {
	if (!images.count)
		return nil;
	CGFloat side = TGMetricMenuGlyph;
	CGFloat scale = [UIScreen mainScreen].scale;
	CGFloat shift = ceilf(side * kSimilarChannelsOverlapRatio);
	NSUInteger count = images.count;
	CGFloat totalWidth = (count == 1) ? side : (shift * (count - 1) + side);
	CGSize totalSize = CGSizeMake(totalWidth, side);

	UIGraphicsBeginImageContextWithOptions(totalSize, NO, scale);
	CGContextRef ctx = UIGraphicsGetCurrentContext();

	CGFloat ringWidth = TGMetricBorderThick;
	if (!ringColour)
		ringColour = [[TGTheme shared] cardBackgroundColour];

	for (NSUInteger i = 0; i < count; i++) {
		CGFloat x = i * shift;
		CGRect avatarRect = CGRectMake(x, 0, side, side);

		if (i > 0) {
			CGContextSaveGState(ctx);
			CGFloat prevX = (i - 1) * shift;
			CGRect prevRect = CGRectMake(prevX, 0, side, side);
			UIBezierPath *prevAvatarClip = [UIBezierPath bezierPathWithOvalInRect:prevRect];
			[prevAvatarClip addClip];

			CGRect ringRect = CGRectInset(avatarRect, -ringWidth, -ringWidth);
			UIBezierPath *ringPath = [UIBezierPath bezierPathWithOvalInRect:ringRect];
			[ringColour setFill];
			[ringPath fill];
			CGContextRestoreGState(ctx);
		}

		CGContextSaveGState(ctx);
		UIBezierPath *clipPath = [UIBezierPath bezierPathWithOvalInRect:avatarRect];
		[clipPath addClip];

		UIImage *img = images[i];
		[img drawInRect:avatarRect];
		CGContextRestoreGState(ctx);
	}

	UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return result;
}

static NSString *TGProfileTruncateToThreeLines(NSString *text, UIFont *font, CGFloat width, CGFloat maxH) {
	if (!text.length)
		return @"";
	CGSize fullSize = [text sizeWithFont:font constrainedToSize:CGSizeMake(width, CGFLOAT_MAX) lineBreakMode:NSLineBreakByWordWrapping];
	if (fullSize.height <= maxH + 1.0f)
		return text;

	NSString *moreSuffix = @"... more";
	NSUInteger low = 0;
	NSUInteger high = text.length;
	NSUInteger best = 0;
	while (low <= high) {
		NSUInteger mid = (low + high) / 2;
		NSString *cand = [NSString stringWithFormat:@"%@ %@", [text substringToIndex:mid], moreSuffix];
		CGSize sz = [cand sizeWithFont:font constrainedToSize:CGSizeMake(width, CGFLOAT_MAX) lineBreakMode:NSLineBreakByWordWrapping];
		if (sz.height <= maxH + 1.0f) {
			best = mid;
			low = mid + 1;
		} else {
			if (mid == 0) break;
			high = mid - 1;
		}
	}
	NSString *base = [text substringToIndex:best];
	NSRange lastSpace = [base rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] options:NSBackwardsSearch];
	if (lastSpace.location != NSNotFound && lastSpace.location > 0) {
		base = [base substringToIndex:lastSpace.location];
	}
	base = [base stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!base.length && best > 0)
		base = [text substringToIndex:best];
	return [NSString stringWithFormat:@"%@... more", base];
}




@implementation TGProfileViewController (TGProfileDetails)

#pragma mark - details model
- (NSArray *)basicDetailsRows {
	return TGProfileUserInfoRows(@{
		@"phoneNumber"     : self.phoneNumber ?: @"",
		@"username"        : self.username ?: @"",
		@"activeUsernames" : self.activeUsernames ?: @[],
	});
}

/// The whole card, rebuilt once full info answers. Order and row kinds come
/// from TGProfileUserInfoRows so the host tests can check them without UIKit.
- (NSArray *)fullDetailsRowsWithBio:(NSString *)bio birthday:(NSString *)birthday {
	return TGProfileUserInfoRows(@{
		@"phoneNumber"     : self.phoneNumber ?: @"",
		@"username"        : self.username ?: @"",
		@"activeUsernames" : self.activeUsernames ?: @[],
		@"isScam"          : @(self.isScam),
		@"isFake"          : @(self.isFake),
		@"birthday"        : birthday ?: @"",
		@"bio"             : bio ?: @"",
		@"note"            : self.personalNote ?: @"",
		@"businessLocation": self.businessLocation ?: @"",
		@"isOwnProfile"    : @(self.isOwnProfile),
		@"isContact"       : @(self.isContact),
		@"isBot"           : @(self.isBot),
		@"blocked"         : @(self.blocked),
	});
}

/// The person's personal channel: one getChat, then a row at the top of the
/// card that opens it like any chat the list holds.
- (void)fetchEmojiStatusImage:(int64_t)emojiId {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] customEmojiStickersForIds:@[@(emojiId)] completion:^(NSArray *stickers){
		NSNumber *thumb = stickers.count ? stickers[0][@"thumbId"] : nil;
		if (![thumb isKindOfClass:NSNumber.class] || !thumb.integerValue)
			return;
		[[TGClient shared] downloadFile:thumb.integerValue
							   priority:TGDownloadPriorityAvatar
							 completion:^(NSString *path){
			if (!path.length)
				return;
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				UIImage *image = [UIImage imageWithContentsOfFile:path]
						?: [UIImage convertFromWebP:path compressedData:nil error:nil];
				dispatch_async(dispatch_get_main_queue(), ^{
					if (!image)
						return;
					weakSelf.emojiStatusImage = image;
					[weakSelf buildHeader];
				});
			});
		}];
	}];
}

- (void)fetchPersonalChannel:(int64_t)chatId {
	if (self.personalChannel)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] chatRecordForChat:chatId completion:^(NSDictionary *chat){
		TGProfileViewController *me = weakSelf;
		if (!me || !chat)
			return;
		NSString *title = chat[@"title"] ?: @"";
		NSNumber *photoId = chat[@"photo"][@"small"][@"id"];
		me.personalChannel = @{
			@"chatId" : @(chatId),
			@"title" : title,
			@"photoFileId" : [photoId isKindOfClass:NSNumber.class] ? photoId : @0,
		};
		if ([photoId isKindOfClass:[NSNumber class]] && photoId.integerValue > 0 &&
				!me.chatAvatars[@(chatId)]){
			[me loadAvatarForChatId:chatId kind:@"channel"];
		}
		// The personal channel is its own section above the card, not a row
		// inside it. Its row is a chat-list item, so the last post reads as
		// the preview under the channel name.
		[[TGClient shared] memberCountForChat:chatId completion:^(NSInteger count){
			TGProfileViewController *again = weakSelf;
			if (!again)
				return;
			again.personalChannelMemberCount = count;
			[again reloadTableDebounced];
		}];
		[[TGClient shared] historyForChat:chatId limit:1 completion:^(NSArray *messages){
			TGProfileViewController *again = weakSelf;
			if (!again)
				return;
			NSDictionary *last = messages.lastObject;
			NSString *preview = [last[@"text"] isKindOfClass:NSString.class]
					? last[@"text"] : @"";
			if (!preview.length && [last[@"photoId"] respondsToSelector:@selector(longLongValue)])
				preview = @"Photo";
			again.personalChannelPreview = preview;
			[again reloadTableDebounced];
		}];
		[me reloadTableDebounced];
	}];
}

- (void)reloadTableDebounced {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(doReloadTable) object:nil];
	[self performSelector:@selector(doReloadTable) withObject:nil afterDelay:0.05];
}

- (void)doReloadTable {
	[self rebuildSections];
}


@end
