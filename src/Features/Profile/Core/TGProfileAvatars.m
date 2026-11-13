#import "TGProfileViewControllerInternal.h"
#import "TGPeerStore.h"
#import "TGLocalization.h"
#import "TGProfileStore.h"
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




@implementation TGProfileViewController (TGProfileAvatars)

#pragma mark - row avatars and composite icons

- (void)loadAvatarForChatId:(int64_t)chatId kind:(NSString *)kind {
	if (!chatId)
		return;
	if (self.chatAvatars[@(chatId)])
		return;
	if ([self.requestedChatAvatars containsObject:@(chatId)])
		return;
	[self.requestedChatAvatars addObject:@(chatId)];

	__weak typeof(self) weakSelf = self;
	[[TGPeerStore shared] loadAvatarForPeer:chatId side:TGMetricMenuGlyph
								 completion:^(UIImage *round){
		TGProfileViewController *me = weakSelf;
		if (!me)
			return;
		if (!round){
			if (![kind isEqualToString:@"communityChat"])
				return;
			NSString *title = [[TGPeerStore shared] peerForId:chatId].title ?: @"";
			round = [TGIcons avatarWithInitials:[TGIcons initialsForTitle:title]
										   size:TGMetricMenuGlyph colourId:chatId];
			if (!round)
				return;
		}
		me.chatAvatars[@(chatId)] = round;
		[me reloadTableDebounced];
		if ([kind isEqualToString:@"communityChat"]){
			NSDictionary *fullComm = [[TGProfileStore shared] cachedCommunityFullInfo:me.communityId];
			NSArray *chats = [fullComm[@"chats"] isKindOfClass:[NSArray class]] ? fullComm[@"chats"] : @[];
			NSUInteger count = MIN((NSUInteger)3, chats.count);
			NSMutableArray *cids = [NSMutableArray arrayWithCapacity:count];
			for (NSUInteger i = 0; i < count; i++){
				int64_t cId = [chats[i][@"chatId"] longLongValue];
				if (cId != 0) [cids addObject:@(cId)];
			}
			[me checkAndCompositeCommunityAvatars:cids];
		}
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

		UIImage *cached = [[TGPeerStore shared] cachedAvatarForPeer:cId
															   side:TGMetricMenuGlyph];
		if (cached){
			[self handleSimilarAvatarLoaded:cached forChatId:cId];
			continue;
		}

		__weak typeof(self) weakSelf = self;
		[[TGPeerStore shared] loadAvatarForPeer:cId side:TGMetricMenuGlyph
									 completion:^(UIImage *image){
			TGProfileViewController *me = weakSelf;
			if (!me)
				return;
			if (image){
				[me handleSimilarAvatarLoaded:image forChatId:cId];
				return;
			}
			NSString *title = [[TGPeerStore shared] peerForId:cId].title ?: @"";
			CGFloat side = TGMetricMenuGlyph;
			UIImage *initials = [TGIcons avatarWithInitials:[TGIcons initialsForTitle:title]
													   size:side
												   colourId:cId];
			if (initials)
				[me handleSimilarAvatarLoaded:initials forChatId:cId];
		}];
	}
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
	for (NSDictionary *c in [TGProfileStore shared].communities) {
		if ([c[@"id"] longLongValue] == self.communityId) {
			commRecord = c;
			break;
		}
	}
	NSDictionary *fullComm = [[TGProfileStore shared] cachedCommunityFullInfo:self.communityId];
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
		commSubtitle = TGLocalizedFormat(@"Community with %@ chats", @(commChats.count));
	} else {
		commSubtitle = @"Community";
	}

	self.communityName = commName;
	self.communitySubtitle = commSubtitle;
	[self loadCommunityPhotoOrAvatars];
	[self reloadTableDebounced];
}

- (void)loadCommunityPhotoOrAvatars {
	if (self.communityId == 0) return;
	if (self.chatAvatars[@(self.communityId)]) return;

	NSDictionary *commRecord = nil;
	for (NSDictionary *c in [TGProfileStore shared].communities) {
		if ([c[@"id"] longLongValue] == self.communityId) {
			commRecord = c;
			break;
		}
	}
	NSDictionary *fullComm = [[TGProfileStore shared] cachedCommunityFullInfo:self.communityId];
	int64_t photoId = [commRecord[@"photoFileId"] respondsToSelector:@selector(longLongValue)]
			? [commRecord[@"photoFileId"] longLongValue] : 0;
	if (photoId == 0 && [fullComm[@"photoFileId"] respondsToSelector:@selector(longLongValue)]) {
		photoId = [fullComm[@"photoFileId"] longLongValue];
	}

	__weak typeof(self) weakSelf = self;
	if (photoId != 0) {
		[[TGProfileStore shared] downloadFile:photoId priority:TGDownloadPriorityAvatar completion:^(NSString *path){
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
		UIImage *cached = [[TGPeerStore shared] cachedAvatarForPeer:cId
															   side:TGMetricMenuGlyph];
		if (cached){
			self.chatAvatars[@(cId)] = cached;
			continue;
		}
		[self loadAvatarForChatId:cId kind:@"communityChat"];
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
