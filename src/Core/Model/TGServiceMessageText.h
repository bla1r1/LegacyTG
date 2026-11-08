#import <Foundation/Foundation.h>

typedef NSString *(^TGServiceUserName)(int64_t userId);   // nil when unknown
typedef NSString *(^TGServiceChatTitle)(int64_t chatId);  // nil when unknown

/// The one-line sentence a service message shows in the chat, or nil when the
/// content is not a service action. `message` is the whole TDLib `message`.
FOUNDATION_EXPORT NSString *TGServiceMessageText(NSDictionary *message,
		TGServiceUserName userName, TGServiceChatTitle chatTitle);
