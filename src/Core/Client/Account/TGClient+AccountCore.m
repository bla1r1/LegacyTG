#import "TGClientInternal.h"
#import "TGStatusText.h"
#import "TGGiftFlatten.h"
#import "TGClient+AccountCore.h"
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





@implementation TGClient (AccountCore)

#pragma mark - account

- (void)sessionsWithCompletion:(void (^)(NSArray *))completion {
	[self sessionsWithInactiveTtlCompletion:^(NSArray *sessions, NSInteger ttlDays){
		if (completion) completion(sessions);
	}];
}

- (void)sessionsWithInactiveTtlCompletion:(void (^)(NSArray *, NSInteger))completion {
	[self request:@{@"@type" : @"getActiveSessions"} completion:^(NSDictionary *result){
		if ([result[@"@type"] isEqualToString:@"error"]){
			if (completion) completion(@[], 0);
			return;
		}
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *session in result[@"sessions"]){
			[out addObject:@{
				@"id"         : session[@"id"] ?: @0,
				@"name"       : session[@"application_name"] ?: @"",
				@"platform"   : [NSString stringWithFormat:@"%@ %@",
						session[@"platform"] ?: @"", session[@"system_version"] ?: @""],
				@"ip"         : session[@"ip_address"] ?: session[@"ip"] ?: @"",
				@"isCurrent"  : session[@"is_current"] ?: @NO,
				@"isUnconfirmed" : session[@"is_unconfirmed"] ?: @NO,
				@"canAcceptSecretChats" : session[@"can_accept_secret_chats"] ?: @YES,
				@"canAcceptCalls" : session[@"can_accept_calls"] ?: @YES,
				@"lastActive" : session[@"last_active_date"] ?: @0,
			}];
		}
		if (completion)
			completion(out, [result[@"inactive_session_ttl_days"] integerValue]);
	}];
}

- (void)terminateSession:(long long)sessionId {
	[self send:@{@"@type" : @"terminateSession", @"session_id" : @(sessionId)}];
}

- (void)confirmSession:(long long)sessionId {
	[self send:@{@"@type" : @"confirmSession", @"session_id" : @(sessionId)}];
}

- (void)toggleSession:(long long)sessionId
	   canAcceptCalls:(BOOL)canAccept
		   completion:(void (^)(BOOL, NSString *))completion {
	if (!sessionId){
		if (completion) completion(NO, @"No session was named.");
		return;
	}
	[self request:@{@"@type" : @"toggleSessionCanAcceptCalls",
					@"session_id" : @(sessionId),
					@"can_accept_calls" : @(canAccept)}
	   completion:^(NSDictionary *result){
		BOOL failed = [result[@"@type"] isEqualToString:@"error"];
		NSString *message = [result[@"message"] isKindOfClass:NSString.class]
				? result[@"message"] : @"An error occurred.";
		if (completion) completion(!failed, failed ? message : nil);
	}];
}

- (void)setInactiveSessionTtlDays:(NSInteger)days
					   completion:(void (^)(BOOL, NSString *))completion {
	// TDLib's own range; naming it here means the picker cannot send a value
	// the server will only reject.
	if (days < 1 || days > 366){
		if (completion) completion(NO, @"The idle timeout is 1 to 366 days.");
		return;
	}
	[self request:@{@"@type" : @"setInactiveSessionTtl",
					@"inactive_session_ttl_days" : @((int32_t)days)}
	   completion:^(NSDictionary *result){
		BOOL failed = [result[@"@type"] isEqualToString:@"error"];
		NSString *message = [result[@"message"] isKindOfClass:NSString.class]
				? result[@"message"] : @"An error occurred.";
		if (completion) completion(!failed, failed ? message : nil);
	}];
}

- (void)setName:(NSString *)firstName
			last:(NSString *)lastName
	  completion:(void (^)(BOOL, NSString *))completion {
	[self request:@{
		@"@type"      : @"setName",
		@"first_name" : firstName ?: @"",
		@"last_name"  : lastName ?: @"",
	} completion:^(NSDictionary *result){
		BOOL failed = [result[@"@type"] isEqualToString:@"error"];
		if (completion)
			completion(!failed, failed ? (result[@"message"] ?: @"An error occurred.") : nil);
	}];
}

- (void)setBio:(NSString *)bio
	completion:(void (^)(BOOL, NSString *))completion {
	[self request:@{@"@type" : @"setBio", @"bio" : bio ?: @""}
	   completion:^(NSDictionary *result){
		BOOL failed = [result[@"@type"] isEqualToString:@"error"];
		if (completion)
			completion(!failed, failed ? (result[@"message"] ?: @"An error occurred.") : nil);
	}];
}

- (void)bioLengthMaxWithCompletion:(void (^)(NSInteger))completion {
	[self request:@{@"@type" : @"getOption", @"name" : @"bio_length_max"}
	   completion:^(NSDictionary *option){
		// getOption answers with the optionValueInteger itself, its number as a
		// string over JSON; an error or an empty option reads as 0.
		if (completion)
			completion([option[@"@type"] isEqualToString:@"optionValueInteger"]
					? [option[@"value"] integerValue] : 0);
	}];
}

- (void)setUsername:(NSString *)username completion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"setUsername", @"username" : username ?: @""}
	   completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}

/// Small profile photo of a user, so a group message can show who wrote it.
- (void)cacheProfilePhoto:(NSDictionary *)user {
	NSNumber *fileId = user[@"profile_photo"][@"small"][@"id"];
	if (user[@"id"] && fileId)
		self.userPhotosById[user[@"id"]] = fileId;
}

- (int64_t)savedMessagesChatId {
	return [self.me[@"id"] longLongValue];
}

- (BOOL)hasSignedInAccount {
	return self.me != nil;
}

- (void)statusForUser:(int64_t)userId completion:(void (^)(NSString *))completion {
	if (self.rawUsersById[@(userId)][@"status"]){
		NSString *text = TGStatusTextFromTDStatus(self.rawUsersById[@(userId)][@"status"]);
		if (completion) completion(text);
		return;
	}
	[self request:@{@"@type" : @"getUser", @"user_id" : @(userId)}
	   completion:^(NSDictionary *user){
		if ([user[@"@type"] isEqualToString:@"user"]){
			if (!self.rawUsersById) self.rawUsersById = [[TGObjectLruCache alloc] initWithCapacity:TGRawUserCacheCap];
			self.rawUsersById[@(userId)] = user;
		}
		// The phrase table now lives in TGStatusText alongside the network
		// names, so a host test can pin every line it can say (B4).
		NSString *text = TGStatusTextFromTDStatus(user[@"status"]);
		if (completion) completion(text);
	}];
}

- (NSNumber *)photoFileIdForUserId:(int64_t)userId {
	return self.userPhotosById[@(userId)];
}

- (void)profilePhotoFileIdForUser:(int64_t)userId
                       completion:(void (^)(NSNumber *))completion {
	if (!userId){
		if (completion) completion(nil);
		return;
	}
	NSNumber *cached = self.userPhotosById[@(userId)];
	if (cached){
		if (completion) completion(cached);
		return;
	}
	// A member list names people TDLib has already told us about; their raw
	// record carries the picture without another round trip.
	NSDictionary *raw = self.rawUsersById[@(userId)];
	if (raw){
		NSNumber *fileId = [raw[@"profile_photo"][@"small"][@"id"]
				isKindOfClass:NSNumber.class]
				? raw[@"profile_photo"][@"small"][@"id"] : nil;
		if (fileId)
			self.userPhotosById[@(userId)] = fileId;
		if (completion) completion(fileId);
		return;
	}
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getUser", @"user_id" : @(userId)}
	   completion:^(NSDictionary *user){
		TGClient *me = weakSelf;
		NSNumber *fileId = nil;
		if ([user[@"@type"] isEqualToString:@"user"]){
			// The raw record is what the next call reads, so a user with no
			// picture is answered locally instead of asked for again.
			if (!me.rawUsersById)
				me.rawUsersById = [[TGObjectLruCache alloc] initWithCapacity:TGRawUserCacheCap];
			if (me)
				me.rawUsersById[@(userId)] = user;
			NSNumber *small = user[@"profile_photo"][@"small"][@"id"];
			if ([small isKindOfClass:NSNumber.class]){
				fileId = small;
				if (!me.userPhotosById)
					me.userPhotosById = [NSMutableDictionary dictionary];
				me.userPhotosById[@(userId)] = small;
			}
		}
		if (completion) completion(fileId);
	}];
}

- (void)userProfile:(int64_t)userId completion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getUserFullInfo", @"user_id" : @(userId)}
	   completion:^(NSDictionary *full){
		NSDictionary *birth = full[@"birthdate"];
		NSString *birthday = TGProfileBirthdayText([birth[@"day"] integerValue],
				[birth[@"month"] integerValue], [birth[@"year"] integerValue], [NSDate date]);
		NSString *tab = full[@"main_profile_tab"][@"@type"];
		tab = [tab stringByReplacingOccurrencesOfString:@"profileTab" withString:@""];
		// The bio travels as formatted text; the entities let the row keep its
		// links and mentions instead of clipping them to one grey line.
		NSDictionary *bio = full[@"bio"];
		NSDictionary *note = full[@"note"];
		if (completion) completion(@{
			@"bio"          : bio[@"text"] ?: @"",
			@"bioEntities"  : [bio[@"entities"] isKindOfClass:NSArray.class]
					? bio[@"entities"] : @[],
			@"commonGroups" : full[@"group_in_common_count"] ?: @0,
			@"birthday"     : birthday ?: @"",
			// The profile draws "Birthday today" in the online colour with a
			// gift glyph; the flag travels beside the text so the row does not
			// compare strings.
			@"birthdayToday": @(TGProfileBirthdayIsToday([birth[@"day"] integerValue],
					[birth[@"month"] integerValue], [NSDate date])),
			// The note is this account's own copy; empty means none is kept.
			@"note"         : note[@"text"] ?: @"",
			@"noteEntities" : [note[@"entities"] isKindOfClass:NSArray.class]
					? note[@"entities"] : @[],
			// A contact's private picture: an id is present only when one is
			// set, which is what the profile's remove row keys off.
			@"personalPhoto": full[@"personal_photo"][@"small"][@"id"] ?: @0,
			@"mainProfileTab": tab.length ? tab.lowercaseString : @"posts",
			@"shareTheme"   : full[@"share_theme"][@"@type"] ?: @"",
			// A user who has calls turned off should not be offered one.
			@"canCall"      : full[@"can_be_called"] ?: @NO,
			@"canVideoCall" : full[@"supports_video_calls"] ?: @NO,
			// Whether this account has them blocked, read from the same
			// full-info answer the card already waited for, so opening a
			// profile is one round trip instead of two.
			@"isBlocked"    : @([full[@"block_list"] isKindOfClass:NSDictionary.class]),
			// The strip under the action buttons: the owner's saved music.
			@"firstProfileAudio" : TGProfileAudioRow(full[@"first_profile_audio"]) ?: (id)[NSNull null],
			// The channel this person set as their personal channel, if any.
			@"personalChatId" : [full[@"personal_chat_id"] isKindOfClass:NSNumber.class]
					? full[@"personal_chat_id"] : @0,
			@"businessLocation" : full[@"business_info"][@"location"][@"address"] ?: @"",
			@"botDescription"   : full[@"bot_info"][@"short_description"] ?: (full[@"bot_info"][@"description"] ?: @""),
		});
	}];
}


@end
