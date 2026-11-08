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
- (void)importContactNamed:(NSString *)firstName
				  lastName:(NSString *)lastName
					 phone:(NSString *)phone
				completion:(void (^)(int64_t userId))completion {
	NSString *who = [firstName ?: @"" stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSString *number = [phone ?: @"" stringByReplacingOccurrencesOfString:@" "
															   withString:@""];
	if (!who.length || !number.length){
		if (completion) completion(0);
		return;
	}
	[self request:@{
		@"@type"    : @"importContacts",
		@"contacts" : @[@{
			@"@type"        : @"importedContact",
			@"phone_number" : number,
			@"first_name"   : who,
			@"last_name"    : [lastName ?: @"" stringByTrimmingCharactersInSet:
							 [NSCharacterSet whitespaceAndNewlineCharacterSet]],
			@"note"         : @{@"@type" : @"formattedText", @"text" : @""},
		}],
	} completion:^(NSDictionary *result){
		if (completion)
			completion([result[@"user_ids"] count]
					? [result[@"user_ids"][0] longLongValue] : 0);
	}];
}

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
- (void)addContactWithUserId:(int64_t)userId
				   firstName:(NSString *)firstName
					lastName:(NSString *)lastName
					   phone:(NSString *)phone
				  completion:(void (^)(BOOL ok))completion {
	[self request:@{
		@"@type"   : @"addContact",
		@"user_id" : @(userId),
		@"contact" : @{
			@"@type"           : @"importedContact",
			@"phone_number"    : phone ?: @"",
			@"first_name"      : firstName ?: @"",
			@"last_name"       : lastName ?: @"",
			@"note"            : @{@"@type" : @"formattedText", @"text" : @""},
		},
		@"share_phone_number" : @NO,
	} completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}

/// Takes someone out of your contacts. The chat with them stays.
- (void)removeContactWithUserId:(int64_t)userId completion:(void (^)(BOOL ok))completion {
	[self request:@{@"@type" : @"removeContacts", @"user_ids" : @[@(userId)]}
	   completion:^(NSDictionary *result){
		if (completion)
			completion([result[@"@type"] isEqualToString:@"ok"]);
	}];
}

@end
