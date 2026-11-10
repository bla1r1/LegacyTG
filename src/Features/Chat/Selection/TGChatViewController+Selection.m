#import "TGChatViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGForwardPicker.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGChatParityModel.h"
#import <QuartzCore/QuartzCore.h>

/// finalizeCell runs for every row that scrolls past, so the entrance pop is
/// kept here instead: only the row the finger hit is animated.
static void TGAnimateSelectionCheckbox(TGChatViewController *chat, int64_t messageId) {
	NSInteger row = NSNotFound;
	for (NSUInteger i = 0; i < chat.messages.count; i++) {
		if ([chat.messages[i][@"id"] longLongValue] == messageId) {
			row = (NSInteger)i;
			break;
		}
	}
	if (row == NSNotFound)
		return;

	NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:0];
	TGBubbleCell *cell = (TGBubbleCell *)[chat.table cellForRowAtIndexPath:path];
	if (![cell isKindOfClass:[TGBubbleCell class]] || cell.checkbox.hidden)
		return;

	cell.checkbox.alpha = TGAlphaTransparent;
	CAKeyframeAnimation *pop = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
	pop.values = @[@(TGTransformScaleMenuInitial), @(TGTransformScalePillActive), @(1.0f)];
	pop.keyTimes = @[@0.0f, @0.66f, @1.0f];
	pop.duration = TGAnimationDurationFast;
	pop.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
	[cell.checkbox.layer addAnimation:pop forKey:@"tg.selection.pop"];

	[UIView animateWithDuration:TGAnimationDurationFast animations:^{
		cell.checkbox.alpha = TGAlphaOpaque;
	}];
}

@implementation TGChatViewController (Selection)

#pragma mark - multi-select edit mode

- (void)enterEditMode {
	if (self.isEditingMessages) return;
	self.isEditingMessages = YES;
	if (!self.selectedMessageIds) {
		self.selectedMessageIds = [NSMutableSet set];
	} else {
		[self.selectedMessageIds removeAllObjects];
	}

	[self.input resignFirstResponder];
	// Keep the composer on screen while it fades. Hiding it now would leave
	// the toolbar sliding over an empty strip.
	self.inputBar.hidden = NO;

	if (!self.editToolbar) {
		CGRect b = self.view.bounds;
		self.editToolbar = [[UIView alloc] initWithFrame:CGRectMake(0, b.size.height - kInputHeight, b.size.width, kInputHeight)];
		self.editToolbar.backgroundColor = [[TGTheme shared] inputBarColour];
		self.editToolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;

		UIView *hair = [[UIView alloc] initWithFrame:CGRectMake(0, 0, b.size.width, TGMetricHairline)];
		hair.backgroundColor = [[TGTheme shared] separatorColour];
		hair.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[self.editToolbar addSubview:hair];

		// Official's selection panel is icon-only circles, not two text
		// buttons: Delete, then Forward, with the count living in the title.
		TGTheme *theme = [TGTheme shared];
		CGFloat side = TGMetricSelectionActionSide;
		CGFloat glyph = TGMetricSelectionActionGlyphSide;

		self.editDeleteButton = [UIButton buttonWithType:UIButtonTypeCustom];
		self.editDeleteButton.frame = CGRectMake(TGMetricPadLarge,
				TGCenteredOrigin(kInputHeight, side), side, side);
		self.editDeleteButton.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
		[self.editDeleteButton setBackgroundImage:[TGTheme
				skeuomorphicButtonImageWithColor:[theme destructiveColour]
				height:side highlighted:NO cornerRadius:TGHalf(side)]
				forState:UIControlStateNormal];
		[self.editDeleteButton setBackgroundImage:[TGTheme
				skeuomorphicButtonImageWithColor:[theme destructiveColour]
				height:side highlighted:YES cornerRadius:TGHalf(side)]
				forState:UIControlStateHighlighted];
		[self.editDeleteButton setImage:[TGIcons glyphNamed:@"delete"
				colour:[theme onAccentColour] side:glyph]
				forState:UIControlStateNormal];
		self.editDeleteButton.adjustsImageWhenHighlighted = NO;
		self.editDeleteButton.accessibilityLabel = TGLocalized(@"Delete");
		[self.editDeleteButton addTarget:self action:@selector(deleteSelectedMessages) forControlEvents:UIControlEventTouchUpInside];
		[self.editToolbar addSubview:self.editDeleteButton];

		self.editForwardButton = [UIButton buttonWithType:UIButtonTypeCustom];
		self.editForwardButton.frame = CGRectMake(b.size.width - side - TGMetricPadLarge,
				TGCenteredOrigin(kInputHeight, side), side, side);
		self.editForwardButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		[self.editForwardButton setBackgroundImage:[TGTheme
				skeuomorphicButtonImageWithColor:[theme accentColour]
				height:side highlighted:NO cornerRadius:TGHalf(side)]
				forState:UIControlStateNormal];
		[self.editForwardButton setBackgroundImage:[TGTheme
				skeuomorphicButtonImageWithColor:[theme accentColour]
				height:side highlighted:YES cornerRadius:TGHalf(side)]
				forState:UIControlStateHighlighted];
		[self.editForwardButton setImage:[TGIcons glyphNamed:@"forward"
				colour:[theme onAccentColour] side:glyph]
				forState:UIControlStateNormal];
		self.editForwardButton.adjustsImageWhenHighlighted = NO;
		self.editForwardButton.accessibilityLabel = TGLocalized(@"Forward");
		[self.editForwardButton addTarget:self action:@selector(forwardSelectedMessages) forControlEvents:UIControlEventTouchUpInside];
		[self.editToolbar addSubview:self.editForwardButton];

		[self.view addSubview:self.editToolbar];
	}
	self.editToolbar.hidden = NO;
	self.editToolbar.transform = CGAffineTransformMakeTranslation(0, self.editToolbar.bounds.size.height);
	[self.view bringSubviewToFront:self.editToolbar];

	self.savedTitleView = self.navigationItem.titleView;
	self.savedRightBarButtonItem = self.navigationItem.rightBarButtonItem;

	self.navigationItem.titleView = nil;
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Cancel")
																		 style:UIBarButtonItemStylePlain
																		target:self
																		action:@selector(exitEditMode)];
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Clear All")
																		 style:UIBarButtonItemStylePlain
																		target:self
																		action:@selector(clearHistoryFromSelection)];

	[self updateEditToolbar];
	[self.table reloadData];

	// Move the toolbar with a transform rather than its frame: a frame change
	// relayouts every button inside it, which is the expensive part on an A4.
	// The composer fades out underneath at the same time.
	__weak typeof(self) weakSelf = self;
	[UIView animateWithDuration:TGAnimationDurationNormal animations:^{
		weakSelf.editToolbar.transform = CGAffineTransformIdentity;
		weakSelf.inputBar.alpha = TGAlphaTransparent;
	} completion:^(BOOL finished){
		// Selecting again during this fade must not hide the composer.
		TGChatViewController *me = weakSelf;
		if (me && me.isEditingMessages)
			me.inputBar.hidden = YES;
	}];
}

- (void)exitEditMode {
	if (!self.isEditingMessages) return;
	self.isEditingMessages = NO;
	[self.selectedMessageIds removeAllObjects];

	self.inputBar.hidden = NO;
	self.inputBar.alpha = TGAlphaTransparent;

	self.navigationItem.leftBarButtonItem = nil;
	self.navigationItem.titleView = self.savedTitleView;
	self.navigationItem.rightBarButtonItem = self.savedRightBarButtonItem;
	self.title = nil;
	[self.table reloadData];

	// The reverse: the toolbar drops away while the composer fades back in.
	// It is hidden only after the animation, and only if the mode is still off,
	// so a fast Select-again does not expose the composer under it.
	__weak typeof(self) weakSelf = self;
	[UIView animateWithDuration:TGAnimationDurationNormal animations:^{
		weakSelf.editToolbar.transform = CGAffineTransformMakeTranslation(0,
				weakSelf.editToolbar.bounds.size.height);
		weakSelf.inputBar.alpha = TGAlphaOpaque;
	} completion:^(BOOL finished){
		TGChatViewController *me = weakSelf;
		if (!me || me.isEditingMessages)
			return;
		me.editToolbar.hidden = YES;
		me.editToolbar.transform = CGAffineTransformIdentity;
	}];
}

- (void)clearSelectedMessages {
	[self.selectedMessageIds removeAllObjects];
	[self updateEditToolbar];
	[self.table reloadData];
}

/// Clear All is the clear-history action, not a deselect. Only a private
/// chat may clear for both sides (TDLib ignores revoke elsewhere); groups,
/// channels and Saved Messages clear for this account only.
- (void)clearHistoryFromSelection {
	BOOL isSaved = (self.chatId == [[TGMessageStore shared] savedMessagesChatId]);
	BOOL canRevoke = !isSaved && !self.isGroup && !self.isChannel;
	NSArray *choices = canRevoke
			? @[TGLocalized(@"Delete for Everyone"), TGLocalized(@"Delete for me")]
			: @[TGLocalized(@"Clear History")];
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:choices
						title:TGLocalized(@"Clear History")
			 destructiveIndex:0
					   inView:self.view
					 onChoice:^(NSInteger index){
		TGChatViewController *me = weakSelf;
		if (!me)
			return;
		[me exitEditMode];
		[[TGMessageStore shared] clearHistoryInChat:me.chatId revoke:(canRevoke && index == 0)];
		[me reload];
	}];
}

- (void)updateEditToolbar {
	NSUInteger count = self.selectedMessageIds.count;
	BOOL enabled = (count > 0);

	self.editDeleteButton.enabled = enabled;
	self.editDeleteButton.alpha = enabled ? TGAlphaOpaque : TGAlphaDisabled;

	// One protected message in the selection keeps the whole batch home.
	BOOL forwardable = enabled;
	for (NSDictionary *m in self.messages){
		if ([m[@"canBeSaved"] isEqual:@NO] && [self.selectedMessageIds containsObject:m[@"id"]]){
			forwardable = NO;
			break;
		}
	}
	self.editForwardButton.enabled = forwardable;
	self.editForwardButton.alpha = forwardable ? TGAlphaOpaque : TGAlphaDisabled;

	if (count == 0) {
		self.title = TGLocalized(@"Select Messages");
	} else {
		self.title = TGLocalizedFormat(@"%d Selected", (int)count);
	}
}

- (void)toggleMessageSelection:(int64_t)messageId {
	if (!messageId) return;
	NSNumber *num = @(messageId);
	BOOL selecting = ![self.selectedMessageIds containsObject:num];
	if (selecting) {
		[self.selectedMessageIds addObject:num];
	} else {
		[self.selectedMessageIds removeObject:num];
	}
	[self updateEditToolbar];
	[self.table reloadData];

	if (selecting) {
		// The reload may have built the visible row only on the next layout
		// pass; force it so the pop lands on the cell the finger touched.
		[self.table layoutIfNeeded];
		TGAnimateSelectionCheckbox(self, messageId);
	}
}

- (void)selectMessageAtIndex:(NSInteger)index {
	if (index < 0 || index >= (NSInteger)self.messages.count) return;
	if (!self.isEditingMessages) {
		[self enterEditMode];
	}
	NSDictionary *m = self.messages[index];
	if ([m[@"service"] boolValue])
		return;
	int64_t msgId = [m[@"id"] longLongValue];
	if (msgId) {
		[self toggleMessageSelection:msgId];
	}
}

- (void)promptDeleteMessages:(NSArray *)ids {
	if (!ids.count) return;

	// Saved Messages has nobody else to revoke from, so there is one choice
	// there and two everywhere else. Either way the first one revokes.
	BOOL isSaved = (self.chatId == [[TGMessageStore shared] savedMessagesChatId]);
	NSString *forBoth = self.isGroup ? TGLocalized(@"Delete for All")
									 : TGLocalized(@"Delete for Everyone");
	NSArray *choices = isSaved ? @[TGLocalized(@"Delete")]
			: @[forBoth, TGLocalized(@"Delete for me")];

	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:choices
						title:nil
			 destructiveIndex:0
					   inView:self.view
					 onChoice:^(NSInteger index){
		[weakSelf executeDeleteMessages:ids revoke:(index == 0)];
	}];
}

- (void)deleteSelectedMessages {
	if (!self.selectedMessageIds.count) return;
	[self promptDeleteMessages:[self.selectedMessageIds allObjects]];
}

- (void)executeDeleteMessages:(NSArray *)ids revoke:(BOOL)revoke {
	if (!ids.count) return;
	NSUInteger count = ids.count;
	int64_t chatId = self.chatId;
	NSSet *idSet = [NSSet setWithArray:ids];

	NSMutableArray *without = [NSMutableArray arrayWithCapacity:self.messages.count];
	for (NSDictionary *m in self.messages) {
		if (![idSet containsObject:m[@"id"]]) {
			[without addObject:m];
		}
	}
	self.messages = without;

	if (self.isEditingMessages) {
		[self exitEditMode];
	} else {
		[self.table reloadData];
	}

	NSString *text = TGLocalizedPlural(@"Message Deleted",
			@"%d Messages Deleted", (NSInteger)count);
	if (TGChatDeleteDefersToCommit(revoke)){
		// Delete-for-me waits behind the undo plate: the rows are out of the
		// list, and nothing is sent until the plate commits. UNDO removes
		// the plate without a request and a reload brings the rows back.
		[TGSnackbar showInView:self.view text:text seconds:3 onCommit:^{
			[[TGSendStore shared] deleteMessages:ids inChat:chatId revoke:NO];
		}];
		__weak typeof(self) weakSelf = self;
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)),
				dispatch_get_main_queue(), ^{ [weakSelf reload]; });
	} else {
		// Delete for everyone cannot be undone once it has left, so it is
		// sent at once and the plate is only a notice.
		[[TGSendStore shared] deleteMessages:ids inChat:chatId revoke:YES];
		[TGSnackbar showInView:self.view text:text seconds:3 onCommit:nil];
		__weak typeof(self) weakSelf = self;
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)),
				dispatch_get_main_queue(), ^{ [weakSelf reload]; });
	}
}

- (void)forwardSelectedMessages {
	if (!self.selectedMessageIds.count) return;
	NSArray *ids = [self.selectedMessageIds allObjects];
	int64_t chatId = self.chatId;

	TGForwardPicker *picker = [[TGForwardPicker alloc] init];
	picker.sourceChatId = chatId;
	__weak typeof(self) weakSelf = self;
	picker.onPicked = ^(int64_t targetChatId){
		[[TGMessageStore shared] forwardMessages:ids
								  fromChat:chatId
									toChat:targetChatId];
		[weakSelf exitEditMode];
		NSString *title = [[TGMessageStore shared] titleForChat:targetChatId] ?: @"";
		NSString *text = TGLocalizedPluralValue(@"Message forwarded to **%@**.",
				@"Messages forwarded to **%@**.", title, (NSInteger)ids.count);
		text = [text stringByReplacingOccurrencesOfString:@"**" withString:@""];
		[TGSnackbar showInView:weakSelf.view text:text seconds:3 onCommit:^{}];
	};
	UINavigationController *nav = [[UINavigationController alloc]
			initWithRootViewController:picker];
	[self presentViewController:nav animated:YES completion:nil];
}

- (TGBubbleCell *)finalizeCell:(TGBubbleCell *)cell message:(NSDictionary *)m layout:(TGMessageLayout *)layout isMine:(BOOL)mine {
	if (!self.isEditingMessages || layout.isService) {
		cell.checkbox.hidden = YES;
		cell.bubble.userInteractionEnabled = YES;
		return cell;
	}

	cell.checkbox.hidden = NO;
	cell.bubble.userInteractionEnabled = NO;

	int64_t msgId = [m[@"id"] longLongValue];
	BOOL isSelected = [self.selectedMessageIds containsObject:@(msgId)];
	cell.checkbox.image = [TGIcons selectionCheckboxSelected:isSelected];

	if (!mine) {
		CGRect bf = cell.bubble.frame;
		bf.origin.x += TGMetricSelectionShift;
		cell.bubble.frame = bf;

		if (!cell.senderAvatar.hidden) {
			CGRect af = cell.senderAvatar.frame;
			af.origin.x += TGMetricSelectionShift;
			cell.senderAvatar.frame = af;
		}
		if (!cell.sender.hidden && cell.sender.superview != cell.bubble) {
			CGRect sf = cell.sender.frame;
			sf.origin.x += TGMetricSelectionShift;
			cell.sender.frame = sf;
		}

		// Reaction chips sit on the canvas below the bubble, so they have to
		// follow the same shift the bubble did.
		UIView *chips = [cell.contentView viewWithTag:0x9005];
		if (chips && !chips.hidden){
			CGRect cf = chips.frame;
			cf.origin.x += TGMetricSelectionShift;
			chips.frame = cf;
		}
	}

	CGFloat cy = CGRectGetMidY(cell.bubble.frame);
	cell.checkbox.frame = CGRectMake(TGMetricBubblePadH, cy - TGHalf(TGMetricGiftAvatar), TGMetricGiftAvatar, TGMetricGiftAvatar);
	return cell;
}

@end
