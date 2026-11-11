#import "TGClient+ChatContacts.h"
#import "TGClientInternal.h"
#ifndef typeof
#define typeof __typeof__
#endif


@implementation TGClient (ChatContacts)

#pragma mark - contacts

/// A contact Telegram has never met. addContact matches on the phone number,
/// and a number nobody here has met yet has no user id to hand it - so the
/// import is what makes the user, and the id it hands back is what the
/// contact is finished with.
/// A number back in the block list. The sender is spelled as a user rather
/// than as a chat id, which is what the report path has to do for a group.
- (void)blockUserWithUserId:(int64_t)userId {
	if (!userId)
		return;
	[self send:@{
		@"@type"     : @"setMessageSenderBlockList",
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @(userId)},
		@"block_list": @{@"@type" : @"blockListMain"},
	}];
}

/// Your phone number to a mutual contact, on their offer to share it.
- (void)sharePhoneNumberWithUser:(int64_t)userId {
	if (!userId)
		return;
	[self send:@{@"@type" : @"sharePhoneNumber", @"user_id" : @(userId)}];
}

/// Adds someone to your Telegram contacts. The phone number is what the
/// server matches on; without one it only renames an existing contact.
/// Takes someone out of your contacts. The chat with them stays.
@end
