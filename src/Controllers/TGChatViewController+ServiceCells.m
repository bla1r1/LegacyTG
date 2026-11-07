//
// TGChatViewController+ServiceCells.m
// Bubble cell rendering for service messages, polls, documents, contacts, and locations.
//
#import "TGChatViewControllerInternal.h"
#import <QuartzCore/QuartzCore.h>
#import "TGStyle.h"
#import "TGPollPresentation.h"
#import "TGLiveLocation.h"
#import "TGChecklistPresentation.h"

/// The card a chat row shows, without the buttons this app cannot honour
/// yet: there is no payment form and no group-call audio, and a Pay or Join
/// that does nothing is worse than none. Layout and cell both call this, so
/// the height always matches what is drawn.
TGMessageCard *TGChatCardForRow(NSDictionary *m) {
	TGMessageCard *card = TGMessageCardForRow(m);
	if (card.action == TGMessageCardActionPay || card.action == TGMessageCardActionJoinCall){
		card.buttonTitle = nil;
		card.action = TGMessageCardActionNone;
	}
	if (card.action == TGMessageCardActionOpenUser && card.actionTargetId != 0) {
		card.titleStatusEmojiId = [[TGClient shared] emojiStatusIdForUser:card.actionTargetId];
	}
	return card;
}

@implementation TGChatViewController (ServiceCells)

- (BOOL)configureServiceCell:(TGBubbleCell *)cell message:(NSDictionary *)m layout:(TGMessageLayout *)layout isMine:(BOOL)mine indexPath:(NSIndexPath *)indexPath {
	// Service messages & separators
	if (layout.isService && !layout.isCard) {
		TGTheme *serviceTheme = [TGTheme shared];
		NSString *line = [self serviceLineForMessage:m];

		cell.bubble.frame = layout.bubbleFrame;
		cell.bubble.backgroundColor = [serviceTheme serviceBubbleColour];
		cell.bubble.layer.borderWidth = 0;
		cell.bubble.layer.cornerRadius = [serviceTheme bubbleCornerRadius];
		cell.picture.hidden = YES;
		cell.time.text = @"";
		cell.body.hidden = NO;
		cell.body.numberOfLines = 1;
		cell.body.font = TGFontMeta();
		cell.body.textAlignment = NSTextAlignmentCenter;
		cell.body.textColor = [serviceTheme serviceTextColour];
		cell.body.text = line;
		cell.body.frame = layout.bodyFrame;
		if ([m[@"separator"] isEqualToString:@"unread"]) {
			cell.bubble.backgroundColor = [serviceTheme unreadSeparatorColour];
			cell.bubble.layer.cornerRadius = TGMetricCornerNone;
			cell.body.font = TGFontCaptionStrong();
			cell.body.textColor = [serviceTheme secondaryTextColour];
		} else if (m[@"separator"]) {
			cell.body.font = TGFontMetaStrong();
		}
		return YES;
	}

	// Invoices, gifts, giveaways, games, shared peers, calls, stories
	if (layout.isCard) {
		TGTheme *theme = [TGTheme shared];
		cell.bubble.frame = layout.bubbleFrame;
		cell.bubble.backgroundColor = mine ? [theme bubbleMineColour] : [theme bubbleTheirsColour];
		cell.bubble.layer.borderWidth = TGMetricBorderNone;
		cell.bubble.layer.borderColor = [UIColor clearColor].CGColor;
		cell.bubble.layer.cornerRadius = [theme bubbleCornerRadius];
		cell.body.hidden = YES;
		cell.subtitle.hidden = YES;
		cell.picture.hidden = YES;
		cell.disc.hidden = YES;

		if (!cell.cardView)
			cell.cardView = [[TGMessageCardView alloc] initWithFrame:CGRectZero];
		if (cell.cardView.superview != cell.bubble)
			[cell.bubble addSubview:cell.cardView];
		cell.cardView.hidden = NO;
		TGMessageCard *card = TGChatCardForRow(m);
		CGFloat width = layout.bubbleFrame.size.width - TGDoubled(kPadH);
		CGFloat senderH = layout.senderName.length ? TGMetricSenderLineHeight : TGMetricZero;
		cell.cardView.frame = CGRectMake(kPadH, kPadV + senderH, width,
				TGMessageCardLayout(card, width).size.height);
		int64_t messageId = [m[@"id"] longLongValue];
		__weak typeof(self) weakSelf = self;
		cell.cardView.onAction = ^(TGMessageCard *tapped){
			[weakSelf openCard:tapped ofMessage:messageId];
		};
		[cell.cardView showCard:card];

		cell.time.text = layout.stamp;
		cell.time.textColor = mine ? [theme timeMineColour] : [theme timeColour];
		TGPlaceStamp(cell, layout.bubbleFrame, layout.timeWidth, mine);
		cell.ticks.hidden = !mine;
		if (mine) {
			cell.ticks.image = [self ticksForMessage:m white:NO];
			TGPlaceTicks(cell, layout.bubbleFrame);
		}
		return YES;
	}

	// Checklists
	if (layout.isChecklist) {
		TGTheme *checklistTheme = [TGTheme shared];
		NSDictionary *checklist = [m[@"checklist"] isKindOfClass:NSDictionary.class]
				? m[@"checklist"] : @{};
		NSString *title = [checklist[@"title"] isKindOfClass:NSString.class]
				? checklist[@"title"] : @"Checklist";
		NSArray *tasks = [checklist[@"tasks"] isKindOfClass:NSArray.class]
				? checklist[@"tasks"] : @[];
		BOOL canToggle = TGChecklistCanToggle(checklist);
		int64_t msgId = [m[@"id"] longLongValue];

		cell.bubble.frame = layout.bubbleFrame;
		cell.bubble.backgroundColor = mine ? [checklistTheme bubbleMineColour] : [checklistTheme bubbleTheirsColour];
		cell.bubble.layer.borderWidth = TGMetricBorderNone;
		cell.bubble.layer.borderColor = [UIColor clearColor].CGColor;
		cell.bubble.layer.cornerRadius = [checklistTheme bubbleCornerRadius];

		CGFloat contentW = layout.bubbleFrame.size.width - TGDoubled(kPadH);
		CGFloat textW = contentW - kChecklistTextColumn;
		CGSize titleSize = TGTextSize(title, TGFontBodyStrong(), contentW);

		cell.body.hidden = NO;
		cell.body.numberOfLines = 0;
		cell.body.font = TGFontBodyStrong();
		cell.body.textColor = [checklistTheme primaryTextColour];
		NSArray *titleEntities = [checklist[@"titleEntities"] isKindOfClass:NSArray.class] ? checklist[@"titleEntities"] : nil;
		if (titleEntities.count) {
			cell.body.attributedText = TGAttributedMessageText(title, titleEntities, cell.body.font, cell.body.textColor);
		} else {
			cell.body.text = title;
		}
		CGFloat y = kPadV + (layout.senderName.length ? TGMetricSenderLineHeight : TGMetricZero);
		cell.body.frame = CGRectMake(kPadH, y, contentW, titleSize.height);
		y += titleSize.height;
		if (tasks.count)
			y += kChecklistTitleGap;

		cell.subtitle.hidden = YES;
		cell.subtitle.text = @"";

		NSUInteger revision = 5381;
		revision = revision * 33 + title.length;
		revision = revision * 33 + tasks.count;
		revision = revision * 33 + (canToggle ? 1 : 0);
		for (id raw in tasks) {
			NSDictionary *task = [raw isKindOfClass:NSDictionary.class] ? raw : @{};
			NSString *text = [task[@"text"] isKindOfClass:NSString.class]
					? task[@"text"] : @"";
			revision = revision * 33 + text.length;
			revision = revision * 33 + (TGChecklistTaskDone(task) ? 1 : 0);
		}

		if (cell.pollMessageId == msgId && cell.pollRevision == revision) {
			for (UIView *row in cell.bubble.subviews) {
				if (row.tag >= 0x9300 && row.tag < 0x9400) row.hidden = NO;
			}
		} else {
			for (UIView *old in [cell.bubble.subviews copy]) {
				if (old.tag >= 0x9300 && old.tag < 0x9400) [old removeFromSuperview];
			}
			cell.pollMessageId = msgId;
			cell.pollRevision = revision;

			CGFloat rowY = y;
			for (NSUInteger i = 0; i < tasks.count; i++) {
				id raw = tasks[i];
				NSDictionary *task = [raw isKindOfClass:NSDictionary.class]
						? raw : @{};
				NSString *text = [task[@"text"] isKindOfClass:NSString.class]
						? task[@"text"] : @"";
				BOOL done = TGChecklistTaskDone(task);
				CGFloat textH = TGTextSize(text, TGFontBody(), textW).height;
				CGFloat rowH = MAX(kChecklistRow, textH);

				UIButton *row = [UIButton buttonWithType:UIButtonTypeCustom];
				row.frame = CGRectMake(kPadH, rowY, contentW, rowH);
				row.tag = 0x9300 + (NSInteger)i;
				row.enabled = canToggle;
				[row addTarget:self action:@selector(checklistTaskTapped:) forControlEvents:UIControlEventTouchUpInside];
				[cell.bubble addSubview:row];

				// The mark sits on the task's first line, wherever the text lands.
				CGFloat textY = TGCenteredOrigin(rowH, textH);
				UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(TGMetricZero,
						textY + TGCenteredOrigin(MIN(textH, TGMetricLineBody), TGMetricPollDotSide),
						TGMetricPollDotSide, TGMetricPollDotSide)];
				dot.layer.cornerRadius = TGHalf(TGMetricPollDotSide);
				dot.layer.borderWidth = TGMetricBorderMedium;
				dot.layer.borderColor = [checklistTheme accentColour].CGColor;
				dot.backgroundColor = done ? [checklistTheme accentColour] : [UIColor clearColor];
				[row addSubview:dot];

				UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(kChecklistTextColumn,
						textY, textW, textH)];
				label.numberOfLines = 0;
				label.font = TGFontBody();
				label.textColor = [checklistTheme primaryTextColour];
				label.backgroundColor = [UIColor clearColor];
				NSArray *taskEntities = [task[@"entities"] isKindOfClass:NSArray.class] ? task[@"entities"] : nil;
				if (taskEntities.count) {
					label.attributedText = TGAttributedMessageText(text, taskEntities, label.font, label.textColor);
				} else {
					label.text = text;
				}
				[row addSubview:label];

				rowY += rowH;
			}

			rowY += kChecklistProgressGap;
			UILabel *progress = [[UILabel alloc] initWithFrame:
					CGRectMake(kPadH, rowY, contentW, kChecklistProgressLine)];
			progress.tag = 0x93FF;
			progress.font = TGFontMeta();
			progress.textColor = [checklistTheme secondaryTextColour];
			progress.backgroundColor = [UIColor clearColor];
			progress.text = TGChecklistProgressLine(checklist);
			[cell.bubble addSubview:progress];
		}

		cell.picture.hidden = YES;
		cell.disc.hidden = YES;
		cell.time.text = layout.stamp;
		cell.time.textColor = mine ? [checklistTheme timeMineColour] : [checklistTheme timeColour];
		TGPlaceStamp(cell, layout.bubbleFrame, layout.timeWidth, mine);
		cell.ticks.hidden = !mine;
		if (mine) {
			cell.ticks.image = [self ticksForMessage:m white:NO];
			TGPlaceTicks(cell, layout.bubbleFrame);
		}
		return YES;
	}

	// Polls
	if (layout.isPoll) {
		TGTheme *pollTheme = [TGTheme shared];
		NSDictionary *poll = [m[@"poll"] isKindOfClass:NSDictionary.class]
				? m[@"poll"] : @{
					@"question"        : [m[@"pollQuestion"] isKindOfClass:NSString.class]
							? m[@"pollQuestion"] : @"Poll",
					@"options"         : [m[@"pollOptions"] isKindOfClass:NSArray.class]
							? m[@"pollOptions"] : @[],
					@"totalVoterCount" : [m[@"pollTotal"] isKindOfClass:NSNumber.class]
							? m[@"pollTotal"] : @0,
					@"isClosed"        : [m[@"pollClosed"] isKindOfClass:NSNumber.class]
							? m[@"pollClosed"] : @NO,
					@"isQuiz"          : [m[@"pollQuiz"] isKindOfClass:NSNumber.class]
							? m[@"pollQuiz"] : @NO,
				};
		NSArray *options = [poll[@"options"] isKindOfClass:NSArray.class]
				? poll[@"options"] : @[];
		NSString *question = [poll[@"question"] isKindOfClass:NSString.class]
				? poll[@"question"] : @"Poll";
		NSString *description = [poll[@"description"] isKindOfClass:NSString.class]
				? poll[@"description"] : @"";
		NSString *explanation = [poll[@"explanation"] isKindOfClass:NSString.class]
				? poll[@"explanation"] : @"";
		BOOL closed = [poll[@"isClosed"] boolValue];
		BOOL multiple = [poll[@"allowsMultiple"] boolValue];
		BOOL showsResults = TGPollShowsResults(poll);

		NSString *kindLine = TGPollKindLine(poll);
		NSString *closesLine = TGPollClosesLine(poll,
				[[NSDate date] timeIntervalSince1970]);
		if (closesLine.length)
			kindLine = [NSString stringWithFormat:@"%@, e%@", kindLine,
					[closesLine substringFromIndex:1]];

		int64_t msgId = [m[@"id"] longLongValue];
		NSMutableIndexSet *pending = self.pendingPollVotes[@(msgId)];
		BOOL hasPending = [pending isKindOfClass:NSIndexSet.class] && pending.count > 0;
		BOOL showVote = multiple && !closed && !showsResults && hasPending;
		BOOL showExplanation = showsResults && explanation.length > 0;

		cell.bubble.frame = layout.bubbleFrame;
		cell.bubble.backgroundColor = mine ? [pollTheme bubbleMineColour] : [pollTheme bubbleTheirsColour];
		cell.bubble.layer.borderWidth = TGMetricBorderNone;
		cell.bubble.layer.borderColor = [UIColor clearColor].CGColor;
		cell.bubble.layer.cornerRadius = [pollTheme bubbleCornerRadius];

		CGFloat contentW = layout.bubbleFrame.size.width - TGDoubled(kPadH);
		CGSize questionSize = TGTextSize(question, TGFontBodyStrong(), contentW);

		cell.body.hidden = NO;
		cell.body.numberOfLines = 0;
		cell.body.font = TGFontBodyStrong();
		cell.body.textColor = [pollTheme primaryTextColour];
		NSArray *questionEntities = [poll[@"questionEntities"] isKindOfClass:NSArray.class] ? poll[@"questionEntities"] : nil;
		if (questionEntities.count) {
			cell.body.attributedText = TGAttributedMessageText(question, questionEntities, cell.body.font, cell.body.textColor);
		} else {
			cell.body.text = question;
		}
		CGFloat y = kPadV + (layout.senderName.length ? TGMetricSenderLineHeight : TGMetricZero);
		cell.body.frame = CGRectMake(kPadH, y, contentW, questionSize.height);
		y += questionSize.height;

		if (description.length) {
			CGFloat descriptionH = TGTextSize(description, TGFontSubhead(),
					contentW).height;
			cell.subtitle.hidden = NO;
			cell.subtitle.numberOfLines = 0;
			cell.subtitle.font = TGFontSubhead();
			cell.subtitle.textColor = [pollTheme secondaryTextColour];
			cell.subtitle.text = description;
			y += kPollDescriptionGap;
			cell.subtitle.frame = CGRectMake(kPadH, y, contentW, descriptionH);
			y += descriptionH;
		} else {
			cell.subtitle.hidden = YES;
			cell.subtitle.text = @"";
		}

		CGFloat kindY = y + kPollKindGap;
		CGFloat optionsY = kindY + kPollKindLine + kPollOptionsGap;

		NSUInteger revision = 5381;
		revision = revision * 33 + (NSUInteger)[poll[@"totalVoterCount"] longLongValue];
		revision = revision * 33 + options.count;
		revision = revision * 33 + (closed ? 1 : 0);
		revision = revision * 33 + (showsResults ? 1 : 0);
		revision = revision * 33 + (multiple ? 1 : 0);
		revision = revision * 33 + (NSUInteger)([poll[@"correctOption"] longLongValue] + 1);
		revision = revision * 33 + description.length;
		revision = revision * 33 + explanation.length;
		revision = revision * 33 + kindLine.length;
		for (NSUInteger i = 0; i < options.count; i++) {
			NSDictionary *option = [options[i] isKindOfClass:NSDictionary.class]
					? options[i] : @{};
			revision = revision * 33 + TGPollOptionText(option).length;
			revision = revision * 33 + (NSUInteger)(TGPollMarkForOption(poll, i) + 1);
			revision = revision * 33 + (NSUInteger)[option[@"percent"] longLongValue];
			if ([pending containsIndex:i])
				revision = revision * 33 + (i + 1);
		}

		if (cell.pollMessageId == msgId && cell.pollRevision == revision) {
			for (UIView *row in cell.bubble.subviews) {
				if (row.tag >= 0x9100 && row.tag < 0x9200) row.hidden = NO;
			}
		} else {
			for (UIView *old in [cell.bubble.subviews copy]) {
				if (old.tag >= 0x9100 && old.tag < 0x9200) [old removeFromSuperview];
			}
			cell.pollMessageId = msgId;
			cell.pollRevision = revision;

			UILabel *kind = [[UILabel alloc] initWithFrame:
					CGRectMake(kPadH, kindY, contentW, kPollKindLine)];
			kind.tag = 0x91E0;
			kind.font = TGFontMeta();
			kind.textColor = [pollTheme secondaryTextColour];
			kind.backgroundColor = [UIColor clearColor];
			kind.text = kindLine;
			[cell.bubble addSubview:kind];

			CGFloat rowW = layout.bubbleFrame.size.width - TGDoubled(kPadH);
			CGFloat rowY = optionsY;
			for (NSUInteger i = 0; i < options.count; i++) {
				NSDictionary *option = [options[i] isKindOfClass:NSDictionary.class]
						? options[i] : @{};
				TGPollMark mark = TGPollMarkForOption(poll, i);
				BOOL pendingHere = multiple && [pending containsIndex:i];
				BOOL filled = mark != TGPollMarkNone || pendingHere;
				UIColor *dotColour = mark == TGPollMarkWrong
						? [pollTheme destructiveColour] : [pollTheme accentColour];

				NSString *optionText = TGPollOptionText(option);
				CGFloat textW = rowW - kPollTextColumn - kPollShareWidth - TGMetricPadTiny;
				CGFloat textH = TGTextSize(optionText, TGFontSubhead(), textW).height;
				CGFloat rowH = TGPollOptionRowHeight(option, rowW);
				CGFloat textY = TGMetricPadTiny;

				UIButton *row = [UIButton buttonWithType:UIButtonTypeCustom];
				row.frame = CGRectMake(kPadH, rowY, rowW, rowH);
				row.tag = 0x9100 + (NSInteger)i;
				row.enabled = !closed && !showsResults;
				[row addTarget:self action:@selector(pollOptionTapped:) forControlEvents:UIControlEventTouchUpInside];
				[cell.bubble addSubview:row];

				// The dot marks the first line, wherever a wrapped option puts
				// the rest of its text.
				UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(TGMetricZero,
						textY + TGCenteredOrigin(TGMetricLineSubhead, TGMetricPollDotSide),
						TGMetricPollDotSide, TGMetricPollDotSide)];
				dot.layer.cornerRadius = multiple
						? TGMetricCornerSmall : TGHalf(TGMetricPollDotSide);
				dot.layer.borderWidth = TGMetricBorderMedium;
				dot.layer.borderColor = dotColour.CGColor;
				dot.backgroundColor = filled ? dotColour : [UIColor clearColor];
				[row addSubview:dot];

				UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(kPollTextColumn,
						textY, textW, textH)];
				label.numberOfLines = 0;
				label.font = TGFontSubhead();
				label.textColor = [pollTheme primaryTextColour];
				label.backgroundColor = [UIColor clearColor];
				NSArray *optEntities = [option[@"entities"] isKindOfClass:NSArray.class] ? option[@"entities"] : nil;
				if (optEntities.count) {
					label.attributedText = TGAttributedMessageText(optionText, optEntities, label.font, label.textColor);
				} else {
					label.text = optionText;
				}
				[row addSubview:label];

				if (showsResults) {
					NSInteger share = [option[@"percent"] isKindOfClass:NSNumber.class]
							? [option[@"percent"] integerValue] : 0;
					UILabel *percent = [[UILabel alloc] initWithFrame:
							CGRectMake(rowW - kPollShareWidth, textY,
									kPollShareWidth, TGMetricLineRow)];
					percent.text = [NSString stringWithFormat:@"%ld%%", (long)share];
					percent.font = TGFontCaption();
					percent.textAlignment = NSTextAlignmentRight;
					percent.textColor = [pollTheme secondaryTextColour];
					percent.backgroundColor = [UIColor clearColor];
					[row addSubview:percent];

					// The track stays under the text: below a wrapped option it
					// drops to the bottom of the taller row.
					CGFloat trackY = MAX(textY + textH,
							rowH - kPollTrackDrop - kPollTrackHeight);
					UIView *track = [[UIView alloc] initWithFrame:
							CGRectMake(kPollTextColumn, trackY,
									rowW - kPollTextColumn, kPollTrackHeight)];
					track.backgroundColor = [pollTheme separatorColour];
					[row addSubview:track];

					UIView *fill = [[UIView alloc] initWithFrame:
							CGRectMake(kPollTextColumn, trackY,
									(rowW - kPollTextColumn) * share / TGPercentFull,
									kPollTrackHeight)];
					fill.backgroundColor = [pollTheme accentColour];
					[row addSubview:fill];
				}

				rowY += rowH;
			}

			CGFloat stackY = rowY;
			if (showVote) {
				UIButton *vote = [UIButton buttonWithType:UIButtonTypeCustom];
				vote.tag = 0x91F0;
				stackY += kPollVoteGap;
				vote.frame = CGRectMake(kPadH, stackY, contentW, kPollVoteHeight);
				vote.titleLabel.font = TGFontBodyStrong();
				[vote setTitle:@"Vote" forState:UIControlStateNormal];
				[vote setTitleColor:[pollTheme accentColour] forState:UIControlStateNormal];
				[vote setTitleColor:[pollTheme accentColour] forState:UIControlStateHighlighted];
				vote.backgroundColor = [UIColor clearColor];
				[vote addTarget:self action:@selector(pollVoteTapped:) forControlEvents:UIControlEventTouchUpInside];
				[cell.bubble addSubview:vote];
				stackY += kPollVoteHeight;
			}

			if (showExplanation) {
				CGFloat explanationH = TGTextSize(explanation, TGFontCaption(),
						contentW).height;
				stackY += kPollExplanationGap;
				UILabel *note = [[UILabel alloc] initWithFrame:
						CGRectMake(kPadH, stackY, contentW, explanationH)];
				note.tag = 0x91F2;
				note.numberOfLines = 0;
				note.font = TGFontCaption();
				note.textColor = [pollTheme secondaryTextColour];
				note.backgroundColor = [UIColor clearColor];
				note.text = explanation;
				[cell.bubble addSubview:note];
				stackY += explanationH;
			}

			stackY += kPollFooterGap;
			UILabel *footer = [[UILabel alloc] initWithFrame:
					CGRectMake(kPadH, stackY, contentW, kPollFooterLine)];
			footer.tag = 0x91F1;
			footer.font = TGFontMeta();
			footer.textColor = [pollTheme secondaryTextColour];
			footer.backgroundColor = [UIColor clearColor];
			footer.text = TGPollVotesLine(poll);
			[cell.bubble addSubview:footer];
		}

		cell.picture.hidden = YES;
		cell.disc.hidden = YES;
		cell.time.text = layout.stamp;
		cell.time.textColor = mine ? [pollTheme timeMineColour] : [pollTheme timeColour];
		TGPlaceStamp(cell, layout.bubbleFrame, layout.timeWidth, mine);
		cell.ticks.hidden = !mine;
		if (mine) {
			cell.ticks.image = [self ticksForMessage:m white:NO];
			TGPlaceTicks(cell, layout.bubbleFrame);
		}
		return YES;
	}

	// Documents
	if (layout.isDoc) {
		TGTheme *cardTheme = [TGTheme shared];
		CGFloat fwd = [self layoutForwardIn:cell message:m width:layout.bubbleFrame.size.width];
		cell.bubble.frame = layout.bubbleFrame;
		cell.bubble.backgroundColor = mine ? [cardTheme bubbleMineColour] : [cardTheme bubbleTheirsColour];
		cell.bubble.layer.borderWidth = TGMetricBorderNone;
		cell.bubble.layer.borderColor = [UIColor clearColor].CGColor;
		cell.bubble.layer.cornerRadius = [cardTheme bubbleCornerRadius];

		NSArray *docs = nil;
		if (layout.isAlbum && [m[@"albumMessages"] isKindOfClass:NSArray.class]) {
			docs = m[@"albumMessages"];
		}
		if (!docs.count) {
			docs = @[m];
		}

		cell.docMessageId = [m[@"id"] longLongValue];
		__weak typeof(self) weakSelf = self;
		__weak TGBubbleCell *weakCell = cell;

		for (UIView *old in [cell.bubble.subviews copy]) {
			if (old.tag >= 0x9200 && old.tag < 0x9300) [old removeFromSuperview];
		}

		cell.icon.hidden = YES;
		cell.disc.hidden = YES;
		cell.body.hidden = YES;
		cell.subtitle.hidden = YES;

		CGFloat curY = fwd + kPadV;
		CGFloat bubbleW = layout.bubbleFrame.size.width;
		CGFloat rowW = bubbleW - TGDoubled(kPadH);

		for (NSUInteger i = 0; i < docs.count; i++) {
			NSDictionary *docMsg = docs[i];
			NSString *fileName = [docMsg[@"docName"] length] ? docMsg[@"docName"] : nil;
			NSString *fileSize = @"";
			if ([docMsg[@"docSize"] longLongValue] > 0) {
				fileSize = [NSString stringWithFormat:@"%.1f KB", [docMsg[@"docSize"] doubleValue] / 1024.0];
			}
			if (!fileName.length) {
				NSArray *lines = [docMsg[@"text"] componentsSeparatedByString:@"\n"];
				fileName = lines.count ? lines[0] : @"Document";
				if (!fileSize.length && lines.count > 1) fileSize = lines[1];
			}

			UIButton *rowBtn = [UIButton buttonWithType:UIButtonTypeCustom];
			rowBtn.tag = 0x9200 + (NSInteger)i;
			rowBtn.frame = CGRectMake(kPadH, curY, rowW, kFileTile);
			[rowBtn addTarget:self action:@selector(docRowTapped:) forControlEvents:UIControlEventTouchUpInside];
			[cell.bubble addSubview:rowBtn];

			UIView *tile = [[UIView alloc] initWithFrame:CGRectMake(TGMetricZero, TGMetricZero, kFileTile, kFileTile)];
			tile.userInteractionEnabled = NO;
			tile.backgroundColor = [cardTheme fileTileColour];
			tile.layer.cornerRadius = TGMetricCornerSmall;
			[rowBtn addSubview:tile];

			UIImageView *disc = [[UIImageView alloc] initWithFrame:CGRectMake(TGCenteredOrigin(kFileTile, kFileDisc),
																			  TGCenteredOrigin(kFileTile, kFileDisc),
																			  kFileDisc, kFileDisc)];
			disc.userInteractionEnabled = NO;
			disc.image = [TGIcons fileDiscOfSide:kFileDisc];
			[tile addSubview:disc];

			NSNumber *thumbId = [docMsg[@"docThumbFileId"] isKindOfClass:NSNumber.class]
					? docMsg[@"docThumbFileId"] : nil;
			if (thumbId.longLongValue > 0) {
				UIImageView *thumb = [[UIImageView alloc] initWithFrame:
						CGRectMake(TGMetricZero, TGMetricZero, kFileTile, kFileTile)];
				thumb.contentMode = UIViewContentModeScaleAspectFill;
				thumb.clipsToBounds = YES;
				thumb.userInteractionEnabled = NO;
				thumb.hidden = YES;
				[tile addSubview:thumb];

				UIImage *cached = self.images[thumbId];
				if (cached) {
					thumb.image = cached;
					thumb.hidden = NO;
					disc.hidden = YES;
				} else if (![self.imagesRequested containsObject:thumbId]) {
					[self.imagesRequested addObject:thumbId];
					int64_t guardId = [m[@"id"] longLongValue];
					CGFloat screenScale = [UIScreen mainScreen].scale;
					[[TGClient shared] downloadFile:[thumbId integerValue]
										 completion:^(NSString *path){
						if (!path.length) {
							dispatch_async(dispatch_get_main_queue(), ^{
								[weakSelf.imagesRequested removeObject:thumbId];
							});
							return;
						}
						dispatch_async(dispatch_get_global_queue(
								DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
							dispatch_semaphore_wait(TGIconsDecodeGate(),
									DISPATCH_TIME_FOREVER);
							__block UIImage *image = nil;
							@autoreleasepool {
								image = [TGIcons decodedImageAtPath:path
										fittingSize:CGSizeMake(kFileTile, kFileTile)
											   fill:YES scale:screenScale];
							}
							dispatch_semaphore_signal(TGIconsDecodeGate());
							if (!image) {
								dispatch_async(dispatch_get_main_queue(), ^{
									[weakSelf.imagesRequested removeObject:thumbId];
								});
								return;
							}
							dispatch_async(dispatch_get_main_queue(), ^{
								TGChatViewController *me = weakSelf;
								TGBubbleCell *guardCell = weakCell;
								if (!me || guardCell.docMessageId != guardId ||
										thumb.superview == nil) {
									[me.imagesRequested removeObject:thumbId];
									return;
								}
								me.images[thumbId] = image;
								[me.imagesRequested removeObject:thumbId];
								thumb.image = image;
								thumb.hidden = NO;
								disc.hidden = YES;
							});
						});
					}];
				}
			}

			CGFloat textX = kFileTile + kTileTextGap;
			CGFloat textW = rowW - textX;

			UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(textX, TGMetricPadTiny, textW, TGMetricLineBody)];
			nameLabel.userInteractionEnabled = NO;
			nameLabel.font = TGFontBody();
			nameLabel.textColor = [cardTheme fileNameColour];
			nameLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
			nameLabel.text = fileName;
			[rowBtn addSubview:nameLabel];

			UILabel *sizeLabel = [[UILabel alloc] initWithFrame:CGRectMake(textX, TGMetricPadTiny + TGMetricLineBody, textW, TGMetricLineSubhead)];
			sizeLabel.userInteractionEnabled = NO;
			sizeLabel.font = TGFontCaption();
			sizeLabel.textColor = [cardTheme fileMetaColour];
			sizeLabel.text = fileSize;
			[rowBtn addSubview:sizeLabel];

			curY += kFileTile + TGMetricPadSmall;
		}

		NSString *caption = [m[@"caption"] length] ? m[@"caption"] : nil;
		if (!caption.length && [m[@"text"] length]) {
			NSString *docName = m[@"docName"] ?: @"";
			if (docName.length == 0 || ![m[@"text"] hasPrefix:docName]) {
				caption = m[@"text"];
			}
		}

		if (layout.bodyFrame.size.height > 0 && caption.length) {
			cell.captionLabel.hidden = NO;
			cell.captionLabel.frame = layout.bodyFrame;
			cell.captionLabel.font = TGFontBody();
			cell.captionLabel.textColor = [cardTheme primaryTextColour];
			NSArray *entities = [m[@"entities"] isKindOfClass:NSArray.class] ? m[@"entities"] : nil;
			if (entities.count) {
				cell.captionLabel.attributedText = TGAttributedMessageText(caption, entities, cell.captionLabel.font, cell.captionLabel.textColor);
			} else {
				cell.captionLabel.text = caption;
			}
			[cell.bubble bringSubviewToFront:cell.captionLabel];
		} else {
			cell.captionLabel.hidden = YES;
		}

		cell.time.text = layout.stamp;
		cell.time.textColor = mine ? [cardTheme timeMineColour] : [cardTheme timeColour];
		if (!CGRectIsEmpty(layout.timeFrame)) {
			cell.time.frame = layout.timeFrame;
		} else {
			TGPlaceStamp(cell, layout.bubbleFrame, layout.timeWidth, mine);
		}
		cell.ticks.hidden = !mine;
		if (mine) {
			cell.ticks.image = [self ticksForMessage:m white:NO];
			TGPlaceTicks(cell, layout.bubbleFrame);
		}
		cell.picture.hidden = YES;
		return YES;
	}

	// Contacts
	if (layout.isContact) {
		NSDictionary *contact = [m[@"contact"] isKindOfClass:NSDictionary.class] ? m[@"contact"] : nil;
		NSString *name = contact[@"name"];
		NSString *phone = contact[@"phoneNumber"];
		if (!name.length || !phone.length) {
			NSArray *lines = [m[@"text"] componentsSeparatedByString:@"\n"];
			if (!name.length && lines.count) name = lines[0];
			if (!phone.length && lines.count > 1) phone = lines[1];
		}
		if (!name.length) name = @"Contact";
		if (!phone.length) phone = @"";

		TGTheme *cardTheme = [TGTheme shared];
		CGFloat fwd = [self layoutForwardIn:cell message:m width:layout.bubbleFrame.size.width];
		cell.bubble.frame = layout.bubbleFrame;
		cell.bubble.backgroundColor = mine ? [cardTheme bubbleMineColour] : [cardTheme bubbleTheirsColour];
		cell.bubble.layer.borderWidth = TGMetricBorderNone;
		cell.bubble.layer.borderColor = [UIColor clearColor].CGColor;
		cell.bubble.layer.cornerRadius = [cardTheme bubbleCornerRadius];

		cell.icon.hidden = NO;
		CGFloat side = kContactDisc;
		cell.icon.frame = CGRectMake(kPadH, fwd + kContactDiscTop, side, side);
		cell.icon.text = [TGIcons initialsForTitle:name];
		cell.icon.font = TGFontHeader();
		cell.icon.layer.cornerRadius = TGHalf(side);
		cell.icon.backgroundColor = [cardTheme mediaCircleColour];

		CGFloat textX = kPadH + side + kTileTextGap;
		CGFloat textW = layout.bubbleFrame.size.width - textX - kPadH;
		cell.body.hidden = NO;
		cell.body.numberOfLines = 1;
		cell.body.font = TGFontBodyStrong();
		cell.body.textColor = [cardTheme primaryTextColour];
		cell.body.text = name;
		TGPlaceTitleDetail(cell, textX, fwd + TGMetricPadSmall, textW);

		cell.subtitle.hidden = NO;
		cell.subtitle.font = TGFontCaption();
		cell.subtitle.textColor = [cardTheme fileMetaColour];
		cell.subtitle.text = phone;

		CGFloat sepY = fwd + kContactButtons;
		cell.contactSeparatorH.hidden = NO;
		cell.contactSeparatorH.backgroundColor = [cardTheme separatorColour];
		cell.contactSeparatorH.frame = CGRectMake(TGMetricZero, sepY,
				layout.bubbleFrame.size.width, TGMetricHairline);

		CGFloat btnW = TGHalf(layout.bubbleFrame.size.width);
		cell.contactSeparatorV.hidden = NO;
		cell.contactSeparatorV.backgroundColor = [cardTheme separatorColour];
		cell.contactSeparatorV.frame = CGRectMake(btnW, sepY, TGMetricHairline, TGMetricButtonHeightSmall);

		cell.contactCallButton.hidden = NO;
		cell.contactCallButton.frame = CGRectMake(TGMetricZero, sepY, btnW, TGMetricButtonHeightSmall);
		[cell.contactCallButton setTitleColor:[cardTheme accentColour] forState:UIControlStateNormal];
		[cell.contactCallButton setTitleColor:[cardTheme buttonHighlightColour] forState:UIControlStateHighlighted];
		cell.contactCallButton.tag = indexPath.row;
		[cell.contactCallButton removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
		[cell.contactCallButton addTarget:self action:@selector(contactCallButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

		cell.contactAddButton.hidden = NO;
		cell.contactAddButton.frame = CGRectMake(btnW, sepY, btnW, TGMetricButtonHeightSmall);
		[cell.contactAddButton setTitleColor:[cardTheme accentColour] forState:UIControlStateNormal];
		[cell.contactAddButton setTitleColor:[cardTheme buttonHighlightColour] forState:UIControlStateHighlighted];
		cell.contactAddButton.tag = indexPath.row;
		[cell.contactAddButton removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
		[cell.contactAddButton addTarget:self action:@selector(contactAddButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

		cell.time.text = layout.stamp;
		cell.time.textColor = mine ? [cardTheme timeMineColour] : [cardTheme timeColour];
		TGPlaceStamp(cell, layout.bubbleFrame, layout.timeWidth, mine);
		cell.ticks.hidden = !mine;
		if (mine) {
			cell.ticks.image = [self ticksForMessage:m white:NO];
			TGPlaceTicks(cell, layout.bubbleFrame);
		}
		cell.picture.hidden = YES;
		return YES;
	}

	// Locations
	if (layout.isLocation) {
		TGTheme *locTheme = [TGTheme shared];
		CGFloat fwd = [self layoutForwardIn:cell message:m width:layout.bubbleFrame.size.width];
		cell.bubble.frame = layout.bubbleFrame;
		cell.bubble.backgroundColor = mine ? [locTheme bubbleMineColour] : [locTheme bubbleTheirsColour];
		cell.bubble.layer.borderWidth = TGMetricBorderNone;
		cell.bubble.layer.borderColor = [UIColor clearColor].CGColor;
		cell.bubble.layer.cornerRadius = [locTheme bubbleCornerRadius];

		CGFloat mapW = layout.bubbleFrame.size.width;
		CGFloat mapH = TGMetricMapCardHeight;

		double lat = [m[@"lat"] doubleValue];
		double lon = [m[@"lon"] doubleValue];

		cell.picture.hidden = NO;
		cell.picture.frame = CGRectMake(TGMetricZero, fwd, mapW, mapH);
		// The card meets the bubble's top edge; the bubble no longer clips
		// (see TGBubbleBackImage), so the card rounds its own top corners.
		cell.picture.clipsToBounds = NO;
		cell.picture.layer.cornerRadius = TGMetricCornerNone;
		cell.picture.image = [TGIcons roundedImage:[self imageFor:m] size:CGSizeMake(mapW, mapH)
											radius:[[TGTheme shared] bubbleCornerRadius]
										   corners:UIRectCornerTopLeft | UIRectCornerTopRight];

		cell.disc.hidden = NO;
		cell.disc.userInteractionEnabled = NO;
		cell.disc.image = [TGIcons mapPinBadge];
		cell.disc.frame = CGRectMake(TGCenteredOrigin(mapW, kMapPinWidth),
				fwd + TGCenteredOrigin(mapH, kMapPinHeight) - kMapPinLift,
				kMapPinWidth, kMapPinHeight);
		[cell.bubble bringSubviewToFront:cell.disc];

		cell.icon.hidden = NO;
		cell.icon.layer.cornerRadius = TGMetricCornerSmall;
		cell.icon.backgroundColor = [[TGTheme shared] mediaOverlayColour];
		cell.icon.textColor = [[TGTheme shared] onMediaColour];
		cell.icon.font = TGFontPlate();
		cell.icon.text = @" Apple Maps ";
		cell.icon.frame = CGRectMake(kMediaStampInset, fwd + mapH - TGMetricFloatingDateHeight,
				kMapCreditWidth, TGMetricLineCaption);
		[cell.bubble bringSubviewToFront:cell.icon];

		cell.mediaStamp.hidden = YES;

		NSDictionary *venue = [m[@"venue"] isKindOfClass:NSDictionary.class] ? m[@"venue"] : nil;
		NSString *vTitle = venue[@"title"];
		NSString *vAddr = venue[@"address"];
		if (!vTitle.length) {
			NSArray *lines = [m[@"text"] componentsSeparatedByString:@"\n"];
			if (lines.count > 1) {
				vTitle = lines[0];
				vAddr = lines[1];
			} else if (lines.count == 1 && ![lines[0] isEqualToString:@"Location"]) {
				vTitle = lines[0];
			}
		}

		BOOL titleIsCoords = NO;
		if (vTitle.length) {
			NSCharacterSet *coordChars = [NSCharacterSet characterSetWithCharactersInString:@"0123456789., -+°NSEWnsew"];
			if ([[vTitle stringByTrimmingCharactersInSet:coordChars] length] == 0 &&
				[vTitle rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet]].location != NSNotFound) {
				titleIsCoords = YES;
			}
		}
		if (titleIsCoords) {
			if (!vAddr.length) {
				vAddr = vTitle;
			}
			vTitle = @"Location";
		}

		if (!vTitle.length) vTitle = @"Location";
		if (!vAddr.length && !titleIsCoords) {
			vAddr = [NSString stringWithFormat:@"%.4f, %.4f", lat, lon];
		}
		if ([vTitle isEqualToString:vAddr]) {
			vAddr = @"";
		}
		// A live location says whether it still moves and when it last did,
		// in place of an address.
		NSDictionary *live = [m[@"live"] isKindOfClass:NSDictionary.class] ? m[@"live"] : nil;
		if (live) {
			NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
			vTitle = TGLiveLocationStatus(live, [m[@"date"] doubleValue], now);
			// Official writes only the freshness here; the line is one
			// narrow row, and heading and alert would be cut off anyway.
			// ponytail: heading as an arrow on the pin, when the map grows one.
			vAddr = TGLiveLocationUpdated([m[@"editDate"] doubleValue], now)
					?: TGLiveLocationRadius([live[@"proximityRadius"] longLongValue]) ?: @"";
		}

		CGFloat locTimeW = layout.timeWidth;
		CGFloat locTicks = mine ? TGMetricStampTicksRoom : TGMetricZero;

		cell.body.hidden = NO;
		cell.body.numberOfLines = 1;
		cell.body.font = TGFontSubheadStrong();
		cell.body.textColor = [locTheme primaryTextColour];
		cell.body.text = vTitle;

		if (vAddr.length > 0) {
			cell.subtitle.hidden = NO;
			cell.subtitle.numberOfLines = 1;
			cell.subtitle.font = TGFontMeta();
			cell.subtitle.textColor = [locTheme fileMetaColour];
			cell.subtitle.text = vAddr;
			TGPlaceTitleDetail(cell, kPadH, fwd + mapH + TGMetricPadTiny,
							   mapW - TGDoubled(kPadH));
			CGRect detail = cell.subtitle.frame;
			detail.size.width -= locTimeW + locTicks + TGMetricPadSmall;
			cell.subtitle.frame = detail;
		} else {
			cell.subtitle.hidden = YES;
			cell.subtitle.text = @"";
			cell.body.frame = CGRectMake(kPadH, fwd + mapH + TGMetricPadMedium,
					mapW - TGDoubled(kPadH) - locTimeW - locTicks - TGMetricPadSmall,
					TGMetricLineBody);
		}

		cell.time.hidden = NO;
		cell.time.text = layout.stamp;
		cell.time.textColor = mine ? [locTheme timeMineColour] : [locTheme timeColour];
		cell.time.frame = CGRectMake(layout.bubbleFrame.size.width - locTimeW - locTicks - kPadH,
									 layout.bubbleFrame.size.height - TGMetricStampBottomInset,
									 locTimeW, TGMetricStampHeight);

		cell.ticks.hidden = !mine;
		if (mine) {
			cell.ticks.image = [self ticksForMessage:m white:NO];
			cell.ticks.frame = CGRectMake(layout.bubbleFrame.size.width - locTicks - kPadH + TGMetricPadTiny,
										  layout.bubbleFrame.size.height - TGMetricStampBottomInset
												  + TGMetricPadTiny,
										  TGMetricTicksWidth, TGMetricTicksHeight);
			[cell.bubble bringSubviewToFront:cell.ticks];
		}
		return YES;
	}

	return NO;
}

@end
