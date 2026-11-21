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


// Height of the folder pill strip above the chat list (official-style tabs).


static NSString *TGChatSnapshotPath(void) {
	NSString *dir = [NSSearchPathForDirectoriesInDomains(
			NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	// The snapshot is one account's list. Slot 0 keeps the pre-accounts name
	// so an update does not discard the last list it saved; later slots get
	// their own file so switching never shows another account's rows.
	NSInteger slot = [TGChatListStore activeAccountSlot];
	NSString *name = slot > 0
			? [NSString stringWithFormat:@"chat-list-snapshot-%ld.plist", (long)slot]
			: @"chat-list-snapshot.plist";
	return [dir stringByAppendingPathComponent:name];
}

/// Only primitive fields go to the plist. chatsById also holds TDLib records
/// (permissions, action bar, background) that are not plist values and are
/// not read by a list row.
static NSDictionary *TGChatSnapshotRow(NSDictionary *chat) {
	static NSArray *keys = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		keys = @[@"id", @"title", @"date", @"text", @"previewText", @"lastAuthor",
				@"unread", @"unreadMentions", @"markedUnread", @"isMuted",
				@"isPinned", @"isOnline", @"storyRing", @"isSaved", @"lastId", @"lastOutgoing",
				@"readOutbox", @"readInbox", @"isGroup", @"isForum",
				@"isSecret", @"order", @"archiveOrder", @"supergroupId", @"draft",
				@"emojiStatusId", @"photoFileId", @"previewKind", @"previewFileId", @"previewReactionSummary", @"previewPollVotes", @"unreadReactions", @"unreadPollVotes", @"folderIds", @"lastFailed"];
	});
	NSMutableDictionary *row = [NSMutableDictionary dictionaryWithCapacity:keys.count];
	for (NSString *key in keys){
		id value = chat[key];
		if ([value isKindOfClass:NSNumber.class] || [value isKindOfClass:NSString.class] || [value isKindOfClass:NSArray.class])
			row[key] = value;
	}
	// The preview's custom emoji ranges: without them the first paint showed
	// the fallback characters and the pictures only arrived with the live list,
	// though they were already on disk. Kept only as plain numbers.
	NSArray *emoji = TGSnapshotCustomEmoji(chat[@"previewCustomEmoji"]);
	if (emoji.count)
		row[@"previewCustomEmoji"] = emoji;
	return row[@"id"] ? row : nil;
}



@implementation TGChatListViewController (TGChatListSnapshot)

#pragma mark - snapshot
- (NSArray *)loadChatSnapshot {
	NSArray *rows = [NSArray arrayWithContentsOfFile:TGChatSnapshotPath()];
	if (![rows isKindOfClass:NSArray.class])
		return @[];
	NSMutableArray *chats = [NSMutableArray arrayWithCapacity:rows.count];
	for (NSDictionary *row in rows) {
		if ([row isKindOfClass:NSDictionary.class] && row[@"id"]) {
			[chats addObject:[row mutableCopy]];
		}
	}
	return chats;
}

- (void)saveChatSnapshot:(NSArray *)chats {
	if (!chats.count)
		return;
	NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
	if (now - self.snapshotWrittenAt < 5.0)
		return;
	self.snapshotWrittenAt = now;
	NSMutableArray *rows = [NSMutableArray arrayWithCapacity:chats.count];
	for (NSDictionary *chat in chats){
		NSDictionary *row = TGChatSnapshotRow(chat);
		if (row)
			[rows addObject:row];
	}
	if (!rows.count)
		return;
	NSString *path = TGChatSnapshotPath();
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
		[rows writeToFile:path atomically:YES];
	});
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
							  duration:(NSTimeInterval)duration {
	[super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
	// The search bar and the folder pill strip are built to the width at
	// header build time; a rotated screen needs both re-measured. The pills
	// live in the sticky section header, so the table has to re-ask for it.
	[self rebuildTableHeader];
	[self.tableView reloadData];
	[self reselectActiveChatIfPad];
	// The other height changes how much the bottom inset must give.
	[self parkHeaderIfNeeded];
}


@end
