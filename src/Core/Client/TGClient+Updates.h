//
// TGClient+Updates.h - the inline query the update bot answers.
//
#import "TGClient+Base.h"

@interface TGClient (Updates)

/// Resolves a public bot by username and asks it an inline query on behalf of
/// the account's own chat. The bot's answer is returned as the raw result
/// array; nil when the lookup or the request failed.
- (void)inlineQueryWithBotUsername:(NSString *)username
                            chatId:(int64_t)chatId
                             query:(NSString *)query
                        completion:(void (^)(NSArray *results))completion;

@end
