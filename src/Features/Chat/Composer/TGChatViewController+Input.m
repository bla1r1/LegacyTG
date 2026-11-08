#import "TGChatViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGChatParityModel.h"
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

@interface TGComposerInputField : UITextField
@property (nonatomic, copy) void (^onLayout)(void);
@end

@implementation TGComposerInputField {
	BOOL _inLayout;
}

- (void)layoutSubviews {
	[super layoutSubviews];
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

	CGFloat sendY = TGCenteredOrigin(kInputHeight, kSendSide);

	UIButton *attach = [UIButton buttonWithType:UIButtonTypeCustom];
	attach.frame = CGRectMake(kComposerInset, sendY, kAttachWidth, kSendSide);
	[attach setImage:[TGIcons attach] forState:UIControlStateNormal];
	attach.tintColor = [[TGTheme shared] accentColour];
	[attach addTarget:self action:@selector(attachTapped)
			forControlEvents:UIControlEventTouchUpInside];
	[self.inputBar addSubview:attach];

	CGFloat fieldH = kInputHeight - TGDoubled(kFieldInsetV);
	// The send control lives inside the field capsule; the mic sits outside
	// it, as official places them. Nothing else goes between the two.
	CGFloat micX = b.size.width - kSendSide - kSendInset;
	CGFloat fieldRight = micX - kComposerInset;
	TGComposerInputField *field = [[TGComposerInputField alloc] initWithFrame:
			CGRectMake(kFieldLeft, kFieldInsetV, fieldRight - kFieldLeft, fieldH)];
	field.borderStyle = UITextBorderStyleNone;
	field.background = [TGTheme skeuomorphicWellImageWithHeight:fieldH cornerRadius:TGHalf(fieldH)];
	field.backgroundColor = [UIColor clearColor];
	field.layer.borderWidth = 0.0f;
	field.layer.shouldRasterize = YES;
	field.layer.rasterizationScale = scale;
	field.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kFieldLeftPad,
			TGMetricBorderWidth)];
	field.leftViewMode = UITextFieldViewModeAlways;
	field.placeholder = TGLocalized(@"Message");	field.textColor = [[TGTheme shared] primaryTextColour];
	field.font = TGFontBody();
	field.returnKeyType = UIReturnKeySend;
	field.delegate = self;
	field.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	field.clipsToBounds = YES;
	__weak typeof(self) weakSelf = self;
	field.onLayout = ^{
		[weakSelf refreshComposerEmojiOverlay];
	};
	self.input = field;
	self.composerEmojiViews = [NSMutableArray array];
	self.composerText = [[TGComposerText alloc] initWithText:@"" entities:@[]];
	[self.inputBar addSubview:self.input];

	self.sendButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.sendButton.frame = CGRectMake(fieldRight - kSendSide - TGMetricPadTiny, sendY,
									   kSendSide, kSendSide);
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

	// The sticker button is retired: official keeps the field, the send
	// control inside it and the mic outside it, with no extra glyph.
	self.stickerButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.stickerButton.hidden = YES;
	[self.inputBar addSubview:self.stickerButton];

	// Hold to record, release to send - the gesture every client uses. It sits
	// where Send is and swaps with it depending on whether anything is typed.
	// The same button is the mode switch: a quick tap turns voice note
	// recording into a round video note and back, the way Telegram keeps two
	// modes on one spot instead of a second control beside the paperclip.
	self.micButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.micButton.frame = CGRectMake(micX, sendY, kSendSide, kSendSide);
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
	self.videoNoteMode = [[NSUserDefaults standardUserDefaults]
			boolForKey:kRecordVideoModeKey];
	[self updateRecordModeIcon];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(composerCustomEmojiLoaded:)
												 name:TGCustomEmojiLoadedNotification
											   object:nil];

	[self.input addTarget:self action:@selector(inputChanged)
		 forControlEvents:UIControlEventEditingChanged];
	[self.input addTarget:self action:@selector(composerEditingChanged)
		 forControlEvents:UIControlEventEditingChanged];
	[self inputChanged];
	[self updateComposerPlaceholder];

	[self.view addSubview:self.inputBar];
}

/// Official picks the field's word from the chat kind: a channel broadcasts,
/// a group or a private chat sends a message.
- (void)updateComposerPlaceholder {
	self.input.placeholder = TGChatComposerPlaceholder(self.isChannel,
			self.silentPosting, self.canBeAnonymous);
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
	[[TGClient shared] linkPreviewForText:self.input.text
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
	[[TGClient shared] sendTypingToChat:self.chatId thread:self.threadId];
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

static NSRange TGTextFieldSelectedRange(UITextField *tf) {
	UITextRange *r = tf.selectedTextRange;
	if (!r) return NSMakeRange(NSNotFound, 0);
	NSInteger start = [tf offsetFromPosition:tf.beginningOfDocument toPosition:r.start];
	NSInteger end = [tf offsetFromPosition:tf.beginningOfDocument toPosition:r.end];
	return NSMakeRange(start, end - start);
}

static void TGTextFieldSetSelectedRange(UITextField *tf, NSRange range) {
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
		[[TGClient shared] editCaption:text
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
		NSDictionary *ft = [[TGClient shared] markdownParsed:[self.composerText formattedText]];
		if (self.editingId != 0) {
			[[TGClient shared] editMessage:self.editingId inChat:self.chatId formattedText:ft];
		} else {
			[[TGClient shared] sendFormattedText:ft toChat:self.chatId
										  thread:self.threadId replyTo:self.replyToId];
		}
	}

	// Before clearComposeState, so inputChanged sees an empty field and puts
	// the microphone back in the send button's place.
	self.input.text = @"";
	self.composerText = [[TGComposerText alloc] initWithText:@"" entities:@[]];
	[self clearComposeState];
	// The draft was this text; it has been sent, so it is not a draft now.
	[[TGClient shared] setDraft:@"" inChat:self.chatId thread:self.threadId replyTo:0];
	[[TGClient shared] cancelTypingInChat:self.chatId thread:self.threadId];

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
			vc.hidesBottomBarWhenPushed = YES;
			[weakSelf.navigationController pushViewController:vc animated:YES];
		} else if (index == 2)
			[weakSelf holdScheduledSheet];
		else if (index == 3)
			[weakSelf sendHeldText:[TGClient scheduledWhenOnline]];
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
	[[TGClient shared] parseMarkdownText:text completion:^(NSDictionary *formatted){
		[[TGClient shared] textEntitiesInText:text completion:^(NSArray *entities){
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
	[[TGClient shared] sendText:text toChat:self.chatId
						 thread:self.threadId replyTo:self.replyToId
					  scheduled:state];
	self.input.text = @"";
	self.composerText = [[TGComposerText alloc] initWithText:@"" entities:@[]];
	[self clearComposeState];
	[[TGClient shared] setDraft:@"" inChat:self.chatId thread:self.threadId replyTo:0];
	[[TGClient shared] cancelTypingInChat:self.chatId thread:self.threadId];
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
	[self sendHeldText:[TGClient scheduledWhenOnline]];
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
	[self sendHeldText:[TGClient scheduledAtDate:date]];
	// The queue has one more in it than the menu last said.
	self.scheduledCount++;
	// Official lands the user on the queue so the result is visible.
	[self openScheduledMessages];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
	if (textField == self.input) {
		if (!self.composerText) {
			self.composerText = [[TGComposerText alloc] initWithText:self.input.text ?: @"" entities:@[]];
		} else if (![self.composerText.text isEqualToString:self.input.text ?: @""]) {
			[self.composerText resetText:self.input.text ?: @""];
		}
		[self.composerText replaceCharactersInRange:range withString:string];
		__weak typeof(self) weakSelf = self;
		dispatch_async(dispatch_get_main_queue(), ^{
			[weakSelf refreshComposerEmojiOverlay];
		});
	}
	return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField {
	if (textField == self.input) {
		self.composerText = [[TGComposerText alloc] initWithText:@"" entities:@[]];
		__weak typeof(self) weakSelf = self;
		dispatch_async(dispatch_get_main_queue(), ^{
			[weakSelf refreshComposerEmojiOverlay];
		});
	}
	return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	[self sendTapped];
	return NO;
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
	[[TGClient shared] sendStickerWithFileId:fileId toChat:self.chatId thread:self.threadId];
}

- (void)emojiPanel:(TGEmojiPanel *)panel didPickAnimation:(NSDictionary *)animation {
	[[TGClient shared] sendAnimation:animation toChat:self.chatId thread:self.threadId];
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
	[UIView animateWithDuration:TGAnimationDurationMedium animations:^{
		self.inputBar.frame = CGRectMake(0, b.size.height - kInputHeight - height,
				b.size.width, kInputHeight);
		self.table.frame = CGRectMake(0, 0, b.size.width,
				b.size.height - kInputHeight - height);
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
