#import "TGClient+Revenue.h"
#import "TGClientInternal.h"
#import "TGClient+AuditSupport.h"

@implementation TGClient (Revenue)

#pragma mark - revenue

/// The balance itself has no screen asking for it today, so it is only kept
/// here for the getter. The two revenue updates do have a screen: the Stars
/// page re-reads the statistics it already asked for when it hears them.
- (void)applyOwnedStarCountUpdate:(NSDictionary *)update {
	self.ownedStarCountValue = [update[@"star_count"] longLongValue];
}

- (void)applyChatRevenueAmountUpdate:(NSDictionary *)update {
	NSNumber *chatId = update[@"chat_id"];
	if (!chatId)
		return;
	NSDictionary *amount = [update[@"revenue_amount"] isKindOfClass:NSDictionary.class]
			? update[@"revenue_amount"] : @{};
	if (!self.chatRevenueAmountByChat)
		self.chatRevenueAmountByChat = [NSMutableDictionary dictionary];
	self.chatRevenueAmountByChat[chatId] = amount;
	[[NSNotificationCenter defaultCenter]
			postNotificationName:TGChatRevenueChangedNotification object:self
						userInfo:@{@"chatId" : chatId}];
}

- (NSDictionary *)chatRevenueAmountForChat:(int64_t)chatId {
	return self.chatRevenueAmountByChat[@(chatId)];
}

- (void)applyStarRevenueStatusUpdate:(NSDictionary *)update {
	NSDictionary *owner = [update[@"owner_id"] isKindOfClass:NSDictionary.class]
			? update[@"owner_id"] : nil;
	if (!owner)
		return;
	BOOL isChat = [owner[@"@type"] isEqualToString:@"messageSenderChat"];
	NSString *kind = isChat ? @"chat" : @"user";
	int64_t ownerId = isChat ? [owner[@"chat_id"] longLongValue]
			: [owner[@"user_id"] longLongValue];
	if (!ownerId)
		return;
	NSDictionary *status = [update[@"status"] isKindOfClass:NSDictionary.class]
			? update[@"status"] : @{};
	if (!self.starRevenueStatusByOwner)
		self.starRevenueStatusByOwner = [NSMutableDictionary dictionary];
	self.starRevenueStatusByOwner[[NSString stringWithFormat:@"%@:%lld", kind, ownerId]]
			= status;
	[[NSNotificationCenter defaultCenter]
			postNotificationName:TGStarRevenueChangedNotification object:self
						userInfo:@{@"ownerKind" : kind, @"ownerId" : @(ownerId)}];
}

- (NSDictionary *)starRevenueStatusForOwner:(NSString *)ownerKind
									ownerId:(int64_t)ownerId {
	NSString *kind = [ownerKind isEqualToString:@"chat"] ? @"chat" : @"user";
	return self.starRevenueStatusByOwner[
			[NSString stringWithFormat:@"%@:%lld", kind, ownerId]];
}

@end
