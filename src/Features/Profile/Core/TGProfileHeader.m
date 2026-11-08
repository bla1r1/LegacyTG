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
#import "TGLocalization.h"




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




@implementation TGProfileViewController (TGProfileHeader)

#pragma mark - header and music
- (void)buildMusicStripIn:(UIView *)header atY:(CGFloat)y {
	NSDictionary *track = self.firstProfileAudio;
	if (!track)
		return;
	TGTheme *theme = [TGTheme shared];
	CGFloat width = header.bounds.size.width;
	UIView *band = [[UIView alloc] initWithFrame:
			CGRectMake(kMusicStripInset, y,
					width - TGDoubled(kMusicStripInset), kMusicStripHeight)];
	band.backgroundColor = [theme cardBackgroundColour];
	band.layer.cornerRadius = TGMetricCornerControl;
	[header addSubview:band];

	UIImageView *glyph = [[UIImageView alloc] initWithFrame:
			CGRectMake(TGMetricPadMedium, TGCenteredOrigin(kMusicStripHeight, kMusicStripGlyph),
					kMusicStripGlyph, kMusicStripGlyph)];
	glyph.image = [TGIcons glyphNamed:@"music" colour:[theme accentColour]
								side:kMusicStripGlyph];
	glyph.contentMode = UIViewContentModeScaleAspectFit;
	[band addSubview:glyph];

	CGFloat textX = TGMetricPadMedium + kMusicStripGlyph + TGMetricPad;
	CGFloat textW = band.bounds.size.width - textX - TGMetricPadMedium - kMusicChevronSide
			- TGMetricPad;
	UILabel *title = [[UILabel alloc] initWithFrame:
			CGRectMake(textX, kMusicTitleTop, textW, TGMetricLineCaption)];
	title.font = TGFontMetaStrong();
	title.textColor = [theme accentColour];
	title.backgroundColor = [UIColor clearColor];
	title.lineBreakMode = NSLineBreakByTruncatingTail;
	title.text = track[@"title"] ?: @"Audio";
	[band addSubview:title];

	UILabel *artist = [[UILabel alloc] initWithFrame:
			CGRectMake(textX, kMusicArtistTop, textW, TGMetricLineCaption)];
	artist.font = TGFontMeta();
	artist.textColor = [theme secondaryTextColour];
	artist.backgroundColor = [UIColor clearColor];
	artist.lineBreakMode = NSLineBreakByTruncatingTail;
	artist.text = [track[@"performer"] length] ? track[@"performer"] : @"Unknown artist";
	[band addSubview:artist];

	UIImageView *chevron = [[UIImageView alloc] initWithFrame:
			CGRectMake(band.bounds.size.width - TGMetricPadMedium - kMusicChevronSide,
					TGCenteredOrigin(kMusicStripHeight, kMusicChevronSide),
					kMusicChevronSide, kMusicChevronSide)];
	chevron.image = [TGIcons glyphNamed:@"forward" colour:[theme secondaryTextColour]
								   side:kMusicChevronSide];
	chevron.contentMode = UIViewContentModeScaleAspectFit;
	[band addSubview:chevron];

	// The whole band is the button, including the glyph and the two lines.
	UIButton *tap = [UIButton buttonWithType:UIButtonTypeCustom];
	tap.frame = band.bounds;
	[tap addTarget:self action:@selector(musicStripTapped)
		  forControlEvents:UIControlEventTouchUpInside];
	[band addSubview:tap];
}

- (void)musicStripTapped {
	TGProfileAudioViewController *audio = [[TGProfileAudioViewController alloc] init];
	audio.userId = self.userId;
	audio.subjectTitle = self.name.length ? self.name : @"Profile Music";
	audio.autoplay = YES;
	audio.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:audio animated:YES];
}

- (void)buildHeader {
	CGFloat width = self.view.bounds.size.width;
	CGFloat side = TGMetricProfileAvatar;
	// Header height is the same stack the constants below lay out: picture,
	// name, status, then the action plate, then the saved-music strip when
	// the account has one.
	// My Profile has no action plate (PeerInfoHeaderNode yields no buttons
	// for isMyProfile), so it reserves none.
	CGFloat actionsHeight = self.isOwnProfile ? 0 : kActionTile;
	CGFloat height = kAvatarTop + side + kActionsTop + actionsHeight + TGMetricPadMedium;
	if (self.firstProfileAudio)
		height += kMusicStripHeight + TGMetricPad;

	UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
	header.backgroundColor = [[TGTheme shared] groupedBackgroundColour];

	self.avatarView = [[UIImageView alloc] initWithFrame:
			CGRectMake(TGCenteredOrigin(width, side), kAvatarTop, side, side)];
	self.avatarView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
			UIViewAutoresizingFlexibleRightMargin;
	// The circle is in the bitmap. A corner radius plus clipsToBounds on a
	// view inside a scrolling table header is a mask the A4 repaints on every
	// scroll step; TGIcons bakes the same circle once.
	self.avatarView.contentMode = UIViewContentModeScaleAspectFill;
	self.avatarView.opaque = NO;
	self.avatarView.backgroundColor = [UIColor clearColor];
	NSString *initials = [TGIcons initialsForTitle:self.name];
	// The header is rebuilt on every answer that changes a mark or a tile. Going
	// back to the initials each time looked like the photo never finished loading.
	self.avatarView.image = self.avatarImage ?: [TGIcons avatarWithInitials:initials
												   size:side
											   colourId:self.userId ?: self.chatId];
	[header addSubview:self.avatarView];

	// The picture is an address to what the account wears: tapping it shows
	// every photo history this profile still holds.
	UITapGestureRecognizer *avatarTap = [[UITapGestureRecognizer alloc]
			initWithTarget:self action:@selector(avatarTapped)];
	[self.avatarView addGestureRecognizer:avatarTap];
	self.avatarView.userInteractionEnabled = YES;

	UILabel *nameLabel = [[UILabel alloc] initWithFrame:
			CGRectMake(kHeaderTextInset, kAvatarTop + side + kNameTop,
					width - TGDoubled(kHeaderTextInset), TGMetricLineTitle)];
	nameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	nameLabel.font = TGFontTitle();
	nameLabel.textAlignment = NSTextAlignmentCenter;
	nameLabel.backgroundColor = [UIColor clearColor];
	nameLabel.textColor = [[TGTheme shared] primaryTextColour];
	nameLabel.attributedText = TGNameWithStatus(self.name ?: @"", self.emojiStatusId, TGFontTitle(), [[TGTheme shared] primaryTextColour]);
	[header addSubview:nameLabel];
	// The marks sit after the centred name. Both are plain images, never masks.
	CGFloat measuredNameW = [self.name sizeWithFont:TGFontTitle()].width;
	if (nameLabel.attributedText.length > 0 && [nameLabel.attributedText respondsToSelector:@selector(boundingRectWithSize:options:context:)]) {
		CGRect r = [nameLabel.attributedText boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, TGMetricLineTitle)
														  options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
														  context:nil];
		measuredNameW = ceilf(r.size.width);
	}
	CGFloat markX = TGHalf(width) + TGHalf(MIN(measuredNameW,
			nameLabel.bounds.size.width)) + TGMetricPadSmall;
	CGFloat markY = kAvatarTop + side + kNameTop + TGCenteredOrigin(TGMetricLineTitle, kNameBadge);
	for (UIImage *mark in @[self.isVerified ? [TGIcons verifiedBadge] : [NSNull null]]){
		if (![mark isKindOfClass:UIImage.class])
			continue;
		UIImageView *badge = [[UIImageView alloc] initWithFrame:
				CGRectMake(markX, markY, kNameBadge, kNameBadge)];
		badge.image = mark;
		badge.contentMode = UIViewContentModeScaleAspectFit;
		[header addSubview:badge];
		markX += kNameBadge + TGMetricPadTiny;
	}

	self.statusLabel = [[UILabel alloc] initWithFrame:
			CGRectMake(kHeaderTextInset, kAvatarTop + side + kStatusTop,
					width - TGDoubled(kHeaderTextInset), TGMetricLineBody)];
	self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.statusLabel.font = TGFontSubhead();
	self.statusLabel.textAlignment = NSTextAlignmentCenter;
	self.statusLabel.textColor = [[TGTheme shared] secondaryTextColour];
	self.statusLabel.backgroundColor = [UIColor clearColor];
	[header addSubview:self.statusLabel];

	[self buildActionsIn:header atY:(kAvatarTop + side + kActionsTop)];

	if (self.firstProfileAudio)
		[self buildMusicStripIn:header
						  atY:(kAvatarTop + side + kActionsTop + actionsHeight + TGMetricPad)];

	// The status line listens to presence too: a status arriving while the
	// profile is open refreshes the line (B4).
	if ([self showsSavedMessages]){
		self.statusLabel.text = nil;
	} else if (self.isOwnProfile){
		// You are using the app, so to yourself you are online. The server's
		// last-seen for your own account lags behind and read like a stranger's.
		self.restingStatus = @"online";
		self.statusLabel.textColor = [[TGTheme shared] accentColour];
		[self statusLabelOwnerChanged:nil];
	} else if (self.userId){
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] statusForUser:self.userId completion:^(NSString *status){
			if (!status.length)
				return;
			if (!weakSelf.isBot)
				weakSelf.restingStatus = status;
			[weakSelf statusLabelOwnerChanged:nil];
		}];
	} else {
		// The count is known from chatProfile on most opens; only fall back
		// to the member request while that answer is still on its way.
		[self updateGroupStatus];
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] memberCountForChat:self.chatId completion:^(NSInteger count){
			if (count > 0 && weakSelf.memberCount <= 0){
				weakSelf.memberCount = count;
				[weakSelf updateGroupStatus];
			}
		}];
	}

	self.tableView.tableHeaderView = header;
	self.tableView.backgroundColor = [[TGTheme shared] groupedBackgroundColour];

	NSNumber *fileId = self.userId
			? [[TGClient shared] photoFileIdForUserId:self.userId]
			: [[TGClient shared] photoFileIdForChat:self.chatId];
	if (!fileId || [fileId isEqual:self.avatarFileId])
		return;
	self.avatarFileId = fileId;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] downloadFile:fileId.integerValue
						   priority:TGDownloadPriorityAvatar
						 completion:^(NSString *path){
		[weakSelf applyAvatarImageAtPath:path];
	}];
}

- (void)updateGroupStatus {
	if (self.userId || self.memberCount <= 0)
		return;
	NSString *count = TGLocalizedPlural(
			self.isChannel ? @"%d subscriber" : @"%d member",
			self.isChannel ? @"%d subscribers" : @"%d members",
			self.memberCount);
	self.restingStatus = self.onlineCount > 0 && !self.isChannel
			? [NSString stringWithFormat:@"%@, %@",
					count, TGLocalizedFormat(@"%@ online",
							[NSString stringWithFormat:@"%ld",
									(long)self.onlineCount])]
			: count;
	[self statusLabelOwnerChanged:nil];
}

- (BOOL)isOwner {
	return [self.myStatus isEqualToString:@"owner"];
}

- (BOOL)isOwnProfile {
	return self.userId && self.userId == [[TGClient shared].me[@"id"] longLongValue];
}

/// What this account may do in a group. The profile needs the same answer
/// Group Settings asks for: a plain member must not see an Add Member tile,
/// and only the owner gets Delete Group rather than Leave Group.

@end
