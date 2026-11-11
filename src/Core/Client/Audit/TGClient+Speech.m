#import "TGClient+Speech.h"
#import "TGClientInternal.h"
#import "TGClient+AuditSupport.h"

@implementation TGClient (Speech)

#pragma mark - speech

- (void)recognizeSpeechInChat:(int64_t)chatId
					  message:(int64_t)messageId
				   completion:(void (^)(BOOL, NSString *))completion {
	if (!chatId || !messageId){
		if (completion) completion(NO, @"An error occurred.");
		return;
	}
	[self request:@{@"@type" : @"recognizeSpeech",
					@"chat_id" : @(chatId),
					@"message_id" : @(messageId)}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)rateSpeechInChat:(int64_t)chatId
				 message:(int64_t)messageId
				  isGood:(BOOL)isGood
			  completion:(void (^)(BOOL, NSString *))completion {
	if (!chatId || !messageId){
		if (completion) completion(NO, @"An error occurred.");
		return;
	}
	[self request:@{@"@type" : @"rateSpeechRecognition",
					@"chat_id" : @(chatId),
					@"message_id" : @(messageId),
					@"is_good" : @(isGood)}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

@end
