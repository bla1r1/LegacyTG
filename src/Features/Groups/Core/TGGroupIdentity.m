#import "TGGroupSettingsViewController.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGSnackbar.h"
#import "TGContactsViewController.h"
#import "TGChatToolsViewController.h"
#import "TGGroupMemberActions.h"
#import "TGMemberCell.h"
#import "TGProfileViewController.h"
#import "TGIcons.h"
#import "TGGroupCallViewController.h"
#import "TGVideoChatSetupViewController.h"
#import "TGAntiSpamViewController.h"
#import "TGGroupSettingsViewController.h"
#import "TGGroupSwitch.h"
#import "TGGroupSettingsViewControllerInternal.h"
#import "TGGroupStore.h"
#import "TGProfileStore.h"
#import "TGPresent.h"



//
// TGGroupSettingsViewController.m - one screen for everything a group is.
//
// The group profile's More menu used to grow one row per setting: Photo,
// Name, Description, Invite Link, Permissions, Sign Messages, Join to Send,
// All History, Welcome Messages, Direct Messages, Import, Send as, Clear by
// Date, Chat Tools. Each row asked the server what it sat on and answered
// with a sheet. A settings screen can show the value, group the rows by what
// they change, and leave the profile menu for the things a profile does.
//
// The chat id is the only thing the caller passes. Every action here names
// that id directly, so nothing is routed through the profile controller
// behind this screen.
//

/// The rows a section can hold. A switch draws a UISwitch, a member row a
/// face, and everything else a value with a chevron.
typedef NS_ENUM(NSInteger, TGGroupRowKind) {
	TGGroupRowInfo = 0,
	TGGroupRowAction,
	TGGroupRowSwitch,
	TGGroupRowUsername,
	TGGroupRowMember,
};

/// A switch that names the setting it changes, so a reload can rebuild rows
/// without an index pointing at the wrong one.





@implementation TGGroupSettingsViewController (TGGroupIdentity)

#pragma mark - identity

- (void)openGroupCall {
	__weak typeof(self) weakSelf = self;
	[[TGProfileStore shared] chatRecordForChat:self.chatId completion:^(NSDictionary *chat){
		TGGroupSettingsViewController *me = weakSelf;
		if (!me)
			return;
		int32_t callId = [chat[@"video_chat"][@"group_call_id"] intValue];
		TGGroupCallViewController *screen = [[TGGroupCallViewController alloc]
				initWithChatId:me.chatId groupCallId:callId];
		screen.hidesBottomBarWhenPushed = YES;
		[me.navigationController pushViewController:screen animated:YES];
	}];
}

- (void)openVideoChatSetup {
	__weak typeof(self) weakSelf = self;
	[[TGProfileStore shared] chatRecordForChat:self.chatId completion:^(NSDictionary *chat){
		TGGroupSettingsViewController *me = weakSelf;
		if (!me)
			return;
		int32_t callId = [chat[@"video_chat"][@"group_call_id"] intValue];
		TGVideoChatSetupViewController *screen = [[TGVideoChatSetupViewController alloc]
				initWithChatId:me.chatId groupCallId:callId];
		screen.hidesBottomBarWhenPushed = YES;
		[me.navigationController pushViewController:screen animated:YES];
	}];
}

- (void)editName {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Group Name" message:nil placeholder:@"Name"
					   text:self.chatTitle action:@"Save" inView:self.view
				 onSubmit:^(NSString *name){
		[[TGGroupStore shared] setChat:weakSelf.chatId title:name completion:^(BOOL ok){
			TGGroupSettingsViewController *me = weakSelf;
			if (!ok){
				[TGAlertSheet showMessage:@"An error occurred."
									title:@"Group Name" inView:me.view];
				return;
			}
			me.chatTitle = name;
			me.title = name;
			[me rebuild];
			[TGSnackbar showInView:me.view text:@"Your name was updated." seconds:2 onCommit:nil];
		}];
	}];
}

- (void)editDescription {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Edit Description"
					message:nil
				placeholder:@"Description"
					   text:self.descriptionText
					 action:@"Save"
					 inView:self.view
				 onSubmit:^(NSString *text){
		[[TGGroupStore shared] setChat:weakSelf.chatId description:text
						completion:^(BOOL ok){
			TGGroupSettingsViewController *me = weakSelf;
			if (!ok){
				[TGAlertSheet showMessage:@"An error occurred."
									title:@"Edit Description" inView:me.view];
				return;
			}
			me.descriptionText = text;
			[me rebuild];
			[TGSnackbar showInView:me.view text:@"Description is changed."
						   seconds:2 onCommit:nil];
		}];
	}];
}

- (void)editPhoto {
	if (![UIImagePickerController isSourceTypeAvailable:
			UIImagePickerControllerSourceTypePhotoLibrary]){
		[TGAlertSheet showMessage:@"An error occurred."
							title:@"Set Group Photo" inView:self.view];
		return;
	}
	self.pickingPhoto = YES;
	__weak typeof(self) weakSelf = self;
	[TGPresent pickMediaFrom:self source:TGMediaSourceLibrary videos:NO sourceView:nil
					  onPick:^(NSDictionary *info){ [weakSelf didPickMedia:info]; }];
}

/// What the library handed back, once the picker has gone.
- (void)didPickMedia:(NSDictionary *)info {
	if (!self.pickingPhoto)
		return;
	self.pickingPhoto = NO;
	UIImage *image = info[UIImagePickerControllerOriginalImage];
	if (!image)
		return;
	UIImage *scaled = [TGIcons decodedImage:image
								fittingSize:CGSizeMake(TGMetricUploadPhotoSide, TGMetricUploadPhotoSide)
									   fill:NO scale:TGMetricScaleFull];
	NSString *path = [NSTemporaryDirectory()
			stringByAppendingPathComponent:@"group-photo.jpg"];
	if (![UIImageJPEGRepresentation(scaled, TGCompressionQualityStandard) writeToFile:path atomically:YES]){
		[TGAlertSheet showMessage:@"An error occurred."
							title:@"Set Group Photo" inView:self.view];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGGroupStore shared] setChat:self.chatId photoAtPath:path completion:^(BOOL ok){
		TGGroupSettingsViewController *me = weakSelf;
		if (!ok){
			[TGAlertSheet showMessage:@"An error occurred."
								title:@"Set Group Photo" inView:me.view];
			return;
		}
		me.hasPhoto = YES;
		[me rebuild];
		[TGSnackbar showInView:me.view text:@"Group photo updated"
					   seconds:2 onCommit:nil];
	}];
}

- (void)chooseMainTab {
	NSArray *names = @[@"posts", @"media", @"files", @"links", @"music",
					   @"voice", @"gifs"];
	NSArray *titles = @[@"Posts", @"Media", @"Files", @"Links", @"Music",
						@"Voice", @"GIFs"];
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:titles title:@"Set as Main Tab" destructiveIndex:-1
					   inView:self.view onChoice:^(NSInteger index){
		NSString *tab = names[(NSUInteger)index];
		[[TGProfileStore shared] setSupergroupMainProfileTab:tab inChat:weakSelf.chatId
				completion:^(BOOL ok, NSString *error){
			TGGroupSettingsViewController *me = weakSelf;
			if (!ok){
				[me showRefusal:error title:@"Set as Main Tab"];
				return;
			}
			NSMutableDictionary *changed = [me.settings mutableCopy];
			changed[@"mainTab"] = tab;
			me.settings = changed;
			[me rebuild];
		}];
	}];
}

- (void)confirmUpgrade {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:@"To go over the limit and get additional features, upgrade to a supergroup:"
						 title:@"Upgrade to supergroup"
						action:@"Upgrade"
				   destructive:NO
						inView:self.view
					 onConfirm:^{
		[[TGGroupStore shared] upgradeGroupToSupergroup:weakSelf.chatId
										 completion:^(int64_t newChatId){
			TGGroupSettingsViewController *me = weakSelf;
			if (!newChatId){
				[TGAlertSheet showMessage:@"An error occurred."
										  title:@"Upgrade" inView:me.view];
				return;
			}
			UINavigationController *nav = me.navigationController;
			[nav popToRootViewControllerAnimated:YES];
			[TGAlertSheet showMessage:@"This group was upgraded to a supergroup"
								  title:@"Upgrade to supergroup"
								 inView:(nav.view ?: me.view)];
		}];
	}];
}


@end
