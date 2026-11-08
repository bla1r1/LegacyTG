#import "TGClient+Base.h"

@interface TGClient (Speech)

/// Asks Telegram's own recognizer to transcribe a voice or video note. TDLib
/// answers ok at once and the text arrives in updateMessageContent; the chat
/// re-reads the message and the bubble shows the result. No speech engine is
/// shipped with the app, and none is needed.
- (void)recognizeSpeechInChat:(int64_t)chatId
					  message:(int64_t)messageId
				   completion:(void (^)(BOOL ok, NSString *error))completion;

/// Quality vote for a finished transcript.
- (void)rateSpeechInChat:(int64_t)chatId
				 message:(int64_t)messageId
					isGood:(BOOL)isGood
			  completion:(void (^)(BOOL ok, NSString *error))completion;

/// Informs TDLib that a music file was listened to for `duration` seconds.
/// Telegram uses it for the "listened" mark and for recommendations.
- (void)markAudioListened:(int32_t)fileId
				 duration:(int32_t)duration
			   completion:(void (^)(BOOL ok, NSString *error))completion;

@end
