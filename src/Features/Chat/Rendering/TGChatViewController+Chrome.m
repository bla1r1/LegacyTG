//
// TGChatViewController+Chrome.m - what sits around the messages rather than
// in them: day and unread separators, the floating date, the jump-down
// button, swipe to reply, and the animated "typing".
//
#import "TGDateFormat.h"
#import "TGTextDraw.h"
#import "TGChatViewControllerInternal.h"
#import "TGNameWithStatus.h"
#import <QuartzCore/QuartzCore.h>
#import "TGAlertSheet.h"
#import "TGStatusText.h"
#import "TGStyle.h"
#import "TGContactsViewController.h"
#import "TGNewContactViewController.h"
#import "TGGroupSettingsViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGChatParityModel.h"
#import "TGListViewController.h"
#import "TGDevShowcase.h"
#import "TGStatisticsViewController.h"
#import "TGChatListStore.h"
#import "TGRows.h"

static const CGFloat kJumpSide = TGMetricJumpSide;
/// The widest the unread count on the jump button goes before it truncates.
static const CGFloat kJumpBadgeMaxW    = 60.0f;
/// The arrow that appears while a bubble is dragged to be replied to.
static const CGFloat kReplyHintGlyph   = 20.0f;
static const CGFloat kReplyHintInset   = 24.0f;

@implementation TGChatViewController (Chrome)

#pragma mark - separators

/// "Today", "5 November", "5 November 2026" - how the day plates and the
/// floating date read. The month word and its order come from the pack, not
/// the device locale or a hardcoded English order.
static NSString *TGDayTitle(NSTimeInterval stamp) {
	return TGChatDayTitle(stamp, [[NSDate date] timeIntervalSince1970]);
}

- (NSArray *)messagesWithSeparators:(NSArray *)grouped {
	if (!grouped.count)
		return grouped;
	NSMutableArray *out = [NSMutableArray arrayWithCapacity:grouped.count + 8];
	long lastDay = -1;
	for (NSDictionary *m in grouped){
		NSTimeInterval stamp = [m[@"date"] doubleValue];
		if (stamp > 0){
			long dayNumber = TGFastDayNumber((time_t)stamp);
			if (dayNumber != lastDay){
				lastDay = dayNumber;
				[out addObject:@{@"service" : @YES, @"separator" : @"day",
								 @"text" : TGDayTitle(stamp), @"date" : m[@"date"]}];
			}
		}
		if (self.unreadFromId && [m[@"id"] longLongValue] == self.unreadFromId)
			[out addObject:@{@"service" : @YES, @"separator" : @"unread",
							 @"text" : @"Unread Messages", @"date" : m[@"date"] ?: @0}];
		[out addObject:m];
	}
	return out;
}

/// The first message that arrived after you last read the chat, captured
/// once as it opens so it stays put while you read.
- (void)noteFirstUnreadIn:(NSArray *)raw {
	if (self.unreadChecked)
		return;
	self.unreadChecked = YES;
	if (self.readInboxAtOpen <= 0)
		return;
	for (NSDictionary *m in raw){
		if (![m[@"outgoing"] boolValue] && ![m[@"service"] boolValue] &&
			[m[@"id"] longLongValue] > self.readInboxAtOpen){
			self.unreadFromId = [m[@"id"] longLongValue];
			return;
		}
	}
}

- (NSInteger)unreadSeparatorRow {
	for (NSUInteger i = 0; i < self.messages.count; i++)
		if ([self.messages[i][@"separator"] isEqualToString:@"unread"])
			return (NSInteger)i;
	return NSNotFound;
}

#pragma mark - the bar over a chat nobody has spoken to

static const CGFloat kActionBarCloseSide = TGMetricButtonLargeH;

/// The chat dict row of the open chat, read fresh: the bar follows the chat,
/// so its kind and words are re-derived on every pass rather than stored.
- (NSDictionary *)actionBarRow {
#if TG_DEV
	// Dev Bot stands for a chat a Business bot answers in.
	if (self.chatId == kDevBotChatId)
		return @{@"id" : @(kDevBotChatId), @"businessBot" : @{@"botId" : @10001,
				 @"paused" : @NO, @"canReply" : @YES, @"manageUrl" : @"https://t.me/devbot"}};
	// The private showcase chat stands for a stranger's archived chat.
	if (self.chatId == kDevDurovChatId)
		return @{@"id" : @(kDevDurovChatId), @"actionBarKind" : @"chatActionBarReportAddBlock",
				 @"actionBarCanUnarchive" : @YES,
				 @"actionBarAccount" : @{@"registrationMonth" : @3, @"registrationYear" : @2021,
					@"country" : @"AE", @"nameChanged" : @([[NSDate date] timeIntervalSince1970] - 3 * 86400),
					@"photoChanged" : @0}};
#endif
	for (NSDictionary *chat in [TGMessageStore shared].chats)
		if ([chat[@"id"] longLongValue] == self.chatId)
			return chat;
	return nil;
}

/// The bar Telegram puts over a chat the account has never spoken to: report
/// spam over a stranger, add to contacts, share a phone number. It rides the
/// composer the way the reply banner does, and the X is not a hiding - it is
/// the removeChatActionBar request.
/// Official's ChatUserInfoItem over the history of a chat with someone who
/// is not a contact: their name, "Not a contact", the phone's country, the
/// month they joined, and whether they changed name or photo lately. Built
/// from the action bar's accountInfo; gone once the bar is.
- (void)refreshNewContactCard {
	NSDictionary *account = self.isGroup ? nil : [self actionBarRow][@"actionBarAccount"];
	NSString *code = [account[@"country"] isKindOfClass:NSString.class] ? account[@"country"] : @"";
	NSString *language = TGAppLanguage();
	NSLocale *locale = language.length ? [NSLocale localeWithLocaleIdentifier:language] : [NSLocale currentLocale];
	NSString *country = code.length ? [locale displayNameForKey:NSLocaleCountryCode value:code] : nil;
	NSArray *rows = TGNewContactCardRows(account, country, [[NSDate date] timeIntervalSince1970]);
	if (!rows.count){
		if (self.table.tableHeaderView)
			self.table.tableHeaderView = nil;
		return;
	}
	TGTheme *theme = [TGTheme shared];
	CGFloat width = self.table.bounds.size.width;
	CGFloat plateW = MIN(width - TGDoubled(TGMetricGutter), kBubbleMaxW);
	CGFloat lineH = TGMetricLineCaption + TGMetricPadTiny;
	CGFloat plateH = TGDoubled(TGMetricPadMedium) + lineH * (rows.count + 2) + TGMetricPadSmall;
	UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, plateH + TGDoubled(TGMetricPad))];
	header.backgroundColor = [UIColor clearColor];
	UIView *plate = [[UIView alloc] initWithFrame:CGRectMake(TGCenteredOrigin(width, plateW),
			TGMetricPad, plateW, plateH)];
	plate.backgroundColor = [theme serviceBubbleColour];
	plate.layer.cornerRadius = TGMetricCornerControl;
	[header addSubview:plate];
	CGFloat y = TGMetricPadMedium;
	NSMutableArray *lines = [NSMutableArray arrayWithObjects:@[self.chatTitle ?: @""],
			@[TGLocalized(@"Not a contact")], nil];
	[lines addObjectsFromArray:rows];
	for (NSUInteger i = 0; i < lines.count; i++){
		NSArray *line = lines[i];
		UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(TGMetricPadMedium, y,
				plateW - TGDoubled(TGMetricPadMedium), lineH)];
		label.backgroundColor = [UIColor clearColor];
		label.textColor = [theme serviceTextColour];
		label.textAlignment = NSTextAlignmentCenter;
		label.font = i == 0 ? TGFontCaptionStrong() : TGFontCaption();
		label.text = line.count > 1 ? [NSString stringWithFormat:@"%@: %@", line[0], line[1]] : line[0];
		[plate addSubview:label];
		y += lineH + (i == 1 ? TGMetricPadSmall : TGMetricZero);
	}
	self.table.tableHeaderView = header;
}

- (void)refreshActionBar {
	[self refreshNewContactCard];
	NSString *kind = [self actionBarRow][@"actionBarKind"] ?: @"";
	// Admins see who waits at a request link in the same strip, as official's
	// ChatRequestsPanel, when TDLib has no bar of its own for the chat.
	NSInteger waiting = [[self actionBarRow][@"joinRequestCount"] integerValue];
	if (!kind.length && waiting > 0 && waiting != self.joinRequestsDismissedAt)
		kind = @"pendingJoinRequests";
	// A Business bot answering here keeps its own panel when no other bar
	// is up (ChatManagingBotTitlePanelNode).
	NSDictionary *bot = [self actionBarRow][@"businessBot"];
	if (!kind.length && [bot isKindOfClass:NSDictionary.class])
		kind = @"businessBot";
	// Only a bar coming up from hidden fades; an update to one already on
	// screen must not flash.
	BOOL reveal = !self.actionBarView || self.actionBarView.hidden;
	if (!kind.length){
		if (self.actionBarView && !self.actionBarView.hidden){
			self.actionBarView.hidden = YES;
			[self layoutChrome];
		}
		return;
	}

	if (!self.actionBarView){
		UIView *bar = [[UIView alloc] init];
		bar.backgroundColor = [[TGTheme shared] inputBarColour];
		bar.autoresizingMask = UIViewAutoresizingFlexibleWidth |
							   UIViewAutoresizingFlexibleTopMargin;

		UIView *hair = [[UIView alloc] initWithFrame:CGRectMake(0, 0,
				self.view.bounds.size.width, TGMetricBorderWidth)];
		hair.backgroundColor = [[TGTheme shared] separatorColour];
		hair.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[bar addSubview:hair];

		UILabel *say = [[UILabel alloc] init];
		say.font = TGFontCaption();
		say.textColor = [[TGTheme shared] secondaryTextColour];
		say.backgroundColor = [UIColor clearColor];
		self.actionBarLabel = say;
		[bar addSubview:say];

		TGTheme *theme = [TGTheme shared];

		UIButton *primary = [UIButton buttonWithType:UIButtonTypeCustom];
		primary.titleLabel.font = TGFontCaptionStrong();
		primary.tag = 1;
		[primary setTitleColor:[theme accentColour] forState:UIControlStateNormal];
		[primary addTarget:self action:@selector(actionBarPrimaryTapped)
			  forControlEvents:UIControlEventTouchUpInside];
		[bar addSubview:primary];

		UIButton *secondary = [UIButton buttonWithType:UIButtonTypeCustom];
		secondary.titleLabel.font = TGFontCaptionStrong();
		secondary.tag = 2;
		secondary.hidden = YES;
		[secondary setTitleColor:[theme accentColour] forState:UIControlStateNormal];
		[secondary addTarget:self action:@selector(actionBarSecondaryTapped)
			forControlEvents:UIControlEventTouchUpInside];
		[bar addSubview:secondary];

		UIButton *close = [UIButton buttonWithType:UIButtonTypeCustom];
		close.tag = 9;
		[close setImage:[TGIcons glyphNamed:@"close"
									 colour:[theme secondaryTextColour]
									   side:kBannerCloseGlyph]
				forState:UIControlStateNormal];
		[close addTarget:self action:@selector(actionBarClosed)
			forControlEvents:UIControlEventTouchUpInside];
		[bar addSubview:close];

		self.actionBarView = bar;
		[self.view addSubview:bar];
	}

	NSString *say = nil;
	NSString *primary = nil;
	NSString *secondary = nil;
	NSString *who = self.chatTitle ?: @"";
	// Official's bar carries action words only; the explanatory sentences
	// that used to sit beside them are not in that panel.
	// An archived chat from a stranger offers Unarchive where the contact
	// would be added (ChatReportPeerTitlePanelNode's autoArchived buttons).
	BOOL unarchive = [[self actionBarRow][@"actionBarCanUnarchive"] boolValue];
	if ([kind isEqualToString:@"chatActionBarReportAddBlock"]){
		primary = TGLocalized(@"Block User");
		secondary = unarchive ? TGLocalized(@"Unarchive")
				: ([who length] ? TGLocalizedFormat(@"Add %@ to Contacts", who)
								: TGLocalized(@"Add to Contacts"));
	}
	else if ([kind isEqualToString:@"chatActionBarReportSpam"]){
		primary = self.isChannel ? TGLocalized(@"Report Spam and Leave")
								 : TGLocalized(@"Report Spam");
		if (unarchive)
			secondary = TGLocalized(@"Unarchive");
	}
	else if ([kind isEqualToString:@"chatActionBarAddContact"]){
		primary = [who length] ? TGLocalizedFormat(@"Add %@ to Contacts", who)
							   : TGLocalized(@"Add to Contacts");
	}
	else if ([kind isEqualToString:@"chatActionBarSharePhoneNumber"]){
		primary = TGLocalized(@"Share My Phone Number");
	}
	else if ([kind isEqualToString:@"chatActionBarInviteMembers"]){
		primary = TGLocalized(@"Add Members");
	}
	else if ([kind isEqualToString:@"pendingJoinRequests"]){
		primary = TGLocalizedPlural(@"%d Request to Join", @"%d Requests to Join", waiting);
	}
	else if ([kind isEqualToString:@"businessBot"]){
		NSString *name = [[TGMessageStore shared] nameForUserId:[bot[@"botId"] longLongValue]] ?: @"";
		say = [NSString stringWithFormat:@"%@, %@", name, TGBusinessBotStatus(bot)];
		if ([bot[@"canReply"] boolValue])
			primary = [bot[@"paused"] boolValue] ? TGLocalized(@"START") : TGLocalized(@"STOP");
		if ([bot[@"manageUrl"] length])
			secondary = TGLocalized(@"Manage Bot");
	}
	else if ([kind isEqualToString:@"chatActionBarJoinRequest"]){
		// Official's panel names the admin and the chat; a tap on it says
		// when the request was sent, and "I understand" takes it away.
		NSString *title = [self actionBarRow][@"actionBarText"] ?: @"";
		say = [[self actionBarRow][@"actionBarIsChannel"] boolValue]
				? TGLocalizedFormat(@"%1$@ is an admin of %2$@, a channel you requested to join.", who, title)
				: TGLocalizedFormat(@"%1$@ is an admin of %2$@, a group you requested to join.", who, title);
		if (!self.actionBarView.gestureRecognizers.count)
			[self.actionBarView addGestureRecognizer:[[UITapGestureRecognizer alloc]
					initWithTarget:self action:@selector(joinRequestBarTapped)]];
	}
	else {
		say = kind;
	}

	self.actionBarLabel.text = say;
	if (reveal)
		self.actionBarView.alpha = TGAlphaTransparent;
	self.actionBarView.hidden = NO;
	[self positionActionBarButtons:primary secondary:secondary];
	[self layoutChrome];
	if (reveal)
		[UIView animateWithDuration:TGAnimationDurationFast animations:^{
			self.actionBarView.alpha = TGAlphaOpaque;
		}];
}

/// The buttons hang from the right, the X outermost; the label keeps what is
/// left of them. buttonTitle nil hides it.
- (void)positionActionBarButtons:(NSString *)primaryTitle secondary:(NSString *)secondaryTitle {
	CGFloat width = self.view.bounds.size.width;
	CGFloat height = kComposeBannerHeight;

	UIButton *close = nil;
	UIButton *primary = nil;
	UIButton *secondary = nil;
	for (UIView *sub in self.actionBarView.subviews)
		if ([sub isKindOfClass:[UIButton class]]){
			UIButton *button = (UIButton *)sub;
			if (button.tag == 9)      close = button;
			else if (button.tag == 1) primary = button;
			else if (button.tag == 2) secondary = button;
		}

	CGFloat x = width;
	close.frame = CGRectMake(x - kActionBarCloseSide, 0,
			kActionBarCloseSide, height);
	x -= kActionBarCloseSide;
	if (!x) return;

	for (UIButton *button in (@[primary, secondary])){
		NSString *title = (button == primary ? primaryTitle : secondaryTitle) ?: @"";
		if (!title.length){
			button.hidden = YES;
			continue;
		}
		button.hidden = NO;
		[button setTitle:title forState:UIControlStateNormal];
		CGFloat textWidth = TGLineTextSize(button.titleLabel.text,
				button.titleLabel.font ?: TGFontCaptionStrong()).width;
		if (textWidth <= 0.0f)
			textWidth = TGMetricRow;
		CGFloat side = MAX(TGMetricRow, textWidth) + TGMetricPadWide;   // TGMetricPad on either side
		button.frame = CGRectMake(x - side, 0, side, height);
		x -= side;
	}

	self.actionBarLabel.frame = CGRectMake(TGHalf(TGMetricGutter),
			TGCenteredOrigin(height, TGMetricLineSubhead),
			x - TGMetricGutter, TGMetricLineSubhead);
}

- (void)actionBarClosed {
	// Not a hiding: Telegram keeps offering the bar until it is told no.
	NSString *kind = [self actionBarRow][@"actionBarKind"] ?: @"";
	// The bot panel's X is official's "Remove bot from this chat".
	if (!kind.length && [[self actionBarRow][@"businessBot"] isKindOfClass:NSDictionary.class]){
		__weak typeof(self) weakSelf = self;
		[TGAlertSheet showConfirm:nil title:TGLocalized(@"Remove bot from this chat")
						   action:TGLocalized(@"Remove bot from this chat") destructive:YES
						   inView:self.view
						onConfirm:^{ [[TGMessageStore shared] removeBusinessBotFromChat:weakSelf.chatId]; }];
		return;
	}
	if (kind.length)
		[[TGMessageStore shared] removeActionBarInChat:self.chatId];
	else
		self.joinRequestsDismissedAt = [[self actionBarRow][@"joinRequestCount"] integerValue];
	[self refreshActionBar];
	// The dictionary still holds the kind until the update lands; say so
	// locally too, because the bar must not sit over an already-dismissed one.
	for (NSDictionary *chat in [TGMessageStore shared].chats)
		if ([chat[@"id"] longLongValue] == self.chatId){
			[self refreshActionBar];
			break;
		}
}

/// Straight answers only: the reasons reportChat hands back are looked at,
/// and the spam one is what a bar is for - asked about first, sent after.
- (void)actionBarPrimaryTapped {
	NSString *kind = [self actionBarRow][@"actionBarKind"] ?: @"";
	if ([kind isEqualToString:@"chatActionBarJoinRequest"]){
		[self joinRequestBarTapped];
		return;
	}
	NSDictionary *bot = [self actionBarRow][@"businessBot"];
	if (!kind.length && [bot isKindOfClass:NSDictionary.class]){
		[[TGMessageStore shared] setBusinessBotPaused:![bot[@"paused"] boolValue] inChat:self.chatId];
		return;
	}
	if (!kind.length && [[self actionBarRow][@"joinRequestCount"] integerValue] > 0){
		TGGroupSettingsViewController *settings = [[TGGroupSettingsViewController alloc] init];
		settings.chatId = self.chatId;
		settings.chatTitle = self.chatTitle;
		[self.navigationController pushViewController:settings animated:YES];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)),
				dispatch_get_main_queue(), ^{ [settings showJoinRequests]; });
		return;
	}
	if ([kind isEqualToString:@"chatActionBarReportAddBlock"]){
		[self blockActionBarUser];
		return;
	}
	if ([kind isEqualToString:@"chatActionBarAddContact"]){
		[self pushNewContactFromActionBar];
		return;
	}
	if ([kind isEqualToString:@"chatActionBarInviteMembers"]){
		TGContactsViewController *contacts = [[TGContactsViewController alloc] init];
		contacts.addingToChatId = self.chatId;
		self.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:contacts animated:YES];
		return;
	}
	if ([kind isEqualToString:@"chatActionBarSharePhoneNumber"]){
		NSString *who = self.chatTitle ?: @"them";
		__weak typeof(self) weakSelf = self;
		[TGAlertSheet showConfirm:TGLocalizedFormat(@"%@ can now see your phone number.", who)
							title:@"Share" action:@"Share" destructive:NO
						   inView:self.view
						onConfirm:^{
			int64_t userId = weakSelf.isGroup ? 0 : weakSelf.chatId;
			[[TGMessageStore shared] sharePhoneNumberWithUser:userId];
		}];
		return;
	}
	// A report of either kind. The reasons are one round trip; the bar's
	// report is the spam reason, which Telegram names among the options.
	NSString *who = self.chatTitle ?: @"this chat";
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:(self.isGroup
						? TGLocalized(@"Are you sure you want to report this group for spam?")
						: TGLocalized(@"Are you sure you want to report spam from this user?"))
						title:@"Report" action:@"Report" destructive:NO
					   inView:self.view
					onConfirm:^{
		[[TGMessageStore shared] reportChat:weakSelf.chatId
							   optionId:nil
								  text:@""
							completion:^(NSString *title, NSArray *options, BOOL done){
			TGChatViewController *me = weakSelf;
			if (!me)
				return;
			NSString *spamOption = nil;
			for (NSDictionary *option in options){
				NSString *optionId = [option[@"id"] isKindOfClass:NSString.class]
						? option[@"id"] : @"";
				if ([optionId.lowercaseString rangeOfString:@"spam"].location != NSNotFound){
					spamOption = option[@"id"];
					break;
				}
			}
			// The reason text is localised and cannot be matched by the word
			// "spam"; the first option is Telegram's spam reason.
			if (!spamOption && options.count)
				spamOption = options.firstObject[@"id"];
			if (!spamOption){
				[TGAlertSheet showMessage:@"An error occurred."
									title:@"Report" inView:me.view];
				return;
			}
			[[TGMessageStore shared] reportChat:me.chatId optionId:spamOption text:@""
							   completion:^(NSString *t, NSArray *o, BOOL d){
				if (d && weakSelf)
					[weakSelf actionBarClosed];
			}];
		}];
	}];
}

/// Official's join-request panel: why a message from this admin is here
/// and the day the request went out.
- (void)joinRequestBarTapped {
	NSDictionary *row = [self actionBarRow];
	if (![row[@"actionBarKind"] isEqualToString:@"chatActionBarJoinRequest"])
		return;
	double date = [row[@"actionBarRequestDate"] doubleValue];
	NSString *day = date > 0 ? TGAppDate(date, NSDateFormatterMediumStyle, NSDateFormatterNoStyle) : @"";
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:TGJoinRequestInfoText(row[@"actionBarText"], day)
						title:nil action:TGLocalized(@"I understand") destructive:NO
					   inView:self.view
					onConfirm:^{ [weakSelf actionBarClosed]; }];
}

- (void)actionBarSecondaryTapped {
	NSDictionary *bot = [self actionBarRow][@"businessBot"];
	if (![[self actionBarRow][@"actionBarKind"] length] && [bot[@"manageUrl"] length]){
		[self handleOpenLink:bot[@"manageUrl"]];
		return;
	}
	if ([[self actionBarRow][@"actionBarCanUnarchive"] boolValue]){
		[[TGChatListStore shared] setChat:self.chatId archived:NO];
		[self actionBarClosed];
		[TGSnackbar showInView:self.view text:TGLocalized(@"The chat was moved to your main list.")
					   seconds:2 onCommit:nil];
		return;
	}
	if ([[self actionBarRow][@"actionBarKind"] isEqualToString:@"chatActionBarReportAddBlock"]){
		[self pushNewContactFromActionBar];
		return;
	}
	[self blockActionBarUser];
}

- (void)blockActionBarUser {
	int64_t userId = self.isGroup ? 0 : self.chatId;
	if (!userId)
		return;
	NSString *who = self.chatTitle ?: TGLocalized(@"Someone");
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:TGLocalizedFormat(@"Block %@", who)
						title:@"Block" action:TGLocalized(@"Block User") destructive:YES
					   inView:self.view
					onConfirm:^{
		[[TGMessageStore shared] blockUserWithUserId:userId];
		[weakSelf actionBarClosed];
	}];
}

/// A new contact out of the bar: the form starts from the chat's name.
/// accountInfo carries no name or phone, only the dates the card above the
/// history shows, so the old fields here were always empty.
- (void)pushNewContactFromActionBar {
	TGNewContactViewController *form = [[TGNewContactViewController alloc] init];
	NSString *name = self.chatTitle ?: @"";
	NSString *first = [name componentsSeparatedByString:@" "].firstObject;
	form.first = first ?: @"";
	form.last = name.length ? [name substringFromIndex:MIN((NSUInteger)first.length + 1, name.length)] : @"";
	form.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:form animated:YES];
}

#pragma mark - floating date and jump button

- (void)buildChrome {
	TGTheme *theme = [TGTheme shared];

	self.floatingDate = [[UILabel alloc] init];
	// Clear, or iOS 6 paints the label's default white box.
	self.floatingDate.backgroundColor = [UIColor clearColor];
	self.floatingDate.font = TGFontCaptionStrong();
	self.floatingDate.textAlignment = NSTextAlignmentCenter;
	// Rounded by its background alone. Every view over the table is drawn
	// again on each frame of a scroll, so a clip or a path-less shadow here
	// costs an offscreen pass per frame - backboardd, not this app, pays.
	self.floatingDate.layer.cornerRadius = TGHalf(TGMetricFloatingDateHeight);
	self.floatingDate.alpha = 0;
	self.floatingDate.userInteractionEnabled = NO;
	[self.view addSubview:self.floatingDate];

	self.jumpButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.jumpButton.frame = CGRectMake(0, 0, kJumpSide, kJumpSide);
	self.jumpButton.layer.cornerRadius = TGHalf(kJumpSide);
	self.jumpButton.layer.shadowColor = [UIColor blackColor].CGColor;
	self.jumpButton.layer.shadowOpacity = TGMetricShadowButtonOpacity;
	self.jumpButton.layer.shadowRadius = TGMetricShadowButtonRadius;
	self.jumpButton.layer.shadowOffset = TGMetricShadowOffsetEtched;
	self.jumpButton.layer.shadowPath = [UIBezierPath bezierPathWithOvalInRect:
			self.jumpButton.bounds].CGPath;
	self.jumpButton.hidden = YES;
	[self.jumpButton addTarget:self action:@selector(jumpTapped)
			  forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:self.jumpButton];

	self.mentionsJumpButton = [self unreadJumpButtonWithAction:@selector(mentionsJumpTapped)];
	self.reactionsJumpButton = [self unreadJumpButtonWithAction:@selector(reactionsJumpTapped)];
	self.pollVotesJumpButton = [self unreadJumpButtonWithAction:@selector(pollVotesJumpTapped)];

	self.jumpBadge = [[UILabel alloc] init];
	self.jumpBadge.backgroundColor = [[TGTheme shared] badgeColour];
	self.jumpBadge.font = TGFontCaptionStrong();
	self.jumpBadge.textColor = [[TGTheme shared] onAccentColour];
	self.jumpBadge.textAlignment = NSTextAlignmentCenter;
	self.jumpBadge.layer.cornerRadius = TGHalf(TGMetricJumpBadgeHeight);
	self.jumpBadge.hidden = YES;
	[self.jumpButton addSubview:self.jumpBadge];

	if (!self.titleStatusIcon && self.titleNameLabel.superview){
		self.titleStatusIcon = [[UIImageView alloc] init];
		self.titleStatusIcon.contentMode = UIViewContentModeScaleAspectFit;
		self.titleStatusIcon.hidden = YES;
		[self.titleNameLabel.superview addSubview:self.titleStatusIcon];
	}
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(chromeCustomEmojiLoaded:)
												 name:TGCustomEmojiLoadedNotification
											   object:nil];

	[self applyChromeTheme:theme];
	[self layoutChrome];
}

static const NSInteger kUnreadJumpBadgeTag = 0x9101;

/// The down button's twin: the same disc and shadow, a glyph and a badge.
- (UIButton *)unreadJumpButtonWithAction:(SEL)action {
	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	button.frame = CGRectMake(0, 0, kJumpSide, kJumpSide);
	button.layer.cornerRadius = TGHalf(kJumpSide);
	button.layer.shadowColor = [UIColor blackColor].CGColor;
	button.layer.shadowOpacity = TGMetricShadowButtonOpacity;
	button.layer.shadowRadius = TGMetricShadowButtonRadius;
	button.layer.shadowOffset = TGMetricShadowOffsetEtched;
	button.layer.shadowPath = [UIBezierPath bezierPathWithOvalInRect:button.bounds].CGPath;
	button.hidden = YES;
	[button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
	UILabel *badge = [[UILabel alloc] init];
	badge.tag = kUnreadJumpBadgeTag;
	badge.backgroundColor = [[TGTheme shared] badgeColour];
	badge.font = TGFontCaptionStrong();
	badge.textColor = [[TGTheme shared] onAccentColour];
	badge.textAlignment = NSTextAlignmentCenter;
	badge.layer.cornerRadius = TGHalf(TGMetricJumpBadgeHeight);
	[button addSubview:badge];
	[self.view addSubview:button];
	return button;
}

- (void)refreshUnreadJumps {
#if TG_DEV
	if (TGIsDevChat(self.chatId)){
		self.unreadMentionJumps = 3;
		self.unreadReactionJumps = 2;
		self.unreadPollVoteJumps = 1;
		[self layoutUnreadJumps];
		return;
	}
#endif
	__weak typeof(self) weakSelf = self;
	[[TGMessageStore shared] unreadJumpCountsForChat:self.chatId
										  completion:^(NSInteger mentions, NSInteger reactions, NSInteger pollVotes){
		TGChatViewController *me = weakSelf;
		me.unreadMentionJumps = mentions;
		me.unreadReactionJumps = reactions;
		me.unreadPollVoteJumps = pollVotes;
		[me layoutUnreadJumps];
	}];
}

/// Stacked over the down arrow, which takes the lowest place while it
/// shows; each button keeps its own badge.
- (void)layoutUnreadJumps {
	if (!self.reactionsJumpButton)
		return;
	BOOL down = !self.jumpButton.hidden && self.jumpButton.alpha > TGAlphaEpsilon;
	CGFloat mentionsY, reactionsY, pollY;
	TGChatNavigationButtonOffsets(down, self.unreadMentionJumps, self.unreadReactionJumps,
			self.unreadPollVoteJumps, kJumpSide + TGMetricPadMedium, &mentionsY, &reactionsY, &pollY);
	CGRect base = self.jumpButton.frame;
	UIButton *buttons[3] = {self.mentionsJumpButton, self.reactionsJumpButton, self.pollVotesJumpButton};
	CGFloat offsets[3] = {mentionsY, reactionsY, pollY};
	NSInteger counts[3] = {self.unreadMentionJumps, self.unreadReactionJumps, self.unreadPollVoteJumps};
	for (int i = 0; i < 3; i++){
		UIButton *button = buttons[i];
		button.hidden = offsets[i] < 0;
		if (button.hidden)
			continue;
		button.frame = CGRectOffset(base, 0, -offsets[i]);
		UILabel *badge = (UILabel *)[button viewWithTag:kUnreadJumpBadgeTag];
		badge.text = [NSString stringWithFormat:@"%ld", (long)counts[i]];
		CGSize size = [badge sizeThatFits:CGSizeMake(kJumpBadgeMaxW, TGMetricJumpBadgeHeight)];
		CGFloat bw = MAX(TGMetricJumpBadgeHeight, ceilf(size.width) + TGMetricPadMedium);
		badge.frame = CGRectMake(TGCenteredOrigin(kJumpSide, bw), TGMetricBadgeOffsetTop,
				bw, TGMetricJumpBadgeHeight);
	}
}

/// Official goes to the oldest unread one and lets the list report it seen.
- (void)jumpToOldestUnread:(NSString *)filter {
	__weak typeof(self) weakSelf = self;
	[[TGMessageStore shared] oldestUnreadMessageInChat:self.chatId filter:filter
											completion:^(int64_t messageId){
		if (messageId)
			[weakSelf jumpToReplyById:messageId];
		else
			[weakSelf refreshUnreadJumps];
	}];
}

- (void)mentionsJumpTapped {
	[self jumpToOldestUnread:@"searchMessagesFilterUnreadMention"];
}

- (void)reactionsJumpTapped {
	[self jumpToOldestUnread:@"searchMessagesFilterUnreadReaction"];
}

- (void)pollVotesJumpTapped {
	[self jumpToOldestUnread:@"searchMessagesFilterUnreadPollVote"];
}

/// TDLib marks a reaction or a vote read when its message is viewed; rows
/// the list only scrolls past were never reported, so the counter stuck.
- (void)noteUnreadMarksOfMessage:(NSDictionary *)m {
	if (![m[@"unreadReactions"] integerValue] && ![m[@"unreadPollVotes"] boolValue] &&
		![m[@"unreadMention"] boolValue])
		return;
	NSNumber *messageId = m[@"id"];
	if (![messageId isKindOfClass:NSNumber.class] || [self.unreadMarksSeen containsObject:messageId] ||
		[TGChatViewController activeChatId] != self.chatId)
		return;
	if (!self.unreadMarksSeen)
		self.unreadMarksSeen = [NSMutableSet set];
	[self.unreadMarksSeen addObject:messageId];
	[[TGMessageStore shared] markRead:@[messageId] inChat:self.chatId];
}

/// The jump button's chevron, from TGIconPaths.
static UIImage *TGJumpChevron(UIColor *colour) {
	return [TGIcons glyphNamed:@"chevronDown" colour:colour
						  side:TGMetricStampTicksRoom];
}

- (void)applyChromeTheme:(TGTheme *)theme {
	self.floatingDate.backgroundColor = [theme serviceBubbleColour];
	self.floatingDate.textColor = [theme serviceTextColour];
	self.jumpButton.backgroundColor = [theme inputBarColour];
	[self.jumpButton setImage:TGJumpChevron([theme secondaryTextColour]) forState:UIControlStateNormal];
	self.jumpBadge.backgroundColor = [theme badgeColour];
	NSString *glyphs[3] = {@"mention", @"heart", @"poll"};
	UIButton *jumps[3] = {self.mentionsJumpButton, self.reactionsJumpButton, self.pollVotesJumpButton};
	for (int i = 0; i < 3; i++){
		jumps[i].backgroundColor = [theme inputBarColour];
		[jumps[i] setImage:[TGIcons glyphNamed:glyphs[i] colour:[theme secondaryTextColour]
										  side:TGMetricStampTicksRoom]
				  forState:UIControlStateNormal];
		[jumps[i] viewWithTag:kUnreadJumpBadgeTag].backgroundColor = [theme badgeColour];
	}

	if (self.actionBarView){
		self.actionBarView.backgroundColor = [theme inputBarColour];
		self.actionBarLabel.textColor = [theme secondaryTextColour];
		for (UIView *sub in self.actionBarView.subviews){
			if ([sub isKindOfClass:[UIButton class]]){
				UIButton *button = (UIButton *)sub;
				[button setTitleColor:[theme accentColour] forState:UIControlStateNormal];
				if (button.tag == 9)
					[button setImage:[TGIcons glyphNamed:@"close"
												  colour:[theme secondaryTextColour]
													side:kBannerCloseGlyph]
							forState:UIControlStateNormal];
			}
		}
	}
}

/// Both hang off the table's frame, which moves with the keyboard and the
/// panel; called from wherever that frame changes.
- (void)layoutChrome {
	[self updateTitleEmojiStatus];
	CGRect table = self.table.frame;
	// The pinned strip lives at the top, the report / add-contact bar below
	// it, and the table clears both. The pinned code also adjusts the inset
	// when it appears and leaves; writing the sum here keeps the two from
	// counting each other twice.
	BOOL hasPinned = self.pinnedBannerView && !self.pinnedBannerView.hidden;
	CGFloat pinnedH = hasPinned ? kPinnedBanner : TGMetricZero;
	if (self.pinnedBannerView)
		self.pinnedBannerView.frame = CGRectMake(0, 0,
				self.view.bounds.size.width, kPinnedBanner);
	BOOL hasActionBar = self.actionBarView && !self.actionBarView.hidden;
	CGFloat actionH = hasActionBar ? kComposeBannerHeight : TGMetricZero;
	if (self.actionBarView){
		self.actionBarView.frame = CGRectMake(0, pinnedH,
				self.view.bounds.size.width, actionH);
	}
	UIEdgeInsets insets = self.table.contentInset;
	insets.top = pinnedH + actionH;
	self.table.contentInset = insets;
	self.table.scrollIndicatorInsets = insets;
	// Clear of the reply / edit strip when one is showing over the table. The
	// strip rides directly on the composer, so it has to be placed here rather
	// than where it was built: the keyboard moves the bar out from under it.
	CGFloat bottom = CGRectGetMaxY(table);
	if (self.composeBanner && !self.composeBanner.hidden &&
		CGAffineTransformIsIdentity(self.composeBanner.transform)){
		self.composeBanner.frame = TGChatComposeBannerPlace(self.view.bounds.size.width,
				CGRectGetMinY(self.inputBar.frame), NO).plate;
		bottom = MIN(bottom, CGRectGetMinY(self.composeBanner.frame));
	}
	self.jumpButton.frame = CGRectMake(CGRectGetMaxX(table) - kJumpSide - TGMetricJumpMarginRight,
									   bottom - kJumpSide - TGMetricJumpMarginBottom, kJumpSide, kJumpSide);
	CGSize badge = [self.jumpBadge sizeThatFits:CGSizeMake(kJumpBadgeMaxW,
			TGMetricJumpBadgeHeight)];
	CGFloat bw = MAX(18, ceilf(badge.width) + TGMetricPadMedium);
	self.jumpBadge.frame = CGRectMake(TGCenteredOrigin(kJumpSide, bw),
			TGMetricBadgeOffsetTop, bw, TGMetricJumpBadgeHeight);
	// The badge pokes out above the button.
	self.jumpButton.clipsToBounds = NO;
	[self layoutUnreadJumps];

	CGSize date = [self.floatingDate sizeThatFits:CGSizeMake(table.size.width,
			TGMetricFloatingDateHeight)];
	CGFloat dw = ceilf(date.width) + TGMetricPadWide;
	CGFloat top = self.table.contentInset.top;
	self.floatingDate.frame = CGRectMake(TGCenteredOrigin(table.size.width, dw), top + TGMetricFloatingDateTopOffset, dw,
			TGMetricFloatingDateHeight);
}

- (BOOL)isNearBottom {
	UIScrollView *s = self.table;
	CGFloat fromBottom = s.contentSize.height - (s.contentOffset.y + s.bounds.size.height);
	return fromBottom < TGHalf(s.bounds.size.height);
}

- (void)updateJumpButton {
	BOOL show = ![self isNearBottom] && self.messages.count > 0;
	if (show){
		// Mid-fade counts as hidden, so an unread landing during the fade in
		// starts it again instead of being swallowed by the early return.
		if (!self.jumpButton.hidden && self.jumpButton.alpha > TGAlphaEpsilon)
			return;
		BOOL wasHidden = self.jumpButton.hidden;
		self.jumpButton.hidden = NO;
		if (wasHidden){
			self.jumpButton.alpha = TGAlphaTransparent;
			self.jumpButton.transform = CGAffineTransformMakeScale(
					TGTransformScaleMenuInitial, TGTransformScaleMenuInitial);
		}
		[UIView animateWithDuration:TGAnimationDurationFast animations:^{
			self.jumpButton.alpha = TGAlphaOpaque;
			self.jumpButton.transform = CGAffineTransformIdentity;
			[self layoutUnreadJumps];
		}];
		return;
	}

	// Already fading out: a second animation per scrolled row would stack up.
	if (self.jumpButton.hidden || self.jumpButton.alpha < TGAlphaEpsilon)
		return;
	__weak typeof(self) weakSelf = self;
	[UIView animateWithDuration:TGAnimationDurationFast animations:^{
		self.jumpButton.alpha = TGAlphaTransparent;
		self.jumpButton.transform = CGAffineTransformMakeScale(
				TGTransformScaleMenuInitial, TGTransformScaleMenuInitial);
	} completion:^(BOOL finished){
		TGChatViewController *me = weakSelf;
		// The button came back while this ran; its own animation owns it now.
		if (!me || me.jumpButton.alpha > TGAlphaEpsilon)
			return;
		me.jumpButton.hidden = YES;
		me.jumpButton.transform = CGAffineTransformIdentity;
		me.newWhileAway = 0;
		me.jumpBadge.hidden = YES;
		[UIView animateWithDuration:TGAnimationDurationFast animations:^{
			[me layoutUnreadJumps];
		}];
	}];
}

- (void)noteArrivedWhileAway {
	BOOL first = self.jumpBadge.hidden;
	self.newWhileAway++;
	self.jumpBadge.text = [NSString stringWithFormat:@"%ld", (long)self.newWhileAway];
	self.jumpBadge.hidden = NO;
	[self layoutChrome];

	// Only the first count gets the pop; later increments would make the
	// badge twitch on every message while the list sits away.
	if (!first)
		return;
	CAKeyframeAnimation *pop = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
	pop.values = @[ @(TGTransformScaleMenuInitial), @(TGTransformScalePillActive), @(1.0) ];
	pop.keyTimes = @[ @0.0, @0.5, @1.0 ];
	pop.duration = TGAnimationDurationFast;
	pop.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
	[self.jumpBadge.layer addAnimation:pop forKey:@"badgePop"];
}

- (void)jumpTapped {
	self.newWhileAway = 0;
	self.jumpBadge.hidden = YES;
	[self scrollToBottomAnimated:YES];
}

- (void)updateFloatingDate {
	NSArray *visible = [self.table indexPathsForVisibleRows];
	if (!visible.count)
		return;
	NSIndexPath *first = visible.firstObject;
	for (NSIndexPath *path in visible)
		if (path.row < first.row)
			first = path;
	if (first.row >= (NSInteger)self.messages.count)
		return;
	NSTimeInterval stamp = [self.messages[first.row][@"date"] doubleValue];
	if (stamp <= 0)
		return;
	NSString *title = TGDayTitle(stamp);
	if (![self.floatingDate.text isEqualToString:title]){
		self.floatingDate.text = title;
		[self layoutChrome];
	}
}

- (void)chromeDidScroll {
	[self updateJumpButton];
	if (self.table.isDragging || self.table.isDecelerating){
		[self updateFloatingDate];
		if (self.floatingDate.alpha < 1){
			[UIView animateWithDuration:TGAnimationDurationFast animations:^{ self.floatingDate.alpha = 1; }];
		}
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(fadeFloatingDate) object:nil];
	}
}

- (void)chromeDidStopScrolling {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(fadeFloatingDate) object:nil];
	[self performSelector:@selector(fadeFloatingDate) withObject:nil afterDelay:1.0];
}

- (void)fadeFloatingDate {
	[UIView animateWithDuration:TGAnimationDurationSlow animations:^{ self.floatingDate.alpha = 0; }];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
	if (scrollView == self.table && !decelerate){
		[self chromeDidStopScrolling];
		// A finger held still and lifted sends no scroll event, and the timer
		// set by the last one found the table still dragging and gave up.
		[self resumeGifAutoplayAfterScrolling];
	}
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
	if (scrollView == self.table)
		[self chromeDidStopScrolling];
}

#pragma mark - swipe to reply

static const CGFloat kReplyPull = TGMetricReplyPull;   // how far a bubble travels before it counts

- (void)installSwipeToReply {
	UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
			initWithTarget:self action:@selector(replyPan:)];
	pan.delegate = self;
	[self.table addGestureRecognizer:pan];
	// Vertical drags must still scroll at once; this one decides within a
	// few points whether it is horizontal and gives up otherwise.
	if ([self.table respondsToSelector:@selector(panGestureRecognizer)])
		[self.table.panGestureRecognizer requireGestureRecognizerToFail:pan];
	self.replyPanRecognizer = pan;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture {
	if (gesture != self.replyPanRecognizer)
		return YES;
	if (self.isEditingMessages)
		return NO;
	UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gesture;
	CGPoint v = [pan velocityInView:self.table];
	if (v.x >= 0 || fabs(v.x) < fabs(v.y) * TGDampingReplySwipeSlope)
		return NO;
	NSIndexPath *path = [self.table indexPathForRowAtPoint:[pan locationInView:self.table]];
	if (!path || path.row >= (NSInteger)self.messages.count)
		return NO;
	NSDictionary *m = self.messages[path.row];
	return ![m[@"service"] boolValue] && [m[@"id"] longLongValue] != 0;
}

- (void)replyPan:(UIPanGestureRecognizer *)pan {
	if (pan.state == UIGestureRecognizerStateBegan){
		NSIndexPath *path = [self.table indexPathForRowAtPoint:[pan locationInView:self.table]];
		UITableViewCell *cell = path ? [self.table cellForRowAtIndexPath:path] : nil;
		if (!cell)
			return;
		self.replySwipeCell = cell;
		self.replySwipeRow = path.row;

		if (!self.replyHint){
			CGFloat side = 30;
			self.replyHint = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, side, side)];
			self.replyHint.layer.cornerRadius = TGHalf(side);
			self.replyHint.contentMode = UIViewContentModeCenter;
		}
		TGTheme *theme = [TGTheme shared];
		self.replyHint.backgroundColor = [theme serviceBubbleColour];
		self.replyHint.image = [TGIcons glyphNamed:@"reply" colour:[theme serviceTextColour]
										  side:kReplyHintGlyph];
		self.replyHint.alpha = TGAlphaTransparent;
		self.replyHint.center = CGPointMake(cell.bounds.size.width - kReplyHintInset,
			TGHalf(cell.bounds.size.height));
		[cell addSubview:self.replyHint];
		return;
	}

	UITableViewCell *cell = self.replySwipeCell;
	if (!cell)
		return;
	CGFloat dx = MIN(0, [pan translationInView:self.table].x);
	// Past the threshold it resists, the way theirs does.
	CGFloat shown = dx > -kReplyPull ? dx : -kReplyPull + (dx + kReplyPull) * TGDampingRubberband;

	if (pan.state == UIGestureRecognizerStateChanged){
		cell.contentView.transform = CGAffineTransformMakeTranslation(shown, 0);
		self.replyHint.alpha = MIN(1, -dx / kReplyPull);
		CGFloat scale = TGTransformScaleReplyMin + TGTransformScaleReplyRange * self.replyHint.alpha;
		self.replyHint.transform = CGAffineTransformMakeScale(scale, scale);
		return;
	}

	BOOL commit = pan.state == UIGestureRecognizerStateEnded && dx <= -kReplyPull;
	NSInteger row = self.replySwipeRow;
	self.replySwipeCell = nil;
	[UIView animateWithDuration:TGAnimationDurationNormal animations:^{
		cell.contentView.transform = CGAffineTransformIdentity;
		self.replyHint.alpha = 0;
	} completion:^(BOOL finished){
		[self.replyHint removeFromSuperview];
	}];
	if (commit && row < (NSInteger)self.messages.count){
		self.actionMessage = self.messages[row];
		[self runMessageAction:@"Reply"];
	}
}

#pragma mark - subtitle ownership

/// Whose phrase the header subtitle carries: the network state first, then
/// the typing dots, then the resting last-seen. B4: a chat opened offline
/// used to sit at its captured status and never say "Waiting for network".
- (void)titleSubtitleOwnerChanged:(NSNotification *)note {
	[self updateTitleEmojiStatus];
	if ([TGMessageStore shared].connectionState == TGConnectionStateWaitingForNetwork){
		NSString *network = TGNetworkSubtitleForState(TGConnectionStateWaitingForNetwork, nil);
		self.networkSubtitle = network;
		self.titleSubtitleLabel.text = network;
		self.titleSubtitleLabel.textColor = [[TGTheme shared] barSubtitleColour];
		return;
	}

	self.networkSubtitle = nil;
	// A status notification asks for a fresh presence line; the old code
	// returned when no network line was handing back, so "online" froze
	// until the chat was reopened.
	if (note && TGChatStatusNotificationRefreshesPresence(note.name,
			self.isGroup, self.secretChatId != 0)){
		__weak typeof(self) weakSelf = self;
		[[TGMessageStore shared] statusForUser:self.chatId completion:^(NSString *status){
			TGChatViewController *me = weakSelf;
			if (!me || !status.length)
				return;
			me.restingSubtitle = status;
			[me titleSubtitleOwnerChanged:nil];
		}];
		return;
	}
	if (!self.typingTimer){
		NSString *resting = self.restingSubtitle ?: @"";
		if (resting.length){
			self.titleSubtitleLabel.text = resting;
			self.titleSubtitleLabel.textColor = [[TGTheme shared] barSubtitleColour];
		}
	}
	// A live typing timer re-writes the line on its own tick.
}

#pragma mark - secret chats

/// A secret chat lives or dies by its state: "pending" until the other
/// device has answered the exchange, spent when closed. The state is the
/// resting subtitle, and an update mid-chat re-runs this line.
- (void)refreshSecretState {
	__weak typeof(self) weakSelf = self;
	NSInteger secretId = self.secretChatId;
	if (!secretId)
		return;
	[[TGMessageStore shared] secretChatState:secretId completion:^(NSString *state, BOOL outgoing){
		TGChatViewController *me = weakSelf;
		if (!me)
			return;
		NSString *resting = nil;
		if ([state isEqualToString:@"pending"]){
			me.inputBar.hidden = YES;
		} else if ([state isEqualToString:@"ready"]){
			me.inputBar.hidden = NO;
		} else if ([state isEqualToString:@"closed"]){
			me.inputBar.hidden = YES;
		}
		// Official keeps the ordinary presence line under a secret chat and
		// marks the state with a lock; the long sentences were ours.
		(void)resting;
		[me titleSubtitleOwnerChanged:nil];
	}];
}

- (void)titleHeld:(UILongPressGestureRecognizer *)hold {
	if (hold.state == UIGestureRecognizerStateBegan)
		[self toggleChatSearch];
}

/// Holding the avatar opens the official chat menu: Open Profile,
/// Statistics for a group or channel, and Search. A secret chat also offers
/// ending itself, which is what the hold used to do alone.
- (void)headerHeld:(UILongPressGestureRecognizer *)hold {
	if (hold.state != UIGestureRecognizerStateBegan)
		return;
	NSMutableArray *items = [NSMutableArray arrayWithObject:TGLocalized(@"Open Profile")];
	if (self.isGroup || self.isChannel || self.chatId < 0)
		[items addObject:TGLocalized(@"Statistics")];
	[items addObject:TGLocalized(@"Search")];
	BOOL secret = self.secretChatId != 0;
	if (secret){
		[items addObject:TGLocalized(@"Encryption Key")];
		[items addObject:TGLocalized(@"Close")];
	}
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:items title:nil
			 destructiveIndex:(secret ? (NSInteger)items.count - 1 : -1)
					   inView:self.navigationController.view ?: self.view
					 onChoice:^(NSInteger index){
		TGChatViewController *me = weakSelf;
		if (!me)
			return;
		NSString *chosen = items[(NSUInteger)index];
		if ([chosen isEqualToString:TGLocalized(@"Open Profile")])
			[me openProfile];
		else if ([chosen isEqualToString:TGLocalized(@"Statistics")])
			[me showChatStatistics];
		else if ([chosen isEqualToString:TGLocalized(@"Search")])
			[me toggleChatSearch];
		else if ([chosen isEqualToString:TGLocalized(@"Encryption Key")])
			[me showEncryptionKey];
		else if ([chosen isEqualToString:TGLocalized(@"Close")])
			[me closeSecretChatFromHeader];
	}];
}

/// Official's Encryption Key page: the 12x12 picture drawn from key_hash
/// in its four colours, the hex under it and the sentence that says what
/// to compare.
- (void)showEncryptionKey {
	__weak typeof(self) weakSelf = self;
	[[TGMessageStore shared] secretChatKeyHash:self.secretChatId completion:^(NSData *keyHash){
		TGChatViewController *me = weakSelf;
		if (!me || !keyHash.length)
			return;
		static const NSUInteger kKeyGrid = 12;   // td_api.tl: a 12x12 square
		CGFloat side = TGMetricBotKeyboardHeight;
		CGFloat cell = side / kKeyGrid;
		UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), YES, 0);
		NSArray *cells = TGSecretKeyCells(keyHash);
		for (NSUInteger i = 0; i < cells.count; i++){
			[TGColourSecretKey([cells[i] integerValue]) setFill];
			UIRectFill(CGRectMake((i % kKeyGrid) * cell, (i / kKeyGrid) * cell, ceilf(cell), ceilf(cell)));
		}
		UIImage *picture = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();
		NSString *who = me.chatTitle ?: @"";
		NSString *text = [NSString stringWithFormat:@"%@\n\n%@", TGSecretKeyHex(keyHash),
				TGLocalizedFormat(@"This image and text were derived from the encryption key for this secret chat with %1$@.\n\n If they look the same on %2$@'s device, end-to-end encryption is guaranteed.\n\nLearn more at telegram.org", who, who)];
		TGRowsViewController *page = [[TGRowsViewController alloc] init];
		page.title = TGLocalized(@"Encryption Key");
		page.sections = @[TGSection(nil, nil, @[TGPageHeaderRow(picture, nil, text)])];
		page.hidesBottomBarWhenPushed = YES;
		[me.navigationController pushViewController:page animated:YES];
	}];
}

- (void)closeSecretChatFromHeader {
	NSInteger secretId = self.secretChatId;
	if (!secretId)
		return;
	int64_t chatId = self.chatId;
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:nil
						 title:@"Secret Chats"
						action:@"Close"
				   destructive:YES
						inView:self.navigationController.view ?: self.view
				   onConfirm:^{
		[[TGMessageStore shared] closeSecretChat:secretId];
		[weakSelf.navigationController popViewControllerAnimated:YES];
		[[TGMessageStore shared] closeChat:chatId];
	}];
}

- (void)showChatStatistics {
#if TG_DEV
	if (TGIsDevChat(self.chatId)){
		TGStatisticsViewController *stats = [[TGStatisticsViewController alloc]
				initWithChatId:self.chatId rows:[TGDevShowcase statisticsRows]];
		stats.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:stats animated:YES];
		return;
	}
#endif
	__weak typeof(self) weakSelf = self;
	[[TGMessageStore shared] chatStatisticsForChat:self.chatId completion:^(NSArray *rows, NSString *kind){
		TGChatViewController *me = weakSelf;
		if (!me)
			return;
		if (!rows.count){
			[TGAlertSheet showMessage:TGLocalized(@"An error occurred.") title:nil inView:me.view];
			return;
		}
		TGStatisticsViewController *stats = [[TGStatisticsViewController alloc]
				initWithChatId:me.chatId rows:rows];
		stats.hidesBottomBarWhenPushed = YES;
		[me.navigationController pushViewController:stats animated:YES];
	}];
}

#pragma mark - typing

- (void)showChatAction:(NSString *)action resting:(NSString *)resting {
	[self.typingTimer invalidate];
	self.typingTimer = nil;
	if (!action.length){
		self.titleSubtitleLabel.text = resting;
		self.titleSubtitleLabel.textColor = [[TGTheme shared] barSubtitleColour];
		return;
	}
	NSString *base = action;
	while ([base hasSuffix:@"."] || [base hasSuffix:@"…"])
		base = [base substringToIndex:base.length - 1];
	self.typingBase = base;
	self.typingStep = 0;
	self.titleSubtitleLabel.textColor = [[TGTheme shared] accentColour];
	[self typingTick];
	self.typingTimer = [NSTimer scheduledTimerWithTimeInterval:0.4 target:self
			selector:@selector(typingTick) userInfo:nil repeats:YES];
}

- (void)typingTick {
	NSString *dots = [@"..." substringToIndex:(NSUInteger)(self.typingStep % 4)];
	// Padded on the right so the word does not shift as the dots grow.
	NSString *pad = [@"   " substringToIndex:3 - dots.length];
	self.titleSubtitleLabel.text = [NSString stringWithFormat:@"%@%@%@", self.typingBase, dots, pad];
	self.typingStep++;
}

- (void)stopChrome {
	[[NSNotificationCenter defaultCenter] removeObserver:self
													 name:TGCustomEmojiLoadedNotification
												   object:nil];
	[self.typingTimer invalidate];
	self.typingTimer = nil;
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(fadeFloatingDate) object:nil];
}

#pragma mark - header emoji status

/// A padlock for a secret chat: the catalog's lock path at the bar's colour.
static UIImage *TGChatLockImage(CGFloat side, UIColor *colour) {
	return [TGIcons glyphNamed:@"lock" colour:colour side:side];
}

- (void)updateTitleEmojiStatus {
	if (!self.titleNameLabel || !self.titleNameLabel.superview)
		return;

	if (self.titleStatusIcon){
		self.titleStatusIcon.image = nil;
		self.titleStatusIcon.hidden = YES;
	}

	BOOL isSaved = (self.chatId == [[TGMessageStore shared] savedMessagesChatId]) ||
			[[TGMessageStore shared] chatIsSavedMessages:self.chatId];
	BOOL isPrivate = !self.isGroup && (self.chatId > 0) && !isSaved;

	int64_t statusId = 0;
	if (isPrivate){
		for (NSDictionary *chat in [TGMessageStore shared].chats){
			if ([chat[@"id"] longLongValue] == self.chatId){
				if (![chat[@"isSaved"] boolValue])
					statusId = [chat[@"emojiStatusId"] longLongValue];
				break;
			}
		}
		if (statusId == 0)
			statusId = [[TGMessageStore shared] emojiStatusIdForUser:self.chatId];
	} else if (!isSaved) {
		statusId = [[TGMessageStore shared] emojiStatusIdForChat:self.chatId];
	}

	NSString *liveTitle = [[TGMessageStore shared] titleForChat:self.chatId];
	NSString *rawTitle = liveTitle.length ? liveTitle
			: (self.chatTitle ?: (self.titleNameLabel.text ?: @""));
	if (rawTitle.length && ![rawTitle isEqualToString:self.chatTitle])
		self.chatTitle = rawTitle;
	// TDLib names the chat "Saved Messages" in English; the pack has it.
	NSString *shownTitle = isSaved ? TGLocalized(@"Saved Messages") : rawTitle;
	self.titleNameLabel.attributedText = TGNameWithStatus(shownTitle, statusId, self.titleNameLabel.font, [[TGTheme shared] barTitleColour]);
	// The header is narrower when search sits beside the avatar.
	CGFloat titleWidth = self.titleNameLabel.superview
			? self.titleNameLabel.superview.bounds.size.width : kTitleWidth;
	self.titleNameLabel.frame = CGRectMake(TGMetricZero, TGMetricBorderWidth,
			titleWidth, TGMetricLineRow);
	self.titleNameLabel.textAlignment = NSTextAlignmentCenter;

	// A secret chat keeps the ordinary presence line and marks itself with a
	// lock beside the name, which is the one difference official shows in
	// the title rather than in the subtitle.
	BOOL secret = self.secretChatId != 0;
	if (!self.titleStatusIcon && self.titleNameLabel.superview){
		self.titleStatusIcon = [[UIImageView alloc] init];
		self.titleStatusIcon.contentMode = UIViewContentModeScaleAspectFit;
		self.titleStatusIcon.hidden = YES;
		[self.titleNameLabel.superview addSubview:self.titleStatusIcon];
	}
	if (secret){
		CGFloat side = TGMetricLineSubhead;
		CGFloat textWidth = [rawTitle sizeWithFont:self.titleNameLabel.font].width;
		CGFloat x = MAX(TGMetricZero, (titleWidth - textWidth) * 0.5f
				- side - TGMetricPadTiny);
		self.titleStatusIcon.image = TGChatLockImage(side,
				[[TGTheme shared] barTitleColour]);
		self.titleStatusIcon.frame = CGRectMake(x,
				TGCenteredOrigin(TGMetricLineRow, side) + TGMetricBorderWidth,
				side, side);
		self.titleStatusIcon.hidden = NO;
	}
}

- (void)chromeCustomEmojiLoaded:(NSNotification *)note {
	[self updateTitleEmojiStatus];
}

@end
