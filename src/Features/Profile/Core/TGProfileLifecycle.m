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
#import "TGProfileHeaderView.h"
#import "TGNewContactViewController.h"
#import "TGLocalization.h"
#import "TGGroupSettingsViewController.h"
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




@implementation TGProfileViewController (TGProfileLifecycle)

#pragma mark - lifecycle
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
							  duration:(NSTimeInterval)duration {
	[super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
	// Grid tiles are laid out to the width at build time; rebuilding the rows
	// lets the table re-ask their metrics at the new width.
	[self rebuildSections];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	// A profile carries no title in the bar: the name in the header already
	// says whose it is.
	self.title = @"";
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	[self applyTheme];
	[self updateNavigationItem];

	// The status line listens to the network too (B4): a profile opened
	// offline used to freeze at its captured last-seen.
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(statusLabelOwnerChanged:)
			name:TGConnectionStateChangedNotification object:nil];
	[nc addObserver:self selector:@selector(statusLabelOwnerChanged:)
			name:TGUserStatusChangedNotification object:nil];
	// A bio edited elsewhere, a member added to the group: the full record
	// arrives as its own update and this screen used to need a reopen.
	[nc addObserver:self selector:@selector(fullInfoChanged:)
			name:TGFullInfoChangedNotification object:nil];
	// Someone joined, was promoted or removed, or asked to join: the member
	// rows and the request count are both read in loadDetails.
	[nc addObserver:self selector:@selector(membersChanged:)
			name:TGChatMembersChangedNotification object:nil];

	[self buildHeader];
	[self rebuildSections];
	[self loadDetails];
	[self loadMedia];

	// A tap opens who they are; a hold keeps the member sheet that used to
	// be the only thing a tap did. Cancelling touches on recognition stops
	// the lift after a hold from also selecting the row underneath.
	UILongPressGestureRecognizer *memberHold = [[UILongPressGestureRecognizer alloc]
			initWithTarget:self action:@selector(memberRowHeld:)];
	memberHold.minimumPressDuration = 0.5;
	memberHold.cancelsTouchesInView = YES;
	[self.tableView addGestureRecognizer:memberHold];

	__weak typeof(self) weakSelf = self;
	[[NSNotificationCenter defaultCenter] addObserverForName:TGThemeChangedNotification
			object:nil queue:[NSOperationQueue mainQueue]
		 usingBlock:^(NSNotification *note) {
		[weakSelf applyTheme];
		[weakSelf buildHeader];
		[weakSelf rebuildSections];
	}];

	[[NSNotificationCenter defaultCenter] addObserverForName:TGCustomEmojiLoadedNotification
			object:nil queue:[NSOperationQueue mainQueue]
		 usingBlock:^(NSNotification *note) {
		TGProfileViewController *me = weakSelf;
		if (!me)
			return;
		[NSObject cancelPreviousPerformRequestsWithTarget:me selector:@selector(reloadEmojiStatusRows) object:nil];
		[me performSelector:@selector(reloadEmojiStatusRows) withObject:nil afterDelay:0.3];
	}];
}

- (void)reloadEmojiStatusRows {
	[self buildHeader];
	NSArray *visible = [self.tableView indexPathsForVisibleRows];
	if (visible.count) {
		[self.tableView reloadRowsAtIndexPaths:visible withRowAnimation:UITableViewRowAnimationNone];
	}
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self applyTheme];
	[self updateNavigationItem];
	if (self.isOwnProfile){
		NSString *ownName = TGProfileUserName([TGClient shared].me);
		if (ownName.length)
			self.name = ownName;
		[self loadDetails];
	}
}

- (void)updateNavigationItem {
	NSMutableArray *items = [NSMutableArray array];
	// My Profile posts a story from the bar; every profile you may edit gets
	// the Edit word on the right.
	if (self.isOwnProfile){
		// Same control as the chat list's: the official ring at the bar's
		// button size, in the bar-button colour.
		UIButton *storyButton = [UIButton buttonWithType:UIButtonTypeCustom];
		CGFloat side = TGMetricButtonMediumH;
		storyButton.frame = CGRectMake(0, 0, side, side);
		[storyButton setImage:[TGIcons glyphNamed:@"addStory"
				colour:[[TGTheme shared] barButtonColour] side:side]
				forState:UIControlStateNormal];
		[storyButton addTarget:self action:@selector(addStoryTapped)
				forControlEvents:UIControlEventTouchUpInside];
		UIBarButtonItem *story = [[UIBarButtonItem alloc] initWithCustomView:storyButton];
		[items addObject:story];
	}
	// A creator or administrator can edit a group/channel profile too; the
	// role arrives after the first answer, so updateNavigationItem is called
	// again when it does.
	BOOL canEdit = self.isOwnProfile || self.isContact ||
			(self.chatId && self.canManage);
	if (canEdit){
		[items addObject:[[UIBarButtonItem alloc]
				initWithTitle:TGLocalized(@"Edit")
						style:UIBarButtonItemStylePlain
					   target:self
					   action:@selector(editProfileTapped)]];
	}
	// Files, Music and Links search from the bar while their pane is open.
	NSString *kind = [self selectedMediaKind];
	if (!self.mediaSearchActive && TGProfileMediaKindSupportsSearch(kind)){
		[items addObject:[[UIBarButtonItem alloc]
				initWithBarButtonSystemItem:UIBarButtonSystemItemSearch
									 target:self action:@selector(mediaSearchTapped)]];
	}
	self.navigationItem.rightBarButtonItems = items.count ? items : nil;
}

/// A contact's Edit fills the contact form with the name and number the
/// profile already knows; the form writes only on Done.
- (void)editProfileTapped {
	// A group or channel's Edit is its settings screen (official opens the
	// peer's edit mode there); the account editor would rename the user.
	// A user's profile carries its private chat id too; userId is 0 only
	// for a group or channel.
	if (self.chatId && !self.userId){
		TGGroupSettingsViewController *settings = [[TGGroupSettingsViewController alloc] init];
		settings.chatId = self.chatId;
		settings.chatTitle = self.name;
		settings.hidesBottomBarWhenPushed = YES;
		TGPresentControllerFrom(settings, self);
		return;
	}
	if (!self.isOwnProfile && self.isContact){
		TGNewContactViewController *edit = [[TGNewContactViewController alloc] init];
		edit.title = TGLocalized(@"Edit");
		edit.userId = self.userId;
		NSArray *words = [self.name componentsSeparatedByString:@" "];
		edit.first = words.firstObject ?: @"";
		edit.last = words.count > 1
				? [[words subarrayWithRange:NSMakeRange(1, words.count - 1)]
						componentsJoinedByString:@" "] : @"";
		edit.phone = self.phoneNumber ?: @"";
		UINavigationController *nav = [[UINavigationController alloc]
				initWithRootViewController:edit];
		[self presentViewController:nav animated:YES completion:nil];
		return;
	}
	TGEditProfileViewController *edit = [[TGEditProfileViewController alloc] init];
	edit.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:edit animated:YES];
}

- (void)applyTheme {
	[super applyTheme];
	TGTheme *theme = [TGTheme shared];
	[theme styleGroupedTable:self.tableView];
	[theme styleNavigationBar:self.navigationController.navigationBar];
	if (self.similarChannelsCompositeImage) {
		self.similarChannelsCompositeImage = nil;
		[self checkAndCompositeSimilarChannelsAvatars];
	}
}

/// The profile as the current client draws it: a large picture centred, the
/// name and status under it, and a row of tiles for the things you actually do
/// here. The coloured block this replaced is the old design; everything since
/// Downloads decode off the main thread and the circle is baked into the
/// bitmap, so the scrolling header never carries a masked layer.
- (void)applyAvatarImageAtPath:(NSString *)path {
	if (!path.length)
		return;
	CGFloat side = TGMetricProfileAvatar;
	CGFloat scale = [UIScreen mainScreen].scale;
	__weak typeof(self) weakSelf = self;
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
			weakSelf.avatarImage = round;
			weakSelf.headerView.avatarImage = round;
		});
	});
}


@end
