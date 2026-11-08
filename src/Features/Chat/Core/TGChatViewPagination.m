#import "TGPerf.h"
#import "TGChatViewController.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGForwardPicker.h"
#import "TGVoiceRecorder.h"
#import "TGProfileViewController.h"
#import "TGThemeFile.h"
#import "TGCapabilities.h"
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

#if TG_DEV
#endif



/// The pin in the strip under the bar, and where its two lines begin after it.
static const CGFloat kPinnedGlyph = 14.0f;
static const CGFloat kPinnedTextX = TGMetricPadLarge + kPinnedGlyph + TGMetricPadSmall;
/// Finds the message line when the strip already exists and only its text changes.
static const NSInteger kPinnedBodyTag = 0x9010;
/// The bar that stands in for the composer: mute for a channel you follow,
/// join for one you have not joined yet. One tag per state, so a second answer
/// replaces the bar instead of stacking another one on top.
static const NSInteger kChatMuteBarTag = 0x9020;
static const NSInteger kChatJoinGroupBarTag = 0x9021;
static const NSInteger kChatJoinChannelBarTag = 0x9022;
static const NSInteger kChatDiscussBarTag = 0x9023;
static const NSInteger kChatChannelBottomBarTag = 0x9024;

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
	if (self.table.isDragging || self.table.isDecelerating)
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

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
	if (scrollView == self.table) {
		[self hideStickerPanel];
		[self.input resignFirstResponder];
	}
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView == self.table) {
        [self chromeDidScroll];
        [self scheduleGifAutoplayAfterScrolling];
    }
    if (scrollView != self.table || !self.messages.count)
        return;

    // 1. Load older messages when scrolled near the top
    if (scrollView.contentOffset.y < (CGFloat)TGMetricHistoryTopGate && !self.isLoadingMoreHistory && !self.atChatStart) {
        self.isLoadingMoreHistory = YES;
        int64_t fromMessageId = self.streamStore.oldestMessageId;
        if (!fromMessageId) {
            NSArray *pool = self.rawMessages.count ? self.rawMessages : self.messages;
            fromMessageId = [pool.firstObject[@"id"] longLongValue];
        }

        __weak typeof(self) weakScroll = self;
        [[TGClient shared] historyForChat:self.chatId fromMessageId:fromMessageId limit:60 completion:^(NSArray *older) {
            dispatch_async(dispatch_get_main_queue(), ^{
                TGChatViewController *me = weakScroll;
                if (!me) return;
                me.isLoadingMoreHistory = NO;
                // Without this the next scroll event asks again, and a chat
                // that has nothing older - a local one above all - answers
                // an empty list a hundred times a second.
                if (older.count == 0) {
                    me.atChatStart = YES;
                    return;
                }

                CGFloat oldHeight = me.table.contentSize.height;
                CGFloat oldOffset = me.table.contentOffset.y;

                NSUInteger added = [me.streamStore prependOlderMessages:older];
                if (!added) {
                    me.atChatStart = YES;
                    return;
                }

                me.rawMessages = [me.streamStore messages];
                me.messages = [me groupedMessagesFromMessages:me.rawMessages];

                [UIView setAnimationsEnabled:NO];
                [me.table reloadData];
                me.table.contentOffset = CGPointMake(0, oldOffset + (me.table.contentSize.height - oldHeight));
                [UIView setAnimationsEnabled:YES];
                [me fetchMissingImages];
            });
        }];
    }

    // 2. Load newer messages when scrolled near the bottom
    CGFloat distanceFromBottom = scrollView.contentSize.height - (scrollView.contentOffset.y + scrollView.bounds.size.height);
    if (distanceFromBottom < (CGFloat)TGMetricHistoryTopGate && !self.isLoadingNewerHistory && !self.atChatEnd) {
        self.isLoadingNewerHistory = YES;
        int64_t fromMessageId = self.streamStore.newestMessageId;
        if (!fromMessageId) {
            NSArray *pool = self.rawMessages.count ? self.rawMessages : self.messages;
            fromMessageId = [pool.lastObject[@"id"] longLongValue];
        }

        __weak typeof(self) weakScroll = self;
        [[TGClient shared] newerHistoryForChat:self.chatId fromMessageId:fromMessageId limit:60 completion:^(NSArray *newer) {
            dispatch_async(dispatch_get_main_queue(), ^{
                TGChatViewController *me = weakScroll;
                if (!me) return;
                me.isLoadingNewerHistory = NO;
                if (newer.count == 0) {
                    me.atChatEnd = YES;
                    return;
                }

                NSUInteger added = [me.streamStore appendNewerMessages:newer];
                if (!added) {
                    me.atChatEnd = YES;
                    return;
                }

                me.rawMessages = [me.streamStore messages];
                me.messages = [me groupedMessagesFromMessages:me.rawMessages];

                [UIView setAnimationsEnabled:NO];
                [me.table reloadData];
                [UIView setAnimationsEnabled:YES];
                [me fetchMissingImages];

                if (newer.count < 60) {
                    me.atChatEnd = YES;
                }
            });
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
	for (NSDictionary *c in [TGClient shared].communities)
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
	[[TGClient shared] communityFullInfo:communityId completion:^(NSDictionary *info, NSString *error){
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
					title = [[TGClient shared] titleForChat:[chat[@"chatId"] longLongValue]];
				[titles addObject:title.length ? title : @"Chat"];
			}
			[TGAlertSheet showChoices:titles title:@"Community" destructiveIndex:-1 inView:host
							 onChoice:^(NSInteger index){
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
