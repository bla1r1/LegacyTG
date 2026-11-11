//
// TGStarsStore+Speech.m - the Stars store's Speech requests.
//
// Bodies copied from src/Core/Client/Audit/TGClient+Speech.m; the store owns them.
//

#import "TGStarsStore.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGClient+AuditSupport.h"

@implementation TGStarsStore (Speech)

#pragma mark - speech

- (void)recognizeSpeechInChat:(int64_t)chatId
					  message:(int64_t)messageId
				   completion:(void (^)(BOOL, NSString *))completion {
	if (!chatId || !messageId){
		if (completion) completion(NO, @"An error occurred.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"recognizeSpeech",
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
	[[TGClient shared] request:@{@"@type" : @"rateSpeechRecognition",
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
	[[TGClient shared] request:@{@"@type" : @"listenToAudio",
					@"audio_file_id" : @(fileId),
					@"duration" : @(MAX((int32_t)0, duration))}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

@end
