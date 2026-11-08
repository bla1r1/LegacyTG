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


@implementation TGChatViewController (TGChatActionsMessageActions)

#pragma mark - message actions

- (void)messageHeld:(UILongPressGestureRecognizer *)hold {
	if (self.isEditingMessages)
		return;
	if (hold.state != UIGestureRecognizerStateBegan)
		return;

	NSIndexPath *path = [self.table indexPathForRowAtPoint:[hold locationInView:self.table]];
	if (path)
		[self showActionsForRow:path.row
						atPoint:[hold locationInView:self.view]];
}

/// Split out from the gesture so itglegacy://holdrow/N can reach it: a long
/// press cannot be delivered through a URL. With no finger to go by, the
/// menu falls back to the corner of the bubble.
- (void)showActionsForRow:(NSInteger)row {
	[self showActionsForRow:row atPoint:CGPointZero];
}

/// The reaction Telegram names as the default leads their bar; the rest keep
/// the app's order. A default the message does not offer is left where it is,
/// because reacting with it would be refused.
- (NSArray *)reactionsWithDefaultFirst:(NSArray *)reactions {
	NSString *first = [TGClient shared].defaultReactionEmoji;
	if (!first.length || ![reactions containsObject:first])
		return reactions;
	NSMutableArray *out = [NSMutableArray arrayWithObject:first];
	for (NSString *emoji in reactions)
		if (![emoji isEqualToString:first])
			[out addObject:emoji];
	return out;
}

/// The regular presentation lifts the held bubble to the top of the screen
/// and hangs the card under it; `point` is not the card's anchor any more.
/// It still says where the finger was, which is what the fallback card uses
/// when there is no bubble to lift. CGPointZero means there was no finger -
/// a URL asked for this - and the bubble's own corner stands in.
- (void)showActionsForRow:(NSInteger)row atPoint:(CGPoint)point {
	if (row < 0) {
		row = (NSInteger)self.messages.count + row;
	}
	if (row < 0 || row >= (NSInteger)self.messages.count)
		return;

	NSDictionary *m = self.messages[row];
	if ([m[@"service"] boolValue])
		return;

	// A second hold - or a URL asking for the same menu - replaces the card
	// that is open instead of stacking a new lift under it. Dismissing here
	// also runs the old card's onDismiss while the old lift is still the one
	// it was built for.
	[TGPopupMenu dismiss];
	self.actionMessage = m;

	BOOL mine = [m[@"outgoing"] boolValue];
	int64_t heldId = [m[@"id"] longLongValue];
	NSString *myReaction = m[@"myReaction"];

	NSArray *items = [self commonActionItemsForMessage:m mine:mine heldId:heldId];
	NSArray *reactions = [self reactionsWithDefaultFirst:[TGReactionPicker defaultReactions]];
	__weak typeof(self) weakSelf = self;

	// The same card for both presentations: the actions, the reaction bar and
	// every block stay exactly as they are. Only its anchor changes - under
	// the lifted bubble when there is one, under the finger when there is not.
	void (^presentMenu)(BOOL, CGRect, CGPoint) = ^(BOOL lifted, CGRect anchor, CGPoint where) {
		TGChatViewController *me = weakSelf;
		if (!me)
			return;
		me.actionMenuPoint = where;
		void (^onReaction)(NSString *) = ^(NSString *emoji) {
			TGChatViewController *strong = weakSelf;
			if (!strong) return;
			if ([emoji isEqualToString:myReaction]) {
				[[TGClient shared] removeReaction:myReaction fromMessage:heldId inChat:strong.chatId];
			} else {
				[[TGClient shared] reactTo:heldId inChat:strong.chatId emoji:emoji];
			}
			// The chips are part of the row's height, so the cached geometry
			// is stale the moment the reaction lands.
			[strong.layoutCache removeLayoutForMessageId:heldId];
			[strong reload];
		};
		void (^onDefaultReaction)(NSString *) = ^(NSString *emoji) {
			// Telegram keeps the choice; the bar was already promoted in place.
			[[TGClient shared] setDefaultReactionEmoji:emoji completion:^(BOOL ok){
				if (ok)
					return;
				TGChatViewController *strong = weakSelf;
				if (strong)
					[TGAlertSheet showMessage:@"Telegram refused that default reaction."
										 title:@"Reaction"
										inView:strong.view];
			}];
		};
		void (^onChoice)(NSInteger, NSString *) = ^(NSInteger index, NSString *title) {
			[weakSelf runMessageAction:title];
		};
		if (lifted) {
			[TGPopupMenu showItems:items
						anchoredAt:anchor
							inView:me.view
						 reactions:reactions
				  selectedReaction:myReaction
						onReaction:onReaction
				onDefaultReaction:onDefaultReaction
						  onChoice:onChoice
						 onDismiss:^{
				TGChatViewController *strong = weakSelf;
				[strong endHoldPresentation];
			}];
		} else {
			[TGPopupMenu showItems:items
						   atPoint:where
							inView:me.view
						 reactions:reactions
				  selectedReaction:myReaction
						onReaction:onReaction
				onDefaultReaction:onDefaultReaction
						  onChoice:onChoice];
		}
	};

	NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
	// A hold has a finger on the row, so its cell is there. The URL route has
	// none: scroll the row in first so there is a bubble to lift.
	if (CGPointEqualToPoint(point, CGPointZero)){
		[self.table scrollToRowAtIndexPath:indexPath
						  atScrollPosition:UITableViewScrollPositionMiddle
								  animated:NO];
		[self.table layoutIfNeeded];
	}

	TGBubbleCell *cell = (TGBubbleCell *)[self.table cellForRowAtIndexPath:indexPath];
	CGRect anchor = [self beginHoldPresentationForCell:cell didLift:^(CGRect lifted){
		presentMenu(YES, lifted, CGPointMake(CGRectGetMidX(lifted), CGRectGetMaxY(lifted)));
	}];

	// No bubble to lift - a service row or a row that went away between the
	// touch and this call. The old point-anchored card is still better than
	// no card at all.
	if (CGRectIsEmpty(anchor)){
		CGPoint where = point;
		if (CGPointEqualToPoint(where, CGPointZero)){
			CGRect rect = [self.table rectForRowAtIndexPath:indexPath];
			where = [self.table convertPoint:CGPointMake(
					mine ? CGRectGetMaxX(rect) - TGMetricMenuActionOffset
						 : TGMetricMenuActionOffset,
					CGRectGetMidY(rect)) toView:self.view];
		}
		presentMenu(NO, CGRectZero, where);
	}
}


@end
