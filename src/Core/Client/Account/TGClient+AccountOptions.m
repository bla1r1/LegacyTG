#import "TGClientInternal.h"
#import "TGStatusText.h"
#import "TGGiftFlatten.h"
#import "TGClient+AccountOptions.h"
#import "TGClient+AccountSupport.h"


/// Defined with the autosave reads below; the update branch above it only
/// needs the same flattening so both paths produce one row shape.
static NSDictionary *TGFlattenAutosaveScope(NSDictionary *settings);

/// TDLib names the three scopes; the app names them shortly.
static NSString *TGScopeType(NSString *scope) {
	if ([scope isEqualToString:@"groups"])   return @"notificationSettingsScopeGroupChats";
	if ([scope isEqualToString:@"channels"]) return @"notificationSettingsScopeChannelChats";
	return @"notificationSettingsScopePrivateChats";
}

/// Kept as a compatibility call into the pure gift flattening utility.
static NSDictionary *TGFlattenGift(NSDictionary *entry) {
	return TGFlattenReceivedGift(entry);
}


static NSArray *TGPacksFrom(NSDictionary *target) {
	NSMutableArray *out = [NSMutableArray array];
	for (NSDictionary *pack in target[@"language_packs"]){
		if (![pack[@"id"] length])
			continue;
		[out addObject:@{@"id"   : pack[@"id"],
						 @"name" : pack[@"native_name"] ?: pack[@"name"] ?: pack[@"id"]}];
	}
	return out;
}





@implementation TGClient (AccountOptions)

#pragma mark - options

- (void)optionValue:(NSString *)name completion:(void (^)(id))completion {
	[self request:@{@"@type" : @"getOption", @"name" : name}
	   completion:^(NSDictionary *option){
		if (completion) completion(option[@"value"]);
	}];
}

- (void)setOption:(NSString *)name boolValue:(BOOL)value {
	[self send:@{
		@"@type" : @"setOption",
		@"name"  : name,
		@"value" : @{@"@type" : @"optionValueBoolean", @"value" : @(value)},
	}];
}

/// Fetches profile stories (pinned profile stories falling back to active 24h stories).
- (void)storiesForChat:(int64_t)chatId completion:(void (^)(NSArray *))completion {
	__weak typeof(self) weakSelf = self;

	void (^flattenAll)(NSArray *) = ^(NSArray *stories){
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *story in stories)
			if ([story isKindOfClass:NSDictionary.class])
				[out addObject:TGFlattenStory(story)];
		if (completion) completion(out);
	};

	[self request:@{
		@"@type"         : @"getChatPostedToChatPageStories",
		@"chat_id"       : @(chatId),
		@"from_story_id" : @(0),
		@"limit"         : @(20),
	} completion:^(NSDictionary *posted){
		NSArray *stories = posted[@"stories"];
		if ([stories count]){
			flattenAll(stories);
			return;
		}

		// Nothing kept on the page: the active list needs each story fetched
		// by id, because it only carries the ids.
		[weakSelf request:@{@"@type" : @"getChatActiveStories", @"chat_id" : @(chatId)}
			   completion:^(NSDictionary *active){
			NSArray *infos = active[@"stories"];
			if (![infos count]){
				if (completion) completion(@[]);
				return;
			}

			NSMutableArray *collected = [NSMutableArray array];
			__block NSUInteger outstanding = infos.count;
			for (NSDictionary *info in infos){
				[weakSelf request:@{
					@"@type"                : @"getStory",
					@"story_sender_chat_id" : @(chatId),
					@"story_id"             : info[@"story_id"] ?: @(0),
					@"only_local"           : @NO,
				} completion:^(NSDictionary *story){
					if ([story[@"@type"] isEqualToString:@"story"])
						[collected addObject:TGFlattenStory(story)];
					if (--outstanding == 0 && completion)
						completion(collected);
				}];
			}
		}];
	}];
}

/// Their Edit Profile has a birthday row; TDLib keeps it as three numbers and
/// a zero day means it is not set. Year is optional, which is why it is only
/// written when it is there.
- (void)setBirthdayDay:(NSInteger)day month:(NSInteger)month year:(NSInteger)year
			completion:(void (^)(BOOL, NSString *))completion {
	if (day <= 0){
		[self request:@{@"@type" : @"setBirthdate", @"birthdate" : [NSNull null]}
		   completion:^(NSDictionary *result){
			BOOL failed = [result[@"@type"] isEqualToString:@"error"];
			if (completion)
				completion(!failed, failed ? (result[@"message"] ?: @"An error occurred.") : nil);
		}];
		return;
	}
	NSMutableDictionary *birthdate = [@{
		@"@type" : @"birthdate",
		@"day"   : @(day),
		@"month" : @(month),
	} mutableCopy];
	if (year > 0)
		birthdate[@"year"] = @(year);
	[self request:@{@"@type" : @"setBirthdate", @"birthdate" : birthdate}
	   completion:^(NSDictionary *result){
		BOOL failed = [result[@"@type"] isEqualToString:@"error"];
		if (completion)
			completion(!failed, failed ? (result[@"message"] ?: @"An error occurred.") : nil);
	}];
}

/// The signed-in account's own birthday as TDLib stores it: "day", "month",
/// "year" (0 when unset).
- (void)myBirthdayWithCompletion:(void (^)(NSInteger, NSInteger, NSInteger))completion {
	[self request:@{@"@type"   : @"getUserFullInfo",
					@"user_id" : self.me[@"id"] ?: @0}
	   completion:^(NSDictionary *full){
		NSDictionary *birth = full[@"birthdate"];
		if (completion)
			completion([birth[@"day"] integerValue], [birth[@"month"] integerValue],
					   [birth[@"year"] integerValue]);
	}];
}

/// Their profile page leads with this, and there was no way to set a picture
/// from the app at all - only to look at one already set from another client.
- (void)setProfilePhotoAtPath:(NSString *)path completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"setProfilePhoto",
		@"photo" : @{@"@type" : @"inputChatPhotoStatic",
					 @"photo" : @{@"@type" : @"inputFileLocal", @"path" : path ?: @""}},
		// This path changes the main photo, not the public fallback.
		@"is_public" : @NO,
	} completion:^(NSDictionary *result){
		BOOL ok = ![result[@"@type"] isEqualToString:@"error"];
		if (!ok)
			NSLog(@"setProfilePhoto: %@", result[@"message"]);
		if (completion) completion(ok);
	}];
}

- (void)clearImportedContacts {
	[self send:@{@"@type" : @"clearImportedContacts"}];
}

- (void)importedContactCountWithCompletion:(void (^)(NSInteger))completion {
	[self request:@{@"@type" : @"getImportedContactCount"}
	   completion:^(NSDictionary *result){
		NSInteger count = 0;
		if ([result isKindOfClass:NSDictionary.class] &&
			![result[@"@type"] isEqualToString:@"error"])
			count = [result[@"count"] integerValue];
		if (completion) completion(count);
	}];
}

- (void)changeImportedContacts:(NSArray *)contacts
					completion:(void (^)(NSInteger, NSArray *))completion {
	NSMutableArray *rows = [NSMutableArray array];
	for (NSDictionary *contact in contacts){
		if (![contact isKindOfClass:NSDictionary.class])
			continue;
		NSString *phone = contact[@"phone_number"] ?: @"";
		if (!phone.length)
			continue;
		[rows addObject:@{
			@"@type"        : @"importedContact",
			@"phone_number" : phone,
			@"first_name"   : contact[@"first_name"] ?: @"",
			@"last_name"    : contact[@"last_name"] ?: @"",
			@"note"         : [NSNull null],
		}];
	}
	[self request:@{@"@type" : @"changeImportedContacts", @"contacts" : rows}
	   completion:^(NSDictionary *result){
		NSArray *userIds = result[@"user_ids"];
		if (![userIds isKindOfClass:NSArray.class])
			userIds = @[];
		if (completion) completion((NSInteger)userIds.count, userIds);
	}];
}

- (void)applicationDownloadLinkWithCompletion:(void (^)(NSString *))completion {
	[self request:@{@"@type" : @"getApplicationDownloadLink"}
	   completion:^(NSDictionary *result){
		NSString *url = @"";
		if ([result isKindOfClass:NSDictionary.class] &&
			![result[@"@type"] isEqualToString:@"error"])
			url = [result[@"url"] isKindOfClass:NSString.class] ? result[@"url"] : @"";
		if (completion) completion(url);
	}];
}


@end
