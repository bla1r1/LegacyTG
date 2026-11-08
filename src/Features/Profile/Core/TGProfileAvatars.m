#import "TGProfileViewControllerInternal.h"
#import "TGClientInternal.h"
#import "TGNameWithStatus.h"
#import "TGCustomEmojiStore.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGMemberCell.h"
#import "TGGroupMemberActions.h"
#import "TGProfileAudioViewController.h"
#import "TGProfileTrackCell.h"
#import "TGMusicPlayer.h"
#import "TGChatViewController.h"
#import "TGSimilarChannelsViewController.h"
#import "TGDMTopicsViewController.h"
#import "UIImage+WebP.h"
#import <AVFoundation/AVFoundation.h>
#import "TGProfileViewController.h"
#import "TGProfileDetailCell.h"




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

static NSString *TGProfileRowGlyphName(NSString *kind) {
	if (![kind isKindOfClass:[NSString class]])
		return nil;
	if ([kind isEqualToString:@"phone"])
		return @"call";
	if ([kind isEqualToString:@"username"])
		return @"mention";
	if ([kind isEqualToString:@"birthday"])
		return @"star";
	if ([kind isEqualToString:@"bio"] || [kind isEqualToString:@"about"] ||
		[kind isEqualToString:@"note"] || [kind isEqualToString:@"addBio"])
		return @"edit";
	if ([kind isEqualToString:@"channel"] || [kind isEqualToString:@"linkedChat"] ||
		[kind isEqualToString:@"community"] || [kind isEqualToString:@"similarChannels"] ||
		[kind isEqualToString:@"directMessages"])
		return @"chat";
	if ([kind isEqualToString:@"businessLocation"])
		return @"archive";
	if ([kind isEqualToString:@"invite"])
		return @"forward";
	if ([kind isEqualToString:@"addContact"])
		return @"contacts";
	if ([kind isEqualToString:@"warning"])
		return @"close";
	return nil;
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




@implementation TGProfileViewController (TGProfileAvatars)

#pragma mark - row avatars and composite icons

- (void)loadAvatarForChatId:(int64_t)chatId kind:(NSString *)kind cell:(TGProfileDetailCell *)cell {
	if (!chatId)
		return;
	if (self.chatAvatars[@(chatId)])
		return;
	if ([self.requestedChatAvatars containsObject:@(chatId)])
		return;
	[self.requestedChatAvatars addObject:@(chatId)];

	NSNumber *photoFileId = [[TGClient shared] photoFileIdForChat:chatId];
	if (![photoFileId isKindOfClass:[NSNumber class]] || photoFileId.integerValue <= 0) {
		if ([kind isEqualToString:@"channel"]) {
			NSNumber *pId = self.personalChannel[@"photoFileId"];
			if ([pId isKindOfClass:[NSNumber class]] && pId.integerValue > 0) {
				photoFileId = pId;
			}
		}
	}
	if ([photoFileId isKindOfClass:[NSNumber class]] && photoFileId.integerValue > 0) {
		[self downloadAvatarWithFileId:photoFileId.integerValue chatId:chatId kind:kind cell:cell];
		return;
	}

	__weak typeof(self) weakSelf = self;
	__weak TGProfileDetailCell *weakCell = cell;
	[[TGClient shared] chatRecordForChat:chatId completion:^(NSDictionary *chat){
		TGProfileViewController *me = weakSelf;
		if (!me || ![chat isKindOfClass:[NSDictionary class]])
			return;
		NSNumber *fileId = chat[@"photo"][@"small"][@"id"];
		if ([fileId isKindOfClass:[NSNumber class]] && fileId.integerValue > 0) {
			[me downloadAvatarWithFileId:fileId.integerValue chatId:chatId kind:kind cell:weakCell];
		}
	}];
}

- (void)downloadAvatarWithFileId:(NSInteger)fileId chatId:(int64_t)chatId kind:(NSString *)kind cell:(TGProfileDetailCell *)cell {
	__weak typeof(self) weakSelf = self;
	__weak TGProfileDetailCell *weakCell = cell;
	[[TGClient shared] downloadFile:fileId
						   priority:TGDownloadPriorityAvatar
						 completion:^(NSString *path){
		if (!path.length)
			return;
		CGFloat side = TGMetricMenuGlyph;
		CGFloat scale = [UIScreen mainScreen].scale;
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			UIImage *image = [TGIcons decodedImageAtPath:path
											 fittingSize:CGSizeMake(side, side)
													fill:YES
												   scale:scale];
			UIImage *round = [TGIcons roundedImage:image
											 size:CGSizeMake(side, side)
										   radius:TGHalf(side)
										  corners:UIRectCornerAllCorners];
			if (!round)
				return;
			dispatch_async(dispatch_get_main_queue(), ^{
				TGProfileViewController *me = weakSelf;
				if (me) {
					me.chatAvatars[@(chatId)] = round;
				}
				TGProfileDetailCell *c = weakCell;
				if (c && [c.rowKind isEqualToString:kind] && c.rowChatId == chatId) {
					c.iconView.image = round;
				}
				if (me && [kind isEqualToString:@"communityChat"]) {
					NSDictionary *fullComm = [[TGClient shared] cachedCommunityFullInfo:me.communityId];
					NSArray *chats = [fullComm[@"chats"] isKindOfClass:[NSArray class]] ? fullComm[@"chats"] : @[];
					NSUInteger count = MIN((NSUInteger)3, chats.count);
					NSMutableArray *cids = [NSMutableArray arrayWithCapacity:count];
					for (NSUInteger i = 0; i < count; i++) {
						int64_t cId = [chats[i][@"chatId"] longLongValue];
						if (cId != 0) [cids addObject:@(cId)];
					}
					[me checkAndCompositeCommunityAvatars:cids];
				}
			});
		});
	}];
}

- (void)loadSimilarChannelsAvatars {
	if (!self.isChannel || !self.similarChatIds.count)
		return;
	if (self.similarChannelsCompositeImage)
		return;

	NSUInteger count = MIN((NSUInteger)3, self.similarChatIds.count);
	for (NSUInteger i = 0; i < count; i++) {
		int64_t cId = TGProfileChatIdFromItem(self.similarChatIds[i]);
		if (!cId)
			continue;
		if (self.similarChannelAvatars[@(cId)])
			continue;
		if ([self.similarChannelsRequested containsObject:@(cId)])
			continue;
		[self.similarChannelsRequested addObject:@(cId)];

		NSNumber *photoFileId = [[TGClient shared] photoFileIdForChat:cId];
		if ([photoFileId isKindOfClass:[NSNumber class]] && photoFileId.integerValue > 0) {
			[self downloadSimilarAvatarWithFileId:photoFileId.integerValue chatId:cId];
			continue;
		}

		__weak typeof(self) weakSelf = self;
		[[TGClient shared] chatRecordForChat:cId completion:^(NSDictionary *chat){
			TGProfileViewController *me = weakSelf;
			if (!me || ![chat isKindOfClass:[NSDictionary class]])
				return;
			NSNumber *fileId = chat[@"photo"][@"small"][@"id"];
			if ([fileId isKindOfClass:[NSNumber class]] && fileId.integerValue > 0) {
				[me downloadSimilarAvatarWithFileId:fileId.integerValue chatId:cId];
			} else {
				NSString *title = chat[@"title"] ?: @"";
				CGFloat side = TGMetricMenuGlyph;
				UIImage *initials = [TGIcons avatarWithInitials:[TGIcons initialsForTitle:title]
														   size:side
													   colourId:cId];
				if (initials) {
					[me handleSimilarAvatarLoaded:initials forChatId:cId];
				}
			}
		}];
	}
}

- (void)downloadSimilarAvatarWithFileId:(NSInteger)fileId chatId:(int64_t)chatId {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] downloadFile:fileId
						   priority:TGDownloadPriorityAvatar
						 completion:^(NSString *path){
		TGProfileViewController *me = weakSelf;
		if (!me)
			return;
		CGFloat side = TGMetricMenuGlyph;
		CGFloat scale = [UIScreen mainScreen].scale;
		if (!path.length) {
			NSString *title = [[TGClient shared] titleForChat:chatId] ?: @"";
			UIImage *initials = [TGIcons avatarWithInitials:[TGIcons initialsForTitle:title]
													   size:side
												   colourId:chatId];
			if (initials) {
				[me handleSimilarAvatarLoaded:initials forChatId:chatId];
			}
			return;
		}
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			UIImage *image = [TGIcons decodedImageAtPath:path
											 fittingSize:CGSizeMake(side, side)
													fill:YES
												   scale:scale];
			UIImage *round = [TGIcons roundedImage:image
											 size:CGSizeMake(side, side)
										   radius:TGHalf(side)
										  corners:UIRectCornerAllCorners];
			dispatch_async(dispatch_get_main_queue(), ^{
				TGProfileViewController *again = weakSelf;
				if (!again)
					return;
				UIImage *picture = round;
				if (!picture) {
					NSString *title = [[TGClient shared] titleForChat:chatId] ?: @"";
					picture = [TGIcons avatarWithInitials:[TGIcons initialsForTitle:title]
													 size:side
												 colourId:chatId];
				}
				if (picture) {
					[again handleSimilarAvatarLoaded:picture forChatId:chatId];
				}
			});
		});
	}];
}

- (void)handleSimilarAvatarLoaded:(UIImage *)avatar forChatId:(int64_t)chatId {
	if (!avatar)
		return;
	self.similarChannelAvatars[@(chatId)] = avatar;
	[self checkAndCompositeSimilarChannelsAvatars];
}

- (void)checkAndCompositeSimilarChannelsAvatars {
	NSUInteger count = MIN((NSUInteger)3, self.similarChatIds.count);
	if (count == 0)
		return;
	NSMutableArray *images = [NSMutableArray arrayWithCapacity:count];
	for (NSUInteger i = 0; i < count; i++) {
		int64_t cId = TGProfileChatIdFromItem(self.similarChatIds[i]);
		UIImage *img = self.similarChannelAvatars[@(cId)];
		if (!img)
			return;
		[images addObject:img];
	}

	UIColor *ringColour = [[TGTheme shared] cardBackgroundColour];
	__weak typeof(self) weakSelf = self;
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		UIImage *composite = TGProfileCompositeSimilarAvatars(images, ringColour);
		dispatch_async(dispatch_get_main_queue(), ^{
			TGProfileViewController *me = weakSelf;
			if (!me || !composite)
				return;
			me.similarChannelsCompositeImage = composite;
			[me reloadTableDebounced];
		});
	});
}

- (void)reloadCommunityRow {
	if (self.communityId == 0) return;
	NSDictionary *commRecord = nil;
	for (NSDictionary *c in [TGClient shared].communities) {
		if ([c[@"id"] longLongValue] == self.communityId) {
			commRecord = c;
			break;
		}
	}
	NSDictionary *fullComm = [[TGClient shared] cachedCommunityFullInfo:self.communityId];
	NSString *commName = commRecord[@"name"];
	if (!commName.length && [fullComm[@"name"] isKindOfClass:[NSString class]]) {
		commName = fullComm[@"name"];
	}
	if (!commName.length) {
		commName = @"Community";
	}
	NSArray *commChats = [fullComm[@"chats"] isKindOfClass:[NSArray class]] ? fullComm[@"chats"] : @[];
	NSString *commSubtitle = nil;
	if (commChats.count > 0) {
		commSubtitle = [NSString stringWithFormat:@"Community with %lu chats", (unsigned long)commChats.count];
	} else {
		commSubtitle = @"Community";
	}

	NSMutableArray *updated = [self.details mutableCopy];
	BOOL found = NO;
	for (NSUInteger i = 0; i < updated.count; i++) {
		NSDictionary *r = updated[i];
		if ([r[@"kind"] isEqualToString:@"community"]) {
			updated[i] = @{
				@"kind" : @"community",
				@"label" : commName,
				@"value" : commSubtitle,
				@"communityId" : @(self.communityId)
			};
			found = YES;
			break;
		}
	}
	if (!found) {
		[updated insertObject:@{
			@"kind" : @"community",
			@"label" : commName,
			@"value" : commSubtitle,
			@"communityId" : @(self.communityId)
		} atIndex:0];
	}
	self.details = updated;
	[self loadCommunityPhotoOrAvatars];
	[self reloadTableDebounced];
}

- (void)loadCommunityPhotoOrAvatars {
	if (self.communityId == 0) return;
	if (self.chatAvatars[@(self.communityId)]) return;

	NSDictionary *commRecord = nil;
	for (NSDictionary *c in [TGClient shared].communities) {
		if ([c[@"id"] longLongValue] == self.communityId) {
			commRecord = c;
			break;
		}
	}
	NSDictionary *fullComm = [[TGClient shared] cachedCommunityFullInfo:self.communityId];
	int64_t photoId = [commRecord[@"photoFileId"] respondsToSelector:@selector(longLongValue)]
			? [commRecord[@"photoFileId"] longLongValue] : 0;
	if (photoId == 0 && [fullComm[@"photoFileId"] respondsToSelector:@selector(longLongValue)]) {
		photoId = [fullComm[@"photoFileId"] longLongValue];
	}

	__weak typeof(self) weakSelf = self;
	if (photoId != 0) {
		[[TGClient shared] downloadFile:photoId priority:TGDownloadPriorityAvatar completion:^(NSString *path){
			if (!path.length) return;
			CGFloat side = TGMetricMenuGlyph;
			CGFloat scale = [UIScreen mainScreen].scale;
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				UIImage *image = [TGIcons decodedImageAtPath:path fittingSize:CGSizeMake(side, side) fill:YES scale:scale];
				UIImage *round = [TGIcons roundedImage:image size:CGSizeMake(side, side) radius:TGHalf(side) corners:UIRectCornerAllCorners];
				if (!round) return;
				dispatch_async(dispatch_get_main_queue(), ^{
					TGProfileViewController *me = weakSelf;
					if (!me) return;
					me.chatAvatars[@(me.communityId)] = round;
					[me reloadTableDebounced];
				});
			});
		}];
		return;
	}

	NSArray *chats = [fullComm[@"chats"] isKindOfClass:[NSArray class]] ? fullComm[@"chats"] : @[];
	NSUInteger count = MIN((NSUInteger)3, chats.count);
	if (count == 0) return;

	NSMutableArray *chatIds = [NSMutableArray arrayWithCapacity:count];
	for (NSUInteger i = 0; i < count; i++) {
		NSDictionary *ch = [chats[i] isKindOfClass:[NSDictionary class]] ? chats[i] : @{};
		int64_t cId = [ch[@"chatId"] longLongValue];
		if (cId != 0) [chatIds addObject:@(cId)];
	}
	if (!chatIds.count) return;

	for (NSNumber *cidNum in chatIds) {
		int64_t cId = [cidNum longLongValue];
		if (self.chatAvatars[@(cId)]) continue;
		NSNumber *pFileId = [[TGClient shared] photoFileIdForChat:cId];
		if ([pFileId isKindOfClass:[NSNumber class]] && pFileId.integerValue > 0) {
			[self downloadAvatarWithFileId:pFileId.integerValue chatId:cId kind:@"communityChat" cell:nil];
			continue;
		}
		[[TGClient shared] chatRecordForChat:cId completion:^(NSDictionary *chat){
			TGProfileViewController *me = weakSelf;
			if (!me || ![chat isKindOfClass:[NSDictionary class]]) return;
			NSNumber *fileId = chat[@"photo"][@"small"][@"id"];
			if ([fileId isKindOfClass:[NSNumber class]] && fileId.integerValue > 0) {
				[me downloadAvatarWithFileId:fileId.integerValue chatId:cId kind:@"communityChat" cell:nil];
			} else {
				NSString *title = chat[@"title"] ?: @"";
				CGFloat side = TGMetricMenuGlyph;
				UIImage *initials = [TGIcons avatarWithInitials:[TGIcons initialsForTitle:title] size:side colourId:cId];
				if (initials) {
					me.chatAvatars[@(cId)] = initials;
					[me checkAndCompositeCommunityAvatars:chatIds];
				}
			}
		}];
	}
	[self checkAndCompositeCommunityAvatars:chatIds];
}

- (void)checkAndCompositeCommunityAvatars:(NSArray *)chatIds {
	if (!chatIds.count) return;
	NSMutableArray *images = [NSMutableArray arrayWithCapacity:chatIds.count];
	for (NSNumber *cidNum in chatIds) {
		UIImage *img = self.chatAvatars[cidNum];
		if (!img) return;
		[images addObject:img];
	}
	UIColor *ringColour = [[TGTheme shared] cardBackgroundColour];
	__weak typeof(self) weakSelf = self;
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		UIImage *composite = TGProfileCompositeSimilarAvatars(images, ringColour);
		dispatch_async(dispatch_get_main_queue(), ^{
			TGProfileViewController *me = weakSelf;
			if (!me || !composite) return;
			me.chatAvatars[@(me.communityId)] = composite;
			[me reloadTableDebounced];
		});
	});
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	if (scrollView != self.tableView) return;
	[self loadVisibleMediaTabIfNeeded];
	CGFloat distanceFromBottom = scrollView.contentSize.height - (scrollView.contentOffset.y + scrollView.bounds.size.height);
	if (distanceFromBottom < 300.0f && !self.isLoadingMoreMedia) {
		[self loadMoreMediaForCurrentTab];
	}
}


@end
