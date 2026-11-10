#import "TGProfileViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGProfileStore.h"
#import "TGProfileSupport.h"
#import "TGNameWithStatus.h"
#import "TGCustomEmojiStore.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGMemberCell.h"
#import "TGGroupMemberActions.h"
#import "TGProfileAudioViewController.h"
#import "TGMusicPlayer.h"
#import "TGChatViewController.h"
#import "TGSimilarChannelsViewController.h"
#import "TGDMTopicsViewController.h"
#import "UIImage+WebP.h"
#import <AVFoundation/AVFoundation.h>
#import "TGProfileViewController.h"
#import "TGGroupLogic.h"
#import "TGProfileLogic.h"




/// Flattened messages carry a unix date, not a formatted stamp; the shared
/// lists want a short one beside each row.
/// A file's size as the row prints it. The file info sheet has its own copy;
/// this one is only the compact line under a name here.
static NSString *TGProfileFileSize(NSNumber *bytes) {
	long long value = [bytes longLongValue];
	if (value <= 0)
		return nil;
	if (value < 1024)
		return [NSString stringWithFormat:@"%lld B", value];
	if (value < 1024 * 1024)
		return [NSString stringWithFormat:@"%.0f KB", value / 1024.0];
	return [NSString stringWithFormat:@"%.1f MB", value / (1024.0 * 1024.0)];
}

static NSString *TGProfileDurationText(NSNumber *seconds) {
	NSInteger value = [seconds integerValue];
	if (value <= 0)
		return nil;
	return [NSString stringWithFormat:@"%ld:%02ld", (long)(value / 60), (long)(value % 60)];
}

static NSString *TGProfileShortDate(NSNumber *date) {
	if (![date isKindOfClass:NSNumber.class] || !date.doubleValue)
		return nil;
	static NSDateFormatter *formatter = nil;
	if (!formatter){
		formatter = [[NSDateFormatter alloc] init];
		formatter.dateStyle = NSDateFormatterMediumStyle;
		formatter.timeStyle = NSDateFormatterNoStyle;
	}
	return [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:date.doubleValue]];
}

/// The gift glyph: the sticker's own emoji drawn large. Every gift cell
/// starts here, and the sticker thumbnail replaces the image once the
/// download lands - until then the row is never blank (B5).
static UIImage *TGGiftGlyph(NSString *emoji) {
	if (!emoji.length || ![TGCapabilities canDrawEmoji:emoji])
		return nil;
	static NSCache *cache = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ cache = [[NSCache alloc] init]; });
	NSString *key = [emoji stringByAppendingFormat:@"@40"];
	UIImage *cached = [cache objectForKey:key];
	if (cached)
		return cached;

	UIGraphicsBeginImageContextWithOptions(CGSizeMake(kGiftTile, kGiftTile), NO, 0);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	[emoji drawInRect:CGRectMake(kGiftTileInset, kGiftTileInset,
								 kGiftTile - TGDoubled(kGiftTileInset),
								 kGiftTile - TGDoubled(kGiftTileInset))
			 withFont:TGFontEmoji()
		lineBreakMode:NSLineBreakByClipping
		   alignment:NSTextAlignmentCenter];
#pragma clang diagnostic pop
	UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	[cache setObject:img forKey:key];
	return img;
}

/// The bar under the selected tab, and the room a text row leaves at its sides.
static const CGFloat kMediaTabLine = 2.0f;
static NSString *TGProfileUserName(NSDictionary *user) {
	if (!user) return @"";
	NSString *first = user[@"first_name"] ?: @"";
	NSString *last = user[@"last_name"] ?: @"";
	if (first.length && last.length)
		return [NSString stringWithFormat:@"%@ %@", first, last];
	return first.length ? first : last;
}

static const CGFloat kDetailInset = TGMetricPadWide;

static const CGFloat kMusicStripInset = TGMetricPadMedium;
static const CGFloat kMusicTitleTop   = TGMetricPadSmall;
static const CGFloat kMusicArtistTop  = TGMetricPadSmall + TGMetricLineMicro;
static const CGFloat kMusicChevronSide = TGMetricGiftStar;

static const CGFloat kMinDetailTextWidth = TGMetricActionRow;
static const CGFloat kSimilarChannelsOverlapRatio = 2.0f / 3.0f;

static int64_t TGProfileChatIdFromItem(id item) {
	if ([item isKindOfClass:[NSDictionary class]]) {
		id rawId = item[@"id"];
		if ([rawId respondsToSelector:@selector(longLongValue)])
			return [rawId longLongValue];
	} else if ([item respondsToSelector:@selector(longLongValue)]) {
		return [item longLongValue];
	}
	return 0;
}

/// Overlaps up to three avatars with CoreGraphics into a single bitmap.
/// Each circular face is clipped in the context, separated from its neighbour
/// by a ring cut into the prior face using cardBackgroundColour.
static UIImage *TGProfileCompositeSimilarAvatars(NSArray *images, UIColor *ringColour) {
	if (!images.count)
		return nil;
	CGFloat side = TGMetricMenuGlyph;
	CGFloat scale = [UIScreen mainScreen].scale;
	CGFloat shift = ceilf(side * kSimilarChannelsOverlapRatio);
	NSUInteger count = images.count;
	CGFloat totalWidth = (count == 1) ? side : (shift * (count - 1) + side);
	CGSize totalSize = CGSizeMake(totalWidth, side);

	UIGraphicsBeginImageContextWithOptions(totalSize, NO, scale);
	CGContextRef ctx = UIGraphicsGetCurrentContext();

	CGFloat ringWidth = TGMetricBorderThick;
	if (!ringColour)
		ringColour = [[TGTheme shared] cardBackgroundColour];

	for (NSUInteger i = 0; i < count; i++) {
		CGFloat x = i * shift;
		CGRect avatarRect = CGRectMake(x, 0, side, side);

		if (i > 0) {
			CGContextSaveGState(ctx);
			CGFloat prevX = (i - 1) * shift;
			CGRect prevRect = CGRectMake(prevX, 0, side, side);
			UIBezierPath *prevAvatarClip = [UIBezierPath bezierPathWithOvalInRect:prevRect];
			[prevAvatarClip addClip];

			CGRect ringRect = CGRectInset(avatarRect, -ringWidth, -ringWidth);
			UIBezierPath *ringPath = [UIBezierPath bezierPathWithOvalInRect:ringRect];
			[ringColour setFill];
			[ringPath fill];
			CGContextRestoreGState(ctx);
		}

		CGContextSaveGState(ctx);
		UIBezierPath *clipPath = [UIBezierPath bezierPathWithOvalInRect:avatarRect];
		[clipPath addClip];

		UIImage *img = images[i];
		[img drawInRect:avatarRect];
		CGContextRestoreGState(ctx);
	}

	UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return result;
}

static NSString *TGProfileTruncateToThreeLines(NSString *text, UIFont *font, CGFloat width, CGFloat maxH) {
	if (!text.length)
		return @"";
	CGSize fullSize = [text sizeWithFont:font constrainedToSize:CGSizeMake(width, CGFLOAT_MAX) lineBreakMode:NSLineBreakByWordWrapping];
	if (fullSize.height <= maxH + 1.0f)
		return text;

	NSString *moreSuffix = @"... more";
	NSUInteger low = 0;
	NSUInteger high = text.length;
	NSUInteger best = 0;
	while (low <= high) {
		NSUInteger mid = (low + high) / 2;
		NSString *cand = [NSString stringWithFormat:@"%@ %@", [text substringToIndex:mid], moreSuffix];
		CGSize sz = [cand sizeWithFont:font constrainedToSize:CGSizeMake(width, CGFLOAT_MAX) lineBreakMode:NSLineBreakByWordWrapping];
		if (sz.height <= maxH + 1.0f) {
			best = mid;
			low = mid + 1;
		} else {
			if (mid == 0) break;
			high = mid - 1;
		}
	}
	NSString *base = [text substringToIndex:best];
	NSRange lastSpace = [base rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] options:NSBackwardsSearch];
	if (lastSpace.location != NSNotFound && lastSpace.location > 0) {
		base = [base substringToIndex:lastSpace.location];
	}
	base = [base stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!base.length && best > 0)
		base = [text substringToIndex:best];
	return [NSString stringWithFormat:@"%@... more", base];
}




@implementation TGProfileViewController (TGProfileData)

#pragma mark - profile data
- (void)loadOwnRole {
	if (self.userId || !self.chatId)
		return;
	int64_t meId = [[TGProfileStore shared].me[@"id"] longLongValue];
	if (!meId)
		return;
	__weak typeof(self) weakSelf = self;
	// The type tells the profile whether "members" or "subscribers" is the
	// word, and a basic group's invite right lives on the chat rather than
	// on a member record. Read it before the member so both answers land in
	// the same order whichever request finishes first.
	[[TGProfileStore shared] chatRecordForChat:self.chatId completion:^(NSDictionary *chat){
		TGProfileViewController *me = weakSelf;
		if (!me)
			return;
		NSString *kind = chat[@"type"][@"@type"];
		BOOL wasChannel = me.isChannel;
		me.isGroup = [kind isEqualToString:@"chatTypeBasicGroup"] ||
					 [kind isEqualToString:@"chatTypeSupergroup"];
		me.isChannel = [kind isEqualToString:@"chatTypeSupergroup"] &&
					   [chat[@"type"][@"is_channel"] boolValue];
		me.chatPermissions = [chat[@"permissions"] isKindOfClass:NSDictionary.class]
				? chat[@"permissions"] : @{};
		[me updateGroupStatus];
		[me buildHeader];
		// A channel label built before this answer used the group words;
		// rebuild the card once the type is known.
		if (TGProfileTypeChangeNeedsDetailsReload(wasChannel, me.isChannel,
				me.details.count))
			[me loadDetails];

		[[TGProfileStore shared] chatMember:meId inChat:me.chatId
							completion:^(NSDictionary *member){
			TGProfileViewController *again = weakSelf;
			if (!again)
				return;
			NSDictionary *status = [member[@"status"] isKindOfClass:NSDictionary.class]
					? member[@"status"] : @{};
			NSString *role = status[@"@type"];
			again.myStatus = [role isEqualToString:@"chatMemberStatusCreator"] ? @"owner"
					: ([role isEqualToString:@"chatMemberStatusAdministrator"]
							? @"admin" : @"member");
			again.myRights = [status[@"rights"] isKindOfClass:NSDictionary.class]
					? status[@"rights"] : @{};
			BOOL owner = [again isOwner];
			BOOL hadInvite = again.canInvite;
			BOOL hadManage = again.canManage;
			again.canManage = owner || [again.myStatus isEqualToString:@"admin"];
			// A basic group has no administrator rights object; its
			// permissions are the chat's, and any unrestricted member may
			// invite. A supergroup asks the member's own rights record.
			if (again.isGroup && !again.isChannel &&
					![again.myStatus isEqualToString:@"admin"] && !owner){
				id canInvite = again.chatPermissions[@"can_invite_users"];
				again.canInvite = canInvite ? [canInvite boolValue] : YES;
			} else {
				again.canInvite = owner ||
						[again.myRights[@"can_invite_users"] boolValue];
			}
			// Only the tile row changes shape with this answer; rebuilding
			// the header for every role read would re-download the avatar.
			if (hadInvite != again.canInvite)
				[again buildHeader];
			[again updateNavigationItem];
			// The card gained or lost its Settings row with this answer.
			if (hadManage != again.canManage && again.details.count)
				[again loadDetails];
			[again reloadTableDebounced];
		}];
	}];
}

/// Only this screen's own peer. A group profile has the chat id, not the
/// supergroup id, so any group's full info re-reads a group profile - one
/// request, and the alternative is caching the mapping for no gain.
- (void)fullInfoChanged:(NSNotification *)note {
	NSString *kind = note.userInfo[@"kind"];
	BOOL mine;
	if ([kind isEqualToString:@"user"])
		mine = self.userId && [note.userInfo[@"id"] longLongValue] == self.userId;
	else if ([kind isEqualToString:@"chat"])
		mine = self.chatId && [note.userInfo[@"id"] longLongValue] == self.chatId;
	else
		mine = (self.userId == 0 && self.chatId != 0);
	if (mine)
		[self loadDetails];
}

- (void)membersChanged:(NSNotification *)note {
	if (self.chatId && [note.userInfo[@"chatId"] longLongValue] == self.chatId)
		[self loadDetails];
}

- (void)loadDetails {
	self.muted = [[TGProfileStore shared] isChatMuted:self.chatId];

	if (!self.userId){
		__weak typeof(self) weakSelf = self;
		// A public group's link is its @name, not the invite link, and the
		// name lives on the supergroup record only. Ask once per profile.
		if (self.groupUsername == nil && self.chatId){
			[[TGProfileStore shared] supergroupSettingsForChat:self.chatId
					completion:^(NSDictionary *settings){
				TGProfileViewController *again = weakSelf;
				if (!again)
					return;
				NSArray *active = [settings[@"active"] isKindOfClass:NSArray.class]
						? settings[@"active"] : @[];
				NSString *name = active.count ? active[0] : @"";
				if (![name isKindOfClass:NSString.class])
					name = @"";
				BOOL gained = !again.groupUsername.length && name.length > 0;
				again.groupUsername = name;
				// The card was already built with the invite link; rebuild it
				// once the public name makes the official t.me link possible.
				if (gained && again.details.count)
					[again loadDetails];
			}];
		}
		[self loadOwnRole];
		[[TGProfileStore shared] membersOfChat:self.chatId completion:^(NSArray *members){
			weakSelf.members = members;
			[weakSelf reloadTableDebounced];
		}];
		// Group details: description, member count, invite link.
		[[TGProfileStore shared] chatProfile:self.chatId completion:^(NSDictionary *info){
			TGProfileViewController *me = weakSelf;
			if (!me)
				return;
			me.chatDescription = info[@"description"] ?: @"";
			me.memberCount = [info[@"members"] integerValue];
			me.onlineCount = [info[@"online"] integerValue];
			me.isVerified = [info[@"verified"] boolValue];
			me.inviteLink = info[@"inviteLink"] ?: @"";
			me.directMessagesChatId = [info[@"directMessagesChatId"] longLongValue];
			me.hasDirectMessages = [info[@"hasDirectMessages"] boolValue];
			me.canManageDirectMessages = [info[@"canManageDirectMessages"] boolValue];
			[me updateGroupStatus];
			me.communityId = [info[@"communityId"] longLongValue];
			me.communityName = nil;
			me.communitySubtitle = nil;
			if (me.communityId != 0) {
				NSDictionary *commRecord = nil;
				for (NSDictionary *c in [TGProfileStore shared].communities) {
					if ([c[@"id"] longLongValue] == me.communityId) {
						commRecord = c;
						break;
					}
				}
				NSDictionary *fullComm = [[TGProfileStore shared] cachedCommunityFullInfo:me.communityId];
				NSString *commName = commRecord[@"name"];
				if (!commName.length && [fullComm[@"name"] isKindOfClass:[NSString class]]) {
					commName = fullComm[@"name"];
				}
				me.communityName = commName.length ? commName : @"Community";
				NSArray *commChats = [fullComm[@"chats"] isKindOfClass:[NSArray class]] ? fullComm[@"chats"] : @[];
				if (commChats.count > 0) {
					me.communitySubtitle = TGLocalizedFormat(@"Community with %@ chats", @(commChats.count));
				} else {
					me.communitySubtitle = @"Community";
				}
			}

			// The community is its own section before the card, so the card
			// keeps only the link, the description and Settings.
			me.details = TGProfileGroupInfoRows(@{
				@"inviteLink"           : me.inviteLink ?: @"",
				@"username"             : me.groupUsername ?: @"",
				@"description"          : info[@"description"] ?: @"",
				@"canManage"            : @(me.canManage),
				@"isChannel"            : @(me.isChannel),
			});
			[me buildHeader];
			[me reloadTableDebounced];

			if (me.communityId != 0) {
				[me loadCommunityPhotoOrAvatars];
				if (![[TGProfileStore shared] cachedCommunityFullInfo:me.communityId]) {
					[[TGProfileStore shared] communityFullInfo:me.communityId completion:^(NSDictionary *cinfo, NSString *err){
						TGProfileViewController *again = weakSelf;
						if (!again) return;
						[again reloadCommunityRow];
					}];
				}
			}

			// Similar channels are the last media pane, not an info row.
			if (me.isChannel){
				[[TGProfileStore shared] similarChatsForChat:me.chatId completion:^(NSArray *chats, NSInteger total){
					TGProfileViewController *again = weakSelf;
					if (!again || !chats.count)
						return;
					again.similarChatIds = chats;
					[again reloadTableDebounced];
				}];
			}

			// A linked discussion group or channel is edited in Settings;
			// the profile card itself does not list it.
			int64_t linkedId = [info[@"linkedChatId"] longLongValue];
			if (linkedId != 0)
				me.linkedChatId = linkedId;
		}];
		return;
	}

	__weak typeof(self) weakSelf = self;
	[[TGProfileStore shared] userInfo:self.userId completion:^(NSDictionary *user){
		if (!user) return;
		NSString *updatedName = TGProfileUserName(user);
		if (updatedName.length)
			weakSelf.name = updatedName;
		// The marks beside the name and the scam/fake warning all come off
		// the plain user record; none needs the full-info call.
		NSDictionary *verification = user[@"verification_status"];
		weakSelf.isVerified = [verification[@"is_verified"] boolValue];
		weakSelf.isScam = [verification[@"is_scam"] boolValue];
		weakSelf.isFake = [verification[@"is_fake"] boolValue];
		weakSelf.isContact = [user[@"is_contact"] boolValue];
		// A bot has no presence and cannot be a contact.
		if ([user[@"type"][@"@type"] isEqualToString:@"userTypeBot"]){
			weakSelf.isBot = YES;
			weakSelf.restingStatus = @"bot";
			[weakSelf statusLabelOwnerChanged:nil];
		}
		// The contact flag arrives with this answer and decides the Edit
		// button, so the bar is rebuilt after it lands.
		[weakSelf updateNavigationItem];
		NSDictionary *statusType = user[@"emoji_status"][@"type"];
		int64_t statusId = [statusType[@"custom_emoji_id"] longLongValue]
				?: [statusType[@"model_custom_emoji_id"] longLongValue];
		if (statusId && statusId != weakSelf.emojiStatusId){
			weakSelf.emojiStatusId = statusId;
			[weakSelf fetchEmojiStatusImage:statusId];
		}
		weakSelf.phoneNumber = user[@"phone_number"] ?: @"";
		if (weakSelf.isOwnProfile &&
				(!weakSelf.name.length || [weakSelf.name isEqualToString:@"."]))
			weakSelf.name = TGProfileDisplayName(user, weakSelf.phoneNumber);
		NSArray *activeUsernames = user[@"usernames"][@"active_usernames"];
		if ([activeUsernames isKindOfClass:NSArray.class] && activeUsernames.count) {
			weakSelf.activeUsernames = activeUsernames;
		} else if ([user[@"username"] length]) {
			weakSelf.activeUsernames = @[user[@"username"]];
		} else {
			weakSelf.activeUsernames = @[];
		}
		weakSelf.username = TGFirstUsername(user) ?: @"";
		weakSelf.details = [weakSelf basicDetailsRows];
		[weakSelf buildHeader];
		[weakSelf reloadTableDebounced];

		// The bio, the birthday and the channel live in the full record, which
		// this screen never asked for - so "about" was missing from a profile
		// that has one. The same call carries the block flag, so isUserBlocked
		// would send getUserFullInfo a second time.
		[[TGProfileStore shared] userProfile:weakSelf.userId completion:^(NSDictionary *info){
			weakSelf.blocked = [info[@"isBlocked"] boolValue];
			weakSelf.canCall = [info[@"canCall"] boolValue];
			weakSelf.canVideoCall = [info[@"canVideoCall"] boolValue];
			weakSelf.commonGroupCount = [info[@"commonGroups"] integerValue];
			weakSelf.businessLocation = info[@"businessLocation"] ?: @"";
			NSDictionary *firstAudio = [info[@"firstProfileAudio"]
					isKindOfClass:NSDictionary.class] ? info[@"firstProfileAudio"] : nil;
			if (![firstAudio isEqual:weakSelf.firstProfileAudio]){
				weakSelf.firstProfileAudio = firstAudio;
				[weakSelf buildHeader];
			}
			weakSelf.personalNote = info[@"note"] ?: @"";
			weakSelf.bioEntities = info[@"bioEntities"] ?: @[];
			weakSelf.noteEntities = info[@"noteEntities"] ?: @[];
			weakSelf.birthdayToday = [info[@"birthdayToday"] boolValue];
			weakSelf.hasPersonalPhoto = [info[@"personalPhoto"] longLongValue] != 0;
			NSString *bio = info[@"bio"];
			if (!bio.length && [info[@"botDescription"] length])
				bio = info[@"botDescription"];
			weakSelf.details = [weakSelf fullDetailsRowsWithBio:bio
													  birthday:info[@"birthday"]];
			// The tab the person chose goes first, and the screen opens on it
			// unless a tab has already been picked.
			NSString *mainTab = info[@"mainProfileTab"];
			if (mainTab.length){
				weakSelf.mainMediaKind = mainTab;
				if (!weakSelf.storedMediaKind.length)
					weakSelf.storedMediaKind = mainTab;
			}
			int64_t personalChatId = [info[@"personalChatId"] longLongValue];
			if (personalChatId != 0)   // a channel id is negative
				[weakSelf fetchPersonalChannel:personalChatId];
			[weakSelf buildHeader];
			[weakSelf reloadTableDebounced];
		}];

		// updateUser does not always carry a photo; getUser does.
		NSNumber *photoId = user[@"profile_photo"][@"small"][@"id"];
		if (photoId && ![photoId isEqual:weakSelf.avatarFileId]){
			weakSelf.avatarFileId = photoId;
			[[TGProfileStore shared] downloadFile:photoId.integerValue
								   priority:TGDownloadPriorityAvatar
								 completion:^(NSString *path){
				[weakSelf applyAvatarImageAtPath:path];
			}];
		}
	}];
}

/// The rows the plain user record can answer before full info arrives: just
/// the phone number and username, which are the parts that never move.

@end
