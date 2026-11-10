//
// TGAiComposeViewController.m
//
// Official's TextProcessingScreen, edit mode, rebuilt for the composer: the
// chat and its text arrive with the push, Translate / Style / Fix are the
// tabs across the top, the original and the result are the two blocks, and
// the one bottom action is Apply. Nothing here sends a message.
//
#import "TGAiComposeViewController.h"
#import "TGMessageStore.h"
#import "TGAlertSheet.h"
#import "TGChatActionMenuModel.h"
#import "TGLocalization.h"
#import "TGStyle.h"
#import "TGTheme.h"
#import "TGSegmentedControl.h"

static const CGFloat kAiTextAreaHeight = 118.0f;

@interface TGAiComposeViewController ()

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) TGSegmentedControl *modeControl;
@property (nonatomic, strong) UIButton *languageButton;
@property (nonatomic, strong) NSArray *styleButtons;
@property (nonatomic, strong) UILabel *emojiLabel;
@property (nonatomic, strong) UISwitch *emojiSwitch;
@property (nonatomic, strong) UILabel *sourceBadge;
@property (nonatomic, strong) UITextView *sourceView;
@property (nonatomic, strong) UILabel *resultBadge;
@property (nonatomic, strong) UITextView *resultView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIButton *applyButton;

@property (nonatomic, assign) TGAiComposeMode mode;
@property (nonatomic, copy) NSString *sourceLanguage;
@property (nonatomic, copy) NSString *targetLanguage;
@property (nonatomic, copy) NSString *styleKey;
@property (nonatomic, assign) BOOL addEmojis;
@property (nonatomic, copy) NSString *result;
@property (nonatomic, assign) BOOL processing;
@property (nonatomic, assign) NSInteger requestGeneration;

@end

@implementation TGAiComposeViewController

- (void)viewDidLoad {
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	[super viewDidLoad];
	self.title = TGLocalized(@"Edit");
	self.mode = TGAiComposeModeTranslate;
	self.addEmojis = NO;
	NSArray *styles = TGAiComposeStyleChoices();
	self.styleKey = styles.count ? styles[0][@"key"] : @"";

	NSString *appLanguage = [[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode]
			?: @"en";
	NSDictionary *model = TGAiComposeInputModel(self.initialText ?: @"",
			self.chatId, self.chatLanguage, appLanguage);
	self.sourceLanguage = model[@"sourceLanguage"];
	self.targetLanguage = model[@"targetLanguage"];
	self.result = @"";

	[self buildViews];
	[self applyTheme];
	[self updateModeControls];
	[self runRequest];
}

- (void)buildViews {
	TGTheme *theme = [TGTheme shared];
	self.view.backgroundColor = [theme groupedBackgroundColour];

	self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
	self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
			UIViewAutoresizingFlexibleHeight;
	self.scrollView.alwaysBounceVertical = YES;
	[self.view addSubview:self.scrollView];

	self.modeControl = [[TGSegmentedControl alloc] initWithItems:TGAiComposeModeTitles()];
	[self.modeControl addTarget:self action:@selector(modeChanged:)
			   forControlEvents:UIControlEventValueChanged];
	[self.scrollView addSubview:self.modeControl];

	NSMutableArray *buttons = [NSMutableArray array];
	NSArray *choices = TGAiComposeStyleChoices();
	for (NSUInteger i = 0; i < choices.count; i++) {
		NSDictionary *choice = choices[i];
		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		button.tag = (NSInteger)i;
		button.titleLabel.font = TGFontCaptionStrong();
		[button setTitle:choice[@"title"] forState:UIControlStateNormal];
		[button addTarget:self action:@selector(styleTapped:)
		 forControlEvents:UIControlEventTouchUpInside];
		[self.scrollView addSubview:button];
		[buttons addObject:button];
	}
	self.styleButtons = buttons;

	self.emojiLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	self.emojiLabel.font = TGFontBody();
	self.emojiLabel.text = TGLocalized(@"Add emoji");
	self.emojiLabel.backgroundColor = [UIColor clearColor];
	[self.scrollView addSubview:self.emojiLabel];

	self.emojiSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(0, 0,
			TGMetricSwitchW, TGMetricSwitchH)];
	self.emojiSwitch.on = self.addEmojis;
	[self.emojiSwitch addTarget:self action:@selector(emojiChanged:)
			   forControlEvents:UIControlEventValueChanged];
	[self.scrollView addSubview:self.emojiSwitch];

	self.languageButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.languageButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
	self.languageButton.titleLabel.font = TGFontRow();
	[self.languageButton addTarget:self action:@selector(languageTapped)
				   forControlEvents:UIControlEventTouchUpInside];
	[self.scrollView addSubview:self.languageButton];

	self.sourceBadge = [[UILabel alloc] initWithFrame:CGRectZero];
	self.sourceBadge.font = TGFontCaptionStrong();
	self.sourceBadge.text = TGLocalized(@"Original");
	self.sourceBadge.backgroundColor = [UIColor clearColor];
	[self.scrollView addSubview:self.sourceBadge];

	self.sourceView = [self textView];
	self.sourceView.text = self.initialText ?: @"";
	[self.scrollView addSubview:self.sourceView];

	self.resultBadge = [[UILabel alloc] initWithFrame:CGRectZero];
	self.resultBadge.font = TGFontCaptionStrong();
	self.resultBadge.text = TGLocalized(@"Result");
	self.resultBadge.backgroundColor = [UIColor clearColor];
	[self.scrollView addSubview:self.resultBadge];

	self.resultView = [self textView];
	[self.scrollView addSubview:self.resultView];

	self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:
			UIActivityIndicatorViewStyleGray];
	self.spinner.hidesWhenStopped = YES;
	[self.scrollView addSubview:self.spinner];

	self.applyButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.applyButton.titleLabel.font = TGFontHeader();
	[self.applyButton setTitle:TGLocalized(@"Apply") forState:UIControlStateNormal];
	[self.applyButton addTarget:self action:@selector(applyTapped)
			   forControlEvents:UIControlEventTouchUpInside];
	self.applyButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin |
			UIViewAutoresizingFlexibleWidth;
	[self.view addSubview:self.applyButton];
}

- (UITextView *)textView {
	UITextView *view = [[UITextView alloc] initWithFrame:CGRectZero];
	view.editable = NO;
	if ([view respondsToSelector:@selector(setSelectable:)])
		view.selectable = YES;
	view.scrollEnabled = YES;
	view.font = TGFontBody();
	view.layer.cornerRadius = TGMetricCornerControl;
	view.layer.borderWidth = TGMetricHairline;
	if ([view respondsToSelector:@selector(textContainerInset)])
		view.textContainerInset = UIEdgeInsetsMake(TGMetricPadMedium,
				TGMetricPadMedium, TGMetricPadMedium, TGMetricPadMedium);
	else
		view.contentInset = UIEdgeInsetsMake(TGMetricPadMedium,
				TGMetricPadMedium, TGMetricPadMedium, TGMetricPadMedium);
	return view;
}

- (void)applyTheme {
	[super applyTheme];
	TGTheme *theme = [TGTheme shared];
	self.view.backgroundColor = [theme groupedBackgroundColour];
	// TGViewController's viewDidLoad calls this before our views exist; the
	// array literal below threw on the nil text views and killed the app.
	if (!self.sourceView || !self.resultView)
		return;
	self.sourceBadge.textColor = [theme secondaryTextColour];
	self.resultBadge.textColor = [theme secondaryTextColour];
	self.emojiLabel.textColor = [theme primaryTextColour];
	for (UITextView *view in @[self.sourceView, self.resultView]) {
		view.backgroundColor = [theme cardBackgroundColour];
		view.textColor = [theme primaryTextColour];
		view.layer.borderColor = [theme separatorColour].CGColor;
	}
	[self.languageButton setTitleColor:[theme accentColour]
							  forState:UIControlStateNormal];
	[self.applyButton setBackgroundImage:
			[TGTheme buttonImageForStyle:TGButtonStyleAction highlighted:NO
								   height:TGMetricButtonHeight]
								forState:UIControlStateNormal];
	[self.applyButton setBackgroundImage:
			[TGTheme buttonImageForStyle:TGButtonStyleAction highlighted:YES
								   height:TGMetricButtonHeight]
								forState:UIControlStateHighlighted];
	[self.applyButton setTitleColor:[theme onAccentColour]
						   forState:UIControlStateNormal];
	[self updateStyleButtons];
	[self updateResultState];
}

#pragma mark - mode and controls

- (void)modeChanged:(TGSegmentedControl *)control {
	TGAiComposeMode mode = (TGAiComposeMode)control.selectedSegmentIndex;
	if (mode == self.mode)
		return;
	self.mode = mode;
	self.result = @"";
	[self updateModeControls];
	[self runRequest];
}

- (void)styleTapped:(UIButton *)button {
	NSArray *choices = TGAiComposeStyleChoices();
	if (button.tag < 0 || button.tag >= (NSInteger)choices.count)
		return;
	NSString *key = choices[(NSUInteger)button.tag][@"key"];
	if ([key isEqualToString:self.styleKey])
		return;
	self.styleKey = key;
	[self updateStyleButtons];
	self.result = @"";
	[self runRequest];
}

- (void)emojiChanged:(UISwitch *)sender {
	self.addEmojis = sender.on;
	if (self.mode == TGAiComposeModeTranslate || self.mode == TGAiComposeModeStyle) {
		self.result = @"";
		[self runRequest];
	}
}

- (void)languageTapped {
	NSArray *codes = TGAiComposeLanguageChoices();
	NSMutableArray *titles = [NSMutableArray arrayWithCapacity:codes.count];
	for (NSUInteger i = 0; i < codes.count; i++)
		[titles addObject:TGAiComposeLanguageName(codes[i])];
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:titles title:TGLocalized(@"Translate")
			 destructiveIndex:-1 inView:self.view onChoice:^(NSInteger index){
		TGAiComposeViewController *me = weakSelf;
		if (!me || index < 0 || index >= (NSInteger)codes.count)
			return;
		me.targetLanguage = codes[(NSUInteger)index];
		[me updateModeControls];
		me.result = @"";
		[me runRequest];
	}];
}

- (void)updateModeControls {
	BOOL translate = self.mode == TGAiComposeModeTranslate;
	BOOL style = self.mode == TGAiComposeModeStyle;
	self.languageButton.hidden = !translate;
	self.emojiLabel.hidden = !(translate || style);
	self.emojiSwitch.hidden = !(translate || style);
	for (UIButton *button in self.styleButtons)
		button.hidden = !style;
	[self.languageButton setTitle:TGLocalizedFormat(@"Translate to %@",
			TGAiComposeLanguageName(self.targetLanguage))
						forState:UIControlStateNormal];
	self.modeControl.selectedSegmentIndex = self.mode;
	[self updateStyleButtons];
	[self updateResultState];
	[self.view setNeedsLayout];
}

- (void)updateStyleButtons {
	NSArray *choices = TGAiComposeStyleChoices();
	TGTheme *theme = [TGTheme shared];
	for (UIButton *button in self.styleButtons) {
		NSInteger index = button.tag;
		BOOL selected = index >= 0 && index < (NSInteger)choices.count &&
				[choices[(NSUInteger)index][@"key"] isEqualToString:self.styleKey];
		TGButtonStyle style = selected ? TGButtonStyleAction : TGButtonStyleSilver;
		[button setBackgroundImage:[TGTheme buttonImageForStyle:style
				highlighted:NO height:TGMetricRow]
						  forState:UIControlStateNormal];
		[button setBackgroundImage:[TGTheme buttonImageForStyle:style
				highlighted:YES height:TGMetricRow]
						  forState:UIControlStateHighlighted];
		[button setTitleColor:selected ? [theme onAccentColour]
				: [theme primaryTextColour] forState:UIControlStateNormal];
	}
}

- (void)updateResultState {
	self.resultView.text = self.result ?: @"";
	self.applyButton.enabled = self.result.length > 0 && !self.processing;
	self.applyButton.alpha = self.applyButton.enabled
			? TGAlphaOpaque : TGAlphaDisabled;
	if (self.processing) {
		[self.spinner startAnimating];
		self.resultView.text = @"";
	} else {
		[self.spinner stopAnimating];
	}
}

#pragma mark - requests

- (void)runRequest {
	NSString *text = [self.initialText ?: @"" stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!text.length) {
		self.processing = NO;
		self.result = @"";
		[self updateResultState];
		return;
	}
	NSInteger generation = ++self.requestGeneration;
	self.processing = YES;
	self.result = @"";
	[self updateResultState];

	__weak typeof(self) weakSelf = self;
	void (^finish)(NSString *, NSString *) = ^(NSString *answer, NSString *error){
		TGAiComposeViewController *me = weakSelf;
		if (!me || generation != me.requestGeneration)
			return;
		me.processing = NO;
		NSString *clean = [answer isKindOfClass:NSString.class] ? answer : @"";
		me.result = clean.length ? clean : (error ?: TGLocalized(@"An error occurred."));
		[me updateResultState];
	};

	NSString *body = self.initialText ?: @"";
	switch (self.mode) {
		case TGAiComposeModeTranslate: {
			[[TGMessageStore shared] composeTextWithAi:body
									 translateTo:self.targetLanguage
										   style:@""
									   addEmojis:self.addEmojis
									  completion:^(NSString *answer, NSString *error){
				finish(answer, error);
			}];
			break;
		}
		case TGAiComposeModeStyle: {
			[[TGMessageStore shared] composeTextWithAi:body
									 translateTo:@""
										   style:self.styleKey
									   addEmojis:self.addEmojis
									  completion:^(NSString *answer, NSString *error){
				finish(answer, error);
			}];
			break;
		}
		case TGAiComposeModeFix: {
			[[TGMessageStore shared] fixTextWithAi:body
								  completion:^(NSString *answer, NSString *diff,
										  NSString *error){
				finish(answer, error);
			}];
			break;
		}
	}
}

- (void)applyTapped {
	if (!self.result.length)
		return;
	if (self.onApply)
		self.onApply(self.result);
	[self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - layout

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	CGFloat width = self.view.bounds.size.width;
	CGFloat height = self.view.bounds.size.height;
	CGFloat pad = TGMetricPadLarge;
	CGFloat contentWidth = MAX(0.0f, width - TGDoubled(pad));
	CGFloat applyHeight = TGMetricButtonHeight;
	CGFloat applyY = height - applyHeight - pad;
	CGFloat scrollBottom = applyY - TGMetricPadSmall;

	self.scrollView.frame = CGRectMake(0, 0, width, MAX(0.0f, scrollBottom));
	self.applyButton.frame = CGRectMake(pad, applyY, contentWidth, applyHeight);

	CGFloat y = pad;
	self.modeControl.frame = CGRectMake(pad, y, contentWidth, TGMetricRow);
	y += TGMetricRow + TGMetricPadSmall;

	if (self.mode == TGAiComposeModeStyle) {
		CGFloat gap = TGMetricPadSmall;
		CGFloat buttonWidth = MAX(0.0f,
				(contentWidth - TGDoubled(gap)) / self.styleButtons.count);
		for (NSUInteger i = 0; i < self.styleButtons.count; i++) {
			UIButton *button = self.styleButtons[i];
			button.frame = CGRectMake(pad + (buttonWidth + gap) * i, y,
					buttonWidth, TGMetricRow);
		}
		y += TGMetricRow + TGMetricPadSmall;
	}

	if (!self.emojiSwitch.hidden) {
		self.emojiSwitch.frame = CGRectMake(pad, y +
				TGCenteredOrigin(TGMetricRow, self.emojiSwitch.bounds.size.height),
				self.emojiSwitch.bounds.size.width, self.emojiSwitch.bounds.size.height);
		self.emojiLabel.frame = CGRectMake(CGRectGetMaxX(self.emojiSwitch.frame) +
				TGMetricPadSmall, y,
				contentWidth - self.emojiSwitch.bounds.size.width - TGMetricPadSmall,
				TGMetricRow);
		y += TGMetricRow + TGMetricPadSmall;
	}

	if (!self.languageButton.hidden) {
		self.languageButton.frame = CGRectMake(pad, y, contentWidth, TGMetricRow);
		y += TGMetricRow + TGMetricPadSmall;
	}

	self.sourceBadge.frame = CGRectMake(pad, y, contentWidth, TGMetricLineSubhead);
	y += TGMetricLineSubhead + TGMetricPadSmall;
	self.sourceView.frame = CGRectMake(pad, y, contentWidth, kAiTextAreaHeight);
	y += kAiTextAreaHeight + TGMetricPadLarge;

	self.resultBadge.frame = CGRectMake(pad, y, contentWidth, TGMetricLineSubhead);
	self.spinner.frame = CGRectMake(CGRectGetMaxX(self.resultBadge.frame) -
			TGMetricRow, CGRectGetMinY(self.resultBadge.frame), TGMetricRow,
			TGMetricLineSubhead);
	self.spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
	y += TGMetricLineSubhead + TGMetricPadSmall;
	self.resultView.frame = CGRectMake(pad, y, contentWidth, kAiTextAreaHeight);
	y += kAiTextAreaHeight + TGMetricPadLarge;

	self.scrollView.contentSize = CGSizeMake(width, y);
}

@end
