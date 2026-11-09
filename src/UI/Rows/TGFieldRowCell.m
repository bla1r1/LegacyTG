//
// TGFieldRowCell.m
//
#import "TGFieldRowCell.h"
#import "TGRows.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGLocalization.h"

#pragma mark - single-line and multiline field

@interface TGFieldRowCell ()
@property (nonatomic, strong) NSDictionary *row;
@property (nonatomic, copy) void (^changeBlock)(NSString *text);
@property (nonatomic, copy) void (^endEditingBlock)(NSString *text);
@property (nonatomic, copy) void (^returnBlock)(void);
@property (nonatomic, strong) UILabel *prefixLabel;
@property (nonatomic, strong) UILabel *placeholderLabel;
@property (nonatomic, strong) UILabel *counterLabel;
@end

@implementation TGFieldRowCell

+ (CGFloat)heightForRow:(NSDictionary *)row inTableView:(UITableView *)tableView {
	if (![row[TGRowKind] isEqualToString:TGKindMultilineField])
		return TGMetricRow;
	CGFloat width = MAX(0, tableView.bounds.size.width - TGDoubled(TGMetricGutter));
	NSInteger maxLength = [row[TGRowFieldMaxLength] integerValue];
	if (maxLength > 0)
		width -= TGMetricFieldCounterWidth;
	NSString *text = row[TGRowFieldText];
	if (![text isKindOfClass:NSString.class] || !text.length)
		text = @"|";
	CGSize size = [text sizeWithFont:TGFontRow()
			constrainedToSize:CGSizeMake(width, TGMetricTextMeasureHeight)
			lineBreakMode:NSLineBreakByWordWrapping];
	CGFloat height = size.height + TGDoubled(TGMetricPad);
	if (maxLength > 0)
		height += TGMetricLineCaption;
	return MAX(TGMetricFieldMultilineMinHeight, height);
}

+ (instancetype)cellForTableView:(UITableView *)tableView row:(NSDictionary *)row
					   rowIndex:(NSInteger)rowIndex totalRows:(NSInteger)totalRows {
	NSString *kind = row[TGRowKind] ?: TGKindField;
	NSString *reuse = [@"TGFieldRowCell-" stringByAppendingString:kind];
	TGFieldRowCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[TGFieldRowCell alloc] initWithStyle:UITableViewCellStyleDefault
									 reuseIdentifier:reuse];
	[cell configureWithRow:row rowIndex:rowIndex totalRows:totalRows];
	return cell;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style
			   reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;
	self.selectionStyle = UITableViewCellSelectionStyleNone;
	self.textLabel.text = nil;
	self.detailTextLabel.text = nil;

	_textField = [[UITextField alloc] initWithFrame:CGRectZero];
	_textField.delegate = self;
	_textField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
	[_textField addTarget:self action:@selector(fieldTextChanged:)
			forControlEvents:UIControlEventEditingChanged];
	[self.contentView addSubview:_textField];

	_textView = [[UITextView alloc] initWithFrame:CGRectZero];
	_textView.delegate = self;
	_textView.backgroundColor = [UIColor clearColor];
	_textView.scrollEnabled = NO;
	_textView.contentInset = UIEdgeInsetsZero;
	if ([_textView respondsToSelector:@selector(setTextContainerInset:)])
		_textView.textContainerInset = UIEdgeInsetsZero;
	[self.contentView addSubview:_textView];
	_textView.hidden = YES;

	_prefixLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_prefixLabel.backgroundColor = [UIColor clearColor];
	_prefixLabel.hidden = YES;
	[self.contentView addSubview:_prefixLabel];

	_placeholderLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_placeholderLabel.backgroundColor = [UIColor clearColor];
	_placeholderLabel.userInteractionEnabled = NO;
	_placeholderLabel.hidden = YES;
	[self.contentView addSubview:_placeholderLabel];

	_counterLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_counterLabel.backgroundColor = [UIColor clearColor];
	_counterLabel.textAlignment = NSTextAlignmentRight;
	_counterLabel.hidden = YES;
	[self.contentView addSubview:_counterLabel];

	[self applyTheme];
	return self;
}

- (void)prepareForReuse {
	[super prepareForReuse];
	self.changeBlock = nil;
	self.endEditingBlock = nil;
	self.returnBlock = nil;
	self.fieldIdentifier = nil;
	self.row = nil;
}

- (void)configureWithRow:(NSDictionary *)row rowIndex:(NSInteger)rowIndex
			   totalRows:(NSInteger)totalRows {
	self.row = row;
	self.fieldIdentifier = TGRowFieldKey(row);
	self.changeBlock = row[TGRowFieldChanged];
	self.endEditingBlock = row[TGRowFieldEndEditing];
	self.returnBlock = row[TGRowFieldReturn];

	TGTheme *theme = [TGTheme shared];
	[theme styleGroupedCell:self forRow:rowIndex totalRows:totalRows];
	self.selectionStyle = UITableViewCellSelectionStyleNone;

	NSString *text = row[TGRowFieldText];
	if (![text isKindOfClass:NSString.class])
		text = @"";
	NSString *placeholder = TGLocalized(row[TGRowFieldPlaceholder] ?: @"");
	NSNumber *keyboard = row[TGRowFieldKeyboard];
	UIReturnKeyType returnKey = row[TGRowFieldReturnKey]
			? (UIReturnKeyType)[row[TGRowFieldReturnKey] integerValue]
			: UIReturnKeyDone;
	NSNumber *capitalization = row[TGRowFieldAutocapitalization];
	NSNumber *autocorrection = row[TGRowFieldAutocorrection];

	BOOL multiline = [row[TGRowKind] isEqualToString:TGKindMultilineField];
	self.textField.hidden = multiline;
	self.textView.hidden = !multiline;
	self.prefixLabel.hidden = multiline || ![row[TGRowFieldPrefix] length];
	self.placeholderLabel.hidden = !multiline;

	self.prefixLabel.text = row[TGRowFieldPrefix];
	self.prefixLabel.font = TGFontRow();
	self.prefixLabel.textColor = [theme secondaryTextColour];

	if (multiline){
		self.textView.font = TGFontRow();
		self.textView.textColor = [theme primaryTextColour];
		self.textView.keyboardType = keyboard ? (UIKeyboardType)[keyboard integerValue]
				: UIKeyboardTypeDefault;
		self.textView.returnKeyType = returnKey;
		self.textView.autocapitalizationType = capitalization
				? (UITextAutocapitalizationType)[capitalization integerValue]
				: UITextAutocapitalizationTypeSentences;
		self.textView.autocorrectionType = autocorrection
				? (UITextAutocorrectionType)[autocorrection integerValue]
				: UITextAutocorrectionTypeDefault;
		if (![self.textView isFirstResponder] &&
				![self.textView.text isEqualToString:text])
			self.textView.text = text;
		self.placeholderLabel.text = placeholder;
		self.placeholderLabel.font = TGFontRow();
		self.placeholderLabel.textColor = [theme placeholderColour];
		self.placeholderLabel.hidden = self.textView.text.length > 0;
		self.counterLabel.font = TGFontCaption();
		[self updateCounter];
	} else {
		self.textField.font = TGFontRow();
		self.textField.textColor = [theme primaryTextColour];
		self.textField.keyboardType = keyboard ? (UIKeyboardType)[keyboard integerValue]
				: UIKeyboardTypeDefault;
		self.textField.returnKeyType = returnKey;
		self.textField.secureTextEntry = [row[TGRowFieldSecure] boolValue];
		self.textField.clearButtonMode = [row[TGRowFieldClear] boolValue]
				? UITextFieldViewModeWhileEditing : UITextFieldViewModeNever;
		self.textField.autocapitalizationType = capitalization
				? (UITextAutocapitalizationType)[capitalization integerValue]
				: UITextAutocapitalizationTypeSentences;
		self.textField.autocorrectionType = autocorrection
				? (UITextAutocorrectionType)[autocorrection integerValue]
				: UITextAutocorrectionTypeDefault;
		if (![self.textField isFirstResponder] &&
				![self.textField.text isEqualToString:text])
			self.textField.text = text;
		[self setPlaceholder:placeholder on:self.textField];
	}
	[self setNeedsLayout];
}

- (void)setPlaceholder:(NSString *)placeholder on:(UITextField *)field {
	UIColor *colour = [[TGTheme shared] placeholderColour];
	if ([field respondsToSelector:@selector(setAttributedPlaceholder:)]){
		field.attributedPlaceholder = [[NSAttributedString alloc]
				initWithString:placeholder
					attributes:@{NSForegroundColorAttributeName : colour}];
		return;
	}
	field.placeholder = placeholder;
}

- (void)applyTheme {
	if (self.row)
		[self configureWithRow:self.row rowIndex:0 totalRows:1];
}

- (void)focus {
	if ([self.row[TGRowKind] isEqualToString:TGKindMultilineField]){
		if (!self.textView.isFirstResponder)
			[self.textView becomeFirstResponder];
	} else if (!self.textField.isFirstResponder){
		[self.textField becomeFirstResponder];
	}
}

- (NSString *)text {
	return self.textView.hidden ? (self.textField.text ?: @"")
			: (self.textView.text ?: @"");
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGRect bounds = self.contentView.bounds;
	CGFloat left = TGMetricGutter;
	CGFloat width = MAX(0, bounds.size.width - TGDoubled(left));

	if (!self.textView.hidden){
		CGFloat counterHeight = self.counterLabel.hidden ? TGMetricPad : TGMetricLineCaption;
		self.textView.frame = CGRectMake(left, TGMetricPad, width,
				MAX(0, bounds.size.height - TGMetricPad - counterHeight));
		self.placeholderLabel.frame = CGRectMake(left, TGMetricPad, width,
				MIN(TGMetricLineRow, MAX(0, bounds.size.height - TGMetricPad)));
		CGFloat counterWidth = self.counterLabel.hidden ? 0 : TGMetricFieldCounterWidth;
		self.counterLabel.frame = CGRectMake(bounds.size.width - left - counterWidth,
				bounds.size.height - TGMetricLineCaption, counterWidth,
				TGMetricLineCaption);
		return;
	}

	CGFloat prefixWidth = self.prefixLabel.hidden ? 0 : TGMetricFieldPrefixWidth;
	self.prefixLabel.frame = CGRectMake(left, 0, prefixWidth, bounds.size.height);
	self.textField.frame = CGRectMake(left + prefixWidth, 0,
			MAX(0, width - prefixWidth), bounds.size.height);
}

- (void)updateCounter {
	BOOL exceeded = NO;
	NSString *counter = TGFieldCounterText(self.textView.text,
			[self.row[TGRowFieldMaxLength] integerValue], &exceeded);
	self.counterLabel.text = counter;
	self.counterLabel.textColor = exceeded
			? [[TGTheme shared] destructiveColour]
			: [[TGTheme shared] secondaryTextColour];
	self.counterLabel.hidden = counter.length == 0;
}

- (void)notifyChanged {
	NSString *text = self.text;
	void (^changed)(NSString *) = self.changeBlock;
	if (changed)
		changed(text);
	[self.fieldDelegate fieldRowCell:self didChangeText:text];
}

- (void)fieldTextChanged:(UITextField *)field {
	(void)field;
	[self notifyChanged];
}

- (BOOL)textField:(UITextField *)textField
		shouldChangeCharactersInRange:(NSRange)range
		replacementString:(NSString *)string {
	NSString *current = textField.text ?: @"";
	NSString *next = [current stringByReplacingCharactersInRange:range withString:string];
	NSInteger maxLength = [self.row[TGRowFieldMaxLength] integerValue];
	return TGFieldTextWithinLimit(next, maxLength);
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	void (^action)(void) = self.returnBlock;
	if (action)
		action();
	else
		[textField resignFirstResponder];
	return NO;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
	(void)textField;
	[self.fieldDelegate fieldRowCellDidBeginEditing:self];
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
	[self endEditingWithText:textField.text];
}

- (void)textViewDidBeginEditing:(UITextView *)textView {
	(void)textView;
	[self.fieldDelegate fieldRowCellDidBeginEditing:self];
}

- (void)textViewDidEndEditing:(UITextView *)textView {
	[self endEditingWithText:textView.text];
}

- (void)endEditingWithText:(NSString *)text {
	self.placeholderLabel.hidden = text.length > 0;
	void (^ended)(NSString *) = self.endEditingBlock;
	if (ended)
		ended(text ?: @"");
	[self.fieldDelegate fieldRowCellDidEndEditing:self];
}

- (BOOL)textView:(UITextView *)textView
		shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
	if ([text isEqualToString:@"\n"]){
		void (^action)(void) = self.returnBlock;
		if (action){
			action();
			return NO;
		}
	}
	NSString *current = textView.text ?: @"";
	NSString *next = [current stringByReplacingCharactersInRange:range withString:text];
	return TGFieldTextWithinLimit(next, [self.row[TGRowFieldMaxLength] integerValue]);
}

- (void)textViewDidChange:(UITextView *)textView {
	self.placeholderLabel.hidden = textView.text.length > 0;
	[self updateCounter];
	[self notifyChanged];
}

@end

#pragma mark - note row

@interface TGNoteRowCell ()
@property (nonatomic, strong) NSDictionary *row;
@property (nonatomic, strong) UILabel *noteLabel;
@end

@implementation TGNoteRowCell

+ (CGFloat)heightForRow:(NSDictionary *)row inTableView:(UITableView *)tableView {
	CGFloat width = MAX(0, tableView.bounds.size.width - TGDoubled(TGMetricGutter));
	CGSize size = [TGLocalized(row[TGRowTitle] ?: @"") sizeWithFont:TGFontCaption()
			constrainedToSize:CGSizeMake(width, TGMetricTextMeasureHeight)
			lineBreakMode:NSLineBreakByWordWrapping];
	return MAX(TGMetricRow, size.height + TGDoubled(TGMetricPad));
}

+ (instancetype)cellForTableView:(UITableView *)tableView row:(NSDictionary *)row {
	TGNoteRowCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TGNoteRowCell"];
	if (!cell)
		cell = [[TGNoteRowCell alloc] initWithStyle:UITableViewCellStyleDefault
									 reuseIdentifier:@"TGNoteRowCell"];
	[cell configureWithRow:row];
	return cell;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style
			   reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;
	_noteLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_noteLabel.numberOfLines = 0;
	_noteLabel.backgroundColor = [UIColor clearColor];
	[self.contentView addSubview:_noteLabel];
	[self applyTheme];
	return self;
}

- (void)configureWithRow:(NSDictionary *)row {
	self.row = row;
	[self applyTheme];
	[self setNeedsLayout];
}

- (void)applyTheme {
	TGTheme *theme = [TGTheme shared];
	[self styleCellWithTheme:theme];
	self.selectionStyle = UITableViewCellSelectionStyleNone;
	self.noteLabel.text = TGLocalized(self.row[TGRowTitle] ?: @"");
	self.noteLabel.font = TGFontCaption();
	NSInteger tone = [self.row[TGRowTextTone] integerValue];
	self.noteLabel.textColor = tone == 2
			? [theme destructiveColour]
			: (tone == 1 ? [theme accentColour] : [theme secondaryTextColour]);
}

- (void)styleCellWithTheme:(TGTheme *)theme {
	(void)theme;
	[[TGTheme shared] styleCell:self];
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGRect bounds = self.contentView.bounds;
	self.noteLabel.frame = CGRectMake(TGMetricGutter, TGMetricPad,
			MAX(0, bounds.size.width - TGDoubled(TGMetricGutter)),
			MAX(0, bounds.size.height - TGDoubled(TGMetricPad)));
}

@end

#pragma mark - photo row

@interface TGPhotoRowCell ()
@property (nonatomic, strong) NSDictionary *row;
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, copy) void (^actionBlock)(void);
@property (nonatomic, copy) void (^imageLoader)(UIImageView *);
@property (nonatomic, assign) BOOL imageLoaderStarted;
@end

@implementation TGPhotoRowCell

+ (CGFloat)heightForRow:(NSDictionary *)row inTableView:(UITableView *)tableView {
	(void)row;
	(void)tableView;
	return TGMetricEditProfileHeaderRow;
}

+ (instancetype)cellForTableView:(UITableView *)tableView row:(NSDictionary *)row {
	TGPhotoRowCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TGPhotoRowCell"];
	if (!cell)
		cell = [[TGPhotoRowCell alloc] initWithStyle:UITableViewCellStyleDefault
									 reuseIdentifier:@"TGPhotoRowCell"];
	[cell configureWithRow:row];
	return cell;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style
			   reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;
	self.selectionStyle = UITableViewCellSelectionStyleNone;
	_avatarView = [[UIImageView alloc] initWithFrame:CGRectZero];
	_avatarView.contentMode = UIViewContentModeScaleAspectFill;
	_avatarView.clipsToBounds = YES;
	[self.contentView addSubview:_avatarView];
	_actionButton = [UIButton buttonWithType:UIButtonTypeCustom];
	[_actionButton addTarget:self action:@selector(actionTapped:)
			forControlEvents:UIControlEventTouchUpInside];
	[self.contentView addSubview:_actionButton];
	[self applyTheme];
	return self;
}

- (void)configureWithRow:(NSDictionary *)row {
	self.row = row;
	self.actionBlock = row[TGRowAccessoryTap];
	self.imageLoader = row[TGRowImageLoader];
	self.imageLoaderStarted = NO;
	[self applyTheme];
	[self setNeedsLayout];
}

- (void)applyTheme {
	TGTheme *theme = [TGTheme shared];
	[[TGTheme shared] styleCell:self];
	self.selectionStyle = UITableViewCellSelectionStyleNone;
	self.avatarView.image = self.row[TGRowImage];
	self.avatarView.layer.cornerRadius = TGHalf(TGMetricProfileAvatar);
	self.avatarView.layer.borderColor = [theme separatorColour].CGColor;
	self.avatarView.layer.borderWidth = 1.0f;
	NSString *title = self.row[TGRowAccessoryTitle];
	self.actionButton.hidden = !title.length;
	[self.actionButton setTitle:title forState:UIControlStateNormal];
	[self.actionButton setTitleColor:[theme accentColour]
			forState:UIControlStateNormal];
	self.actionButton.titleLabel.font = TGFontRow();
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGRect bounds = self.contentView.bounds;
	self.avatarView.frame = CGRectMake(TGCenteredOrigin(bounds.size.width,
			TGMetricProfileAvatar), TGMetricPad, TGMetricProfileAvatar,
			TGMetricProfileAvatar);
	self.actionButton.frame = CGRectMake(0, TGMetricProfileAvatar + TGMetricPadMedium,
			bounds.size.width, TGMetricLineTitle);
	if (!self.imageLoaderStarted && self.imageLoader &&
			self.avatarView.bounds.size.width > 0){
		self.imageLoaderStarted = YES;
		self.imageLoader(self.avatarView);
	}
}

- (void)actionTapped:(UIButton *)button {
	(void)button;
	void (^action)(void) = self.actionBlock;
	if (action)
		action();
}

@end

#pragma mark - image check row

@interface TGImageCheckRowCell ()
@property (nonatomic, strong) NSDictionary *row;
@end

@implementation TGImageCheckRowCell

+ (CGFloat)heightForRow:(NSDictionary *)row inTableView:(UITableView *)tableView {
	(void)row;
	(void)tableView;
	return TGMetricRow;
}

+ (instancetype)cellForTableView:(UITableView *)tableView row:(NSDictionary *)row {
	TGImageCheckRowCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TGImageCheckRowCell"];
	if (!cell)
		cell = [[TGImageCheckRowCell alloc] initWithStyle:UITableViewCellStyleDefault
										 reuseIdentifier:@"TGImageCheckRowCell"];
	[cell configureWithRow:row];
	return cell;
}

- (void)configureWithRow:(NSDictionary *)row {
	self.row = row;
	[self applyTheme];
}

- (void)applyTheme {
	TGTheme *theme = [TGTheme shared];
	[[TGTheme shared] styleCell:self];
	self.selectionStyle = self.row[TGRowTap]
			? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
	self.textLabel.text = TGLocalized(self.row[TGRowTitle] ?: @"");
	self.textLabel.font = TGFontRow();
	self.textLabel.textColor = [theme primaryTextColour];
	self.imageView.image = self.row[TGRowImage];
	self.accessoryType = [self.row[TGRowChecked] boolValue]
			? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
}

@end
