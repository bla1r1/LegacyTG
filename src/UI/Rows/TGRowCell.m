//
// TGRowCell.m
//
#import "TGRowCell.h"
#import "TGRows.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGIcons.h"
#import "TGLocalization.h"

@interface TGRowCell ()
@property (nonatomic, strong) NSDictionary *row;
@property (nonatomic, assign) NSInteger rowIndex;
@property (nonatomic, assign) NSInteger totalRows;
@property (nonatomic, copy) void (^switchToggleBlock)(BOOL on);
@property (nonatomic, copy) void (^accessoryTapBlock)(void);
@property (nonatomic, strong) UISwitch *toggleSwitch;
@end

@implementation TGRowCell

+ (BOOL)isSubtitleRow:(NSDictionary *)row {
	NSString *kind = row[TGRowKind] ?: TGKindPlain;
	return [row[TGRowSubtitle] boolValue] ||
			[kind isEqualToString:TGKindToggleInfo];
}

+ (NSString *)reuseIdentifierForRow:(NSDictionary *)row {
	NSString *kind = row[TGRowKind] ?: TGKindPlain;
	if ([kind isEqualToString:TGKindToggleInfo])
		return @"TGRowCellToggleInfo";
	if ([row[TGRowSubtitle] boolValue])
		return @"TGRowCellSubtitle";
	if ([kind isEqualToString:TGKindPlain])
		return @"TGRowCellPlain";
	return [@"TGRowCell-" stringByAppendingString:kind];
}

+ (CGFloat)heightForRow:(NSDictionary *)row inTableView:(UITableView *)tableView {
	NSString *kind = row[TGRowKind];
	if ([kind isEqualToString:TGKindPeerRow]){
		NSNumber *height = row[TGRowHeight];
		return height ? [height doubleValue] : TGMetricPersonRow;
	}
	NSNumber *height = row[TGRowHeight];
	if (height)
		return [height doubleValue];
	if ([kind isEqualToString:TGKindToggleInfo]){
		// The detail is the row's second line and wraps in Russian, so both
		// labels are measured: the switch and the icon take their own width
		// out of the text column, which the old fixed 30 + detail formula did
		// not account for.
		CGFloat width = MAX(TGMetricRow, tableView.bounds.size.width -
				TGMetricGutter - TGMetricRow - TGMetricSwitchW -
				TGMetricPadMedium);
		CGSize title = [TGLocalized(row[TGRowTitle] ?: @"")
				sizeWithFont:TGFontRow()
				constrainedToSize:CGSizeMake(width, TGMetricImageMax)
				lineBreakMode:NSLineBreakByWordWrapping];
		CGSize detail = [TGLocalized(row[TGRowDetail] ?: @"")
				sizeWithFont:TGFontCaption()
				constrainedToSize:CGSizeMake(width, TGMetricImageMax)
				lineBreakMode:NSLineBreakByWordWrapping];
		return TGRowsToggleInfoHeight(title.height, detail.height);
	}
	if (row[TGRowTitleLines]){
		CGFloat width = tableView.bounds.size.width - TGMetricPadLarge -
				TGMetricViewerBottomBar;
		if (width <= 0)
			width = TGMetricScreenWidth - TGMetricPadLarge -
					TGMetricViewerBottomBar;
		CGSize title = [TGLocalized(row[TGRowTitle] ?: @"")
				sizeWithFont:TGFontBody()
				constrainedToSize:CGSizeMake(width, CGFLOAT_MAX)
				lineBreakMode:NSLineBreakByWordWrapping];
		CGFloat total = ceilf(title.height) + TGDoubled(TGMetricPadMedium);
		NSString *detail = row[TGRowDetail];
		if ([detail isKindOfClass:NSString.class] && detail.length){
			CGSize sub = [TGLocalized(detail) sizeWithFont:TGFontCaption()
					constrainedToSize:CGSizeMake(width, CGFLOAT_MAX)
					lineBreakMode:NSLineBreakByWordWrapping];
			total += ceilf(sub.height);
		}
		return MAX(TGMetricRow, total);
	}
	return TGMetricRow;
}

+ (instancetype)cellForTableView:(UITableView *)tableView
							 row:(NSDictionary *)row
					   rowIndex:(NSInteger)rowIndex
					   totalRows:(NSInteger)totalRows {
	NSString *reuse = [self reuseIdentifierForRow:row];
	TGRowCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell){
		UITableViewCellStyle style = [self isSubtitleRow:row]
				? UITableViewCellStyleSubtitle : UITableViewCellStyleValue1;
		cell = [[TGRowCell alloc] initWithStyle:style reuseIdentifier:reuse];
	}
	[cell configureWithRow:row rowIndex:rowIndex totalRows:totalRows];
	// Every screen wants its colour, raw text and accessory keys honoured;
	// four screens overrode cellForRow just to call this.
	[cell applyAppendedOptions:row];
	return cell;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuse {
	self = [super initWithStyle:style reuseIdentifier:reuse];
	if (self)
		[self applyTheme];
	return self;
}

- (void)prepareForReuse {
	[super prepareForReuse];
	self.switchToggleBlock = nil;
	self.accessoryTapBlock = nil;
	self.accessoryView = nil;
	self.accessoryType = UITableViewCellAccessoryNone;
	self.imageView.image = nil;
	self.selectionStyle = UITableViewCellSelectionStyleDefault;
	self.row = nil;
	[self applyTheme];
}

- (void)configureWithRow:(NSDictionary *)row
				rowIndex:(NSInteger)rowIndex
			   totalRows:(NSInteger)totalRows {
	self.row = row;
	self.rowIndex = rowIndex;
	self.totalRows = totalRows;

	TGTheme *theme = [TGTheme shared];
	NSString *kind = row[TGRowKind] ?: TGKindPlain;
	BOOL subtitle = [self.class isSubtitleRow:row];
	UITableViewCellStyle style = subtitle ? UITableViewCellStyleSubtitle
			: UITableViewCellStyleValue1;

	self.accessoryType = UITableViewCellAccessoryNone;
	self.accessoryView = nil;
	self.accessoryTapBlock = nil;
	self.imageView.image = nil;
	self.selectionStyle = UITableViewCellSelectionStyleDefault;
	self.textLabel.textAlignment = NSTextAlignmentLeft;
	NSInteger detailLines = [row[TGRowDetailLines] integerValue];
	self.detailTextLabel.numberOfLines = detailLines > 0 ? detailLines : 1;
	NSNumber *titleLines = row[TGRowTitleLines];
	self.textLabel.numberOfLines = titleLines ? [titleLines integerValue] : 1;
	self.textLabel.lineBreakMode = titleLines &&
			[titleLines integerValue] != 1
			? NSLineBreakByWordWrapping : NSLineBreakByTruncatingTail;
	[theme styleGroupedCell:self forRow:rowIndex totalRows:totalRows];

	self.textLabel.text = TGLocalized(row[TGRowTitle]);
	self.detailTextLabel.text = TGLocalized(row[TGRowDetail]);
	UITableViewCell *system = [TGTheme systemCellOfStyle:style];
	self.textLabel.font = system.textLabel.font;
	self.detailTextLabel.font = system.detailTextLabel.font;
	if ([theme isDark]){
		self.textLabel.textColor = [theme primaryTextColour];
		self.detailTextLabel.textColor = [theme cellDetailColour];
	} else {
		self.textLabel.textColor = system.textLabel.textColor;
		self.detailTextLabel.textColor = system.detailTextLabel.textColor;
	}
	if ([kind isEqualToString:TGKindDestructive])
		self.textLabel.textColor = [theme destructiveColour];

	if (row[TGRowIcon])
		self.imageView.image = [TGIcons settingsIconNamed:row[TGRowIcon]
												   color:row[TGRowColour]];

	if ([kind isEqualToString:TGKindToggle]){
		self.switchToggleBlock = row[TGRowToggle];
		self.toggleSwitch.enabled = row[TGRowEnabled]
				? [row[TGRowEnabled] boolValue] : YES;
		[self.toggleSwitch setOn:[row[TGRowOn] boolValue] animated:NO];
		self.accessoryView = self.toggleSwitch;
		self.selectionStyle = UITableViewCellSelectionStyleNone;
	} else if ([kind isEqualToString:TGKindCheck]){
		self.accessoryType = [row[TGRowChecked] boolValue]
				? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
	} else if ([kind isEqualToString:TGKindDisclosure]){
		if ([row[TGRowOpens] boolValue])
			self.accessoryView = [[UIImageView alloc] initWithImage:
					[TGIcons skeuomorphicDisclosureChevron]];
		else
			self.accessoryView = nil;
		self.accessoryType = UITableViewCellAccessoryNone;
	} else if ([kind isEqualToString:TGKindAction]){
		self.textLabel.textColor = [theme accentColour];
		self.textLabel.textAlignment = NSTextAlignmentCenter;
	} else if ([kind isEqualToString:TGKindPlain]){
		self.textLabel.textColor = [theme secondaryTextColour];
		self.selectionStyle = UITableViewCellSelectionStyleNone;
	} else if ([kind isEqualToString:TGKindToggleInfo]){
		self.textLabel.text = TGLocalized(row[TGRowTitle]);
		self.textLabel.font = TGFontRow();
		self.textLabel.textAlignment = NSTextAlignmentLeft;
		self.textLabel.textColor = [theme primaryTextColour];

		self.detailTextLabel.text = TGLocalized(row[TGRowDetail]);
		self.detailTextLabel.font = TGFontCaption();
		self.detailTextLabel.textColor = [theme secondaryTextColour];
		self.detailTextLabel.numberOfLines = 0;

		self.imageView.image = row[TGRowIcon]
				? [TGIcons settingsIconNamed:row[TGRowIcon]
									   color:row[TGRowColour]] : nil;

		self.switchToggleBlock = row[TGRowToggle];
		self.toggleSwitch.enabled = row[TGRowEnabled]
				? [row[TGRowEnabled] boolValue] : YES;
		[self.toggleSwitch setOn:[row[TGRowOn] boolValue] animated:NO];
		self.accessoryView = self.toggleSwitch;
		self.selectionStyle = UITableViewCellSelectionStyleNone;
	}

	if ([row[TGRowAccessoryTitle] length]){
		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		button.frame = CGRectMake(0, 0, TGMetricStoryBubble,
				TGMetricSearchScopeHeight);
		button.titleLabel.font = TGFontCaption();
		[button setTitle:row[TGRowAccessoryTitle] forState:UIControlStateNormal];
		[button setTitleColor:[theme accentColour]
				forState:UIControlStateNormal];
		[button addTarget:self action:@selector(accessoryTapped:)
				forControlEvents:UIControlEventTouchUpInside];
		self.accessoryTapBlock = row[TGRowAccessoryTap];
		self.accessoryView = button;
	}

	if ([row[TGRowBadge] boolValue]){
		CGFloat side = TGMetricBadgeH + TGMetricPadTiny;
		UILabel *badge = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, side, side)];
		badge.text = @"!";
		badge.font = TGFontMicro();
		badge.textAlignment = NSTextAlignmentCenter;
		badge.textColor = [theme onAccentColour];
		badge.backgroundColor = [theme destructiveColour];
		badge.layer.cornerRadius = TGHalf(side);
		badge.clipsToBounds = YES;
		self.accessoryView = badge;
	}

	NSString *trailing = row[TGRowAccessory];
	if ([trailing isKindOfClass:NSString.class] && trailing.length){
		UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
		label.font = TGFontSubheadStrong();
		label.text = trailing;
		UIColor *trailingColour = row[TGRowAccessoryColour];
		label.textColor = trailingColour ?: [theme secondaryTextColour];
		[label sizeToFit];
		self.accessoryView = label;
	}

	if (row[TGRowTap] == nil)
		self.selectionStyle = UITableViewCellSelectionStyleNone;
}

- (void)applyTheme {
	if (!self.row)
		return;
	[self configureWithRow:self.row rowIndex:self.rowIndex
				 totalRows:self.totalRows];
}

- (UISwitch *)toggleSwitch {
	if (_toggleSwitch)
		return _toggleSwitch;
	_toggleSwitch = [[UISwitch alloc] init];
	[_toggleSwitch addTarget:self action:@selector(toggleChanged:)
			forControlEvents:UIControlEventValueChanged];
	return _toggleSwitch;
}

- (void)toggleChanged:(UISwitch *)sender {
	void (^changed)(BOOL) = self.switchToggleBlock;
	if (changed)
		changed(sender.on);
}

- (void)accessoryTapped:(UIButton *)sender {
	(void)sender;
	void (^tap)(void) = self.accessoryTapBlock;
	if (tap)
		tap();
}

- (void)layoutSubviews {
	[super layoutSubviews];
	[self keepValueWhole];
	if (!self.imageView.image ||
		NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1)
		return;
	CGRect icon = self.imageView.frame;
	CGFloat shift = TGMetricGutter - icon.origin.x;
	if (shift <= 0)
		return;
	CGFloat iconRight = CGRectGetMaxX(icon);
	icon.origin.x += shift;
	self.imageView.frame = icon;
	CGFloat edge = self.contentView.bounds.size.width - TGMetricPadMedium;
	for (UILabel *label in @[self.textLabel, self.detailTextLabel]) {
		CGRect frame = label.frame;
		if (frame.origin.x > iconRight + TGMetricGutter)
			continue;
		frame.origin.x += shift;
		frame.size.width = MIN(frame.size.width, MAX(0, edge - frame.origin.x));
		label.frame = frame;
	}
}

/// Value1 gives the title priority and cut "121 МБ" to "1…" next to a long
/// Russian title. The value is the answer the row exists for, so it keeps its
/// full width and the title takes the ellipsis instead.
- (void)keepValueWhole {
	UILabel *value = self.detailTextLabel;
	UILabel *title = self.textLabel;
	if (!value.text.length || !title.text.length || value.numberOfLines != 1 ||
		CGRectGetMinY(value.frame) > CGRectGetMinY(title.frame) + TGMetricPadSmall)
		return;   // empty, wrapping or a subtitle row: nothing side by side
	CGFloat need = ceilf([value.text sizeWithFont:value.font].width);
	if (need <= value.frame.size.width)
		return;
	CGRect valueFrame = value.frame;
	CGFloat right = CGRectGetMaxX(valueFrame);
	valueFrame.size.width = need;
	valueFrame.origin.x = right - need;
	value.frame = valueFrame;
	CGRect titleFrame = title.frame;
	titleFrame.size.width = MAX(0, valueFrame.origin.x - TGMetricPadMedium -
			titleFrame.origin.x);
	title.frame = titleFrame;
}

#pragma mark - appended row options

/// The keys above are applied after the row's own configure, so a screen that
/// needs a coloured value or a centred destructive row does not paint labels
/// itself. Raw text wins over TGLocalized: a bio is the account's, not the
/// pack's.
- (void)applyAppendedOptions:(NSDictionary *)row {
	if (![row isKindOfClass:NSDictionary.class])
		return;

	if ([row[TGRowRawTitle] boolValue])
		self.textLabel.text = row[TGRowTitle] ?: @"";
	if ([row[TGRowRawDetail] boolValue])
		self.detailTextLabel.text = row[TGRowDetail] ?: @"";

	if ([row[TGRowLabelAbove] boolValue]){
		TGTheme *theme = [TGTheme shared];
		self.textLabel.font = TGFontMeta();
		self.textLabel.textColor = [theme secondaryTextColour];
		self.detailTextLabel.font = TGFontBody();
		self.detailTextLabel.textColor = [row[TGRowDetailAccent] boolValue]
				? [theme accentColour] : [theme primaryTextColour];
	}

	UIColor *titleColour = row[TGRowTitleColour];
	if ([titleColour isKindOfClass:UIColor.class])
		self.textLabel.textColor = titleColour;
	UIColor *detailColour = row[TGRowDetailColour];
	if ([detailColour isKindOfClass:UIColor.class])
		self.detailTextLabel.textColor = detailColour;

	if ([row[TGRowCentred] boolValue]){
		self.textLabel.textAlignment = NSTextAlignmentCenter;
		self.detailTextLabel.text = nil;
		self.accessoryView = nil;
		self.accessoryType = UITableViewCellAccessoryNone;
	}

	UIImage *accessoryImage = row[TGRowAccessoryImage];
	if ([accessoryImage isKindOfClass:UIImage.class]){
		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		button.frame = CGRectMake(0, 0, TGMetricRow, TGMetricRow);
		[button setImage:accessoryImage forState:UIControlStateNormal];
		[button addTarget:self action:@selector(accessoryTapped:)
				forControlEvents:UIControlEventTouchUpInside];
		self.accessoryTapBlock = row[TGRowAccessoryTap];
		self.accessoryView = button;
	}
}

@end
