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

/// Dates follow the app language, not the device locale: a Russian UI must
/// not print "Mar 5, 1990" in a media list.
static void TGProfileApplyAppLocale(NSDateFormatter *formatter) {
	NSString *language = TGAppLanguage();
	formatter.locale = language.length
			? [NSLocale localeWithLocaleIdentifier:language]
			: [NSLocale currentLocale];
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
	TGProfileApplyAppLocale(formatter);
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




@implementation TGProfileViewController (TGProfileTable)

#pragma mark - table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 8;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == kSectionPersonalChannel) return self.personalChannel ? 1 : 0;
	if (section == kSectionDetails) return self.details.count;
	if (section == kSectionDirectMessages) return 0;
	// Stories and Gifts live in the bar above the shared section now, so the
	// standalone sections would show the same rows a second time.
	if (section == kSectionStories) return 0;
	if (section == kSectionGifts)   return 0;
	if (section == kSectionMembers) return self.members.count;
	if (section == kSectionDanger)
		return (self.userId && self.isContact && !self.isBot &&
				!self.isOwnProfile) ? 1 : 0;

	if (section == kSectionMedia) {
		if (![self currentMediaTabs].count)
			return 0;
		// Media and Stories each draw into grid rows; the rest are lists.
		if ([self selectedTabIsGrid]) {
			NSArray *rows = [self selectedMediaRows];
			return (rows.count + kStoryGridCols - 1) / kStoryGridCols;
		}
		return [self selectedMediaRows].count;
	}
	return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == kSectionPersonalChannel){
		if (!self.personalChannel)
			return nil;
		// The pack has no "Personal Channel" label; Channel is the official
		// noun for the section and the count sits under the name.
		return @"Channel";
	}
	if (section == kSectionMembers){
		if (self.members.count == 0)
			return nil;
		NSInteger count = self.memberCount > 0 ? self.memberCount
											   : (NSInteger)self.members.count;
		if (count <= 0)
			return nil;
		// Telegram counts the whole group here, even when the list below is
		// only the first page it returned.
		return TGLocalizedPlural(
				self.isChannel ? @"%d subscriber" : @"%d member",
				self.isChannel ? @"%d subscribers" : @"%d members", count);
	}
	return nil;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	if (section == kSectionPersonalChannel && self.personalChannel)
		return [self personalChannelHeaderOfWidth:tableView.bounds.size.width];
	if (section == kSectionMedia && [self currentMediaTabs].count) {
		CGFloat width = tableView.bounds.size.width;
		if (!self.mediaSearchActive)
			return [self mediaTabBarOfWidth:width];
		// The search field sits at the top of the pane, above its tabs.
		TGTheme *theme = [TGTheme shared];
		UIView *header = [[UIView alloc] initWithFrame:CGRectMake(TGMetricZero,
				TGMetricZero, width,
				TGMetricSearchBarHeight + kMediaTabsRow)];
		header.backgroundColor = [theme groupedBackgroundColour];
		UISearchBar *bar = [self ensureMediaSearchBar];
		bar.frame = CGRectMake(TGMetricZero, TGMetricZero, width,
							  TGMetricSearchBarHeight);
		bar.showsCancelButton = YES;
		[header addSubview:bar];
		UIView *tabs = [self mediaTabBarOfWidth:width];
		tabs.frame = CGRectMake(TGMetricZero, TGMetricSearchBarHeight, width,
							   kMediaTabsRow);
		[header addSubview:tabs];
		return header;
	}
	return nil;
}

/// Official puts the subscriber count on the section header's right, beside
/// the "Channel" title, rather than under the peer's name in the row.
- (UIView *)personalChannelHeaderOfWidth:(CGFloat)width {
	UIView *header = [[UIView alloc] initWithFrame:
			CGRectMake(0, 0, width, TGMetricMediaStripHeader)];
	TGTheme *theme = [TGTheme shared];
	UILabel *title = [[UILabel alloc] initWithFrame:
			CGRectMake(TGMetricPadLarge, 0, width - TGDoubled(TGMetricPadLarge),
					TGMetricMediaStripHeader)];
	title.font = TGFontCaption();
	title.textColor = [theme sectionHeaderColour];
	title.backgroundColor = [UIColor clearColor];
	title.text = TGLocalized(@"Channel");
	[header addSubview:title];
	if (self.personalChannelMemberCount > 0){
		UILabel *count = [[UILabel alloc] initWithFrame:title.frame];
		count.font = TGFontCaption();
		count.textColor = [theme secondaryTextColour];
		count.textAlignment = NSTextAlignmentRight;
		count.backgroundColor = [UIColor clearColor];
		count.text = TGLocalizedPlural(@"%d subscriber", @"%d subscribers",
				self.personalChannelMemberCount);
		[header addSubview:count];
	}
	return header;
}

/// More tabs than a phone's width holds, so they scroll. The offset is kept by
/// hand because the table builds this view again on every reload, and a tab the
/// finger just reached must not jump back to the start. The selected tab carries
/// the count of what is in it.
- (UIView *)mediaTabBarOfWidth:(CGFloat)width {
	TGTheme *theme = [TGTheme shared];
	UIScrollView *bar = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, width, kMediaTabsRow)];
	bar.backgroundColor = [theme groupedBackgroundColour];
	bar.showsHorizontalScrollIndicator = NO;
	bar.scrollsToTop = NO;
	NSArray *tabs = [self currentMediaTabs];
	NSString *selected = [self selectedMediaKind];
	CGFloat x = TGMetricPadMedium;
	for (NSUInteger i = 0; i < tabs.count; i++){
		NSString *kind = tabs[i][@"kind"];
		BOOL isSelected = [kind isEqualToString:selected];
		// No raw number after a tab title: official shows the count in the
		// pane header, with its plural form.
		// Measure the word the button will show: setTitle: translates, so
		// sizing the English "Voice" cut "Голосовые" to "Го…вые".
		NSString *title = TGLocalized(tabs[i][@"title"] ?: @"");
		UIFont *font = TGFontCaptionStrong();
		CGFloat w = ceilf([title sizeWithFont:font].width) + TGDoubled(TGMetricPadMedium);
		UIButton *tab = [UIButton buttonWithType:UIButtonTypeCustom];
		tab.frame = CGRectMake(x, 0, w, kMediaTabsRow);
		tab.titleLabel.font = font;
		tab.tag = (NSInteger)i;
		[tab setTitle:title forState:UIControlStateNormal];
		[tab setTitleColor:isSelected ? [theme accentColour] : [theme secondaryTextColour]
				  forState:UIControlStateNormal];
		[tab addTarget:self action:@selector(mediaTabTapped:) forControlEvents:UIControlEventTouchUpInside];
		// A group's or channel's main tab is chosen by holding the tab, as
		// the official pane's context menu does.
		if (self.chatId && self.canManage){
			UILongPressGestureRecognizer *hold = [[UILongPressGestureRecognizer alloc]
					initWithTarget:self action:@selector(mediaTabHeld:)];
			hold.minimumPressDuration = 0.5;
			[tab addGestureRecognizer:hold];
		}
		[bar addSubview:tab];
		if (isSelected){
			UIView *line = [[UIView alloc] initWithFrame:CGRectMake(x + TGMetricPadSmall,
					kMediaTabsRow - kMediaTabLine, w - TGDoubled(TGMetricPadSmall), kMediaTabLine)];
			line.backgroundColor = [theme accentColour];
			[bar addSubview:line];
		}
		x += w;
	}
	bar.contentSize = CGSizeMake(x + TGMetricPadMedium, kMediaTabsRow);
	bar.contentOffset = CGPointMake(MIN(self.mediaTabsOffset, MAX(0, bar.contentSize.width - width)), 0);
	return bar;
}

- (void)mediaTabTapped:(UIButton *)tab {
	self.mediaTabsOffset = [(UIScrollView *)tab.superview contentOffset].x;
	NSArray *tabs = [self currentMediaTabs];
	if (tab.tag < (NSInteger)tabs.count)
		[self mediaTabSelected:tabs[(NSUInteger)tab.tag][@"kind"]];
}

- (void)mediaTabHeld:(UILongPressGestureRecognizer *)hold {
	if (hold.state != UIGestureRecognizerStateBegan)
		return;
	UIButton *tab = (UIButton *)hold.view;
	NSArray *tabs = [self currentMediaTabs];
	if (tab.tag >= (NSInteger)tabs.count)
		return;
	NSString *kind = tabs[(NSUInteger)tab.tag][@"kind"];
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:nil
						title:nil
					   action:@"Set as Main Tab"
				  destructive:NO
					   inView:self.view
					onConfirm:^{
		[[TGClient shared] setSupergroupMainProfileTab:kind inChat:weakSelf.chatId
				completion:^(BOOL ok, NSString *error){
			TGProfileViewController *me = weakSelf;
			if (!ok){
				[TGAlertSheet showMessage:(error ?: @"An error occurred.")
									title:@"Set as Main Tab" inView:me.view];
				return;
			}
			me.mainMediaKind = kind;
			[me.tableView reloadData];
		}];
	}];
}



- (void)tableView:(UITableView *)tableView willDisplayFooterView:(UIView *)view forSection:(NSInteger)section {
	if ([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
		UITableViewHeaderFooterView *footer = (UITableViewHeaderFooterView *)view;
		footer.textLabel.textColor = [[TGTheme shared] sectionHeaderColour];
	}
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	if (section == kSectionMedia){
		if (![self currentMediaTabs].count)
			return CGFLOAT_MIN;
		return kMediaTabsRow +
				(self.mediaSearchActive ? TGMetricSearchBarHeight : TGMetricZero);
	}
	if (section == kSectionPersonalChannel)
		return self.personalChannel ? TGMetricMediaStripHeader : CGFLOAT_MIN;
	// Stories and Gifts are categories in the bar now and have no rows left.
	// A grouped table still pads an empty section at both ends, and two of
	// them in a row opened a gap the size of a screen above the bar.
	if ([self tableView:tableView numberOfRowsInSection:section] == 0)
		return CGFLOAT_MIN;
	// Its title is the member count; the default height cut the text in half.
	if (section == kSectionMembers){
		if (self.members.count == 0) return CGFLOAT_MIN;
		return TGMetricMediaStripHeader;
	}
	return [super tableView:tableView heightForHeaderInSection:section];
}

/// Your own Stories or Archive tab once it has answered with nothing. A tab
/// that is still loading stays blank rather than claiming there is nothing.
- (BOOL)showsEmptyStories {
	NSString *kind = [self selectedMediaKind];
	if (!([kind isEqualToString:@"stories"] || [kind isEqualToString:@"archive"]))
		return NO;
	return [self.loadedMediaKinds containsObject:kind] && ![self selectedMediaRows].count;
}

- (BOOL)emptyStoriesHasSentence {
	return YES;
}

- (BOOL)emptyStoriesHasAction {
	return ![[self selectedMediaKind] isEqualToString:@"archive"] &&
			self.isOwnProfile;
}

- (CGFloat)emptyStoriesHeight {
	CGFloat height = TGMetricPadWide + TGMetricLineTitle + TGMetricPadSmall;
	if ([self emptyStoriesHasSentence])
		height += TGDoubled(TGMetricLineBody) + TGMetricPadSmall;
	if ([self emptyStoriesHasAction])
		height += TGMetricLineBody + TGMetricPadSmall;
	return height + TGMetricPadWide;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	if (section != kSectionMedia || ![self showsEmptyStories])
		return nil;
	TGTheme *theme = [TGTheme shared];
	CGFloat width = tableView.bounds.size.width;
	BOOL archive = [[self selectedMediaKind] isEqualToString:@"archive"];
	UIView *empty = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width,
			[self emptyStoriesHeight])];

	CGFloat y = TGMetricPadWide;
	UILabel *line = [[UILabel alloc] initWithFrame:
			CGRectMake(TGMetricPadLarge, y, width - TGDoubled(TGMetricPadLarge),
					TGMetricLineTitle)];
	line.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	line.text = archive ? @"No Archived Stories" : @"No posted stories";
	line.font = TGFontBodyStrong();
	line.textColor = [theme primaryTextColour];
	line.textAlignment = NSTextAlignmentCenter;
	line.backgroundColor = [UIColor clearColor];
	[empty addSubview:line];
	y += TGMetricLineTitle + TGMetricPadSmall;

	// The archive only fills from stories that expire, so it offers nothing;
	// the posted pane explains that a new story will appear here instead.
	if ([self emptyStoriesHasSentence]){
		UILabel *sentence = [[UILabel alloc] initWithFrame:
				CGRectMake(TGMetricPadLarge, y, width - TGDoubled(TGMetricPadLarge),
						TGDoubled(TGMetricLineBody))];
		sentence.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		sentence.numberOfLines = 2;
		sentence.text = archive
				? @"Only you can see archived stories unless you choose to post them to your profile."
				: @"Upload a new story to view it here";
		sentence.font = TGFontBody();
		sentence.textColor = [theme secondaryTextColour];
		sentence.textAlignment = NSTextAlignmentCenter;
		sentence.backgroundColor = [UIColor clearColor];
		[empty addSubview:sentence];
		y += TGDoubled(TGMetricLineBody) + TGMetricPadSmall;
	}
	if ([self emptyStoriesHasAction]){
		UIButton *add = [UIButton buttonWithType:UIButtonTypeCustom];
		add.frame = CGRectMake(0, y, width, TGMetricLineBody);
		add.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		add.titleLabel.font = TGFontBody();
		[add setTitle:@"Add Story" forState:UIControlStateNormal];
		[add setTitleColor:[theme accentColour] forState:UIControlStateNormal];
		[add addTarget:self action:@selector(addStoryTapped)
				forControlEvents:UIControlEventTouchUpInside];
		[empty addSubview:add];
	}
	return empty;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	if (section == kSectionMedia && [self showsEmptyStories])
		return [self emptyStoriesHeight];
	if ([self tableView:tableView numberOfRowsInSection:section] == 0)
		return CGFLOAT_MIN;
	if (section == kSectionMedia)
		return CGFLOAT_MIN;
	return [super tableView:tableView heightForFooterInSection:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == kSectionMedia && [self selectedTabIsGrid]) {
		CGFloat side = [[self class] storySideForWidth:tableView.bounds.size.width];
		return side + kStoryGridGap;
	}
	if (indexPath.section == kSectionMedia &&
			[[self selectedMediaKind] isEqualToString:@"music"])
		return TGMetricTrackRow;
	if (indexPath.section == kSectionDirectMessages) return TGMetricPersonRow;
	if (indexPath.section == kSectionStories) return TGMetricPersonRow;
	if (indexPath.section == kSectionMembers) return TGMetricPersonRow;
	if (indexPath.section == kSectionPersonalChannel) return TGMetricPersonRow;
	if (indexPath.section == kSectionMedia) return TGMetricPersonRow;
	if (indexPath.section == kSectionDetails && indexPath.row < (NSInteger)self.details.count){
		NSDictionary *row = self.details[indexPath.row];
		NSString *kind = row[@"kind"];
		UIImage *commImg = self.chatAvatars[@(self.communityId)];
		CGFloat iconW = ([kind isEqualToString:@"community"] && commImg)
				? commImg.size.width
				: (([kind isEqualToString:@"similarChannels"] && self.similarChannelsCompositeImage)
					? self.similarChannelsCompositeImage.size.width : TGMetricMenuGlyph);
		CGFloat left = TGMetricPadLarge + iconW + TGMetricPadMedium;
		BOOL hasAccessory = [kind isEqualToString:@"channel"] ||
				[kind isEqualToString:@"linkedChat"] || [kind isEqualToString:@"community"] ||
				[kind isEqualToString:@"similarChannels"] ||
				[kind isEqualToString:@"settings"];
		CGFloat rightMargin = hasAccessory ? (TGMetricMenuGlyph + TGMetricPadMedium) : TGMetricPadLarge;
		if ([kind isEqualToString:@"invite"] || [kind isEqualToString:@"username"]) {
			rightMargin = TGMetricPadLarge + TGMetricMenuGlyph + TGMetricPadMedium;
		}
		CGFloat textWidth = tableView.bounds.size.width - left - rightMargin - TGDoubled(TGMetricPad);
		if (textWidth < kMinDetailTextWidth) textWidth = kMinDetailTextWidth;
		NSString *val = row[@"value"] ?: @"";
		// Only our own wording in the card grows when translated; a username,
		// link, bio or birthday is the account's text and keeps its height.
		BOOL ownText = [kind isEqualToString:@"warning"] ||
				[kind isEqualToString:@"addContact"] || [kind isEqualToString:@"block"];
		NSString *measured = ownText ? TGLocalized(val) : val;
		CGFloat textH = [measured sizeWithFont:TGFontBody()
				constrainedToSize:CGSizeMake(textWidth, CGFLOAT_MAX)
					lineBreakMode:NSLineBreakByWordWrapping].height;
		if ([kind isEqualToString:@"about"] && !self.descriptionExpanded) {
			// The full description is drawn; there is no "... more" expander.
		}
		CGFloat labelH = [row[@"label"] length] ? (TGMetricLineCaption + TGMetricPadTiny) : 0;
		if ([kind isEqualToString:@"community"]) {
			labelH = TGMetricLineBody + TGMetricPadTiny;
			textH = TGMetricLineSubhead;
		}
		CGFloat totalH = TGMetricPadSmall + labelH + ceilf(textH) + TGMetricPadMedium;
		return MAX(TGMetricPersonRow, totalH);
	}
	return TGMetricRow;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == kSectionMedia && [self selectedTabIsGrid])
		return [self mediaGridCellForTableView:tableView atRow:indexPath.row];

	// The member list draws a face per row; the shared cell owns the picture
	// and the one-row reload that follows its download.
	if (indexPath.section == kSectionMembers){
		static NSString *memberReuse = @"member";
		TGMemberCell *memberCell = [tableView dequeueReusableCellWithIdentifier:memberReuse];
		if (!memberCell)
			memberCell = [[TGMemberCell alloc] initWithStyle:UITableViewCellStyleDefault
										  reuseIdentifier:memberReuse];
		[[TGTheme shared] styleCell:memberCell];
		memberCell.textLabel.font = TGFontBody();
		memberCell.textLabel.textColor = [[TGTheme shared] primaryTextColour];
		memberCell.selectionStyle = UITableViewCellSelectionStyleDefault;
		memberCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		NSDictionary *member = self.members[indexPath.row];
		int64_t userId = [member[@"id"] longLongValue];
		NSString *name = [member[@"name"] length]
				? member[@"name"] : [[TGClient shared] nameForUserId:userId];
		int64_t statusEmojiId = [[TGClient shared] emojiStatusIdForUser:userId];
		[memberCell setName:name userId:userId status:member[@"status"]
						tag:member[@"tag"] statusEmojiId:statusEmojiId inTable:tableView];
		return memberCell;
	}

	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row"];
	cell.detailTextLabel.numberOfLines = 1;
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:@"row"];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	cell.imageView.image = nil;
	[[TGTheme shared] styleCell:cell];
	cell.textLabel.font = TGFontBody();
	cell.textLabel.textColor = [[TGTheme shared] primaryTextColour];
	cell.detailTextLabel.font = TGFontCaption();
	cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];

	// The information card: what it is in small grey, the value itself under
	// it in the accent colour.
	if (indexPath.section == kSectionDetails){
		static NSString *detailReuse = @"profile-detail";
		TGProfileDetailCell *detailCell = [tableView dequeueReusableCellWithIdentifier:detailReuse];
		if (!detailCell)
			detailCell = [[TGProfileDetailCell alloc] initWithStyle:UITableViewCellStyleDefault
													reuseIdentifier:detailReuse];
		[[TGTheme shared] styleCell:detailCell];
		detailCell.selectionStyle = UITableViewCellSelectionStyleNone;

		NSDictionary *row = self.details[indexPath.row];
		NSString *kind = row[@"kind"];
		TGTheme *theme = [TGTheme shared];
		detailCell.accessoryType = ([kind isEqualToString:@"channel"] ||
				[kind isEqualToString:@"linkedChat"] || [kind isEqualToString:@"community"] ||
				[kind isEqualToString:@"similarChannels"] ||
				[kind isEqualToString:@"settings"])
				? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;

		detailCell.rowKind = kind;
		detailCell.iconWidth = 0;

		UIColor *glyphColour = [theme accentColour];
		if ([kind isEqualToString:@"bio"] || [kind isEqualToString:@"about"] ||
			[kind isEqualToString:@"note"] || [kind isEqualToString:@"warning"]) {
			glyphColour = [theme secondaryTextColour];
		} else if ([kind isEqualToString:@"birthday"] && self.birthdayToday) {
			glyphColour = [theme onlineColour];
		}

		CGFloat iconSide = TGMetricMenuGlyph;
		UIImage *icon = nil;
		if ([kind isEqualToString:@"channel"]) {
			int64_t targetChatId = [self.personalChannel[@"chatId"] longLongValue];
			detailCell.rowChatId = targetChatId;
			UIImage *cached = targetChatId ? self.chatAvatars[@(targetChatId)] : nil;
			if (cached) {
				icon = cached;
			} else {
				icon = [TGIcons glyphNamed:@"chat" colour:glyphColour side:iconSide];
				if (targetChatId) {
					[self loadAvatarForChatId:targetChatId kind:kind cell:detailCell];
				}
			}
		} else if ([kind isEqualToString:@"linkedChat"]) {
			int64_t targetChatId = self.linkedChatId;
			detailCell.rowChatId = targetChatId;
			UIImage *cached = targetChatId ? self.chatAvatars[@(targetChatId)] : nil;
			if (cached) {
				icon = cached;
			} else {
				icon = [TGIcons glyphNamed:@"chat" colour:glyphColour side:iconSide];
				if (targetChatId) {
					[self loadAvatarForChatId:targetChatId kind:kind cell:detailCell];
				}
			}
		} else if ([kind isEqualToString:@"similarChannels"]) {
			detailCell.rowChatId = self.chatId;
			if (self.similarChannelsCompositeImage) {
				icon = self.similarChannelsCompositeImage;
				detailCell.iconWidth = self.similarChannelsCompositeImage.size.width;
			} else {
				icon = [TGIcons glyphNamed:@"chat" colour:glyphColour side:iconSide];
				[self loadSimilarChannelsAvatars];
			}
		} else if ([kind isEqualToString:@"community"]) {
			detailCell.rowChatId = self.communityId;
			detailCell.titleLabel.font = TGFontBodyStrong();
			detailCell.titleLabel.textColor = [theme primaryTextColour];
			detailCell.subtitleLabel.font = TGFontSubhead();
			detailCell.subtitleLabel.textColor = [theme secondaryTextColour];
			UIImage *cached = self.chatAvatars[@(self.communityId)];
			if (cached) {
				icon = cached;
				detailCell.iconWidth = cached.size.width;
			} else {
				icon = [TGIcons glyphNamed:@"chat" colour:glyphColour side:iconSide];
				[self loadCommunityPhotoOrAvatars];
			}
		} else {
			detailCell.titleLabel.font = TGFontMeta();
			detailCell.subtitleLabel.font = TGFontBody();
			detailCell.rowChatId = 0;
			// Only the birthday keeps a leading glyph (its gift), as the
			// official card does; the rest are a label over a value.
			NSString *glyphName = ([kind isEqualToString:@"birthday"] &&
					self.birthdayToday) ? @"star" : nil;
			if (glyphName.length) {
				icon = [TGIcons glyphNamed:glyphName colour:glyphColour side:iconSide];
			}
		}
		detailCell.iconView.image = icon;

		if ([kind isEqualToString:@"invite"]) {
			detailCell.rightButton.hidden = NO;
			[detailCell.rightButton setImage:[TGIcons glyphNamed:@"qr" colour:[theme accentColour] side:TGMetricMenuGlyph] forState:UIControlStateNormal];
			__weak typeof(self) weakSelf = self;
			NSString *link = row[@"value"];
			detailCell.onRightButtonTapped = ^{
				[weakSelf showQRCodeForValue:link];
			};
		} else if ([kind isEqualToString:@"username"]) {
			// A username has a QR code, not a copy button, as the official
			// card does.
			detailCell.rightButton.hidden = NO;
			[detailCell.rightButton setImage:[TGIcons glyphNamed:@"qr" colour:[theme accentColour] side:TGMetricMenuGlyph] forState:UIControlStateNormal];
			__weak typeof(self) weakSelf = self;
			NSString *username = row[@"value"];
			detailCell.onRightButtonTapped = ^{
				[weakSelf showQRCodeForValue:username];
			};
		} else {
			detailCell.rightButton.hidden = YES;
			detailCell.onRightButtonTapped = nil;
		}

		detailCell.titleLabel.text = row[@"label"];
		if (![kind isEqualToString:@"community"]) {
			detailCell.titleLabel.textColor = [theme secondaryTextColour];
		}

		if ([kind isEqualToString:@"about"]) {
			NSString *val = row[@"value"] ?: @"";
			detailCell.subtitleLabel.attributedText = nil;
			detailCell.subtitleLabel.text = val;
			detailCell.subtitleLabel.textColor = [theme primaryTextColour];
		} else if ([kind isEqualToString:@"community"]) {
			detailCell.subtitleLabel.attributedText = nil;
			detailCell.subtitleLabel.text = row[@"value"];
			detailCell.subtitleLabel.textColor = [theme secondaryTextColour];
		} else {
			detailCell.subtitleLabel.attributedText = nil;
			detailCell.subtitleLabel.text = row[@"value"];
			BOOL plain = [kind isEqualToString:@"bio"] || [kind isEqualToString:@"note"];
			BOOL today = [kind isEqualToString:@"birthday"] && self.birthdayToday;
			detailCell.subtitleLabel.textColor = ([kind isEqualToString:@"warning"] ||
					[kind isEqualToString:@"block"]) ? [theme destructiveColour]
					: (today ? [theme onlineColour]
					: (plain ? [theme primaryTextColour] : [theme accentColour]));
		}
		[detailCell setNeedsLayout];
		return detailCell;
	}

	if (indexPath.section == kSectionPersonalChannel){
		static NSString *channelReuse = @"profile-personal-channel";
		TGProfileDetailCell *channelCell = [tableView dequeueReusableCellWithIdentifier:channelReuse];
		if (!channelCell)
			channelCell = [[TGProfileDetailCell alloc] initWithStyle:UITableViewCellStyleDefault
													reuseIdentifier:channelReuse];
		[[TGTheme shared] styleCell:channelCell];
		channelCell.selectionStyle = UITableViewCellSelectionStyleDefault;
		int64_t targetChatId = [self.personalChannel[@"chatId"] longLongValue];
		channelCell.rowChatId = targetChatId;
		channelCell.titleLabel.font = TGFontBody();
		channelCell.titleLabel.textColor = [[TGTheme shared] primaryTextColour];
		channelCell.subtitleLabel.font = TGFontCaption();
		channelCell.subtitleLabel.textColor = [[TGTheme shared] secondaryTextColour];
		channelCell.titleLabel.text = self.personalChannel[@"title"] ?: @"Channel";
		channelCell.subtitleLabel.text = nil;
		UIImage *avatar = targetChatId ? self.chatAvatars[@(targetChatId)] : nil;
		if (!avatar){
			avatar = [TGIcons glyphNamed:@"chat"
								   colour:[[TGTheme shared] accentColour]
									 side:TGMetricMenuGlyph];
			if (targetChatId)
				[self loadAvatarForChatId:targetChatId kind:@"channel" cell:channelCell];
		}
		channelCell.iconView.image = avatar;
		channelCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		[channelCell setNeedsLayout];
		return channelCell;
	}

	if (indexPath.section == kSectionDanger){
		static NSString *dangerReuse = @"profile-danger";
		UITableViewCell *danger = [tableView dequeueReusableCellWithIdentifier:dangerReuse];
		if (!danger)
			danger = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
											reuseIdentifier:dangerReuse];
		[[TGTheme shared] styleCell:danger];
		danger.textLabel.text = @"Delete Contact";
		danger.textLabel.font = TGFontBody();
		danger.textLabel.textColor = [[TGTheme shared] destructiveColour];
		danger.textLabel.textAlignment = NSTextAlignmentLeft;
		danger.accessoryType = UITableViewCellAccessoryNone;
		danger.selectionStyle = UITableViewCellSelectionStyleDefault;
		return danger;
	}

	if (indexPath.section == kSectionDirectMessages){
		static NSString *dmReuse = @"profile-dm";
		TGProfileDetailCell *dmCell = [tableView dequeueReusableCellWithIdentifier:dmReuse];
		if (!dmCell)
			dmCell = [[TGProfileDetailCell alloc] initWithStyle:UITableViewCellStyleDefault
												reuseIdentifier:dmReuse];
		[[TGTheme shared] styleCell:dmCell];
		dmCell.selectionStyle = UITableViewCellSelectionStyleNone;
		TGTheme *theme = [TGTheme shared];
		dmCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		dmCell.iconView.image = [TGIcons glyphNamed:@"chat" colour:[theme accentColour] side:TGMetricMenuGlyph];
		dmCell.titleLabel.text = @"Direct Messages";
		dmCell.titleLabel.textColor = [theme secondaryTextColour];
		dmCell.subtitleLabel.text = (self.canManageDirectMessages || self.canManage) ? @"Manage Topics" : @"Direct Messages";
		dmCell.subtitleLabel.textColor = [theme accentColour];
		[dmCell setNeedsLayout];
		return dmCell;
	}

	// A story reads as its picture, its caption and when it went up - the
	// same three things the story list in a current client shows.
	if (indexPath.section == kSectionStories){
		NSDictionary *story = self.stories[indexPath.row];
		NSString *caption = [story[@"caption"] length] ? story[@"caption"]
				: @"Story";
		cell.textLabel.text = caption;
		cell.textLabel.font = TGFontBody();
		cell.textLabel.textColor = [[TGTheme shared] primaryTextColour];

		static NSDateFormatter *when = nil;
		if (!when){
			when = [[NSDateFormatter alloc] init];
			when.dateStyle = NSDateFormatterShortStyle;
			when.timeStyle = NSDateFormatterShortStyle;
		}
		TGProfileApplyAppLocale(when);
		NSString *seen = [story[@"viewers"] integerValue] > 0
				? [NSString stringWithFormat:@" - %@ views", story[@"viewers"]] : @"";
		cell.detailTextLabel.text = [NSString stringWithFormat:@"%@%@",
				[when stringFromDate:[NSDate dateWithTimeIntervalSince1970:
						[story[@"date"] doubleValue]]], seen];
		cell.detailTextLabel.font = TGFontMeta();
		cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];

		UIImageView *thumb = [[UIImageView alloc] initWithFrame:
				CGRectMake(0, 0, kStoryThumb, kStoryThumb)];
		thumb.backgroundColor = [[TGTheme shared] fileTileColour];
		thumb.contentMode = UIViewContentModeScaleAspectFill;
		thumb.clipsToBounds = YES;
		thumb.layer.cornerRadius = TGMetricCornerMedium;
		cell.imageView.image = [TGIcons avatarWithInitials:@" " size:kStoryThumb
												  colourId:indexPath.row];
		NSNumber *fileId = story[@"thumbPhotoId"] ?: story[@"photoId"];
		if ([fileId isKindOfClass:NSNumber.class]){
			__weak UITableView *weakTable = tableView;
			[[TGClient shared] downloadFile:fileId.integerValue
								   priority:TGDownloadPriorityOnScreen
								 completion:^(NSString *path){
				if (!path.length) return;
				UIImage *image = [TGIcons decodedImage:[UIImage imageWithContentsOfFile:path]
										   fittingSize:CGSizeMake(kStoryThumb, kStoryThumb) fill:YES
												 scale:[UIScreen mainScreen].scale];
				if (!image) return;
				cell.imageView.image = image;
				[cell setNeedsLayout];
				(void)weakTable;
			}];
		}
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		return cell;
	}

	if (indexPath.section == kSectionGifts){
		NSDictionary *gift = self.gifts[indexPath.row];
		BOOL isCollectible = [gift[@"isCollectible"] boolValue];
		NSString *emoji = gift[@"emoji"] ?: @"";
		NSString *message = gift[@"note"] ?: gift[@"message"];
		if (isCollectible) {
			NSString *title = gift[@"title"] ?: @"";
			cell.textLabel.text = title.length
					? [NSString stringWithFormat:@"%@ #%ld", title, (long)[gift[@"number"] integerValue]]
					: [NSString stringWithFormat:@"#%ld", (long)[gift[@"number"] integerValue]];
			cell.detailTextLabel.text = TGProfileShortDate(gift[@"date"]) ?: @"";
		} else {
			cell.textLabel.text = (message.length && emoji.length)
					? [NSString stringWithFormat:@"%@ %@", emoji, message]
					: (emoji.length ? emoji : @"Gift");
			NSString *stars = TGLocalizedPluralValue(
					@"%@ Stars", @"%@ Stars",
					[NSString stringWithFormat:@"%ld",
							(long)[gift[@"starCount"] integerValue]],
					[gift[@"starCount"] integerValue]);
			cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@",
					TGProfileShortDate(gift[@"date"]) ?: @"", stars];
		}
		cell.textLabel.font = TGFontBody();
		cell.textLabel.textColor = [[TGTheme shared] primaryTextColour];
		cell.detailTextLabel.font = TGFontMeta();
		cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];

		cell.imageView.image = TGGiftGlyph(emoji);
		NSNumber *thumbId = isCollectible ? gift[@"modelThumbFileId"] : gift[@"thumbFileId"];
		if ([thumbId isKindOfClass:NSNumber.class]){
			__weak UITableViewCell *weakCell = cell;
			[[TGClient shared] downloadFile:thumbId.integerValue
								   priority:TGDownloadPriorityOnScreen
								 completion:^(NSString *path){
				if (!weakCell || !path.length)
					return;
				UIImage *image = [TGIcons decodedImage:
						[UIImage imageWithContentsOfFile:path]
						fittingSize:CGSizeMake(kStoryThumb, kStoryThumb) fill:YES
						scale:[UIScreen mainScreen].scale];
				if (!image)
					return;
				weakCell.imageView.image = image;
				[weakCell setNeedsLayout];
			}];
		}
		return cell;
	}

	if (indexPath.section == kSectionMedia) {
		NSString *kind = [self selectedMediaKind];
		NSArray *rows = [self selectedMediaRows];
		if (indexPath.row < (NSInteger)rows.count) {
			NSDictionary *m = rows[indexPath.row];
			if ([kind isEqualToString:@"music"]){
				static NSString *trackReuse = @"profile-track";
				TGProfileTrackCell *trackCell =
						[tableView dequeueReusableCellWithIdentifier:trackReuse];
				if (!trackCell)
					trackCell = [[TGProfileTrackCell alloc]
							initWithStyle:UITableViewCellStyleDefault
						  reuseIdentifier:trackReuse];
				[[TGTheme shared] styleCell:trackCell];
				NSString *title = [m[@"audioTitle"] length] ? m[@"audioTitle"]
						: ([m[@"docName"] length] ? m[@"docName"] : @"Audio");
				NSString *performer = [m[@"audioPerformer"] length]
						? m[@"audioPerformer"] : @"Unknown artist";
				TGMusicPlayer *player = [TGMusicPlayer shared];
				BOOL current = player.currentMessageId == [m[@"id"] longLongValue];
				[trackCell configureTitle:title
								   artist:performer
								 duration:TGProfileDurationText(m[@"duration"])
								  current:current
								  playing:player.playing];
				[self applyArtworkToTrackCell:trackCell message:m indexPath:indexPath];
				return trackCell;
			}

			cell.textLabel.numberOfLines = 1;
			cell.accessoryType = UITableViewCellAccessoryNone;
			if ([kind isEqualToString:@"files"]) {
				cell.textLabel.text = [m[@"docName"] length] ? m[@"docName"] : @"File";
				NSString *size = TGProfileFileSize(m[@"docSize"]);
				NSString *date = TGProfileShortDate(m[@"date"]);
				cell.detailTextLabel.text = size.length
						? (date.length ? [NSString stringWithFormat:@"%@ · %@", size, date] : size)
						: date;
				cell.imageView.image = [TGIcons document];
			} else if ([kind isEqualToString:@"voice"]) {
				BOOL videoNote = [m[@"kind"] isEqualToString:@"messageVideoNote"];
				cell.textLabel.text = videoNote ? @"Video message" : @"Voice message";
				// The row plays in place, so it has to show which one is sounding.
				if (self.playingVoiceId == [m[@"id"] longLongValue])
					cell.textLabel.textColor = [[TGTheme shared] accentColour];
				NSString *length = TGProfileDurationText(m[@"duration"]);
				NSString *date = TGProfileShortDate(m[@"date"]);
				cell.detailTextLabel.text = length.length
						? (date.length ? [NSString stringWithFormat:@"%@ · %@", length, date] : length)
						: date;
				cell.imageView.image = videoNote ? [TGIcons glyphNamed:@"video"
						colour:[[TGTheme shared] accentColour] side:kLinkGlyph]
						: [TGIcons microphone];
			} else if ([kind isEqualToString:@"links"]) {
				NSString *domain = [self linkDomainForMessage:m];
				NSString *date = TGProfileShortDate(m[@"date"]);
				BOOL bare = !domain.length || [m[@"text"] hasPrefix:domain] ||
						[m[@"text"] hasPrefix:@"http"];
				cell.textLabel.text = bare ? (domain.length ? domain : @"Link") : m[@"text"];
				cell.detailTextLabel.text = bare || !date.length ? (bare ? date : domain)
						: [NSString stringWithFormat:@"%@ · %@", domain, date];
				cell.imageView.image = [TGIcons glyphNamed:@"forward"
													colour:[[TGTheme shared] secondaryTextColour]
													  side:kLinkGlyph];
				cell.accessoryType = UITableViewCellAccessoryNone;
			} else if ([kind isEqualToString:@"groups"]) {
				cell.textLabel.text = [m[@"title"] length] ? m[@"title"] : @"Group";
				cell.detailTextLabel.text = nil;
				cell.imageView.image = nil;
				cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			} else if ([kind isEqualToString:@"gifts"]) {
				BOOL isCollectible = [m[@"isCollectible"] boolValue];
				NSString *emoji = m[@"emoji"] ?: @"";
				NSString *message = m[@"note"] ?: m[@"message"];
				if (isCollectible) {
					NSString *title = m[@"title"] ?: @"";
					cell.textLabel.text = title.length
							? [NSString stringWithFormat:@"%@ #%ld", title, (long)[m[@"number"] integerValue]]
							: [NSString stringWithFormat:@"#%ld", (long)[m[@"number"] integerValue]];
					cell.detailTextLabel.text = TGProfileShortDate(m[@"date"]) ?: @"";
				} else {
					cell.textLabel.text = (message.length && emoji.length)
							? [NSString stringWithFormat:@"%@ %@", emoji, message]
							: (emoji.length ? emoji : @"Gift");
					NSString *stars = TGLocalizedPluralValue(
							@"%@ Stars", @"%@ Stars",
							[NSString stringWithFormat:@"%ld",
									(long)[m[@"starCount"] integerValue]],
							[m[@"starCount"] integerValue]);
					cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@",
							TGProfileShortDate(m[@"date"]) ?: @"", stars];
				}
				cell.imageView.image = TGGiftGlyph(emoji);
				NSNumber *thumbId = isCollectible ? m[@"modelThumbFileId"] : m[@"thumbFileId"];
				if ([thumbId isKindOfClass:NSNumber.class]){
					__weak UITableViewCell *weakCell = cell;
					[[TGClient shared] downloadFile:thumbId.integerValue
										   priority:TGDownloadPriorityOnScreen
										 completion:^(NSString *path){
						if (!weakCell || !path.length)
							return;
						UIImage *image = [TGIcons decodedImage:
								[UIImage imageWithContentsOfFile:path]
								fittingSize:CGSizeMake(kStoryThumb, kStoryThumb) fill:YES
								scale:[UIScreen mainScreen].scale];
						if (!image)
							return;
						weakCell.imageView.image = image;
						[weakCell setNeedsLayout];
					}];
				}
			}
		}
	}
	return cell;
}

/// A hold on a member row is the old tap: the sheet of member actions. It
/// is the only way to reach Promote, Ban or Hand Over now that a tap opens
/// the person's profile, and it never turns into a chat on its own.
- (void)memberRowHeld:(UILongPressGestureRecognizer *)hold {
	if (hold.state != UIGestureRecognizerStateBegan)
		return;
	NSIndexPath *path = [self.tableView indexPathForRowAtPoint:
			[hold locationInView:self.tableView]];
	// One recogniser for both, since two on one table would race for the press.
	// A detail row copies whatever a tap on it would have done.
	if (path && path.section == kSectionDetails && path.row < (NSInteger)self.details.count){
		if ([self.details[path.row][@"value"] length])
			[self copyDetailValue:self.details[path.row][@"value"]];
		return;
	}
	if (!path || path.section != kSectionMembers ||
			path.row >= (NSInteger)self.members.count)
		return;
	[self showMemberActionsFor:self.members[(NSUInteger)path.row]];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	if (indexPath.section == kSectionPersonalChannel){
		[self openChat:[self.personalChannel[@"chatId"] longLongValue]
				 title:self.personalChannel[@"title"] message:0];
		return;
	}

	if (indexPath.section == kSectionMembers &&
		indexPath.row < (NSInteger)self.members.count){
		// A member row is a person, not a chat: open their profile. The
		// sheet with Send Message and the administrator actions stays on a
		// hold, which is where this screen kept it.
		[TGGroupMemberActions openProfileForMember:self.members[indexPath.row]
											  from:self];
		return;
	}

	if (indexPath.section == kSectionMedia){
		[self openMediaRow:indexPath.row];
		return;
	}

	if (indexPath.section == kSectionDirectMessages){
		[self openDirectMessages];
		return;
	}

	if (indexPath.section == kSectionDanger){
		[self runMoreAction:@"Delete Contact"];
		return;
	}

	if (indexPath.section != kSectionDetails ||
		indexPath.row >= (NSInteger)self.details.count)
		return;
	NSDictionary *row = self.details[indexPath.row];
	NSString *kind = row[@"kind"];
	// Each row does what it says. Copying everything was the only thing a tap
	// did before, so tapping a bio put the bio on the clipboard.
	if ([kind isEqualToString:@"channel"]){
		[self openChat:[self.personalChannel[@"chatId"] longLongValue]
				 title:self.personalChannel[@"title"] message:0];
	} else if ([kind isEqualToString:@"linkedChat"]){
		[self openChat:self.linkedChatId title:self.linkedChatTitle message:0];
	} else if ([kind isEqualToString:@"community"]){
		[TGChatViewController openCommunity:self.communityId
								 navigation:self.navigationController
									 inView:self.view];
	} else if ([kind isEqualToString:@"directMessages"]){
		[self openDirectMessages];
	} else if ([kind isEqualToString:@"settings"]){
		[self runMoreAction:(self.isChannel ? @"Channel Settings" : @"Group Settings")];
	} else if ([kind isEqualToString:@"similarChannels"]){
		TGSimilarChannelsViewController *similarVC = [[TGSimilarChannelsViewController alloc] init];
		similarVC.originalChatId = self.chatId;
		similarVC.channelChatIds = self.similarChatIds;
		similarVC.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:similarVC animated:YES];
	} else if ([kind isEqualToString:@"businessLocation"]){
		NSString *encoded = [row[@"value"] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		NSString *mapsUrl = [NSString stringWithFormat:@"http://maps.apple.com/?q=%@", encoded ?: @""];
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:mapsUrl]];
	} else if ([kind isEqualToString:@"addContact"]){
		[self addToContactsTapped];
	} else if ([kind isEqualToString:@"block"]){
		[self runMoreAction:(self.blocked ? @"Unblock" : @"Block")];
	} else if ([kind isEqualToString:@"addBio"]){
		[self editProfileTapped];
	} else if ([kind isEqualToString:@"bio"]){
		NSURL *url = TGProfileFirstURL(row[@"value"], self.bioEntities);
		if (url)
			[[UIApplication sharedApplication] openURL:url];
	} else if ([kind isEqualToString:@"about"]){
		if (!self.descriptionExpanded) {
			self.descriptionExpanded = YES;
			[self reloadTableDebounced];
			return;
		}
		[self copyDetailValue:row[@"value"]];
	} else if ([kind isEqualToString:@"phone"] || [kind isEqualToString:@"username"] ||
			   [kind isEqualToString:@"invite"] || [kind isEqualToString:@"birthday"]){
		[self copyDetailValue:row[@"value"]];
	}
}

- (void)openDirectMessages {
	int64_t targetId = self.directMessagesChatId;
	if (targetId == 0) {
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] chatProfile:self.chatId completion:^(NSDictionary *info){
			TGProfileViewController *me = weakSelf;
			if (!me) return;
			int64_t dmId = [info[@"directMessagesChatId"] longLongValue];
			me.hasDirectMessages = [info[@"hasDirectMessages"] boolValue];
			me.canManageDirectMessages = [info[@"canManageDirectMessages"] boolValue];
			if (dmId != 0) {
				me.directMessagesChatId = dmId;
				[me openDirectMessages];
			} else if (me.hasDirectMessages || me.canManageDirectMessages) {
				me.directMessagesChatId = me.chatId;
				[me openDirectMessages];
			} else {
				[TGAlertSheet showMessage:@"An error occurred."
									title:@"Direct Messages"
								   inView:me.view];
			}
		}];
		return;
	}

	if (self.canManage || self.canManageDirectMessages) {
		TGDMTopicsViewController *topics = [[TGDMTopicsViewController alloc] init];
		topics.chatId = targetId;
		topics.chatTitle = self.name;
		topics.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:topics animated:YES];
	} else {
		[self openChat:targetId
				 title:(self.name.length ? self.name : TGLocalized(@"Direct Messages"))
			   message:0];
	}
}

- (void)openChat:(int64_t)chatId title:(NSString *)title message:(int64_t)messageId {
	if (!chatId)
		return;
	TGChatViewController *chat = [[TGChatViewController alloc] init];
	chat.chatId = chatId;
	chat.chatTitle = title ?: @"";
	chat.initialMessageId = messageId;
	chat.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:chat animated:YES];
}

/// A row in the shared lists. Grids have their own tiles; these are the lists,
/// which used to ignore the tap altogether.
- (void)openMediaRow:(NSInteger)index {
	NSArray *rows = [self selectedMediaRows];
	if (index >= (NSInteger)rows.count)
		return;
	NSDictionary *m = rows[(NSUInteger)index];
	NSString *kind = [self selectedMediaKind];
	int64_t messageId = [m[@"id"] longLongValue];
	if ([kind isEqualToString:@"music"]){
		[[TGMusicPlayer shared] playTracks:rows atIndex:index inChat:self.chatId];
		[self.tableView reloadData];
	} else if ([kind isEqualToString:@"links"]){
		NSURL *url = TGProfileFirstURL(m[@"text"], m[@"entities"]);
		if (url)
			[[UIApplication sharedApplication] openURL:url];
	} else if ([kind isEqualToString:@"groups"]){
		[self openChat:[m[@"chatId"] longLongValue] title:m[@"title"] message:0];
	} else if ([kind isEqualToString:@"voice"] &&
			   ![m[@"kind"] isEqualToString:@"messageVideoNote"]){
		[self toggleVoiceRow:m];
	} else if ([kind isEqualToString:@"files"] || [kind isEqualToString:@"voice"]){
		// The chat already knows how to open every kind of file and play a round
		// note, so the row goes to the message rather than growing a second way.
		[self openChat:self.chatId title:self.name message:messageId];
	}
}

- (void)toggleVoiceRow:(NSDictionary *)m {
	int64_t messageId = [m[@"id"] longLongValue];
	BOOL same = self.voicePlayer && self.playingVoiceId == messageId;
	[self.voicePlayer stop];
	self.voicePlayer = nil;
	self.playingVoiceId = 0;
	[self.tableView reloadData];
	NSNumber *docId = m[@"docId"];
	if (same || ![docId isKindOfClass:NSNumber.class])
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] downloadFile:docId.integerValue completion:^(NSString *path){
		dispatch_async(dispatch_get_main_queue(), ^{
			TGProfileViewController *me = weakSelf;
			if (!me || !path)
				return;
			[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
			[[AVAudioSession sharedInstance] setActive:YES error:nil];
			NSError *err = nil;
			me.voicePlayer = [[TGStreamingVoicePlayer alloc] initWithPath:path error:&err];
			if (!me.voicePlayer){
				NSLog(@"voice playback: %@", err);
				[TGAlertSheet showMessage:@"An error occurred."
									title:@"Voice Message" inView:me.view];
				return;
			}
			me.voicePlayer.delegate = me;
			me.playingVoiceId = messageId;
			[me.voicePlayer play];
			[me.tableView reloadData];
		});
	}];
}

- (void)audioPlayerDidFinishPlaying:(id)player successfully:(BOOL)flag {
	self.voicePlayer = nil;
	self.playingVoiceId = 0;
	[self.tableView reloadData];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	[self loadVisibleMediaTabIfNeeded];
	// Back from the viewer, which can move or delete a story.
	[self reloadOwnStories];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[self.voicePlayer stop];
	self.voicePlayer = nil;
	self.playingVoiceId = 0;
}

- (void)copyDetailValue:(NSString *)value {
	[UIPasteboard generalPasteboard].string = value;

	UILabel *toast = [[UILabel alloc] initWithFrame:
			CGRectMake(0, 0, kToastWidth, kToastHeight)];
	toast.center = CGPointMake(TGHalf(self.view.bounds.size.width),
							   self.view.bounds.size.height - TGMetricToastBottomOffset);
	toast.text = @"Copied to clipboard.";
	toast.textAlignment = NSTextAlignmentCenter;
	toast.font = TGFontSubhead();
	toast.textColor = [[TGTheme shared] hudTextColour];
	toast.backgroundColor = [[TGTheme shared] hudBackgroundColour];
	toast.layer.cornerRadius = TGMetricCornerMedium;
	toast.clipsToBounds = YES;
	[self.view addSubview:toast];
	[UIView animateWithDuration:TGAnimationDurationSlow delay:1.0 options:0
					 animations:^{ toast.alpha = 0; }
					 completion:^(BOOL done){ [toast removeFromSuperview]; }];
}


@end
