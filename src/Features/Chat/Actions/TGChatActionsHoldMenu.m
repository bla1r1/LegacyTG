#import "TGChatViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGForwardPicker.h"
#import "TGPopupMenu.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGReactionPicker.h"
#import "TGDateFormat.h"
#import "TGOptions.h"
#import "TGMessageStore.h"
#import "TGInstantViewController.h"
#import "TGMessageAudienceViewController.h"
#import "TGChecklistViewController.h"
#import "TGSuggestedPostViewController.h"
#import "TGSponsoredMessagesViewController.h"
#import "TGGameScoresViewController.h"
#import "TGPollPresentation.h"
#import "TGChatActionMenuModel.h"
#import "TGPerf.h"
#import "TGPresent.h"
#import "TGLabel.h"
#import "TGControls.h"
#import <CoreImage/CoreImage.h>
#import <QuartzCore/QuartzCore.h>


/// What the reply strip shows on its second line. The rows here are already
/// flattened, so TGMessagePreview - which reads a raw TDLib content - cannot
/// be used; a media row carries no text and is named by its kind instead.
static NSString *TGComposePreview(NSDictionary *m) {
	return TGDescribeMessageContent(m);
}

/// The poll's vote graph as lines this OS can draw in a sheet. TDLib hands
/// statisticalGraphData over as a JSON chart: one columns entry per series,
/// its first element naming the answer, the rest counting the votes each
/// bucket took. Whatever the chart says the reader cannot hold falls back
/// to the options' own share the bubble already knows, so the sheet is
/// honest even when the graph arrives in a spelling this file never saw.
static NSString *TGPollGraphLines(NSString *json, NSArray *options) {
	NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
	NSDictionary *chart = data.length
			? [NSJSONSerialization JSONObjectWithData:data
					options:NSJSONReadingAllowFragments error:nil] : nil;
	NSArray *columns = [chart isKindOfClass:NSDictionary.class]
			? chart[@"columns"] : nil;
	NSArray *labels = [chart isKindOfClass:NSDictionary.class]
			? (chart[@"labels"] ?: chart[@"x"]) : nil;

	NSMutableString *out = [NSMutableString string];
	if ([columns isKindOfClass:NSArray.class] && columns.count){
		for (NSUInteger i = 1; i < columns.count; i++){
			NSArray *series = [columns[i] isKindOfClass:NSArray.class]
					? columns[i] : nil;
			if (!series || !series.count)
				continue;
			NSString *name = [series[0] isKindOfClass:NSString.class]
					? series[0]
					: [NSString stringWithFormat:@"Answer %lu",
							(unsigned long)i];
			NSInteger votes = 0;
			for (NSUInteger j = 1; j < series.count; j++)
				votes += (NSInteger)[series[j] doubleValue];
			NSString *title = nil;
			NSInteger k = (NSInteger)i - 1;
			if (k >= 0 && k < (NSInteger)options.count){
				NSDictionary *option = options[k];
				id ot = option[@"text"];
				title = [ot isKindOfClass:[NSDictionary class]] ? (ot[@"text"] ?: @"") : ([ot isKindOfClass:[NSString class]] ? (NSString *)ot : @"");
			}
			NSString *who = [title isKindOfClass:NSString.class] && title.length
					? title : name;
			[out appendFormat:@"%@ · %ld votes\n", who, (long)votes];
		}
		if ([labels isKindOfClass:NSArray.class] && labels.count)
			[out appendFormat:@"\n%lu time slices", (unsigned long)labels.count];
		return out.length ? out : nil;
	}

	// The chart said nothing this reader could hold: the options' own
	// percentages from the bubble, which are the same story told plainer.
	for (NSDictionary *option in options){
		id ot = option[@"text"];
		NSString *title = [ot isKindOfClass:[NSDictionary class]] ? (ot[@"text"] ?: @"") : ([ot isKindOfClass:[NSString class]] ? (NSString *)ot : @"?");
		NSString *counts = option[@"voter_count"]
				? [NSString stringWithFormat:@" · %ld votes",
						(long)[option[@"voter_count"] integerValue]]
				: @"";
		[out appendFormat:@"%@%@ · %ld%%\n", title, counts,
				(long)[option[@"vote_percentage"] integerValue]];
	}
	return out.length ? out : nil;
}

/// The sticker's own file, whichever shape the message carries it in: a .tgs
/// rides as the document, a .webp as the picture.
static NSInteger TGStickerFileId(NSDictionary *m) {
	NSNumber *docId = [m[@"docId"] isKindOfClass:NSNumber.class] ? m[@"docId"] : nil;
	if (docId.integerValue > 0 && [m[@"docName"] isEqualToString:@"tgs"])
		return docId.integerValue;
	NSNumber *photoId = [m[@"photoId"] isKindOfClass:NSNumber.class] ? m[@"photoId"] : nil;
	return photoId.integerValue > 0 ? photoId.integerValue : docId.integerValue;
}


/// The read/reaction line at the top of the message card. It is one row of
/// the same card, so it scrolls and clips with it; the numbers are labels,
/// not a second row that the menu builder has to know about.
@interface TGReadSummaryHeaderView : UIView {
	UIButton *_button;
	UIImageView *_glyph;
	UILabel *_seen;
	UILabel *_reactions;
}
- (void)setViewerCount:(NSInteger)viewers reactionCount:(NSInteger)reactions;
- (void)addTarget:(id)target action:(SEL)action;
@end

@implementation TGReadSummaryHeaderView

- (instancetype)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (!self)
		return nil;

	TGTheme *theme = [TGTheme shared];
	_button = TGPlateButton(TGMetricMenuReadHeaderHeight, nil, NULL);
	_button.frame = self.bounds;
	_button.autoresizingMask = UIViewAutoresizingFlexibleWidth |
			UIViewAutoresizingFlexibleHeight;
	[self addSubview:_button];

	_glyph = [[UIImageView alloc] initWithFrame:CGRectZero];
	_glyph.image = [TGIcons glyphNamed:@"select" colour:[theme primaryTextColour]
			side:TGMetricMenuReadGlyphSide];
	_glyph.contentMode = UIViewContentModeScaleAspectFit;
	[self addSubview:_glyph];

	_seen = TGLabelWith(TGLabelRowStrong, CGRectZero, nil);
	[self addSubview:_seen];

	_reactions = TGLabelWith(TGLabelCaption, CGRectZero, nil);
	_reactions.textAlignment = NSTextAlignmentRight;
	[self addSubview:_reactions];

	return self;
}

- (void)setViewerCount:(NSInteger)viewers reactionCount:(NSInteger)reactions {
	_seen.text = TGChatActionMenuSeenText(viewers);
	_reactions.text = TGChatActionMenuReactionText(reactions);
	_reactions.hidden = !_reactions.text.length;
	[self setNeedsLayout];
}

- (void)addTarget:(id)target action:(SEL)action {
	[_button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGFloat h = self.bounds.size.height;
	_glyph.frame = CGRectMake(TGMetricPadLarge, TGCenteredOrigin(h,
			TGMetricMenuReadGlyphSide), TGMetricMenuReadGlyphSide,
			TGMetricMenuReadGlyphSide);

	CGFloat left = TGMetricPadLarge + TGMetricMenuReadGlyphSide + TGMetricPad;
	CGFloat right = TGMetricPadLarge;
	CGSize reactionSize = [_reactions sizeThatFits:CGSizeMake(CGFLOAT_MAX, h)];
	CGFloat reactionW = _reactions.hidden ? 0.0f : reactionSize.width;
	_reactions.frame = CGRectMake(self.bounds.size.width - right - reactionW, 0.0f,
			reactionW, h);

	CGFloat seenW = self.bounds.size.width - left - right - reactionW;
	if (!_reactions.hidden)
		seenW -= TGMetricPad;
	_seen.frame = CGRectMake(left, 0.0f, MAX(0.0f, seenW), h);
}

@end

@implementation TGChatViewController (TGChatActionsHoldMenu)

/// One picture of `view`, at `scale` pixels per point. renderInContext is
/// the only path iOS 6 offers.
static UIImage *TGHoldCapture(UIView *view, CGFloat scale) {
	if (!view || CGRectIsEmpty(view.bounds))
		return nil;
	UIGraphicsBeginImageContextWithOptions(view.bounds.size, NO, scale);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	if (!ctx){
		UIGraphicsEndImageContext();
		return nil;
	}
	CGContextSetInterpolationQuality(ctx, kCGInterpolationLow);
	[view.layer renderInContext:ctx];
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

/// The chat as it stands, at `scale`, for the blur. The wallpaper is the
/// slow part (a full-screen picture scaled down: 170 ms on the A4) and does
/// not change between holds, so its small copy is kept per picture and size;
/// the views over it (the list, the composer, the pinned strip) take 5-15 ms.
static UIImage *TGHoldCaptureChat(UIView *root, UIImageView *wallpaper, CGFloat scale) {
	static UIImage *cachedWallpaper = nil;
	static __weak UIImage *cachedSource = nil;
	static CGSize cachedSize;
	if (wallpaper.image && (cachedSource != wallpaper.image ||
			!CGSizeEqualToSize(cachedSize, wallpaper.bounds.size))){
		cachedWallpaper = TGHoldCapture(wallpaper, scale);
		cachedSource = wallpaper.image;
		cachedSize = wallpaper.bounds.size;
	}
	UIGraphicsBeginImageContextWithOptions(root.bounds.size, YES, scale);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	if (!ctx){
		UIGraphicsEndImageContext();
		return nil;
	}
	CGContextSetInterpolationQuality(ctx, kCGInterpolationLow);
	[root.backgroundColor ?: [UIColor blackColor] setFill];
	UIRectFill(root.bounds);
	if (wallpaper.image && cachedWallpaper)
		[cachedWallpaper drawInRect:[wallpaper convertRect:wallpaper.bounds toView:root]];
	for (UIView *sub in root.subviews){
		if (sub == wallpaper || sub.hidden || sub.alpha < TGAlphaEpsilon)
			continue;
		CGContextSaveGState(ctx);
		CGContextTranslateCTM(ctx, CGRectGetMinX(sub.frame), CGRectGetMinY(sub.frame));
		[sub.layer renderInContext:ctx];
		CGContextRestoreGState(ctx);
	}
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

/// The blur behind a held message. Official lays UIBlurEffect over the chat,
/// a frosted Gaussian about 20 points wide; iOS 6 has no live blur, so the
/// chat is captured once at 1x and blurred once: TGTheme's box passes run on
/// a quarter-size copy, which is what makes a radius this wide cheap on the
/// A4 (the old hold used 10 points, a 3-pixel box, and read as a smudge).
static const CGFloat kHoldBlurRadius = 28.0f;

#pragma mark - hold presentation

/// Official lifts the held message out of the list over a blurred, dimmed
/// chat (ContextControllerImpl: UIBlurEffect plus contextMenu.dimColor) and
/// moves it only when the reaction bar or the card would leave the screen.
/// Here the chat is one blurred capture taken without the bubble, the
/// bubble is a sharp copy above it, and nothing is live.
- (CGRect)beginHoldPresentationForCell:(TGBubbleCell *)cell
								 above:(CGFloat)above
								 below:(CGFloat)below
                              didLift:(void (^)(CGRect anchor))didLift {
	if (self.holdBackdropView || self.holdLiftView){
		self.table.scrollEnabled = self.holdTableWasScrollable;
		[self discardHoldPresentation];
	}

	if (!cell || ![cell isKindOfClass:[TGBubbleCell class]])
		return CGRectZero;
	if (!cell.bubble || CGRectIsEmpty(cell.bubble.bounds))
		return CGRectZero;

	CGRect origin = [cell.bubble convertRect:cell.bubble.bounds toView:self.view];
	if (CGRectIsEmpty(origin))
		return CGRectZero;

	double start = TGPerfNow();
	UIImage *bubbleImage = TGHoldCapture(cell.bubble, 0);
	if (!bubbleImage)
		return CGRectZero;
	// The chat without the bubble, so the blur has no ghost of it; the alpha
	// goes straight back so a reload never finds an invisible bubble.
	CGFloat bubbleAlpha = cell.bubble.alpha, tailAlpha = cell.tail.alpha;
	cell.bubble.alpha = TGAlphaTransparent;
	cell.tail.alpha = TGAlphaTransparent;
	UIImage *chat = TGHoldCaptureChat(self.view, self.wallpaperView, 0.25f);
	cell.bubble.alpha = bubbleAlpha;
	cell.tail.alpha = tailAlpha;
	UIImage *blurred = chat ? [TGTheme softenedImage:chat radius:kHoldBlurRadius dim:0] : nil;
	TGPerfReport("hold", "backdrop", start, 50.0);

	TGTheme *theme = [TGTheme shared];
	UIView *backdrop = [[UIView alloc] initWithFrame:self.view.bounds];
	backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	backdrop.backgroundColor = [theme chatBackgroundColour];
	backdrop.alpha = TGAlphaTransparent;
	UIImageView *picture = [[UIImageView alloc] initWithFrame:backdrop.bounds];
	picture.autoresizingMask = backdrop.autoresizingMask;
	picture.contentMode = UIViewContentModeScaleToFill;
	picture.image = blurred;
	[backdrop addSubview:picture];
	// The material's frost, then official's dim over it.
	for (UIColor *wash in @[[theme holdFrostColour], [theme holdDimColour]]){
		UIView *layer = [[UIView alloc] initWithFrame:backdrop.bounds];
		layer.autoresizingMask = backdrop.autoresizingMask;
		layer.backgroundColor = wash;
		[backdrop addSubview:layer];
	}
	[self.view addSubview:backdrop];

	UIImageView *lift = [[UIImageView alloc] initWithImage:bubbleImage];
	lift.frame = origin;
	lift.userInteractionEnabled = NO;
	[self.view addSubview:lift];

	self.holdBackdropView = backdrop;
	self.holdLiftView = lift;
	self.holdLiftOrigin = origin;
	self.holdTableWasScrollable = self.table.scrollEnabled;
	self.table.scrollEnabled = NO;

	// Clear of the pinned strip, inside this screen (it does not run under
	// the navigation bar).
	CGFloat top = TGMetricPad;
	if (self.pinnedBannerView && !self.pinnedBannerView.hidden)
		top = MAX(top, CGRectGetMaxY(self.pinnedBannerView.frame) + TGMetricPadSmall);
	CGFloat bottom = CGRectGetHeight(self.view.bounds) - TGMetricPad;
	CGRect target = origin;
	target.origin.y = TGHoldLiftY(origin, above, below, top, bottom);

	NSInteger generation = ++self.holdGeneration;
	__weak typeof(self) weakSelf = self;
	TGMotionLift(^{
		backdrop.alpha = TGAlphaOpaque;
		lift.frame = target;
	}, ^(BOOL finished){
		TGChatViewController *me = weakSelf;
		if (!me || me.holdGeneration != generation || me.holdLiftView != lift)
			return;
		if (didLift)
			didLift(target);
	});
	return target;
}

- (void)discardHoldPresentation {
	++self.holdGeneration;
	self.holdReturning = NO;
	[self.holdBackdropView removeFromSuperview];
	[self.holdLiftView removeFromSuperview];
	self.holdBackdropView = nil;
	self.holdLiftView = nil;
}

- (void)endHoldPresentation {
	if (!self.holdBackdropView && !self.holdLiftView)
		return;
	// The menu can be dismissed twice on the way out - once by the row or
	// the tap, once by the screen closing. One return is enough.
	if (self.holdReturning)
		return;

	NSInteger generation = ++self.holdGeneration;
	self.holdReturning = YES;
	self.table.scrollEnabled = self.holdTableWasScrollable;

	UIView *backdrop = self.holdBackdropView;
	UIImageView *lift = self.holdLiftView;
	CGRect home = self.holdLiftOrigin;
	TGMotionQuick(^{
		backdrop.alpha = TGAlphaTransparent;
		lift.frame = home;
	}, ^(BOOL finished){
		[backdrop removeFromSuperview];
		[lift removeFromSuperview];
		if (generation != self.holdGeneration)
			return;
		self.holdBackdropView = nil;
		self.holdLiftView = nil;
		self.holdReturning = NO;
	});
}

/// The facts the message dictionary cannot carry: what the chat knows about
/// this hold, and what the selected message is allowed to do.
- (TGChatActionMenuContext)actionMenuContextForMessage:(NSDictionary *)m
												  mine:(BOOL)mine
												heldId:(int64_t)heldId {
	TGChatActionMenuContext context = {0};
	context.mine = mine;
	context.isGroup = self.isGroup;
	context.isChannel = self.isChannel;
	context.isSavedMessages = [[TGMessageStore shared] chatIsSavedMessages:self.chatId];
	context.isPinned = (heldId != 0 && heldId == self.pinnedMessageId);
	context.canReply = ![m[@"service"] boolValue] && ![m[@"failed"] boolValue];
	context.canEdit = mine;
	context.canPin = ![m[@"service"] boolValue] && ![m[@"failed"] boolValue];
	context.canTranslate = YES;
	context.canSpeak = YES;
	context.canViewStats = self.isChannel;
	context.canSelect = YES;
	context.canReport = !mine;
	context.canAddToFavorites = NO;
	// Mono-forum posts are the only ones whose author official names here.
	context.canViewAuthor = NO;
	context.canEditFactCheck = self.isChannel;
	if ([self.actionProperties isKindOfClass:NSDictionary.class] &&
		[self.actionMessage[@"id"] longLongValue] == heldId)
		TGChatActionMenuApplyProperties(&context, self.actionProperties);
#if TG_DEV
	context.hasMessageEffects = [m[@"effectId"] longLongValue] > 0 ||
			[TGMessageStore shared].availableMessageEffectIds.count ||
			[TGMessageStore shared].availableStickerEffectIds.count;
#endif
	return context;
}

/// The whole hold card. One list, in official order: the verbs, the record
/// rows and the debug rows at the end, with no second card behind More.
- (NSArray *)commonActionItemsForMessage:(NSDictionary *)m
									mine:(BOOL)mine
								  heldId:(int64_t)heldId {
	TGChatActionMenuContext context = [self actionMenuContextForMessage:m
																 mine:mine
															   heldId:heldId];
	return TGChatActionMenuRows(m, context);
}

/// The read/reaction summary for an own group or channel message. The count
/// comes from the message when Telegram already counted it, else from the
/// same getMessageViewers call the Who Read This screen uses - never from
/// cell layout.
/// One quiet line across the top of the card: the copy-protection tip or
/// when the message was read.
- (UILabel *)holdCardNote:(NSString *)text {
	UILabel *note = TGLabelWith(TGLabelCaption, CGRectMake(0.0f, 0.0f, TGMetricMenuWidth,
			TGMetricMenuReadHeaderHeight), nil);
	note.textAlignment = NSTextAlignmentCenter;
	note.numberOfLines = 2;
	note.text = text;
	return note;
}

- (UIView *)readSummaryHeaderForMessage:(NSDictionary *)m {
	BOOL mine = [m[@"outgoing"] boolValue];
	TGChatActionMenuContext context = [self actionMenuContextForMessage:m
																 mine:mine
															   heldId:[m[@"id"] longLongValue]];
	// Official's tip in a chat with copying turned off.
	NSString *tip = TGCopyProtectionTip(context, self.chatTitle);
	if (tip)
		return [self holdCardNote:tip];
	// "read 12:30" over our message in a private chat, when TDLib has it.
	if (mine && context.canGetReadDate && !self.isGroup && !self.isChannel){
		UILabel *note = [self holdCardNote:@""];
		__weak UILabel *weakNote = note;
		[[TGMessageStore shared] readDateOfMessage:[m[@"id"] longLongValue] inChat:self.chatId
										completion:^(NSTimeInterval readDate, NSString *reason){
			weakNote.text = TGReadDateText(readDate) ?: reason;
		}];
		return note;
	}
	if (!TGChatActionMenuShowsReadSummary(m, context))
		return nil;

	NSInteger reactionCount = TGChatActionMenuReactionCount(m);
	NSInteger viewers = [m[@"viewCount"] integerValue];
	TGReadSummaryHeaderView *header = [[TGReadSummaryHeaderView alloc]
			initWithFrame:CGRectMake(0.0f, 0.0f, TGMetricMenuWidth,
					TGMetricMenuReadHeaderHeight)];
	[header setViewerCount:viewers reactionCount:reactionCount];
	[header addTarget:self action:@selector(readSummaryTapped)];

	// A group message does not carry its viewer count in interaction_info;
	// the viewers list does. A channel post already has view_count.
	if (viewers <= 0 && self.isGroup){
		int64_t messageId = [m[@"id"] longLongValue];
		int64_t chatId = self.chatId;
		__weak TGReadSummaryHeaderView *weakHeader = header;
		[[TGMessageStore shared] viewersOfMessage:messageId inChat:chatId
								completion:^(NSArray *list){
			TGReadSummaryHeaderView *strongHeader = weakHeader;
			if (!strongHeader || ![list isKindOfClass:NSArray.class])
				return;
			[strongHeader setViewerCount:list.count
						   reactionCount:TGChatActionMenuReactionCount(m)];
		}];
	}
	return header;
}

- (void)readSummaryTapped {
	[TGPopupMenu dismiss];
	[self showViewersOfActionMessage];
}

/// Speak reads the message aloud. iOS 7 and later has the speech synthesiser;
/// older systems can only hand the text to VoiceOver, which is still better
/// than a row that does nothing.
- (void)speakActionMessage {
	NSString *text = [self.actionMessage[@"text"] isKindOfClass:NSString.class]
			? self.actionMessage[@"text"] : @"";
	if (!text.length)
		return;
	Class synthesizerClass = NSClassFromString(@"AVSpeechSynthesizer");
	Class utteranceClass = NSClassFromString(@"AVSpeechUtterance");
	if (synthesizerClass && utteranceClass){
		id synthesizer = [[synthesizerClass alloc] init];
		id utterance = [utteranceClass speechUtteranceWithString:text];
		if ([synthesizer respondsToSelector:@selector(speakUtterance:)])
			[synthesizer performSelector:@selector(speakUtterance:) withObject:utterance];
		return;
	}
	UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, text);
}

- (void)runMessageAction:(NSString *)action {
	NSDictionary *m = self.actionMessage;
	int64_t messageId = [m[@"id"] longLongValue];
	if (!messageId)
		return;

	if ([action isEqualToString:@"Reply"] || [action isEqualToString:@"Quote"] || [action isEqualToString:@"Find Quote"]){
		// A chat can forbid replies to this particular message; can_be_replied
		// is the server's word on it, and opening a composer that would be
		// refused is worse than one line saying so.
		__weak typeof(self) weakSelf = self;
		[[TGMessageStore shared] messagePropertiesForChat:self.chatId
										  messageId:messageId
										 completion:^(NSDictionary *properties){
			TGChatViewController *me = weakSelf;
			if (!me)
				return;
			id allowed = properties[@"can_be_replied"];
			if (allowed && ![allowed boolValue]){
				[TGAlertSheet showMessage:nil title:@"Reply" inView:me.view];
				return;
			}
			me.replyToId = messageId;
			me.editingId = 0;
			NSString *who = [m[@"outgoing"] boolValue] ? TGLocalized(@"You")
					: ([[TGMessageStore shared] nameForUserId:
							[m[@"senderId"] longLongValue]] ?: self.chatTitle ?: TGLocalized(@"Reply"));
			if ([action isEqualToString:@"Quote"] || [action isEqualToString:@"Find Quote"]){
				NSString *fullText = [m[@"text"] isKindOfClass:NSString.class] && [m[@"text"] length]
						? m[@"text"]
						: ([m[@"caption"] isKindOfClass:NSString.class] && [m[@"caption"] length]
								? m[@"caption"] : TGComposePreview(m));
				TGQuotePickerController *picker = [[TGQuotePickerController alloc] initWithText:fullText onQuote:^(NSString *quote){
					TGChatViewController *live = weakSelf;
					if (!live)
						return;
					live.replyToId = messageId;
					live.editingId = 0;
					live.replyQuoteText = quote;
					[live showComposeBanner:who subtitle:[NSString stringWithFormat:@"\"%@\"", quote]];
					[live.input becomeFirstResponder];
				}];
				[TGPresent presentModal:picker kind:TGModalForm from:me];
				return;
			} else {
				me.replyQuoteText = nil;
				[me showComposeBanner:who subtitle:TGComposePreview(m)];
			}
			[me.input becomeFirstResponder];
		}];

	} else if ([action isEqualToString:@"Forward"]){
		TGForwardPicker *picker = [[TGForwardPicker alloc] init];
		picker.sourceChatId = self.chatId;
		__weak typeof(self) weakSelf = self;
		picker.onPickedWithOptions = ^(int64_t targetChatId, BOOL hideSenderName, BOOL hideCaptions){
			[[TGMessageStore shared] forwardMessages:@[@(messageId)]
									  fromChat:weakSelf.chatId
										toChat:targetChatId
									  sendCopy:hideSenderName
								 removeCaption:hideCaptions];
		};
		[TGPresent presentModal:picker kind:TGModalForm from:self];

	} else if ([action isEqualToString:@"View Thread"]){
		[self openCommentsForMessage:m];

	} else if ([action isEqualToString:@"Select"]){
		[self enterEditMode];
		[self toggleMessageSelection:messageId];

	} else if ([action isEqualToString:@"Retry"]){
		[self retryFailedMessage:m];

	} else if ([action isEqualToString:@"Checklist"]){
		TGChecklistViewController *checklist = [[TGChecklistViewController alloc]
				initWithChatId:self.chatId messageId:messageId title:@"Checklist"];
		checklist.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:checklist animated:YES];

	} else if ([action isEqualToString:@"Suggest Post"]){
		TGSuggestedPostViewController *post = [[TGSuggestedPostViewController alloc]
				initWithChatId:self.chatId messageId:messageId];
		post.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:post animated:YES];

	} else if ([action isEqualToString:@"Fact Check"]){
		NSString *existing = [m[@"factCheck"] isKindOfClass:NSString.class]
				? m[@"factCheck"] : @"";
		int64_t chatId = self.chatId;
		__weak typeof(self) weakSelf = self;
		[TGAlertSheet showInput:@"Fact Check"
						message:nil
					placeholder:@"Fact Check"
						   text:existing
						 action:@"Save"
						 inView:self.view
					   onSubmit:^(NSString *text){
			[[TGMessageStore shared] setMessageFactCheck:messageId
											 inChat:chatId
											   text:text
										 completion:^(BOOL ok, NSString *error){
				TGChatViewController *me = weakSelf;
				if (!ok){
					[TGAlertSheet showMessage:(error.length ? error
							: @"An error occurred.")
										 title:@"Fact Check" inView:me.view];
					return;
				}
				[me.layoutCache removeLayoutForMessageId:messageId];
				[me reload];
			}];
		}];

	} else if ([action isEqualToString:@"Show 1 Reply"] ||
			   [action hasPrefix:@"Show "] ||
			   [action isEqualToString:@"Leave a Comment"]){
		[self openCommentsForMessage:m];

	} else if ([action hasPrefix:@"Remove "]){
		[[TGMessageStore shared] removeReaction:m[@"myReaction"]
							  fromMessage:messageId
								   inChat:self.chatId];
		[self.layoutCache removeLayoutForMessageId:messageId];
		[self reload];

	} else if ([action hasPrefix:@"React"]){
		[self askReactionForMessage:messageId];

	} else if ([action isEqualToString:@"Pin"]){
		[[TGMessageStore shared] pinMessage:messageId inChat:self.chatId notify:NO];
		[self performSelector:@selector(loadPinnedMessage) withObject:nil afterDelay:0.6];

	} else if ([action isEqualToString:@"Unpin"]){
		[[TGMessageStore shared] unpinMessage:messageId inChat:self.chatId];
		self.pinnedMessageId = 0;
		[self hidePinnedBanner];

	} else if ([action isEqualToString:@"Stop Poll"]){
		__weak typeof(self) weakSelf = self;
		[TGAlertSheet showConfirm:nil
							title:@"Stop Poll"
						   action:@"Stop"
					  destructive:YES
						   inView:self.view
						onConfirm:^{
			[[TGMessageStore shared] stopPoll:messageId inChat:weakSelf.chatId];
		}];

	} else if ([action isEqualToString:@"Retract Vote"]){
		// The empty answer set is how TDLib takes a vote back; the updated
		// message follows, and the row re-reads a second later.
		[[TGMessageStore shared] votePoll:messageId inChat:self.chatId options:@[]];
		[self.layoutCache removeLayoutForMessageId:messageId];
		__weak typeof(self) weakSelf = self;
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
				(int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			[weakSelf reload];
		});

	} else if ([action isEqualToString:@"Stop Live Location"]){
		// The pin comes off the map: an edit whose period says zero, which
		// is what ending a live location is on the wire.
		int64_t chatId = self.chatId;
		__weak typeof(self) weakSelf = self;
		[TGAlertSheet showConfirm:nil
							title:@"Live Location"
						   action:@"Stop"
					  destructive:YES
						   inView:self.view
						onConfirm:^{
			[[TGMessageStore shared] editLiveLocationOfMessage:messageId
												  inChat:chatId
												latitude:0.0
											   longitude:0.0
											  livePeriod:0
											  completion:nil];
			TGChatViewController *me = weakSelf;
			if (me){
				me.liveLocationMessageId = 0;
				me.liveLocationSeconds = 0;
				[me.locationManager stopUpdatingLocation];
			}
		}];
	} else if ([action isEqualToString:@"PollVoters"]){
		// Who voted which way: the answers first, the people behind one of
		// them next. A poll without answers to look at says so.
		NSArray *options = m[@"pollOptions"];
		NSMutableArray *titles = [NSMutableArray array];
		for (NSDictionary *option in options) {
			id ot = option[@"text"];
			NSString *otStr = [ot isKindOfClass:[NSDictionary class]] ? (ot[@"text"] ?: @"") : ([ot isKindOfClass:[NSString class]] ? (NSString *)ot : @"?");
			[titles addObject:otStr];
		}
		if (!titles.count){
			[TGAlertSheet showMessage:@"An error occurred."
									  title:@"Read All Votes"
								inView:self.view];
			return;
		}
		int64_t chatId = self.chatId;
		__weak typeof(self) weakSelf = self;
		[TGAlertSheet showChoices:titles
							title:m[@"pollQuestion"] ?: @"Poll"
				 destructiveIndex:-1
						   inView:self.view
						 onChoice:^(NSInteger index){
			[[TGMessageStore shared] pollVotersOfOption:index ofMessage:messageId inChat:chatId
									   completion:^(NSArray *voters, BOOL end){
				TGChatViewController *me = weakSelf;
				if (!me)
					return;
				if (!voters.count){
					[TGAlertSheet showMessage:TGLocalized(@"No votes")
										title:TGLocalized(@"Poll Results") inView:me.view];
					return;
				}
				NSMutableArray *rows = [NSMutableArray array];
				for (NSDictionary *voter in voters)
					[rows addObject:voter[@"name"] ?: @"?"];
				NSString *head = [NSString stringWithFormat:@"%@ · %lu%@",
						titles[index], (unsigned long)voters.count,
						end ? @"" : @"…"];
				[TGPresent showList:rows title:head destructiveIndex:-1
			from:self onPick:^(NSInteger pick){}];
			}];
		}];

	} else if ([action isEqualToString:@"Poll Statistics"]){
		// The graph of votes gathered in as the poll ran. TDLib hands the
		// chart over as a JSON string; whatever it holds, the sheet reads
		// every column it recognises into a line per option, worst case a
		// sentence instead of a chart.
		int64_t pollChatId = self.chatId;
		__weak typeof(self) weakSelf = self;
		[[TGMessageStore shared] pollVoteStatisticsOfMessage:messageId
												inChat:pollChatId
											completion:^(NSDictionary *graph){
			TGChatViewController *me = weakSelf;
			if (!me)
				return;
			if (!graph){
				[TGAlertSheet showMessage:@"An error occurred."
									title:@"Statistics"
								   inView:me.view];
				return;
			}
					NSString *lines = TGPollGraphLines(graph[@"json"],
					m[@"pollOptions"]);
			NSString *body = [lines isKindOfClass:NSString.class] && lines.length
					? lines
					: @"An error occurred.";
			[TGAlertSheet showMessage:body
								title:m[@"pollQuestion"] ?: @"Statistics"
								   inView:me.view];
		}];

	} else if ([action isEqualToString:@"Add Option"]){
		// A poll that grew after the fact: the line asked for, sent, and the
		// message re-answered by the update the client does not watch for.
		int64_t chatId = self.chatId;
		__weak typeof(self) weakSelf = self;
		[TGAlertSheet showInput:@"Add an Option"
						message:nil
					placeholder:@"Option"
						   text:nil
						 action:@"Add"
						 inView:self.view
					   onSubmit:^(NSString *text){
			NSString *what = [text stringByTrimmingCharactersInSet:
					[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			[[TGMessageStore shared] addPollOption:what toMessage:messageId inChat:chatId
								  completion:^(BOOL ok){
				TGChatViewController *me = weakSelf;
				if (!ok)
					[TGAlertSheet showMessage:@"An error occurred."
										title:@"Add an Option" inView:me.view];
			}];
		}];

	} else if ([action isEqualToString:@"Delete Option"]){
		// The answer taken out: the options with votes on them are not this
		// menu's to guess at - the server owns the refusal, this sheet owns
		// the confirm.
		NSArray *options = m[@"pollOptions"];
		NSMutableArray *titles = [NSMutableArray array];
		for (NSDictionary *option in options) {
			id ot = option[@"text"];
			NSString *otStr = [ot isKindOfClass:[NSDictionary class]] ? (ot[@"text"] ?: @"") : ([ot isKindOfClass:[NSString class]] ? (NSString *)ot : @"?");
			[titles addObject:otStr];
		}
		int64_t chatId = self.chatId;
		__weak typeof(self) weakSelf = self;
		[TGAlertSheet showChoices:titles
							title:m[@"pollQuestion"] ?: @"Poll"
				 destructiveIndex:-1
						   inView:self.view
						 onChoice:^(NSInteger index){
			NSString *optionId = (NSString *)options[index][@"id"];
			NSString *which = titles[index];
			[TGAlertSheet showConfirm:nil
								title:@"Delete"
							   action:@"Delete"
						  destructive:YES
							   inView:weakSelf.view
							onConfirm:^{
				[[TGMessageStore shared] deletePollOption:optionId
										  ofMessage:messageId
											 inChat:chatId
										 completion:^(BOOL ok){
					TGChatViewController *me = weakSelf;
					if (!ok)
						[TGAlertSheet showMessage:@"An error occurred."
											title:@"Delete" inView:me.view];
				}];
			}];
		}];

	} else if ([action isEqualToString:@"Report Spam"]){
		int64_t chatId = self.chatId;
		__weak typeof(self) weakSelf = self;
		[TGAlertSheet showChoices:@[@"Report", @"Report and Block Sender"]
							title:@"Report Spam"
						  message:nil
				 destructiveIndex:1
						   inView:self.view
						 onChoice:^(NSInteger index){
			TGChatViewController *me = weakSelf;
			if (index == 1)
				[[TGMessageStore shared] blockSenderOfMessage:messageId
										 deleteMessages:YES
											 reportSpam:YES];
			[[TGMessageStore shared] reportSpamMessages:@[@(messageId)]
										   inChat:chatId
									   completion:^(BOOL ok){
				[TGSnackbar showInView:me.view
								  text:(ok ? @"Done" : @"An error occurred.")
							   seconds:2 onCommit:nil];
			}];
		}];

	} else if ([action isEqualToString:@"Report Reaction"]){
		// The flattening decided who is being reported: the latest reactor
		// the message named, with the emoji it put on this bubble.
		NSDictionary *choice = m[@"reactionReport"];
		if (![choice isKindOfClass:NSDictionary.class])
			return;
		int64_t reactionChatId = self.chatId;
		__weak typeof(self) weakSelf = self;
		[TGAlertSheet showConfirm:nil
							title:@"Report Reaction"
						   action:@"Report"
					  destructive:YES
						   inView:self.view
						onConfirm:^{
			[[TGMessageStore shared] reportReactionBySender:choice[@"sender"]
											ofMessage:messageId
												inChat:reactionChatId
										 completion:^(BOOL ok){
				TGChatViewController *me = weakSelf;
				if (!me)
					return;
				[TGSnackbar showInView:me.view
								  text:(ok ? @"Done"
										   : @"An error occurred.")
							   seconds:2 onCommit:nil];
			}];
		}];

	} else if ([action isEqualToString:@"Click Emoji"]){
		int64_t chatId = self.chatId;
		__weak typeof(self) weakSelf = self;
		[[TGMessageStore shared] clickAnimatedEmojiMessage:messageId inChat:chatId
										 completion:^(NSString *emoji){
			TGChatViewController *me = weakSelf;
			if (!me)
				return;
			[TGSnackbar showInView:me.view
							  text:(emoji.length
									? [NSString stringWithFormat:@"%@", emoji]
									: @"None")
						   seconds:2 onCommit:nil];
		}];

	} else if ([action isEqualToString:@"Message Info"]){
		[self showInfoOfActionMessage];

	} else if ([action isEqualToString:@"Shared Media Map"]){
		[self showSparsePositionsOfActionMessage];

	} else if ([action isEqualToString:@"Clear Buttons"]){
		int64_t chatId = self.chatId;
		__weak typeof(self) weakSelf = self;
		[[TGMessageStore shared] clearReplyMarkupOfMessage:messageId inChat:chatId
										 completion:^(BOOL ok){
			TGChatViewController *me = weakSelf;
			if (!me)
				return;
			[TGSnackbar showInView:me.view
							  text:(ok ? @"Done"
									   : @"An error occurred.")
						   seconds:2 onCommit:nil];
		}];

	} else if ([action isEqualToString:@"Message Effects"]){
		// The message's own effect leads, then whatever updateAvailableMessageEffects
		// last listed. Live at the moment of the hold, not the list the menu
		// was built with; a picked id is fetched for its emoji and kind.
		int64_t currentEffect = [m[@"effectId"] longLongValue];
		NSMutableArray *effectIds = [NSMutableArray array];
		NSMutableArray *titles = [NSMutableArray array];
		NSMutableSet *seen = [NSMutableSet set];
		if (currentEffect > 0){
			[effectIds addObject:@(currentEffect)];
			[titles addObject:[NSString stringWithFormat:@"This message - %lld",
					(long long)currentEffect]];
			[seen addObject:@(currentEffect)];
		}
		for (NSNumber *effectId in [TGMessageStore shared].availableMessageEffectIds){
			if ([seen containsObject:effectId])
				continue;
			[seen addObject:effectId];
			[effectIds addObject:effectId];
			[titles addObject:[NSString stringWithFormat:@"Reaction effect %lld",
					(long long)[effectId longLongValue]]];
		}
		for (NSNumber *effectId in [TGMessageStore shared].availableStickerEffectIds){
			if ([seen containsObject:effectId])
				continue;
			[seen addObject:effectId];
			[effectIds addObject:effectId];
			[titles addObject:[NSString stringWithFormat:@"Sticker effect %lld",
					(long long)[effectId longLongValue]]];
		}
		if (!effectIds.count){
			[TGAlertSheet showMessage:@"An error occurred."
								title:@"Message Effects" inView:self.view];
		} else {
			__weak typeof(self) weakSelf = self;
			[TGAlertSheet showChoices:titles
								title:@"Message Effects"
							  message:nil
					 destructiveIndex:-1
							   inView:self.view
							 onChoice:^(NSInteger index){
				if (index < 0 || (NSUInteger)index >= effectIds.count)
					return;
				int64_t effectId = [effectIds[(NSUInteger)index] longLongValue];
				[[TGMessageStore shared] messageEffectWithId:effectId
											completion:^(NSDictionary *effect){
					TGChatViewController *me = weakSelf;
					if (!me)
						return;
					if (!effect){
						[TGAlertSheet showMessage:@"An error occurred."
											title:@"Message Effects" inView:me.view];
						return;
					}
					[TGAlertSheet showMessage:(effect[@"emoji"] ?: @"")
										title:@"Message Effects" inView:me.view];
				}];
			}];
		}

	} else if ([action isEqualToString:@"Copy Link"]){
		__weak typeof(self) weakSelf = self;
		[[TGMessageStore shared] linkToMessage:messageId inChat:self.chatId
							  completion:^(NSString *link){
			TGChatViewController *me = weakSelf;
			if (!link.length){
				[TGSnackbar showInView:me.view text:@"An error occurred."
							   seconds:2 onCommit:nil];
				return;
			}
			[UIPasteboard generalPasteboard].string = link;
			[TGSnackbar showInView:me.view text:@"Link copied." seconds:2 onCommit:nil];
		}];

	} else if ([action isEqualToString:@"Copy"]){
		[UIPasteboard generalPasteboard].string = m[@"text"];

	} else if ([action isEqualToString:@"Who Read This"]){
		[self showViewersOfActionMessage];

	} else if ([action isEqualToString:@"Public Forwards"]){
		[self showPublicForwardsOfActionMessage];

	} else if ([action isEqualToString:@"Reactions"]){
		[self showReactorsOfActionMessage];

	} else if ([action isEqualToString:@"Author"]){
		[self showAuthorOfActionMessage];

	} else if ([action isEqualToString:@"Speak"]){
		[self speakActionMessage];

	} else if ([action isEqualToString:@"View Stats"]){
		[self showChatStatistics];

	} else if ([action isEqualToString:@"Translate"]){
		[self translateActionMessage];


	} else if ([action isEqualToString:@"Search by Hashtag"]){
		NSString *query = m[@"text"] ?: @"";
		NSRange first = [query rangeOfString:@"#"];
		NSString *tag = [query substringFromIndex:first.location];
		NSString *clean = [[tag componentsSeparatedByCharactersInSet:
				[NSCharacterSet whitespaceAndNewlineCharacterSet]] firstObject]
				?: tag;
		// The in-chat search bar owns the results view; a hashtag rides it,
		// just typed for the user.
		[self toggleChatSearchOpenWithTag:clean ?: tag];

	} else if ([action isEqualToString:@"Recent Locations"]){
		[self showRecentLocationsInActionMessage];

	} else if ([action isEqualToString:@"Location"]){
		NSNumber *latitude = m[@"latitude"];
		NSNumber *longitude = m[@"longitude"];
		if (![latitude isKindOfClass:NSNumber.class] ||
				![longitude isKindOfClass:NSNumber.class]){
			[TGAlertSheet showMessage:@"An error occurred."
								title:@"Location" inView:self.view];
			return;
		}
		__weak typeof(self) weakSelf = self;
		[[TGMessageStore shared] currentWeatherAtLatitude:latitude.doubleValue
										  longitude:longitude.doubleValue
										 completion:^(NSDictionary *weather, NSString *error){
			TGChatViewController *me = weakSelf;
			if (!me) return;
			NSString *text = error.length ? error
					: [NSString stringWithFormat:@"%@  %.1f°",
					   weather[@"emoji"] ?: @"", [weather[@"temperature"] doubleValue]];
			[TGAlertSheet showMessage:text title:@"Location" inView:me.view];
		}];

	} else if ([action isEqualToString:@"Transcribe"]){
		TGMessageStore *store = [TGMessageStore shared];
		NSString *cooldown = TGTranscriptionCooldownText([store freeTranscriptionsLeft],
				[store freeTranscriptionsWeekly], [store freeTranscriptionsResetDate],
				[[NSDate date] timeIntervalSince1970]);
		if (cooldown){
			[TGAlertSheet showMessage:cooldown title:nil inView:self.view];
			return;
		}
		__weak typeof(self) weakSelf = self;
		[[TGMessageStore shared] recognizeSpeechInChat:self.chatId message:messageId
									  completion:^(BOOL ok, NSString *error){
			TGChatViewController *me = weakSelf;
			if (!me) return;
			if (ok){
				// The bubble says "Transcribing..." until the text lands; an
				// account on the free trial hears how many are left.
				NSString *left = TGFreeTranscriptionsText([[TGMessageStore shared] freeTranscriptionsLeft]);
				if (left)
					[TGSnackbar showInView:me.view text:left seconds:3 onCommit:nil];
				return;
			}
			NSString *text = error.length ? error
					: @"An error occurred.";
			[TGAlertSheet showMessage:text title:@"Transcribe" inView:me.view];
		}];

	} else if ([action isEqualToString:@"Rate Transcription"]){
		__weak typeof(self) weakSelf = self;
		[TGAlertSheet showChoices:@[@"Thumbs Up", @"Thumbs Down"]
							title:@"Rate Transcription" destructiveIndex:-1
						   inView:self.view onChoice:^(NSInteger index){
			[[TGMessageStore shared] rateSpeechInChat:weakSelf.chatId message:messageId
										 isGood:(index == 0)
									 completion:^(BOOL ok, NSString *error){
				NSString *text = ok ? @"Done"
						: (error.length ? error : @"An error occurred.");
				[TGAlertSheet showMessage:text title:@"Rate Transcription"
								   inView:weakSelf.view];
			}];
		}];

	} else if ([action isEqualToString:@"Video Advertisements"]){
		TGSponsoredMessagesViewController *ads =
				[[TGSponsoredMessagesViewController alloc] init];
		ads.chatId = self.chatId;
		ads.messageId = messageId;
		ads.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:ads animated:YES];

	} else if ([action isEqualToString:@"Game Scores"]){
		TGGameScoresViewController *scores =
				[[TGGameScoresViewController alloc] init];
		scores.chatId = self.chatId;
		scores.messageId = messageId;
		scores.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:scores animated:YES];

	} else if ([action isEqualToString:@"Copy Embed Code"]){
		int64_t chatId = self.chatId;
		__weak typeof(self) weakSelf = self;
		[[TGMessageStore shared] embeddingCodeOfMessage:messageId inChat:chatId
											album:[m[@"isAlbum"] boolValue]
									   completion:^(NSString *code){
			TGChatViewController *me = weakSelf;
			if (!me) return;
			if (!code.length){
				[TGSnackbar showInView:me.view
								  text:@"An error occurred." seconds:2 onCommit:nil];
				return;
			}
			[UIPasteboard generalPasteboard].string = code;
			[TGSnackbar showInView:me.view text:@"Code copied to clipboard" seconds:2 onCommit:nil];
		}];

	} else if ([action isEqualToString:@"Replace Photo"]){
		self.editingId = messageId;
		self.editingIsCaption = NO;
		self.replacingPhoto = YES;
		self.replacingPhotoCaption = m[@"text"] ?: @"";
		[self pickReplacementPhoto];

	} else if ([action isEqualToString:@"Edit"]){
		self.editingId = messageId;
		self.replyToId = 0;
		// Media carries a caption, and a caption is not text: the commit has
		// to know which request to send.
		self.editingIsCaption = [m[@"photoId"] isKindOfClass:NSNumber.class] ||
								[m[@"docId"] isKindOfClass:NSNumber.class];
		NSString *text = [m[@"text"] isKindOfClass:NSString.class] ? m[@"text"] : @"";
		NSArray *entities = [m[@"entities"] isKindOfClass:NSArray.class] ? m[@"entities"] : @[];
		NSDictionary *inFt = @{
			@"@type" : @"formattedText",
			@"text" : text,
			@"entities" : entities
		};
		NSDictionary *ft = [[TGMessageStore shared] markdownForEditing:inFt];
		NSString *editText = [ft[@"text"] isKindOfClass:NSString.class] ? ft[@"text"] : text;
		NSArray *editEntities = [ft[@"entities"] isKindOfClass:NSArray.class] ? ft[@"entities"] : entities;
		self.input.text = editText;
		self.composerText = [[TGComposerText alloc] initWithText:editText entities:editEntities];
		[self showComposeBanner:self.editingIsCaption ? @"Edit Caption" : @"Edit"];
		[self.input becomeFirstResponder];
		[self inputChanged];

	} else if ([action isEqualToString:@"Add to Favourites"]){
		[[TGMessageStore shared] setSticker:TGStickerFileId(m) favourite:YES];
		[TGSnackbar showInView:self.navigationController.view ?: self.view
						  text:@"Done" seconds:2 onCommit:nil];

	} else if ([action isEqualToString:@"Delete"]){
		[self promptDeleteMessages:@[@(messageId)]];
	}
	self.actionMessage = nil;
}

/// One graph as a line: an error, a loading token, or the sums of its
/// series. The chart arrives as JSON; nothing here invents a number it does
/// not contain.
static NSString *TGStatGraphLine(NSDictionary *graph, NSString *label) {
	if (![graph isKindOfClass:NSDictionary.class])
		return nil;
	NSString *error = graph[@"error_message"];
	if ([error isKindOfClass:NSString.class] && error.length)
		return [NSString stringWithFormat:@"%@: %@", label, error];
	if ([graph[@"token"] isKindOfClass:NSString.class])
		return [NSString stringWithFormat:@"%@: still loading", label];
	NSString *json = graph[@"json_data"];
	NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
	NSDictionary *chart = data.length
			? [NSJSONSerialization JSONObjectWithData:data
					options:NSJSONReadingAllowFragments error:nil] : nil;
	NSArray *columns = [chart isKindOfClass:NSDictionary.class]
			? chart[@"columns"] : nil;
	if ([columns isKindOfClass:NSArray.class] && columns.count > 1){
		NSMutableString *parts = [NSMutableString string];
		for (NSUInteger i = 1; i < columns.count; i++){
			NSArray *series = [columns[i] isKindOfClass:NSArray.class]
					? columns[i] : nil;
			if (!series.count)
				continue;
			double total = 0;
			for (NSUInteger j = 1; j < series.count; j++)
				total += [series[j] doubleValue];
			NSString *name = [series[0] isKindOfClass:NSString.class]
					? series[0]
					: [NSString stringWithFormat:@"Series %lu", (unsigned long)i];
			[parts appendFormat:@"%@ %.0f  ", name, total];
		}
		if (parts.length)
			return [NSString stringWithFormat:@"%@: %@", label, parts];
	}
	return [NSString stringWithFormat:@"%@: chart available", label];
}

/// The message's own record, gathered in one sheet: what is cached, where it
/// sits, the channel graphs, the effect it carries, and the view report TDLib
/// asks for whenever a message has been seen. Any of those can be refused
/// without taking the rest down - the sheet says which.
- (void)showInfoOfActionMessage {
	NSDictionary *m = self.actionMessage;
	int64_t messageId = [m[@"id"] longLongValue];
	if (!messageId)
		return;
	int64_t chatId = self.chatId;

	// How much of the viewport the row takes, which is the ratio TDLib
	// stores. A row that cannot be found still reports as fully seen.
	NSInteger heightPerMille = 1000;
	for (NSInteger row = 0; row < (NSInteger)self.messages.count; row++){
		if ([self.messages[row][@"id"] longLongValue] != messageId)
			continue;
		CGRect rect = [self.table rectForRowAtIndexPath:
				[NSIndexPath indexPathForRow:row inSection:0]];
		CGFloat viewport = CGRectGetHeight(self.table.bounds);
		if (viewport > 0)
			heightPerMille = (NSInteger)(CGRectGetHeight(rect) / viewport * 1000);
		break;
	}
	if (heightPerMille <= 0)
		heightPerMille = 1000;

	dispatch_group_t group = dispatch_group_create();
	__block NSString *localLine = @"Local copy: not cached";
	__block NSInteger position = 0;
	__block NSDictionary *statistics = nil;
	__block NSString *effectLine = nil;
	int64_t effectId = [m[@"effectId"] longLongValue];
	__weak typeof(self) weakSelf = self;

	dispatch_group_enter(group);
	[[TGMessageStore shared] localMessageWithId:messageId inChat:chatId
							   completion:^(NSDictionary *local){
		if (local){
			NSString *text = local[@"text"];
			localLine = text.length
					? [NSString stringWithFormat:@"Local copy: %@", text]
					: @"Local copy: cached";
		}
		dispatch_group_leave(group);
	}];

	dispatch_group_enter(group);
	[[TGMessageStore shared] positionOfMessage:messageId inChat:chatId
								  thread:self.threadId
							  completion:^(NSInteger found){
		position = found;
		dispatch_group_leave(group);
	}];

	dispatch_group_enter(group);
	[[TGMessageStore shared] statisticsOfMessage:messageId inChat:chatId
								completion:^(NSDictionary *found){
		statistics = found;
		dispatch_group_leave(group);
	}];

	if (effectId > 0){
		dispatch_group_enter(group);
		[[TGMessageStore shared] messageEffectWithId:effectId
									completion:^(NSDictionary *effect){
			if (effect)
				effectLine = [NSString stringWithFormat:@"Effect: %@%@",
						effect[@"emoji"] ?: @"",
						[effect[@"premium"] boolValue] ? @" (Premium)" : @""];
			dispatch_group_leave(group);
		}];
	}

	// The message is on screen while its menu is open, which is the thing
	// this report is for; one second is TDLib's own floor for counting it.
	// It does not hold the sheet open: the report is a side effect.
	[[TGMessageStore shared] reportViewOfMessage:messageId inChat:chatId
							  timeInViewMs:1000
						activeTimeInViewMs:1000
							   heightRatio:heightPerMille
						 seenRangeRatio:1000
								completion:nil];

	dispatch_group_notify(group, dispatch_get_main_queue(), ^{
		TGChatViewController *me = weakSelf;
		if (!me)
			return;
		NSMutableArray *lines = [NSMutableArray arrayWithObject:localLine];
		if (position > 0)
			[lines addObject:[NSString stringWithFormat:@"Position: %ld in this chat",
					(long)position]];
		else
			[lines addObject:@"Position: not counted here"];
		if (effectLine.length)
			[lines addObject:effectLine];
		NSString *interaction = TGStatGraphLine(
				statistics[@"message_interaction_graph"], @"Views");
		NSString *reactions = TGStatGraphLine(
				statistics[@"message_reaction_graph"], @"Reactions");
		if (interaction.length)
			[lines addObject:interaction];
		if (reactions.length)
			[lines addObject:reactions];
		if (!statistics)
			[lines addObject:@"Statistics: not a channel post, or not "
							  @"released to this account"];
		[TGAlertSheet showMessage:[lines componentsJoinedByString:@"\n"]
							title:@"Info" inView:me.view];
	});
}

/// The sparse positions a shared-media scroll is built from, shown as the
/// ids Telegram returned. A chat with no positions says so rather than
/// opening an empty list.
- (void)showSparsePositionsOfActionMessage {
	NSDictionary *m = self.actionMessage;
	int64_t messageId = [m[@"id"] longLongValue];
	if (!messageId)
		return;
	int64_t chatId = self.chatId;
	__weak typeof(self) weakSelf = self;
	[[TGMessageStore shared] sparsePositionsInChat:chatId fromMessageId:messageId
									  thread:self.threadId limit:200
								  completion:^(NSArray *ids){
		TGChatViewController *me = weakSelf;
		if (!me)
			return;
		if (!ids.count){
			[TGAlertSheet showMessage:@"An error occurred."
								title:@"Shared Media" inView:me.view];
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSNumber *position in ids)
			[rows addObject:[NSString stringWithFormat:@"Message %lld",
					(long long)[position longLongValue]]];
		[TGPresent showList:rows title:[NSString stringWithFormat:@"%lu positions",
									(unsigned long)rows.count] destructiveIndex:-1
			from:self onPick:^(NSInteger index){
			int64_t target = [ids[index] longLongValue];
			[me showMessageId:target gone:nil];
		}];
	}];
}
/// Their six, in their order. One reaction at a time is all this screen
/// offers; picking a second replaces the first on Telegram's side.
- (void)askReactionForMessage:(int64_t)messageId {
	NSArray *fallback = @[@"\U0001F44D", @"\U0001F44E", @"\U00002764",
						  @"\U0001F525", @"\U0001F389", @"\U0001F62D"];
	__weak typeof(self) weakSelf = self;
	// The chat sets what may be reacted with, and getMessageAvailableReactions
	// says which of those this message itself offers; the fixed six are only
	// what answers a chat that allows everything.
	[[TGMessageStore shared] availableReactionsForMessage:messageId
											 inChat:self.chatId
										 completion:^(NSArray *offered){
		TGChatViewController *me = weakSelf;
		if (!me)
			return;
		NSArray *emoji = [me reactionsWithDefaultFirst:
				(offered.count ? offered : fallback)];
		[TGAlertSheet showChoices:emoji
							title:@"Reactions"
				 destructiveIndex:-1
						   inView:me.view
						 onChoice:^(NSInteger index){
			[[TGMessageStore shared] reactTo:messageId inChat:me.chatId emoji:emoji[index]];
			[me reload];
		}];
	}];
}


@end
