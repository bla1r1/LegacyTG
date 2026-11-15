#import "TGProfileViewControllerInternal.h"
#import "TGProfileStore.h"
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
#import "TGProfileLogic.h"









@implementation TGProfileViewController (TGProfileDetails)

#pragma mark - details model
- (NSArray *)basicDetailsRows {
	return TGProfileUserInfoRows(@{
		@"phoneNumber"     : self.phoneNumber ?: @"",
		@"username"        : self.username ?: @"",
		@"activeUsernames" : self.activeUsernames ?: @[],
	});
}

/// The whole card, rebuilt once full info answers. Order and row kinds come
/// from TGProfileUserInfoRows so the host tests can check them without UIKit.
- (NSArray *)fullDetailsRowsWithBio:(NSString *)bio birthday:(NSString *)birthday {
	return TGProfileUserInfoRows(@{
		@"phoneNumber"     : self.phoneNumber ?: @"",
		@"username"        : self.username ?: @"",
		@"activeUsernames" : self.activeUsernames ?: @[],
		@"isScam"          : @(self.isScam),
		@"isFake"          : @(self.isFake),
		@"birthday"        : birthday ?: @"",
		@"bio"             : bio ?: @"",
		@"note"            : self.personalNote ?: @"",
		@"businessLocation": self.businessLocation ?: @"",
		@"businessInfo"    : self.businessInfo ?: (id)[NSNull null],
		@"isOwnProfile"    : @(self.isOwnProfile),
		@"isContact"       : @(self.isContact),
		@"isBot"           : @(self.isBot),
		@"botCanJoinGroups": @(self.botCanJoinGroups),
		@"botVerification" : self.botVerification ?: @"",
		@"blocked"         : @(self.blocked),
	});
}

/// The person's personal channel: one getChat, then a row at the top of the
/// card that opens it like any chat the list holds.
- (void)fetchEmojiStatusImage:(int64_t)emojiId {
	__weak typeof(self) weakSelf = self;
	[[TGProfileStore shared] customEmojiStickersForIds:@[@(emojiId)] completion:^(NSArray *stickers){
		NSNumber *thumb = stickers.count ? stickers[0][@"thumbId"] : nil;
		if (![thumb isKindOfClass:NSNumber.class] || !thumb.integerValue)
			return;
		[[TGProfileStore shared] downloadFile:thumb.integerValue
							   priority:TGDownloadPriorityAvatar
							 completion:^(NSString *path){
			if (!path.length)
				return;
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				UIImage *image = [UIImage imageWithContentsOfFile:path]
						?: [UIImage convertFromWebP:path compressedData:nil error:nil];
				dispatch_async(dispatch_get_main_queue(), ^{
					if (!image)
						return;
					weakSelf.emojiStatusImage = image;
					[weakSelf buildHeader];
				});
			});
		}];
	}];
}

- (void)fetchPersonalChannel:(int64_t)chatId {
	if (self.personalChannel)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGProfileStore shared] chatRecordForChat:chatId completion:^(NSDictionary *chat){
		TGProfileViewController *me = weakSelf;
		if (!me || !chat)
			return;
		NSString *title = chat[@"title"] ?: @"";
		NSNumber *photoId = chat[@"photo"][@"small"][@"id"];
		me.personalChannel = @{
			@"chatId" : @(chatId),
			@"title" : title,
			@"photoFileId" : [photoId isKindOfClass:NSNumber.class] ? photoId : @0,
		};
		if ([photoId isKindOfClass:[NSNumber class]] && photoId.integerValue > 0 &&
				!me.chatAvatars[@(chatId)]){
			[me loadAvatarForChatId:chatId kind:@"channel"];
		}
		// The personal channel is its own section above the card, not a row
		// inside it. Its row is a chat-list item, so the last post reads as
		// the preview under the channel name.
		[[TGProfileStore shared] memberCountForChat:chatId completion:^(NSInteger count){
			TGProfileViewController *again = weakSelf;
			if (!again)
				return;
			again.personalChannelMemberCount = count;
			[again reloadTableDebounced];
		}];
		[[TGProfileStore shared] historyForChat:chatId limit:1 completion:^(NSArray *messages){
			TGProfileViewController *again = weakSelf;
			if (!again)
				return;
			NSDictionary *last = messages.lastObject;
			NSString *preview = [last[@"text"] isKindOfClass:NSString.class]
					? last[@"text"] : @"";
			if (!preview.length && [last[@"photoId"] respondsToSelector:@selector(longLongValue)])
				preview = @"Photo";
			again.personalChannelPreview = preview;
			[again reloadTableDebounced];
		}];
		[me reloadTableDebounced];
	}];
}

- (void)reloadTableDebounced {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(doReloadTable) object:nil];
	[self performSelector:@selector(doReloadTable) withObject:nil afterDelay:0.05];
}

- (void)doReloadTable {
	[self rebuildSections];
}


@end
