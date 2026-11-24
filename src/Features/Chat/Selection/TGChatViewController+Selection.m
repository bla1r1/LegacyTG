#import "TGChatViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGChatActionMenuModel.h"
#import "TGForwardPicker.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGChatParityModel.h"
#import "TGBarItem.h"
#import "TGPresent.h"
#import "TGControls.h"
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

	TGMotionQuick(^{
		cell.checkbox.alpha = TGAlphaOpaque;
	}, nil);
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
		// The composer's own chrome: the panel takes the composer's place, so
		// it wears the same gloss and top line instead of a flat white strip.
		self.editToolbar = TGComposerStripView(CGRectMake(0, b.size.height - kInputHeight,
				b.size.width, kInputHeight));
		self.editToolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;

		// Official's selection panel is icon-only circles, not two text
		// buttons: Delete, then Forward, with the count living in the title.
		TGTheme *theme = [TGTheme shared];
		CGFloat side = TGMetricSelectionActionSide;
		CGFloat glyph = TGMetricSelectionActionGlyphSide;

		self.editDeleteButton = TGRoundGlyphButton(@"delete", [theme destructiveColour],
				side, glyph, @"Delete", self, @selector(deleteSelectedMessages));
		self.editDeleteButton.frame = CGRectMake(TGMetricPadLarge,
				TGCenteredOrigin(kInputHeight, side), side, side);
		self.editDeleteButton.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
		[self.editToolbar addSubview:self.editDeleteButton];

		self.editCopyButton = TGRoundGlyphButton(@"copy", [theme accentColour],
				side, glyph, @"Copy", self, @selector(copySelectedMessages));
		self.editCopyButton.frame = CGRectMake(TGCenteredOrigin(b.size.width, side),
				TGCenteredOrigin(kInputHeight, side), side, side);
		self.editCopyButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
		[self.editToolbar addSubview:self.editCopyButton];

		self.editForwardButton = TGRoundGlyphButton(@"forward", [theme accentColour],
				side, glyph, @"Forward", self, @selector(forwardSelectedMessages));
		self.editForwardButton.frame = CGRectMake(b.size.width - side - TGMetricPadLarge,
				TGCenteredOrigin(kInputHeight, side), side, side);
		self.editForwardButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		[self.editToolbar addSubview:self.editForwardButton];

		[self.view addSubview:self.editToolbar];
	}
	self.editToolbar.hidden = NO;
	self.editToolbar.transform = CGAffineTransformMakeTranslation(0, self.editToolbar.bounds.size.height);
	[self.view bringSubviewToFront:self.editToolbar];

	self.savedTitleView = self.navigationItem.titleView;
	self.savedRightBarButtonItem = self.navigationItem.rightBarButtonItem;

	self.navigationItem.titleView = nil;
	self.navigationItem.rightBarButtonItem = [TGBarItem itemWithRole:TGBarRoleCancel
			target:self action:@selector(exitEditMode)];
	self.navigationItem.leftBarButtonItem = [TGBarItem itemWithTitle:@"Clear All" primary:NO
			target:self action:@selector(clearHistoryFromSelection)];

	[self updateEditToolbar];
	[self.table reloadData];

	// Move the toolbar with a transform rather than its frame: a frame change
	// relayouts every button inside it, which is the expensive part on an A4.
	// The composer fades out underneath at the same time.
	__weak typeof(self) weakSelf = self;
	TGMotionSheet(^{
		weakSelf.editToolbar.transform = CGAffineTransformIdentity;
		weakSelf.inputBar.alpha = TGAlphaTransparent;
	}, ^(BOOL finished){
		// Selecting again during this fade must not hide the composer.
		TGChatViewController *me = weakSelf;
		if (me && me.isEditingMessages)
			me.inputBar.hidden = YES;
	});
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
	TGMotionSheet(^{
		weakSelf.editToolbar.transform = CGAffineTransformMakeTranslation(0,
				weakSelf.editToolbar.bounds.size.height);
		weakSelf.inputBar.alpha = TGAlphaOpaque;
	}, ^(BOOL finished){
		TGChatViewController *me = weakSelf;
		if (!me || me.isEditingMessages)
			return;
		me.editToolbar.hidden = YES;
		me.editToolbar.transform = CGAffineTransformIdentity;
	});
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
	self.editCopyButton.enabled = forwardable;
	self.editCopyButton.alpha = forwardable ? TGAlphaOpaque : TGAlphaDisabled;

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
	// One held message carries TDLib's word on who it can go from; a
	// selection of many keeps both choices.
	NSDictionary *properties = (ids.count == 1 &&
			[ids[0] longLongValue] == [self.actionMessage[@"id"] longLongValue])
			? self.actionProperties : nil;
	NSArray *options = TGMessageDeleteChoices(isSaved, self.isGroup, properties);
	if (!options.count)
		return;
	NSMutableArray *choices = [NSMutableArray array];
	for (NSDictionary *option in options)
		[choices addObject:option[@"title"]];

	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:choices
						title:nil
			 destructiveIndex:0
					   inView:self.view
					 onChoice:^(NSInteger index){
		if (index < 0 || index >= (NSInteger)options.count)
			return;
		BOOL revoke = [options[(NSUInteger)index][@"revoke"] boolValue];
		TGChatViewController *me = weakSelf;
		NSMutableArray *chosen = [NSMutableArray array];
		NSSet *idSet = [NSSet setWithArray:ids];
		for (NSDictionary *m in me.messages)
			if ([idSet containsObject:m[@"id"]])
				[chosen addObject:m];
		if (me && TGDeleteLosesPaidPostStars(chosen, revoke, [[NSDate date] timeIntervalSince1970])) {
			NSString *text = [TGLocalized(@"You won't receive **Stars** for this post if you delete it now. The post must remain visible for at least **24 hours** after publication.")
					stringByReplacingOccurrencesOfString:@"**" withString:@""];
			[TGAlertSheet showConfirm:text
								title:TGLocalized(@"Stars Will Be Lost")
							   action:TGLocalized(@"Delete Anyway")
						  destructive:YES
							   inView:me.view
							onConfirm:^{
				[weakSelf executeDeleteMessages:ids revoke:YES];
			}];
			return;
		}
		[me executeDeleteMessages:ids revoke:revoke];
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

- (void)copySelectedMessages {
	if (!self.selectedMessageIds.count) return;

	NSMutableArray *selected = [NSMutableArray array];
	for (NSDictionary *m in self.messages) {
		if ([self.selectedMessageIds containsObject:m[@"id"]]) {
			[selected addObject:m];
		}
	}
	if (!selected.count) return;

	NSMutableArray *texts = [NSMutableArray arrayWithCapacity:selected.count];
	for (NSDictionary *m in selected) {
		NSString *t = m[@"text"];
		if (!t.length) {
			t = m[@"caption"];
		}
		if (t.length) {
			[texts addObject:t];
		}
	}

	if (texts.count > 0) {
		NSString *joined = [texts componentsJoinedByString:@"\n\n"];
		[UIPasteboard generalPasteboard].string = joined;
	}

	NSUInteger count = selected.count;
	[self exitEditMode];

	NSString *notice = TGLocalizedPlural(@"Message Copied",
			@"%d Messages Copied", (NSInteger)count);
	[TGSnackbar showInView:self.view text:notice seconds:2 onCommit:^{}];
}

- (void)forwardSelectedMessages {
	if (!self.selectedMessageIds.count) return;
	NSArray *ids = [self.selectedMessageIds allObjects];
	int64_t chatId = self.chatId;

	TGForwardPicker *picker = [[TGForwardPicker alloc] init];
	picker.sourceChatId = chatId;
	__weak typeof(self) weakSelf = self;
	picker.onPickedWithOptions = ^(int64_t targetChatId, BOOL hideSenderName, BOOL hideCaptions){
		[[TGMessageStore shared] forwardMessages:ids
								  fromChat:chatId
									toChat:targetChatId
								  sendCopy:hideSenderName
							 removeCaption:hideCaptions];
		[weakSelf exitEditMode];
		NSString *title = [[TGMessageStore shared] titleForChat:targetChatId] ?: @"";
		NSString *text = TGLocalizedPluralValue(@"Message forwarded to **%@**.",
				@"Messages forwarded to **%@**.", title, (NSInteger)ids.count);
		text = [text stringByReplacingOccurrencesOfString:@"**" withString:@""];
		[TGSnackbar showInView:weakSelf.view text:text seconds:3 onCommit:^{}];
	};
	[TGPresent presentModal:picker kind:TGModalForm from:self];
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
