#import "TGPopupMenu.h"
#import "TGAlertSheet.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import <QuartzCore/QuartzCore.h>
#import "TGStyle.h"
#import "TGReactionPicker.h"
#import "TGLocalization.h"
#import "TGChatActionMenuModel.h"

static const CGFloat kMenuCardW        = 212.0f;
static const CGFloat kMenuRowH         = 36.0f;
static const CGFloat kMenuRowHCompact  = 32.0f;
static const CGFloat kMenuHeaderH      = TGMetricPadSmall;
static const CGFloat kMenuGlyphSide    = 18.0f;
static const CGFloat kMenuGlyphX       = 16.0f;
static const CGFloat kMenuLabelX       = 46.0f;
static const CGFloat kReactionPadH     = 12.0f;
static const CGFloat kReactionPadV     = 6.0f;

static TGPopupMenu *sOpenMenu = nil;

@interface TGPopupMenu () <UIScrollViewDelegate, UIGestureRecognizerDelegate> {
	UIView *_reactionWrapper;
	UIView *_reactionCard;
	UIView *_actionWrapper;
	UIView *_actionCard;
	TGReactionPicker *_reactionPicker;
	NSArray *_items;
	void (^_choice)(NSInteger, NSString *);
	void (^_reactionChoice)(NSString *);
	void (^_defaultReactionChoice)(NSString *);
	/// Named once when the menu goes away, however it goes away: the hold
	/// presentation uses it to put the message back into the list.
	void (^_onDismiss)(void);
	NSTimeInterval _shownAt;

	/// The lifted-bubble presentation: a full-screen vertical scroll view
	/// holding the reaction capsule, lifted bubble, and full-size action card.
	BOOL _lifted;
	CGRect _anchorRect;
	UIView *_liftedView;
	UIScrollView *_pageScroll;
	CGFloat _reactionBaseY;
	CGFloat _reactionH;
	CGFloat _bubbleMaxY;
	CGFloat _topInset;
}
@end

@implementation TGPopupMenu

+ (void)liftedRoomForItems:(NSArray *)items
				headerView:(UIView *)headerView
				 reactions:(NSArray *)reactions
					 above:(CGFloat *)above
					 below:(CGFloat *)below {
	CGFloat headerH = headerView ? headerView.bounds.size.height : kMenuHeaderH;
	CGFloat rowH = ([UIScreen mainScreen].bounds.size.height <= 500.0f) ? kMenuRowHCompact : kMenuRowH;
	CGFloat cardH = headerH + (CGFloat)items.count * rowH + TGMetricPadSmall;
	for (NSDictionary *it in items)
		if ([it[@"title"] isEqualToString:@"Select"]){
			cardH += TGMetricPadTiny;
			break;
		}
	CGFloat reactionH = 0;
	if (reactions.count){
		TGReactionPicker *probe = [[TGReactionPicker alloc] initWithEmojis:reactions selectedEmoji:nil];
		reactionH = [probe sizeThatFits:CGSizeZero].height + kReactionPadV + TGMetricPadSmall;
	}
	if (above) *above = reactionH;
	if (below) *below = TGMetricPadSmall + cardH;
}

+ (void)dismiss {
	TGPopupMenu *menu = sOpenMenu;
	sOpenMenu = nil;
	// The block is copied and the menu released before it runs: it restores
	// the held message, which must not happen while a new menu still holds
	// this one as the open menu. A nil menu has no fields to read.
	if (menu && menu->_liftedView && menu.superview &&
		menu->_liftedView.superview == menu->_pageScroll) {
		CGRect screenRect = [menu->_pageScroll convertRect:menu->_liftedView.frame
													toView:menu.superview];
		menu->_liftedView.frame = screenRect;
		[menu.superview addSubview:menu->_liftedView];
	}
	void (^done)(void) = menu ? [menu->_onDismiss copy] : nil;
	[menu removeFromSuperview];
	if (done)
		done();
}

+ (void)showItems:(NSArray *)items
          atPoint:(CGPoint)point
           inView:(UIView *)host
         onChoice:(void (^)(NSInteger, NSString *))choice
{
	// A plain list of actions is what UIActionSheet is for; the drawn popup
	// stays only where it carries something the system sheet cannot
	// (reactions, the emoji header).
	NSMutableArray *titles = [NSMutableArray arrayWithCapacity:items.count];
	__block NSInteger destructive = -1;
	[items enumerateObjectsUsingBlock:^(NSDictionary *item, NSUInteger i, BOOL *stop){
		[titles addObject:item[@"title"] ?: @""];
		if (destructive < 0 && [item[@"destructive"] boolValue])
			destructive = (NSInteger)i;
	}];
	[TGAlertSheet showChoices:titles title:nil destructiveIndex:destructive inView:host
					 onChoice:^(NSInteger index){ if (choice) choice(index, titles[index]); }];
}

+ (void)showItems:(NSArray *)items
          atPoint:(CGPoint)point
           inView:(UIView *)host
       headerView:(UIView *)headerView
         onChoice:(void (^)(NSInteger, NSString *))choice
{
	if ((!items.count && !headerView) || !host)
		return;
	[self dismiss];

	// The header is the reason this variant exists - an animated sticker or
	// an emoji glyph above the rows - so it is drawn as the card, not handed
	// to the system sheet where a header has nowhere to go.
	TGPopupMenu *menu = [[TGPopupMenu alloc] initWithFrame:host.bounds];
	[menu buildWithItems:items atPoint:point headerView:headerView reactions:nil selectedReaction:nil];
	menu->_choice = [choice copy];
	menu->_shownAt = [NSDate timeIntervalSinceReferenceDate];
	[host addSubview:menu];
	sOpenMenu = menu;

	menu->_actionWrapper.transform = CGAffineTransformMakeScale(TGTransformScaleMenuInitial, TGTransformScaleMenuInitial);
	menu->_actionWrapper.alpha = TGAlphaTransparent;
	[UIView animateWithDuration:TGAnimationDurationFast animations:^{
		menu->_actionWrapper.transform = CGAffineTransformIdentity;
		menu->_actionWrapper.alpha = TGAlphaOpaque;
	}];
}

+ (void)showItems:(NSArray *)items
          atPoint:(CGPoint)point
           inView:(UIView *)host
        reactions:(NSArray<NSString *> *)reactions
   selectedReaction:(NSString *)selectedReaction
       onReaction:(void (^)(NSString *))reactionChoice
         onChoice:(void (^)(NSInteger, NSString *))choice
{
	[self showItems:items atPoint:point inView:host headerView:nil reactions:reactions
		   selectedReaction:selectedReaction onReaction:reactionChoice
		onDefaultReaction:nil onChoice:choice];
}

+ (void)showItems:(NSArray *)items
          atPoint:(CGPoint)point
           inView:(UIView *)host
       headerView:(UIView *)headerView
        reactions:(NSArray<NSString *> *)reactions
   selectedReaction:(NSString *)selectedReaction
       onReaction:(void (^)(NSString *))reactionChoice
onDefaultReaction:(void (^)(NSString *))defaultChoice
         onChoice:(void (^)(NSInteger, NSString *))choice
{
	if ((!items.count && !reactions.count) || !host)
		return;
	[self dismiss];

	TGPopupMenu *menu = [[TGPopupMenu alloc] initWithFrame:host.bounds];
	[menu buildWithItems:items atPoint:point headerView:headerView reactions:reactions selectedReaction:selectedReaction];
	menu->_choice = [choice copy];
	menu->_reactionChoice = [reactionChoice copy];
	menu->_defaultReactionChoice = [defaultChoice copy];
	menu->_shownAt = [NSDate timeIntervalSinceReferenceDate];
	[host addSubview:menu];
	sOpenMenu = menu;

	if (menu->_reactionWrapper) {
		menu->_reactionWrapper.transform = CGAffineTransformMakeScale(TGTransformScaleMenuInitial, TGTransformScaleMenuInitial);
		menu->_reactionWrapper.alpha = TGAlphaTransparent;
	}
	menu->_actionWrapper.transform = CGAffineTransformMakeScale(TGTransformScaleMenuInitial, TGTransformScaleMenuInitial);
	menu->_actionWrapper.alpha = TGAlphaTransparent;

	[UIView animateWithDuration:TGAnimationDurationFast animations:^{
		if (menu->_reactionWrapper) {
			menu->_reactionWrapper.transform = CGAffineTransformIdentity;
			menu->_reactionWrapper.alpha = TGAlphaOpaque;
		}
		menu->_actionWrapper.transform = CGAffineTransformIdentity;
		menu->_actionWrapper.alpha = TGAlphaOpaque;
	}];
}

+ (void)showItems:(NSArray *)items
       anchoredAt:(CGRect)anchor
           inView:(UIView *)host
       headerView:(UIView *)headerView
        reactions:(NSArray<NSString *> *)reactions
   selectedReaction:(NSString *)selectedReaction
       onReaction:(void (^)(NSString *))reactionChoice
onDefaultReaction:(void (^)(NSString *))defaultChoice
         onChoice:(void (^)(NSInteger, NSString *))choice
       onDismiss:(void (^)(void))dismissal
{
	[self showItems:items anchoredAt:anchor liftedView:nil inView:host
		 headerView:headerView reactions:reactions selectedReaction:selectedReaction
		 onReaction:reactionChoice onDefaultReaction:defaultChoice
		   onChoice:choice onDismiss:dismissal];
}

+ (void)showItems:(NSArray *)items
       anchoredAt:(CGRect)anchor
       liftedView:(UIView *)liftedView
           inView:(UIView *)host
       headerView:(UIView *)headerView
        reactions:(NSArray<NSString *> *)reactions
   selectedReaction:(NSString *)selectedReaction
       onReaction:(void (^)(NSString *))reactionChoice
onDefaultReaction:(void (^)(NSString *))defaultChoice
         onChoice:(void (^)(NSInteger, NSString *))choice
       onDismiss:(void (^)(void))dismissal
{
	if ((!items.count && !reactions.count) || !host)
		return;
	[self dismiss];

	TGPopupMenu *menu = [[TGPopupMenu alloc] initWithFrame:host.bounds];
	menu->_lifted = YES;
	menu->_anchorRect = anchor;
	menu->_liftedView = liftedView;
	[menu buildWithItems:items
				 atPoint:CGPointMake(CGRectGetMidX(anchor), CGRectGetMaxY(anchor))
			  headerView:headerView
			   reactions:reactions
		selectedReaction:selectedReaction];
	menu->_choice = [choice copy];
	menu->_reactionChoice = [reactionChoice copy];
	menu->_defaultReactionChoice = [defaultChoice copy];
	menu->_onDismiss = [dismissal copy];
	menu->_shownAt = [NSDate timeIntervalSinceReferenceDate];
	[host addSubview:menu];
	sOpenMenu = menu;

	if (menu->_reactionWrapper) {
		menu->_reactionWrapper.transform = CGAffineTransformMakeScale(TGTransformScaleMenuInitial, TGTransformScaleMenuInitial);
		menu->_reactionWrapper.alpha = TGAlphaTransparent;
	}
	menu->_actionWrapper.transform = CGAffineTransformMakeScale(TGTransformScaleMenuInitial, TGTransformScaleMenuInitial);
	menu->_actionWrapper.alpha = TGAlphaTransparent;

	[UIView animateWithDuration:TGAnimationDurationFast animations:^{
		if (menu->_reactionWrapper) {
			menu->_reactionWrapper.transform = CGAffineTransformIdentity;
			menu->_reactionWrapper.alpha = TGAlphaOpaque;
		}
		menu->_actionWrapper.transform = CGAffineTransformIdentity;
		menu->_actionWrapper.alpha = TGAlphaOpaque;
	}];
}

- (void)buildWithItems:(NSArray *)items
               atPoint:(CGPoint)point
            headerView:(UIView *)headerView
             reactions:(NSArray<NSString *> *)reactions
      selectedReaction:(NSString *)selectedReaction
{
	_items = items;
	TGTheme *theme = [TGTheme shared];

	// The lifted presentation sits over the blurred chat and must not add a
	// second wash to it; it is a touch catcher, not a tinted sheet.
	self.backgroundColor = _lifted ? [UIColor clearColor] : [theme menuWashColour];

	CGFloat hostW = self.bounds.size.width;
	CGFloat hostH = self.bounds.size.height;
	CGFloat rowH = (_lifted && hostH <= 500.0f) ? kMenuRowHCompact : kMenuRowH;

	// Calculate Action Card Height (always full natural height; when _lifted,
	// _pageScroll scrolls the entire stack so nothing is clipped or squished).
	CGFloat headerH = headerView ? headerView.bounds.size.height : kMenuHeaderH;
	CGFloat actionCardH = headerH + (CGFloat)items.count * rowH + TGMetricPadSmall;
	for (NSDictionary *it in items) {
		if ([it[@"title"] isEqualToString:@"Select"]) {
			actionCardH += TGMetricPadTiny;
			break;
		}
	}

	CGFloat reactionW = 0.0f;
	CGFloat reactionH = 0.0f;
	CGSize pSize = CGSizeZero;

	if (reactions.count) {
		_reactionPicker = [[TGReactionPicker alloc] initWithEmojis:reactions selectedEmoji:selectedReaction];
		pSize = [_reactionPicker sizeThatFits:CGSizeZero];
		reactionW = pSize.width + kReactionPadH;
		reactionH = pSize.height + kReactionPadV;

		__weak typeof(self) weakSelf = self;
		_reactionPicker.onEmojiSelected = ^(NSString *emoji){
			TGPopupMenu *strongSelf = weakSelf;
			if (!strongSelf) return;
			void (^rChoice)(NSString *) = strongSelf->_reactionChoice;
			[TGPopupMenu dismiss];
			if (rChoice) {
				rChoice(emoji);
			}
		};
		_reactionPicker.onDefaultRequested = ^(NSString *emoji){
			TGPopupMenu *strongSelf = weakSelf;
			if (!strongSelf) return;
			void (^dChoice)(NSString *) = strongSelf->_defaultReactionChoice;
			// Promote first: the bar is still on screen under the finger,
			// so the answer to the hold is visible before the request lands.
			[strongSelf->_reactionPicker promoteEmoji:emoji];
			if (dChoice) {
				dChoice(emoji);
			}
		};
	}

	// Layout positions
	CGFloat cardX = MIN(MAX(TGMetricPad, point.x - TGHalf(kMenuCardW)), hostW - kMenuCardW - TGMetricPad);
	CGFloat cardY = 0.0f;
	CGFloat reactionX = 0.0f;
	CGFloat reactionY = 0.0f;
	UIView *container = self;

	if (_lifted) {
		_pageScroll = [[UIScrollView alloc] initWithFrame:self.bounds];
		_pageScroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		_pageScroll.backgroundColor = [UIColor clearColor];
		_pageScroll.alwaysBounceVertical = YES;
		_pageScroll.showsVerticalScrollIndicator = YES;
		_pageScroll.scrollsToTop = NO;
		_pageScroll.delegate = self;
		[self addSubview:_pageScroll];

		UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backgroundTapped:)];
		tap.cancelsTouchesInView = NO;
		tap.delegate = self;
		[_pageScroll addGestureRecognizer:tap];

		container = _pageScroll;

		CGFloat topPad = (hostH > 430.0f) ? (20.0f + TGMetricPad) : TGMetricPad;
		CGFloat above = reactionH > 0 ? (reactionH + TGMetricPadSmall) : 0.0f;
		TGHoldScrollMetrics m = TGHoldScrollLayout(_anchorRect, above, TGMetricPadSmall,
				actionCardH, topPad, hostH - TGMetricPad, hostH, TGMetricPad);

		if (_liftedView) {
			_liftedView.frame = CGRectMake(CGRectGetMinX(_anchorRect), m.bubbleY,
					CGRectGetWidth(_anchorRect), CGRectGetHeight(_anchorRect));
			[_pageScroll addSubview:_liftedView];
		}

		_reactionBaseY = m.reactionBaseY;
		_reactionH = reactionH;
		_bubbleMaxY = m.bubbleY + CGRectGetHeight(_anchorRect);
		_topInset = topPad;

		CGFloat midX = CGRectGetMidX(_anchorRect);
		reactionX = MIN(MAX(TGMetricPad, midX - TGHalf(reactionW)),
						hostW - reactionW - TGMetricPad);
		reactionY = TGHoldStickyReactionY(_reactionBaseY, _bubbleMaxY, _reactionH,
				TGMetricPadSmall, m.initialOffsetY, _topInset);
		cardX = MIN(MAX(TGMetricPad, midX - TGHalf(kMenuCardW)),
					hostW - kMenuCardW - TGMetricPad);
		cardY = m.cardY;

		_pageScroll.contentSize = CGSizeMake(hostW, m.contentH);
		_pageScroll.contentOffset = CGPointMake(0.0f, m.initialOffsetY);
	} else if (reactions.count) {
		reactionX = MIN(MAX(TGMetricPad, point.x - TGHalf(reactionW)), hostW - reactionW - TGMetricPad);
		if (point.y + actionCardH + TGMetricPad < hostH) {
			// Message is high: Reactions capsule floating ABOVE message, Action card BELOW
			reactionY = MAX(TGMetricPad, point.y - reactionH - TGMetricPadSmall);
			cardY = point.y + TGMetricPadSmall;
		} else {
			// Message is low: Action card floats above message, Reaction capsule above action card
			cardY = MAX(TGMetricPad + reactionH + TGMetricPadSmall, point.y - actionCardH - TGMetricPadSmall);
			reactionY = cardY - reactionH - TGMetricPadSmall;
		}
	} else {
		if (point.y + actionCardH + TGMetricPad < hostH) {
			cardY = point.y + TGMetricPadSmall;
		} else {
			cardY = MAX(TGMetricPad, point.y - actionCardH - TGMetricPadSmall);
		}
	}

	// 1. Build Floating Reaction Capsule
	if (reactions.count) {
		_reactionWrapper = [[UIView alloc] initWithFrame:CGRectMake(reactionX, reactionY, reactionW, reactionH)];
		_reactionWrapper.backgroundColor = [UIColor clearColor];
		_reactionWrapper.layer.shadowColor = [UIColor blackColor].CGColor;
		_reactionWrapper.layer.shadowOpacity = TGMetricShadowMenuOpacity;
		_reactionWrapper.layer.shadowRadius = TGMetricShadowMenuRadius;
		_reactionWrapper.layer.shadowOffset = TGMetricShadowOffsetMenu;
		_reactionWrapper.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:_reactionWrapper.bounds
																	  cornerRadius:TGHalf(reactionH)].CGPath;
		[container addSubview:_reactionWrapper];

		_reactionCard = [[UIView alloc] initWithFrame:_reactionWrapper.bounds];
		_reactionCard.backgroundColor = [theme calloutBackgroundColour];
		_reactionCard.layer.cornerRadius = TGHalf(reactionH);
		_reactionCard.layer.masksToBounds = YES;
		_reactionCard.layer.borderColor = [theme calloutBorderColour].CGColor;
		_reactionCard.layer.borderWidth = 1.0f;
		// No shouldRasterize: the picker inside animates (emoji spring-in),
		// so the raster cache would be invalidated and re-created every frame,
		// costing more than the masksToBounds clip it was meant to amortise.
		// masksToBounds (above) clips the picker correctly without rasterizing.
		[_reactionWrapper addSubview:_reactionCard];

		UIImage *rGlossImage = [TGTheme calloutGlossImageWithSize:CGSizeMake(reactionW, TGHalf(reactionH))];
		if (rGlossImage) {
			UIImageView *rGloss = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, reactionW, TGHalf(reactionH))];
			rGloss.image = rGlossImage;
			[_reactionCard addSubview:rGloss];
		}

		_reactionPicker.frame = CGRectMake(TGHalf(kReactionPadH), TGHalf(kReactionPadV), pSize.width, pSize.height);
		[_reactionCard addSubview:_reactionPicker];
	}

	// 2. Build Floating Action Menu Card
	_actionWrapper = [[UIView alloc] initWithFrame:CGRectMake(cardX, cardY, kMenuCardW, actionCardH)];
	_actionWrapper.backgroundColor = [UIColor clearColor];
	_actionWrapper.layer.shadowColor = [UIColor blackColor].CGColor;
	_actionWrapper.layer.shadowOpacity = TGMetricShadowMenuOpacity;
	_actionWrapper.layer.shadowRadius = TGMetricShadowMenuRadius;
	_actionWrapper.layer.shadowOffset = TGMetricShadowOffsetMenu;
	_actionWrapper.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:_actionWrapper.bounds
																  cornerRadius:TGMetricCornerCard].CGPath;
	[container addSubview:_actionWrapper];

	_actionCard = [[UIView alloc] initWithFrame:_actionWrapper.bounds];
	_actionCard.backgroundColor = [UIColor clearColor];
	[_actionWrapper addSubview:_actionCard];

	// Pre-bake rounded card + border + optional gloss into one flat image so
	// scrolling _actionScroll never triggers an offscreen cornerRadius mask pass.
	UIGraphicsBeginImageContextWithOptions(_actionCard.bounds.size, NO, [UIScreen mainScreen].scale);
	UIBezierPath *cardPath = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(_actionCard.bounds, 0.5f, 0.5f)
														cornerRadius:TGMetricCornerCard];
	[[theme calloutBackgroundColour] setFill];
	[cardPath fill];
	UIImage *glossImage = [TGTheme calloutGlossImageWithSize:CGSizeMake(kMenuCardW, TGHalf(actionCardH))];
	if (glossImage) {
		CGContextSaveGState(UIGraphicsGetCurrentContext());
		[cardPath addClip];
		[glossImage drawInRect:CGRectMake(0, 0, kMenuCardW, TGHalf(actionCardH))];
		CGContextRestoreGState(UIGraphicsGetCurrentContext());
	}
	[[theme calloutBorderColour] setStroke];
	cardPath.lineWidth = 1.0f;
	[cardPath stroke];
	UIImage *cardBg = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	if (cardBg) {
		UIImageView *bgView = [[UIImageView alloc] initWithFrame:_actionCard.bounds];
		bgView.image = cardBg;
		[_actionCard addSubview:bgView];
	}

	CGFloat currentY = 0.0f;

	if (headerView) {
		headerView.frame = CGRectMake(0, 0, kMenuCardW, headerH);
		[_actionCard addSubview:headerView];
		currentY += headerH;

		UIView *divDark = [[UIView alloc] initWithFrame:CGRectMake(TGMetricPadSmall, currentY - 0.5f, kMenuCardW - TGDoubled(TGMetricPadSmall), 0.5f)];
		divDark.backgroundColor = [theme calloutDividerDarkColour];
		[_actionCard addSubview:divDark];

		UIView *divLight = [[UIView alloc] initWithFrame:CGRectMake(TGMetricPadSmall, currentY, kMenuCardW - TGDoubled(TGMetricPadSmall), 0.5f)];
		divLight.backgroundColor = [theme calloutDividerLightColour];
		[_actionCard addSubview:divLight];
	} else {
		currentY = kMenuHeaderH;
	}

	UIView *rowParent = _actionCard;

	// Action Rows
	for (NSUInteger i = 0; i < items.count; i++) {
		NSDictionary *item = items[i];
		BOOL destructive = [item[@"destructive"] boolValue];
		NSString *title = item[@"title"];

		// Section divider before "Select"
		if ([title isEqualToString:@"Select"]) {
			UIView *sDark = [[UIView alloc] initWithFrame:CGRectMake(TGMetricPadSmall, currentY - 0.5f, kMenuCardW - TGDoubled(TGMetricPadSmall), 0.5f)];
			sDark.backgroundColor = [theme calloutDividerDarkColour];
			[rowParent addSubview:sDark];

			UIView *sLight = [[UIView alloc] initWithFrame:CGRectMake(TGMetricPadSmall, currentY, kMenuCardW - TGDoubled(TGMetricPadSmall), 0.5f)];
			sLight.backgroundColor = [theme calloutDividerLightColour];
			[rowParent addSubview:sLight];

			currentY += TGMetricPadTiny;
		}

		UIButton *row = [UIButton buttonWithType:UIButtonTypeCustom];
		row.frame = CGRectMake(0, currentY, kMenuCardW, rowH);
		row.tag = (NSInteger)i;
		[row addTarget:self action:@selector(rowTapped:) forControlEvents:UIControlEventTouchUpInside];
		[row setBackgroundImage:[TGTheme skeuomorphicButtonImageWithColor:([theme isDark] ? [theme accentColour] : [theme buttonHighlightColour]) height:rowH highlighted:YES cornerRadius:0.0f] forState:UIControlStateHighlighted];
		[rowParent addSubview:row];

		UIImage *glyph = [TGIcons menuGlyphNamed:item[@"icon"]];
		if (glyph) {
			UIImageView *icon = [[UIImageView alloc] initWithFrame:CGRectMake(
					kMenuGlyphX, TGCenteredOrigin(rowH, kMenuGlyphSide), kMenuGlyphSide, kMenuGlyphSide)];
			icon.image = glyph;
			icon.contentMode = UIViewContentModeScaleAspectFit;
			[TGIcons tintImageView:icon colour:(destructive ? [theme destructiveColour]
					: [theme calloutIconColour])];
			[row addSubview:icon];
		}

		// A row with a subtitle (a timed message's Delete) puts the title in
		// the upper part and the smaller line under it, in the row's colour.
		NSString *subtitle = [item[@"subtitle"] isKindOfClass:NSString.class] ? item[@"subtitle"] : nil;
		CGFloat titleH = subtitle.length ? rowH - TGMetricLineMicro : rowH;
		UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(
				kMenuLabelX, 0, kMenuCardW - kMenuLabelX - TGMetricPad, titleH)];
		if (subtitle.length){
			UILabel *small = [[UILabel alloc] initWithFrame:CGRectMake(kMenuLabelX,
					titleH - TGMetricPadSmall, kMenuCardW - kMenuLabelX - TGMetricPad, TGMetricLineMicro)];
			small.text = subtitle;
			small.font = TGFontMicro();
			small.backgroundColor = [UIColor clearColor];
			small.textColor = destructive ? [theme destructiveColour] : [theme secondaryTextColour];
			small.shadowColor = [theme calloutTextShadowColour];
			small.shadowOffset = [theme isDark] ? CGSizeMake(0, -1.0f) : ([TGTheme drawsSkeuomorphicChrome] ? CGSizeMake(0, 1.0f) : CGSizeZero);
			[row addSubview:small];
		}
		label.text = title;
		label.font = TGFontRowStrong();
		label.backgroundColor = [UIColor clearColor];
		label.textColor = destructive ? [theme destructiveColour] : [theme calloutTextColour];
		label.shadowColor = [theme calloutTextShadowColour];
		label.shadowOffset = [theme isDark] ? CGSizeMake(0, -1.0f) : ([TGTheme drawsSkeuomorphicChrome] ? CGSizeMake(0, 1.0f) : CGSizeZero);
		[row addSubview:label];

		currentY += rowH;
	}
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	if (scrollView != _pageScroll || !_reactionWrapper)
		return;
	CGRect rf = _reactionWrapper.frame;
	rf.origin.y = TGHoldStickyReactionY(_reactionBaseY, _bubbleMaxY, _reactionH,
			TGMetricPadSmall, scrollView.contentOffset.y, _topInset);
	_reactionWrapper.frame = rf;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
	CGPoint where = [touch locationInView:_pageScroll];
	if (CGRectContainsPoint(_actionWrapper.frame, where))
		return NO;
	if (_reactionWrapper && CGRectContainsPoint(_reactionWrapper.frame, where))
		return NO;
	if (_liftedView && CGRectContainsPoint(_liftedView.frame, where)) {
		if ([touch.view isKindOfClass:[UITextView class]] ||
			[_liftedView viewWithTag:0x909E] != nil)
			return NO;
	}
	return YES;
}

- (void)backgroundTapped:(UITapGestureRecognizer *)tap {
	if ([NSDate timeIntervalSinceReferenceDate] - _shownAt < 0.3)
		return;
	[TGPopupMenu dismiss];
}

- (void)rowTapped:(UIButton *)row {
	NSInteger index = row.tag;
	NSDictionary *item = _items[(NSUInteger)index];
	// `action` keeps dispatch stable while `title` is translated.
	NSString *action = item[@"action"] ?: item[@"title"];
	void (^choice)(NSInteger, NSString *) = _choice;
	[TGPopupMenu dismiss];
	if (choice)
		choice(index, action);
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
	if ([NSDate timeIntervalSinceReferenceDate] - _shownAt < 0.3)
		return;
	CGPoint where = [[touches anyObject] locationInView:self];
	if (!CGRectContainsPoint(_actionWrapper.frame, where) &&
		(!_reactionWrapper || !CGRectContainsPoint(_reactionWrapper.frame, where))) {
		[TGPopupMenu dismiss];
	}
}

@end

@interface TGQuotePickerController () {
	UITextView *_textView;
	NSString *_fullText;
	void (^_onQuote)(NSString *quote);
}
@end

@implementation TGQuotePickerController

- (instancetype)initWithText:(NSString *)text onQuote:(void (^)(NSString *quote))onQuote {
	if ((self = [super init])){
		_fullText = [text copy] ?: @"";
		_onQuote = [onQuote copy];
		self.title = TGLocalized(@"Quote");
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	TGTheme *theme = [TGTheme shared];
	self.view.backgroundColor = [theme listBackgroundColour];

	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
			initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
								 target:self
								 action:@selector(cancelTapped)];
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
			initWithTitle:TGLocalized(@"Quote")
					style:UIBarButtonItemStyleDone
				   target:self
				   action:@selector(quoteTapped)];

	CGFloat pad = TGMetricPadLarge;
	UITextView *tv = [[UITextView alloc] initWithFrame:CGRectInset(self.view.bounds, pad, pad)];
	tv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	tv.backgroundColor = [UIColor clearColor];
	tv.textColor = [theme primaryTextColour];
	tv.font = TGFontBody();
	tv.editable = NO;
	tv.text = _fullText;
	_textView = tv;
	[self.view addSubview:tv];

	UIMenuItem *quoteItem = [[UIMenuItem alloc] initWithTitle:TGLocalized(@"Quote")
														action:@selector(quoteSelectionFromMenu:)];
	[UIMenuController sharedMenuController].menuItems = @[quoteItem];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	[_textView becomeFirstResponder];
	_textView.selectedRange = NSMakeRange(0, _fullText.length);
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
	if (action == @selector(quoteSelectionFromMenu:))
		return _textView.selectedRange.length > 0;
	return [super canPerformAction:action withSender:sender];
}

- (void)quoteSelectionFromMenu:(id)sender {
	[self quoteTapped];
}

- (void)cancelTapped {
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)quoteTapped {
	NSRange sel = _textView.selectedRange;
	NSString *picked = (sel.length > 0 && NSMaxRange(sel) <= _fullText.length)
			? [_fullText substringWithRange:sel]
			: _fullText;
	picked = [picked stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!picked.length)
		picked = _fullText;
	void (^cb)(NSString *) = _onQuote;
	[self dismissViewControllerAnimated:YES completion:^{
		if (cb) cb(picked);
	}];
}

@end
