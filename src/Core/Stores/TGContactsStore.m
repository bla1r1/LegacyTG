//
// TGContactsStore.m - the Contacts requests, in one place.
//
#import "TGContactsStore.h"
#import "TGClient.h"
#import "TGClientInternal.h"

@implementation TGContactsStore

+ (instancetype)shared {
	static TGContactsStore *store = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ store = [[TGContactsStore alloc] init]; });
	return store;
}

#pragma mark - the address book

- (void)contactsWithCompletion:(void (^)(NSArray *))completion {
	[[TGClient shared] request:@{@"@type" : @"getContacts"} completion:^(NSDictionary *result){
		NSArray *ids = result[@"user_ids"];
		if (![ids isKindOfClass:NSArray.class]){
			if (completion) completion(@[]);
			return;
		}

		// Fetch each user; finish when the last one answers.
		NSMutableArray *users = [NSMutableArray array];
		__block NSUInteger left = ids.count;
		if (!left){
			if (completion) completion(@[]);
			return;
		}
		for (NSNumber *uid in ids){
			[[TGClient shared] request:@{@"@type" : @"getUser", @"user_id" : uid}
				   completion:^(NSDictionary *u){
				if ([u[@"@type"] isEqualToString:@"user"]){
					// The photo id travels with the row, so the list can show a
					// face rather than a letter for everyone who has one.
					[[TGClient shared] cacheProfilePhoto:u];
					[users addObject:@{
						@"id"          : u[@"id"] ?: @(0),
						@"first_name"  : u[@"first_name"] ?: @"",
						@"last_name"   : u[@"last_name"] ?: @"",
						@"phone"       : u[@"phone_number"] ?: @"",
						@"username"    : ([u[@"usernames"][@"active_usernames"] isKindOfClass:[NSArray class]] && [u[@"usernames"][@"active_usernames"] count] > 0) ? u[@"usernames"][@"active_usernames"][0] : (u[@"username"] ?: @""),
						@"photoFileId" : u[@"profile_photo"][@"small"][@"id"] ?: [NSNull null],
						@"status"      : u[@"status"] ?: [NSNull null],
					}];
				}
				if (--left == 0 && completion)
					completion(users);
			}];
		}
	}];
}

- (void)importedContactCountWithCompletion:(void (^)(NSInteger))completion {
	[[TGClient shared] request:@{@"@type" : @"getImportedContactCount"}
	   completion:^(NSDictionary *result){
		NSInteger count = 0;
		if ([result isKindOfClass:NSDictionary.class] &&
			![result[@"@type"] isEqualToString:@"error"])
			count = [result[@"count"] integerValue];
		if (completion) completion(count);
	}];
}

#pragma mark - making and renaming a contact

- (void)addContactWithUserId:(int64_t)userId
				   firstName:(NSString *)firstName
					lastName:(NSString *)lastName
					   phone:(NSString *)phone
				  completion:(void (^)(BOOL))completion {
	[[TGClient shared] request:@{
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

- (void)importContactNamed:(NSString *)firstName
				  lastName:(NSString *)lastName
					 phone:(NSString *)phone
				completion:(void (^)(int64_t))completion {
	NSString *who = [firstName ?: @"" stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSString *number = [phone ?: @"" stringByReplacingOccurrencesOfString:@" "
															   withString:@""];
	if (!who.length || !number.length){
		if (completion) completion(0);
		return;
	}
	[[TGClient shared] request:@{
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

#pragma mark - the group picker

- (void)addUser:(int64_t)userId
		 toChat:(int64_t)chatId
	 completion:(void (^)(BOOL, NSArray *))completion {
	[[TGClient shared] request:@{
		@"@type"         : @"addChatMember",
		@"chat_id"       : @(chatId),
		@"user_id"       : @(userId),
		@"forward_limit" : @(100),
	} completion:^(NSDictionary *result){
		if (!completion)
			return;
		NSMutableArray *failed = [NSMutableArray array];
		for (NSDictionary *entry in result[@"failed_to_add_members"])
			if (entry[@"user_id"])
				[failed addObject:entry[@"user_id"]];
		BOOL errored = [result[@"@type"] isEqualToString:@"error"];
		completion(!errored && failed.count == 0, failed);
	}];
}

- (void)addUsers:(NSArray *)userIds
		  toChat:(int64_t)chatId
	  completion:(void (^)(BOOL, NSArray *))completion {
	if (!userIds.count){
		if (completion) completion(NO, @[]);
		return;
	}
	[[TGClient shared] request:@{
		@"@type"         : @"addChatMembers",
		@"chat_id"       : @(chatId),
		@"user_ids"      : userIds,
		@"forward_limit" : @(100),
	} completion:^(NSDictionary *result){
		if (!completion)
			return;
		NSMutableArray *failed = [NSMutableArray array];
		for (NSDictionary *entry in result[@"failed_to_add_members"])
			if (entry[@"user_id"])
				[failed addObject:entry[@"user_id"]];
		BOOL errored = [result[@"@type"] isEqualToString:@"error"];
		completion(!errored && failed.count == 0, failed);
	}];
}

- (void)createGroupNamed:(NSString *)title
			   withUsers:(NSArray *)userIds
			  completion:(void (^)(int64_t, NSArray *))completion {
	if (!title.length || !userIds.count){
		if (completion) completion(0, userIds ?: @[]);
		return;
	}
	[[TGClient shared] request:@{
		@"@type"                    : @"createNewBasicGroupChat",
		@"user_ids"                 : userIds,
		@"title"                    : title,
		@"message_auto_delete_time" : @(0),
	} completion:^(NSDictionary *result){
		if (!completion)
			return;
		// Someone whose privacy settings refuse group invitations is reported
		// rather than silently missing from the new group.
		NSMutableArray *failed = [NSMutableArray array];
		for (NSDictionary *entry in result[@"failed_to_add_members"][@"failed_to_add_members"])
			if (entry[@"user_id"])
				[failed addObject:entry[@"user_id"]];
		completion([result[@"chat_id"] longLongValue], failed);
	}];
}

@end
