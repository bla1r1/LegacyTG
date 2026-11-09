//
// TGAiComposeViewController.h - the composer's AI text screen.
//
// Official opens TextProcessingScreen in its edit mode: Translate, Style and
// Fix tabs, the original and the result, one Apply at the bottom. The screen
// knows the chat and the composer text; it never asks for a recipient and it
// does not send anything itself.
//
#import "TGViewController.h"

@interface TGAiComposeViewController : TGViewController

/// The open chat. Apply hands the result back to its composer; the recipient
/// is this chat, not a picker.
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, copy) NSString *chatTitle;
/// The language of the chat when the caller knows it; nil otherwise, in which
/// case the text's script and then the app language decide.
@property (nonatomic, copy) NSString *chatLanguage;
/// The composer's text when the AI button opened this screen.
@property (nonatomic, copy) NSString *initialText;
/// Apply puts the result here. Official updates the composer and leaves the
/// send to the user, so this block never sends a message.
@property (nonatomic, copy) void (^onApply)(NSString *text);

@end
