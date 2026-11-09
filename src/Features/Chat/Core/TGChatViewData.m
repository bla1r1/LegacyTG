#import "TGPerf.h"
#import "TGLocalization.h"
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
#import "TGLocalization.h"
#import "TGChatParityModel.h"
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
#import "TGPeerStore.h"
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
static const NSInteger kChatUnblockBarTag = 0x9025;
static const NSInteger kChatJoinChannelBarTag = 0x9022;
static const NSInteger kChatDiscussBarTag = 0x9023;
static const NSInteger kChatChannelBottomBarTag = 0x9024;

#pragma mark - controller


@implementation TGChatViewController (TGChatViewData)

#pragma mark - data

- (void)readOutboxChanged:(NSNotification *)note {
	if ([note.userInfo[@"chatId"] longLongValue] == self.chatId)
		[self reloadTableDebounced];
}

/// updateStopMessageDraft names the chat, topic and draft. The composer only
/// clears when it still holds the text the client had cached: a stop must not
/// wipe words typed after it. The table reloads either way, because the
/// message being streamed may have changed too.
- (void)customEmojiLoaded:(NSNotification *)note {
	// A screenful of emoji lands as a burst: one redraw for all of it.
	[NSObject cancelPreviousPerformRequestsWithTarget:self
			selector:@selector(redrawVisibleRows) object:nil];
	[self performSelector:@selector(redrawVisibleRows) withObject:nil afterDelay:0.15];
}

- (void)redrawVisibleRows {
	NSArray *visible = [self.table indexPathsForVisibleRows];
	if (visible.count)
		[self.table reloadRowsAtIndexPaths:visible withRowAnimation:UITableViewRowAnimationNone];
}

- (void)draftStopped:(NSNotification *)note {
	NSDictionary *info = note.userInfo;
	if ([info[@"chat_id"] longLongValue] != self.chatId)
		return;
	int64_t topicId = [info[@"forum_topic_id"] longLongValue];
	if (topicId && topicId != self.threadId)
		return;
	NSString *draft = info[@"draft_text"];
	if ([draft isKindOfClass:NSString.class] && draft.length &&
			[self.input.text isEqualToString:draft]){
		self.input.text = @"";
		[self inputChanged];
	}
	[self reloadTableDebounced];
}

/// updateVideoPublished says which message gained the video. The history is
/// re-read rather than patched, because the message's kind and its file both
/// changed; the chat list is nudged by the client on the same update.
- (void)videoPublished:(NSNotification *)note {
	if ([note.userInfo[@"chat_id"] longLongValue] != self.chatId)
		return;
	[self reload];
	[TGSnackbar showInView:self.view text:@"Video published" seconds:2 onCommit:nil];
}

- (void)reloadTableDebounced {
	[NSObject cancelPreviousPerformRequestsWithTarget:self.table selector:@selector(reloadData) object:nil];
	[self.table performSelector:@selector(reloadData) withObject:nil afterDelay:0.05];
}

- (NSDictionary *)compositeAlbumMessageFromMessages:(NSArray *)albumMsgs {
	if (!albumMsgs.count) return @{};
	NSDictionary *lead = albumMsgs.firstObject;
	NSMutableDictionary *comp = [lead mutableCopy];
	comp[@"isAlbum"] = @(YES);
	comp[@"albumMessages"] = albumMsgs;
	comp[@"albumCount"] = @(albumMsgs.count);

	comp[@"caption"] = @"";
	for (NSDictionary *sub in albumMsgs) {
		NSString *cap = sub[@"caption"];
		if ([cap length]) {
			comp[@"caption"] = cap;
			comp[@"text"] = cap;
			comp[@"entities"] = sub[@"entities"] ?: @[];
			break;
		}
	}
	if (![comp[@"caption"] length]) {
		for (NSDictionary *sub in albumMsgs) {
			NSString *t = sub[@"text"];
			NSString *docName = sub[@"docName"];
			if (t.length && (docName.length == 0 || ![t hasPrefix:docName])) {
				comp[@"caption"] = t;
				comp[@"text"] = t;
				comp[@"entities"] = sub[@"entities"] ?: @[];
				break;
			}
		}
	}
	return comp;
}

- (NSArray *)groupedMessagesFromMessages:(NSArray *)rawMessages {
	if (!rawMessages.count) return @[];
	NSMutableArray *grouped = [NSMutableArray arrayWithCapacity:rawMessages.count];
	NSMutableArray *currentAlbum = nil;
	NSString *currentAlbumId = nil;

	for (NSDictionary *m in rawMessages) {
		NSString *albumId = m[@"albumId"];
		NSString *kind = m[@"kind"];
		BOOL isAlbumCandidate = [kind isEqualToString:@"messagePhoto"] ||
								[kind isEqualToString:@"messageVideo"] ||
								[kind isEqualToString:@"messageAnimation"] ||
								[kind isEqualToString:@"messageDocument"];
		BOOL hasAlbum = (albumId.length > 0 && ![albumId isEqualToString:@"0"] && isAlbumCandidate);

		if (hasAlbum) {
			if (currentAlbum && [currentAlbumId isEqualToString:albumId] &&
				[currentAlbum.firstObject[@"kind"] isEqualToString:kind]) {
				[currentAlbum addObject:m];
				continue;
			} else {
				if (currentAlbum.count > 1) {
					[grouped addObject:[self compositeAlbumMessageFromMessages:currentAlbum]];
				} else if (currentAlbum.count == 1) {
					[grouped addObject:currentAlbum.firstObject];
				}
				currentAlbum = [NSMutableArray arrayWithObject:m];
				currentAlbumId = albumId;
				continue;
			}
		}

		if (currentAlbum) {
			if (currentAlbum.count > 1) {
				[grouped addObject:[self compositeAlbumMessageFromMessages:currentAlbum]];
			} else if (currentAlbum.count == 1) {
				[grouped addObject:currentAlbum.firstObject];
			}
			currentAlbum = nil;
			currentAlbumId = nil;
		}

		[grouped addObject:m];
	}

	if (currentAlbum) {
		if (currentAlbum.count > 1) {
			[grouped addObject:[self compositeAlbumMessageFromMessages:currentAlbum]];
		} else if (currentAlbum.count == 1) {
			[grouped addObject:currentAlbum.firstObject];
		}
	}

	return [self messagesWithSeparators:grouped];
}

- (void)reload {
#if TG_DEV
	if (TGIsDevChat(self.chatId)) {
		double fixtureStart = TGPerfNow();
		NSArray *messages = [TGDevShowcase messagesForChatId:self.chatId];
		TGPerfReport("chat dev", "fixtures", fixtureStart, 50.0);
		[self noteFirstUnreadIn:messages];
		NSArray *oldRaw = self.rawMessages ?: @[];
		[self.streamStore resetWithMessages:messages];
		self.rawMessages = [self.streamStore messages];
		self.messages = [self groupedMessagesFromMessages:self.rawMessages];
		double buildStart = TGPerfNow();
		TGPerfReport("chat dev", "grouping", buildStart, 50.0);
		self.atChatEnd = YES;
		self.anchorToBottom = NO;

		NSString *tgsPath = [TGDevShowcase devStickerPath];
		NSString *webmPath = [TGDevShowcase devWebMPath];
		if (tgsPath) self.lottiePaths[@(-101)] = tgsPath;
		if (webmPath) self.lottiePaths[@(-102)] = webmPath;

		// iOS 6 asks this delegate for the height of every row during
		// reloadData, so the layout of the whole chat runs synchronously
		// here - the "outed" tap on this tier. The chip names it exact.
		double tableStart = TGPerfNow();
		for (NSNumber *messageId in TGChangedMessageIds(oldRaw, self.rawMessages))
			[self.layoutCache removeLayoutForMessageId:messageId.longLongValue];
		[self.table reloadData];
		TGPerfReport("chat table", "layouts during reload", tableStart, 150.0);
		[self refreshActionBar];
		[self updateTitleEmojiStatus];
		return;
	}
#endif

	__weak typeof(self) weakSelf = self;
	double chatStart = TGPerfNow();
	[[TGClient shared] historyForChat:self.chatId thread:self.threadId limit:60 completion:^(NSArray *messages){
		TGChatViewController *me = weakSelf;
		if (!me)
			return;
		TGPerfReport("chat load", "history wait", chatStart, 300.0);
		BOOL firstLoad = !me.unreadChecked;
		[me noteFirstUnreadIn:messages];
		NSArray *oldRaw = me.rawMessages ?: @[];
		[me.streamStore resetWithMessages:messages];
		me.rawMessages = [me.streamStore messages];
		me.messages = [me groupedMessagesFromMessages:me.rawMessages];
		me.atChatEnd = YES;
		NSInteger unreadRow = firstLoad ? [me unreadSeparatorRow] : NSNotFound;
		// hold the bottom until the media has settled - unless the chat opens
		// at what you have not read yet
		// Opened on one message, the pin would pull the table away from it.
		me.anchorToBottom = unreadRow == NSNotFound && !me.initialMessageId;
		if (me.anchorToBottom)
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6.0 * NSEC_PER_SEC)),
					dispatch_get_main_queue(), ^{ me.anchorToBottom = NO; });
		// kinds only - the content is the user's, the log is read remotely
		NSMutableArray *kinds = [NSMutableArray array];
		for (NSDictionary *m in messages)
			[kinds addObject:m[@"kind"] ?: @"?"];
		NSLog(@"TDLIB HISTORY: %lu msgs: %@",
				(unsigned long)messages.count, [kinds componentsJoinedByString:@", "]);
		// The layout of thirty visible rows is what a first paint on the A4
		// really pays for; the network wait is logged on its own.
		double tableStart = TGPerfNow();
		for (NSNumber *messageId in TGChangedMessageIds(oldRaw, me.rawMessages))
			[me.layoutCache removeLayoutForMessageId:messageId.longLongValue];
		[me.table reloadData];
		TGPerfReport("chat table", "reloadData", tableStart, 100.0);
		[me refreshActionBar];
		[me updateTitleEmojiStatus];
		if (me.initialMessageId){
			// Opened by a link to one message: the unread separator and the
			// bottom both lose to the message the tap was about.
			int64_t target = me.initialMessageId;
			me.initialMessageId = 0;
			[me showMessageId:target gone:@"Message Deleted."];
			[me fetchMissingImages];
			[me resolveUnknownSenders];
			return;
		}
		if (unreadRow != NSNotFound)
			[me.table scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:unreadRow inSection:0]
							atScrollPosition:UITableViewScrollPositionTop animated:NO];
		else
			[me scrollToBottomAnimated:NO];
		[me fetchMissingImages];
		[me resolveUnknownSenders];
		[me fetchMissingQuotes];

		NSMutableArray *ids = [NSMutableArray array];
		for (NSDictionary *m in messages)
			[ids addObject:m[@"id"]];
		[[TGClient shared] markRead:ids inChat:me.chatId];
	}];
}

- (void)scrollToBottomAnimated:(BOOL)animated {
	if (!self.messages.count)
		return;
	NSIndexPath *last = [NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0];
	[self.table scrollToRowAtIndexPath:last
					  atScrollPosition:UITableViewScrollPositionBottom animated:animated];
}

/// Telegram puts the chat's picture top right, and it opens the profile.
- (void)buildAvatarButton {
	// 42dp in their header, which is 37 here and still clears a 44pt bar.
	CGFloat side = 37;
	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	button.frame = CGRectMake(0, 0, side, side);
	// No clip: the nav bar is recomposited on every frame of a scroll, and a
	// rounded clip there is an offscreen pass each time. The images below are
	// round already.
	[button addTarget:self action:@selector(openProfile)
	 forControlEvents:UIControlEventTouchUpInside];
	// Holding the avatar offers Open Profile, Statistics and Search.
	UILongPressGestureRecognizer *avatarHold = [[UILongPressGestureRecognizer alloc]
			initWithTarget:self action:@selector(headerHeld:)];
	avatarHold.minimumPressDuration = 0.5;
	[button addGestureRecognizer:avatarHold];

	NSString *title = self.chatTitle ?: @"";
	BOOL isSaved = (self.chatId == [[TGClient shared] savedMessagesChatId]);
	TGPeer *peer = isSaved ? nil : [[TGPeerStore shared] peerForId:self.chatId];
	if (!title.length && peer.title.length)
		title = peer.title;
	NSString *initials = peer.initials.length ? peer.initials
			: [TGIcons initialsForTitle:title];
	[button setImage:(isSaved
			? [TGIcons savedMessagesAvatarOfSide:side]
			: [TGIcons avatarWithInitials:initials size:side colourId:self.chatId])
			forState:UIControlStateNormal];

	self.navigationItem.rightBarButtonItem =
			[[UIBarButtonItem alloc] initWithCustomView:button];

	// Your own peer and a forum get a second right item: search is reachable
	// from the bar, not only from the title hold.
	int64_t selfUserId = [[TGClient shared].me[@"id"] longLongValue];
	BOOL ownPeer = selfUserId != 0 && self.chatId == selfUserId;
	BOOL forum = NO;
	for (NSDictionary *row in [TGClient shared].chats){
		if ([row[@"id"] longLongValue] == self.chatId){
			forum = [row[@"isForum"] boolValue];
			break;
		}
	}
	if (ownPeer || forum){
		UIButton *search = [UIButton buttonWithType:UIButtonTypeCustom];
		search.frame = CGRectMake(0, 0, TGMetricRow, TGMetricRow);
		[search setImage:[TGIcons glyphNamed:@"search"
									  colour:[[TGTheme shared] barButtonColour]
										side:TGMetricMenuGlyph]
				forState:UIControlStateNormal];
		[search addTarget:self action:@selector(toggleChatSearch)
		 forControlEvents:UIControlEventTouchUpInside];
		search.accessibilityLabel = TGLocalized(@"Search");
		UIBarButtonItem *searchItem = [[UIBarButtonItem alloc]
				initWithCustomView:search];
		self.navigationItem.rightBarButtonItems =
				@[[[UIBarButtonItem alloc] initWithCustomView:button], searchItem];
	}

	// Your own photo is not what Saved Messages is known by; the bookmark set
	// above stays.
	if (isSaved)
		return;

	UIImage *cached = [[TGPeerStore shared] cachedAvatarForPeer:self.chatId
														   side:side];
	if (cached){
		[button setImage:cached forState:UIControlStateNormal];
		return;
	}
	[[TGPeerStore shared] loadAvatarForPeer:self.chatId side:side
								 completion:^(UIImage *photo){
		if (photo)
			[button setImage:photo forState:UIControlStateNormal];
	}];
}

- (void)openProfile {
	// A private chat id is the user id, which is what the profile needs to
	// look up a photo and a phone number; a group has no single user.
	int64_t userId = (self.isGroup || self.chatId < 0) ? 0 : self.chatId;
	TGProfileViewController *profile = [[TGProfileViewController alloc]
			initWithChatId:self.chatId userId:userId title:self.chatTitle];
	__weak typeof(self) weakSelf = self;
	profile.onSearchTapped = ^{
		[weakSelf.navigationController popViewControllerAnimated:YES];
		[weakSelf toggleChatSearch];
	};
	profile.onJumpToDateTapped = ^{
		[weakSelf.navigationController popViewControllerAnimated:YES];
		[weakSelf showJumpToDateSheet];
	};
	[self.navigationController pushViewController:profile animated:YES];
}

/// Asks for the chat's real kind before drawing the header and the composer.
/// Until the answer lands the subtitle stays empty; a presence line or a Mute
/// button for a channel you never joined is worse than no line at all.
/// The last answer per chat, for this run: reopening a channel draws its bar
/// and subtitle at once instead of after the round trip.
static NSMutableDictionary *TGChatCanSendMemo(void) {
	static NSMutableDictionary *memo;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ memo = [NSMutableDictionary dictionary]; });
	return memo;
}

static NSMutableDictionary *TGChatKindMemo(void) {
	static NSMutableDictionary *memo;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ memo = [NSMutableDictionary dictionary]; });
	return memo;
}

static NSMutableDictionary *TGChatProfileMemo(void) {
	static NSMutableDictionary *memo;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ memo = [NSMutableDictionary dictionary]; });
	return memo;
}

- (void)loadChatKindAndChrome {
	// getChat + getSupergroup can wait seconds behind a history load, and a
	// channel looked like a plain chat until then. Draw what is already
	// known - the last answer, or the chat list row (a listed channel is one
	// you follow) - and let the answer correct it.
	NSDictionary *profileMemo = TGChatProfileMemo()[@(self.chatId)];
	if (profileMemo){
		self.linkedChatId = [profileMemo[@"linkedChatId"] longLongValue];
		self.directMessagesChatId = [profileMemo[@"directMessagesChatId"] longLongValue];
		self.hasDirectMessages = [profileMemo[@"hasDirectMessages"] boolValue];
		self.canManageDirectMessages = [profileMemo[@"canManageDirectMessages"] boolValue];
	}
	NSDictionary *known = TGChatKindMemo()[@(self.chatId)];
	if (!known){
		for (NSDictionary *row in [TGClient shared].chats){
			if ([row[@"id"] longLongValue] == self.chatId){
				if ([row[@"isGroup"] boolValue])
					known = @{@"isGroup" : @YES, @"isMember" : @YES,
							  @"isChannel" : @([row[@"isChannel"] boolValue])};
				break;
			}
		}
	}
	if ([known[@"isGroup"] boolValue]){
		BOOL isChannel = [known[@"isChannel"] boolValue];
		BOOL isMember = [known[@"isMember"] boolValue];
		self.isChannel = isChannel;
		self.isChannelMember = isMember;
		if (!self.isGroup){
			self.isGroup = YES;
			[self.table reloadData];
		}
		NSInteger count = [known[@"memberCount"] integerValue];
		if (count > 0){
			self.restingSubtitle = isChannel
					? TGLocalizedPlural(@"%d subscriber", @"%d subscribers", count)
					: TGLocalizedPlural(@"%d member", @"%d members", count);
			[self titleSubtitleOwnerChanged:nil];
		}
		[self applyPostingRightsForGroup:YES channel:isChannel member:isMember];
	}
	__weak typeof(self) weakSelf = self;
	int64_t memoChatId = self.chatId;
	[[TGClient shared] chatKindForChat:self.chatId completion:^(NSDictionary *kind){
		TGChatViewController *me = weakSelf;
		if (kind)
			TGChatKindMemo()[@(memoChatId)] = kind;
		if (!me || !kind)
			return;

		BOOL isGroup = [kind[@"isGroup"] boolValue];
		BOOL isChannel = [kind[@"isChannel"] boolValue];
		BOOL isMember = [kind[@"isMember"] boolValue];
		me.isChannel = isChannel;
		me.isChannelMember = isMember;
		me.silentPosting = [kind[@"silent"] boolValue];
		me.canBeAnonymous = [kind[@"canBeAnonymous"] boolValue];
		NSInteger count = [kind[@"memberCount"] integerValue];
		// A chat opened from a profile came in as private, and the rows laid out so
		// far took no sender line or group spacing.
		if (me.isGroup != isGroup){
			me.isGroup = isGroup;
			[me.table reloadData];
		}

		if (!isGroup){
			[[TGPeerStore shared] refreshPeerForId:me.chatId completion:^(TGPeer *peer){
				TGChatViewController *again = weakSelf;
				if (!again || !peer.lastSeenText.length)
					return;
				again.restingSubtitle = peer.lastSeenText;
				[again titleSubtitleOwnerChanged:nil];
			}];
		} else if (count > 0){
			NSString *members = isChannel
					? TGLocalizedPlural(@"%d subscriber", @"%d subscribers", count)
					: TGLocalizedPlural(@"%d member", @"%d members", count);
			NSInteger onlineCount = 0;
			for (NSDictionary *row in [TGClient shared].chats){
				if ([row[@"id"] longLongValue] == me.chatId){
					onlineCount = [row[@"onlineMembers"] integerValue];
					break;
				}
			}
			if (!isChannel && onlineCount > 1){
				NSString *online = TGLocalizedFormat(@"%@ online", @(onlineCount));
				me.restingSubtitle = TGLocalizedFormat(@"%@, %@", members, online);
			} else {
				me.restingSubtitle = members;
			}
			[me titleSubtitleOwnerChanged:nil];
		}

		[me applyPostingRightsForGroup:isGroup channel:isChannel member:isMember];

		if (isChannel){
			[[TGClient shared] chatProfile:me.chatId completion:^(NSDictionary *info){
				TGChatViewController *again = weakSelf;
				if (!again || !info) return;
				TGChatProfileMemo()[@(again.chatId)] = info;
				int64_t linked = [info[@"linkedChatId"] longLongValue];
				again.linkedChatId = linked;
				again.directMessagesChatId = [info[@"directMessagesChatId"] longLongValue];
				again.hasDirectMessages = [info[@"hasDirectMessages"] boolValue];
				again.canManageDirectMessages = [info[@"canManageDirectMessages"] boolValue];
				[again applyPostingRightsForGroup:YES channel:YES member:isMember];
			}];
		}
	}];
}

/// The bottom bar is one of three: the composer, the channel bottom bar for
/// a channel you follow or have not joined, or Join for a group you have
/// not joined. A joined group always gets the composer back, even if posting
/// is restricted.
- (void)applyPostingRightsForGroup:(BOOL)isGroup
						  channel:(BOOL)isChannel
						   member:(BOOL)isMember {
	self.isChannel = isChannel;
	self.isChannelMember = isMember;
	[self updateComposerPlaceholder];
	[self removeComposerStandIn];
	self.input.enabled = YES;
	self.sendButton.enabled = YES;

	if (isGroup && !isMember){
		if (isChannel){
			[self showChannelBottomBar];
		} else {
			[self showComposerStandIn:@"Join Group"
							   action:@selector(joinFromChat:)
								  tag:kChatJoinGroupBarTag];
		}
		return;
	}

	if (isGroup && !isChannel){
		self.inputBar.hidden = NO;
		return;
	}

	// A channel you follow has no composer unless you may post in it; the
	// same answer decides a private chat's bottom, as before. The answer
	// queues behind the history load, so a channel shows its bar at once -
	// or the composer, if the last answer this run said you may post - and
	// the answer only swaps it.
	NSNumber *couldSend = TGChatCanSendMemo()[@(self.chatId)];
	if (isChannel){
		if ([couldSend boolValue])
			self.inputBar.hidden = NO;
		else
			[self showChannelBottomBar];
	}
	__weak typeof(self) weakSelf = self;
	int64_t memoChatId = self.chatId;
	[[TGClient shared] canSendInChat:self.chatId completion:^(BOOL canSend, BOOL channel){
		TGChatCanSendMemo()[@(memoChatId)] = @(canSend);
		TGChatViewController *me = weakSelf;
		if (!me)
			return;
		if (canSend){
			[me removeComposerStandIn];
			me.inputBar.hidden = NO;
			return;
		}
		if (channel){
			[me showChannelBottomBar];
			return;
		}
		// An unwritable private chat is blocked or restricted, not muted.
		[[TGClient shared] isUserBlocked:me.chatId completion:^(BOOL blocked){
			TGChatViewController *again = weakSelf;
			if (!again)
				return;
			if (blocked){
				[again showComposerStandIn:TGLocalized(@"Unblock")
								   action:@selector(unblockFromChat:)
									  tag:kChatUnblockBarTag];
			} else {
				// Restricted rather than blocked: there is no Unblock to
				// offer, but an empty strip explains nothing. Keep the field
				// where it is, disabled, so the bottom still says this is a
				// chat with a composer that the server will not take.
				again.inputBar.hidden = NO;
				again.input.enabled = NO;
				again.sendButton.enabled = NO;
				again.input.placeholder = TGLocalized(@"Message");
			}
		}];
	}];
}

/// A channel's bottom bar: one solid strip like the composer it replaces,
/// with plain UIKit-style buttons - icons on the left for Direct Messages and
/// the discussion, the mute toggle (or Join Channel) as a word in the middle,
/// search on the right. The idea is official's; the look is this app's.
- (void)showChannelBottomBar {
	self.inputBar.hidden = YES;
	[self removeComposerStandIn];

	CGRect barFrame = self.inputBar.frame;
	TGTheme *theme = [TGTheme shared];

	UIView *container = [[UIView alloc] initWithFrame:barFrame];
	container.tag = kChatChannelBottomBarTag;
	container.backgroundColor = [theme inputBarColour];
	container.autoresizingMask = UIViewAutoresizingFlexibleWidth |
								 UIViewAutoresizingFlexibleTopMargin;

	UIView *hair = [[UIView alloc] initWithFrame:CGRectMake(0, 0, barFrame.size.width,
															TGMetricBorderWidth)];
	hair.backgroundColor = [theme separatorColour];
	hair.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[container addSubview:hair];

	CGFloat side = barFrame.size.height;
	UIButton *(^iconButton)(NSString *, SEL, CGFloat) = ^UIButton *(NSString *glyph, SEL action, CGFloat x){
		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		button.frame = CGRectMake(x, 0, side, side);
		button.showsTouchWhenHighlighted = YES;
		[button setImage:[TGIcons glyphNamed:glyph colour:[theme accentColour] side:kChannelBarIconSide]
				forState:UIControlStateNormal];
		[button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
		[container addSubview:button];
		return button;
	};

	// Channel and supergroup chat ids are negative: "present" is non-zero.
	CGFloat leftW = 0;
	// "chats" is not a glyph TGIcons draws; it fell back to a bare disc.
	// Direct messages get the compose pen (official's suggest-post icon),
	// the discussion the speech bubble.
	if (self.directMessagesChatId != 0){
		iconButton(@"compose", @selector(directMessagesFromChat:), leftW);
		leftW += side;
	}
	if (self.linkedChatId != 0){
		UIButton *discuss = iconButton(@"chat", @selector(discussFromChat:), leftW);
		discuss.tag = kChatDiscussBarTag;
		leftW += side;
	}
	UIButton *search = iconButton(@"search", @selector(toggleChatSearch), barFrame.size.width - side);
	search.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;

	// The word sits in the middle of the bar whatever stands at either end.
	CGFloat inset = MAX(leftW, side);
	UIButton *centre = [UIButton buttonWithType:UIButtonTypeCustom];
	centre.frame = CGRectMake(inset, 0, barFrame.size.width - TGDoubled(inset), side);
	centre.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	centre.titleLabel.font = TGFontBody();
	[centre setTitleColor:[theme accentColour] forState:UIControlStateNormal];
	[centre setTitleColor:[theme secondaryTextColour] forState:UIControlStateHighlighted];
	if (!self.isChannelMember){
		centre.tag = kChatJoinChannelBarTag;
		[centre setTitle:@"Join Channel" forState:UIControlStateNormal];
		[centre addTarget:self action:@selector(joinFromChat:) forControlEvents:UIControlEventTouchUpInside];
	} else {
		centre.tag = kChatMuteBarTag;
		BOOL muted = [[TGClient shared] isChatMuted:self.chatId];
		[centre setTitle:TGChatChannelMuteTitle(muted) forState:UIControlStateNormal];
		[centre addTarget:self action:@selector(muteFromChat:) forControlEvents:UIControlEventTouchUpInside];
	}
	[container addSubview:centre];
	[self.view addSubview:container];
}

- (void)directMessagesFromChat:(UIButton *)sender {
	// The direct-messages group is a supergroup: its chat id is negative.
	int64_t targetId = self.directMessagesChatId;
	if (targetId == 0)
		return;

	if (self.canManageDirectMessages){
		TGDMTopicsViewController *topics = [[TGDMTopicsViewController alloc] init];
		topics.chatId = targetId;
		topics.chatTitle = self.chatTitle.length ? self.chatTitle : @"Channel";
		topics.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:topics animated:YES];
	} else {
		TGChatViewController *chat = [[TGChatViewController alloc] init];
		chat.chatId = targetId;
		chat.chatTitle = self.chatTitle.length ? self.chatTitle : TGLocalized(@"Direct Messages");
		chat.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:chat animated:YES];
	}
}

- (void)docRowTapped:(UIButton *)sender {
	UIView *view = sender;
	while (view && ![view isKindOfClass:TGBubbleCell.class])
		view = view.superview;
	TGBubbleCell *cell = (TGBubbleCell *)view;
	if (!cell || !cell.docMessageId)
		return;

	NSInteger index = sender.tag - 0x9200;
	NSDictionary *message = nil;
	for (NSDictionary *candidate in self.messages){
		if ([candidate[@"id"] longLongValue] == cell.docMessageId){
			message = candidate;
			break;
		}
	}
	if (!message) return;
	NSArray *docs = [message[@"isAlbum"] boolValue] && [message[@"albumMessages"] isKindOfClass:NSArray.class]
			? message[@"albumMessages"] : @[message];
	NSDictionary *doc = (index >= 0 && index < (NSInteger)docs.count) ? docs[(NSUInteger)index] : message;
	[self downloadAndPresentDocument:doc fromCell:cell];
}

- (void)discussFromChat:(UIButton *)sender {
	if (self.linkedChatId == 0) return;
	TGChatViewController *chat = [[TGChatViewController alloc] init];
	chat.chatId = self.linkedChatId;
	chat.chatTitle = @"Discussion";
	chat.isGroup = YES;
	chat.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:chat animated:YES];
}

- (void)showComposerStandIn:(NSString *)title action:(SEL)action tag:(NSInteger)tag {
	self.inputBar.hidden = YES;
	UIButton *bar = [UIButton buttonWithType:UIButtonTypeCustom];
	bar.frame = self.inputBar.frame;
	bar.tag = tag;
	bar.backgroundColor = [[TGTheme shared] inputBarColour];
	bar.autoresizingMask = UIViewAutoresizingFlexibleWidth |
						   UIViewAutoresizingFlexibleTopMargin;
	[bar setTitleColor:[[TGTheme shared] accentColour] forState:UIControlStateNormal];
	bar.titleLabel.font = TGFontBody();
	[bar setTitle:title forState:UIControlStateNormal];
	[bar addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:bar];
}

- (void)removeComposerStandIn {
	[[self.view viewWithTag:kChatChannelBottomBarTag] removeFromSuperview];
	[[self.view viewWithTag:kChatMuteBarTag] removeFromSuperview];
	[[self.view viewWithTag:kChatUnblockBarTag] removeFromSuperview];
	[[self.view viewWithTag:kChatDiscussBarTag] removeFromSuperview];
	[[self.view viewWithTag:kChatJoinGroupBarTag] removeFromSuperview];
	[[self.view viewWithTag:kChatJoinChannelBarTag] removeFromSuperview];
}

/// Nothing is sent until the tap. A successful join turns the bar into what
/// the chat now offers: Mute for a channel, the composer for a group.
- (void)joinFromChat:(UIButton *)button {
	BOOL isChannel = button.tag == kChatJoinChannelBarTag;
	button.enabled = NO;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] joinChat:self.chatId completion:^(BOOL ok, BOOL requestSent){
		TGChatViewController *me = weakSelf;
		if (!me)
			return;
		if (!ok){
			button.enabled = !requestSent;
			[TGSnackbar showInView:me.view
							  text:(requestSent ? @"Join request sent"
												: @"Telegram did not let you join")
						   seconds:2 onCommit:nil];
			return;
		}
		me.isGroup = YES;
		me.isChannelMember = YES;
		[me applyPostingRightsForGroup:YES channel:isChannel member:YES];
	}];
}

- (void)unblockFromChat:(UIButton *)button {
	button.enabled = NO;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setUser:self.chatId blocked:NO];
	[weakSelf applyPostingRightsForGroup:weakSelf.isGroup
								channel:weakSelf.isChannel member:YES];
}

- (void)muteFromChat:(UIButton *)button {
	// The state, not the button's English title: a translated title never
	// started with "Mute", so the bar could only ever unmute.
	BOOL muting = ![[TGClient shared] isChatMuted:self.chatId];
	[[TGClient shared] setChat:self.chatId muted:muting];
	[button setTitle:TGChatChannelMuteTitle(muting) forState:UIControlStateNormal];
}

/// YES when this message continues the album the one before it started.
- (BOOL)continuesAlbumAtRow:(NSInteger)row {
	NSString *album = self.messages[row][@"albumId"];
	if (!album.length || [album isEqualToString:@"0"] || row == 0)
		return NO;
	return [self.messages[row - 1][@"albumId"] isEqualToString:album];
}

/// YES when the next message belongs to the same album, so this one should not
/// carry the timestamp - only the last of a block does.
- (BOOL)albumContinuesAfterRow:(NSInteger)row {
	NSString *album = self.messages[row][@"albumId"];
	if (!album.length || [album isEqualToString:@"0"] ||
		row + 1 >= (NSInteger)self.messages.count)
		return NO;
	return [self.messages[row + 1][@"albumId"] isEqualToString:album];
}

/// The pinned message, which may be far above whatever the chat has loaded.
- (void)pinnedBannerTapped {
	if (self.pinnedMessageId)
		[self showMessageId:self.pinnedMessageId gone:@"Message Deleted."];
}

/// Scrolls to a message; when it is outside the loaded window the history is
/// fetched around it, replacing what was on screen the way following a reply
/// upwards does, and the scroll is tried again. `gone` is said if even that
/// does not find it.
- (void)showMessageId:(int64_t)messageId gone:(NSString *)gone {
	if ([self scrollToMessageId:messageId])
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] historyForChat:self.chatId
					   aroundMessageId:messageId
								 limit:(NSInteger)TGMetricHistoryPageAroundPinned
							completion:^(NSArray *messages){
		TGChatViewController *me = weakSelf;
		if (!me || !messages.count)
			return;
		[me.streamStore resetWithMessages:messages];
		me.rawMessages = [me.streamStore messages];
		me.messages = [me groupedMessagesFromMessages:me.rawMessages];
		me.atChatEnd = NO;
		me.atChatStart = NO;
		[me.table reloadData];
		if (![me scrollToMessageId:messageId])
			[TGSnackbar showInView:me.view text:gone seconds:2 onCommit:nil];
	}];
}

/// Holding the strip offers the one thing a tap cannot: taking every pinned
/// message down at once.
- (void)pinnedBannerHeld:(UILongPressGestureRecognizer *)hold {
	if (hold.state != UIGestureRecognizerStateBegan)
		return;
	int64_t chatId = self.chatId, threadId = self.threadId;
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:nil
						title:@"Unpin All Messages"
					   action:@"Unpin All Messages"
				  destructive:YES
					   inView:self.view
					onConfirm:^{
		[[TGClient shared] unpinAllMessagesInChat:chatId thread:threadId];
		weakSelf.pinnedMessageId = 0;
		[weakSelf hidePinnedBanner];
	}];
}

/// A day to go to: the last message sent on or before the end of it.
- (void)showJumpToDateSheet {
	TGSheet *sheet = [TGSheet sheetForView:self.view.window ?: self.view];
	UIView *card = [sheet addCardOfHeight:TGMetricRow * 2 + TGMetricPickerHeight edgeToEdge:YES];
	UIDatePicker *picker = [[UIDatePicker alloc] initWithFrame:
			CGRectMake(0, TGMetricRow, card.bounds.size.width, TGMetricPickerHeight)];
	picker.datePickerMode = UIDatePickerModeDate;
	picker.maximumDate = [NSDate date];
	[card addSubview:picker];
	UIToolbar *bar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, card.bounds.size.width, TGMetricRow)];
	bar.items = @[
		[[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain
				target:sheet action:@selector(dismiss)],
		[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
				target:nil action:nil],
		[[UIBarButtonItem alloc] initWithTitle:@"Go" style:UIBarButtonItemStyleDone
				target:self action:@selector(jumpToDateCommit:)],
	];
	UILabel *countLabel = [[UILabel alloc] initWithFrame:CGRectMake(
			TGMetricPad, TGMetricRow + TGMetricPickerHeight - TGMetricPad,
			card.bounds.size.width - TGMetricPad - TGMetricPad, TGMetricRow)];
	countLabel.font = TGFontCaption();
	countLabel.textColor = [[TGTheme shared] secondaryTextColour];
	countLabel.text = @"counting...";
	[card addSubview:countLabel];
	self.pickCountLabel = countLabel;
	self.pickPicker = picker;
	self.pickSheet = sheet;
	[sheet present];

	// The one number the sheet never knew: how big this chat carries. A
	// folder applies its own answer, so the chat itself is asked.
	NSString *line = self.chatTitle ?: @"This chat";
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] messageCountInChat:self.chatId thread:self.threadId
			completion:^(NSInteger count){
		NSString *say = count > 0
				? [NSString stringWithFormat:@"%@: %ld messages total",
								   line, (long)count]
				: [NSString stringWithFormat:@"%@: no server answer", line];
		TGChatViewController *me = weakSelf ? weakSelf : nil;
		if (!me || !me.pickCountLabel)
			return;
		me.pickCountLabel.text = say;
	}];
}

- (void)jumpToDateCommit:(UIBarButtonItem *)sender {
	NSDate *day = self.pickPicker.date;
	[self.pickSheet dismiss];
	self.pickSheet = nil;
	self.pickPicker = nil;
	// End of the chosen day in local time: "the 3rd" includes its evening.
	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDateComponents *c = [calendar components:NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit
									  fromDate:day];
	c.hour = 23; c.minute = 59; c.second = 59;
	NSTimeInterval end = [[calendar dateFromComponents:c] timeIntervalSince1970];
	__weak typeof(self) weakSelf = self;
	// One stop instead of two: the calendar answers both the message to
	// land on and how many the chat has carried all along.
	[[TGClient shared] calendarJumpForChat:self.chatId
									endDate:(NSInteger)end
								completion:^(int64_t messageId, NSInteger total){
		TGChatViewController *me = weakSelf;
		if (!me)
			return;
		if (messageId){
			[me showMessageId:messageId gone:@"Message Deleted."];
			return;
		}
		// The calendar query is a search and can answer nothing while the
		// day still holds a message; getChatMessageByDate is the direct
		// lookup for exactly that day.
		[[TGClient shared] messageAtDate:end inChat:me.chatId
							  completion:^(NSDictionary *found){
			int64_t foundId = [found[@"id"] longLongValue];
			if (!foundId){
				[TGSnackbar showInView:me.view
								  text:@"No Results"
							   seconds:2 onCommit:nil];
				return;
			}
			[me showMessageId:foundId gone:@"Message Deleted."];
		}];
	}];
}

/// A channel post's comments: a thread in the discussion group, opened as a
/// chat of its own the way forum topics are.
- (void)openCommentsForMessage:(NSDictionary *)m {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] commentThreadForChat:self.chatId messageId:[m[@"id"] longLongValue]
								 completion:^(int64_t discussionChatId, int64_t threadId, NSString *error){
		TGChatViewController *me = weakSelf;
		if (!me)
			return;
		if (error) {
			[TGAlertSheet showMessage:error title:@"Comments" inView:me.view];
			return;
		}
		TGChatViewController *thread = [[TGChatViewController alloc] init];
		thread.chatId = discussionChatId;
		thread.threadId = threadId;
		thread.chatTitle = @"Comments";
		thread.isGroup = YES;
		thread.hidesBottomBarWhenPushed = YES;
		[me.navigationController pushViewController:thread animated:YES];
	}];
}

/// Scroll to a message already loaded, and flash it so the eye finds it.
/// NO when the message is not in the loaded window.
- (BOOL)scrollToMessageId:(int64_t)messageId {
	for (NSInteger row = 0; row < (NSInteger)self.messages.count; row++){
		NSDictionary *candidate = self.messages[row];
		// An album is one row, under the id of its first message.
		BOOL found = [candidate[@"id"] longLongValue] == messageId;
		for (NSDictionary *member in candidate[@"albumMessages"])
			found = found || [member[@"id"] longLongValue] == messageId;
		if (!found)
			continue;

		NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:0];
		[self.table scrollToRowAtIndexPath:path
						  atScrollPosition:UITableViewScrollPositionMiddle
								  animated:YES];
		UITableViewCell *cell = [self.table cellForRowAtIndexPath:path];
		cell.contentView.alpha = TGAlphaHighlight;
		[UIView animateWithDuration:TGAnimationDurationHighlight animations:^{ cell.contentView.alpha = TGAlphaOpaque; }];
		return YES;
	}
	return NO;
}

/// Following a reply. The loaded window first; then a fetched window around
/// what it answers, replacing what was on screen the way the pinned banner
/// does; then the chat that actually holds it, because a reply can point
/// across chats - and that one opens rather than scrolls.
- (void)jumpToReplyById:(int64_t)replyId {
	if (!replyId)
		return;
	if ([self scrollToMessageId:replyId])
		return;

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] historyForChat:self.chatId
					  aroundMessageId:replyId
								limit:(NSInteger)TGMetricHistoryPageAroundPinned
						   completion:^(NSArray *messages){
		TGChatViewController *me = weakSelf;
		if (!me)
			return;
		if (messages.count){
			[me.streamStore resetWithMessages:messages];
			me.rawMessages = [me.streamStore messages];
			me.messages = [me groupedMessagesFromMessages:me.rawMessages];
			me.atChatEnd = NO;
			me.atChatStart = NO;
			[me.table reloadData];
			if ([me scrollToMessageId:replyId])
				return;
		}
		// Not in this chat's history: ask TDLib what the reply names.
		[[TGClient shared] repliedMessageTo:replyId inChat:me.chatId
								 completion:^(NSDictionary *reply){
			TGChatViewController *inner = weakSelf;
			if (!inner)
				return;
			int64_t otherChat = reply ? [reply[@"chatId"] longLongValue] : 0;
			if (otherChat && otherChat != inner.chatId){
				NSString *title = [[TGClient shared] titleForChat:otherChat] ?: @"Chat";
				TGChatViewController *other = [[TGChatViewController alloc] init];
				other.chatId = otherChat;
				other.chatTitle = title;
				other.hidesBottomBarWhenPushed = YES;
				[inner.navigationController pushViewController:other animated:YES];
				return;
			}
			[TGSnackbar showInView:inner.view
							  text:@"Message Deleted."
						   seconds:2 onCommit:nil];
		}];
	}];
}

/// A tap votes, unless the poll has already heard from you or closed. A
/// single-answer poll sends its one option at once; a multiple-answer poll
/// keeps the tapped answers as a draft and the bubble grows a Vote button.
/// The answer's developer card is gone: it told the voter nothing Telegram
/// shows, and it put a second tap between them and the vote.
- (void)pollOptionTapped:(UIButton *)option {
	UIView *view = option;
	while (view && ![view isKindOfClass:TGBubbleCell.class])
		view = view.superview;
	TGBubbleCell *cell = (TGBubbleCell *)view;
	if (!cell || !cell.pollMessageId)
		return;

	NSInteger index = option.tag - 0x9100;
	NSDictionary *message = nil;
	for (NSDictionary *candidate in self.messages){
		if ([candidate[@"id"] longLongValue] == cell.pollMessageId){
			message = candidate;
			break;
		}
	}
	NSDictionary *poll = [message[@"poll"] isKindOfClass:NSDictionary.class]
			? message[@"poll"] : nil;
	NSArray *options = [poll[@"options"] isKindOfClass:NSArray.class]
			? poll[@"options"] : @[];
	if (!poll || index < 0 || index >= (NSInteger)options.count)
		return;
	// Closed polls and polls this account voted in show their results; their
	// options are labels, not votes.
	if (TGPollShowsResults(poll))
		return;

	int64_t messageId = cell.pollMessageId;
	int64_t chatId = self.chatId;
	__weak typeof(self) weakSelf = self;

	if (![poll[@"allowsMultiple"] boolValue]){
		[[TGClient shared] votePoll:messageId inChat:chatId options:@[@(index)]];
		// TDLib answers with an updated message; re-read so the shares move.
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
				(int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			[weakSelf reload];
		});
		return;
	}

	if (!self.pendingPollVotes)
		self.pendingPollVotes = [NSMutableDictionary dictionary];
	NSNumber *key = @(messageId);
	NSMutableIndexSet *pending = self.pendingPollVotes[key];
	if (![pending isKindOfClass:NSMutableIndexSet.class]){
		pending = [NSMutableIndexSet indexSet];
		self.pendingPollVotes[key] = pending;
	}
	if ([pending containsIndex:(NSUInteger)index])
		[pending removeIndex:(NSUInteger)index];
	else
		[pending addIndex:(NSUInteger)index];
	if (!pending.count)
		[self.pendingPollVotes removeObjectForKey:key];

	// The Vote button changes the bubble's height, so the cached geometry and
	// the row both have to be rebuilt.
	[self.layoutCache removeLayoutForMessageId:messageId];
	NSIndexPath *path = [self.table indexPathForCell:cell];
	if (path)
		[self.table reloadRowsAtIndexPaths:@[path]
						 withRowAnimation:UITableViewRowAnimationNone];
}

/// A task row is a toggle when the checklist lets this account mark tasks.
/// TDLib answers with an updated message, so the row reloads once it does.
- (void)checklistTaskTapped:(UIButton *)taskRow {
	UIView *view = taskRow;
	while (view && ![view isKindOfClass:TGBubbleCell.class])
		view = view.superview;
	TGBubbleCell *cell = (TGBubbleCell *)view;
	if (!cell || !cell.pollMessageId)
		return;

	NSInteger index = taskRow.tag - 0x9300;
	NSDictionary *message = nil;
	for (NSDictionary *candidate in self.messages){
		if ([candidate[@"id"] longLongValue] == cell.pollMessageId){
			message = candidate;
			break;
		}
	}
	NSDictionary *checklist = [message[@"checklist"] isKindOfClass:NSDictionary.class]
			? message[@"checklist"] : nil;
	NSArray *tasks = [checklist[@"tasks"] isKindOfClass:NSArray.class]
			? checklist[@"tasks"] : @[];
	if (!checklist || index < 0 || index >= (NSInteger)tasks.count)
		return;
	if (!TGChecklistCanToggle(checklist))
		return;

	NSDictionary *task = [tasks[(NSUInteger)index] isKindOfClass:NSDictionary.class]
			? tasks[(NSUInteger)index] : nil;
	if (!task)
		return;
	int64_t taskId = [task[@"taskId"] longLongValue];
	if (!taskId)
		return;

	int64_t messageId = cell.pollMessageId;
	int64_t chatId = self.chatId;
	BOOL done = TGChecklistTaskDone(task);
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] markChecklistTask:taskId done:!done inMessage:messageId chat:chatId];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
			(int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[weakSelf reload];
	});
}

/// A card's button, as the official clients answer it.
- (void)openCard:(TGMessageCard *)card ofMessage:(int64_t)messageId {
	NSDictionary *m = nil;
	for (NSDictionary *candidate in self.messages){
		if ([candidate[@"id"] longLongValue] == messageId){
			m = candidate;
			break;
		}
	}
	__weak typeof(self) weakSelf = self;
	switch (card.action){
	case TGMessageCardActionOpenUser: {
		TGProfileViewController *profile = [[TGProfileViewController alloc]
				initWithChatId:card.actionTargetId userId:card.actionTargetId title:card.title];
		[self.navigationController pushViewController:profile animated:YES];
		break;
	}
	case TGMessageCardActionOpenChat: {
		TGChatViewController *chat = [[TGChatViewController alloc] init];
		chat.chatId = card.actionTargetId;
		chat.chatTitle = card.title;
		chat.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:chat animated:YES];
		break;
	}
	case TGMessageCardActionViewGift: {
		NSDictionary *gift = [m[@"gift"] isKindOfClass:NSDictionary.class] ? m[@"gift"] : @{};
		NSNumber *thumb = [gift[@"stickerThumbFileId"] longLongValue] ? gift[@"stickerThumbFileId"]
				: @(card.imageFileId);
		NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:@{
			@"starCount"          : gift[@"starCount"] ?: @0,
			@"note"               : gift[@"text"] ?: @"",
			@"senderUserId"       : gift[@"senderUserId"] ?: @0,
			@"date"               : m[@"date"] ?: @0,
			@"thumbFileId"        : thumb ?: @0,
			@"stickerThumbFileId" : thumb ?: @0,
		}];
		if (gift[@"stickerFileId"])
			dict[@"stickerFileId"] = gift[@"stickerFileId"];
		if (gift[@"isCollectible"])
			dict[@"isCollectible"] = gift[@"isCollectible"];
		TGGiftViewController *vc = [[TGGiftViewController alloc] initWithGift:dict];
		vc.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:vc animated:YES];
		break;
	}
	case TGMessageCardActionOpenStory: {
		TGStoryViewerViewController *viewer = [[TGStoryViewerViewController alloc]
				initWithChatId:card.actionChatId title:@"Story"
					   stories:@[@(card.actionTargetId)] startIndex:0 canManage:NO];
		UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:viewer];
		nav.navigationBar.barStyle = UIBarStyleBlack;
		nav.navigationBar.translucent = YES;
		[self presentViewController:nav animated:YES completion:nil];
		break;
	}
	case TGMessageCardActionPlayGame: {
		// A game is a web page the bot hands out for this message.
		NSDictionary *game = [m[@"game"] isKindOfClass:NSDictionary.class] ? m[@"game"] : @{};
		[[TGClient shared] pressCallbackButton:@{@"gameShortName" : game[@"shortName"] ?: @""}
										inChat:self.chatId messageId:messageId
									completion:^(NSString *text, BOOL alert, NSString *url, NSString *error){
			dispatch_async(dispatch_get_main_queue(), ^{
				TGChatViewController *me = weakSelf;
				if (url.length)
					[[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
				else if (me)
					[TGSnackbar showInView:me.view text:(text.length ? text : @"An error occurred.")
								   seconds:2 onCommit:nil];
			});
		}];
		break;
	}
	case TGMessageCardActionOpenGiveaway: {
		int64_t giveawayId = card.actionTargetId ?: messageId;
		[[TGClient shared] giveawayInfoForChat:self.chatId message:giveawayId
									completion:^(NSDictionary *info, NSString *error){
			dispatch_async(dispatch_get_main_queue(), ^{
				TGChatViewController *me = weakSelf;
				if (!me)
					return;
				NSString *body;
				if (!info)
					body = @"Could not load this giveaway.";
				else if ([info[@"isWinner"] boolValue])
					body = [info[@"giftCode"] length]
						? [NSString stringWithFormat:@"You won a prize in this giveaway. Your gift code: %@", info[@"giftCode"]]
						: @"You won a prize in this giveaway.";
				else if ([info[@"isEnded"] boolValue])
					body = @"This giveaway has ended.";
				else
					body = @"This giveaway is still running.";
				[TGAlertSheet showMessage:body title:@"Giveaway" inView:me.view];
			});
		}];
		break;
	}
	case TGMessageCardActionOpenCommunity: {
		int64_t communityId = card.actionTargetId;
		if (communityId != 0) {
			[TGChatViewController openCommunity:communityId
									 navigation:self.navigationController
										 inView:self.view];
		}
		break;
	}
	default:
		break;
	}
}

/// Sends every draft answer of a multiple-answer poll in one request. TDLib
/// wants the whole set at once; the empty set is how a vote is retracted.
- (void)pollVoteTapped:(UIButton *)button {
	UIView *view = button;
	while (view && ![view isKindOfClass:TGBubbleCell.class])
		view = view.superview;
	TGBubbleCell *cell = (TGBubbleCell *)view;
	if (!cell || !cell.pollMessageId)
		return;

	int64_t messageId = cell.pollMessageId;
	NSNumber *key = @(messageId);
	NSArray *indexes = TGPollVoteIndexes(self.pendingPollVotes[key]);
	if (!indexes.count)
		return;
	[self.pendingPollVotes removeObjectForKey:key];

	[[TGClient shared] votePoll:messageId inChat:self.chatId options:indexes];
	[self.layoutCache removeLayoutForMessageId:messageId];
	NSIndexPath *path = [self.table indexPathForCell:cell];
	if (path)
		[self.table reloadRowsAtIndexPaths:@[path]
						 withRowAnimation:UITableViewRowAnimationNone];

	__weak typeof(self) weakSelf = self;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
			(int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[weakSelf reload];
	});
}


@end
