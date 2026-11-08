//
// TGGroupMemberActions.m - the member sheet, moved out of the profile.
//
// Which rows appear is decided by getChatAdministrators rather than guessed:
// a plain member's menu must not list things that will be refused, and the
// owner's must not hide the handover.
//
#import "TGGroupMemberActions.h"
#import "TGClient.h"
#import "TGAlertSheet.h"
#import "TGChatViewController.h"
#import "TGProfileViewController.h"
#import "TGLocalization.h"

/// Pushes `controller` when the host is on a navigation stack; otherwise
/// wraps it in one and presents that. A profile opened from a popover or a
/// modal has no stack to push onto, and pushing nil there is the silent tap
/// this exists to remove. The Done button is kept alive with the wrapper.
@interface TGControllerDismisser : NSObject
@property (nonatomic, weak) UIViewController *wrapper;
@end

static NSMutableArray *sDismissers;

@implementation TGControllerDismisser
- (void)close:(id)sender {
	UIViewController *me = self.wrapper;
	[me dismissViewControllerAnimated:YES completion:nil];
	[sDismissers removeObject:self];
}
@end

void TGPresentControllerFrom(UIViewController *controller, UIViewController *host) {
	if (!controller || !host)
		return;
	UINavigationController *stack = host.navigationController;
	if (stack){
		[stack pushViewController:controller animated:YES];
		return;
	}
	NSLog(@"TGPresentControllerFrom: %@ has no navigation stack; presenting",
		  NSStringFromClass(host.class));
	UINavigationController *wrapper = [[UINavigationController alloc]
			initWithRootViewController:controller];
	TGControllerDismisser *closer = [[TGControllerDismisser alloc] init];
	closer.wrapper = wrapper;
	if (!sDismissers)
		sDismissers = [NSMutableArray array];
	[sDismissers addObject:closer];
	if (!controller.navigationItem.leftBarButtonItem)
		controller.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
				initWithBarButtonSystemItem:UIBarButtonSystemItemDone
									 target:closer action:@selector(close:)];
	[host presentViewController:wrapper animated:YES completion:nil];
}

@interface TGGroupMemberActions ()
+ (void)runAction:(NSString *)action
		   onUser:(int64_t)userId
			named:(NSString *)name
		   inChat:(int64_t)chatId
			 from:(UIViewController *)host
		onChanged:(void (^)(void))onChanged;
+ (void)showRecordFor:(int64_t)userId
				named:(NSString *)name
			   inChat:(int64_t)chatId
				 from:(UIViewController *)host;
@end

@implementation TGGroupMemberActions

+ (void)openProfileForMember:(NSDictionary *)member from:(UIViewController *)host {
	if (!host)
		return;
	int64_t userId = [member[@"id"] longLongValue];
	if (!userId){
		NSLog(@"TGGroupMemberActions: member has no user id, cannot open profile");
		return;
	}
	NSString *name = [member[@"name"] length] ? member[@"name"]
			: [[TGClient shared] nameForUserId:userId];
	TGProfileViewController *profile = [[TGProfileViewController alloc]
			initWithChatId:userId userId:userId title:name ?: @""];
	if (!profile){
		NSLog(@"TGGroupMemberActions: could not create a profile for user %lld",
			  userId);
		return;
	}
	profile.hidesBottomBarWhenPushed = YES;
	TGPresentControllerFrom(profile, host);
}

+ (void)showForMember:(NSDictionary *)member
			   inChat:(int64_t)chatId
				 from:(UIViewController *)host
			onChanged:(void (^)(void))onChanged {
	if (!host)
		return;
	int64_t userId = [member[@"id"] longLongValue];
	NSString *name = [member[@"name"] length] ? member[@"name"]
			: [[TGClient shared] nameForUserId:userId];
	if (!userId)
		return;

	__weak UIViewController *weakHost = host;
	[[TGClient shared] administratorsOfChat:chatId completion:^(NSArray *admins){
		UIViewController *me = weakHost;
		if (!me)
			return;

		int64_t myId = [[TGClient shared].me[@"id"] longLongValue];
		BOOL iCanEdit = NO, iAmOwner = NO, theyAreAdmin = NO;
		for (NSDictionary *admin in admins){
			int64_t adminId = [admin[@"id"] longLongValue];
			if (adminId == myId){
				iCanEdit = [admin[@"owner"] boolValue] ||
						   [admin[@"editable"] boolValue];
				iAmOwner = [admin[@"owner"] boolValue];
			}
			if (adminId == userId)
				theyAreAdmin = YES;
		}

		NSMutableArray *choices = [NSMutableArray arrayWithObject:@"Send Message"];
		if (iCanEdit){
			[choices addObject:@"Add Member Tag"];
			[choices addObject:theyAreAdmin ? @"Dismiss Admin" : @"Promote"];
			[choices addObject:@"Remove"];
		}

		[TGAlertSheet showChoices:choices
							title:name.length ? name : @"Member"
				 destructiveIndex:(iCanEdit
						 ? (NSInteger)[choices indexOfObject:@"Remove"] : -1)
						   inView:me.view
						 onChoice:^(NSInteger index){
			[self runAction:choices[(NSUInteger)index]
					 onUser:userId named:name inChat:chatId
					   from:me onChanged:onChanged];
		}];
	}];
}

+ (void)runAction:(NSString *)action
		   onUser:(int64_t)userId
			named:(NSString *)name
		   inChat:(int64_t)chatId
			 from:(UIViewController *)host
		onChanged:(void (^)(void))onChanged {
	__weak UIViewController *weakHost = host;
	void (^report)(BOOL) = ^(BOOL ok){
		UIViewController *me = weakHost;
		if (!ok){
			[TGAlertSheet showMessage:@"An error occurred."
								title:action inView:me.view];
			return;
		}
		if (onChanged)
			onChanged();
	};

	if ([action isEqualToString:@"Member Info"]){
		// A person, not a conversation: this opens their profile. Send
		// Message is the row that opens a chat, and only it does.
		[self openProfileForMember:@{@"id" : @(userId), @"name" : name ?: @""}
							  from:host];
		return;

	} else if ([action isEqualToString:@"Member Details"]){
		[self showRecordFor:userId named:name inChat:chatId from:host];
		return;

	} else if ([action isEqualToString:@"Send Message"]){
		// The check before the push: a user who takes no messages from
		// non-contacts turns the composer into a doomed one.
		[[TGClient shared] canSendMessageToUser:userId completion:^(NSString *result){
			UIViewController *me = weakHost;
			if (!me)
				return;
			if ([result isEqualToString:@"ok"]){
				[[TGClient shared] privateChatWithUser:userId completion:^(int64_t privateId){
					UIViewController *again = weakHost;
					if (!again || !privateId)
						return;
					TGChatViewController *chat = [[TGChatViewController alloc] init];
					chat.chatId = privateId;
					chat.chatTitle = name ?: @"";
					chat.hidesBottomBarWhenPushed = YES;
					[again.navigationController pushViewController:chat animated:YES];
				}];
				return;
			}
			NSString *say = [result isEqualToString:@"paidMessages"]
					? @"An error occurred."
					: ([result isEqualToString:@"userRestrictsNewChats"]
					   ? @"An error occurred."
					   : @"An error occurred.");
			[TGAlertSheet showMessage:say
								title:name.length ? name : @"Message"
							   inView:me.view];
		}];
		return;

	} else if ([action isEqualToString:@"Make Admin"] ||
			   [action isEqualToString:@"Promote"]){
		[[TGClient shared] setMember:userId inChat:chatId status:@"administrator"
						  completion:report];

	} else if ([action isEqualToString:@"Dismiss Admin"]){
		[[TGClient shared] setMember:userId inChat:chatId status:@"member"
						  completion:report];

	} else if ([action isEqualToString:@"Add Member Tag"] ||
			   [action isEqualToString:@"Add Rank"]){
		[TGAlertSheet showInput:@"Member Tag"
						message:nil
					placeholder:@"Tag" text:nil action:@"Save" inView:host.view
					 onSubmit:^(NSString *tag){
			[[TGClient shared] setMemberTag:tag forUser:userId inChat:chatId
					completion:^(BOOL ok){
				UIViewController *me = weakHost;
				[TGAlertSheet showMessage:(ok ? @"Tag edited"
											   : @"An error occurred.")
									title:@"Member Tag" inView:me.view];
				if (ok && onChanged)
					onChanged();
			}];
		}];

	} else if ([action isEqualToString:@"Delete All Reactions"]){
		NSDictionary *sender = @{@"@type" : @"messageSenderUser", @"user_id" : @(userId)};
		[TGAlertSheet showConfirm:
				@"Delete All Reactions"
					title:(name.length ? name : @"Member")
						   action:@"Clear"
					  destructive:YES
						   inView:host.view
						onConfirm:^{
			[[TGClient shared] deleteAllReactionsOfSender:sender inChat:chatId];
		}];

	} else if ([action isEqualToString:@"Delete All Messages"]){
		NSDictionary *sender = @{@"@type" : @"messageSenderUser", @"user_id" : @(userId)};
		[TGAlertSheet showConfirm:
				@"Delete All Messages"
					title:(name.length ? name : @"Member")
						   action:@"Clear"
					  destructive:YES
						   inView:host.view
						onConfirm:^{
			[[TGClient shared] deleteChatMessagesBySender:sender
												   inChat:chatId
												   revoke:YES];
		}];

	} else if ([action isEqualToString:@"Remove"]){
		[[TGClient shared] setMember:userId inChat:chatId status:@"left"
						  completion:report];

	} else if ([action isEqualToString:@"Ban"]){
		[TGAlertSheet showConfirm:[NSString stringWithFormat:
						@"Ban %@",
						name.length ? name : @"They"]
							title:@"Ban"
						   action:@"Ban"
					  destructive:YES
						   inView:host.view
						onConfirm:^{
			[[TGClient shared] banMember:userId inChat:chatId
						  revokeMessages:NO completion:report];
		}];

	} else if ([action isEqualToString:@"Transfer Group Ownership"]){
		// Ownership leaves this account entirely, and TDLib demands the 2FA
		// password for it.
		[TGAlertSheet showConfirm:@"Transfer Group Ownership"
							title:@"Transfer Group Ownership"
						   action:@"Transfer Group Ownership"
					  destructive:NO
						   inView:host.view
						onConfirm:^{
			// Telegram decides whether this session may hand a chat over at
			// all. The pre-check is shown before the password is asked for,
			// because a session that is too new cannot proceed either way.
			[[TGClient shared] canTransferOwnershipWithCompletion:
					^(NSString *result, NSInteger retryAfter, NSString *error){
				(void)retryAfter;
				UIViewController *me = weakHost;
				if (!me)
					return;
				if (error){
					[TGAlertSheet showMessage:error
										title:@"Transfer Group Ownership"
									   inView:me.view];
					return;
				}
				if ([result isEqualToString:@"passwordTooFresh"] ||
						[result isEqualToString:@"sessionTooFresh"]){
					[TGAlertSheet showMessage:@"An error occurred."
										title:@"Transfer Group Ownership"
									   inView:me.view];
					return;
				}
				[[TGClient shared] hasPasswordWithCompletion:
						^(BOOL has, NSString *email){
					void (^hand)(NSString *) = ^(NSString *password){
						[[TGClient shared] transferOwnershipOfChat:chatId
															 toUser:userId
														   password:password
														 completion:report];
					};
					if (!has){
						hand(@"");
						return;
					}
					UIViewController *again = weakHost;
					[TGAlertSheet showSecureInput:@"Your Password"
										  message:nil
									  placeholder:@"Password"
										   action:@"Transfer Group Ownership"
										   inView:again.view
									 onSubmit:hand];
				}];
			}];
		}];
	}
}

/// One member's own record: the status word, the title this group gave them,
/// and when a restriction lifts. getChatMember is the only request that
/// answers for one person, and the sheet is the only place the raw details
/// are shown - Member Info itself opens the person's profile.
+ (void)showRecordFor:(int64_t)userId
				named:(NSString *)name
			   inChat:(int64_t)chatId
				 from:(UIViewController *)host {
	__weak UIViewController *weakHost = host;
	[[TGClient shared] chatMember:userId inChat:chatId completion:^(NSDictionary *member){
		UIViewController *me = weakHost;
		if (!me)
			return;
		NSString *sheetTitle = name.length ? name : @"Member";
		if (!member){
			[TGAlertSheet showMessage:@"An error occurred."
								  title:sheetTitle inView:me.view];
			return;
		}

		NSDictionary *status = [member[@"status"] isKindOfClass:NSDictionary.class]
				? member[@"status"] : @{};
		NSMutableArray *lines = [NSMutableArray array];
		[lines addObject:[NSString stringWithFormat:@"%@: %@",
						  TGLocalized(@"Status"),
						  TGMemberStatusName(status)]];
		if ([member[@"tag"] length])
			[lines addObject:TGLocalizedFormat(@"Title: %@", member[@"tag"])];

		double until = [status[@"restricted_until_date"] doubleValue];
		if (until > 0)
			[lines addObject:TGLocalizedFormat(@"until %@",
					[NSDateFormatter localizedStringFromDate:
							[NSDate dateWithTimeIntervalSince1970:until]
							dateStyle:NSDateFormatterMediumStyle
							timeStyle:NSDateFormatterNoStyle])];

		NSDictionary *permissions =
				[status[@"permissions"] isKindOfClass:NSDictionary.class]
				? status[@"permissions"] : nil;
		id send = permissions[@"can_send_basic_messages"]
				?: permissions[@"can_send_messages"];
		if (send)
			[lines addObject:[NSString stringWithFormat:@"%@: %@",
							  TGLocalized(@"Send Messages"),
							  [send boolValue] ? TGLocalized(@"Yes")
											   : TGLocalized(@"No")]];

		[TGAlertSheet showMessage:[lines componentsJoinedByString:@"\n"]
							 title:sheetTitle inView:me.view];
	}];
}

@end
