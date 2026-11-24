//
// TGChatViewController+Bots.m - what a bot puts in a chat besides text: the
// buttons under its messages and the keyboard it can swap in for the system
// one. Neither was drawn before, so a bot that asked a question offered no
// way to answer it.
//
#import "TGChatViewControllerInternal.h"
#import "TGProfileViewController.h"
#import "TGDevShowcase.h"
#import "TGForwardPicker.h"
#import "TGPresent.h"
#import "TGMediaStore.h"

@implementation TGChatViewController (Bots)

#pragma mark - inline buttons

/// The tapped button's message and place come from where it sits: the tag is
/// row * 16 + column, and the row is found from the table.
- (void)botButtonTapped:(UIButton *)key {
	CGPoint at = [key convertPoint:CGPointZero toView:self.table];
	NSIndexPath *path = [self.table indexPathForRowAtPoint:at];
	if (!path || path.row >= (NSInteger)self.messages.count)
		return;
	NSDictionary *m = self.messages[path.row];
	NSArray *rows = m[@"inlineRows"];
	NSUInteger r = (NSUInteger)key.tag / 16, c = (NSUInteger)key.tag % 16;
	if (r >= rows.count || c >= [rows[r] count])
		return;
	[self pressBotButton:rows[r][c] onMessage:m];
}

- (void)pressBotButton:(NSDictionary *)button onMessage:(NSDictionary *)m {
	NSString *kind = button[@"kind"];
	int64_t chatId = self.chatId, messageId = [m[@"id"] longLongValue];
	__weak typeof(self) weakSelf = self;

	if ([kind isEqualToString:@"callback"]) {
		[[TGMessageStore shared] pressCallbackButton:button inChat:chatId messageId:messageId
									completion:^(NSString *text, BOOL alert, NSString *url, NSString *error){
			TGChatViewController *me = weakSelf;
			if (error)
				[TGSnackbar showInView:me.view text:error seconds:2 onCommit:nil];
			else if (url.length)
				[me handleOpenLink:url];
			else if (text.length && alert)
				[TGAlertSheet showMessage:text title:(button[@"text"] ?: @"") inView:me.view];
			else if (text.length)
				[TGSnackbar showInView:me.view text:text seconds:2 onCommit:nil];
		}];
	} else if ([kind isEqualToString:@"url"]) {
		[self handleOpenLink:button[@"url"]];
	} else if ([kind isEqualToString:@"login"]) {
		[[TGMessageStore shared] loginURLForButton:button inChat:chatId messageId:messageId
								  completion:^(NSString *url, NSString *domain, NSString *error){
			TGChatViewController *me = weakSelf;
			if (url.length) {
				[me handleOpenLink:url];
				return;
			}
			if (!domain.length)
				return;
			[TGAlertSheet showConfirm:nil
								title:@"Log In"
							   action:@"Log In"
						  destructive:NO
							   inView:me.view
							onConfirm:^{
				[[TGMessageStore shared] confirmLoginButton:button inChat:chatId messageId:messageId
										   completion:^(NSString *link, NSString *refused){
					if (link.length)
						[weakSelf handleOpenLink:link];
					else
						[TGSnackbar showInView:weakSelf.view text:refused seconds:2 onCommit:nil];
				}];
			}];
		}];
	} else if ([kind isEqualToString:@"switch"]) {
		// Inline mode is typed into the composer: "@bot query" - here, or in
		// a chat the user picks first when the button says so.
		BOOL choose = [button[@"chooseChat"] boolValue];
		[[TGMessageStore shared] userInfo:[m[@"senderId"] longLongValue] completion:^(NSDictionary *user){
			TGChatViewController *me = weakSelf;
			NSArray *names = user[@"usernames"][@"active_usernames"];
			NSString *bot = names.count ? [@"@" stringByAppendingString:names[0]] : @"";
			NSString *text = [[NSString stringWithFormat:@"%@ %@", bot, button[@"query"] ?: @""]
					stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			if (!choose){
				me.input.text = text;
				[me.input becomeFirstResponder];
				[me inputChanged];
				return;
			}
			TGForwardPicker *picker = [[TGForwardPicker alloc] init];
			picker.sourceChatId = me.chatId;
			picker.onPicked = ^(int64_t targetChatId){
				TGChatViewController *other = [[TGChatViewController alloc] init];
				other.chatId = targetChatId;
				other.chatTitle = [[TGMessageStore shared] titleForChat:targetChatId] ?: @"";
				other.hidesBottomBarWhenPushed = YES;
				[weakSelf.navigationController pushViewController:other animated:YES];
				(void)other.view;   // the composer is built in viewDidLoad
				other.input.text = text;
				[other inputChanged];
			};
			[TGPresent presentModal:picker kind:TGModalForm from:me];
		}];
	} else if ([kind isEqualToString:@"copy"]) {
		[UIPasteboard generalPasteboard].string = button[@"copy"] ?: @"";
		[TGSnackbar showInView:self.view text:@"Text copied." seconds:1 onCommit:nil];
	} else if ([kind isEqualToString:@"user"]) {
		int64_t userId = [button[@"userId"] longLongValue];
		TGProfileViewController *profile = [[TGProfileViewController alloc]
				initWithChatId:userId userId:userId title:button[@"text"]];
		[self.navigationController pushViewController:profile animated:YES];
	} else {
		[TGSnackbar showInView:self.view text:@"Update Telegram" seconds:2 onCommit:nil];
	}
}

#pragma mark - bot commands

/// Official's "/" key sits where the keyboard key would (ChatTextInputPanelNode's
/// commands accessory) when the chat's bots have commands and no keyboard
/// is up; a reply keyboard takes the place instead.
- (void)refreshBotCommands {
	__weak typeof(self) weakSelf = self;
	void (^apply)(NSArray *) = ^(NSArray *commands){
		TGChatViewController *me = weakSelf;
		if (!me || me.replyKeyboard)
			return;
		me.botCommands = commands;
		if (!commands.count){
			[me hideBotCommands];
			return;
		}
		if (!me.botCommandsToggle){
			UIButton *toggle = [UIButton buttonWithType:UIButtonTypeCustom];
			toggle.frame = CGRectMake(0, 0, TGMetricRow - TGMetricPadMedium, me.input.bounds.size.height);
			[toggle addTarget:me action:@selector(toggleBotCommands)
			 forControlEvents:UIControlEventTouchUpInside];
			me.botCommandsToggle = toggle;
		}
		[me.botCommandsToggle setImage:[TGIcons glyphNamed:@"botCommands"
				colour:[[TGTheme shared] secondaryTextColour] side:TGMetricMenuGlyph]
							  forState:UIControlStateNormal];
		me.input.rightView = me.botCommandsToggle;
		me.input.rightViewMode = UITextFieldViewModeAlways;
	};
#if TG_DEV
	NSArray *fixture = [TGDevShowcase botCommandsForChatId:self.chatId];
	if (fixture){
		apply(fixture);
		return;
	}
#endif
	[[TGMessageStore shared] botCommandsForChat:self.chatId completion:apply];
}

- (void)hideBotCommands {
	[self.botCommandsPanel removeFromSuperview];
	self.botCommandsPanel = nil;
}

/// The list rises over the composer, a row per command: "/start" and what
/// it does, as official's commands panel shows them. A row sends its command.
- (void)toggleBotCommands {
	if (self.botCommandsPanel){
		[self hideBotCommands];
		return;
	}
	NSArray *commands = self.botCommands;
	if (!commands.count)
		return;
	TGTheme *theme = [TGTheme shared];
	CGFloat width = self.view.bounds.size.width;
	CGFloat rowH = TGMetricRow;
	CGFloat height = MIN((CGFloat)commands.count, TGMetricBotCommandRowsShown) * rowH;
	CGFloat bottom = CGRectGetMinY(self.inputBar.frame);
	UIScrollView *panel = [[UIScrollView alloc] initWithFrame:CGRectMake(0, bottom - height, width, height)];
	panel.backgroundColor = [theme inputBarColour];
	panel.contentSize = CGSizeMake(width, commands.count * rowH);
	for (NSUInteger i = 0; i < commands.count; i++){
		NSDictionary *command = commands[i];
		UIButton *row = [UIButton buttonWithType:UIButtonTypeCustom];
		row.frame = CGRectMake(0, i * rowH, width, rowH);
		row.tag = (NSInteger)i;
		[row addTarget:self action:@selector(botCommandTapped:) forControlEvents:UIControlEventTouchUpInside];
		UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(TGMetricPadLarge, 0,
				width - TGDoubled(TGMetricPadLarge), TGHalf(rowH) + TGMetricPadSmall)];
		name.backgroundColor = [UIColor clearColor];
		name.font = TGFontBodyStrong();
		name.textColor = [theme primaryTextColour];
		name.text = [@"/" stringByAppendingString:command[@"command"]];
		[row addSubview:name];
		UILabel *about = [[UILabel alloc] initWithFrame:CGRectMake(TGMetricPadLarge,
				TGHalf(rowH), width - TGDoubled(TGMetricPadLarge), TGHalf(rowH) - TGMetricPadSmall)];
		about.backgroundColor = [UIColor clearColor];
		about.font = TGFontCaption();
		about.textColor = [theme secondaryTextColour];
		about.text = command[@"description"];
		[row addSubview:about];
		UIView *rule = [[UIView alloc] initWithFrame:CGRectMake(TGMetricPadLarge, rowH - TGMetricHairline,
				width - TGMetricPadLarge, TGMetricHairline)];
		rule.backgroundColor = [theme separatorColour];
		[row addSubview:rule];
		[panel addSubview:row];
	}
	[self.view addSubview:panel];
	self.botCommandsPanel = panel;
}

- (void)botCommandTapped:(UIButton *)row {
	NSArray *commands = self.botCommands;
	if (row.tag < 0 || row.tag >= (NSInteger)commands.count)
		return;
	// ponytail: "/cmd" without "@bot"; a group with two bots that share a
	// command name answers from both, as Telegram itself routes it.
	NSString *text = [@"/" stringByAppendingString:commands[(NSUInteger)row.tag][@"command"]];
	[[TGSendStore shared] sendText:text toChat:self.chatId thread:self.threadId];
	[self hideBotCommands];
}

#pragma mark - reply keyboard

/// Asks for the chat's keyboard and shows or hides the key in the composer.
/// Run on open and whenever the chat's keyboard changes.
- (void)refreshReplyKeyboard {
	__weak typeof(self) weakSelf = self;
	void (^apply)(NSDictionary *) = ^(NSDictionary *keyboard){
		TGChatViewController *me = weakSelf;
		if (!me)
			return;
		me.replyKeyboard = keyboard;
		if (!keyboard) {
			[me hideBotKeyboard];
			me.input.rightView = nil;
			me.input.rightViewMode = UITextFieldViewModeNever;
			[me refreshBotCommands];
			return;
		}
		if (!me.botKeyboardToggle) {
			UIButton *toggle = [UIButton buttonWithType:UIButtonTypeCustom];
			toggle.frame = CGRectMake(0, 0, TGMetricRow - TGMetricPadMedium, me.input.bounds.size.height);
			[toggle setImage:[TGIcons botKeyboard] forState:UIControlStateNormal];
			[TGIcons tintButton:toggle colour:[[TGTheme shared] secondaryTextColour]];
			[toggle addTarget:me action:@selector(toggleBotKeyboard)
			 forControlEvents:UIControlEventTouchUpInside];
			me.botKeyboardToggle = toggle;
		}
		me.input.rightView = me.botKeyboardToggle;
		me.input.rightViewMode = UITextFieldViewModeAlways;
		NSString *placeholder = keyboard[@"placeholder"];
		if (placeholder.length)
			me.input.placeholder = placeholder;
		// A persistent keyboard is open whenever the text one is not.
		if ([keyboard[@"persistent"] boolValue] && ![me botKeyboardShown] &&
			![me.input isFirstResponder])
			[me toggleBotKeyboard];
	};
#if TG_DEV
	NSDictionary *fixture = [TGDevShowcase replyKeyboardForChatId:self.chatId];
	if (fixture) {
		apply(fixture);
		return;
	}
#endif
	[[TGMessageStore shared] replyKeyboardForChat:self.chatId completion:apply];
}

- (void)replyMarkupChanged:(NSNotification *)note {
	if ([note.userInfo[@"chatId"] longLongValue] == self.chatId)
		[self refreshReplyKeyboard];
}

- (BOOL)botKeyboardShown {
	return self.botKeyboardPanel && !self.botKeyboardPanel.hidden;
}

- (void)toggleBotKeyboard {
	if ([self botKeyboardShown]) {
		[self.input becomeFirstResponder];     // its arrival puts the panel away
		return;
	}
	NSArray *rows = self.replyKeyboard[@"rows"];
	if (!rows.count)
		return;
	[self hideStickerPanel];
	if ([self.input isFirstResponder])
		[self.input resignFirstResponder];

	CGRect b = self.view.bounds;
	CGFloat pitch = TGMetricBotKeyHeight;
	CGFloat height = TGBotKeyboardPanelHeight((NSInteger)rows.count,
			[self.replyKeyboard[@"resize"] boolValue], TGMetricBotKeyboardHeight,
			TGMetricBotButtonGap, &pitch);
	[self.botKeyboardPanel removeFromSuperview];
	UIScrollView *panel = [[UIScrollView alloc] initWithFrame:CGRectMake(0, b.size.height, b.size.width, height)];
	panel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
	TGTheme *theme = [TGTheme shared];
	panel.backgroundColor = [theme inputBarColour];
	CGFloat gap = TGMetricBotButtonGap;
	for (NSUInteger r = 0; r < rows.count; r++) {
		NSArray *row = rows[r];
		CGFloat w = (b.size.width - gap * (row.count + 1)) / row.count;
		for (NSUInteger c = 0; c < row.count; c++) {
			UIButton *key = [UIButton buttonWithType:UIButtonTypeCustom];
			key.frame = CGRectMake(gap + c * (w + gap), gap + r * pitch,
								   w, pitch - gap);
			key.backgroundColor = [theme cardBackgroundColour];
			key.layer.cornerRadius = TGMetricCornerSmall;
			key.layer.borderWidth = TGMetricBorderWidth;
			key.layer.borderColor = [theme separatorColour].CGColor;
			key.titleLabel.font = TGFontBody();
			[key setTitle:row[c] forState:UIControlStateNormal];
			[key setTitleColor:[theme primaryTextColour] forState:UIControlStateNormal];
			[key addTarget:self action:@selector(botKeyTapped:) forControlEvents:UIControlEventTouchUpInside];
			[panel addSubview:key];
		}
	}
	panel.contentSize = CGSizeMake(b.size.width, rows.count * pitch + gap);
	[self.view addSubview:panel];
	self.botKeyboardPanel = panel;
	[UIView animateWithDuration:TGAnimationDurationMedium animations:^{
		panel.frame = CGRectMake(0, b.size.height - height, b.size.width, height);
	}];
	[self shiftForKeyboardHeight:height];
}

- (void)hideBotKeyboard {
	if (![self botKeyboardShown])
		return;
	UIView *panel = self.botKeyboardPanel;
	CGRect b = self.view.bounds;
	[UIView animateWithDuration:TGAnimationDurationNormal animations:^{
		CGRect f = panel.frame;
		f.origin.y = b.size.height;
		panel.frame = f;
	} completion:^(BOOL finished) {
		panel.hidden = YES;
	}];
	if (![self.input isFirstResponder])
		[self shiftForKeyboardHeight:0];
}

/// A key sends its own label, which is the whole protocol of a reply
/// keyboard. A one-time keyboard folds away after one key.
- (void)botKeyTapped:(UIButton *)key {
	NSString *text = key.currentTitle;
	if (!text.length)
		return;
	[[TGSendStore shared] sendText:text toChat:self.chatId thread:self.threadId];
	if ([self.replyKeyboard[@"oneTime"] boolValue]){
		// A one-time keyboard is spent; TDLib wants the markup dropped so a
		// reload of the chat does not bring the dead keys back.
		[[TGMessageStore shared] dismissReplyMarkupInChat:self.chatId];
		[self hideBotKeyboard];
	}
}

#pragma mark - inline bot mode

static NSData *TGDecodeMiniThumb(id value) {
	if ([value isKindOfClass:NSData.class])
		return value;
	if (![value isKindOfClass:NSString.class] || ![value length])
		return nil;
	return [[NSData alloc] initWithBase64Encoding:value];
}

static void TGInlineResultThumbnailInfo(NSDictionary *item, NSInteger *outFileId, NSData **outMiniThumb) {
	NSInteger fileId = 0;
	NSData *mini = nil;
	NSDictionary *thumb = [item[@"thumbnail"] isKindOfClass:NSDictionary.class] ? item[@"thumbnail"] : nil;
	if (!thumb) {
		for (NSString *k in @[@"animation", @"video", @"document", @"sticker"]) {
			NSDictionary *media = [item[k] isKindOfClass:NSDictionary.class] ? item[k] : nil;
			if (!media)
				continue;
			if ([media[@"thumbnail"] isKindOfClass:NSDictionary.class])
				thumb = media[@"thumbnail"];
			if (media[@"minithumbnail"][@"data"])
				mini = TGDecodeMiniThumb(media[@"minithumbnail"][@"data"]);
			break;
		}
	}
	if (thumb && [thumb[@"file"][@"id"] isKindOfClass:NSNumber.class]) {
		fileId = [thumb[@"file"][@"id"] integerValue];
	}
	if (!fileId && [item[@"photo"] isKindOfClass:NSDictionary.class]) {
		NSDictionary *photo = item[@"photo"];
		if (!mini && photo[@"minithumbnail"][@"data"])
			mini = TGDecodeMiniThumb(photo[@"minithumbnail"][@"data"]);
		NSArray *sizes = [photo[@"sizes"] isKindOfClass:NSArray.class] ? photo[@"sizes"] : nil;
		if (sizes.count) {
			NSDictionary *pick = sizes.count > 1 ? sizes[1] : sizes[0];
			if ([pick[@"photo"][@"id"] isKindOfClass:NSNumber.class])
				fileId = [pick[@"photo"][@"id"] integerValue];
		}
	}
	if (outFileId) *outFileId = fileId;
	if (outMiniThumb) *outMiniThumb = mini;
}

static BOOL TGInlineResultIsMediaTile(NSDictionary *item) {
	NSString *type = [item[@"@type"] isKindOfClass:NSString.class] ? item[@"@type"] : @"";
	BOOL isMedia = [type isEqualToString:@"inlineQueryResultAnimation"]
			|| [type isEqualToString:@"inlineQueryResultPhoto"]
			|| [type isEqualToString:@"inlineQueryResultSticker"]
			|| [type isEqualToString:@"inlineQueryResultVideo"];
	NSString *title = [item[@"title"] isKindOfClass:NSString.class] ? item[@"title"] : @"";
	return isMedia && !title.length;
}

- (void)loadInlineThumbnailInto:(UIImageView *)imageView fileId:(NSInteger)fileId miniThumb:(NSData *)mini {
	if (mini.length) {
		UIImage *miniImg = [UIImage imageWithData:mini];
		if (miniImg)
			imageView.image = miniImg;
	}
	if (fileId <= 0)
		return;
	__weak UIImageView *weakIV = imageView;
	[[TGMediaStore shared] downloadFile:fileId completion:^(NSString *path){
		UIImageView *iv = weakIV;
		if (!iv || !path.length)
			return;
		UIImage *img = [UIImage imageWithContentsOfFile:path];
		if (img)
			iv.image = img;
	}];
}

- (UIScrollView *)prepareInlineBotPanelWithHeight:(CGFloat)panelH {
	TGTheme *theme = [TGTheme shared];
	CGFloat width = self.view.bounds.size.width;
	CGFloat bottom = CGRectGetMinY(self.inputBar.frame);
	CGFloat maxH = MAX(TGMetricPersonRow, bottom - TGMetricNavigationBarHeight - TGMetricPadWide);
	CGFloat height = MIN(panelH, maxH);

	if (!self.inlineBotPanel) {
		UIScrollView *panel = [[UIScrollView alloc] initWithFrame:CGRectMake(0, bottom - height, width, height)];
		panel.backgroundColor = [theme inputBarColour];
		panel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
		[self.view addSubview:panel];
		self.inlineBotPanel = panel;
	} else {
		self.inlineBotPanel.frame = CGRectMake(0, bottom - height, width, height);
		for (UIView *sub in [self.inlineBotPanel.subviews copy]) {
			[sub removeFromSuperview];
		}
	}

	UIView *topBorder = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, TGMetricHairline)];
	topBorder.backgroundColor = [theme separatorColour];
	[self.inlineBotPanel addSubview:topBorder];
	return self.inlineBotPanel;
}

- (void)checkInlineBotQuery {
	NSString *text = self.input.text ?: @"";
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(performInlineBotQuery) object:nil];

	if (![text hasPrefix:@"@"]) {
		[self hideInlineBotResults];
		return;
	}

	static NSRegularExpression *prefixRegex = nil;
	static NSRegularExpression *queryRegex = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		prefixRegex = [NSRegularExpression regularExpressionWithPattern:@"^@([A-Za-z0-9_]{0,32})$"
		                                                        options:0
		                                                          error:nil];
		queryRegex = [NSRegularExpression regularExpressionWithPattern:@"^@([A-Za-z0-9_]{3,32})\\s+(.*)$"
		                                                       options:NSRegularExpressionDotMatchesLineSeparators
		                                                         error:nil];
	});

	NSTextCheckingResult *prefixMatch = [prefixRegex firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
	if (prefixMatch && prefixMatch.numberOfRanges >= 2) {
		NSString *prefix = [[text substringWithRange:[prefixMatch rangeAtIndex:1]] lowercaseString];
		__weak typeof(self) weakSelf = self;
		[[TGMessageStore shared] recentInlineBots:^(NSArray *bots){
			TGChatViewController *me = weakSelf;
			if (!me || ![me.input.text isEqualToString:text])
				return;
			NSMutableArray *filtered = [NSMutableArray array];
			for (NSDictionary *bot in bots) {
				NSString *uname = [bot[@"username"] lowercaseString] ?: @"";
				if (!prefix.length || [uname hasPrefix:prefix])
					[filtered addObject:bot];
			}
			if (filtered.count)
				[me showInlineBotSuggestions:filtered];
			else
				[me hideInlineBotResults];
		}];
		return;
	}

	NSTextCheckingResult *match = [queryRegex firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
	if (!match || match.numberOfRanges < 3) {
		[self hideInlineBotResults];
		return;
	}

	[self performSelector:@selector(performInlineBotQuery) withObject:nil afterDelay:0.35];
}

- (void)performInlineBotQuery {
	NSString *text = self.input.text ?: @"";
	static NSRegularExpression *regex = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		regex = [NSRegularExpression regularExpressionWithPattern:@"^@([A-Za-z0-9_]{3,32})\\s+(.*)$"
		                                                  options:NSRegularExpressionDotMatchesLineSeparators
		                                                    error:nil];
	});

	NSTextCheckingResult *match = [regex firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
	if (!match || match.numberOfRanges < 3) {
		[self hideInlineBotResults];
		return;
	}

	NSString *botName = [text substringWithRange:[match rangeAtIndex:1]];
	NSString *query = [text substringWithRange:[match rangeAtIndex:2]];

	__weak typeof(self) weakSelf = self;
	[[TGMessageStore shared] queryInlineBot:botName query:query inChat:self.chatId offset:@""
	                         fullCompletion:^(NSArray *results, int64_t queryId, NSDictionary *button, NSString *nextOffset, int64_t botUserId){
		TGChatViewController *me = weakSelf;
		if (!me)
			return;
		NSString *current = me.input.text ?: @"";
		NSString *expectedPrefix = [NSString stringWithFormat:@"@%@", botName.lowercaseString];
		if (![current.lowercaseString hasPrefix:expectedPrefix]) {
			[me hideInlineBotResults];
			return;
		}
		me.inlineBotName = botName;
		[me showInlineBotResults:results queryId:queryId button:button botUserId:botUserId];
	}];
}

- (void)hideInlineBotResults {
	if (self.inlineBotPanel) {
		[self.inlineBotPanel removeFromSuperview];
		self.inlineBotPanel = nil;
		self.inlineBotResults = nil;
		self.inlineBotSuggestions = nil;
		self.inlineBotButton = nil;
		self.inlineBotQueryId = 0;
		self.inlineBotUserId = 0;
	}
}

- (void)showInlineBotSuggestions:(NSArray *)bots {
	if (!bots.count) {
		[self hideInlineBotResults];
		return;
	}
	self.inlineBotSuggestions = bots;
	self.inlineBotResults = nil;
	self.inlineBotButton = nil;
	self.inlineBotQueryId = 0;

	TGTheme *theme = [TGTheme shared];
	CGFloat width = self.view.bounds.size.width;
	CGFloat rowH = TGMetricPersonRow;
	CGFloat maxH = TGMetricSettingsProfileRow + TGMetricRow;
	CGFloat contentH = bots.count * rowH;
	UIScrollView *panel = [self prepareInlineBotPanelWithHeight:MIN(contentH, maxH)];
	panel.contentSize = CGSizeMake(width, contentH);

	for (NSUInteger i = 0; i < bots.count; i++) {
		NSDictionary *bot = bots[i];
		UIButton *row = [UIButton buttonWithType:UIButtonTypeCustom];
		row.frame = CGRectMake(0, i * rowH, width, rowH);
		row.tag = (NSInteger)i;
		[row addTarget:self action:@selector(inlineBotSuggestionTapped:) forControlEvents:UIControlEventTouchUpInside];

		CGFloat avatarSide = TGMetricListAvatar;
		UIImageView *avatar = [[UIImageView alloc] initWithFrame:CGRectMake(
				TGMetricPadLarge, TGCenteredOrigin(rowH, avatarSide), avatarSide, avatarSide)];
		avatar.backgroundColor = [theme separatorColour];
		avatar.layer.cornerRadius = TGHalf(avatarSide);
		avatar.clipsToBounds = YES;
		avatar.contentMode = UIViewContentModeScaleAspectFill;
		[row addSubview:avatar];
		NSInteger photoId = [bot[@"photoFileId"] integerValue];
		if (photoId > 0)
			[self loadInlineThumbnailInto:avatar fileId:photoId miniThumb:nil];

		CGFloat textX = TGMetricPadLarge + avatarSide + TGMetricPadMedium;
		CGFloat textW = width - textX - TGMetricPadLarge;

		UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(textX, TGMetricPadSmall, textW, TGHalf(rowH))];
		nameLabel.backgroundColor = [UIColor clearColor];
		nameLabel.font = TGFontBodyStrong();
		nameLabel.textColor = [theme primaryTextColour];
		nameLabel.text = bot[@"name"] ?: bot[@"username"];
		[row addSubview:nameLabel];

		UILabel *userLabel = [[UILabel alloc] initWithFrame:CGRectMake(textX, TGHalf(rowH) - TGMetricPadTiny, textW, TGHalf(rowH) - TGMetricPadSmall)];
		userLabel.backgroundColor = [UIColor clearColor];
		userLabel.font = TGFontCaption();
		userLabel.textColor = [theme secondaryTextColour];
		userLabel.text = [@"@" stringByAppendingString:(bot[@"username"] ?: @"")];
		[row addSubview:userLabel];

		UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(textX, rowH - TGMetricHairline, textW, TGMetricHairline)];
		sep.backgroundColor = [theme separatorColour];
		[row addSubview:sep];

		[panel addSubview:row];
	}
}

- (void)inlineBotSuggestionTapped:(UIButton *)btn {
	NSInteger index = btn.tag;
	if (index < 0 || index >= (NSInteger)self.inlineBotSuggestions.count)
		return;
	NSDictionary *bot = self.inlineBotSuggestions[(NSUInteger)index];
	NSString *username = bot[@"username"];
	if (!username.length)
		return;
	self.input.text = [NSString stringWithFormat:@"@%@ ", username];
	[self inputChanged];
	[self.input becomeFirstResponder];
}

- (void)showInlineBotResults:(NSArray *)results
                     queryId:(int64_t)queryId
                      button:(NSDictionary *)button
                   botUserId:(int64_t)botUserId {
	NSString *buttonText = [button[@"text"] isKindOfClass:NSString.class] ? button[@"text"] : @"";
	if (!results.count && !buttonText.length) {
		[self hideInlineBotResults];
		return;
	}

	self.inlineBotSuggestions = nil;
	self.inlineBotResults = results;
	self.inlineBotQueryId = queryId;
	self.inlineBotButton = button;
	self.inlineBotUserId = botUserId;

	TGTheme *theme = [TGTheme shared];
	CGFloat width = self.view.bounds.size.width;
	CGFloat yOffset = 0.0f;

	BOOL useGrid = results.count > 0;
	for (NSDictionary *item in results) {
		if (!TGInlineResultIsMediaTile(item)) {
			useGrid = NO;
			break;
		}
	}

	CGFloat headerH = buttonText.length ? TGMetricRow : 0.0f;
	CGFloat bodyH = 0.0f;
	NSInteger cols = TGMetricThemeGridColumns;
	CGFloat gap = TGMetricGridGap;
	CGFloat tileSide = floorf((width - (cols + 1) * gap) / cols);

	if (results.count) {
		if (useGrid) {
			NSInteger rows = ((NSInteger)results.count + cols - 1) / cols;
			bodyH = gap + rows * (tileSide + gap);
		} else {
			bodyH = results.count * TGMetricPersonRow;
		}
	}

	CGFloat contentH = headerH + bodyH;
	CGFloat maxPanelH = TGMetricSettingsProfileRow + TGMetricRow;
	UIScrollView *panel = [self prepareInlineBotPanelWithHeight:MIN(contentH, maxPanelH)];
	panel.contentSize = CGSizeMake(width, contentH);

	if (buttonText.length) {
		UIButton *pmBtn = [UIButton buttonWithType:UIButtonTypeCustom];
		pmBtn.frame = CGRectMake(0, 0, width, TGMetricRow);
		[pmBtn setTitle:buttonText forState:UIControlStateNormal];
		[pmBtn setTitleColor:[theme accentColour] forState:UIControlStateNormal];
		pmBtn.titleLabel.font = TGFontBodyStrong();
		[pmBtn addTarget:self action:@selector(inlineBotButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
		UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(0, TGMetricRow - TGMetricHairline, width, TGMetricHairline)];
		sep.backgroundColor = [theme separatorColour];
		[pmBtn addSubview:sep];
		[panel addSubview:pmBtn];
		yOffset += TGMetricRow;
	}

	if (useGrid) {
		for (NSUInteger i = 0; i < results.count; i++) {
			NSDictionary *item = results[i];
			NSInteger col = (NSInteger)(i % cols);
			NSInteger rowIdx = (NSInteger)(i / cols);
			CGFloat x = gap + col * (tileSide + gap);
			CGFloat y = yOffset + gap + rowIdx * (tileSide + gap);

			UIButton *tile = [UIButton buttonWithType:UIButtonTypeCustom];
			tile.frame = CGRectMake(x, y, tileSide, tileSide);
			tile.tag = (NSInteger)i;
			tile.backgroundColor = [theme separatorColour];
			tile.layer.cornerRadius = TGMetricCornerSmall;
			tile.clipsToBounds = YES;
			[tile addTarget:self action:@selector(inlineBotResultTapped:) forControlEvents:UIControlEventTouchUpInside];

			UIImageView *iv = [[UIImageView alloc] initWithFrame:tile.bounds];
			iv.contentMode = UIViewContentModeScaleAspectFill;
			iv.clipsToBounds = YES;
			[tile addSubview:iv];

			NSInteger fileId = 0;
			NSData *mini = nil;
			TGInlineResultThumbnailInfo(item, &fileId, &mini);
			[self loadInlineThumbnailInto:iv fileId:fileId miniThumb:mini];

			[panel addSubview:tile];
		}
		return;
	}

	CGFloat rowH = TGMetricPersonRow;
	for (NSUInteger i = 0; i < results.count; i++) {
		NSDictionary *item = results[i];
		UIButton *row = [UIButton buttonWithType:UIButtonTypeCustom];
		row.frame = CGRectMake(0, yOffset + i * rowH, width, rowH);
		row.tag = (NSInteger)i;
		[row addTarget:self action:@selector(inlineBotResultTapped:) forControlEvents:UIControlEventTouchUpInside];

		NSInteger fileId = 0;
		NSData *mini = nil;
		TGInlineResultThumbnailInfo(item, &fileId, &mini);
		BOOL hasThumb = (fileId > 0 || mini.length > 0);

		CGFloat textX = TGMetricPadLarge;
		if (hasThumb) {
			CGFloat thumbSide = TGMetricListAvatar;
			UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(
					TGMetricPadLarge, TGCenteredOrigin(rowH, thumbSide), thumbSide, thumbSide)];
			iv.backgroundColor = [theme separatorColour];
			iv.layer.cornerRadius = TGMetricCornerSmall;
			iv.clipsToBounds = YES;
			iv.contentMode = UIViewContentModeScaleAspectFill;
			[row addSubview:iv];
			[self loadInlineThumbnailInto:iv fileId:fileId miniThumb:mini];
			textX = TGMetricPadLarge + thumbSide + TGMetricPadMedium;
		}

		NSString *title = [item[@"title"] isKindOfClass:NSString.class] ? item[@"title"] : nil;
		NSString *desc = [item[@"description"] isKindOfClass:NSString.class] ? item[@"description"]
				: ([item[@"performer"] isKindOfClass:NSString.class] ? item[@"performer"] : nil);
		if (!title.length && !desc.length) {
			title = [item[@"@type"] stringByReplacingOccurrencesOfString:@"inlineQueryResult" withString:@""];
		}

		CGFloat textW = width - textX - TGMetricPadLarge;
		if (desc.length && title.length) {
			UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(textX, TGMetricPadSmall, textW, TGHalf(rowH))];
			titleLabel.backgroundColor = [UIColor clearColor];
			titleLabel.font = TGFontBodyStrong();
			titleLabel.textColor = [theme primaryTextColour];
			titleLabel.text = title;
			[row addSubview:titleLabel];

			UILabel *descLabel = [[UILabel alloc] initWithFrame:CGRectMake(textX, TGHalf(rowH) - TGMetricPadTiny, textW, TGHalf(rowH) - TGMetricPadSmall)];
			descLabel.backgroundColor = [UIColor clearColor];
			descLabel.font = TGFontCaption();
			descLabel.textColor = [theme secondaryTextColour];
			descLabel.text = desc;
			[row addSubview:descLabel];
		} else {
			UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(textX, 0, textW, rowH)];
			titleLabel.backgroundColor = [UIColor clearColor];
			titleLabel.font = TGFontBody();
			titleLabel.textColor = [theme primaryTextColour];
			titleLabel.text = title.length ? title : desc;
			[row addSubview:titleLabel];
		}

		UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(textX, rowH - TGMetricHairline, textW, TGMetricHairline)];
		sep.backgroundColor = [theme separatorColour];
		[row addSubview:sep];

		[panel addSubview:row];
	}
}

- (void)inlineBotButtonTapped:(UIButton *)btn {
	NSDictionary *button = self.inlineBotButton;
	NSDictionary *type = [button[@"type"] isKindOfClass:NSDictionary.class] ? button[@"type"] : nil;
	NSString *kind = type[@"@type"];
	if ([kind isEqualToString:@"inlineQueryResultsButtonTypeWebApp"]) {
		NSString *url = type[@"url"];
		if (url.length)
			[self handleOpenLink:url];
		return;
	}
	if ([kind isEqualToString:@"inlineQueryResultsButtonTypeStartBot"] && self.inlineBotUserId) {
		NSString *param = [type[@"parameter"] isKindOfClass:NSString.class] ? type[@"parameter"] : @"";
		__weak typeof(self) weakSelf = self;
		[[TGMessageStore shared] openBot:self.inlineBotUserId startParameter:param
		                      completion:^(int64_t chatId){
			TGChatViewController *me = weakSelf;
			if (!me || !chatId)
				return;
			TGChatViewController *vc = [[TGChatViewController alloc] init];
			vc.chatId = chatId;
			vc.chatTitle = me.inlineBotName ?: @"Bot";
			vc.hidesBottomBarWhenPushed = YES;
			[me.navigationController pushViewController:vc animated:YES];
		}];
	}
}

- (void)inlineBotResultTapped:(UIButton *)btn {
	NSInteger index = btn.tag;
	if (index < 0 || index >= (NSInteger)self.inlineBotResults.count)
		return;
	NSDictionary *item = self.inlineBotResults[(NSUInteger)index];
	NSString *resultId = item[@"id"];
	if (resultId.length && self.inlineBotQueryId) {
		[[TGSendStore shared] sendInlineQueryResult:resultId
		                                    queryId:self.inlineBotQueryId
		                                     toChat:self.chatId
		                                     thread:self.threadId];
	}
	self.input.text = @"";
	[self clearComposeState];
	[self inputChanged];
	[self hideInlineBotResults];
}

@end
