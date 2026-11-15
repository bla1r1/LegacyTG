#import "TGClient+Discovery.h"
#import "TGClientInternal.h"
#import "TGClient+AuditSupport.h"

@implementation TGClient (Discovery)

#pragma mark - discovery

- (void)giveawayInfoForChat:(int64_t)chatId
					message:(int64_t)messageId
				 completion:(void (^)(NSDictionary *, NSString *))completion {
	if (!chatId || !messageId){
		if (completion) completion(nil, @"An error occurred.");
		return;
	}
	[self request:@{@"@type" : @"getGiveawayInfo",
					@"chat_id" : @(chatId), @"message_id" : @(messageId)}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSDictionary *status = [result[@"status"] isKindOfClass:NSDictionary.class] ? result[@"status"] : nil;
		if (completion)
			completion(@{@"kind" : TGAuditShortType(result[@"@type"]),
						 @"activationCount" : TGAuditNumber(result, @"activation_count"),
						 @"status" : status[@"@type"] ?: @"",
						 @"statusDate" : status[@"joined_chat_date"] ?: @0,
						 @"statusCountry" : status[@"user_country_code"] ?: @"",
						 @"creationDate" : TGAuditNumber(result, @"creation_date"),
						 @"isEnded" : @([result[@"is_ended"] boolValue]),
						 @"isWinner" : @([result[@"is_winner"] boolValue]),
						 @"winnerCount" : TGAuditNumber(result, @"winner_count"),
						 @"wonStarCount" : TGAuditNumber(result, @"won_star_count"),
						 @"giftCode" : TGAuditString(result, @"gift_code")}, nil);
	}];
}

@end
