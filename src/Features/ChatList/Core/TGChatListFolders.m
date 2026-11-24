#import "TGCustomEmojiStore.h"
#import "TGNameWithStatus.h"
#import "TGChatListViewControllerInternal.h"
#import "TGPerf.h"
#import "TGStatusText.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGDateFormat.h"
#import "TGOptions.h"
#import "TGStoryViewerViewController.h"
#import "TGStoryComposerViewController.h"
#import "TGProfileViewController.h"
#import "TGPasscode.h"
#import "TGPasscodeViewController.h"
#import "TGChatListRowGeometry.h"
#import "TGCapabilities.h"


// Height of the folder pill strip above the chat list (official-style tabs).




@implementation TGChatListViewController (TGChatListFolders)

#pragma mark - folders and scroll
- (void)mergeAllFolderChats {
	if (self.showsArchive || self.folderId != 0)
		return;

	NSString *sig = [NSString stringWithFormat:@"c%lu f%lu",
			(unsigned long)[TGChatListStore shared].chatsCached,
			(unsigned long)[TGChatListStore shared].folders.count];
	if (!self.mergedChats &&
			![sig isEqualToString:self.mergedSignature]) {
		// first pass, wait for the chain
	} else if ([sig isEqualToString:self.mergedSignature]) {
		// nothing new for the merge to gather
		return;
	}

	NSMutableArray *folders = [NSMutableArray arrayWithArray:
			[TGChatListStore shared].folders];
	if (!folders.count){
		self.mergedChats = nil;
		self.mergedSignature = nil;
		return;
	}

	if (self.mergeInFlight)
		return;
	self.mergeInFlight = YES;

	NSArray *base = [TGChatListStore shared].chats ?: @[];
	NSMutableArray *merged = [NSMutableArray arrayWithArray:base];
	NSMutableSet *seen = [NSMutableSet set];
	for (NSDictionary *c in merged){
		id cid = c[@"id"];
		if (cid)
			[seen addObject:[NSString stringWithFormat:@"%@", cid]];
	}

	__weak typeof(self) weakSelf = self;
	NSString *signature = sig;
	__block NSInteger pendings = 0;
	dispatch_group_t group = dispatch_group_create();
	// The asks run together: one round trip per folder at once instead of
	// a chain where each folder waits for the one before it.
	for (NSDictionary *folder in folders){
		NSInteger askId = [folder[@"id"] integerValue];
		dispatch_group_enter(group);
		[[TGChatListStore shared] chatsInFolder:askId completion:^(NSArray *chats){
			for (NSDictionary *c in chats){
				// A folder may hold archived chats too (the archive is a
				// flag, not a separate bucket from the folders); they belong
				// to the archive strip, not to All chats. Pending entries -
				// ids tdlib named in the folder but has not described yet -
				// wait for the retry below instead of joining the list.
				if ([c[@"pending"] boolValue]){
					pendings++;
					continue;
				}
				if ([c[@"archiveOrder"] longLongValue] > 0)
					continue;
				NSString *key = [NSString stringWithFormat:@"%@", c[@"id"]];
				if (key.length && ![seen containsObject:key]){
					[seen addObject:key];
					[merged addObject:c];
				}
			}
			dispatch_group_leave(group);
		}];
	}
	// The completions above all land on the main queue, so merged, seen and
	// pendings stay single-threaded. The sort runs on a background thread so
	// folder merges do not hitch the main thread.
	dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		if (!weakSelf || weakSelf.folderId != 0){
			dispatch_async(dispatch_get_main_queue(), ^{
				weakSelf.mergeInFlight = NO;
				weakSelf.mergedChats = nil;
				weakSelf.mergedSignature = nil;
			});
			return;
		}
		// Pinned first, then newest last message first: the merge
		// appended the folders after the main list, and without a sort
		// All chats read like a grab bag. Within the pinned block the
		// same date rule applies, so the order stays stable.
		NSArray *combined = [merged sortedArrayUsingComparator:
				^NSComparisonResult(NSDictionary *a, NSDictionary *b){
			BOOL pa = [a[@"isPinned"] boolValue], pb = [b[@"isPinned"] boolValue];
			if (pa != pb)
				return pa ? NSOrderedAscending : NSOrderedDescending;
			if (pa){
				// A pin keeps its slot through newer messages: the sort
				// inside the pinned block reads tdlib's position order,
				// not the message date.
				int64_t oa = [a[@"order"] longLongValue];
				int64_t ob = [b[@"order"] longLongValue];
				if (oa != ob)
					return oa > ob ? NSOrderedAscending : NSOrderedDescending;
			}
			int64_t da = [a[@"date"] longLongValue], db = [b[@"date"] longLongValue];
			if (da == db)
				return NSOrderedSame;
			return da > db ? NSOrderedAscending : NSOrderedDescending;
		}];
		dispatch_async(dispatch_get_main_queue(), ^{
			TGChatListViewController *me = weakSelf;
			if (!me || me.folderId != 0){
				me.mergeInFlight = NO;
				return;
			}
			me.mergedChats = combined;
			[me saveChatSnapshot:combined];
			// A folder answer that dropped unseen ids is not the whole
			// picture: withholding the signature makes the next pass run
			// again, and a short retry covers a silent cache (no chat
			// update will fire onChatsChanged meanwhile).
			me.mergedSignature = pendings ? nil : signature;
			me.mergeInFlight = NO;
			[me reloadTableDebounced];
			[me fetchMissingAvatars];
			if (pendings){
				[NSObject cancelPreviousPerformRequestsWithTarget:me
						selector:@selector(mergeAllFolderChats) object:nil];
				[me performSelector:@selector(mergeAllFolderChats)
							   withObject:nil afterDelay:1.0];
			}
		});
	});
}

- (void)hideHeaderAboveFrom:(CGFloat)previousHeight {
	// The user pulled the strip out themselves and left it there; parking
	// again on the next cache tick would snap it shut under their eyes.
	if (self.userRevealed)
		return;
	// reloadData does not refresh contentSize until the next layout pass;
	// measuring here reads the pre-reload size and misjudges the park. Lay
	// the table out first, then decide.
	[self.tableView layoutIfNeeded];
	NSLog(@"TGClient: park? content=%0.0f bounds=%0.0f y=%0.0f prev=%0.0f park=%0.0f rows=%lu",
			self.tableView.contentSize.height,
			self.tableView.bounds.size.height,
			self.tableView.contentOffset.y, previousHeight,
			self.parkOffset, (unsigned long)[self headerRows].count);
	if (self.tableView.contentSize.height <= self.tableView.bounds.size.height)
		return;
	CGFloat y = self.tableView.contentOffset.y;
	if (y > TGMetricHairline && fabs(y - previousHeight) > TGMetricHairline)
		return;
	self.tableView.contentOffset = CGPointMake(0, self.parkOffset);
}

- (void)releaseUpdatesWhenStill {
	if (self.tableView.isDragging || self.tableView.isDecelerating)
		return;
	[[TGChatListStore shared] setUpdatesHeld:NO];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
	if (scrollView == self.tableView){
		[self fetchMissingAvatars];
		[[TGChatListStore shared] setUpdatesHeld:NO];
	}
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
	if (scrollView == self.tableView && !decelerate){
		[self fetchMissingAvatars];
		[[TGChatListStore shared] setUpdatesHeld:NO];
	}
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	if (scrollView != self.tableView)
		return;
	if ([TGCapabilities pauseUpdatesDuringScrollWanted]){
		[[TGChatListStore shared] setUpdatesHeld:YES];
		[NSObject cancelPreviousPerformRequestsWithTarget:self
				selector:@selector(releaseUpdatesWhenStill) object:nil];
		[self performSelector:@selector(releaseUpdatesWhenStill) withObject:nil
				   afterDelay:0.25 inModes:@[ NSRunLoopCommonModes ]];
	}
	// Pulling the list down unfolds the stories; walking the list collapses
	// them again, which is the header's compact state.
	if (!self.storiesExpanded && scrollView.contentOffset.y < -TGMetricRow &&
			[self collapsedStoryRow]){
		self.storiesExpanded = YES;
		self.storiesFadePending = YES;
		[self rebuildTableHeader];
		return;
	}
	if (self.storiesExpanded && scrollView.contentOffset.y > TGMetricStoryStripRow){
		self.storiesExpanded = NO;
		self.storiesFadePending = YES;
		[self rebuildTableHeader];
		return;
	}
	[self refreshListTitleView];
}

/// Returning to the top after the archive strip has been scrolled away
/// settles on the park again - the official client hides the strip once the
/// list has been walked, and only a deliberate pull down reveals it.
- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView
					 withVelocity:(CGPoint)velocity
		  targetContentOffset:(inout CGPoint *)targetContentOffset {
	if (self.searchResults || self.showsArchive || self.folderId != 0)
		return;
	if (![[self headerRows] containsObject:@"archive"])
		return;
	CGFloat from = scrollView.contentOffset.y;
	CGFloat target = targetContentOffset->y;
	if (target < self.parkOffset - 20){
		if (from > self.parkOffset + 1){
			// walking back to the top after the strip was scrolled away:
			// settle on the park and wake up to hide it again later
			self.userRevealed = NO;
			targetContentOffset->y = self.parkOffset;
			[scrollView setContentOffset:CGPointMake(0, self.parkOffset)
								animated:YES];
		} else {
			// a deliberate pull upward from the park into the reveal zone:
			// the strip stays until the list gets walked again
			self.userRevealed = YES;
		}
	}
}

/// Saved Messages is your own chat; it is not always in the list, and every
/// client keeps a way in regardless.

@end
