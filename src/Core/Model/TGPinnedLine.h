//
// TGPinnedLine.h - the service line a pin leaves in the chat, with the
// pinned message quoted. Foundation only: the layout pass measures the same
// string the cell draws.
//
#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/// "Alice pinned a message" becomes 'Alice pinned "Hello wor..."' with the
/// first 20 characters of `pinned`'s text; a message without text quotes its
/// kind instead ("a photo", "a video", "a voice message", "a sticker",
/// "a poll", "a file"). Anything else, or a line that does not end in
/// "a message", comes back unchanged.
FOUNDATION_EXPORT NSString *TGPinnedLine(NSString *serviceText, NSDictionary *pinned);

#ifdef __cplusplus
}
#endif
