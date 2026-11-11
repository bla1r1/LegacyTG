#import "TGClient+AITools.h"
#import "TGClientInternal.h"
#import "TGClient+FeatureSupport.h"

@implementation TGClient (AITools)

#pragma mark - AI text and rich messages

- (void)composeTextWithAi:(NSString *)text
         translateTo:(NSString *)languageCode
               style:(NSString *)styleName
           addEmojis:(BOOL)addEmojis
          completion:(void (^)(NSString *, NSString *))completion {
	NSString *clean = text ?: @"";
	if (!clean.length){
		if (completion)
			completion(nil, @"No text");
		return;
	}
	[self request:@{
		@"@type"                   : @"composeTextWithAi",
		@"text"                    : TGFormattedText(clean),
		@"translate_to_language_code": languageCode ?: @"",
		@"style_name"              : styleName ?: @"",
		@"add_emojis"              : @(addEmojis),
	} completion:^(NSDictionary *result){
		if (!TGFeatureOK(result)){
			if (completion)
				completion(nil, TGFeatureErrorText(result));
			return;
		}
		NSString *answer = TGFeatureFormattedTextValue(result);
		if (completion)
			completion(answer, answer ? nil : TGFeatureErrorText(result));
	}];
}

- (void)composeRichMessageWithAi:(NSString *)text
                     translateTo:(NSString *)languageCode
                           style:(NSString *)styleName
                    customPrompt:(NSString *)customPrompt
                       addEmojis:(BOOL)addEmojis
                      completion:(void (^)(NSString *, NSString *))completion {
	NSString *clean = text ?: @"";
	if (!clean.length){
		if (completion)
			completion(nil, @"No text");
		return;
	}
	[self request:@{
		@"@type"                     : @"composeRichMessageWithAi",
		@"message"                   : [TGClient inputRichMessageWithText:clean],
		@"translate_to_language_code": languageCode ?: @"",
		@"style_name"                : styleName ?: @"",
		@"custom_prompt"             : customPrompt ?: @"",
		@"add_emojis"                : @(addEmojis),
	} completion:^(NSDictionary *result){
		if (!TGFeatureOK(result)){
			if (completion)
				completion(nil, TGFeatureErrorText(result));
			return;
		}
		NSString *answer = [TGClient plainTextFromRichMessage:result];
		if (completion)
			completion(answer, answer.length ? nil : TGFeatureErrorText(result));
	}];
}

- (void)createRichMessageWithAi:(NSString *)prompt
                   languageCode:(NSString *)languageCode
                      addEmojis:(BOOL)addEmojis
                     completion:(void (^)(NSString *, NSString *))completion {
	NSString *clean = [prompt stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!clean.length){
		if (completion)
			completion(nil, @"A prompt is needed.");
		return;
	}
	[self request:@{
		@"@type"        : @"createRichMessageWithAi",
		@"prompt"       : clean,
		@"language_code": languageCode ?: @"",
		@"add_emojis"   : @(addEmojis),
	} completion:^(NSDictionary *result){
		if (!TGFeatureOK(result)){
			if (completion)
				completion(nil, TGFeatureErrorText(result));
			return;
		}
		NSString *answer = [TGClient plainTextFromRichMessage:result];
		if (completion)
			completion(answer, answer.length ? nil : TGFeatureErrorText(result));
	}];
}

- (void)fixTextWithAi:(NSString *)text
           completion:(void (^)(NSString *, NSString *, NSString *))completion {
	NSString *clean = text ?: @"";
	if (!clean.length){
		if (completion)
			completion(nil, nil, @"No text");
		return;
	}
	[self request:@{
		@"@type" : @"fixTextWithAi",
		@"text"  : TGFormattedText(clean),
	} completion:^(NSDictionary *result){
		if (!TGFeatureOK(result)){
			if (completion)
				completion(nil, nil, TGFeatureErrorText(result));
			return;
		}
		NSString *fixed = TGFeatureFormattedTextValue(result[@"text"]);
		NSString *diff = TGFeatureString(TGFeatureDict(result[@"diff_text"])[@"text"]);
		if (completion)
			completion(fixed, diff, fixed ? nil : TGFeatureErrorText(result));
	}];
}

- (void)fixRichMessageWithAi:(NSString *)text
                  completion:(void (^)(NSString *, NSString *))completion {
	NSString *clean = text ?: @"";
	if (!clean.length){
		if (completion)
			completion(nil, @"No text");
		return;
	}
	[self request:@{
		@"@type"   : @"fixRichMessageWithAi",
		@"message" : [TGClient inputRichMessageWithText:clean],
	} completion:^(NSDictionary *result){
		if (!TGFeatureOK(result)){
			if (completion)
				completion(nil, TGFeatureErrorText(result));
			return;
		}
		NSString *answer = [TGClient plainTextFromRichMessage:result];
		if (completion)
			completion(answer, answer.length ? nil : TGFeatureErrorText(result));
	}];
}

- (void)summarizeMessage:(int64_t)messageId
                  inChat:(int64_t)chatId
             translateTo:(NSString *)languageCode
                    tone:(NSString *)tone
              completion:(void (^)(NSString *, NSString *))completion {
	[self request:@{
		@"@type"                     : @"summarizeMessage",
		@"chat_id"                   : @(chatId),
		@"message_id"                : @(messageId),
		@"translate_to_language_code": languageCode ?: @"",
		@"tone"                      : tone ?: @"",
	} completion:^(NSDictionary *result){
		if (!TGFeatureOK(result)){
			if (completion)
				completion(nil, TGFeatureErrorText(result));
			return;
		}
		NSString *answer = TGFeatureFormattedTextValue(result);
		if (completion)
			completion(answer, answer ? nil : TGFeatureErrorText(result));
	}];
}

- (void)translateMessageRichMessage:(int64_t)messageId
                             inChat:(int64_t)chatId
                             toCode:(NSString *)languageCode
                               tone:(NSString *)tone
                         completion:(void (^)(NSString *, NSString *))completion {
	[self request:@{
		@"@type"          : @"translateMessageRichMessage",
		@"chat_id"        : @(chatId),
		@"message_id"     : @(messageId),
		@"to_language_code": languageCode ?: @"en",
		@"tone"           : tone ?: @"",
	} completion:^(NSDictionary *result){
		if (!TGFeatureOK(result)){
			if (completion)
				completion(nil, TGFeatureErrorText(result));
			return;
		}
		NSString *answer = [TGClient plainTextFromRichMessage:result];
		if (completion)
			completion(answer, answer.length ? nil : TGFeatureErrorText(result));
	}];
}

- (void)translateRichMessage:(NSString *)text
                      toCode:(NSString *)languageCode
                        tone:(NSString *)tone
                  completion:(void (^)(NSString *, NSString *))completion {
	NSString *clean = text ?: @"";
	if (!clean.length){
		if (completion)
			completion(nil, @"No text");
		return;
	}
	[self request:@{
		@"@type"           : @"translateRichMessage",
		@"message"         : [TGClient inputRichMessageWithText:clean],
		@"to_language_code": languageCode ?: @"en",
		@"tone"            : tone ?: @"",
	} completion:^(NSDictionary *result){
		if (!TGFeatureOK(result)){
			if (completion)
				completion(nil, TGFeatureErrorText(result));
			return;
		}
		NSString *answer = [TGClient plainTextFromRichMessage:result];
		if (completion)
			completion(answer, answer.length ? nil : TGFeatureErrorText(result));
	}];
}

- (void)getFullRichMessage:(int64_t)messageId
                    inChat:(int64_t)chatId
                completion:(void (^)(NSString *, NSDictionary *, NSString *))completion {
	[self request:@{
		@"@type"      : @"getFullRichMessage",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
	} completion:^(NSDictionary *result){
		if (!TGFeatureOK(result)){
			if (completion)
				completion(nil, nil, TGFeatureErrorText(result));
			return;
		}
		NSString *text = [TGClient plainTextFromRichMessage:result];
		if (completion)
			completion(text, result, text.length ? nil : TGFeatureErrorText(result));
	}];
}

- (void)sendRichMessageDraft:(NSString *)text
                      toChat:(int64_t)chatId
                     topicId:(int32_t)topicId
                     draftId:(int64_t)draftId
                     canStop:(BOOL)canStop
                  keepOnStop:(BOOL)keepOnStop
                  completion:(void (^)(BOOL, NSString *))completion {
	[self request:@{
		@"@type"         : @"sendRichMessageDraft",
		@"chat_id"       : @(chatId),
		@"forum_topic_id": @(topicId),
		@"draft_id"      : @(draftId),
		@"can_stop"      : @(canStop),
		@"keep_on_stop"  : @(keepOnStop),
		@"message"       : [TGClient inputRichMessageWithText:text],
	} completion:^(NSDictionary *result){
		BOOL ok = TGFeatureOK(result);
		if (completion)
			completion(ok, ok ? nil : TGFeatureErrorText(result));
	}];
}

@end
