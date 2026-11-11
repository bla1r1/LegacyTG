#import "TGClientInternal.h"
#import "TGStatusText.h"
#import "TGGiftFlatten.h"
#import "TGClient+AccountContacts.h"
#import "TGClient+AccountSupport.h"


@implementation TGClient (AccountContacts)

#pragma mark - contacts

- (void)privateChatWithUser:(int64_t)userId completion:(void (^)(int64_t))completion {
	[self request:@{
		@"@type"   : @"createPrivateChat",
		@"user_id" : @(userId),
		@"force"   : @NO,
	} completion:^(NSDictionary *chat){
		// The answer is a full chat object, id included; feeding it into
		// the cache puts a photo and a title beside the id, so the screen a
		// contact opens is dressed like any other chat instead of a bare
		// id and name pair (B6).
		[self mergeChat:chat];
		if (completion)
			completion([chat[@"id"] longLongValue]);
	}];
}

- (void)userForPhone:(NSString *)phone completion:(void (^)(NSDictionary *))completion {
	if (!phone.length){
		if (completion) completion(nil);
		return;
	}
	[self request:@{
		@"@type"        : @"searchUserByPhoneNumber",
		@"phone_number" : phone,
	} completion:^(NSDictionary *u){
		if (![u[@"@type"] isEqualToString:@"user"]){
			if (completion) completion(nil);
			return;
		}
		if (completion) completion(@{
			@"id"         : u[@"id"] ?: @(0),
			@"first_name" : u[@"first_name"] ?: @"",
			@"last_name"  : u[@"last_name"] ?: @"",
			@"phone"      : u[@"phone_number"] ?: @"",
			@"username"   : u[@"usernames"][@"active_usernames"][0] ?: @"",
		});
	}];
}


@end
