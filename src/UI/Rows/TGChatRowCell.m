#import "TGChatRowCell.h"
#import "TGTextDraw.h"
#import "TGMessageLayout.h"
#import "TGLocalization.h"
#import "TGNameWithStatus.h"
#import "TGChatListRowGeometry.h"
#import "TGTheme.h"
#import "TGCustomEmojiStore.h"
#import "TGIcons.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

static const CGFloat kInset    = TGMetricPadMedium;   // picture from the left edge, text from the right
static const CGFloat kTextLeft = kInset + kAvatar + TGMetricPadMedium;
/// The row carries two lines: the name with the date and ticks beside it,
/// then the preview with the unread badge or the pin beside that.
static const CGFloat kFirstLineTop  = TGMetricPadMedium;
static const CGFloat kSecondLineTop = 32.0f;
static const CGFloat kPreviewMax    = 40.0f;
static const CGFloat kMuteGlyph     = 16.0f;
static const CGFloat kMuteRoom      = 20.0f;
/// The mute and pin marks are drawn at this side and fitted into the smaller
/// box the cell gives them, which keeps their strokes even.
static const CGFloat kRowGlyph      = 28.0f;
/// Telegram draws the status a little larger than the mute glyph beside it.
static const CGFloat kStatusGlyph   = 18.0f;
static const CGFloat kStatusRoom    = 22.0f;
static const CGFloat kPinGlyph      = 16.0f;
static const CGFloat kBadgePad      = TGMetricPadMedium + TGMetricPadTiny;
/// Three buttons fit beside a 320 pt row without clipping.
static const CGFloat kSwipeActionWidth = 76.0f;

@interface TGChatRowCell ()
@property (nonatomic, strong) UIImageView *avatar;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *previewLabel;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UILabel *badge;
@property (nonatomic, strong) UILabel *mentionBadge;
@property (nonatomic, strong) UIView *onlineDot;
@property (nonatomic, strong) UIImageView *tick;   // your own last message
@property (nonatomic, strong) UIImageView *pin;   // pinned to the top
@property (nonatomic, strong) UIImageView *statusIcon; // the emoji status after the title
@property (nonatomic, strong) UIImageView *muteIcon;   // beside the title of a muted chat
@property (nonatomic, strong) UIView *separator;   // starts under the text, not the picture

@property (nonatomic, strong) NSMutableArray *trailingActionButtons;
@property (nonatomic, assign) CGFloat trailingActionsWidth;
@property (nonatomic, strong) NSMutableArray *leadingActionButtons;
@property (nonatomic, assign) CGFloat leadingActionsWidth;
@property (nonatomic, assign) BOOL swipeActionsOpen;
@property (nonatomic, assign) CGFloat currentSwipeOffset;
/// A close animation must not strip the buttons of a row that was swiped
/// again before the first animation finished.
@property (nonatomic, assign) NSUInteger swipeActionsGeneration;

@property (nonatomic, strong) NSDictionary *row;
@property (nonatomic, assign) TGChatRowAccessories accessories;
@property (nonatomic, assign) BOOL hasAccessories;

- (void)removeSwipeActionButtons;
- (void)setPreview:(NSString *)text author:(NSString *)author;
- (void)setPreview:(NSString *)text author:(NSString *)author customEmoji:(NSArray *)customEmoji;
- (void)setDraftPreview:(NSString *)draftText;
@end

static CGSize TGChatRowCellTextSize(NSString *text, UIFont *font) {
	return TGLineTextSize(text, font);
}

/// Their titles are a medium weight, not bold; Helvetica Neue has carried one
/// since iOS 5, and bold is the fallback where it does not.
static UIFont *TGChatRowCellTitleFont(void) {
	return TGFontListTitle();
}

/// The unread count occupies the badge slot; over four digits Telegram stops
/// counting and says "9999+".
static NSString *TGChatRowCellBadgeText(NSDictionary *row) {
	NSInteger unread = [row[TGRowChatUnread] integerValue];
	if (unread <= 0)
		return @"";
	return unread > 9999 ? @"9999+" : [NSString stringWithFormat:@"%ld",
			(long)unread];
}

static TGChatRowAccessories TGChatRowCellAccessories(NSDictionary *row,
		CGFloat width) {
	TGChatRowAccessories a = {0};
	CGFloat w = width > 0 ? width : TGMetricScreenWidth;
	a.width = w;
	CGFloat right = w - kInset;
	NSInteger unread = [row[TGRowChatUnread] integerValue];
	BOOL marked = [row[TGRowChatMarkedUnread] boolValue];
	BOOL hasBadge = unread > 0 || marked;
	BOOL hasPin = !hasBadge && [row[TGRowChatPinned] boolValue];
	CGFloat badgeW = 0;
	if (hasBadge){
		CGSize size = TGChatRowCellTextSize(TGChatRowCellBadgeText(row),
				TGFontCaptionStrong());
		badgeW = MAX(TGMetricChatBadgeHeight, ceilf(size.width) + kBadgePad);
	}
	a.hasBadge = hasBadge;
	a.hasPin = hasPin;
	a.badgeWidth = badgeW;

	CGFloat previewRight = right;
	TGChatListRowAccessories(right, TGMetricChatBadgeTop, hasBadge, badgeW,
			TGMetricChatBadgeHeight, hasPin, kPinGlyph, TGMetricPad,
			&a.badgeFrame, &a.pinFrame, &previewRight);

	a.hasMentions = [row[TGRowChatMentions] integerValue] > 0;
	if (a.hasMentions){
		CGFloat side = TGMetricChatBadgeHeight;
		CGFloat x = previewRight - side;
		a.mentionFrame = CGRectMake(x, TGMetricChatBadgeTop, side, side);
		previewRight = x - TGMetricPadSmall;
	}
	a.previewRight = previewRight;
	return a;
}

@implementation TGChatRowCell

+ (CGFloat)statusSide {
	return kStatusGlyph;
}

+ (CGFloat)heightForRow:(NSDictionary *)row {
	(void)row;
	return kRowHeight;
}

+ (instancetype)cellForTableView:(UITableView *)tableView
							 row:(NSDictionary *)row {
	static NSString *reuse = @"TGChatRowCell";
	TGChatRowCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[TGChatRowCell alloc] initWithStyle:UITableViewCellStyleDefault
									 reuseIdentifier:reuse];
	[cell configureWithRow:row];
	return cell;
}

+ (NSValue *)accessoriesValueForRow:(NSDictionary *)row width:(CGFloat)width {
	TGChatRowAccessories accessories = TGChatRowCellAccessories(row, width);
	return [NSValue valueWithBytes:&accessories
						  objCType:@encode(TGChatRowAccessories)];
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	TGTheme *theme = [TGTheme shared];

	self.backgroundColor = [theme listBackgroundColour];
	self.contentView.backgroundColor = [theme listBackgroundColour];

	self.avatar = [[UIImageView alloc] initWithFrame:CGRectMake(kInset, TGCenteredOrigin(kRowHeight, kAvatar), kAvatar, kAvatar)];
	// Pre-baked circle bitmap: no cornerRadius or shouldRasterize layer on scrolling rows.
	self.avatar.contentMode = UIViewContentModeScaleAspectFill;
	self.avatar.opaque = NO;
	self.avatar.backgroundColor = [UIColor clearColor];
	[self.contentView addSubview:self.avatar];

	self.titleLabel = [[UILabel alloc] init];
	self.titleLabel.font = TGChatRowCellTitleFont();
	self.titleLabel.textColor = [theme primaryTextColour];
	self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
	[self.contentView addSubview:self.titleLabel];

	self.previewLabel = [[UILabel alloc] init];
	self.previewLabel.font = TGFontBody();
	self.previewLabel.textColor = [theme secondaryTextColour];
	self.previewLabel.numberOfLines = 2;
	self.previewLabel.lineBreakMode = NSLineBreakByTruncatingTail;
	[self.contentView addSubview:self.previewLabel];

	self.dateLabel = [[UILabel alloc] init];
	self.dateLabel.font = TGFontSubhead();
	self.dateLabel.textColor = [theme listDateColour];
	self.dateLabel.textAlignment = NSTextAlignmentRight;
	[self.contentView addSubview:self.dateLabel];

	self.badge = [[UILabel alloc] init];
	self.badge.font = TGFontCaptionStrong();
	self.badge.textColor = [[TGTheme shared] onAccentColour];
	self.badge.backgroundColor = [theme badgeColour];
	self.badge.textAlignment = NSTextAlignmentCenter;
	self.badge.layer.cornerRadius = TGHalf(TGMetricChatBadgeHeight);
	self.badge.clipsToBounds = YES;

	self.badge.hidden = YES;
	[self.contentView addSubview:self.badge];

	self.mentionBadge = [[UILabel alloc] init];
	self.mentionBadge.text = @"@";
	self.mentionBadge.font = TGFontCaptionStrong();
	self.mentionBadge.textColor = [[TGTheme shared] onAccentColour];
	self.mentionBadge.backgroundColor = [theme accentColour];
	self.mentionBadge.textAlignment = NSTextAlignmentCenter;
	self.mentionBadge.layer.cornerRadius = TGHalf(TGMetricChatBadgeHeight);
	self.mentionBadge.clipsToBounds = YES;
	self.mentionBadge.hidden = YES;
	[self.contentView addSubview:self.mentionBadge];

	CGFloat dot = 15;
	self.onlineDot = [[UIView alloc] initWithFrame:
			CGRectMake(kInset + kAvatar - dot, TGCenteredOrigin(kRowHeight, kAvatar) + kAvatar - dot, dot, dot)];
	self.onlineDot.backgroundColor = [theme onlineColour];
	self.onlineDot.layer.cornerRadius = TGHalf(dot);
	self.onlineDot.layer.borderWidth = TGMetricBorderThick;
	self.onlineDot.layer.borderColor = [theme listBackgroundColour].CGColor;
	self.onlineDot.hidden = YES;
	[self.contentView addSubview:self.onlineDot];

	self.tick = [[UIImageView alloc] init];
	self.tick.hidden = YES;
	[self.contentView addSubview:self.tick];

	self.pin = [[UIImageView alloc] init];
	self.pin.contentMode = UIViewContentModeScaleAspectFit;
	self.pin.hidden = YES;
	[self.contentView addSubview:self.pin];

	self.statusIcon = [[UIImageView alloc] init];
	self.statusIcon.contentMode = UIViewContentModeScaleAspectFit;
	self.statusIcon.hidden = YES;
	[self.contentView addSubview:self.statusIcon];

	self.muteIcon = [[UIImageView alloc] init];
	self.muteIcon.contentMode = UIViewContentModeScaleAspectFit;
	self.muteIcon.hidden = YES;
	[self.contentView addSubview:self.muteIcon];

	// The table's own separator runs under the picture and cannot be inset
	// before iOS 7, so the row draws its own.
	self.separator = [[UIView alloc] init];
	self.separator.backgroundColor = [theme separatorColour];
	[self.contentView addSubview:self.separator];

	// No disclosure arrow: a chat row is not a settings row.
	self.accessoryType = UITableViewCellAccessoryNone;
	return self;
}

#pragma mark - row

- (void)configureWithRow:(NSDictionary *)row {
	self.row = row;
	TGTheme *theme = [TGTheme shared];
	UIColor *bg = [theme listBackgroundColour];

	self.backgroundColor = bg;
	self.contentView.backgroundColor = bg;
	self.titleLabel.backgroundColor = bg;
	self.titleLabel.opaque = YES;
	self.titleLabel.textColor = [theme primaryTextColour];
	self.previewLabel.backgroundColor = bg;
	self.previewLabel.opaque = YES;
	self.previewLabel.textColor = [theme secondaryTextColour];
	self.dateLabel.backgroundColor = bg;
	self.dateLabel.opaque = YES;
	self.dateLabel.textColor = [theme listDateColour];
	self.dateLabel.text = @"";
	self.onlineDot.layer.borderColor = bg.CGColor;
	self.separator.backgroundColor = [theme separatorColour];
	if ([theme isDark]) {
		UIView *selection = [[UIView alloc] init];
		selection.backgroundColor = [theme inputBarColour];
		self.selectedBackgroundView = selection;
	} else {
		self.selectedBackgroundView = nil;
	}

	self.onlineDot.hidden = YES;
	self.tick.hidden = YES;
	self.tick.image = nil;
	self.muteIcon.hidden = YES;
	self.muteIcon.image = nil;
	self.pin.hidden = YES;
	self.pin.image = nil;
	self.statusIcon.hidden = YES;
	self.statusIcon.image = nil;
	self.mentionBadge.hidden = YES;
	self.badge.hidden = YES;
	self.badge.text = @"";
	self.badge.backgroundColor = [theme badgeColour];
	self.avatar.image = nil;
	self.avatar.opaque = NO;
	self.avatar.backgroundColor = [UIColor clearColor];

	NSString *title = row[TGRowTitle];
	if (![title isKindOfClass:NSString.class])
		title = @"";
	BOOL saved = [row[TGRowChatSaved] boolValue];
	int64_t statusId = saved ? 0
			: [row[TGRowChatStatusEmojiId] longLongValue];
	self.titleLabel.attributedText = TGNameWithStatus(title, statusId,
			self.titleLabel.font, [theme primaryTextColour]);

	NSString *date = row[TGRowChatDate];
	self.dateLabel.text = [date isKindOfClass:NSString.class] ? date : @"";

	NSString *action = row[TGRowChatAction];
	NSString *draft = row[TGRowChatDraft];
	if ([action isKindOfClass:NSString.class] && action.length){
		self.previewLabel.text = action;
		self.previewLabel.textColor = [theme typingColour];
	} else if ([draft isKindOfClass:NSString.class] && draft.length){
		[self setDraftPreview:draft];
	} else {
		[self setPreview:row[TGRowChatPreview]
				  author:row[TGRowChatAuthor]
			 customEmoji:row[TGRowChatCustomEmoji]];
	}

	self.onlineDot.hidden = ![row[TGRowChatOnline] boolValue];

	// Your own last message shows whether it has been read, beside the date.
	// Saved Messages has no one to read it.
	if (!saved && [row[TGRowChatOutgoing] boolValue] && ![action length]){
		BOOL read = [row[TGRowChatRead] boolValue];
		self.tick.image = [TGIcons ticksColour:[theme ticksColour] read:read];
		self.tick.hidden = NO;
	}

	BOOL muted = [row[TGRowChatMuted] boolValue];
	self.muteIcon.hidden = !muted;
	if (muted)
		self.muteIcon.image = [TGIcons glyphNamed:@"mute"
										   colour:[theme listDateColour]
											 side:kRowGlyph];

	NSInteger unread = [row[TGRowChatUnread] integerValue];
	NSInteger mentions = [row[TGRowChatMentions] integerValue];
	self.mentionBadge.hidden = (mentions <= 0);

	BOOL marked = [row[TGRowChatMarkedUnread] boolValue];
	BOOL anyBadge = unread > 0 || marked;
	self.badge.hidden = !anyBadge;
	// The unread count occupies the badge slot; the pin only shows when that
	// slot is free.
	self.pin.hidden = anyBadge || ![row[TGRowChatPinned] boolValue];
	if (!self.pin.hidden)
		self.pin.image = [TGIcons glyphNamed:@"pin"
									  colour:[theme listDateColour]
										side:kRowGlyph];
	self.badge.text = TGChatRowCellBadgeText(row);
	// A muted chat still counts, it just stops shouting about it.
	self.badge.backgroundColor = muted
			? [theme mutedBadgeColour] : [theme badgeColour];

	NSString *glyph = row[TGRowChatAvatarGlyph];
	UIImage *photo = row[TGRowChatAvatarImage];
	if ([glyph isEqualToString:TGChatAvatarGlyphArchive])
		photo = [TGIcons archiveAvatarOfSide:kAvatar];
	else if ([glyph isEqualToString:TGChatAvatarGlyphSaved])
		photo = [TGIcons savedMessagesAvatarOfSide:kAvatar];
	if (![photo isKindOfClass:UIImage.class]){
		NSString *initials = [TGIcons initialsForTitle:title];
		photo = [TGIcons avatarWithInitials:initials
									   size:kAvatar
								   colourId:[row[TGRowChatAvatarId] longLongValue]];
	}
	self.avatar.image = photo;

	NSValue *boxed = row[TGRowChatLayout];
	if ([boxed isKindOfClass:NSValue.class]){
		[boxed getValue:&_accessories];
	} else {
		_accessories = TGChatRowCellAccessories(row, 0);
	}
	self.hasAccessories = YES;
	[self setNeedsLayout];
}

- (void)setPreview:(NSString *)text author:(NSString *)author {
	[self setPreview:text author:author customEmoji:nil];
}

- (void)setPreview:(NSString *)text author:(NSString *)author customEmoji:(NSArray *)customEmoji {
	TGTheme *theme = [TGTheme shared];
	text = text ?: @"";

	Class attachmentClass = NSClassFromString(@"NSTextAttachment");
	BOOL canUseAttachments = (attachmentClass != nil && [NSAttributedString respondsToSelector:@selector(attributedStringWithAttachment:)]);

	if (![self.previewLabel respondsToSelector:@selector(setAttributedText:)]) {
		self.previewLabel.text = author.length ? [NSString stringWithFormat:@"%@: %@", author, text] : text;
		return;
	}

	BOOL undrawable = TGTextHasUndrawableEmoji(text);
	// UILabel takes the first run's font as its own once attributed text is
	// set; a reused row would otherwise draw plain text, or build the next
	// attributed line, in the OpenMoji face of the row before.
	self.previewLabel.font = TGFontBody();
	if (!author.length && !undrawable && (!canUseAttachments || customEmoji.count == 0)) {
		self.previewLabel.text = text;
		self.previewLabel.textColor = [theme secondaryTextColour];
		return;
	}

	NSString *prefix = author.length ? [author stringByAppendingString:@": "] : @"";
	NSUInteger authorOffset = prefix.length;
	NSString *fullText = authorOffset > 0 ? [prefix stringByAppendingString:text] : text;

	NSMutableAttributedString *line = [[NSMutableAttributedString alloc]
			initWithString:fullText
				attributes:@{NSFontAttributeName: TGFontBody(),
							 NSForegroundColorAttributeName: [theme secondaryTextColour]}];

	if (authorOffset > 0) {
		[line addAttribute:NSForegroundColorAttributeName
					 value:[theme primaryTextColour]
					 range:NSMakeRange(0, authorOffset)];
	}

	if (canUseAttachments && customEmoji.count > 0) {
		NSMutableArray *entries = [NSMutableArray array];
		for (id item in customEmoji) {
			NSInteger off = 0;
			NSInteger len = 0;
			int64_t eid = 0;
			if ([item isKindOfClass:[NSDictionary class]]) {
				NSDictionary *dict = (NSDictionary *)item;
				off = [dict[@"offset"] integerValue];
				len = [dict[@"length"] integerValue];
				eid = [dict[@"customEmojiId"] longLongValue];
			} else if ([item isKindOfClass:[NSArray class]]) {
				NSArray *arr = (NSArray *)item;
				if (arr.count >= 3) {
					off = [arr[0] integerValue];
					len = [arr[1] integerValue];
					eid = [arr[2] longLongValue];
				}
			}
			if (len > 0 && eid > 0) {
				[entries addObject:@{
					@"offset" : @(off),
					@"length" : @(len),
					@"id"     : @(eid)
				}];
			}
		}

		// Sort from highest offset backwards so replacing earlier glyphs is not affected.
		[entries sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
			return [b[@"offset"] compare:a[@"offset"]];
		}];

		UIFont *font = TGFontBody();
		CGFloat side = font.pointSize;

		for (NSDictionary *entry in entries) {
			NSUInteger off = [entry[@"offset"] unsignedIntegerValue] + authorOffset;
			NSUInteger len = [entry[@"length"] unsignedIntegerValue];
			int64_t eid = [entry[@"id"] longLongValue];

			if (off + len > line.length) {
				continue;
			}

			UIImage *picture = [[TGCustomEmojiStore shared] imageForId:eid side:side];
			if (!picture) {
				// Picture still loading; keep fallback text.
				continue;
			}

			id attachment = [[attachmentClass alloc] init];
			[attachment setImage:picture];
			[attachment setBounds:CGRectMake(0, roundf(font.descender), side, side)];

			NSAttributedString *glyph = [NSAttributedString attributedStringWithAttachment:attachment];
			if (glyph) {
				[line replaceCharactersInRange:NSMakeRange(off, len) withAttributedString:glyph];
			}
		}
	}

	// After the custom emoji: their offsets from TDLib count the U+FE0F, and
	// dropping it first moved every picture after it onto the wrong character.
	if (undrawable)
		TGMarkUndrawableEmoji(line, TGFontBody().pointSize);
	self.previewLabel.attributedText = line;
}

- (void)setDraftPreview:(NSString *)draftText {
	TGTheme *theme = [TGTheme shared];
	draftText = draftText ?: @"";
	NSString *prefix = [TGLocalized(@"Draft") stringByAppendingString:@": "];
	if (![self.previewLabel respondsToSelector:@selector(setAttributedText:)]) {
		self.previewLabel.text = [prefix stringByAppendingString:draftText];
		self.previewLabel.textColor = [theme destructiveColour];
		return;
	}
	NSMutableAttributedString *line = [[NSMutableAttributedString alloc]
			initWithString:[prefix stringByAppendingString:draftText]
				attributes:@{NSFontAttributeName: TGFontBody(),
							 NSForegroundColorAttributeName: [theme secondaryTextColour]}];
	[line addAttribute:NSForegroundColorAttributeName
				 value:[theme destructiveColour]
				 range:NSMakeRange(0, prefix.length)];
	self.previewLabel.attributedText = line;
}

- (void)layoutSubviews {
	// UIKit sets the content view's frame in here, and a frame set under a
	// transform lands somewhere else: the swiped row ended up 228 pt to the right
	// of where it was slid to, covering the buttons it had just uncovered.
	CGAffineTransform slid = self.contentView.transform;
	BOOL isSlid = !CGAffineTransformIsIdentity(slid);
	if (isSlid)
		self.contentView.transform = CGAffineTransformIdentity;
	[super layoutSubviews];
	CGFloat w = self.contentView.bounds.size.width;
	CGFloat h = self.contentView.bounds.size.height;
	CGFloat right = w - kInset;

	// The first line: the date pinned to the right edge, the ticks before it,
	// and the title taking whatever is left.
	CGSize date = TGChatRowCellTextSize(self.dateLabel.text, self.dateLabel.font);
	self.dateLabel.frame = CGRectMake(right - ceilf(date.width), kFirstLineTop + TGMetricBorderWidth,
			ceilf(date.width), TGMetricLineBody);
	CGFloat titleRight = CGRectGetMinX(self.dateLabel.frame) - TGMetricChatCellDateGap;
	if (!self.tick.hidden) {
		self.tick.frame = CGRectMake(titleRight - TGMetricTicksWidth,
				kFirstLineTop + TGMetricPadSmall, TGMetricTicksWidth,
				TGMetricTicksHeight);
		titleRight -= (TGMetricTicksWidth + TGMetricPadSmall);
	}

	// Title, then the status, then the mute glyph: the title gives way to both.
	CGFloat muteW = self.muteIcon.hidden ? 0 : kMuteRoom;
	CGFloat statusW = self.statusIcon.hidden ? 0 : kStatusRoom;
	CGFloat titleRoom = MAX(0, titleRight - kTextLeft - muteW - statusW);
	CGFloat textW = 0;
	if (self.titleLabel.attributedText.length > 0 && [self.titleLabel.attributedText respondsToSelector:@selector(boundingRectWithSize:options:context:)]) {
		CGRect r = [self.titleLabel.attributedText boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, TGMetricLineRow)
															   options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
															   context:nil];
		textW = ceilf(r.size.width);
	} else {
		textW = ceilf(TGChatRowCellTextSize(self.titleLabel.text, self.titleLabel.font).width);
	}
	CGFloat titleW = MIN(textW, titleRoom);
	self.titleLabel.frame = CGRectMake(kTextLeft, kFirstLineTop, titleW, TGMetricLineRow);
	CGFloat afterTitle = kTextLeft + titleW + TGMetricBubbleRowInset;
	if (!self.statusIcon.hidden){
		self.statusIcon.frame = CGRectMake(afterTitle,
				kFirstLineTop + TGCenteredOrigin(TGMetricLineRow, kStatusGlyph), kStatusGlyph, kStatusGlyph);
		afterTitle += statusW;
	}
	if (!self.muteIcon.hidden)
		self.muteIcon.frame = CGRectMake(afterTitle,
				kFirstLineTop + TGMetricPadTiny, kMuteGlyph, kMuteGlyph);

	// The second line: the unread count at the right edge, the pin beside it,
	// and the preview wrapping onto a second line up to whichever is leftmost.
	// The two are not alternatives - a pinned chat with unread messages keeps
	// both, which is what the official row shows.
	TGChatRowAccessories accessories = self.accessories;
	if (!self.hasAccessories || fabs(accessories.width - w) > 0.5f)
		accessories = TGChatRowCellAccessories(self.row, w);
	self.badge.frame = accessories.badgeFrame;
	self.pin.frame = accessories.pinFrame;
	if (!self.mentionBadge.hidden)
		self.mentionBadge.frame = accessories.mentionFrame;
	CGFloat previewRight = accessories.previewRight;

	CGFloat previewW = MAX(0, previewRight - kTextLeft);
	CGSize fit = [self.previewLabel sizeThatFits:CGSizeMake(previewW, kPreviewMax)];
	self.previewLabel.frame = CGRectMake(kTextLeft, kSecondLineTop, previewW,
			MIN(ceilf(fit.height), kPreviewMax - TGMetricPadTiny));

	CGFloat hair = TGMetricHairline;
	self.separator.frame = CGRectMake(kTextLeft, h - hair, w - kTextLeft, hair);

	// Layout trailing buttons along the right edge
	if (self.trailingActionButtons.count){
		CGFloat x = self.bounds.size.width - self.trailingActionsWidth;
		for (UIButton *button in self.trailingActionButtons){
			button.frame = CGRectMake(x, 0, kSwipeActionWidth, self.bounds.size.height);
			x += kSwipeActionWidth;
		}
	}
	// Layout leading buttons along the left edge
	if (self.leadingActionButtons.count){
		CGFloat x = 0;
		for (UIButton *button in self.leadingActionButtons){
			button.frame = CGRectMake(x, 0, kSwipeActionWidth, self.bounds.size.height);
			x += kSwipeActionWidth;
		}
	}
	if (isSlid)
		self.contentView.transform = slid;
}

- (void)applyTheme {
	TGTheme *theme = [TGTheme shared];
	self.backgroundColor = [theme listBackgroundColour];
	self.contentView.backgroundColor = [theme listBackgroundColour];
	self.titleLabel.textColor = [theme primaryTextColour];
	self.previewLabel.textColor = [theme secondaryTextColour];
	self.dateLabel.textColor = [theme listDateColour];
	self.badge.backgroundColor = [theme badgeColour];
	self.mentionBadge.backgroundColor = [theme accentColour];
	self.onlineDot.backgroundColor = [theme onlineColour];
	self.onlineDot.layer.borderColor = [theme listBackgroundColour].CGColor;
	self.separator.backgroundColor = [theme separatorColour];
}

- (CGFloat)swipeActionsWidth {
	return self.trailingActionsWidth + self.leadingActionsWidth;
}

- (void)revealSwipeActionsWithTrailingTitles:(NSArray *)trailingTitles
                             trailingColours:(NSArray *)trailingColours
                               leadingTitles:(NSArray *)leadingTitles
                              leadingColours:(NSArray *)leadingColours
                                      target:(id)target
                                      action:(SEL)action {
	self.swipeActionsGeneration++;
	[self removeSwipeActionButtons];

	// Trailing buttons (shown when dragging left, offset < 0)
	if (trailingTitles.count){
		self.trailingActionButtons = [NSMutableArray arrayWithCapacity:trailingTitles.count];
		for (NSUInteger i = 0; i < trailingTitles.count; i++){
			UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
			button.titleLabel.font = TGFontCaptionStrong();
			[button setTitleColor:[[TGTheme shared] onAccentColour]
						 forState:UIControlStateNormal];
			[button addTarget:target action:action
			 forControlEvents:UIControlEventTouchUpInside];
			[button setTitle:i < trailingTitles.count ? trailingTitles[i] : @""
					forState:UIControlStateNormal];
			if (i < trailingColours.count)
				button.backgroundColor = trailingColours[i];
			[self.contentView.superview insertSubview:button belowSubview:self.contentView];
			[self.trailingActionButtons addObject:button];
		}
		self.trailingActionsWidth = (CGFloat)trailingTitles.count * kSwipeActionWidth;
	}

	// Leading buttons (shown when dragging right, offset > 0)
	if (leadingTitles.count){
		self.leadingActionButtons = [NSMutableArray arrayWithCapacity:leadingTitles.count];
		for (NSUInteger i = 0; i < leadingTitles.count; i++){
			UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
			button.titleLabel.font = TGFontCaptionStrong();
			[button setTitleColor:[[TGTheme shared] onAccentColour]
						 forState:UIControlStateNormal];
			[button addTarget:target action:action
			 forControlEvents:UIControlEventTouchUpInside];
			[button setTitle:i < leadingTitles.count ? leadingTitles[i] : @""
					forState:UIControlStateNormal];
			if (i < leadingColours.count)
				button.backgroundColor = leadingColours[i];
			[self.contentView.superview insertSubview:button belowSubview:self.contentView];
			[self.leadingActionButtons addObject:button];
		}
		self.leadingActionsWidth = (CGFloat)leadingTitles.count * kSwipeActionWidth;
	}

	self.clipsToBounds = YES;
	self.swipeActionsOpen = NO;
	self.currentSwipeOffset = 0;
	self.contentView.transform = CGAffineTransformIdentity;
	[self setNeedsLayout];
}

- (void)revealSwipeActionsWithTitles:(NSArray *)titles
                             colours:(NSArray *)colours
                              target:(id)target
                              action:(SEL)action {
	[self revealSwipeActionsWithTrailingTitles:titles
	                           trailingColours:colours
	                             leadingTitles:nil
	                            leadingColours:nil
	                                    target:target
	                                    action:action];
}

- (void)setSwipeActionsOffset:(CGFloat)offset {
	if (offset < 0){
		// Dragging left: show trailing, hide leading
		for (UIButton *b in self.leadingActionButtons) b.hidden = YES;
		for (UIButton *b in self.trailingActionButtons) b.hidden = NO;
		CGFloat maxOffset = self.trailingActionsWidth;
		if (maxOffset > 0 && offset < -maxOffset)
			offset = -maxOffset;
	} else if (offset > 0){
		// Dragging right: show leading, hide trailing
		for (UIButton *b in self.leadingActionButtons) b.hidden = NO;
		for (UIButton *b in self.trailingActionButtons) b.hidden = YES;
		CGFloat maxOffset = self.leadingActionsWidth;
		if (maxOffset > 0 && offset > maxOffset)
			offset = maxOffset;
	}
	self.currentSwipeOffset = offset;
	self.contentView.transform = CGAffineTransformMakeTranslation(offset, 0);
}

- (void)openTrailingSwipeActionsAnimated:(BOOL)animated {
	CGFloat width = self.trailingActionsWidth;
	if (width <= 0)
		return;
	for (UIButton *b in self.leadingActionButtons) b.hidden = YES;
	for (UIButton *b in self.trailingActionButtons) b.hidden = NO;
	self.swipeActionsOpen = YES;
	self.currentSwipeOffset = -width;
	if (!animated){
		self.contentView.transform = CGAffineTransformMakeTranslation(-width, 0);
		return;
	}
	[UIView animateWithDuration:TGAnimationDurationFast animations:^{
		self.contentView.transform = CGAffineTransformMakeTranslation(-width, 0);
	}];
}

- (void)openLeadingSwipeActionsAnimated:(BOOL)animated {
	CGFloat width = self.leadingActionsWidth;
	if (width <= 0)
		return;
	for (UIButton *b in self.leadingActionButtons) b.hidden = NO;
	for (UIButton *b in self.trailingActionButtons) b.hidden = YES;
	self.swipeActionsOpen = YES;
	self.currentSwipeOffset = width;
	if (!animated){
		self.contentView.transform = CGAffineTransformMakeTranslation(width, 0);
		return;
	}
	[UIView animateWithDuration:TGAnimationDurationFast animations:^{
		self.contentView.transform = CGAffineTransformMakeTranslation(width, 0);
	}];
}

- (void)openSwipeActionsAnimated:(BOOL)animated {
	[self openTrailingSwipeActionsAnimated:animated];
}

- (void)closeSwipeActionsAnimated:(BOOL)animated {
	self.swipeActionsOpen = NO;
	self.currentSwipeOffset = 0;
	NSUInteger generation = ++self.swipeActionsGeneration;
	void (^finish)(void) = ^{
		if (self.swipeActionsGeneration != generation)
			return;
		[self removeSwipeActionButtons];
	};
	if (!animated || (!self.trailingActionButtons.count && !self.leadingActionButtons.count)){
		self.contentView.transform = CGAffineTransformIdentity;
		finish();
		return;
	}
	[UIView animateWithDuration:TGAnimationDurationFast animations:^{
		self.contentView.transform = CGAffineTransformIdentity;
	} completion:^(BOOL finished){
		finish();
	}];
}

- (void)removeSwipeActionButtons {
	for (UIButton *button in self.trailingActionButtons)
		[button removeFromSuperview];
	self.trailingActionButtons = nil;
	self.trailingActionsWidth = 0;

	for (UIButton *button in self.leadingActionButtons)
		[button removeFromSuperview];
	self.leadingActionButtons = nil;
	self.leadingActionsWidth = 0;
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
	[super setEditing:editing animated:animated];
	if (editing)
		[self closeSwipeActionsAnimated:NO];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
	[super setSelected:selected animated:animated];
	if (selected)
		[self closeSwipeActionsAnimated:NO];
}

- (void)prepareForReuse {
	[super prepareForReuse];
	[self closeSwipeActionsAnimated:NO];
	self.row = nil;
	self.hasAccessories = NO;
	self.dateLabel.hidden = NO;
}

@end
