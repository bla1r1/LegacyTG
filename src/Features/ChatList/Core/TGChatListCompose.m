#import "TGCustomEmojiStore.h"
#import "TGNameWithStatus.h"
#import "TGChatListViewControllerInternal.h"
#import "TGPerf.h"
#import "TGStatusText.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGMemberAvatarStore.h"
#import "TGDateFormat.h"
#import "TGOptions.h"
#import "TGStoryViewerViewController.h"
#import "TGStoryComposerViewController.h"
#import "TGProfileViewController.h"
#import "TGPasscode.h"
#import "TGPasscodeViewController.h"
#import "TGChatListRowGeometry.h"


// Height of the folder pill strip above the chat list (official-style tabs).
static const CGFloat kFolderTabRow = TGMetricFolderTabRow;
/// The mute and pin marks on a row are drawn at this side and then fitted into
/// the smaller box the cell gives them, which is what keeps their strokes even.
static const CGFloat kRowGlyph     = 28.0f;
/// The title view's box: the name, then the connection line under it. 200 pt
/// is the chat header's width on the same 320 pt bar, so neither nav button
/// loses its target to a long folder name.
static const CGFloat kListTitleWidth  = 150.0f;
static const CGFloat kListTitleHeight = TGMetricRow;
static const CGFloat kListChevronWidth = 12.0f;
static const CGFloat kListChevronGap   = TGMetricPadTiny;
static const CGFloat kListStorySide    = 24.0f;
static const CGFloat kListStoryGap     = TGMetricPadSmall;
/// The chat-list bar controls: the Edit pill, the circled add and the blue
/// compose button. Named here because only this header stacks them.
static const CGFloat kBarEditWidth    = 66.0f;
static const CGFloat kBarEditHeight   = TGMetricSegmentedHeight;
static const CGFloat kBarRightWidth   = 92.0f;
static const CGFloat kBarControlSide  = TGMetricButtonMediumH;
static const CGFloat kBarComposeSide  = 46.0f;
static const CGFloat kBarComposeX     = 46.0f;
static const CGFloat kBarControlTop   = 5.0f;
/// The archive pill's tag, outside the folder indexes (100 + slot).
static const NSInteger kFolderArchiveTag = 1000;
/// A folder pill's side padding, its widest form and the gap to the next pill.
static const CGFloat kFolderPillPad = 26.0f;
static const CGFloat kFolderPillMax = 150.0f;
static const CGFloat kFolderPillGap = 6.0f;

/// A 3.5" screen shows six rows of 76 pt; this is two screens.
static const NSUInteger kAvatarWindowRows = 14;

/// One pill's two states. The strip rebuilds on every switch, so the old and
/// new chosen pills are repainted here after the new header is on screen.
static void TGPaintFolderPill(UIButton *pill, BOOL active) {
	TGTheme *theme = [TGTheme shared];
	if (active){
		[pill setBackgroundColor:[theme accentColour]];
		[pill setTitleColor:[theme onAccentColour] forState:UIControlStateNormal];
		pill.layer.borderWidth = TGMetricBorderNone;
	} else {
		[pill setBackgroundColor:[theme cardBackgroundColour]];
		[pill setTitleColor:[theme primaryTextColour] forState:UIControlStateNormal];
		pill.layer.borderWidth = TGMetricHairline;
		pill.layer.borderColor = [theme separatorColour].CGColor;
	}
}


static NSString *TGChatSnapshotPath(void) {
	NSString *dir = [NSSearchPathForDirectoriesInDomains(
			NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	// The snapshot is one account's list. Slot 0 keeps the pre-accounts name
	// so an update does not discard the last list it saved; later slots get
	// their own file so switching never shows another account's rows.
	NSInteger slot = [TGClient activeAccountSlot];
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
				@"isPinned", @"isOnline", @"isSaved", @"lastId", @"lastOutgoing",
				@"readOutbox", @"readInbox", @"photoFileId", @"isGroup", @"isForum",
				@"isSecret", @"order", @"archiveOrder", @"supergroupId", @"draft",
				@"emojiStatusId"];
	});
	NSMutableDictionary *row = [NSMutableDictionary dictionaryWithCapacity:keys.count];
	for (NSString *key in keys){
		id value = chat[key];
		if ([value isKindOfClass:NSNumber.class] || [value isKindOfClass:NSString.class])
			row[key] = value;
	}
	return row[@"id"] ? row : nil;
}



@implementation TGChatListViewController (TGChatListCompose)

#pragma mark - compose and links
- (void)openSavedMessages {
	int64_t chatId = [[TGClient shared] savedMessagesChatId];
	if (!chatId)
		return;
	TGChatViewController *vc = [[TGChatViewController alloc] init];
	vc.chatId = chatId;
	vc.chatTitle = @"Saved Messages";
	vc.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:vc animated:YES];
}

- (void)composeTapped {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:@[@"New Message", @"New Group", @"New Channel",
								@"Join by Invite Link"]
						title:nil
			 destructiveIndex:-1
					   inView:self.navigationController.view ?: self.view
					 onChoice:^(NSInteger index){
		TGChatListViewController *me = weakSelf;
		if (index == 2){
			// A channel is a supergroup with one voice: TDLib names both with
			// one request, and the is_channel flag is the whole difference.
			[TGAlertSheet showInput:@"New Channel"
							message:@"A channel posts to subscribers. Anyone "
									@"with the link can read; only admins write."
						placeholder:@"Channel name"
							   text:nil
							 action:@"Create"
							 inView:me.view
						 onSubmit:^(NSString *title){
				[[TGClient shared] createSupergroupNamed:title
											description:@""
											  isChannel:YES
											 completion:^(int64_t chatId){
					if (!chatId)
						return;
					TGChatViewController *vc = [[TGChatViewController alloc] init];
					vc.chatId = chatId;
					vc.chatTitle = title;
					vc.hidesBottomBarWhenPushed = YES;
					[me.navigationController pushViewController:vc animated:YES];
				}];
			}];
			return;
		}
		if (index != 3){
			TGContactsViewController *contacts = [[TGContactsViewController alloc] init];
			if (index == 1)
				contacts.picksGroupMembers = YES;
			else
				contacts.title = @"New Message";
			[me.navigationController pushViewController:contacts animated:YES];
			return;
		}
		// A link is joined from anywhere: the sheet starts from the
		// pasteboard, which is where a copied link already sits.
		[TGAlertSheet showInput:@"Join by Invite Link"
						message:nil
					placeholder:@"t.me/joinchat/… or t.me/+…"
						   text:[UIPasteboard generalPasteboard].string
						 action:@"Check"
						 inView:me.view
					   onSubmit:^(NSString *link){
			[me joinByInviteLink:link];
		}];
	}];
}

/// A pasted t.me link joined: what it is first, then the chat. The account
/// already in the chat does not join again - it only opens it.
- (void)joinByInviteLink:(NSString *)rawLink {
	NSString *link = [rawLink stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (![link hasPrefix:@"http"])
		link = [@"https://" stringByAppendingString:link];
	__weak typeof(self) weakSelf = self;

	// A folder link is a different object behind the same t.me host. It is
	// checked first and adopted, not joined: addChatFolderByInviteLink is
	// what turns it into a pill on this screen.
	if ([link rangeOfString:@"/addlist/"].location != NSNotFound){
		[[TGClient shared] checkFolderInviteLink:link completion:^(NSDictionary *folder){
			TGChatListViewController *me = weakSelf;
			if (!me)
				return;
			if (!folder){
				[TGAlertSheet showMessage:@"That folder link answers nothing."
									title:@"Folder Link" inView:me.view];
				return;
			}
			NSArray *missing = folder[@"missing"] ?: @[];
			NSString *say = [NSString stringWithFormat:@"%@ · %lu chats to add",
					folder[@"name"] ?: @"Shared folder",
					(unsigned long)missing.count];
			[TGAlertSheet showConfirm:say title:@"Folder Link" action:@"Add"
						  destructive:NO inView:me.view onConfirm:^{
				[[TGClient shared] addFolderByInviteLink:link chatIds:missing
											 completion:^(BOOL ok){
					if (!ok)
						[TGAlertSheet showMessage:@"Telegram refused that folder."
											title:@"Folder Link" inView:weakSelf.view];
				}];
			}];
		}];
		return;
	}

	[[TGClient shared] checkInviteLink:link completion:
			^(NSString *title, NSInteger members, BOOL alreadyMember){
		TGChatListViewController *me = weakSelf;
		if (!me)
			return;
		if (!title.length){
			[TGAlertSheet showMessage:@"That link answers nothing - expired, "
									  @"revoked, or mistyped."
								title:@"Invite Link" inView:me.view];
			return;
		}
		NSString *say = [NSString stringWithFormat:@"%@ · %ld members",
						 title, (long)members];
		NSString *action = alreadyMember ? @"Open Chat" : @"Join";
		[TGAlertSheet showConfirm:say
							title:@"Invite Link"
						   action:action
					  destructive:NO
						   inView:me.view
						onConfirm:^{
			TGChatListViewController *inner = weakSelf;
			[[TGClient shared] joinChatByInviteLink:link completion:^(int64_t chatId, NSString *name){
				if (!chatId){
					if (inner)
						[TGAlertSheet showMessage:@"Telegram refused the join."
											title:@"Invite Link" inView:inner.view];
					return;
				}
				dispatch_async(dispatch_get_main_queue(), ^{
					TGChatListViewController *after = weakSelf;
					if (!after)
						return;
					// The chat appears in the list with the update; it is
					// used straight out of it when it has arrived, forced
					// into the shape a joined group has when it has not.
					NSDictionary *found = nil;
					for (NSDictionary *c in [TGClient shared].chats)
						if ([c[@"id"] longLongValue] == chatId){
							found = c;
							break;
						}
					NSDictionary *c = found ?: (@{@"id" : @(chatId),
												  @"title" : (name ?: title ?: @""),
												  @"isGroup" : @YES});
					[after openChatInfo:c];
				});
			}];
		}];
	}];
}

/// A pill switch arms this before asking the folder for its chats; the answer
/// replaces the whole table, and that one swap fades. Spending the flag here
/// is what keeps the periodic reloads from crossfading the list too.

@end
