#import "TGPerf.h"
#import "TGChatViewController.h"
#import "TGMessageStore.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGForwardPicker.h"
#import "TGVoiceRecorder.h"
#import "TGProfileViewController.h"
#import "TGThemeFile.h"
#import "TGCapabilities.h"
#import "TGTextRender.h"
#import "TGCustomEmojiStore.h"
#import "TGChatCellLogic.h"
#import "TGDevice.h"
#import <AddressBookUI/AddressBookUI.h>
#import <CoreLocation/CoreLocation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <QuartzCore/QuartzCore.h>
#import <MediaPlayer/MediaPlayer.h>
#import <MapKit/MapKit.h>
#import <AVFoundation/AVFoundation.h>
#import "TGVoiceDecoder.h"
#import "TGEmojiData.h"
#import "TGCustomEmojiStore.h"
#import "UIImage+WebP.h"
#import "TGLottieView.h"
#import "TGDevShowcase.h"
#import "TGCallViewController.h"
#import "TGPopupMenu.h"
#import "TGSnackbar.h"
#import "TGMediaViewer.h"
#import "TGPollPresentation.h"
#import "TGChecklistPresentation.h"
#import "TGGiftViewController.h"
#import "TGStoryViewerViewController.h"
#import "TGCommunityViewController.h"
#import "TGMusicPlayer.h"
#import "TGDevShowcase.h"
#import "TGMessageLayout.h"
#import "TGBubbleCell.h"
#import "TGChatViewControllerInternal.h"
#import "TGMessageStreamStore.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGDMTopicsViewController.h"
#import "TGPresent.h"

#if TG_DEV
#endif



#pragma mark - controller


@implementation TGChatViewController (TGChatViewPagination)

#pragma mark - pagination & scroll

/// The stop callbacks live in TGChatViewController+Chrome; this file only sees
/// the scroll events. Debouncing here means the check runs once the table has
/// actually settled, whether it stopped after a drag or after deceleration.
- (void)scheduleGifAutoplayAfterScrolling {
	if ([TGDevice tier] != TGDeviceTierVintage)
		return;
	// While the table is moving, a sticker that has not been built yet waits:
	// its raster would fight the scroll for the one core. Cleared below once
	// the scroll settles, then the rows that showed the emoji load for real.
	[TGLottieView setBuildsDeferred:YES];
	[NSObject cancelPreviousPerformRequestsWithTarget:self
			selector:@selector(resumeGifAutoplayAfterScrolling) object:nil];
	[self performSelector:@selector(resumeGifAutoplayAfterScrolling)
			withObject:nil afterDelay:TGAnimationDurationNormal];
}

/// One GIF at most on Vintage, and only the row nearest the middle of the
/// table. Everything else stops so the one core is not decoding two videos.
- (void)resumeGifAutoplayAfterScrolling {
	if ([TGDevice tier] != TGDeviceTierVintage)
		return;
	// A frame that held the main thread past the delay looked like a stop
	// and let every held sticker build loose mid-scroll.
	if (![self tableStillOrRetry:@selector(resumeGifAutoplayAfterScrolling)])
		return;

	// The scroll has settled: let deferred sticker builds run and redraw the
	// rows that had shown the emoji placeholder while the table moved.
	[TGLottieView setBuildsDeferred:NO];
	[self reloadTableDebounced];

	NSArray *visible = [self.table indexPathsForVisibleRows];
	NSIndexPath *nearest = nil;
	CGFloat best = CGFLOAT_MAX;
	CGFloat middle = CGRectGetMidY(self.table.bounds);
	for (NSIndexPath *path in visible) {
		if (path.row >= (NSInteger)self.messages.count)
			continue;
		CGRect row = [self.table rectForRowAtIndexPath:path];
		CGFloat distance = fabs(CGRectGetMidY(row) - middle);
		if (!nearest || distance < best) {
			nearest = path;
			best = distance;
		}
	}
	if (!nearest)
		return;

	TGBubbleCell *target = (TGBubbleCell *)[self.table cellForRowAtIndexPath:nearest];
	if (![target isKindOfClass:TGBubbleCell.class])
		return;

	for (UITableViewCell *visibleCell in self.table.visibleCells) {
		if (![visibleCell isKindOfClass:TGBubbleCell.class] || visibleCell == target)
			continue;
		TGBubbleCell *bubble = (TGBubbleCell *)visibleCell;
		if (!bubble.isPlayingLoop)
			continue;
		[bubble stopLoopingVideo];
		NSIndexPath *path = [self.table indexPathForCell:bubble];
		if (!path || path.row >= (NSInteger)self.messages.count)
			continue;
		// A stopped GIF goes back to showing its play mark.
		if ([self.messages[path.row][@"kind"] isEqualToString:@"messageAnimation"]) {
			bubble.disc.hidden = NO;
			bubble.disc.image = [TGIcons mediaDiscOfSide:kGifDisc playing:NO];
			[bubble settleHiddenViews];
		}
	}

	[self startGifIfWantedIn:target message:self.messages[nearest.row]];
}

- (void)tableTapped:(UITapGestureRecognizer *)gesture {
	// The playing circle is a subview of the table, and with a recognizer of its
	// own it lost to this one: a tap could not pause the note.
	UIView *circle = [self.table viewWithTag:0xF119];
	if (circle && CGRectContainsPoint(circle.frame, [gesture locationInView:self.table])){
		[self togglePlayback];
		return;
	}
	[self hideStickerPanel];
	[self.input resignFirstResponder];
}

- (void)releaseBackgroundWhenStill {
	double wait = TGChatRedrawDelay(CACurrentMediaTime(), self.lastScrollTime);
	if (wait > 0) {
		[self performSelector:@selector(releaseBackgroundWhenStill) withObject:nil
				   afterDelay:wait inModes:@[ NSRunLoopCommonModes ]];
		return;
	}
	self.backgroundHeld = NO;
	[[TGCustomEmojiStore shared] setDecodesHeld:NO];
	[[TGMessageStore shared] setUpdatesHeld:NO];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
	if (scrollView == self.table) {
		// The reader takes the chat from here: the bottom hold lets go.
		self.anchorToBottom = NO;
		[self hideStickerPanel];
		[self.input resignFirstResponder];
	}
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	if (scrollView == self.table) {
		self.lastScrollTime = CACurrentMediaTime();
		// Moved a screen up without a finger (a jump, the bench): not held.
		if (self.anchorToBottom && scrollView.contentOffset.y < scrollView.contentSize.height +
				scrollView.contentInset.bottom - TGDoubled(scrollView.bounds.size.height))
			self.anchorToBottom = NO;
		if (!self.backgroundHeld) {
			// Emoji decodes and store updates wait for scroll to settle, while
			// TGTextRenderQueue keeps running at LOW priority so prefetched
			// body bitmaps are ready before their rows hit displayLayer:.
			self.backgroundHeld = YES;
			[[TGCustomEmojiStore shared] setDecodesHeld:YES];
			if ([TGCapabilities pauseUpdatesDuringScrollWanted])
				[[TGMessageStore shared] setUpdatesHeld:YES];
			[self performSelector:@selector(releaseBackgroundWhenStill) withObject:nil
					   afterDelay:TGChatRedrawSettleSeconds inModes:@[ NSRunLoopCommonModes ]];
		}
		[self chromeDidScroll];
		[self scheduleGifAutoplayAfterScrolling];
	}
	if (scrollView != self.table || !self.messages.count)
		return;

	// Older: the stream owns the request, the "is there more" flag and the
	// duplicate filter; the table only keeps its offset around the insert.
	// Over the saved page the real one is on its way with the older messages;
	// asking for them too measured a page twice mid-scroll.
	if (scrollView.contentOffset.y < (CGFloat)TGMetricHistoryTopGate && !self.pageFromCache &&
		!self.streamStore.loadingOlder && !self.streamStore.reachedStart){
		__weak typeof(self) weakScroll = self;
		NSInteger pageLimit = [TGCapabilities chatHistoryPageLimit];
		[self.streamStore loadOlderInChat:self.chatId limit:pageLimit completion:^(BOOL added){
			TGChatViewController *me = weakScroll;
			if (!me || !added)
				return;
			NSUInteger windowLimit = [TGCapabilities chatMessageWindowLimit];
			[me.streamStore trimNewerToLimit:windowLimit];
			NSArray *raw = [me.streamStore messages];
			[me measureTextsOf:raw then:^{
				TGChatViewController *again = weakScroll;
				if (!again)
					return;
				// Read where the reader is now: the page was measured while
				// they kept scrolling.
				CGFloat oldHeight = again.table.contentSize.height;
				CGFloat oldOffset = again.table.contentOffset.y;
				again.rawMessages = [again.streamStore messages];
				again.messages = [again groupedMessagesFromMessages:again.rawMessages];
				[UIView setAnimationsEnabled:NO];
				[again.table reloadData];
				again.table.contentOffset = CGPointMake(0,
						oldOffset + (again.table.contentSize.height - oldHeight));
				[UIView setAnimationsEnabled:YES];
				[again fetchMissingImages];
			}];
		}];
	}

	// Newer: same deal at the bottom edge.
	CGFloat distanceFromBottom = scrollView.contentSize.height -
			(scrollView.contentOffset.y + scrollView.bounds.size.height);
	if (distanceFromBottom < (CGFloat)TGMetricHistoryTopGate &&
		!self.streamStore.loadingNewer && !self.streamStore.reachedEnd){
		__weak typeof(self) weakScroll = self;
		NSInteger pageLimit = [TGCapabilities chatHistoryPageLimit];
		[self.streamStore loadNewerInChat:self.chatId limit:pageLimit completion:^(BOOL added){
			TGChatViewController *me = weakScroll;
			if (!me || !added)
				return;
			CGFloat preTrimHeight = me.table.contentSize.height;
			CGFloat preTrimOffset = me.table.contentOffset.y;
			NSUInteger windowLimit = [TGCapabilities chatMessageWindowLimit];
			BOOL trimmedOlder = [me.streamStore trimOlderToLimit:windowLimit] > 0;
			[me measureTextsOf:[me.streamStore messages] then:^{
				TGChatViewController *again = weakScroll;
				if (!again)
					return;
				again.rawMessages = [again.streamStore messages];
				again.messages = [again groupedMessagesFromMessages:again.rawMessages];
				[UIView setAnimationsEnabled:NO];
				[again.table reloadData];
				if (trimmedOlder) {
					CGFloat shift = again.table.contentSize.height - preTrimHeight;
					again.table.contentOffset = CGPointMake(0, MAX(0, preTrimOffset + shift));
				}
				[UIView setAnimationsEnabled:YES];
				[again fetchMissingImages];
			}];
		}];
	}
}


+ (void)openCommunity:(int64_t)communityId
		 navigation:(UINavigationController *)navigation
			 inView:(UIView *)view {
	if (!communityId || !navigation)
		return;
#if TG_DEV
	NSDictionary *community = nil;
	for (NSDictionary *c in [TGMessageStore shared].communities)
		if ([c[@"id"] longLongValue] == communityId)
			community = c;
	TGCommunityViewController *screen = [[TGCommunityViewController alloc]
			initWithCommunity:community ?: @{@"id" : @(communityId), @"name" : @"Community"}];
	screen.hidesBottomBarWhenPushed = YES;
	[navigation pushViewController:screen animated:YES];
#else
	// The community screen is an admin harness; a reader needs its chats.
	__weak UINavigationController *weakNav = navigation;
	__weak UIView *weakView = view;
	[[TGMessageStore shared] communityFullInfo:communityId completion:^(NSDictionary *info, NSString *error){
		dispatch_async(dispatch_get_main_queue(), ^{
			UIView *host = weakView;
			if (!host)
				return;
			NSMutableArray *chats = [NSMutableArray array];
			for (NSDictionary *chat in info[@"chats"]){
				if ([chat isKindOfClass:NSDictionary.class] && ![chat[@"hidden"] boolValue] &&
					[chat[@"chatId"] longLongValue] != 0)
					[chats addObject:chat];
			}
			if (!chats.count){
				[TGAlertSheet showMessage:@"This community has no chats you can open."
									title:@"Community" inView:host];
				return;
			}
			NSMutableArray *titles = [NSMutableArray array];
			for (NSDictionary *chat in chats){
				NSString *title = chat[@"title"];
				if (!title.length)
					title = [[TGMessageStore shared] titleForChat:[chat[@"chatId"] longLongValue]];
				[titles addObject:title.length ? title : @"Chat"];
			}
			[TGPresent showList:titles title:@"Community" destructiveIndex:-1
			from:[TGPresent topControllerFrom:nil] onPick:^(NSInteger index){
				TGChatViewController *chat = [[TGChatViewController alloc] init];
				chat.chatId = [chats[(NSUInteger)index][@"chatId"] longLongValue];
				chat.chatTitle = titles[(NSUInteger)index];
				chat.hidesBottomBarWhenPushed = YES;
				[weakNav pushViewController:chat animated:YES];
			}];
		});
	}];
#endif
}

@end
