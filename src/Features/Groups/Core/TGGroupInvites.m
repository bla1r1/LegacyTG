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
#import "TGGroupLogic.h"
#import "TGLocalization.h"
#import "TGGroupStore.h"
#import "TGProfileStore.h"
#import "TGUIFormat.h"
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





@implementation TGGroupSettingsViewController (TGGroupInvites)

#pragma mark - invite links

- (void)showInviteLink {
	int64_t chatId = self.chatId;
	__weak typeof(self) weakSelf = self;
	[[TGGroupStore shared] inviteLinksForChat:chatId completion:^(NSArray *links){
		TGGroupSettingsViewController *me = weakSelf;
		NSDictionary *preferred = TGInviteLinkPreferred(links);
		NSString *primary = preferred[@"link"];
		if (!primary.length){
			[TGAlertSheet showMessage:@"An error occurred."
								title:@"Invite Link" inView:me.view];
			return;
		}
		[TGAlertSheet showChoices:@[@"Copy Link", @"Create a New Link",
									@"Create Subscription Link",
									@"Manage Invite Links", @"Invite Links"]
							title:primary
				 destructiveIndex:-1 inView:me.view
						 onChoice:^(NSInteger index){
			if (index == 0){
				[UIPasteboard generalPasteboard].string = primary;
				[TGAlertSheet showMessage:@"Link copied." title:nil inView:me.view];
				return;
			}
			if (index == 1){
				[[TGGroupStore shared] createInviteLinkForChat:chatId name:nil
											   memberLimit:0
												completion:^(NSString *link){
					[TGAlertSheet showMessage:(link.length ? link
							: @"An error occurred while creating the invite link")
										title:@"New Link" inView:me.view];
				}];
				return;
			}
			if (index == 2){
				[me createSubscriptionLink];
				return;
			}
			if (index == 3){
				[me showAllInviteLinks];
				return;
			}
			[me showInviteLinkCounts];
		}];
	}];
}

- (void)showAllInviteLinks {
	int64_t chatId = self.chatId;
	__weak typeof(self) weakSelf = self;
	[[TGGroupStore shared] inviteLinksForChat:chatId completion:^(NSArray *links){
		TGGroupSettingsViewController *me = weakSelf;
		if (!links.count){
			[TGAlertSheet showMessage:@"An error occurred."
								title:@"Invite Links" inView:me.view];
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *link in links)
			[rows addObject:[NSString stringWithFormat:@"%@%@  ·  %@ joined",
					[link[@"revoked"] boolValue] ? @"(revoked) " : @"",
					link[@"link"], link[@"members"] ?: @(0)]];
		[rows addObject:@"Invite Links"];
		[rows addObject:@"Delete All Revoked Links"];

		[TGPresent showList:rows title:@"Invite Links" destructiveIndex:(NSInteger)rows.count - 1
			from:me onPick:^(NSInteger index){
			if (index == (NSInteger)links.count){
				[me showInviteLinkCounts];
				return;
			}
			if (index == (NSInteger)links.count + 1){
				[me deleteAllRevokedLinks];
				return;
			}
			[me showActionsForInviteLink:links[(NSUInteger)index] inChat:chatId];
		}];
	}];
}

- (void)showActionsForInviteLink:(NSDictionary *)link inChat:(int64_t)chatId {
	NSString *url = link[@"link"];
	if (!url.length)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGGroupStore shared] inviteLink:url inChat:chatId completion:^(NSDictionary *info){
		TGGroupSettingsViewController *me = weakSelf;
		NSDictionary *fresh = info ?: link;
		BOOL primary = [fresh[@"primary"] boolValue];
		BOOL revoked = [fresh[@"revoked"] boolValue];
		id subscriptionValue = fresh[@"subscription"];
		BOOL subscription = subscriptionValue &&
				subscriptionValue != [NSNull null];
		NSMutableArray *choices = [NSMutableArray arrayWithObject:@"Copy Link"];
		[choices addObject:@"Members"];
		if (!revoked)
			[choices addObject:subscription ? @"Rename Link"
											: @"Edit Name & Limit"];
		[choices addObject:(revoked ? @"Delete Link"
									: (primary ? @"Replace" : @"Revoke"))];
		[TGPresent showMenuTitles:choices destructiveIndex:-1
			fromView:nil onController:me onChoice:^(NSInteger index){
			NSString *action = choices[(NSUInteger)index];
			if ([action isEqualToString:@"Copy Link"]){
				[UIPasteboard generalPasteboard].string = url;
				[TGAlertSheet showMessage:@"Link copied." title:nil inView:me.view];
				return;
			}
			if ([action isEqualToString:@"Members"]){
				[me showMembersOfInviteLink:url inChat:chatId];
				return;
			}
			if ([action isEqualToString:@"Rename Link"]){
				[TGAlertSheet showInput:@"Name This Link" message:nil
							placeholder:@"Name" text:fresh[@"name"] ?: @""
								 action:@"Save" inView:me.view
							 onSubmit:^(NSString *name){
					[[TGGroupStore shared] editSubscriptionInviteLink:url inChat:chatId
							name:name completion:^(BOOL ok){
						[TGAlertSheet showMessage:(ok ? @"Link updated"
											   : @"An error occurred while updating the link")
											title:@"Invite Link" inView:me.view];
					}];
				}];
				return;
			}
			if ([action isEqualToString:@"Edit Name & Limit"]){
				[TGAlertSheet showInput:@"Edit Link"
								message:nil
							placeholder:@"Name" text:fresh[@"name"] ?: @""
								 action:@"Next" inView:me.view
							 onSubmit:^(NSString *name){
					[TGAlertSheet showConfirm:@"Set a member limit?"
										title:@"Member Limit"
									   action:@"Set Limit"
								  destructive:NO
									   inView:me.view
									onConfirm:^{
						[TGAlertSheet showInput:@"Member Limit" message:nil
									placeholder:@"No Limit" text:@"0"
										 action:@"Save" inView:me.view
									 onSubmit:^(NSString *limitText){
							[[TGGroupStore shared] editInviteLink:url inChat:chatId
									name:name expiration:0
									memberLimit:limitText.integerValue
									joinRequest:NO completion:^(BOOL ok){
								[TGAlertSheet showMessage:(ok ? @"Link updated"
															   : @"An error occurred while updating the link")
														title:@"Invite Link" inView:me.view];
							}];
						}];
					}];
				}];
				return;
			}
			if ([action isEqualToString:@"Delete Link"]){
				[[TGGroupStore shared] deleteRevokedInviteLink:url inChat:chatId
											 completion:^(BOOL ok){
					[TGAlertSheet showMessage:(ok ? @"The invite link has been revoked."
												   : @"An error occurred.")
											title:@"Invite Link" inView:me.view];
					[me showAllInviteLinks];
				}];
				return;
			}
			NSString *warn = primary
					? @"The common link stops working and a new one takes its place."
					: @"The link above stops working at once, and it does not come back.";
			[TGAlertSheet showConfirm:warn title:url
							   action:(primary ? @"Replace" : @"Revoke")
						  destructive:YES inView:me.view onConfirm:^{
				if (primary){
					[[TGGroupStore shared] replacePrimaryInviteLinkForChat:chatId
														 completion:^(NSString *made){
						[TGAlertSheet showMessage:(made.length ? made
								: @"An error occurred.")
												title:@"Invite Link" inView:me.view];
					}];
					return;
				}
				[[TGGroupStore shared] revokeInviteLink:url inChat:chatId
										 completion:^(BOOL ok){
					if (!ok)
						[TGAlertSheet showMessage:@"An error occurred."
											title:@"Revoke" inView:me.view];
					else
						[me showAllInviteLinks];
				}];
			}];
		}];
	}];
}

/// The joined date follows the app language, not the device locale: a Russian
/// UI should not print an English month.
static NSString *TGInviteLinkDateText(NSDate *date) {
	return TGAppDate(date.timeIntervalSince1970, NSDateFormatterMediumStyle,
			NSDateFormatterNoStyle);
}

- (void)showMembersOfInviteLink:(NSString *)url inChat:(int64_t)chatId {
	__weak typeof(self) weakSelf = self;
	[[TGGroupStore shared] membersOfInviteLink:url inChat:chatId
								completion:^(NSArray *members){
		TGGroupSettingsViewController *me = weakSelf;
		if (!members.count){
			[TGAlertSheet showMessage:@"No one joined yet"
								title:@"Members" inView:me.view];
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *member in members){
			NSDate *date = [NSDate dateWithTimeIntervalSince1970:
					[member[@"date"] doubleValue]];
			NSString *when = TGInviteLinkDateText(date);
			[rows addObject:[NSString stringWithFormat:@"%@ · %@",
					member[@"name"] ?: @"Member",
					TGLocalizedFormat(@"joined %@", when)]];
		}
		[TGPresent showList:rows title:@"Members" destructiveIndex:-1
			from:me onPick:^(NSInteger index){
			if (index < 0 || index >= (NSInteger)members.count)
				return;
			[TGGroupMemberActions openProfileForMember:members[(NSUInteger)index]
												  from:me];
		}];
	}];
}

- (void)showInviteLinkCounts {
	__weak typeof(self) weakSelf = self;
	[[TGGroupStore shared] inviteLinkCountsForChat:self.chatId completion:^(NSArray *counts){
		TGGroupSettingsViewController *me = weakSelf;
		if (!counts.count){
			[TGAlertSheet showMessage:@"An error occurred."
								title:@"Invite Links" inView:me.view];
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *count in counts)
			[rows addObject:[NSString stringWithFormat:@"%@: %@ active, %@ revoked",
					count[@"name"] ?: @"Admin",
					count[@"active"] ?: @(0), count[@"revoked"] ?: @(0)]];
		[TGPresent showList:rows title:@"Invite Links" destructiveIndex:-1
			from:me onPick:^(NSInteger index){
			(void)index;
		}];
	}];
}

/// A monthly Star subscription in a channel, which is the one invite link
/// shape that carries a price rather than a member limit.
- (void)createSubscriptionLink {
	int64_t chatId = self.chatId;
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Subscription"
					message:nil
				placeholder:@"Link Name (Optional)" text:nil action:@"Create"
					 inView:self.view onSubmit:^(NSString *name){
		[TGAlertSheet showInput:@"Subscription Fee" message:nil
					placeholder:@"1" text:@"1" action:@"Create"
					 inView:weakSelf.view onSubmit:^(NSString *stars){
			[[TGGroupStore shared] createSubscriptionInviteLink:chatId name:name
					stars:MAX(stars.integerValue, 1) period:2592000
					completion:^(NSString *link){
				[TGAlertSheet showMessage:(link.length ? link
						: @"An error occurred.")
									title:@"Subscription" inView:weakSelf.view];
			}];
		}];
	}];
}

- (void)deleteAllRevokedLinks {
	int64_t myId = [[TGProfileStore shared].me[@"id"] longLongValue];
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:@"This will delete all revoked links."
						title:@"Delete All Revoked Links"
					   action:@"Delete" destructive:YES inView:self.view
					onConfirm:^{
		[[TGGroupStore shared] deleteAllRevokedInviteLinks:weakSelf.chatId creator:myId
				completion:^(BOOL ok){
			[TGAlertSheet showMessage:(ok ? @"The invite link has been revoked."
										   : @"An error occurred.")
								title:@"Invite Links" inView:weakSelf.view];
		}];
	}];
}


@end
