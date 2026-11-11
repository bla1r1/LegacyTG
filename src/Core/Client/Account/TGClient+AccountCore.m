#import "TGClientInternal.h"
#import "TGStatusText.h"
#import "TGGiftFlatten.h"
#import "TGClient+AccountCore.h"
#import "TGClient+AccountSupport.h"


@implementation TGClient (AccountCore)

#pragma mark - account

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

@end
