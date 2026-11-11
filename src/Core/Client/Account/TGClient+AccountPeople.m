#import "TGClientInternal.h"
#import "TGStatusText.h"
#import "TGGiftFlatten.h"
#import "TGClient+AccountPeople.h"
#import "TGClient+AccountSupport.h"


@implementation TGClient (AccountPeople)

#pragma mark - people

- (void)setUser:(int64_t)userId blocked:(BOOL)blocked {
	[self setUser:userId blocked:blocked completion:nil];
}

- (void)setUser:(int64_t)userId blocked:(BOOL)blocked completion:(void (^)(BOOL))completion {
	// Chat ids are negative; a blocked channel has to be named as a chat, or
	// the unblock goes to a user id that does not exist.
	NSDictionary *sender = userId < 0
			? @{@"@type" : @"messageSenderChat", @"chat_id" : @(userId)}
			: @{@"@type" : @"messageSenderUser", @"user_id" : @(userId)};
	[self request:@{
		@"@type"      : @"setMessageSenderBlockList",
		@"sender_id"  : sender,
		// A null block list is how TDLib spells "not blocked".
		@"block_list" : blocked ? @{@"@type" : @"blockListMain"} : [NSNull null],
	} completion:^(NSDictionary *result){
		if (completion)
			completion([result[@"@type"] isEqualToString:@"ok"]);
	}];
}

- (void)isUserBlocked:(int64_t)userId completion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"getUserFullInfo", @"user_id" : @(userId)}
	   completion:^(NSDictionary *full){
		if (completion)
			completion([full[@"block_list"] isKindOfClass:NSDictionary.class]);
	}];
}

@end
