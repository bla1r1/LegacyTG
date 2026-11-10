#import "TGChatViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGChatParityModel.h"
#import "TGChatActionMenuModel.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "UIImage+WebP.h"
#import "TGAttachSheet.h"
#import "TGAlertSheet.h"
#import "TGSheet.h"
#import "TGScheduledViewController.h"
#import "TGChecklistViewController.h"
#import "TGQuickRepliesViewController.h"
#import "TGDiceViewController.h"
#import "TGEphemeralViewController.h"
#import "TGAiComposeViewController.h"
#import "TGStyle.h"

// The mode the recording button was left in last chat, persisted read/write
// on both sides of the input bar. Telegram keeps the choice made in one chat
// for every other one.
#import "TGVideoNoteRecorder.h"

@interface TGComposerInputField : UITextView
@property (nonatomic, copy) void (^onLayout)(void);
@property (nonatomic, copy) NSString *placeholder;
@property (nonatomic, strong) UIColor *placeholderColour;
@property (nonatomic, assign, getter=isEnabled) BOOL enabled;
@property (nonatomic, strong) UILabel *placeholderLabel;
@end

@implementation TGComposerInputField {
	BOOL _inLayout;
	UIView *_rightView;
	UITextFieldViewMode _rightViewMode;
}

- (UIView *)rightView {
	return _rightView;
}

- (void)setRightView:(UIView *)rightView {
	if (_rightView == rightView)
		return;
	[_rightView removeFromSuperview];
	_rightView = rightView;
	if (rightView)
		[self addSubview:rightView];
	[self setNeedsLayout];
}

- (UITextFieldViewMode)rightViewMode {
	return _rightViewMode;
}

- (void)setRightViewMode:(UITextFieldViewMode)mode {
	_rightViewMode = mode;
	[self setNeedsLayout];
}

- (instancetype)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (!self)
		return nil;
	_placeholderLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_placeholderLabel.font = TGFontBody();
	_placeholderLabel.backgroundColor = [UIColor clearColor];
	_placeholderLabel.userInteractionEnabled = NO;
	[self addSubview:_placeholderLabel];
	_placeholderColour = [[TGTheme shared] secondaryTextColour];
	_placeholderLabel.textColor = _placeholderColour;
	return self;
}

- (void)setPlaceholder:(NSString *)placeholder {
	_placeholder = [placeholder copy];
	self.placeholderLabel.text = placeholder;
	[self setNeedsLayout];
}

- (void)setPlaceholderColour:(UIColor *)colour {
	_placeholderColour = colour;
	self.placeholderLabel.textColor = colour;
}

- (void)setEnabled:(BOOL)enabled {
	_enabled = enabled;
	self.editable = enabled;
	self.selectable = enabled;
	if (!enabled)
		[self resignFirstResponder];
}

- (void)layoutSubviews {
	[super layoutSubviews];
	UIEdgeInsets insets = UIEdgeInsetsZero;
	if ([self respondsToSelector:@selector(textContainerInset)])
		insets = self.textContainerInset;
	else
		insets = self.contentInset;
	CGFloat left = insets.left + TGMetricPadSmall;
	CGFloat width = MAX(0.0f, self.bounds.size.width - left - insets.right);
	CGFloat labelHeight = MAX(TGMetricLineBody, self.bounds.size.height -
			insets.top - insets.bottom);
	if (TGChatDrawableSize(CGSizeMake(width, labelHeight))) {
		self.placeholderLabel.frame = CGRectMake(left, insets.top,
				width, labelHeight);
		self.placeholderLabel.hidden = self.text.length > 0;
	} else {
		// A zero-width text host has no context to draw a label into. Keep it
		// hidden until the field has a real frame and layout runs again.
		self.placeholderLabel.hidden = YES;
	}
	BOOL editing = [self isFirstResponder];
	_rightView.hidden = (_rightViewMode == UITextFieldViewModeNever ||
			(_rightViewMode == UITextFieldViewModeUnlessEditing && editing) ||
			(_rightViewMode == UITextFieldViewModeWhileEditing && !editing));
	if (_rightView){
		CGFloat side = MIN(self.bounds.size.height - TGDoubled(TGMetricPadSmall),
				TGMetricRow);
		if (TGChatDrawableSize(CGSizeMake(side, side))) {
			_rightView.frame = CGRectMake(self.bounds.size.width - side -
					TGMetricPadSmall, TGHalf(self.bounds.size.height - side),
					side, side);
		}
	}
	if (_inLayout)
		return;
	_inLayout = YES;
	if (self.onLayout) {
		self.onLayout();
	}
	_inLayout = NO;
}

@end

@implementation TGChatViewController (Input)

- (void)buildInputBar:(CGRect)b {
	CGFloat scale = [UIScreen mainScreen].scale;

	self.inputBar = [[UIView alloc] initWithFrame:
			CGRectMake(0, b.size.height - kInputHeight, b.size.width, kInputHeight)];
	self.inputBar.backgroundColor = [[TGTheme shared] inputBarColour];
	self.inputBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;

	UIImageView *barBg = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, b.size.width, kInputHeight)];
	barBg.image = [TGTheme skeuomorphicInputBarImageWithHeight:kInputHeight];
	barBg.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.inputBar addSubview:barBg];

	UIView *hair = [[UIView alloc] initWithFrame:CGRectMake(0, 0, b.size.width,
			TGMetricBorderWidth)];
	hair.backgroundColor = [[TGTheme shared] separatorColour];
	hair.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.inputBar addSubview:hair];

	CGFloat fieldH = TGChatComposerFieldHeightForLines(1);
	CGRect sendFrame = TGChatComposerSendFrame(b.size.width, kInputHeight);
	CGRect fieldFrame = TGChatComposerFieldFrame(b.size.width, kInputHeight, fieldH);
	CGFloat sendY = CGRectGetMinY(sendFrame);

	UIButton *attach = [UIButton buttonWithType:UIButtonTypeCustom];
	attach.frame = CGRectMake(kComposerInset, sendY, kAttachWidth, kSendSide);
	[attach setImage:[TGIcons attach] forState:UIControlStateNormal];
	attach.tintColor = [[TGTheme shared] accentColour];
	[attach addTarget:self action:@selector(attachTapped)
			forControlEvents:UIControlEventTouchUpInside];
	[self.inputBar addSubview:attach];
	self.attachButton = attach;

	TGComposerInputField *field = [[TGComposerInputField alloc] initWithFrame:fieldFrame];
	field.backgroundColor = [UIColor clearColor];
	field.layer.borderWidth = 0.0f;
	field.layer.shouldRasterize = YES;
	field.layer.rasterizationScale = scale;
	field.textColor = [[TGTheme shared] primaryTextColour];
	field.font = TGFontBody();
	// Return is a line break now; Send is the button. Official's composer
	// uses a text view for the same reason.
	field.returnKeyType = UIReturnKeyDefault;
	field.delegate = (id<UITextViewDelegate>)self;
	field.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	field.clipsToBounds = YES;
	field.scrollEnabled = NO;
	field.showsVerticalScrollIndicator = NO;
	field.showsHorizontalScrollIndicator = NO;
	// iOS 6 has contentInset only; iOS 7+ has a text container. The vertical
	// inset is the 32 pt capsule's leftover around one 18 pt line.
	if ([field respondsToSelector:@selector(textContainerInset)]){
		// No right inset: the text view already ends where the sticker
		// toggle starts, and that button's own margin is the gap.
		field.textContainerInset = UIEdgeInsetsMake(TGMetricComposerFieldInsetV,
				kFieldLeftPad, TGMetricComposerFieldInsetV, TGMetricCornerNone);
		field.textContainer.lineFragmentPadding = 0.0f;
	} else {
		field.contentInset = UIEdgeInsetsMake(TGMetricComposerFieldInsetV,
				kFieldLeftPad, TGMetricComposerFieldInsetV, TGMetricCornerNone);
	}
	field.placeholderColour = [[TGTheme shared] secondaryTextColour];
	field.placeholder = TGLocalized(@"Message");
	__weak typeof(self) weakSelf = self;
	field.onLayout = ^{
		[weakSelf refreshComposerEmojiOverlay];
	};
	self.input = field;
	self.composerEmojiViews = [NSMutableArray array];
	self.composerText = [[TGComposerText alloc] initWithText:@"" entities:@[]];

	// The field's recessed plate. It is a sibling rather than a subview so it
	// does not scroll with the text once the field passes its line cap.
	self.composerWell = [[UIImageView alloc] initWithFrame:fieldFrame];
	self.composerWell.userInteractionEnabled = NO;
	self.composerWell.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.inputBar addSubview:self.composerWell];
	[self.inputBar addSubview:self.input];

	self.sendButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.sendButton.frame = sendFrame;
	[self.sendButton setBackgroundImage:[TGTheme buttonImageForStyle:TGButtonStyleAction highlighted:NO height:kSendSide] forState:UIControlStateNormal];
	[self.sendButton setBackgroundImage:[TGTheme buttonImageForStyle:TGButtonStyleAction highlighted:YES height:kSendSide] forState:UIControlStateHighlighted];
	self.sendButton.backgroundColor = [UIColor clearColor];
	self.sendButton.layer.shouldRasterize = YES;
	self.sendButton.layer.rasterizationScale = scale;
	[self.sendButton setImage:[TGIcons sendOnAccent] forState:UIControlStateNormal];
	self.sendButton.tintColor = [[TGTheme shared] onAccentColour];
	self.sendButton.imageEdgeInsets = UIEdgeInsetsZero;
	self.sendButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	[self.sendButton addTarget:self action:@selector(sendTapped)
			forControlEvents:UIControlEventTouchUpInside];
	// The tap sends; the hold is where sending waits: a date, the other
	// side's next appearance, or the queue already scheduled.
	UILongPressGestureRecognizer *sendHold = [[UILongPressGestureRecognizer alloc]
			initWithTarget:self action:@selector(sendHeld:)];
	sendHold.minimumPressDuration = 0.5;
	[self.sendButton addGestureRecognizer:sendHold];
	[self.inputBar addSubview:self.sendButton];

	// Official keeps a stickers/emoji toggle at the field's right edge
	// (ChatTextInputAccessoryItem .input, keyboard/stickers/emoji); ec1284a
	// retired it as "no extra glyph" and the panel lost its only button.
	self.stickerButton = [UIButton buttonWithType:UIButtonTypeCustom];
	[self.stickerButton setImage:[TGIcons sticker] forState:UIControlStateNormal];
	self.stickerButton.tintColor = [[TGTheme shared] secondaryTextColour];
	self.stickerButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	[self.stickerButton addTarget:self action:@selector(toggleStickerPanel)
			forControlEvents:UIControlEventTouchUpInside];
	[self.inputBar addSubview:self.stickerButton];

	// Hold to record, release to send - the gesture every client uses. It sits
	// where Send is and swaps with it depending on whether anything is typed.
	// The same button is the mode switch: a quick tap turns voice note
	// recording into a round video note and back, the way Telegram keeps two
	// modes on one spot instead of a second control beside the paperclip.
	self.micButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.micButton.frame = sendFrame;
	[self.micButton setImage:[TGIcons microphone] forState:UIControlStateNormal];
	self.micButton.tintColor = [[TGTheme shared] secondaryTextColour];
	self.micButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	[self.micButton addTarget:self action:@selector(recordTouchDown:withEvent:)
			 forControlEvents:UIControlEventTouchDown];
	[self.micButton addTarget:self action:@selector(recordTouchUp:withEvent:)
			 forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
	// A short tap is the mode switch; a hold is the recording. The two are
	// separated by the touch duration, not a second button.
	[self.micButton addTarget:self action:@selector(recordTouchCancel)
			 forControlEvents:UIControlEventTouchCancel];
	[self.micButton addTarget:self action:@selector(recordDrag:withEvent:)
			 forControlEvents:UIControlEventTouchDragInside | UIControlEventTouchDragOutside];
	[self.inputBar addSubview:self.micButton];

	// Official's AI entry is the top slot of the attachment capsule, faded in
	// once the typed text reaches three lines. Our capsule is one button tall,
	// so the same slot sits directly above the paperclip.
	self.aiButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.aiButton.frame = CGRectMake(kComposerInset, sendY - kSendSide,
			kAttachWidth, kSendSide);
	self.aiButton.hidden = YES;
	self.aiButton.alpha = TGAlphaTransparent;
	[self.aiButton setImage:[TGIcons glyphNamed:@"edit"
			colour:[[TGTheme shared] accentColour] side:TGMetricMenuGlyph]
			forState:UIControlStateNormal];
	self.aiButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
	[self.aiButton addTarget:self action:@selector(aiComposeTapped)
			forControlEvents:UIControlEventTouchUpInside];
	[self.inputBar addSubview:self.aiButton];

	self.videoNoteMode = [[NSUserDefaults standardUserDefaults]
			boolForKey:kRecordVideoModeKey];
	[self updateRecordModeIcon];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(composerCustomEmojiLoaded:)
												 name:TGCustomEmojiLoadedNotification
											   object:nil];

	self.composerBarHeight = kInputHeight;
	[self inputChanged];
	[self updateComposerPlaceholder];

	[self.view addSubview:self.inputBar];
	[self updateComposerHeightAnimated:NO];
}

/// Official picks the field's word from the chat kind: a channel broadcasts,
/// a group or a private chat sends a message.
- (void)updateComposerPlaceholder {
	self.input.placeholder = TGChatComposerPlaceholder(self.isChannel,
			self.silentPosting, self.canBeAnonymous);
}

/// The bar's own growth: the text view asks how many lines it has, the field
/// takes that height up to twelve lines, and the bar, its plate and the
/// table's bottom all move together. Past the cap the text view scrolls.
- (void)updateComposerHeightAnimated:(BOOL)animated {
	if (!self.input || !self.inputBar)
		return;
	CGFloat width = self.inputBar.bounds.size.width;
	if (width <= 0.0f)
		width = self.view.bounds.size.width;
	if (width <= 0.0f)
		return;

	CGFloat textWidth = MAX(1.0f, TGChatComposerFieldFrame(width,
			kInputHeight, TGChatComposerFieldHeightForLines(1)).size.width -
			kFieldLeftPad - kSendSide);
	NSString *text = self.input.text ?: @"";
	NSInteger lines = TGChatComposerLineCount(text, textWidth);
	CGFloat fieldH = TGChatComposerFieldHeightForLines(lines);
	CGFloat barH = TGChatComposerBarHeightForLines(lines);
	BOOL overflow = lines > TGChatComposerMaxLines();
	BOOL showAI = TGChatComposerShowsAIEntry(text, textWidth);
	CGRect fieldFrame = TGChatComposerFieldFrame(width, barH, fieldH);
	CGRect sendFrame = TGChatComposerSendFrame(width, barH);

	self.input.scrollEnabled = overflow;
	self.composerBarHeight = barH;
	// The corner stays the one-line capsule's as the field grows, as
	// official's input panel keeps it; half the grown height turned a
	// six-line field into an oval. The image is drawn at the one-line height
	// and stretched, leaving one stretchable row between the caps.
	CGFloat wellRadius = MAX(TGMetricCornerNone,
			TGHalf(TGMetricComposerFieldMinHeight) - TGMetricBorderWidth);
	if (TGChatDrawableSize(fieldFrame.size)) {
		self.composerWell.image = [TGTheme
				skeuomorphicWellImageWithHeight:TGMetricComposerFieldMinHeight
				cornerRadius:wellRadius];
	} else {
		self.composerWell.image = nil;
	}
	((TGComposerInputField *)self.input).placeholderColour =
			[[TGTheme shared] secondaryTextColour];

	CGFloat bottom = CGRectGetMaxY(self.inputBar.frame);
	if (bottom <= 0.0f || CGRectIsEmpty(self.inputBar.frame))
		bottom = self.view.bounds.size.height;
	CGFloat controlY = CGRectGetMinY(sendFrame);

	void (^apply)(void) = ^{
		self.inputBar.frame = CGRectMake(0, bottom - barH, width, barH);
		self.composerWell.frame = fieldFrame;
		// The text stops short of the sticker toggle sitting in the well.
		CGRect textFrame = fieldFrame;
		textFrame.size.width = MAX(0.0f, textFrame.size.width - kSendSide);
		self.input.frame = textFrame;
		self.stickerButton.frame = CGRectMake(CGRectGetMaxX(fieldFrame) - kSendSide,
				controlY, kSendSide, kSendSide);
		self.attachButton.frame = CGRectMake(kComposerInset, controlY,
				kAttachWidth, kSendSide);
		self.aiButton.frame = CGRectMake(kComposerInset, controlY - kSendSide,
				kAttachWidth, kSendSide);
		self.sendButton.frame = sendFrame;
		self.micButton.frame = sendFrame;
		self.table.frame = CGRectMake(0, 0, width, bottom - barH);
		[self layoutChrome];
	};

	BOOL changed = fabs(self.inputBar.bounds.size.height - barH) > 0.5f;
	if (animated && changed && self.view.window){
		[UIView animateWithDuration:TGAnimationDurationFast animations:apply
				completion:^(BOOL done){
			[self refreshComposerEmojiOverlay];
		}];
	} else {
		apply();
		[self refreshComposerEmojiOverlay];
	}

	if (showAI && self.aiButton.hidden){
		self.aiButton.hidden = NO;
		self.aiButton.alpha = TGAlphaTransparent;
		[UIView animateWithDuration:TGAnimationDurationFast animations:^{
			self.aiButton.alpha = TGAlphaOpaque;
		}];
	} else if (!showAI && !self.aiButton.hidden){
		[UIView animateWithDuration:TGAnimationDurationFast animations:^{
			self.aiButton.alpha = TGAlphaTransparent;
		} completion:^(BOOL finished){
			if (!TGChatComposerShowsAIEntry(self.input.text ?: @"", textWidth))
				self.aiButton.hidden = YES;
		}];
	} else if (showAI){
		self.aiButton.alpha = TGAlphaOpaque;
	}
	((TGComposerInputField *)self.input).placeholderLabel.hidden = text.length > 0;
}

/// The composer's AI button, where official shows it once the text is long
/// enough: the existing AI composer opens with what has been typed.
- (void)aiComposeTapped {
	TGAiComposeViewController *vc = [[TGAiComposeViewController alloc] init];
	vc.chatId = self.chatId;
	vc.chatTitle = self.chatTitle;
	vc.initialText = self.input.text ?: @"";
	__weak typeof(self) weakSelf = self;
	// Official's edit mode applies the result to the composer; it does not
	// send it. The user still presses Send themselves.
	vc.onApply = ^(NSString *text){
		[weakSelf applyComposerText:text];
	};
	vc.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:vc animated:YES];
}

/// Puts the AI screen's result where the composer's text was, keeping the
/// custom-emoji model in step and growing the bar for the new line count.
- (void)applyComposerText:(NSString *)text {
	NSString *body = text ?: @"";
	self.input.text = body;
	self.composerText = [[TGComposerText alloc] initWithText:body entities:@[]];
	[self updateComposerHeightAnimated:NO];
	[self inputChanged];
	[self composerEditingChanged];
	[self refreshComposerEmojiOverlay];
}

/// The first thing in `text` that could be a link. Not a validator - TDLib
/// decides what has a preview - just enough of a trigger to stop asking on
/// every keystroke of an ordinary sentence.
static NSString *TGFirstLinkIn(NSString *text) {
	for (NSString *word in [text componentsSeparatedByCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]]){
		if (word.length < 4)
			continue;
		if ([word rangeOfString:@"://"].location != NSNotFound)
			return word;
		// A bare domain needs a dot with something either side of it.
		NSRange dot = [word rangeOfString:@"."];
		if (dot.location != NSNotFound && dot.location > 0 &&
			dot.location + 1 < word.length &&
			[word rangeOfString:@"@"].location == NSNotFound)
			return word;
	}
	return nil;
}

/// What their composer shows once a link is typed: the site and the title
/// Telegram found, so the card that will be attached is not a surprise.
/// Nothing is asked until the typing stops, and never while the banner is
/// already carrying a reply or an edit.
- (void)refreshLinkPreview {
	if (self.replyToId != 0 || self.editingId != 0)
		return;

	NSString *link = TGFirstLinkIn(self.input.text ?: @"");
	if (!link.length){
		if (self.previewedLink.length){
			self.previewedLink = nil;
			[self hideComposeBannerAnimated];
		}
		return;
	}
	// The X closed this preview; do not ask for it again until the link
	// changes.
	if ([link isEqualToString:self.suppressedPreviewLink])
		return;
	if (self.suppressedPreviewLink.length &&
			![link isEqualToString:self.suppressedPreviewLink])
		self.suppressedPreviewLink = nil;
	if ([link isEqualToString:self.previewedLink])
		return;          // already asked about this one
	self.previewedLink = link;
	// A preview that takes a round trip says it is coming instead of leaving
	// the strip blank until the answer lands.
	[self showComposeBanner:link subtitle:TGLocalized(@"Loading...")];

	__weak typeof(self) weakSelf = self;
	[[TGMessageStore shared] linkPreviewForText:self.input.text
							   completion:^(NSDictionary *preview){
		TGChatViewController *me = weakSelf;
		if (!me || ![TGFirstLinkIn(me.input.text ?: @"") isEqualToString:link])
			return;      // the text moved on while the answer was in flight
		if (!preview){
			[me hideComposeBannerAnimated];
			return;
		}
		NSString *title = [preview[@"title"] length] ? preview[@"title"]
				: ([preview[@"site"] length] ? preview[@"site"] : link);
		NSString *detail = [preview[@"description"] length]
				? preview[@"description"] : preview[@"url"];
		[me showComposeBanner:title subtitle:detail];
	}];
}

/// "typing..." on the other side. TDLib lets one of these stand for a few
/// seconds, so one per four is enough to keep it up while typing goes on -
/// and sending one per keystroke on this radio would be its own problem.
- (void)reportTyping {
	if (!self.input.text.length){
		self.lastTypingReport = 0;
		return;
	}
	NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
	if (now - self.lastTypingReport < 4.0)
		return;
	self.lastTypingReport = now;
	[[TGMessageStore shared] sendTypingToChat:self.chatId thread:self.threadId];
}

#pragma mark - compose banner

/// Back to composing a plain message: no reply, no edit, no banner. Also
/// missing, and reached from the recorder and from the banner's own cancel.
- (void)clearComposeState {
	self.replyToId = 0;
	self.editingId = 0;
	self.editingIsCaption = NO;
	self.previewedLink = nil;
	self.suppressedPreviewLink = nil;
	[self hideComposeBannerAnimated];
	[self inputChanged];
	[self refreshComposerEmojiOverlay];
}

/// The strip drops back behind the composer instead of blinking out. A banner
/// shown again while this slide runs has a newer generation and must stay.
- (void)hideComposeBannerAnimated {
	UIView *banner = self.composeBanner;
	if (!banner || banner.hidden){
		[self layoutChrome];
		return;
	}
	NSUInteger shown = self.composeBannerShows;
	__weak typeof(self) weakSelf = self;
	[UIView animateWithDuration:TGAnimationDurationFast animations:^{
		banner.transform = CGAffineTransformMakeTranslation(0, kComposeBannerHeight);
		banner.alpha = TGAlphaTransparent;
	} completion:^(BOOL finished){
		TGChatViewController *me = weakSelf;
		if (!me || me.composeBanner != banner || me.composeBannerShows != shown)
			return;
		banner.hidden = YES;
		banner.transform = CGAffineTransformIdentity;
		banner.alpha = TGAlphaOpaque;
		// The space the strip held is only given back once it is gone.
		[me layoutChrome];
	}];
}

/// A strip above the composer saying what the next message will be: a reply,
/// an edit, or a recording in progress. Declared and used from three places
/// but never written, so holding the microphone brought the app down.
- (void)showComposeBanner:(NSString *)text {
	[self showComposeBanner:text subtitle:nil];
}

static const NSInteger kBannerTitleTag    = 71;
static const NSInteger kBannerSubtitleTag = 72;

/// Their layout: an accent stripe, who is being answered on the first line and
/// what they said on the second. `subtitle` nil keeps the one-line form the
/// recorder and the editor use.
- (void)showComposeBanner:(NSString *)text subtitle:(NSString *)subtitle {
	CGFloat width = self.view.bounds.size.width;
	if (!self.composeBanner){
		self.composeBanner = [[UIView alloc] initWithFrame:
				CGRectMake(0, CGRectGetMinY(self.inputBar.frame) - kComposeBannerHeight,
						   width, kComposeBannerHeight)];
		self.composeBanner.backgroundColor = [[TGTheme shared] inputBarColour];
		// Born hidden so the first show goes through the same slide-in as
		// every later one.
		self.composeBanner.hidden = YES;
		self.composeBanner.autoresizingMask = UIViewAutoresizingFlexibleWidth |
											  UIViewAutoresizingFlexibleTopMargin;

		UIView *stripe = [[UIView alloc] initWithFrame:CGRectMake(kBannerStripeX,
				kBannerStripeTop, kQuoteBarWidth,
				kComposeBannerHeight - TGDoubled(kBannerStripeTop))];
		stripe.backgroundColor = [[TGTheme shared] accentColour];
		[self.composeBanner addSubview:stripe];

		UILabel *title = [[UILabel alloc] initWithFrame:
				CGRectMake(kBannerTextX, kBannerTitleTop,
						width - TGMetricComposeBannerTextMarginRight, TGMetricLineSubhead)];
		title.tag = kBannerTitleTag;
		title.font = TGFontCaptionStrong();
		title.textColor = [[TGTheme shared] accentColour];
		title.backgroundColor = [UIColor clearColor];
		title.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[self.composeBanner addSubview:title];

		UILabel *preview = [[UILabel alloc] initWithFrame:
				CGRectMake(kBannerTextX, kBannerTitleTop + TGMetricLineSubhead,
						width - TGMetricComposeBannerTextMarginRight, TGMetricLineSubhead)];
		preview.tag = kBannerSubtitleTag;
		preview.font = TGFontCaption();
		preview.textColor = [[TGTheme shared] secondaryTextColour];
		preview.backgroundColor = [UIColor clearColor];
		preview.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[self.composeBanner addSubview:preview];

		UIButton *cancel = [UIButton buttonWithType:UIButtonTypeCustom];
		cancel.frame = CGRectMake(width - TGMetricRow, 0, TGMetricRow, kComposeBannerHeight);
		cancel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		[cancel setImage:[TGIcons glyphNamed:@"close"
									  colour:[[TGTheme shared] secondaryTextColour]
										side:kBannerCloseGlyph]
				forState:UIControlStateNormal];
		[cancel addTarget:self action:@selector(dismissPreviewOrCompose)
		 forControlEvents:UIControlEventTouchUpInside];
		[self.composeBanner addSubview:cancel];

		[self.view insertSubview:self.composeBanner belowSubview:self.inputBar];
	}

	UILabel *title   = (UILabel *)[self.composeBanner viewWithTag:kBannerTitleTag];
	UILabel *preview = (UILabel *)[self.composeBanner viewWithTag:kBannerSubtitleTag];
	title.text   = text;
	preview.text = subtitle ?: @"";
	// One line centres itself; two share the strip.
	CGFloat half = TGHalf(kComposeBannerHeight);
	title.frame = CGRectMake(kBannerTextX,
							 subtitle.length ? kBannerTitleTop
											  : half - TGHalf(TGMetricLineSubhead),
							 self.composeBanner.bounds.size.width - TGMetricComposeBannerTextMarginRight,
							 TGMetricLineSubhead);

	BOOL wasHidden = self.composeBanner.hidden;
	BOOL reveal = wasHidden || self.composeBanner.alpha < TGAlphaOpaque;
	self.composeBanner.hidden = NO;
	self.composeBannerShows++;
	[self layoutChrome];
	[self refreshComposerEmojiOverlay];
	// Slide up from behind the composer. The strip sits below the bar in the
	// view order, so a downward translation hides it fully while it travels.
	// The frame is placed first, while it is untransformed.
	if (reveal){
		if (wasHidden){
			self.composeBanner.transform = CGAffineTransformMakeTranslation(0, kComposeBannerHeight);
			self.composeBanner.alpha = TGAlphaTransparent;
		}
		[UIView animateWithDuration:TGAnimationDurationFast animations:^{
			self.composeBanner.transform = CGAffineTransformIdentity;
			self.composeBanner.alpha = TGAlphaOpaque;
		}];
	}
}

#pragma mark - sending

static NSRange TGTextFieldSelectedRange(UITextView *tf) {
	UITextRange *r = tf.selectedTextRange;
	if (!r) return NSMakeRange(NSNotFound, 0);
	NSInteger start = [tf offsetFromPosition:tf.beginningOfDocument toPosition:r.start];
	NSInteger end = [tf offsetFromPosition:tf.beginningOfDocument toPosition:r.end];
	return NSMakeRange(start, end - start);
}

static void TGTextFieldSetSelectedRange(UITextView *tf, NSRange range) {
	if (range.location == NSNotFound) return;
	UITextPosition *start = [tf positionFromPosition:tf.beginningOfDocument offset:range.location];
	UITextPosition *end = [tf positionFromPosition:start offset:range.length];
	if (start && end) {
		tf.selectedTextRange = [tf textRangeFromPosition:start toPosition:end];
	}
}

- (void)insertCustomEmoji:(int64_t)emojiId fallback:(NSString *)fallback {
	if (!fallback.length)
		return;
	if (!self.composerText) {
		self.composerText = [[TGComposerText alloc] initWithText:self.input.text ?: @"" entities:@[]];
	} else if (![self.composerText.text isEqualToString:self.input.text ?: @""]) {
		[self.composerText resetText:self.input.text ?: @""];
	}
	NSString *text = self.input.text ?: @"";
	NSRange r = TGTextFieldSelectedRange(self.input);
	NSUInteger index = (r.location != NSNotFound && r.location <= text.length) ? r.location : text.length;
	NSUInteger replaceLen = (r.location != NSNotFound && r.location + r.length <= text.length) ? r.length : 0;
	if (replaceLen > 0) {
		[self.composerText replaceCharactersInRange:NSMakeRange(index, replaceLen) withString:@""];
		text = [text stringByReplacingCharactersInRange:NSMakeRange(index, replaceLen) withString:@""];
	}
	[self.composerText insertCustomEmoji:emojiId fallback:fallback atIndex:index];
	self.input.text = [text stringByReplacingCharactersInRange:NSMakeRange(index, 0) withString:fallback];
	TGTextFieldSetSelectedRange(self.input, NSMakeRange(index + fallback.length, 0));
	[self inputChanged];
	[self refreshComposerEmojiOverlay];
}

- (void)sendTapped {
	NSString *text = [self.input.text stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!text.length)
		return;

	if (self.editingId != 0 && self.editingIsCaption){
		__weak typeof(self) weakSelf = self;
		[[TGMessageStore shared] editCaption:text
							 ofMessage:self.editingId
								inChat:self.chatId
							completion:^(BOOL ok){
			if (!ok)
				[TGSnackbar showInView:weakSelf.view
								  text:@"An error occurred."
							   seconds:2 onCommit:nil];
		}];
		self.editingIsCaption = NO;
	} else {
		if (!self.composerText) {
			self.composerText = [[TGComposerText alloc] initWithText:self.input.text ?: @"" entities:@[]];
		} else if (![self.composerText.text isEqualToString:self.input.text ?: @""]) {
			[self.composerText resetText:self.input.text ?: @""];
		}
		NSDictionary *ft = [[TGMessageStore shared] markdownParsed:[self.composerText formattedText]];
		if (self.editingId != 0) {
			[[TGSendStore shared] editMessageText:self.editingId
										   inChat:self.chatId
									formattedText:ft];
		} else {
			[[TGSendStore shared] sendFormattedText:ft
											toChat:self.chatId
											thread:self.threadId
										   replyTo:self.replyToId
								   schedulingState:nil];
		}
	}

	// Before clearComposeState, so inputChanged sees an empty field and puts
	// the microphone back in the send button's place.
	self.input.text = @"";
	self.composerText = [[TGComposerText alloc] initWithText:@"" entities:@[]];
	[self clearComposeState];
	// The draft was this text; it has been sent, so it is not a draft now.
	[[TGMessageStore shared] setDraft:@"" inChat:self.chatId thread:self.threadId replyTo:0];
	[[TGMessageStore shared] cancelTypingInChat:self.chatId thread:self.threadId];

	// TDLib echoes the message back as an update; refresh shortly after.
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
			dispatch_get_main_queue(), ^{
		[self reload];
	});
}

#pragma mark - sending later

- (void)showFormattingSheet {
	__weak typeof(self) weakSelf = self;
	NSArray *styles = @[@"Bold", @"Italic", @"Code", @"Spoiler", @"Strikethrough"];
	[TGAlertSheet showChoices:styles title:@"Format" destructiveIndex:-1
					   inView:self.navigationController.view ?: self.view
					 onChoice:^(NSInteger index){
		[weakSelf applyFormattingStyle:index];
	}];
}

- (void)applyFormattingStyle:(NSInteger)style {
	NSRange r = TGTextFieldSelectedRange(self.input);
	NSString *text = self.input.text ?: @"";
	NSString *prefix = @"";
	NSString *suffix = @"";
	switch (style){
		case 0: prefix = @"**"; suffix = @"**"; break;
		case 1: prefix = @"*";  suffix = @"*"; break;
		case 2: prefix = @"`";  suffix = @"`"; break;
		case 3: prefix = @"||"; suffix = @"||"; break;
		case 4: prefix = @"~";  suffix = @"~"; break;
		default: break;
	}
	if (r.location != NSNotFound && r.length > 0 && r.location + r.length <= text.length){
		NSString *selected = [text substringWithRange:r];
		NSString *formatted = [NSString stringWithFormat:@"%@%@%@", prefix, selected, suffix];
		self.input.text = [text stringByReplacingCharactersInRange:r withString:formatted];
		TGTextFieldSetSelectedRange(self.input, NSMakeRange(r.location + prefix.length, selected.length));
	} else {
		if (text.length > 0){
			self.input.text = [NSString stringWithFormat:@"%@%@%@", prefix, text, suffix];
		} else {
			self.input.text = [NSString stringWithFormat:@"%@%@", prefix, suffix];
			TGTextFieldSetSelectedRange(self.input, NSMakeRange(prefix.length, 0));
		}
	}
	[self.composerText resetText:self.input.text ?: @""];
	[self inputChanged];
	[self refreshComposerEmojiOverlay];
}

/// Holding Send when there is text offers what a send can wait for. With an
/// empty field there is nothing to wait with, and the hold says nothing.
- (void)sendHeld:(UILongPressGestureRecognizer *)hold {
	if (hold.state != UIGestureRecognizerStateBegan)
		return;
	NSString *text = [self.input.text stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!text.length){
		// With nothing typed the hold opens the queue, which is where the
		// scheduled messages live; the list is not a row in the send sheet.
		[self openScheduledMessages];
		return;
	}
	if (self.editingId != 0)
		return;

	__weak typeof(self) weakSelf = self;
	NSArray *choices = @[
		@"Format",
		@"Create with AI",
		@"Schedule Message",
		@"Send When Online",
		@"Preview"
	];
	[TGAlertSheet showChoices:choices
						title:nil
			 destructiveIndex:-1
					   inView:self.navigationController.view ?: self.view
					 onChoice:^(NSInteger index){
		if (index == 0)
			[weakSelf showFormattingSheet];
		else if (index == 1){
			TGAiComposeViewController *vc = [[TGAiComposeViewController alloc] init];
			vc.chatId = weakSelf.chatId;
			vc.chatTitle = weakSelf.chatTitle;
			vc.initialText = weakSelf.input.text ?: @"";
			vc.onApply = ^(NSString *text){
				[weakSelf applyComposerText:text];
			};
			vc.hidesBottomBarWhenPushed = YES;
			[weakSelf.navigationController pushViewController:vc animated:YES];
		} else if (index == 2)
			[weakSelf holdScheduledSheet];
		else if (index == 3)
			[weakSelf sendHeldText:[TGMessageStore scheduledWhenOnline]];
		else
			[weakSelf previewFormattingOfText:text];
	}];
}

- (void)openScheduledMessages {
	TGScheduledViewController *vc = [[TGScheduledViewController alloc] init];
	vc.chatId = self.chatId;
	vc.chatTitle = self.chatTitle;
	[self.navigationController pushViewController:vc animated:YES];
}

/// What the message will look like once Telegram reads the markup. The
/// parser and the entity scanner are both TDLib's, so the preview is the
/// same answer the send path gets rather than a second grammar.
- (void)previewFormattingOfText:(NSString *)text {
	__weak typeof(self) weakSelf = self;
	[[TGMessageStore shared] parseMarkdownText:text completion:^(NSDictionary *formatted){
		[[TGMessageStore shared] textEntitiesInText:text completion:^(NSArray *entities){
			TGChatViewController *me = weakSelf;
			if (!me)
				return;
			NSMutableString *body = [NSMutableString stringWithString:
					formatted[@"text"] ?: text];
			[TGAlertSheet showMessage:body
							   title:@"Preview"
							   inView:me.view];
		}];
	}];
}


/// The composer's text, sent into whatever state was picked. The draft is
/// lost with the field, which is the whole point: it is no longer waiting
/// here to be sent.
- (void)sendHeldText:(NSDictionary *)state {
	NSString *text = [self.input.text stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!text.length)
		return;
	[[TGSendStore shared] sendText:text toChat:self.chatId
							thread:self.threadId replyTo:self.replyToId
					schedulingState:state];
	self.input.text = @"";
	self.composerText = [[TGComposerText alloc] initWithText:@"" entities:@[]];
	[self clearComposeState];
	[[TGMessageStore shared] setDraft:@"" inChat:self.chatId thread:self.threadId replyTo:0];
	[[TGMessageStore shared] cancelTypingInChat:self.chatId thread:self.threadId];
}

/// The X on the compose strip. A link preview is its own thing: closing it
/// must not clear a reply or an edit, and must not fetch the same link again.
- (void)dismissPreviewOrCompose {
	if (self.replyToId == 0 && self.editingId == 0 && self.previewedLink.length){
		self.suppressedPreviewLink = self.previewedLink;
		self.previewedLink = nil;
		[self hideComposeBannerAnimated];
		return;
	}
	[self clearComposeState];
}

/// The date the composer's text waits for. Done reads the picker, clears
/// the field and sends the held-back send in one move.
- (void)holdScheduledSheet {
	static const CGFloat kBar = TGMetricRow, kPicker = TGMetricPickerHeight;

	TGSheet *sheet = [TGSheet sheetForView:self.view.window ?: self.view];
	UIView *card = [sheet addCardOfHeight:kBar + kPicker + kBar edgeToEdge:YES];

	UIDatePicker *picker = [[UIDatePicker alloc] initWithFrame:
			CGRectMake(0, kBar, card.bounds.size.width, kPicker)];
	picker.datePickerMode = UIDatePickerModeDateAndTime;
	picker.minimumDate = [NSDate dateWithTimeIntervalSinceNow:60];
	picker.minuteInterval = 15;
	picker.date = [NSDate dateWithTimeIntervalSinceNow:60 * 60];
	[picker addTarget:self action:@selector(schedulePickerChanged:)
	 forControlEvents:UIControlEventValueChanged];
	[card addSubview:picker];

	UIToolbar *bar = [[UIToolbar alloc] initWithFrame:
			CGRectMake(0, 0, card.bounds.size.width, kBar)];
	bar.items = @[
		[[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain
				target:sheet action:@selector(dismiss)],
		[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
				target:nil action:nil],
	];
	[card addSubview:bar];

	// The primary button says what the chosen date will do, with Send When
	// Online as its own choice below.
	self.schedulePrimaryButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.schedulePrimaryButton.frame = CGRectMake(0, kBar + kPicker,
			card.bounds.size.width, TGHalf(kBar));
	self.schedulePrimaryButton.titleLabel.font = TGFontCaptionStrong();
	[self.schedulePrimaryButton setTitleColor:[[TGTheme shared] accentColour]
									 forState:UIControlStateNormal];
	[self.schedulePrimaryButton addTarget:self action:@selector(scheduleCommit:)
						 forControlEvents:UIControlEventTouchUpInside];
	[card addSubview:self.schedulePrimaryButton];

	UIButton *online = [UIButton buttonWithType:UIButtonTypeCustom];
	online.frame = CGRectMake(0, kBar + kPicker + TGHalf(kBar),
			card.bounds.size.width, TGHalf(kBar));
	online.titleLabel.font = TGFontCaption();
	[online setTitle:@"Send When Online" forState:UIControlStateNormal];
	[online setTitleColor:[[TGTheme shared] accentColour] forState:UIControlStateNormal];
	[online addTarget:self action:@selector(scheduleWhenOnline:)
	 forControlEvents:UIControlEventTouchUpInside];
	[card addSubview:online];

	self.pickPicker = picker;
	self.pickSheet = sheet;
	[self schedulePickerChanged:picker];
	[sheet present];
}

- (void)schedulePickerChanged:(UIDatePicker *)picker {
	NSDate *date = picker.date ?: [NSDate date];
	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDateFormatter *clock = [[NSDateFormatter alloc] init];
	clock.timeStyle = NSDateFormatterShortStyle;
	clock.dateStyle = NSDateFormatterNoStyle;
	NSString *time = [clock stringFromDate:date];
	NSDateComponents *day = [calendar components:NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit
										fromDate:date];
	NSDateComponents *today = [calendar components:NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit
										  fromDate:[NSDate date]];
	NSDate *dayStart = [calendar dateFromComponents:day];
	NSDate *todayStart = [calendar dateFromComponents:today];
	NSInteger days = (NSInteger)lround([dayStart timeIntervalSinceDate:todayStart] / 86400.0);
	NSString *title = nil;
	if (days <= 0)
		title = TGLocalizedFormat(@"Send today at %@", time);
	else if (days == 1)
		title = TGLocalizedFormat(@"Send tomorrow at %@", time);
	else {
		NSDateFormatter *medium = [[NSDateFormatter alloc] init];
		medium.dateStyle = NSDateFormatterMediumStyle;
		medium.timeStyle = NSDateFormatterNoStyle;
		title = TGLocalizedFormat(@"Send on %@ at %@", [medium stringFromDate:date], time);
	}
	[self.schedulePrimaryButton setTitle:title forState:UIControlStateNormal];
}

- (void)scheduleWhenOnline:(UIButton *)sender {
	[self.pickSheet dismiss];
	self.pickSheet = nil;
	self.pickPicker = nil;
	self.schedulePrimaryButton = nil;
	[self sendHeldText:[TGMessageStore scheduledWhenOnline]];
	self.scheduledCount++;
	[self openScheduledMessages];
}

/// The bar's Done. The picker outlives the sheet just long enough to be
/// read: the date is taken first, the sheet dismissed after.
- (void)scheduleCommit:(UIBarButtonItem *)sender {
	NSTimeInterval date = [self.pickPicker.date timeIntervalSince1970];
	[self.pickSheet dismiss];
	self.pickSheet = nil;
	self.pickPicker = nil;
	self.schedulePrimaryButton = nil;
	[self sendHeldText:[TGMessageStore scheduledAtDate:date]];
	// The queue has one more in it than the menu last said.
	self.scheduledCount++;
	// Official lands the user on the queue so the result is visible.
	[self openScheduledMessages];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range
		replacementText:(NSString *)string {
	if (textView == self.input) {
		if (!self.composerText) {
			self.composerText = [[TGComposerText alloc] initWithText:self.input.text ?: @"" entities:@[]];
		} else if (![self.composerText.text isEqualToString:self.input.text ?: @""]) {
			[self.composerText resetText:self.input.text ?: @""];
		}
		[self.composerText replaceCharactersInRange:range withString:string];
	}
	// Return is a line break; sending is the button, as official's composer.
	return YES;
}

- (void)textViewDidChange:(UITextView *)textView {
	if (textView != self.input)
		return;
	[self updateComposerHeightAnimated:YES];
	[self inputChanged];
	[self composerEditingChanged];
}


#pragma mark - emoji, stickers, GIFs

- (BOOL)stickerPanelShown {
	// A panel on its way down no longer owns the spot; the tap has to be able
	// to bring it back instead of being read as "already open".
	return self.stickerPanel && !self.stickerPanel.hidden &&
		   CGAffineTransformIsIdentity(self.stickerPanel.transform);
}

- (void)hideStickerPanel {
	if (![self stickerPanelShown])
		return;
	TGEmojiPanel *panel = self.stickerPanel;
	CGFloat height = panel.bounds.size.height;
	NSUInteger shown = self.stickerPanelShows;
	__weak typeof(self) weakSelf = self;
	[UIView animateWithDuration:TGAnimationDurationMedium animations:^{
		panel.transform = CGAffineTransformMakeTranslation(0, height);
	} completion:^(BOOL finished){
		TGChatViewController *me = weakSelf;
		// Reopened while sliding: the panel stays up, with a new generation.
		if (!me || me.stickerPanel != panel || me.stickerPanelShows != shown)
			return;
		panel.hidden = YES;
		panel.transform = CGAffineTransformIdentity;
	}];
	// The keyboard may be on its way up in place of the panel; it moves the
	// bar itself then.
	if (![self.input isFirstResponder])
		[self shiftForKeyboardHeight:0];
}

/// The panel takes the keyboard's place - same height, same spot - and the
/// chat moves up for it the way it does for the keyboard.
- (void)toggleStickerPanel {
	if ([self stickerPanelShown]){
		// Back to the keyboard; its arrival puts the panel away.
		[self.input becomeFirstResponder];
		return;
	}

	CGRect b = self.view.bounds;
	CGFloat height = [TGEmojiPanel preferredHeight];
	if (!self.stickerPanel){
		TGEmojiPanel *panel = [[TGEmojiPanel alloc] initWithFrame:
				CGRectMake(0, b.size.height, b.size.width, height)];
		panel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
		// Born off screen so the first tap gets the same slide as every later
		// one instead of the panel appearing in place.
		panel.hidden = YES;
		panel.delegate = self;
		panel.chatId = self.chatId;
		[self.view addSubview:panel];
		self.stickerPanel = panel;
	}

	if ([self.input isFirstResponder])
		[self.input resignFirstResponder];
	[self hideBotKeyboard];

	BOOL wasHidden = self.stickerPanel.hidden;
	if (wasHidden){
		// Place the frame before the transform: frame means nothing on a
		// view that is already mid-slide.
		self.stickerPanel.frame = CGRectMake(0, b.size.height - height, b.size.width, height);
		self.stickerPanel.transform = CGAffineTransformMakeTranslation(0, height);
	}
	self.stickerPanel.hidden = NO;
	self.stickerPanelShows++;
	[self.view bringSubviewToFront:self.stickerPanel];
	// Transform only: the panel is full width, so moving its frame would
	// redraw the keyboard-sized surface on every step on an A4.
	[UIView animateWithDuration:TGAnimationDurationMedium animations:^{
		self.stickerPanel.transform = CGAffineTransformIdentity;
	}];
	[self shiftForKeyboardHeight:height];
}

/// itglegacy://stickers/<emoji|stickers|gifs> - open the panel on a given tab,
/// which is the only way a URL can reach a tab a finger would tap.
- (void)openStickerPanelTab:(NSString *)name {
	if (![self stickerPanelShown])
		[self toggleStickerPanel];
	TGEmojiPanelTab tab = TGEmojiPanelTabEmoji;
	if ([name isEqualToString:@"stickers"])
		tab = TGEmojiPanelTabStickers;
	else if ([name isEqualToString:@"gifs"])
		tab = TGEmojiPanelTabGIFs;
	[self.stickerPanel selectTab:tab];
}

- (void)emojiPanel:(TGEmojiPanel *)panel didPickEmoji:(NSString *)emoji {
	self.input.text = [(self.input.text ?: @"") stringByAppendingString:emoji];
	[self.composerText resetText:self.input.text ?: @""];
	[self inputChanged];
	[self refreshComposerEmojiOverlay];
}

- (void)emojiPanel:(TGEmojiPanel *)panel didPickCustomEmoji:(int64_t)emojiId fallback:(NSString *)emoji {
	[self insertCustomEmoji:emojiId fallback:emoji];
}

- (void)emojiPanelDidBackspace:(TGEmojiPanel *)panel {
	NSString *text = self.input.text ?: @"";
	if (!text.length)
		return;
	// One emoji is several UTF-16 units, and a flag is two emoji-sized ones;
	// delete what the eye sees as one character.
	NSRange last = [text rangeOfComposedCharacterSequenceAtIndex:text.length - 1];
	self.input.text = [text substringToIndex:last.location];
	[self.composerText resetText:self.input.text ?: @""];
	[self inputChanged];
	[self refreshComposerEmojiOverlay];
}

- (void)emojiPanel:(TGEmojiPanel *)panel didPickSticker:(NSDictionary *)sticker {
	NSInteger fileId = [sticker[@"fileId"] integerValue];
	if (fileId <= 0)
		return;
	[[TGSendStore shared] sendStickerWithFileId:fileId toChat:self.chatId thread:self.threadId];
}

- (void)emojiPanel:(TGEmojiPanel *)panel didPickAnimation:(NSDictionary *)animation {
	[[TGSendStore shared] sendAnimation:animation toChat:self.chatId thread:self.threadId];
}

#pragma mark - attachments

/// The camera tile of the attach sheet. The shot comes back through the same
/// delegate as a library pick, so it is sent by the code that sends those.
/// A device with no camera gets the library instead of nothing.
- (void)pickCamera {
	if (![UIImagePickerController isSourceTypeAvailable:
			UIImagePickerControllerSourceTypeCamera]){
		[self pickMedia];
		return;
	}
	UIImagePickerController *picker = [[UIImagePickerController alloc] init];
	picker.sourceType = UIImagePickerControllerSourceTypeCamera;
	// Without the movie type the camera takes stills only.
	picker.mediaTypes = @[(NSString *)kUTTypeImage, (NSString *)kUTTypeMovie];
	picker.delegate = (id<UIImagePickerControllerDelegate, UINavigationControllerDelegate>)self;
	[self presentViewController:picker animated:YES completion:nil];
}

- (void)attachTapped {
	[self.input resignFirstResponder];
	[self hideStickerPanel];
	UIView *host = self.navigationController.view ?: self.view;
	TGAttachSheet *sheet = [TGAttachSheet showInView:host];
	__weak typeof(self) weakSelf = self;
	sheet.onPhoto = ^(UIImage *image){
		[weakSelf confirmSendingImage:image];
	};
	sheet.onPhotos = ^(NSArray *images){
		[weakSelf sendImageAlbum:images];
	};
	sheet.onChoice = ^(TGAttachChoice choice){
		switch (choice){
			case TGAttachChoiceGallery:  [weakSelf pickMedia]; break;
			case TGAttachChoiceCamera:   [weakSelf pickCamera]; break;
			case TGAttachChoiceLocation: [weakSelf sendCurrentLocation]; break;
			case TGAttachChoiceContact:  [weakSelf pickContact]; break;
			case TGAttachChoiceChecklist: {
				TGChecklistViewController *checklist = [[TGChecklistViewController alloc]
						initWithChatId:weakSelf.chatId messageId:0 title:@"Checklist"];
				checklist.hidesBottomBarWhenPushed = YES;
				[weakSelf.navigationController pushViewController:checklist animated:YES];
				break;
			}
			case TGAttachChoiceQuickReply: {
				TGQuickRepliesViewController *replies =
						[[TGQuickRepliesViewController alloc] init];
				replies.sendChatId = weakSelf.chatId;
				replies.hidesBottomBarWhenPushed = YES;
				[weakSelf.navigationController pushViewController:replies animated:YES];
				break;
			}
			case TGAttachChoiceDice: {
				TGDiceViewController *dice = [[TGDiceViewController alloc] init];
				dice.chatId = weakSelf.chatId;
				dice.chatTitle = weakSelf.chatTitle;
				dice.hidesBottomBarWhenPushed = YES;
				[weakSelf.navigationController pushViewController:dice animated:YES];
				break;
			}
			case TGAttachChoiceEphemeral: {
				TGEphemeralViewController *ephemeral =
						[[TGEphemeralViewController alloc] init];
				ephemeral.chatId = weakSelf.chatId;
				ephemeral.chatTitle = weakSelf.chatTitle;
				ephemeral.hidesBottomBarWhenPushed = YES;
				[weakSelf.navigationController pushViewController:ephemeral
														animated:YES];
				break;
			}
		}
	};
}


#pragma mark - keyboard

- (void)keyboardWillShow:(NSNotification *)note {
	if ([self stickerPanelShown])
		[self hideStickerPanel];
	[self hideBotKeyboard];
	CGRect kb = [[note.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
	[self shiftForKeyboardHeight:kb.size.height];
}

- (void)keyboardWillHide:(NSNotification *)note {
	// Going down because the panel is coming up: the panel moves the bar.
	if ([self stickerPanelShown])
		return;
	[self shiftForKeyboardHeight:0];
}

- (void)shiftForKeyboardHeight:(CGFloat)height {
	CGRect b = self.view.bounds;
	CGFloat barH = self.composerBarHeight > 0.0f
			? self.composerBarHeight : kInputHeight;
	[UIView animateWithDuration:TGAnimationDurationMedium animations:^{
		self.inputBar.frame = CGRectMake(0, b.size.height - barH - height,
				b.size.width, barH);
		self.table.frame = CGRectMake(0, 0, b.size.width,
				b.size.height - barH - height);
		[self layoutChrome];
	} completion:^(BOOL done){
		[self scrollToBottomAnimated:NO];
		[self refreshComposerEmojiOverlay];
	}];
}

#pragma mark - custom emoji overlay

- (void)composerEditingChanged {
	[self refreshComposerEmojiOverlay];
}

- (void)composerCustomEmojiLoaded:(NSNotification *)note {
	if (self.composerText.customEmoji.count > 0) {
		[self refreshComposerEmojiOverlay];
	}
}

- (void)refreshComposerEmojiOverlay {
	if (!self.input)
		return;

	NSString *plainText = self.input.text ?: @"";
	if (self.composerText && ![self.composerText.text isEqualToString:plainText]) {
		[self.composerText resetText:plainText];
	}

	NSArray *customEmoji = self.composerText.customEmoji;
	if (customEmoji.count == 0) {
		for (UIImageView *view in self.composerEmojiViews) {
			view.hidden = YES;
			view.image = nil;
		}
		// When no custom emoji exist, revert to plain text if clearColor was applied.
		if (self.input.attributedText.length > 0) {
			__block BOOL hasClear = NO;
			[self.input.attributedText enumerateAttribute:NSForegroundColorAttributeName
												  inRange:NSMakeRange(0, self.input.attributedText.length)
												  options:0
											   usingBlock:^(id value, NSRange range, BOOL *stop) {
				if ([value isEqual:[UIColor clearColor]]) {
					hasClear = YES;
					*stop = YES;
				}
			}];
			if (hasClear) {
				UITextRange *sel = self.input.selectedTextRange;
				self.input.attributedText = nil;
				self.input.text = plainText;
				if (sel) {
					self.input.selectedTextRange = sel;
				}
			}
		}
		return;
	}

	if (!plainText.length) {
		for (UIImageView *view in self.composerEmojiViews) {
			view.hidden = YES;
			view.image = nil;
		}
		return;
	}

	if (!self.composerEmojiViews) {
		self.composerEmojiViews = [NSMutableArray array];
	}

	UIView *container = [self.input respondsToSelector:@selector(textInputView)] ? self.input.textInputView : self.input;
	if (!container) {
		container = self.input;
	}

	NSMutableArray *images = [NSMutableArray arrayWithCapacity:customEmoji.count];
	NSMutableArray *frames = [NSMutableArray arrayWithCapacity:customEmoji.count];
	NSMutableArray *ranges = [NSMutableArray arrayWithCapacity:customEmoji.count];

	for (id item in customEmoji) {
		if (![item isKindOfClass:[NSDictionary class]])
			continue;
		NSDictionary *dict = (NSDictionary *)item;
		id offsetObj = dict[@"offset"];
		id lengthObj = dict[@"length"];
		id emojiIdObj = dict[@"customEmojiId"];
		if (!([offsetObj isKindOfClass:[NSNumber class]] || [offsetObj isKindOfClass:[NSString class]]) ||
			!([lengthObj isKindOfClass:[NSNumber class]] || [lengthObj isKindOfClass:[NSString class]]) ||
			!([emojiIdObj isKindOfClass:[NSNumber class]] || [emojiIdObj isKindOfClass:[NSString class]])) {
			continue;
		}

		NSInteger offset = [offsetObj integerValue];
		NSInteger length = [lengthObj integerValue];
		int64_t emojiId = [emojiIdObj longLongValue];

		if (offset < 0 || length <= 0 || (NSUInteger)(offset + length) > plainText.length || emojiId == 0)
			continue;

		UITextPosition *posStart = [self.input positionFromPosition:self.input.beginningOfDocument offset:offset];
		if (!posStart)
			continue;
		UITextPosition *posEnd = [self.input positionFromPosition:posStart offset:length];
		if (!posEnd)
			continue;
		UITextRange *textRange = [self.input textRangeFromPosition:posStart toPosition:posEnd];
		if (!textRange)
			continue;

		CGRect rect = [self.input firstRectForRange:textRange];
		if (CGRectIsNull(rect) || CGRectIsEmpty(rect)) {
			rect = CGRectZero;
		} else if (container != self.input) {
			rect = [self.input convertRect:rect fromView:container];
		}

		CGFloat side = rect.size.height > 0 ? rect.size.height : TGMetricLineBody;
		UIImage *image = [[TGCustomEmojiStore shared] imageForId:emojiId side:side];

		CGFloat x = rect.origin.x + TGHalf(rect.size.width - side);
		CGFloat y = rect.origin.y + TGHalf(rect.size.height - side);
		CGRect imgFrame = (rect.size.height > 0) ? CGRectMake(x, y, side, side) : CGRectZero;

		[images addObject:(image ?: [NSNull null])];
		[frames addObject:[NSValue valueWithCGRect:imgFrame]];
		[ranges addObject:[NSValue valueWithRange:NSMakeRange((NSUInteger)offset, (NSUInteger)length)]];
	}

	UITextRange *savedSelection = self.input.selectedTextRange;

	NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:plainText
		attributes:@{
			NSFontAttributeName : self.input.font ?: TGFontBody(),
			NSForegroundColorAttributeName : [[TGTheme shared] primaryTextColour],
		}];

	NSUInteger poolIndex = 0;
	for (NSUInteger i = 0; i < ranges.count; i++) {
		NSRange r = [ranges[i] rangeValue];
		id imgObj = images[i];
		CGRect imgFrame = [frames[i] CGRectValue];

		if (imgObj != [NSNull null]) {
			// Picture loaded: hide fallback glyph and position overlay image
			[attr addAttribute:NSForegroundColorAttributeName value:[UIColor clearColor] range:r];

			UIImageView *iv = nil;
			if (poolIndex < self.composerEmojiViews.count) {
				iv = self.composerEmojiViews[poolIndex];
			} else {
				iv = [[UIImageView alloc] initWithFrame:CGRectZero];
				iv.userInteractionEnabled = NO;
				iv.contentMode = UIViewContentModeScaleAspectFit;
				[self.input addSubview:iv];
				[self.composerEmojiViews addObject:iv];
			}
			poolIndex++;

			iv.image = (UIImage *)imgObj;
			iv.frame = imgFrame;
			if (CGRectIsEmpty(imgFrame) || !CGRectIntersectsRect(self.input.bounds, imgFrame)) {
				iv.hidden = YES;
			} else {
				iv.hidden = NO;
			}
		}
		// Picture still loading: leave fallback glyph visible with normal text colour
	}

	for (NSUInteger i = poolIndex; i < self.composerEmojiViews.count; i++) {
		UIImageView *extra = self.composerEmojiViews[i];
		extra.hidden = YES;
		extra.image = nil;
	}

	if (![self.input.attributedText isEqualToAttributedString:attr]) {
		self.input.attributedText = attr;
		if (savedSelection) {
			self.input.selectedTextRange = savedSelection;
		}
	}
}

@end
