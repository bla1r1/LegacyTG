#import "TGGroupSettingsViewController.h"
#import "TGClient.h"
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


static NSMutableDictionary *TGRow(NSString *title, NSString *detail,
								  NSString *action, TGGroupRowKind kind) {
	NSMutableDictionary *row = [@{@"kind" : @(kind), @"title" : title ?: @""}
			mutableCopy];
	if (detail)
		row[@"detail"] = detail;
	if (action)
		row[@"action"] = action;
	return row;
}

static NSMutableDictionary *TGInfoRow(NSString *title, NSString *detail,
									  NSString *action) {
	return TGRow(title, detail, action, TGGroupRowInfo);
}

static NSMutableDictionary *TGOpenRow(NSString *title, NSString *detail,
									  NSString *action) {
	NSMutableDictionary *row = TGInfoRow(title, detail, action);
	row[@"opens"] = @YES;
	return row;
}

static NSMutableDictionary *TGActionRow(NSString *title, NSString *detail,
										NSString *action, BOOL destructive) {
	NSMutableDictionary *row = TGRow(title, detail, action, TGGroupRowAction);
	if (destructive)
		row[@"destructive"] = @YES;
	return row;
}

static NSMutableDictionary *TGOpenActionRow(NSString *title, NSString *detail,
											NSString *action, BOOL destructive) {
	NSMutableDictionary *row = TGActionRow(title, detail, action, destructive);
	row[@"opens"] = @YES;
	return row;
}

/// The same row when the account has no right for it: the title and the
/// reason stay on screen, the chevron and the tap do not. That is what
/// Telegram does for a switch an administrator may see but not move.
static NSMutableDictionary *TGDisabledRow(NSString *title, NSString *reason,
										  NSString *action) {
	NSMutableDictionary *row = TGActionRow(title, reason, nil, NO);
	if (action)
		row[@"refusedAction"] = action;
	row[@"disabled"] = @YES;
	return row;
}

static NSMutableDictionary *TGSwitchRow(NSString *title, NSString *detail,
										NSString *key, BOOL on, BOOL enabled) {
	NSMutableDictionary *row = TGRow(title, detail, nil, TGGroupRowSwitch);
	row[@"switch"] = key;
	row[@"on"] = @(on);
	row[@"enabled"] = @(enabled);
	return row;
}

static NSMutableDictionary *TGUsernameRow(NSString *username, BOOL active) {
	NSMutableDictionary *row = TGRow([@"@" stringByAppendingString:username],
									 active ? @"Active" : @"Disabled",
									 nil, TGGroupRowUsername);
	row[@"switch"] = [@"@" stringByAppendingString:username];
	row[@"username"] = username;
	row[@"active"] = @(active);
	row[@"on"] = @(active);
	row[@"enabled"] = @YES;
	return row;
}

static NSDictionary *TGSection(NSString *header, NSString *footer, NSArray *rows) {
	NSMutableDictionary *section = [NSMutableDictionary dictionary];
	if (header) section[@"header"] = header;
	if (footer) section[@"footer"] = footer;
	section[@"rows"] = rows ?: @[];
	return section;
}




@implementation TGGroupSettingsViewController (TGGroupIdentity)

#pragma mark - identity

- (void)openGroupCall {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] chatRecordForChat:self.chatId completion:^(NSDictionary *chat){
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
	[[TGClient shared] chatRecordForChat:self.chatId completion:^(NSDictionary *chat){
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
		[[TGClient shared] setChat:weakSelf.chatId title:name completion:^(BOOL ok){
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
		[[TGClient shared] setChat:weakSelf.chatId description:text
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
	UIImagePickerController *picker = [[UIImagePickerController alloc] init];
	picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
	picker.delegate = self;
	[self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker
		didFinishPickingMediaWithInfo:(NSDictionary *)info {
	[picker dismissViewControllerAnimated:YES completion:nil];
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
	[[TGClient shared] setChat:self.chatId photoAtPath:path completion:^(BOOL ok){
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

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
	self.pickingPhoto = NO;
	[picker dismissViewControllerAnimated:YES completion:nil];
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
		[[TGClient shared] setSupergroupMainProfileTab:tab inChat:weakSelf.chatId
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
		[[TGClient shared] upgradeGroupToSupergroup:weakSelf.chatId
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
