#import "TGChatViewControllerInternal.h"
#import "TGForwardPicker.h"
#import "TGPopupMenu.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGReactionPicker.h"
#import "TGDateFormat.h"
#import "TGOptions.h"
#import "TGClientInternal.h"
#import "TGInstantViewController.h"
#import "TGMessageAudienceViewController.h"
#import "TGMessageToolsViewController.h"
#import "TGSponsoredMessagesViewController.h"
#import "TGGameScoresViewController.h"
#import "TGPollPresentation.h"
#import <CoreImage/CoreImage.h>
#import <QuartzCore/QuartzCore.h>


/// The room left above a lifted bubble for its reaction bar: the capsule plus
/// the gap that separates it from the bubble's top edge.
static const CGFloat kHoldReactionRoom = TGMetricRow;
/// The gap between the lifted bubble and the action card hanging under it.
static const CGFloat kHoldLiftGap = TGMetricPadSmall;
/// The lift never takes more than this share of the screen: the card below it
/// has to stay the bigger half of the presentation.
static const CGFloat kHoldLiftMaxPart = 0.40f;
/// The room the card is guaranteed before the lift is scaled down for it; a
/// card taller than this scrolls inside itself (see TGPopupMenu).
static const CGFloat kHoldMenuRoomMin = 4.0f * TGMetricRow;
/// The backdrop is captured at 1x and stretched. It is about to be blurred
/// and dimmed, so a 320-point-wide capture is indistinguishable from a 640
/// one and costs the A4 a quarter of the pixels and time.
static const CGFloat kHoldBackdropScale = 1.0f;
/// Small on purpose: enough to lose the text under it, not enough to make the
/// chat's shapes unreadable behind the lifted bubble.
static const CGFloat kHoldBlurRadius = 10.0f;

/// A view's current pixels. renderInContext is the only path this OS offers;
/// snapshotViewAfterScreenUpdates is iOS 7 and later.
static UIImage *TGHoldSnapshotOfView(UIView *view, CGFloat scale) {
	if (!view || CGRectIsEmpty(view.bounds))
		return nil;
	UIGraphicsBeginImageContextWithOptions(view.bounds.size, NO, scale);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	if (!ctx) {
		UIGraphicsEndImageContext();
		return nil;
	}
	[view.layer renderInContext:ctx];
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

/// The bubble alone, clipped to its own rounded shape. Rendering the whole
/// cell would lift the sender's name and avatar as well; rendering the row
/// would lift the empty space around the bubble.
static UIImage *TGHoldSnapshotOfBubble(UIView *bubble) {
	if (!bubble || CGRectIsEmpty(bubble.bounds))
		return nil;
	UIGraphicsBeginImageContextWithOptions(bubble.bounds.size, NO, 0.0f);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	if (!ctx) {
		UIGraphicsEndImageContext();
		return nil;
	}
	CGFloat radius = bubble.layer.cornerRadius;
	UIBezierPath *clip = radius > TGMetricCornerNone
			? [UIBezierPath bezierPathWithRoundedRect:bubble.bounds cornerRadius:radius]
			: [UIBezierPath bezierPathWithRect:bubble.bounds];
	[clip addClip];
	[bubble.layer renderInContext:ctx];
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

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


@implementation TGChatViewController (TGChatActionsHoldMenu)

#pragma mark - hold presentation

/// Why the bubble is snapshotted rather than moved: the table owns the cell
/// and will reuse it, while the lift has to outlive a scroll, a reload and a
/// reaction. The cell stays where it is; what leaves the list is its picture.
///
/// The backdrop is one capture of this screen with the bubble left out, one
/// downscaled Gaussian blur on a background queue, and a dim over both. On
/// the A4 CoreImage is slower than the lift animation, so the sharp capture
/// is shown at once and the blurred one replaces it when it arrives. If the
/// blur never does, the sharp capture plus the 45% dim is the fallback.
- (CGRect)beginHoldPresentationForCell:(TGBubbleCell *)cell
                              didLift:(void (^)(CGRect anchor))didLift {
	// A second hold while one is still fading replaces it at once: the old
	// lift and dim must not end up in this lift's backdrop capture.
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

	// The picture before the bubble is hidden: what is lifted is the image
	// the finger was on, not a redraw of it.
	UIImage *bubbleImage = TGHoldSnapshotOfBubble(cell.bubble);
	if (!bubbleImage)
		return CGRectZero;

	// Capture the chat without the bubble so the backdrop has no blurred
	// twin in the list. The alpha goes straight back: a reload during the
	// hold must never find a cell whose bubble is still invisible.
	CGFloat bubbleAlpha = cell.bubble.alpha;
	CGFloat tailAlpha = cell.tail.alpha;
	cell.bubble.alpha = TGAlphaTransparent;
	cell.tail.alpha = TGAlphaTransparent;
	UIImage *screenshot = TGHoldSnapshotOfView(self.view, kHoldBackdropScale);
	cell.bubble.alpha = bubbleAlpha;
	cell.tail.alpha = tailAlpha;

	TGTheme *theme = [TGTheme shared];

	UIView *backdrop = [[UIView alloc] initWithFrame:self.view.bounds];
	backdrop.backgroundColor = [theme holdDimColour];
	backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth |
								UIViewAutoresizingFlexibleHeight;
	backdrop.alpha = TGAlphaTransparent;

	// The sharp capture is the fallback and the first thing shown; the blur
	// swaps it in place under the same dim. With no capture at all, the
	// view's own holdDimColour is already the required 45% black.
	UIImageView *backdropImage = [[UIImageView alloc] initWithFrame:backdrop.bounds];
	backdropImage.contentMode = UIViewContentModeScaleToFill;
	backdropImage.autoresizingMask = UIViewAutoresizingFlexibleWidth |
									 UIViewAutoresizingFlexibleHeight;
	backdropImage.image = screenshot;
	[backdrop addSubview:backdropImage];

	UIView *dim = [[UIView alloc] initWithFrame:backdrop.bounds];
	dim.backgroundColor = [theme holdDimColour];
	dim.autoresizingMask = UIViewAutoresizingFlexibleWidth |
						   UIViewAutoresizingFlexibleHeight;
	[backdrop addSubview:dim];
	[self.view addSubview:backdrop];

	UIImageView *lift = [[UIImageView alloc] initWithImage:bubbleImage];
	lift.frame = origin;
	lift.contentMode = UIViewContentModeScaleToFill;
	lift.userInteractionEnabled = NO;
	// A filled bubble earns the floating shadow. A sticker or a round note
	// is a clear box whose picture carries its own shape; it lifts by the
	// dim alone rather than pretending to be a card.
	UIColor *fill = cell.bubble.backgroundColor;
	if (fill && CGColorGetAlpha(fill.CGColor) > TGAlphaEpsilon){
		lift.layer.shadowColor = [UIColor blackColor].CGColor;
		lift.layer.shadowOpacity = TGMetricShadowMenuOpacity;
		lift.layer.shadowRadius = TGMetricShadowMenuRadius;
		lift.layer.shadowOffset = TGMetricShadowOffsetMenu;
	}
	[self.view addSubview:lift];

	self.holdBackdropView = backdrop;
	self.holdBackdropImageView = backdropImage;
	self.holdLiftView = lift;
	self.holdLiftOriginRect = origin;

	// The list stops scrolling while it is held: the row underneath is the
	// place this message goes back to, and a scroll would take it away from
	// the picture that has to return to it.
	self.holdTableWasScrollable = self.table.scrollEnabled;
	self.table.scrollEnabled = NO;

	NSInteger generation = ++self.holdGeneration;

	__weak typeof(self) weakSelf = self;
	if (screenshot){
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
			UIImage *blurred = [TGTheme softenedImage:screenshot radius:kHoldBlurRadius dim:0];
			if (!blurred)
				return;
			dispatch_async(dispatch_get_main_queue(), ^{
				TGChatViewController *me = weakSelf;
				if (!me || me.holdGeneration != generation ||
						me.holdBackdropImageView != backdropImage)
					return;
				backdropImage.image = blurred;
			});
		});
	}

	// Land clear of the navigation bar (this screen does not extend under
	// it), below the pinned strip when there is one, with the reaction bar's
	// room reserved above the bubble and the action card's below it. A tall
	// bubble or a picture is scaled down rather than allowed to run into the
	// menu; the width shrinks with the height so it never stretches.
	CGRect host = self.view.bounds;
	CGFloat top = TGMetricPad + kHoldReactionRoom;
	if (self.pinnedBannerView && !self.pinnedBannerView.hidden)
		top = MAX(top, CGRectGetMaxY(self.pinnedBannerView.frame) + kHoldReactionRoom);
	CGFloat menuRoom = CGRectGetHeight(host) - top - kHoldLiftGap - kHoldMenuRoomMin - TGMetricPad;
	CGFloat maxHeight = MIN(CGRectGetHeight(host) * kHoldLiftMaxPart, menuRoom);
	maxHeight = MAX(maxHeight, TGMetricRow);
	CGFloat scale = MIN(1.0f, maxHeight / CGRectGetHeight(origin));
	scale = MIN(scale, (CGRectGetWidth(host) - TGDoubled(TGMetricPad)) / CGRectGetWidth(origin));
	CGSize targetSize = CGSizeMake(CGRectGetWidth(origin) * scale,
								   CGRectGetHeight(origin) * scale);
	CGFloat x = MIN(MAX(TGMetricPad, CGRectGetMinX(origin)),
					CGRectGetWidth(host) - TGMetricPad - targetSize.width);
	CGRect target = CGRectMake(x, top, targetSize.width, targetSize.height);

	[UIView animateWithDuration:TGAnimationDurationMedium
						  delay:0
						options:UIViewAnimationOptionCurveEaseOut
					 animations:^{
		backdrop.alpha = TGAlphaOpaque;
		lift.frame = target;
	} completion:^(BOOL finished){
		TGChatViewController *me = weakSelf;
		if (!me || me.holdGeneration != generation || me.holdLiftView != lift)
			return;
		if (didLift)
			didLift(target);
	}];

	return target;
}

- (void)discardHoldPresentation {
	// Invalidate the blur and any animation completion still pointing at
	// these views before they leave the hierarchy.
	++self.holdGeneration;
	self.holdReturning = NO;
	[self.holdBackdropView removeFromSuperview];
	[self.holdLiftView removeFromSuperview];
	self.holdBackdropView = nil;
	self.holdBackdropImageView = nil;
	self.holdLiftView = nil;
}

- (void)endHoldPresentation {
	if (!self.holdBackdropView && !self.holdLiftView)
		return;
	// The menu can be dismissed twice on the way out - once by the row or
	// the tap, once by the screen closing. One return animation is enough.
	if (self.holdReturning)
		return;

	// Anything still in flight - the blur, the lift's completion - now
	// belongs to a presentation that is over.
	NSInteger generation = ++self.holdGeneration;
	self.holdReturning = YES;

	self.table.scrollEnabled = self.holdTableWasScrollable;

	UIView *backdrop = self.holdBackdropView;
	UIImageView *lift = self.holdLiftView;
	CGRect origin = self.holdLiftOriginRect;

	if (!lift){
		[self discardHoldPresentation];
		return;
	}

	// The picture goes back to the row it came from before it is removed:
	// removing it where it stands would read as a jump, not as putting the
	// message back. The fields stay pointed at these views until the
	// animation lands, so a new hold in the meantime can discard them
	// instead of capturing them into its own backdrop.
	[UIView animateWithDuration:TGAnimationDurationNormal
						  delay:0
						options:UIViewAnimationOptionCurveEaseIn
					 animations:^{
		lift.frame = origin;
		backdrop.alpha = TGAlphaTransparent;
	} completion:^(BOOL finished){
		[lift removeFromSuperview];
		[backdrop removeFromSuperview];
		if (generation != self.holdGeneration)
			return;
		self.holdBackdropView = nil;
		self.holdBackdropImageView = nil;
		self.holdLiftView = nil;
		self.holdReturning = NO;
	}];
}

/// What a hold offers on every message: the verbs people came for. Anything
/// administrative or rare lives in the More submenu below, so the card is
/// short enough to read at a glance and keeps the reaction bar on top.
- (NSArray *)commonActionItemsForMessage:(NSDictionary *)m
									mine:(BOOL)mine
								  heldId:(int64_t)heldId {
	NSMutableArray *items = [NSMutableArray array];
	NSString *text = [m[@"text"] isKindOfClass:NSString.class] ? m[@"text"] : @"";

	// A message that failed has one thing worth doing to it, and it goes first.
	if ([m[@"failed"] boolValue])
		[items addObject:@{@"title" : @"Retry", @"icon" : @"reply"}];

	[items addObject:@{@"title" : @"Reply", @"icon" : @"reply"}];

	// A protected chat or a one-time picture lets nothing out of the chat.
	BOOL saveable = ![m[@"canBeSaved"] isEqual:@NO];
	if (text.length && saveable)
		[items addObject:@{@"title" : @"Copy", @"icon" : @"copy"}];

	// A caption is edited by its own request, which is why only text could be
	// edited before: media with a caption got no Edit row at all.
	if (mine && (text.length || [m[@"photoId"] isKindOfClass:NSNumber.class]))
		[items addObject:@{@"title" : @"Edit", @"icon" : @"edit"}];

	if (![m[@"service"] boolValue])
		[items addObject:@{@"title" : (heldId == self.pinnedMessageId ? @"Unpin" : @"Pin"),
						   @"icon" : @"pin"}];

	[items addObject:@{@"title" : @"Copy Link", @"icon" : @"copy"}];
	if (saveable)
		[items addObject:@{@"title" : @"Forward", @"icon" : @"forward"}];
#if TG_DEV
	// One row for the Tier 2 message tools: checklists, suggested posts,
	// fact checks and the AI/rich requests that read this one message.
	[items addObject:@{@"title" : @"Message Tools", @"icon" : @"data"}];
#endif

	// A channel post with a discussion group: the row that was only the bar
	// under the bubble is also one tap from the hold, where Telegram puts it.
	if ([m[@"canComment"] boolValue]){
		NSInteger count = [m[@"replyCount"] integerValue];
		NSString *title = count <= 0 ? @"Leave a Comment"
				: count == 1 ? @"Show 1 Reply"
				: [NSString stringWithFormat:@"Show %ld Replies", (long)count];
		[items addObject:@{@"title" : title, @"icon" : @"reply"}];
	}

	// Who saw this post. On a channel or group this is the number Telegram
	// prints; a chat without one still offers the read date behind the same
	// row name, which is what the sheet says when viewers are refused.
	NSInteger views = [m[@"viewCount"] integerValue];
	if (mine && (views > 0 || self.isGroup)){
		NSString *title = views > 0
				? [NSString stringWithFormat:@"Viewed by %ld", (long)views]
				: @"Who Read This";
		[items addObject:@{@"title" : title, @"icon" : @"select"}];
	}

	// Closing a poll is the sender's to do, and only while it is still open.
	if (mine && [m[@"pollOptions"] count] && ![m[@"pollClosed"] boolValue])
		[items addObject:@{@"title" : @"Stop Poll", @"icon" : @"select"}];
	// A poll that lets the voter change their mind: retracting sends the empty
	// answer set, which TDLib reads as "no answers".
	if (TGPollCanRetract([m[@"poll"] isKindOfClass:NSDictionary.class] ? m[@"poll"] : nil))
		[items addObject:@{@"title" : @"Retract Vote", @"icon" : @"select"}];
	// A poll's crowd and its options: voters answered, an option made after
	// the fact, an option taken out of it.
	if ([m[@"pollOptions"] count]){
		if ([m[@"pollClosed"] boolValue] || [m[@"pollVoters"] boolValue])
			[items addObject:@{@"title" : @"Poll Voters", @"icon" : @"select"}];
		if ([m[@"pollStats"] boolValue])
			[items addObject:@{@"title" : @"Poll Statistics", @"icon" : @"data"}];
		if (mine && [m[@"pollOpen"] boolValue])
			[items addObject:@{@"title" : @"Add Option", @"icon" : @"edit"}];
		if (mine && [m[@"pollOpen"] boolValue] && [m[@"pollDeletable"] boolValue])
			[items addObject:@{@"title" : @"Delete Option", @"icon" : @"delete",
							   @"destructive" : @YES}];
	}

	if (mine)
		[items addObject:@{@"title" : @"Delete", @"icon" : @"delete",
						   @"destructive" : @YES}];

	[items addObject:@{@"title" : @"More", @"icon" : @"more"}];
	[items addObject:@{@"title" : @"Select", @"icon" : @"select"}];
	return items;
}

/// The second card: the record of the message, the moderator rows and the
/// verbs that are useful once a year. This is where a debug list used to be
/// on the first card; the split is the point of the change.
- (NSArray *)moreActionItemsForMessage:(NSDictionary *)m mine:(BOOL)mine {
	NSMutableArray *items = [NSMutableArray array];
	NSString *text = [m[@"text"] isKindOfClass:NSString.class] ? m[@"text"] : @"";

	if (text.length){
		[items addObject:@{@"title" : @"Translate", @"icon" : @"edit"}];
		[items addObject:@{@"title" : @"Find Quote", @"icon" : @"data"}];
	}
	if ([text rangeOfString:@"#"].location != NSNotFound)
		[items addObject:@{@"title" : @"Search by Hashtag", @"icon" : @"data"}];

	if (mine && [m[@"photoId"] isKindOfClass:NSNumber.class])
		[items addObject:@{@"title" : @"Replace Photo", @"icon" : @"react"}];

	[items addObject:@{@"title" : @"Message Info", @"icon" : @"data"}];
#if TG_DEV
	[items addObject:@{@"title" : @"Shared Media Map", @"icon" : @"data"}];
#endif
#if TG_DEV
	// The message's own effect, or the server's list when this message has
	// none: either way the sheet can name an effect and fetch it live.
	if ([m[@"effectId"] longLongValue] > 0 ||
			[TGClient shared].availableMessageEffectIds.count ||
			[TGClient shared].availableStickerEffectIds.count)
		[items addObject:@{@"title" : @"Message Effects", @"icon" : @"react"}];
#endif

	// A dice or a ball is a message whose whole point is the tap.
#if TG_DEV
	if ([m[@"kind"] isEqualToString:@"messageAnimatedEmoji"])
		[items addObject:@{@"title" : @"Click Emoji", @"icon" : @"react"}];
#endif
	// A bot's buttons are the message's furniture; a bot account can take
	// them off, and the row is where that interaction already lives.
	if ([m[@"inlineRows"] count])
		[items addObject:@{@"title" : @"Clear Buttons", @"icon" : @"delete",
						   @"destructive" : @YES}];
	// A sticker you are holding is a sticker you may want to keep.
	if ([m[@"kind"] isEqualToString:@"messageSticker"] && TGStickerFileId(m) > 0)
		[items addObject:@{@"title" : @"Add to Favourites", @"icon" : @"pin"}];

	// The record of a post that left this account: who opened it, who
	// reacted, whether Telegram names the hand behind "Channel Admin".
	if (mine && !self.isGroup && ![[TGClient shared] chatIsSavedMessages:self.chatId])
		[items addObject:@{@"title" : @"Who Read This", @"icon" : @"select"}];
	[items addObject:@{@"title" : @"Public Forwards", @"icon" : @"forward"}];
	if ([m[@"reactionGroups"] count])
		[items addObject:@{@"title" : @"Reactions", @"icon" : @"react"}];
	if (!mine)
		[items addObject:@{@"title" : @"Author", @"icon" : @"select"}];

	if ([m[@"kind"] isEqualToString:@"messageLocation"] ||
			[m[@"kind"] isEqualToString:@"messageLiveLocation"]){
		[items addObject:@{@"title" : @"Recent Locations", @"icon" : @"data"}];
#if TG_DEV
		[items addObject:@{@"title" : @"Weather Here", @"icon" : @"data"}];
#endif
	}

	// Speech recognition is Telegram's, not the device's. A voice or video
	// note is the only content the request accepts.
	if ([m[@"kind"] isEqualToString:@"messageVoiceNote"] ||
			[m[@"kind"] isEqualToString:@"messageVideoNote"]){
		[items addObject:@{@"title" : @"Transcribe", @"icon" : @"data"}];
#if TG_DEV
		[items addObject:@{@"title" : @"Rate Transcription", @"icon" : @"react"}];
#endif
	}

#if TG_DEV
	// A video message can carry advertisements around its playback.
	if ([m[@"kind"] isEqualToString:@"messageVideo"])
		[items addObject:@{@"title" : @"Video Advertisements", @"icon" : @"data"}];
#endif

	// A game message's score table belongs to the bot serving the game. The
	// row is here because this is the message's own More menu, which is the
	// place Telegram puts the table.
	if ([m[@"kind"] isEqualToString:@"messageGame"])
		[items addObject:@{@"title" : @"Game Scores", @"icon" : @"star"}];

	// A live pin of your own stays on the map until you take it off.
	if (mine && [m[@"kind"] isEqualToString:@"messageLiveLocation"]
			 && [m[@"liveEditable"] boolValue])
		[items addObject:@{@"title" : @"Stop Live Location", @"icon" : @"delete",
						   @"destructive" : @YES}];

	// Someone else's message in a group is the only place a spam report has
	// anywhere to go: reportSupergroupSpam wants a supergroup behind it.
	if (!mine && self.isGroup)
		[items addObject:@{@"title" : @"Report Spam", @"icon" : @"privacy",
						   @"destructive" : @YES}];
	// A reaction the flattening could name - the person, not only the
	// emoji - is one confirm away from the report TDLib asks for.
	NSDictionary *reactionReport = m[@"reactionReport"];
	if (reactionReport && ![reactionReport isKindOfClass:NSNull.class] && !mine)
		[items addObject:@{@"title" : @"Report Reaction", @"icon" : @"privacy",
						   @"destructive" : @YES}];
	return items;
}

- (void)showMoreActions {
	NSDictionary *m = self.actionMessage;
	if (!m)
		return;
	NSArray *items = [self moreActionItemsForMessage:m
											   mine:[m[@"outgoing"] boolValue]];
	if (!items.count)
		return;
	CGPoint where = self.actionMenuPoint;
	__weak typeof(self) weakSelf = self;
	[TGPopupMenu showItems:items
				   atPoint:where
					inView:self.view
				headerView:nil
				  onChoice:^(NSInteger index, NSString *title) {
		[weakSelf runMessageAction:title];
	}];
}

- (void)runMessageAction:(NSString *)action {
	NSDictionary *m = self.actionMessage;
	int64_t messageId = [m[@"id"] longLongValue];
	if (!messageId)
		return;

	if ([action isEqualToString:@"Reply"]){
		// A chat can forbid replies to this particular message; can_be_replied
		// is the server's word on it, and opening a composer that would be
		// refused is worse than one line saying so.
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] messagePropertiesForChat:self.chatId
										  messageId:messageId
										 completion:^(NSDictionary *properties){
			TGChatViewController *me = weakSelf;
			if (!me)
				return;
			id allowed = properties[@"can_be_replied"];
			if (allowed && ![allowed boolValue]){
				[TGAlertSheet showMessage:@"Telegram does not allow a reply "
							@"to this message." title:@"Reply" inView:me.view];
				return;
			}
			me.replyToId = messageId;
			me.editingId = 0;
			NSString *who = [m[@"outgoing"] boolValue] ? @"You"
					: ([[TGClient shared] nameForUserId:
							[m[@"senderId"] longLongValue]] ?: @"Reply");
			[me showComposeBanner:who subtitle:TGComposePreview(m)];
			[me.input becomeFirstResponder];
		}];

	} else if ([action isEqualToString:@"Forward"]){
		TGForwardPicker *picker = [[TGForwardPicker alloc] init];
		__weak typeof(self) weakSelf = self;
		picker.onPicked = ^(int64_t targetChatId){
			[[TGClient shared] forwardMessages:@[@(messageId)]
									  fromChat:weakSelf.chatId
										toChat:targetChatId];
		};
		[self.navigationController pushViewController:picker animated:YES];

	} else if ([action isEqualToString:@"Select"]){
		[self enterEditMode];
		[self toggleMessageSelection:messageId];

	} else if ([action isEqualToString:@"Retry"]){
		[[TGClient shared] resendMessages:@[@(messageId)] inChat:self.chatId];

	} else if ([action isEqualToString:@"More"]){
		// The second card is built from actionMessage and its rows run
		// through this same method later, so the message has to outlive
		// this call. Clearing it at the bottom of the method would leave
		// every row of the More card with nothing to act on.
		[self showMoreActions];
		return;

#if TG_DEV
	} else if ([action isEqualToString:@"Message Tools"]){
		TGMessageToolsViewController *tools = [[TGMessageToolsViewController alloc] init];
		tools.chatId = self.chatId;
		tools.chatTitle = self.chatTitle;
		tools.messageId = messageId;
		tools.messageText = [m[@"text"] isKindOfClass:NSString.class]
				? m[@"text"] : @"";
		tools.isChecklist = [m[@"kind"] isEqualToString:@"messageChecklist"];
		tools.hasSuggestedPost = [m[@"hasSuggestedPost"] boolValue];
		tools.factCheck = [m[@"factCheck"] isKindOfClass:NSString.class]
				? m[@"factCheck"] : @"";
		tools.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:tools animated:YES];

#endif
	} else if ([action isEqualToString:@"Show 1 Reply"] ||
			   [action hasPrefix:@"Show "] ||
			   [action isEqualToString:@"Leave a Comment"]){
		[self openCommentsForMessage:m];

	} else if ([action hasPrefix:@"Remove "]){
		[[TGClient shared] removeReaction:m[@"myReaction"]
							  fromMessage:messageId
								   inChat:self.chatId];
		[self.layoutCache removeLayoutForMessageId:messageId];
		[self reload];

	} else if ([action hasPrefix:@"React"]){
		[self askReactionForMessage:messageId];

	} else if ([action isEqualToString:@"Pin"]){
		[[TGClient shared] pinMessage:messageId inChat:self.chatId notify:NO];
		[self performSelector:@selector(loadPinnedMessage) withObject:nil afterDelay:0.6];

	} else if ([action isEqualToString:@"Unpin"]){
		[[TGClient shared] unpinMessage:messageId inChat:self.chatId];
		self.pinnedMessageId = 0;
		[self hidePinnedBanner];

	} else if ([action isEqualToString:@"Stop Poll"]){
		__weak typeof(self) weakSelf = self;
		[TGAlertSheet showConfirm:@"Nobody can vote after this, and the result "
								  @"stands as it is."
							title:@"Stop Poll"
						   action:@"Stop"
					  destructive:YES
						   inView:self.view
						onConfirm:^{
			[[TGClient shared] stopPoll:messageId inChat:weakSelf.chatId];
		}];

	} else if ([action isEqualToString:@"Retract Vote"]){
		// The empty answer set is how TDLib takes a vote back; the updated
		// message follows, and the row re-reads a second later.
		[[TGClient shared] votePoll:messageId inChat:self.chatId options:@[]];
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
		[TGAlertSheet showConfirm:@"Your location stops updating for everyone, "
								  @"right now."
							title:@"Stop Live Location"
						   action:@"Stop"
					  destructive:YES
						   inView:self.view
						onConfirm:^{
			[[TGClient shared] editLiveLocationOfMessage:messageId
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
	} else if ([action isEqualToString:@"Poll Voters"]){
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
			[TGAlertSheet showMessage:@"This poll has no answers to look "
									  @"behind." title:@"Poll Voters"
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
			[[TGClient shared] pollVotersOfOption:index ofMessage:messageId inChat:chatId
									   completion:^(NSArray *voters, BOOL end){
				TGChatViewController *me = weakSelf;
				if (!me)
					return;
				if (!voters.count){
					[TGAlertSheet showMessage:@"Nobody voted for that."
										title:@"Poll Voters" inView:me.view];
					return;
				}
				NSMutableArray *rows = [NSMutableArray array];
				for (NSDictionary *voter in voters)
					[rows addObject:voter[@"name"] ?: @"?"];
				NSString *head = [NSString stringWithFormat:@"%@ · %lu%@",
						titles[index], (unsigned long)voters.count,
						end ? @"" : @"…"];
				[TGAlertSheet showChoices:rows
									title:head
						 destructiveIndex:-1
								   inView:me.view
								 onChoice:^(NSInteger pick){}];
			}];
		}];

	} else if ([action isEqualToString:@"Poll Statistics"]){
		// The graph of votes gathered in as the poll ran. TDLib hands the
		// chart over as a JSON string; whatever it holds, the sheet reads
		// every column it recognises into a line per option, worst case a
		// sentence instead of a chart.
		int64_t pollChatId = self.chatId;
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] pollVoteStatisticsOfMessage:messageId
												inChat:pollChatId
											completion:^(NSDictionary *graph){
			TGChatViewController *me = weakSelf;
			if (!me)
				return;
			if (!graph){
				[TGAlertSheet showMessage:@"Statistics are not there yet."
									title:@"Poll Statistics"
								   inView:me.view];
				return;
			}
					NSString *lines = TGPollGraphLines(graph[@"json"],
					m[@"pollOptions"]);
			NSString *body = [lines isKindOfClass:NSString.class] && lines.length
					? lines
					: @"Statistics came back as numbers this page cannot "
					@"read. The options' own share still shows in the poll.";
			[TGAlertSheet showMessage:body
								title:m[@"pollQuestion"] ?: @"Poll Statistics"
								   inView:me.view];
		}];

	} else if ([action isEqualToString:@"Add Option"]){
		// A poll that grew after the fact: the line asked for, sent, and the
		// message re-answered by the update the client does not watch for.
		int64_t chatId = self.chatId;
		__weak typeof(self) weakSelf = self;
		[TGAlertSheet showInput:@"Add Option"
						message:nil
					placeholder:@"New answer"
						   text:nil
						 action:@"Add"
						 inView:self.view
					   onSubmit:^(NSString *text){
			NSString *what = [text stringByTrimmingCharactersInSet:
					[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			[[TGClient shared] addPollOption:what toMessage:messageId inChat:chatId
								  completion:^(BOOL ok){
				TGChatViewController *me = weakSelf;
				if (!ok)
					[TGAlertSheet showMessage:@"Telegram refused the new answer - "
											  @"this poll does not grow."
										title:@"Add Option" inView:me.view];
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
			[TGAlertSheet showConfirm:[NSString stringWithFormat:
					@"The answer \"%@\" is removed from the poll, along "
					@"with what it collected so far.", which]
								title:@"Delete Option"
							   action:@"Delete"
						  destructive:YES
							   inView:weakSelf.view
							onConfirm:^{
				[[TGClient shared] deletePollOption:optionId
										  ofMessage:messageId
											 inChat:chatId
										 completion:^(BOOL ok){
					TGChatViewController *me = weakSelf;
					if (!ok)
						[TGAlertSheet showMessage:@"Telegram refused to remove "
												  @"that answer."
											title:@"Delete Option" inView:me.view];
				}];
			}];
		}];

	} else if ([action isEqualToString:@"Report Spam"]){
		int64_t chatId = self.chatId;
		__weak typeof(self) weakSelf = self;
		[TGAlertSheet showChoices:@[@"Report", @"Report and Block Sender"]
							title:@"Report Spam"
						  message:@"Telegram's moderators see the message. "
								  @"Blocking also stops them replying to you "
								  @"again."
				 destructiveIndex:1
						   inView:self.view
						 onChoice:^(NSInteger index){
			TGChatViewController *me = weakSelf;
			if (index == 1)
				[[TGClient shared] blockSenderOfMessage:messageId
										 deleteMessages:YES
											 reportSpam:YES];
			[[TGClient shared] reportSpamMessages:@[@(messageId)]
										   inChat:chatId
									   completion:^(BOOL ok){
				[TGSnackbar showInView:me.view
								  text:(ok ? @"Reported" : @"Telegram refused that")
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
		NSString *who = nil;
		if ([choice[@"name"] isKindOfClass:NSString.class]){
			NSString *name = choice[@"name"];
			who = name.length ? name : @"someone";
		} else {
			who = @"someone";
		}
		__weak typeof(self) weakSelf = self;
		NSString *note = [NSString stringWithFormat:
				@"The %@ reaction by %@ is reported. Telegram's moderators "
				@"see the message and the reaction.",
				choice[@"emoji"] ?: @"", who];
		[TGAlertSheet showConfirm:note
							title:@"Report Reaction"
						   action:@"Report"
					  destructive:YES
						   inView:self.view
						onConfirm:^{
			[[TGClient shared] reportReactionBySender:choice[@"sender"]
											ofMessage:messageId
												inChat:reactionChatId
										 completion:^(BOOL ok){
				TGChatViewController *me = weakSelf;
				if (!me)
					return;
				[TGSnackbar showInView:me.view
								  text:(ok ? @"Reaction reported"
										   : @"Telegram refused that")
							   seconds:2 onCommit:nil];
			}];
		}];

	} else if ([action isEqualToString:@"Click Emoji"]){
		int64_t chatId = self.chatId;
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] clickAnimatedEmojiMessage:messageId inChat:chatId
										 completion:^(NSString *emoji){
			TGChatViewController *me = weakSelf;
			if (!me)
				return;
			[TGSnackbar showInView:me.view
							  text:(emoji.length
									? [NSString stringWithFormat:@"%@ rolled", emoji]
									: @"No animation this time")
						   seconds:2 onCommit:nil];
		}];

	} else if ([action isEqualToString:@"Message Info"]){
		[self showInfoOfActionMessage];

	} else if ([action isEqualToString:@"Shared Media Map"]){
		[self showSparsePositionsOfActionMessage];

	} else if ([action isEqualToString:@"Clear Buttons"]){
		int64_t chatId = self.chatId;
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] clearReplyMarkupOfMessage:messageId inChat:chatId
										 completion:^(BOOL ok){
			TGChatViewController *me = weakSelf;
			if (!me)
				return;
			[TGSnackbar showInView:me.view
							  text:(ok ? @"Buttons removed"
									   : @"Telegram refused that")
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
		for (NSNumber *effectId in [TGClient shared].availableMessageEffectIds){
			if ([seen containsObject:effectId])
				continue;
			[seen addObject:effectId];
			[effectIds addObject:effectId];
			[titles addObject:[NSString stringWithFormat:@"Reaction effect %lld",
					(long long)[effectId longLongValue]]];
		}
		for (NSNumber *effectId in [TGClient shared].availableStickerEffectIds){
			if ([seen containsObject:effectId])
				continue;
			[seen addObject:effectId];
			[effectIds addObject:effectId];
			[titles addObject:[NSString stringWithFormat:@"Sticker effect %lld",
					(long long)[effectId longLongValue]]];
		}
		if (!effectIds.count){
			[TGAlertSheet showMessage:@"Telegram has not sent its message effects yet."
								title:@"Message Effects" inView:self.view];
		} else {
			__weak typeof(self) weakSelf = self;
			[TGAlertSheet showChoices:titles
								title:@"Message Effects"
							  message:@"The effects Telegram offers; the record names its emoji and whether it needs Premium."
					 destructiveIndex:-1
							   inView:self.view
							 onChoice:^(NSInteger index){
				if (index < 0 || (NSUInteger)index >= effectIds.count)
					return;
				int64_t effectId = [effectIds[(NSUInteger)index] longLongValue];
				[[TGClient shared] messageEffectWithId:effectId
											completion:^(NSDictionary *effect){
					TGChatViewController *me = weakSelf;
					if (!me)
						return;
					if (!effect){
						[TGAlertSheet showMessage:@"Telegram has no effect with that id."
											title:@"Message Effect" inView:me.view];
						return;
					}
					NSString *premium = [effect[@"is_premium"] boolValue] ? @"yes" : @"no";
					id effectType = effect[@"type"];
					NSString *kind = [effectType isKindOfClass:NSDictionary.class]
							? effectType[@"@type"] : nil;
					if (![kind isKindOfClass:NSString.class] || !kind.length)
						kind = @"unknown";
					[TGAlertSheet showMessage:[NSString stringWithFormat:
							@"Emoji: %@\nPremium: %@\nKind: %@",
							effect[@"emoji"] ?: @"none", premium, kind]
										title:@"Message Effect" inView:me.view];
				}];
			}];
		}

	} else if ([action isEqualToString:@"Copy Link"]){
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] linkToMessage:messageId inChat:self.chatId
							  completion:^(NSString *link){
			TGChatViewController *me = weakSelf;
			if (!link.length){
				[TGSnackbar showInView:me.view text:@"This chat has no public link"
							   seconds:2 onCommit:nil];
				return;
			}
			[UIPasteboard generalPasteboard].string = link;
			[TGSnackbar showInView:me.view text:@"Link copied" seconds:2 onCommit:nil];
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

	} else if ([action isEqualToString:@"Translate"]){
		[self translateActionMessage];

	} else if ([action isEqualToString:@"Find Quote"]){
		[self findQuoteInActionMessage];

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

	} else if ([action isEqualToString:@"Weather Here"]){
		NSNumber *latitude = m[@"latitude"];
		NSNumber *longitude = m[@"longitude"];
		if (![latitude isKindOfClass:NSNumber.class] ||
				![longitude isKindOfClass:NSNumber.class]){
			[TGAlertSheet showMessage:@"This message has no point to ask about."
								title:@"Weather Here" inView:self.view];
			return;
		}
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] currentWeatherAtLatitude:latitude.doubleValue
										  longitude:longitude.doubleValue
										 completion:^(NSDictionary *weather, NSString *error){
			TGChatViewController *me = weakSelf;
			if (!me) return;
			NSString *text = error.length ? error
					: [NSString stringWithFormat:@"%@  %.1f°",
					   weather[@"emoji"] ?: @"", [weather[@"temperature"] doubleValue]];
			[TGAlertSheet showMessage:text title:@"Weather Here" inView:me.view];
		}];

	} else if ([action isEqualToString:@"Transcribe"]){
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] recognizeSpeechInChat:self.chatId message:messageId
									  completion:^(BOOL ok, NSString *error){
			if (ok) return;   // the bubble says "Transcribing..." until the text lands
			TGChatViewController *me = weakSelf;
			if (!me) return;
			NSString *text = error.length ? error
					: @"Could not transcribe this voice message.";
			[TGAlertSheet showMessage:text title:@"Transcribe" inView:me.view];
		}];

	} else if ([action isEqualToString:@"Rate Transcription"]){
		__weak typeof(self) weakSelf = self;
		[TGAlertSheet showChoices:@[@"It was good", @"It was bad"]
							title:@"Rate Transcription" destructiveIndex:-1
						   inView:self.view onChoice:^(NSInteger index){
			[[TGClient shared] rateSpeechInChat:weakSelf.chatId message:messageId
										 isGood:(index == 0)
									 completion:^(BOOL ok, NSString *error){
				NSString *text = ok ? @"Telegram has the vote."
						: (error.length ? error : @"Telegram refused the vote.");
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
		[[TGClient shared] embeddingCodeOfMessage:messageId inChat:chatId
											album:[m[@"isAlbum"] boolValue]
									   completion:^(NSString *code){
			TGChatViewController *me = weakSelf;
			if (!me) return;
			if (!code.length){
				[TGSnackbar showInView:me.view
								  text:@"No embed for this message" seconds:2 onCommit:nil];
				return;
			}
			[UIPasteboard generalPasteboard].string = code;
			[TGSnackbar showInView:me.view text:@"Embed copied" seconds:2 onCommit:nil];
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
		NSDictionary *ft = [[TGClient shared] markdownForEditing:inFt];
		NSString *editText = [ft[@"text"] isKindOfClass:NSString.class] ? ft[@"text"] : text;
		NSArray *editEntities = [ft[@"entities"] isKindOfClass:NSArray.class] ? ft[@"entities"] : entities;
		self.input.text = editText;
		self.composerText = [[TGComposerText alloc] initWithText:editText entities:editEntities];
		[self showComposeBanner:self.editingIsCaption ? @"Editing caption" : @"Editing"];
		[self.input becomeFirstResponder];
		[self inputChanged];

	} else if ([action isEqualToString:@"Add to Favourites"]){
		[[TGClient shared] setSticker:TGStickerFileId(m) favourite:YES];
		[TGSnackbar showInView:self.navigationController.view ?: self.view
						  text:@"Added to Favourites" seconds:2 onCommit:nil];

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
	[[TGClient shared] localMessageWithId:messageId inChat:chatId
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
	[[TGClient shared] positionOfMessage:messageId inChat:chatId
								  thread:self.threadId
							  completion:^(NSInteger found){
		position = found;
		dispatch_group_leave(group);
	}];

	dispatch_group_enter(group);
	[[TGClient shared] statisticsOfMessage:messageId inChat:chatId
								completion:^(NSDictionary *found){
		statistics = found;
		dispatch_group_leave(group);
	}];

	if (effectId > 0){
		dispatch_group_enter(group);
		[[TGClient shared] messageEffectWithId:effectId
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
	[[TGClient shared] reportViewOfMessage:messageId inChat:chatId
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
							title:@"Message Info" inView:me.view];
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
	[[TGClient shared] sparsePositionsInChat:chatId fromMessageId:messageId
									  thread:self.threadId limit:200
								  completion:^(NSArray *ids){
		TGChatViewController *me = weakSelf;
		if (!me)
			return;
		if (!ids.count){
			[TGAlertSheet showMessage:@"Telegram returned no positions from here."
								title:@"Shared Media Map" inView:me.view];
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSNumber *position in ids)
			[rows addObject:[NSString stringWithFormat:@"Message %lld",
					(long long)[position longLongValue]]];
		[TGAlertSheet showChoices:rows
							title:[NSString stringWithFormat:@"%lu positions",
									(unsigned long)rows.count]
				  destructiveIndex:-1
						   inView:me.view
						 onChoice:^(NSInteger index){
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
	[[TGClient shared] availableReactionsForMessage:messageId
											 inChat:self.chatId
										 completion:^(NSArray *offered){
		TGChatViewController *me = weakSelf;
		if (!me)
			return;
		NSArray *emoji = [me reactionsWithDefaultFirst:
				(offered.count ? offered : fallback)];
		[TGAlertSheet showChoices:emoji
							title:@"React"
				 destructiveIndex:-1
						   inView:me.view
						 onChoice:^(NSInteger index){
			[[TGClient shared] reactTo:messageId inChat:me.chatId emoji:emoji[index]];
			[me reload];
		}];
	}];
}


@end
