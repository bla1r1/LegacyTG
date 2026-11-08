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

- (void)markAudioListened:(int32_t)fileId
				 duration:(int32_t)duration
			   completion:(void (^)(BOOL, NSString *))completion {
	if (fileId <= 0){
		if (completion) completion(NO, @"An audio file id is needed.");
		return;
	}
	[self request:@{@"@type" : @"listenToAudio",
					@"audio_file_id" : @(fileId),
					@"duration" : @(MAX((int32_t)0, duration))}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

@end
