//
// TGMessageFlatten.h - the raw TDLib message to the row the chat draws.
//
#import <Foundation/Foundation.h>

/// Flatten a TDLib message into the dictionary cells, actions and the send
/// store read. The implementation stays with TGMessageFlatten.m.
NSDictionary *TGFlattenMessage(NSDictionary *message);

/// "videoChatStarted" -> "Video chat started": the words for a TDLib type
/// this client has no sentence for yet.
NSString *TGPhraseFromTypeName(NSString *ctype);
