#import "TGProfileViewControllerInternal.h"
#import "TGMediaViewer.h"
#import "TGGiftViewController.h"
#import "TGLottieView.h"
#import <objc/runtime.h>
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGStoryViewerViewController.h"
#import "TGProfileTabs.h"
#import "TGProfileTrackCell.h"
#import "TGClientInternal.h"
#import "TGIcons.h"
#import "TGCapabilities.h"
#import "TGLocalization.h"
#import "TGProfileLogic.h"

/// The address a piece of text links to: a text link's own URL, or the first URL
/// typed in it. Nil when it has none.
NSURL *TGProfileFirstURL(NSString *text, NSArray *entities) {
	if (![entities isKindOfClass:NSArray.class])
		return nil;
	for (NSDictionary *entity in entities){
		NSDictionary *type = entity[@"type"];
		NSString *name = [type isKindOfClass:NSDictionary.class] ? type[@"@type"] : nil;
		NSString *url = nil;
		if ([name isEqualToString:@"textEntityTypeTextUrl"])
			url = type[@"url"];
		else if ([name isEqualToString:@"textEntityTypeUrl"]){
			NSInteger offset = [entity[@"offset"] integerValue], length = [entity[@"length"] integerValue];
			if (length > 0 && (NSUInteger)(offset + length) <= text.length)
				url = [text substringWithRange:NSMakeRange((NSUInteger)offset, (NSUInteger)length)];
		}
		if (!url.length)
			continue;
		NSURL *parsed = [NSURL URLWithString:url];
		return parsed.scheme.length ? parsed
				: [NSURL URLWithString:[@"http://" stringByAppendingString:url]];
	}
	return nil;
}

/// Two tabs share the story tiles: what is on the page, and the archive.
static BOOL TGKindIsStories(NSString *kind) {
	return [kind isEqualToString:@"stories"] || [kind isEqualToString:@"archive"];
}

@implementation TGProfileViewController (Media)

- (void)loadMedia {
	// The two panes that decide whether their tabs exist at all.
	[self fetchMediaForKind:@"stories"];
	[self fetchMediaForKind:@"gifts"];
	[self fetchAllMediaCounts];
}

- (void)fetchAllMediaCounts {
	if (!self.chatId)
		return;
	NSDictionary *filters = @{
		@"media" : @"searchMessagesFilterPhotoAndVideo",
		@"files" : @"searchMessagesFilterDocument",
		@"music" : @"searchMessagesFilterAudio",
		@"voice" : @"searchMessagesFilterVoiceAndVideoNote",
		@"links" : @"searchMessagesFilterUrl",
	};
	__weak typeof(self) weakSelf = self;
	[filters enumerateKeysAndObjectsUsingBlock:^(NSString *kind, NSString *filterType, BOOL *stop){
		[[TGClient shared] messageCountInChat:weakSelf.chatId
									   filter:filterType
								   completion:^(NSInteger count){
			TGProfileViewController *me = weakSelf;
			if (!me || count <= 0)
				return;
			me.mediaCounts[kind] = @(count);
			[me reloadTableDebounced];
		}];
	}];
}

/// One pane's first page. A kind is fetched once and re-used until the
/// profile is reopened; switching tabs does not send the same search again.
- (void)fetchMediaForKind:(NSString *)kind {
	if (!kind.length)
		return;
	if ([self.loadedMediaKinds containsObject:kind] ||
			[self.loadingMediaKinds containsObject:kind])
		return;
	if ([kind isEqualToString:@"groups"] && !self.userId)
		return;
	[self.loadingMediaKinds addObject:kind];

	NSDictionary *filters = @{@"media" : @"searchMessagesFilterPhotoAndVideo",
							  @"files" : @"searchMessagesFilterDocument",
							  @"music" : @"searchMessagesFilterAudio",
							  @"voice" : @"searchMessagesFilterVoiceAndVideoNote",
							  @"links" : @"searchMessagesFilterUrl"};
	NSString *filterForCount = filters[kind];
	__weak typeof(self) weakSelf = self;
	void (^done)(NSArray *) = ^(NSArray *rows){
		TGProfileViewController *me = weakSelf;
		if (!me)
			return;
		[me.loadingMediaKinds removeObject:kind];
		[me.loadedMediaKinds addObject:kind];
		NSArray *safe = rows ?: @[];
		if ([kind isEqualToString:@"media"])
			me.photos = safe;
		else if ([kind isEqualToString:@"files"])
			me.files = safe;
		else if ([kind isEqualToString:@"music"])
			me.music = safe;
		else if ([kind isEqualToString:@"voice"])
			me.voice = safe;
		else if ([kind isEqualToString:@"links"])
			me.links = safe;
		else if ([kind isEqualToString:@"groups"])
			me.groupsInCommon = safe;
		else if ([kind isEqualToString:@"stories"])
			me.stories = safe;
		else if ([kind isEqualToString:@"archive"])
			me.archivedStories = safe;
		else if ([kind isEqualToString:@"gifts"])
			me.gifts = safe;
		// A search answers one page, so its total is asked for separately. The
		// other kinds arrive whole.
		if (filterForCount)
			[[TGClient shared] messageCountInChat:me.chatId filter:filterForCount
									   completion:^(NSInteger count){
				me.mediaCounts[kind] = @(count);
				[me reloadTableDebounced];
			}];
		else if (![kind isEqualToString:@"gifts"])
			me.mediaCounts[kind] = @(safe.count);
		if ([kind isEqualToString:@"media"] || TGKindIsStories(kind) ||
				[kind isEqualToString:@"gifts"]){
			me.storyGridCellCache = nil;
			me.mediaGridCacheContent = nil;
		}
		[me reloadTableDebounced];
	};

	if ([kind isEqualToString:@"stories"]){
		[[TGClient shared] storiesForChat:self.chatId completion:done];
	} else if ([kind isEqualToString:@"archive"]){
		[[TGClient shared] archivedStoriesForChat:self.chatId completion:done];
	} else if ([kind isEqualToString:@"gifts"]){
		NSDictionary *owner = [self giftOwnerSenderId];
		if (owner){
			__weak typeof(self) weakProfile = self;
			[[TGClient shared] giftsForOwner:owner offset:@"" completion:^(NSArray *gifts, NSString *nextOffset, NSInteger totalCount){
				TGProfileViewController *me = weakProfile;
				if (!me) return;
				me.giftsNextOffset = nextOffset;
				if (totalCount > 0)
					me.mediaCounts[@"gifts"] = @(totalCount);
				done(gifts);
			}];
		} else {
			done(@[]);
		}
	} else if ([kind isEqualToString:@"groups"]){
		[[TGClient shared] groupsInCommonWithUser:self.userId completion:done];
	} else {
		if (!filterForCount){
			[self.loadingMediaKinds removeObject:kind];
			return;
		}
		[[TGClient shared] mediaInChat:self.chatId filter:filterForCount completion:done];
	}
}

/// A tab only loads when its section is on screen; the details card stays the
/// first thing an open profile costs.
- (void)loadVisibleMediaTabIfNeeded {
	CGRect section = [self.tableView rectForSection:kSectionMedia];
	if (!CGRectIntersectsRect(section, self.tableView.bounds))
		return;
	NSString *kind = [self selectedMediaKind];
	if (kind)
		[self fetchMediaForKind:kind];
}

/// The bar across the top of the shared section, in their order: Media,
/// Files, Music, Voice, Links, Groups, then Stories and Gifts when they have
/// something to show. The category a profile was set to open on moves first.
- (NSArray *)currentMediaTabs {
	NSDictionary *titles = @{@"stories" : @"Stories", @"gifts" : @"Gifts", @"media" : @"Media",
							 @"files" : @"Files", @"music" : @"Music", @"voice" : @"Voice",
							 @"links" : @"Links", @"groups" : @"Groups", @"archive" : @"Archive"};
	// Your own user id is also your Saved Messages chat. Its tabs belong to that
	// chat's profile; My Profile has what you publish, and your archive.
	BOOL own = self.isOwnProfile;
	BOOL ownPublic = own && ![self showsSavedMessages];
	NSMutableArray *out = [NSMutableArray array];
	for (NSString *kind in TGProfileTabKinds(!own && self.stories.count, self.gifts.count > 0,
			self.commonGroupCount > 0, ownPublic, self.mainMediaKind))
		[out addObject:@{@"title" : titles[kind], @"kind" : kind}];
	return out;
}

/// A tab tap: the pane's first page is fetched now, not when the profile was
/// opened. The grid caches are per kind, so they are dropped with the switch.
- (void)mediaTabSelected:(NSString *)kind {
	if (!kind.length)
		return;
	self.storedMediaKind = kind;
	self.storyGridCellCache = nil;
	self.mediaGridCacheContent = nil;
	[self.thumbnailsRequested removeAllObjects];
	[self fetchMediaForKind:kind];
	self.mediaSearchActive = NO;
	self.mediaSearchQuery = nil;
	self.mediaSearchBar.text = @"";
	self.mediaSearchBar.showsCancelButton = NO;
	[self.mediaSearchBar resignFirstResponder];
	[self updateNavigationItem];
	CGPoint offset = self.tableView.contentOffset;
	[self.tableView reloadData];
	CGFloat maxY = self.tableView.contentSize.height - self.tableView.bounds.size.height;
	maxY = MAX(0, maxY);
	offset.y = MIN(MAX(offset.y, 0), maxY);
	[self.tableView setContentOffset:offset animated:NO];
}

/// Media is a strip you push sideways; Stories is a grid that wraps, the way
/// the sticker panel lays its rows out.
- (BOOL)selectedTabIsGrid {
	NSString *kind = [self selectedMediaKind];
	// Media became a grid of its own: one row of the table holds the tiles
	// the photo strip used to (B1). Stories share the same renderer, and
	// gifts read like the official sheet: big square tiles.
	return [kind isEqualToString:@"media"] || TGKindIsStories(kind) ||
		   [kind isEqualToString:@"gifts"];
}

/// The poster's face in the corner of a story tile, and the mark that says a
/// tile is a video rather than a picture.
static const CGFloat kStoryFace      = 26.0f;
static const CGFloat kVideoMark      = 16.0f;
static const CGFloat kVideoMarkInset = TGMetricPadWide;

/// Edge to edge, like the media strip: the tile is whatever is left after the
/// gaps, not a fixed 76 with the remainder thrown away as margin.
+ (CGFloat)storySideForWidth:(CGFloat)width {
	return floorf((width - kStoryGridGap * (kStoryGridCols - 1)) / kStoryGridCols);
}

- (NSDictionary *)giftOwnerSenderId {
	if (self.userId)
		return @{@"@type" : @"messageSenderUser", @"user_id" : @(self.userId)};
	if (self.chatId)
		return @{@"@type" : @"messageSenderChat", @"chat_id" : @(self.chatId)};
	return nil;
}

static const char kGiftTileTagKey;

+ (void)loadCollectibleBackdropWithCenterColor:(int32_t)centerColor
									 edgeColor:(int32_t)edgeColor
										  side:(CGFloat)side
									completion:(void (^)(UIImage *image))completion {
	if (!completion)
		return;

	NSString *key = [NSString stringWithFormat:@"%x-%x@%g", centerColor, edgeColor, side];
	static NSCache *cache = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		cache = [[NSCache alloc] init];
	});
	UIImage *cached = [cache objectForKey:key];
	if (cached) {
		completion(cached);
		return;
	}

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		UIImage *img = [[self class] collectibleBackdropWithCenterColor:centerColor edgeColor:edgeColor side:side];
		dispatch_async(dispatch_get_main_queue(), ^{
			completion(img);
		});
	});
}

+ (UIImage *)collectibleBackdropWithCenterColor:(int32_t)centerColor
									  edgeColor:(int32_t)edgeColor
										   side:(CGFloat)side {
	static NSCache *cache = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		cache = [[NSCache alloc] init];
	});
	NSString *key = [NSString stringWithFormat:@"%x-%x@%g", centerColor, edgeColor, side];
	UIImage *cached = [cache objectForKey:key];
	if (cached)
		return cached;

	static const CGFloat kRGBDivisor = 255.0f;
	CGFloat rC = ((centerColor >> 16) & 0xFF) / kRGBDivisor;
	CGFloat gC = ((centerColor >> 8)  & 0xFF) / kRGBDivisor;
	CGFloat bC = ( centerColor        & 0xFF) / kRGBDivisor;

	CGFloat rE = ((edgeColor >> 16) & 0xFF) / kRGBDivisor;
	CGFloat gE = ((edgeColor >> 8)  & 0xFF) / kRGBDivisor;
	CGFloat bE = ( edgeColor        & 0xFF) / kRGBDivisor;

	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGFloat components[8] = {
		rC, gC, bC, 1.0f,
		rE, gE, bE, 1.0f
	};
	CGFloat locations[2] = { 0.0f, 1.0f };
	CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, components, locations, 2);

	UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), YES, [UIScreen mainScreen].scale);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGPoint center = CGPointMake(TGHalf(side), TGHalf(side));
	CGFloat radius = side;
	CGContextDrawRadialGradient(ctx, gradient, center, 0, center, radius, kCGGradientDrawsAfterEndLocation);
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

	CGGradientRelease(gradient);
	CGColorSpaceRelease(colorSpace);

	if (image)
		[cache setObject:image forKey:key];
	return image;
}

/// A gift tile wears its emoji drawn large - the artwork the tab strip
/// carries until a decodable picture exists. Sized for the grid, checking
/// canDrawEmoji so unavailable emoji do not stall the device.
+ (UIImage *)giftTileGlyph:(NSString *)emoji side:(CGFloat)side {
	if (!emoji.length || ![TGCapabilities canDrawEmoji:emoji])
		return nil;
	static NSCache *cache = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ cache = [[NSCache alloc] init]; });
	NSString *key = [emoji stringByAppendingFormat:@"@%g", side];
	UIImage *cached = [cache objectForKey:key];
	if (cached)
		return cached;

	UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), NO, 0);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	CGFloat inset = side * TGMetricEmojiArtworkInsetRatio * 2;
	[emoji drawInRect:CGRectMake(inset, inset, side - TGDoubled(inset), side - TGDoubled(inset))
			 withFont:TGFontBoldAtSize(TGHalf(side))
		lineBreakMode:NSLineBreakByClipping
		   alignment:NSTextAlignmentCenter];
#pragma clang diagnostic pop
	UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	if (img)
		[cache setObject:img forKey:key];
	return img;
}

- (void)addGiftTile:(NSDictionary *)tile
			  frame:(CGRect)frame
			  index:(NSInteger)index
			 toView:(UIView *)container
			   side:(CGFloat)side {
	BOOL isCollectible = [tile[@"isCollectible"] boolValue];
	NSString *giftTag = tile[@"receivedGiftId"];
	if (![giftTag isKindOfClass:[NSString class]] || !giftTag.length) {
		giftTag = [NSString stringWithFormat:@"gift_%ld", (long)index];
	}

	if (isCollectible) {
		int32_t centerColor = [tile[@"backdropCenterColor"] intValue];
		int32_t edgeColor = [tile[@"backdropEdgeColor"] intValue];
		UIImageView *bg = [[UIImageView alloc] initWithFrame:frame];
		bg.contentMode = UIViewContentModeScaleAspectFill;
		bg.clipsToBounds = YES;
		[container addSubview:bg];
		objc_setAssociatedObject(bg, &kGiftTileTagKey, giftTag, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

		__weak typeof(bg) weakBg = bg;
		__weak typeof(container) weakContainer = container;
		NSString *curTag = giftTag;
		[[self class] loadCollectibleBackdropWithCenterColor:centerColor edgeColor:edgeColor side:side completion:^(UIImage *img){
			if (weakBg.superview == weakContainer && [objc_getAssociatedObject(weakBg, &kGiftTileTagKey) isEqualToString:curTag]) {
				weakBg.image = img;
			}
		}];

		NSNumber *thumbId = tile[@"modelThumbFileId"];
		NSNumber *stickerId = tile[@"modelStickerFileId"];

		if ([thumbId isKindOfClass:[NSNumber class]] && thumbId.integerValue > 0) {
			UIImageView *art = [[UIImageView alloc] initWithFrame:frame];
			art.contentMode = UIViewContentModeScaleAspectFit;
			art.clipsToBounds = YES;
			[container addSubview:art];
			objc_setAssociatedObject(art, &kGiftTileTagKey, giftTag, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

			__weak typeof(art) weakArt = art;
			[[TGClient shared] downloadFile:thumbId.integerValue
								   priority:TGDownloadPriorityOnScreen
								 completion:^(NSString *path){
				if (!path.length) return;
				dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
					UIImage *img = [TGIcons decodedImageAtPath:path
												   fittingSize:CGSizeMake(side, side)
														  fill:NO
														 scale:[UIScreen mainScreen].scale];
					if (!img) return;
					dispatch_async(dispatch_get_main_queue(), ^{
						if (weakArt.superview == weakContainer && [objc_getAssociatedObject(weakArt, &kGiftTileTagKey) isEqualToString:curTag]) {
							weakArt.image = img;
						}
					});
				});
			}];
		} else if ([stickerId isKindOfClass:[NSNumber class]] && stickerId.integerValue > 0) {
			TGLottieView *lottie = [[TGLottieView alloc] initWithFrame:frame];
			lottie.clipsToBounds = YES;
			[container addSubview:lottie];
			objc_setAssociatedObject(lottie, &kGiftTileTagKey, giftTag, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

			__weak typeof(lottie) weakLottie = lottie;
			[[TGClient shared] downloadFile:stickerId.integerValue
								   priority:TGDownloadPriorityOnScreen
								 completion:^(NSString *path){
				if (!path.length) return;
				dispatch_async(dispatch_get_main_queue(), ^{
					if (weakLottie.superview != weakContainer || ![objc_getAssociatedObject(weakLottie, &kGiftTileTagKey) isEqualToString:curTag])
						return;
					weakLottie.onStickerReady = ^{
						[weakLottie stop];
					};
					if ([weakLottie loadStickerFile:path]) {
						[weakLottie stop];
					}
				});
			}];
		}

		UILabel *numLabel = [[UILabel alloc] initWithFrame:CGRectMake(
				frame.origin.x, frame.origin.y + side - TGMetricLineCaption - TGMetricPadTiny,
				side, TGMetricLineCaption)];
		numLabel.text = [NSString stringWithFormat:@"#%ld", (long)[tile[@"number"] integerValue]];
		numLabel.font = TGFontCaptionStrong();
		numLabel.textColor = [[TGTheme shared] onMediaColour];
		numLabel.textAlignment = NSTextAlignmentCenter;
		numLabel.backgroundColor = [UIColor clearColor];
		[container addSubview:numLabel];
	} else {
		UIView *bg = [[UIView alloc] initWithFrame:frame];
		bg.backgroundColor = [[TGTheme shared] fileTileColour];
		bg.clipsToBounds = YES;
		[container addSubview:bg];

		// The picture keeps clear of the star count under it.
		CGRect artFrame = CGRectMake(frame.origin.x + TGMetricPad, frame.origin.y + TGMetricPadSmall,
				side - TGDoubled(TGMetricPad), side - TGMetricLineCaption - TGMetricPadTiny - TGMetricPadSmall);
		NSNumber *thumbId = tile[@"thumbFileId"];
		NSNumber *stickerId = tile[@"stickerFileId"];
		NSString *curTag = giftTag;
		__weak typeof(container) weakContainer = container;

		if ([thumbId isKindOfClass:[NSNumber class]] && thumbId.integerValue > 0) {
			UIImageView *art = [[UIImageView alloc] initWithFrame:artFrame];
			art.contentMode = UIViewContentModeScaleAspectFit;
			art.clipsToBounds = YES;
			[container addSubview:art];
			objc_setAssociatedObject(art, &kGiftTileTagKey, giftTag, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

			__weak typeof(art) weakArt = art;
			[[TGClient shared] downloadFile:thumbId.integerValue
								   priority:TGDownloadPriorityOnScreen
								 completion:^(NSString *path){
				if (!path.length) return;
				dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
					UIImage *img = [TGIcons decodedImageAtPath:path
												   fittingSize:CGSizeMake(side, side)
														  fill:NO
														 scale:[UIScreen mainScreen].scale];
					if (!img) return;
					dispatch_async(dispatch_get_main_queue(), ^{
						if (weakArt.superview == weakContainer && [objc_getAssociatedObject(weakArt, &kGiftTileTagKey) isEqualToString:curTag]) {
							weakArt.image = img;
						}
					});
				});
			}];
		} else if ([stickerId isKindOfClass:[NSNumber class]] && stickerId.integerValue > 0) {
			NSString *emoji = tile[@"emoji"];
			if ([emoji isKindOfClass:[NSString class]] && emoji.length && [TGCapabilities canDrawEmoji:emoji]) {
				UIImageView *emojiArt = [[UIImageView alloc] initWithFrame:artFrame];
				emojiArt.contentMode = UIViewContentModeScaleAspectFit;
				emojiArt.clipsToBounds = YES;
				emojiArt.image = [[self class] giftTileGlyph:emoji side:side];
				[container addSubview:emojiArt];
			}

			TGLottieView *lottie = [[TGLottieView alloc] initWithFrame:artFrame];
			lottie.clipsToBounds = YES;
			[container addSubview:lottie];
			objc_setAssociatedObject(lottie, &kGiftTileTagKey, giftTag, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

			__weak typeof(lottie) weakLottie = lottie;
			[[TGClient shared] downloadFile:stickerId.integerValue
								   priority:TGDownloadPriorityOnScreen
								 completion:^(NSString *path){
				if (!path.length) return;
				dispatch_async(dispatch_get_main_queue(), ^{
					if (weakLottie.superview != weakContainer || ![objc_getAssociatedObject(weakLottie, &kGiftTileTagKey) isEqualToString:curTag])
						return;
					weakLottie.onStickerReady = ^{
						[weakLottie stop];
					};
					if ([weakLottie loadStickerFile:path]) {
						[weakLottie stop];
					}
				});
			}];
		} else {
			NSString *emoji = tile[@"emoji"];
			if ([emoji isKindOfClass:[NSString class]] && emoji.length && [TGCapabilities canDrawEmoji:emoji]) {
				UIImageView *art = [[UIImageView alloc] initWithFrame:artFrame];
				art.contentMode = UIViewContentModeScaleAspectFit;
				art.clipsToBounds = YES;
				art.image = [[self class] giftTileGlyph:emoji side:side];
				[container addSubview:art];
			}
		}

		UILabel *starLabel = [[UILabel alloc] initWithFrame:CGRectMake(
				frame.origin.x, frame.origin.y + side - TGMetricLineCaption - TGMetricPadTiny,
				side, TGMetricLineCaption)];
		NSInteger stars = [tile[@"starCount"] integerValue];
		starLabel.text = TGLocalizedPluralValue(@"%@ Star", @"%@ Stars",
				[NSString stringWithFormat:@"%ld", (long)stars], stars);
		starLabel.font = TGFontCaptionStrong();
		starLabel.textColor = [[TGTheme shared] primaryTextColour];
		starLabel.textAlignment = NSTextAlignmentCenter;
		starLabel.backgroundColor = [UIColor clearColor];
		[container addSubview:starLabel];
	}

	UIButton *tap = [UIButton buttonWithType:UIButtonTypeCustom];
	tap.frame = frame;
	tap.tag = 700 + index;
	[tap addTarget:self action:@selector(giftTileTapped:)
		  forControlEvents:UIControlEventTouchUpInside];
	[container addSubview:tap];
}

- (CGFloat)storyGridHeight {
	NSString *kind = [self selectedMediaKind];
	BOOL storyKind = TGKindIsStories(kind);
	BOOL giftKind = [kind isEqualToString:@"gifts"];
	NSInteger dataCount = storyKind ? (NSInteger)[self selectedMediaRows].count
						: giftKind ? (NSInteger)self.gifts.count
						: (NSInteger)self.photos.count;
	NSInteger count = MIN(dataCount, 120);
	if (!count)
		return 0;
	NSInteger rows = (count + kStoryGridCols - 1) / kStoryGridCols;
	CGFloat side = [[self class] storySideForWidth:self.tableView.bounds.size.width];
	return rows * side + (rows - 1) * kStoryGridGap;
}

/// The stories as a wrapping grid of pictures, each one opening its story.
/// Cached like the media strip: rebuilding it on every pass through
/// cellForRow handed back a grid whose pictures had already been asked for
/// and so never arrived again - scrolling away and back emptied it.
- (void)photoTileTapped:(UIButton *)button {
	NSInteger index = button.tag - 600;
	if (index >= 0 && index < (NSInteger)self.photos.count) {
		[TGMediaViewer presentItems:self.photos startAt:index inChat:self.chatId];
	}
}

- (UITableViewCell *)mediaGridCellForTableView:(UITableView *)tableView atRow:(NSInteger)row {
	static NSString *const kGridReuseId = @"TGMediaGridRowCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kGridReuseId];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:kGridReuseId];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		cell.backgroundColor = [UIColor clearColor];
	}

	for (UIView *v in [cell.contentView.subviews copy]) {
		[v removeFromSuperview];
	}

	NSString *kind = [self selectedMediaKind];
	BOOL storyKind = TGKindIsStories(kind);
	BOOL giftKind  = [kind isEqualToString:@"gifts"];

	NSArray *rows = [self selectedMediaRows];
	CGFloat width = tableView.bounds.size.width;
	CGFloat side  = [[self class] storySideForWidth:width];

	for (NSInteger c = 0; c < kStoryGridCols; c++) {
		NSInteger i = row * kStoryGridCols + c;
		if (i >= (NSInteger)rows.count)
			break;

		NSDictionary *tile = rows[i];
		CGRect frame = CGRectMake(c * (side + kStoryGridGap), 0, side, side);

		if (giftKind) {
			[self addGiftTile:tile frame:frame index:i toView:cell.contentView side:side];
			continue;
		}

		NSNumber *fileId = storyKind
				? (tile[@"thumbPhotoId"] ?: tile[@"photoId"])
				: (tile[@"photoId"] ?: tile[@"thumbPhotoId"]);

		UIImageView *thumb = [[UIImageView alloc] initWithFrame:frame];
		thumb.backgroundColor = [[TGTheme shared] fileTileColour];
		thumb.contentMode = UIViewContentModeScaleAspectFill;
		thumb.clipsToBounds = YES;
		[cell.contentView addSubview:thumb];

		if (storyKind || [tile[@"kind"] isEqualToString:@"messageVideo"] || [tile[@"isVideo"] boolValue]) {
			if ([tile[@"isVideo"] boolValue] || [tile[@"kind"] isEqualToString:@"messageVideo"]) {
				UIImageView *mark = [[UIImageView alloc] initWithFrame:
						CGRectMake(side - kVideoMarkInset, side - kVideoMarkInset, kVideoMark, kVideoMark)];
				mark.image = [TGIcons glyphNamed:@"video" colour:[[TGTheme shared] onMediaColour] side:kVideoMark];
				[thumb addSubview:mark];
			}
		}

		UIButton *tap = [UIButton buttonWithType:UIButtonTypeCustom];
		tap.frame = frame;
		if (storyKind) {
			tap.tag = 500 + i;
			[tap addTarget:self action:@selector(storyTileTapped:) forControlEvents:UIControlEventTouchUpInside];
			[self addStoryHoldTo:tap];
		} else {
			tap.tag = 600 + i;
			[tap addTarget:self action:@selector(photoTileTapped:) forControlEvents:UIControlEventTouchUpInside];
		}
		[cell.contentView addSubview:tap];

		if ([fileId integerValue] > 0) {
			__weak typeof(thumb) weakThumb = thumb;
			[[TGClient shared] downloadFile:fileId.integerValue
								   priority:TGDownloadPriorityOnScreen
								 completion:^(NSString *path){
				dispatch_async(dispatch_get_main_queue(), ^{
					[TGIcons loadImageAtPath:path into:weakThumb];
				});
			}];
		}
	}

	return cell;
}

/// One grid renderer serves every tile-shaped category: photos for "media"
/// and story tiles for "stories". A grid means no collection view - iOS 6
/// has one, but this screen stretches a grouped table instead, and one row
/// of it holds this scroller-less cell (B1: media drew the story tiles and
/// the photo strip was a second, forgetful cache).
- (UITableViewCell *)mediaGridCell:(UITableView *)tableView {
	NSString *kind = [self selectedMediaKind];
	BOOL storyKind = TGKindIsStories(kind);
	BOOL giftKind = [kind isEqualToString:@"gifts"];
	// One cache per kind: the rows themselves change shape between them,
	// and a grid built for photos cannot be re-faced for gifts.
	NSString *cacheName = kind;

	if ([self.mediaGridCacheContent isEqualToString:cacheName] && self.storyGridCellCache)
		return self.storyGridCellCache;

	UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
												   reuseIdentifier:nil];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;

	NSArray *rows = [self selectedMediaRows];
	CGFloat width = tableView.bounds.size.width;
	CGFloat side = [[self class] storySideForWidth:width];
	NSInteger count = MIN((NSInteger)rows.count, 120);

	for (NSInteger i = 0; i < count; i++){
		NSDictionary *tile = rows[i];
		CGRect frame = CGRectMake((i % kStoryGridCols) * (side + kStoryGridGap),
								  (i / kStoryGridCols) * (side + kStoryGridGap),
								  side, side);

		if (giftKind){
			[self addGiftTile:tile frame:frame index:i toView:cell.contentView side:side];
			continue;
		}

		// Story tiles render their thumbnail, photo tiles whatever the
		// message carries. The tile list asks for the list-sized render,
		// not the largest one; a 105 pt square is at most 220 px wide and
		// the queue is shared with everything else (B2).
		NSNumber *fileId = storyKind
				? (tile[@"thumbPhotoId"] ?: tile[@"photoId"])
				: (tile[@"photoId"] ?: tile[@"thumbPhotoId"]);

		UIImageView *thumb = [[UIImageView alloc] initWithFrame:frame];
		thumb.backgroundColor = [[TGTheme shared] fileTileColour];
		thumb.contentMode = UIViewContentModeScaleAspectFill;
		thumb.clipsToBounds = YES;
		[cell.contentView addSubview:thumb];

		if (storyKind){
			if ([tile[@"isVideo"] boolValue]){
				UIImageView *mark = [[UIImageView alloc] initWithFrame:
						CGRectMake(side - kVideoMarkInset, side - kVideoMarkInset, kVideoMark, kVideoMark)];
				mark.image = [TGIcons glyphNamed:@"video" colour:[[TGTheme shared] onMediaColour]
									  side:kVideoMark];
				[thumb addSubview:mark];
			}

			UIButton *tap = [UIButton buttonWithType:UIButtonTypeCustom];
			tap.frame = frame;
			tap.tag = 500 + i;
			[tap addTarget:self action:@selector(storyTileTapped:)
				  forControlEvents:UIControlEventTouchUpInside];
			[self addStoryHoldTo:tap];
			[cell.contentView addSubview:tap];
		}

		if ([fileId integerValue] > 0){
			__weak typeof(self) weakSelf = self;
			[[TGClient shared] downloadFile:fileId.integerValue
								   priority:TGDownloadPriorityOnScreen
								 completion:^(NSString *path){
				[TGIcons loadImageAtPath:path into:thumb];
				(void)weakSelf;
			}];
		}
	}

	self.storyGridCellCache = cell;
	self.mediaGridCacheContent = cacheName;
	return cell;
}

/// The cover is downloaded once per file id and kept with the other profile
/// pictures. A 44 pt row asks for the same thumbnail the chat's track bubble
/// uses, not a 300 px render.
- (void)applyArtworkToTrackCell:(UITableViewCell *)cell
						message:(NSDictionary *)message
					  indexPath:(NSIndexPath *)indexPath {
	TGProfileTrackCell *trackCell = (TGProfileTrackCell *)cell;
	NSNumber *coverId = [message[@"albumCoverId"] isKindOfClass:NSNumber.class]
			? message[@"albumCoverId"] : nil;
	if (!coverId){
		[trackCell setArtworkImage:nil];
		return;
	}
	UIImage *cover = self.coverImages[coverId];
	[trackCell setArtworkImage:cover];
	if (cover || [self.thumbnailsRequested containsObject:coverId])
		return;
	[self.thumbnailsRequested addObject:coverId];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] downloadFile:coverId.integerValue
						   priority:TGDownloadPriorityOnScreen
						 completion:^(NSString *path){
		if (!path.length)
			return;
		UIImage *image = [TGIcons decodedImageAtPath:path
										fittingSize:CGSizeMake(TGMetricTrackArt, TGMetricTrackArt)
											   fill:YES
											  scale:[UIScreen mainScreen].scale];
		UIImage *rounded = [TGIcons roundedImage:image
										 size:CGSizeMake(TGMetricTrackArt, TGMetricTrackArt)
									   radius:TGMetricCornerSmall
									  corners:UIRectCornerAllCorners];
		TGProfileViewController *me = weakSelf;
		if (!rounded || !me)
			return;
		me.coverImages[coverId] = rounded;
		[me.tableView reloadRowsAtIndexPaths:@[indexPath]
							withRowAnimation:UITableViewRowAnimationNone];
	}];
}

/// The host of the first URL entity in a message, or nil. The profile's Links
/// tab shows where a link goes, not the paragraph it arrived in.
- (NSString *)linkDomainForMessage:(NSDictionary *)message {
	return TGProfileFirstURL(message[@"text"], message[@"entities"]).host.lowercaseString;
}

/// What the selected tab shows; nil for the photo strip, which is not a list.
- (NSString *)selectedMediaKind {
	NSString *kind = self.storedMediaKind;
	// td_api's profileTabPosts is the stories on the page. There is no GIF pane
	// here yet, so that one opens the media grid rather than a dead kind.
	if ([kind isEqualToString:@"posts"])
		kind = @"stories";
	else if ([kind isEqualToString:@"gifs"])
		kind = @"media";
	// The answer is only valid while that kind still has a tab: stories end,
	// gifts empty out, and holding a dead kind would render a toolbar
	// selection that no longer matches. Falling back to the photo strip is
	// what the official clients do.
	NSArray *tabs = [self currentMediaTabs];
	for (NSDictionary *tab in tabs)
		if ([tab[@"kind"] isEqualToString:kind])
			return kind;
	return tabs.firstObject[@"kind"];
}

/// Saved Messages' own profile: the chat opened it, and the chat passes a search.
/// Settings' My Profile reaches the same id without one.
- (BOOL)showsSavedMessages {
	return self.chatId && self.chatId == [[TGClient shared] savedMessagesChatId] &&
			self.onSearchTapped != nil;
}

/// The rows behind the selected tab, for the list-shaped categories. A bar
/// search filters the list the pane already holds.
- (NSArray *)selectedMediaRows {
	NSString *kind = [self selectedMediaKind];
	NSArray *rows = @[];
	if ([kind isEqualToString:@"media"])   rows = self.photos ?: @[];
	else if ([kind isEqualToString:@"files"])   rows = self.files ?: @[];
	else if ([kind isEqualToString:@"music"])   rows = self.music ?: @[];
	else if ([kind isEqualToString:@"voice"])   rows = self.voice ?: @[];
	else if ([kind isEqualToString:@"links"])   rows = self.links ?: @[];
	else if ([kind isEqualToString:@"groups"])  rows = self.groupsInCommon ?: @[];
	else if ([kind isEqualToString:@"archive"]) rows = self.archivedStories ?: @[];
	else if ([kind isEqualToString:@"stories"]) rows = self.stories ?: @[];
	else if ([kind isEqualToString:@"gifts"])   rows = self.gifts ?: @[];
	return TGProfileMediaRowsMatchingQuery(rows, self.mediaSearchQuery, kind);
}

/// The bar's Search on Files, Music and Links opens a field above the pane,
/// not a prompt: a prompt hid the rows it was filtering and could not show a
/// keystroke at a time.
- (UISearchBar *)ensureMediaSearchBar {
	if (self.mediaSearchBar)
		return self.mediaSearchBar;
	UISearchBar *bar = [[UISearchBar alloc] initWithFrame:
			CGRectMake(0, 0, self.view.bounds.size.width, TGMetricSearchBarHeight)];
	bar.delegate = self;
	bar.placeholder = TGLocalized(@"Search");
	bar.autocorrectionType = UITextAutocorrectionTypeNo;
	bar.autocapitalizationType = UITextAutocapitalizationTypeNone;
	[[TGTheme shared] styleSearchBar:bar];
	self.mediaSearchBar = bar;
	return bar;
}

- (void)mediaSearchTapped {
	self.mediaSearchActive = YES;
	self.mediaSearchQuery = nil;
	UISearchBar *bar = [self ensureMediaSearchBar];
	bar.text = @"";
	bar.showsCancelButton = YES;
	[self updateNavigationItem];
	[self.tableView reloadData];
	// The field lives at the top of the pane, which may be above the rows
	// the finger was on; bring the field into view before focusing it.
	[self.tableView layoutIfNeeded];
	CGRect header = [self.tableView rectForHeaderInSection:kSectionMedia];
	[self.tableView setContentOffset:CGPointMake(0, header.origin.y) animated:NO];
	// reloadData builds a fresh section header; focus it after the table has
	// put the field back on screen.
	[bar performSelector:@selector(becomeFirstResponder) withObject:nil afterDelay:0];
}

- (void)endMediaSearch {
	self.mediaSearchActive = NO;
	self.mediaSearchQuery = nil;
	self.mediaSearchBar.text = @"";
	self.mediaSearchBar.showsCancelButton = NO;
	[self.mediaSearchBar resignFirstResponder];
	[self updateNavigationItem];
	[self.tableView reloadData];
}

#pragma mark - search bar

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
	self.mediaSearchQuery = [searchText stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	[self.tableView reloadData];
	// The field lives in a section header, which reloadData replaces. Keep
	// the keyboard where the finger left it.
	if (self.mediaSearchActive && !searchBar.isFirstResponder)
		[searchBar performSelector:@selector(becomeFirstResponder) withObject:nil afterDelay:0];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	[searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
	[self endMediaSearch];
}

- (void)storyTileTapped:(UIButton *)button {
	[self openStoryAtIndex:button.tag - 500];
}

- (void)addStoryHoldTo:(UIButton *)tile {
	if (self.isOwnProfile)
		[tile addGestureRecognizer:[[UILongPressGestureRecognizer alloc]
				initWithTarget:self action:@selector(storyTileHeld:)]];
}

/// The manager: holding a tile of My Profile puts the story on the page or takes
/// it off, and it stays in the archive either way. The viewer offers the same.
- (void)storyTileHeld:(UILongPressGestureRecognizer *)hold {
	if (hold.state != UIGestureRecognizerStateBegan)
		return;
	NSArray *rows = [self selectedMediaRows];
	NSInteger index = hold.view.tag - 500;
	if (index < 0 || index >= (NSInteger)rows.count)
		return;
	NSDictionary *story = rows[(NSUInteger)index];
	BOOL posted = [story[@"isPostedToChatPage"] boolValue];
	NSMutableArray *choices = [NSMutableArray array];
	if ([story[@"canToggleIsPostedToChatPage"] boolValue])
		[choices addObject:(posted ? @"Remove from Profile" : @"Add to Profile")];
	if ([story[@"canBeDeleted"] boolValue])
		[choices addObject:@"Delete Story"];
	if (!choices.count)
		return;
	NSInteger deleteIndex = [choices indexOfObject:@"Delete Story"];
	NSInteger destructiveIndex = (deleteIndex != NSNotFound) ? (NSInteger)deleteIndex : (posted ? 0 : -1);
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:choices
						title:nil destructiveIndex:destructiveIndex inView:self.view
					 onChoice:^(NSInteger choice){
		if (choice < 0 || choice >= (NSInteger)choices.count)
			return;
		NSString *picked = choices[(NSUInteger)choice];
		if ([picked isEqualToString:@"Delete Story"]){
			[[TGClient shared] deleteStory:[story[@"storyId"] intValue]
								  fromChat:weakSelf.chatId
								completion:^(BOOL ok, NSString *error){
				TGProfileViewController *me = weakSelf;
				if (!me) return;
				if (!ok){
					[TGAlertSheet showMessage:error ?: @"An error occurred."
										title:@"Delete Story" inView:me.view];
					return;
				}
				[me reloadOwnStories];
			}];
		} else {
			[[TGClient shared] toggleStory:(int32_t)[story[@"storyId"] intValue]
								  fromChat:weakSelf.chatId
						  postedToChatPage:!posted
								completion:^(BOOL ok, NSString *error){
				TGProfileViewController *me = weakSelf;
				if (!me) return;
				if (!ok){
					[TGAlertSheet showMessage:error ?: @"An error occurred."
										title:@"Stories" inView:me.view];
					return;
				}
				[me reloadOwnStories];
			}];
		}
	}];
}

/// Both tabs, because a story moved between them. The viewer can change them too.
- (void)reloadOwnStories {
	if (!self.isOwnProfile)
		return;
	for (NSString *kind in @[@"stories", @"archive"]){
		[self.loadedMediaKinds removeObject:kind];
		[self fetchMediaForKind:kind];
	}
}

/// A gift tile opens the detail sheet, the way the official grid does:
/// artwork on top, From / Date / Cost, an OK button (B5).
- (void)giftTileTapped:(UIButton *)button {
	NSString *kind = [self selectedMediaKind];
	if (![kind isEqualToString:@"gifts"])
		return;
	NSInteger index = button.tag - 700;
	NSArray *rows = [self selectedMediaRows];
	if (index < 0 || index >= (NSInteger)rows.count)
		return;
	TGGiftViewController *vc = [[TGGiftViewController alloc] initWithGift:rows[index]];
	vc.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:vc animated:YES];
}

/// Displays full-screen view for the selected story.
- (void)openStoryAtIndex:(NSInteger)index {
	NSArray *rows = [self selectedMediaRows];
	if (index < 0 || index >= (NSInteger)rows.count)
		return;
	// The profile grid and the chat list's strip open the same viewer. The
	// old inline backdrop lived here and knew nothing about openStory,
	// reactions or the own-story menu.
	TGStoryViewerViewController *viewer = [[TGStoryViewerViewController alloc]
			initWithChatId:self.chatId
					 title:self.title ?: @"Stories"
				   stories:rows
				startIndex:index
				 canManage:self.chatId == [[TGClient shared] savedMessagesChatId]];
	UINavigationController *nav = [[UINavigationController alloc]
			initWithRootViewController:viewer];
	nav.navigationBar.barStyle = UIBarStyleBlack;
	nav.navigationBar.translucent = YES;
	[self presentViewController:nav animated:YES completion:nil];
}

- (void)loadMoreMediaForCurrentTab {
	if (self.isLoadingMoreMedia) return;

	NSString *kind = [self selectedMediaKind];
	if ([kind isEqualToString:@"gifts"]) {
		if (!self.giftsNextOffset.length)
			return;
		NSDictionary *owner = [self giftOwnerSenderId];
		if (!owner)
			return;

		self.isLoadingMoreMedia = YES;
		__weak typeof(self) weakProfile = self;
		[[TGClient shared] giftsForOwner:owner offset:self.giftsNextOffset completion:^(NSArray *more, NSString *nextOffset, NSInteger totalCount){
			dispatch_async(dispatch_get_main_queue(), ^{
				TGProfileViewController *me = weakProfile;
				if (!me) return;
				me.isLoadingMoreMedia = NO;
				me.giftsNextOffset = nextOffset;
				if (totalCount > 0)
					me.mediaCounts[@"gifts"] = @(totalCount);
				if (more.count) {
					NSMutableArray *combined = [NSMutableArray arrayWithArray:me.gifts ?: @[]];
					[combined addObjectsFromArray:more];
					me.gifts = combined;
					me.storyGridCellCache = nil;
					me.mediaGridCacheContent = nil;
					[me reloadTableDebounced];
				}
			});
		}];
		return;
	}

	NSString *filter = nil;
	NSArray *currentList = nil;

	if ([kind isEqualToString:@"media"]) {
		filter = @"searchMessagesFilterPhotoAndVideo";
		currentList = self.photos;
	} else if ([kind isEqualToString:@"files"]) {
		filter = @"searchMessagesFilterDocument";
		currentList = self.files;
	} else if ([kind isEqualToString:@"music"]) {
		filter = @"searchMessagesFilterAudio";
		currentList = self.music;
	} else if ([kind isEqualToString:@"voice"]) {
		filter = @"searchMessagesFilterVoiceAndVideoNote";
		currentList = self.voice;
	} else if ([kind isEqualToString:@"links"]) {
		filter = @"searchMessagesFilterUrl";
		currentList = self.links;
	}

	if (!filter || !currentList.count) return;

	int64_t lastId = [currentList.lastObject[@"id"] longLongValue];
	if (!lastId) return;

	self.isLoadingMoreMedia = YES;
	__weak typeof(self) weakProfile = self;
	[[TGClient shared] mediaInChat:self.chatId filter:filter fromMessageId:lastId limit:60 completion:^(NSArray *more){
		dispatch_async(dispatch_get_main_queue(), ^{
			TGProfileViewController *me = weakProfile;
			if (!me) return;
			me.isLoadingMoreMedia = NO;
			if (!more.count) return;

			if ([kind isEqualToString:@"media"]) {
				me.photos = TGMediaPageAppending(me.photos, more);
				me.storyGridCellCache = nil;
				me.mediaGridCacheContent = nil;
			} else if ([kind isEqualToString:@"files"]) {
				me.files = TGMediaPageAppending(me.files, more);
			} else if ([kind isEqualToString:@"music"]) {
				me.music = TGMediaPageAppending(me.music, more);
			} else if ([kind isEqualToString:@"voice"]) {
				me.voice = TGMediaPageAppending(me.voice, more);
			} else if ([kind isEqualToString:@"links"]) {
				me.links = TGMediaPageAppending(me.links, more);
			}
			[me reloadTableDebounced];
		});
	}];
}

@end
