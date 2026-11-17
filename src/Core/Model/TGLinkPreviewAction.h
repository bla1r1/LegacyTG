//
// TGLinkPreviewAction.h - the button official puts under a Telegram link
// preview (ChatMessageWebpageBubbleContentNode actionTitle), from TDLib's
// linkPreview.
//
#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/// @{"action": the button's words} plus, for the kinds official retitles,
/// "title" (the preview's new title) and "dropsText" (no site, no
/// description). Empty when official draws no button: an article, a bot, a
/// type this client does not know.
NSDictionary *TGLinkPreviewAction(NSDictionary *linkPreview);

#ifdef __cplusplus
}
#endif
