#import "TGProfileViewControllerInternal.h"
#import "TGProfileStore.h"
#import "TGPeerStore.h"
#import "TGStyle.h"
#import "TGProfileHeaderView.h"
#import "TGProfileLogic.h"
#import "TGLocalization.h"

@implementation TGProfileViewController (TGProfileHeader)

/// The tiles under the name, in the official order, as data for the shared
/// header: a glyph, the official word and the routing key.
- (NSArray *)headerActions {
	if (self.isOwnProfile)
		return @[];
	NSMutableArray *tiles = [NSMutableArray array];
	if (self.userId){
		if (!self.onSearchTapped)
			[tiles addObject:@{@"glyph" : @"chat", @"title" : @"Message",
					@"key" : @"message"}];
		if (self.canCall && !self.isBot)
			[tiles addObject:@{@"glyph" : @"call", @"title" : @"call",
					@"key" : @"call"}];
		if (self.canCall && self.canVideoCall && !self.isBot &&
				[TGCapabilities canEncodeVideoCall])
			[tiles addObject:@{@"glyph" : @"video", @"title" : @"video",
					@"key" : @"video"}];
		if (self.isBot && !self.blocked)
			[tiles addObject:@{@"glyph" : @"close", @"title" : @"stop",
					@"key" : @"stop"}];
		[tiles addObject:@{@"glyph" : (self.muted ? @"unmute" : @"mute"),
				@"title" : (self.muted ? @"unmute" : @"mute"),
				@"key" : (self.muted ? @"unmute" : @"mute")}];
		if (self.onSearchTapped)
			[tiles addObject:@{@"glyph" : @"search", @"title" : @"search",
					@"key" : @"search"}];
		[tiles addObject:@{@"glyph" : @"more", @"title" : @"more",
				@"key" : @"more"}];
	} else if (self.isChannel){
		BOOL hasDM = (self.directMessagesChatId != 0) ||
				self.hasDirectMessages || self.canManageDirectMessages;
		if (hasDM)
			[tiles addObject:@{@"glyph" : @"chat", @"title" : @"Message",
					@"key" : @"message"}];
		[tiles addObject:@{@"glyph" : (self.muted ? @"unmute" : @"mute"),
				@"title" : (self.muted ? @"Unmute" : @"Mute"),
				@"key" : (self.muted ? @"unmute" : @"mute")}];
		[tiles addObject:@{@"glyph" : @"logout", @"title" : @"Leave",
				@"key" : @"leave"}];
		[tiles addObject:@{@"glyph" : @"more", @"title" : @"More",
				@"key" : @"more"}];
	} else {
		if (self.canInvite)
			[tiles addObject:@{@"glyph" : @"plus", @"title" : @"add",
					@"key" : @"add"}];
		[tiles addObject:@{@"glyph" : (self.muted ? @"unmute" : @"mute"),
				@"title" : (self.muted ? @"unmute" : @"mute"),
				@"key" : (self.muted ? @"unmute" : @"mute")}];
		if (self.onSearchTapped)
			[tiles addObject:@{@"glyph" : @"search", @"title" : @"search",
					@"key" : @"search"}];
		[tiles addObject:@{@"glyph" : @"more", @"title" : @"more",
				@"key" : @"more"}];
	}
	return tiles;
}

- (void)buildHeader {
	// My Profile has no title to start from: the account's own name is the
	// header, and a nameless account still shows its phone, never a dot.
	if (self.isOwnProfile && (!self.name.length ||
			[self.name isEqualToString:@"."])){
		self.name = TGProfileDisplayName([TGProfileStore shared].me, self.phoneNumber);
	}
	CGFloat width = self.view.bounds.size.width ?: TGMetricScreenWidth;
	NSArray *actions = [self headerActions];
	NSDictionary *music = nil;
	if (self.firstProfileAudio){
		NSString *title = self.firstProfileAudio[@"title"];
		NSString *performer = self.firstProfileAudio[@"performer"];
		music = @{
			TGProfileHeaderMusicTitle : title.length ? title
					: TGLocalized(@"Audio"),
			TGProfileHeaderMusicPerformer : performer.length ? performer
					: TGLocalized(@"Unknown artist"),
		};
	}
	NSMutableDictionary *model = [@{
		TGProfileHeaderName : self.name ?: @"",
		TGProfileHeaderInitials : [TGIcons initialsForTitle:self.name],
		TGProfileHeaderColourId : @(self.userId ?: self.chatId),
		TGProfileHeaderEmojiStatusId : @(self.emojiStatusId),
		TGProfileHeaderVerified : @(self.isVerified),
		TGProfileHeaderActions : actions,
	} mutableCopy];
	if (self.avatarImage)
		model[TGProfileHeaderAvatar] = self.avatarImage;
	if (music)
		model[TGProfileHeaderMusic] = music;

	CGFloat height = [TGProfileHeaderView heightForWidth:width model:model];
	TGProfileHeaderView *header = [[TGProfileHeaderView alloc]
			initWithFrame:CGRectMake(0, 0, width, height)];
	__weak typeof(self) weakSelf = self;
	header.avatarTap = ^{ [weakSelf avatarTapped]; };
	header.actionTap = ^(NSString *key){ [weakSelf handleActionKey:key]; };
	header.musicTap = ^{ [weakSelf musicStripTapped]; };
	[header configureWithModel:model];
	self.headerView = header;
	self.tableView.tableHeaderView = header;
	self.tableView.backgroundColor = [[TGTheme shared] groupedBackgroundColour];

	// The status line listens to presence too: a status arriving while the
	// profile is open refreshes the line (B4).
	if ([self showsSavedMessages]){
		header.statusText = nil;
	} else if (self.isOwnProfile){
		// You are using the app, so to yourself you are online.
		self.restingStatus = @"online";
		header.statusColour = [[TGTheme shared] accentColour];
		[self statusLabelOwnerChanged:nil];
	} else if (self.userId){
		[[TGPeerStore shared] refreshPeerForId:self.userId
									completion:^(TGPeer *peer){
			if (!peer.lastSeenText.length)
				return;
			if (!weakSelf.isBot)
				weakSelf.restingStatus = peer.lastSeenText;
			[weakSelf statusLabelOwnerChanged:nil];
		}];
	} else {
		[self updateGroupStatus];
		[[TGPeerStore shared] refreshPeerForId:self.chatId
									completion:^(TGPeer *peer){
			if (peer.memberCount > 0 && weakSelf.memberCount <= 0){
				weakSelf.memberCount = peer.memberCount;
				[weakSelf updateGroupStatus];
			}
		}];
	}

	int64_t peerId = self.userId ?: self.chatId;
	if (!peerId)
		return;
	UIImage *cached = [[TGPeerStore shared] cachedAvatarForPeer:peerId
														   side:TGMetricProfileAvatar];
	if (cached){
		self.avatarImage = cached;
		header.avatarImage = cached;
		return;
	}
	[[TGPeerStore shared] loadAvatarForPeer:peerId side:TGMetricProfileAvatar
								 completion:^(UIImage *image){
		if (!image)
			return;
		weakSelf.avatarImage = image;
		weakSelf.headerView.avatarImage = image;
	}];
}

- (void)updateGroupStatus {
	if (self.userId || self.memberCount <= 0)
		return;
	NSString *count = TGLocalizedPlural(
			self.isChannel ? @"%d subscriber" : @"%d member",
			self.isChannel ? @"%d subscribers" : @"%d members",
			self.memberCount);
	self.restingStatus = self.onlineCount > 0 && !self.isChannel
			? [NSString stringWithFormat:@"%@, %@",
					count, TGLocalizedFormat(@"%@ online",
							[NSString stringWithFormat:@"%ld",
									(long)self.onlineCount])]
			: count;
	[self statusLabelOwnerChanged:nil];
}

- (BOOL)isOwner {
	return [self.myStatus isEqualToString:@"owner"];
}

- (BOOL)isOwnProfile {
	return self.userId && self.userId == [[TGProfileStore shared].me[@"id"] longLongValue];
}

@end
