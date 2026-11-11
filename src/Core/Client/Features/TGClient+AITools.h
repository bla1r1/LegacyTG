#import "TGClient+Base.h"

@interface TGClient (AITools)

#pragma mark - AI text and rich messages

- (void)composeTextWithAi:(NSString *)text
         translateTo:(NSString *)languageCode
               style:(NSString *)styleName
           addEmojis:(BOOL)addEmojis
          completion:(void (^)(NSString *text, NSString *error))completion;

- (void)composeRichMessageWithAi:(NSString *)text
                     translateTo:(NSString *)languageCode
                           style:(NSString *)styleName
                    customPrompt:(NSString *)customPrompt
                       addEmojis:(BOOL)addEmojis
                      completion:(void (^)(NSString *text, NSString *error))completion;

- (void)createRichMessageWithAi:(NSString *)prompt
                   languageCode:(NSString *)languageCode
                      addEmojis:(BOOL)addEmojis
                     completion:(void (^)(NSString *text, NSString *error))completion;

- (void)fixTextWithAi:(NSString *)text
           completion:(void (^)(NSString *text, NSString *diff, NSString *error))completion;

- (void)fixRichMessageWithAi:(NSString *)text
                  completion:(void (^)(NSString *text, NSString *error))completion;

- (void)summarizeMessage:(int64_t)messageId
                  inChat:(int64_t)chatId
             translateTo:(NSString *)languageCode
                    tone:(NSString *)tone
              completion:(void (^)(NSString *text, NSString *error))completion;

- (void)translateMessageRichMessage:(int64_t)messageId
                             inChat:(int64_t)chatId
                             toCode:(NSString *)languageCode
                               tone:(NSString *)tone
                         completion:(void (^)(NSString *text, NSString *error))completion;

- (void)translateRichMessage:(NSString *)text
                      toCode:(NSString *)languageCode
                        tone:(NSString *)tone
                  completion:(void (^)(NSString *text, NSString *error))completion;

/// The whole rich message. Telegram truncates the block list on a normal
/// message read; this asks for the full one.
- (void)getFullRichMessage:(int64_t)messageId
                    inChat:(int64_t)chatId
                completion:(void (^)(NSString *text, NSDictionary *message, NSString *error))completion;

/// Sends a rich-message draft. Bots own this request, so a user account
/// gets Telegram's refusal in `error` - which is the honest answer.
- (void)sendRichMessageDraft:(NSString *)text
                      toChat:(int64_t)chatId
                     topicId:(int32_t)topicId
                     draftId:(int64_t)draftId
                     canStop:(BOOL)canStop
                  keepOnStop:(BOOL)keepOnStop
                  completion:(void (^)(BOOL ok, NSString *error))completion;

/// Sets or clears the fact-check line under a channel post. A nil or empty
/// `text` removes it, which TDLib spells as a null formattedText.
@end
