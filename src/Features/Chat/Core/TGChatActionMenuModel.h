//
// TGChatActionMenuModel.h - the one-card message menu, ordered like official.
//
// The ordering used to live in two lists across two cards: the first card in
// TGChatActionsHoldMenu and a second behind "More". Both screens and the host
// tests now build from this one table so a row cannot drift out of position or
// appear twice.
//
#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

/// The facts the chat knows about the held message but the flattened message
/// dictionary does not carry. Everything else is read from `message`.
typedef struct {
	BOOL mine;
	BOOL isGroup;
	BOOL isChannel;
	BOOL isSavedMessages;
	BOOL isPinned;
	BOOL canReply;
	BOOL canEdit;
	BOOL canPin;
	BOOL canTranslate;
	BOOL canSpeak;
	BOOL canViewStats;
	BOOL canSelect;
	BOOL canReport;
	BOOL canAddToFavorites;
	BOOL hasMessageEffects;
	/// Mono-forum posts name their author above the verbs; every other message
	/// has none, and the row used to appear on every incoming bubble.
	BOOL canViewAuthor;
	/// Broadcast channels can carry a fact check; official only offers it there.
	BOOL canEditFactCheck;
} TGChatActionMenuContext;

/// The rows of the single context card, in official order. Each row carries
/// "title", "action", "icon" and an optional "destructive". TG_DEV rows sit
/// after Select, as the release build never sees them.
NSArray<NSDictionary *> *TGChatActionMenuRows(NSDictionary *message,
		TGChatActionMenuContext context);

/// The reactions summed over the message's reaction groups. The read/reaction
/// header uses it; a message without groups is zero.
NSInteger TGChatActionMenuReactionCount(NSDictionary *message);

/// Official only puts the read/reaction summary on your own group or channel
/// message. Saved Messages has nobody to read it; a service row has no bubble.
BOOL TGChatActionMenuShowsReadSummary(NSDictionary *message,
		TGChatActionMenuContext context);

/// "N Seen" or "No views", both from the pack.
NSString *TGChatActionMenuSeenText(NSInteger viewerCount);

/// "N reactions", empty at zero.
NSString *TGChatActionMenuReactionText(NSInteger reactionCount);

/// The composer's growth rule, shared by the text view and the host tests.
/// One line is the old capsule; each line adds one body line and the field
/// stops growing at TGMetricComposerMaxLines, where the text view scrolls.
CGFloat TGChatComposerLineHeight(void);
CGFloat TGChatComposerFieldHeightForLines(NSInteger lines);
NSInteger TGChatComposerMaxLines(void);

/// How many body lines `text` takes at `width`. Empty text is one line, as
/// an empty editor still shows its caret on the first one.
NSInteger TGChatComposerLineCount(NSString *text, CGFloat width);

/// The bar height that holds a field of `lines` lines plus its inset above and
/// below. The field and the send control both use it, so they cannot drift.
CGFloat TGChatComposerBarHeightForLines(NSInteger lines);

/// Official's composer frame: the field ends before the send control, which
/// sits in the bar to its right. Both are bottom-aligned as the field grows.
/// These are the two frames used by the live composer and the host test.
CGRect TGChatComposerFieldFrame(CGFloat barWidth, CGFloat barHeight,
		CGFloat fieldHeight);
CGRect TGChatComposerSendFrame(CGFloat barWidth, CGFloat barHeight);

/// Official shows the AI button when the field has non-whitespace text and
/// has grown to at least three lines (ChatTextInputPanelNode, 3-line rule).
BOOL TGChatComposerShowsAIEntry(NSString *text, CGFloat width);

#pragma mark - AI composer

typedef NS_ENUM(NSInteger, TGAiComposeMode) {
	TGAiComposeModeTranslate = 0,
	TGAiComposeModeStyle,
	TGAiComposeModeFix,
};

/// The official TextProcessingScreen edit modes, in tab order: Translate,
/// Style, Fix. "Shorten" is not one of them in the official source.
NSArray<NSString *> *TGAiComposeModeTitles(void);

/// The style names the TDLib composeTextWithAi request takes. Titles are what
/// official's server styles show; keys are what the request is sent.
NSArray<NSDictionary *> *TGAiComposeStyleChoices(void);

/// A language code from the text's script, else the chat language, else the
/// app language, else English. The code is never shown raw in the UI.
NSString *TGAiComposeSourceLanguage(NSString *text, NSString *chatLanguageCode,
		NSString *appLanguageCode);

/// The language a translation goes to: the app language when it differs from
/// the source, otherwise English (or Russian when the source already is).
NSString *TGAiComposeTargetLanguage(NSString *sourceLanguage,
		NSString *appLanguageCode);

/// A human language name for the picker and labels, never the raw code.
NSString *TGAiComposeLanguageName(NSString *languageCode);

/// The common target languages offered by the picker.
NSArray<NSString *> *TGAiComposeLanguageChoices(void);

/// The AI screen's input model. The recipient is the open chat; the source and
/// target languages are derived here rather than typed into a settings row.
NSDictionary *TGAiComposeInputModel(NSString *text, int64_t chatId,
		NSString *chatLanguageCode, NSString *appLanguageCode);

/// A drawing size is real only when both sides are finite and at least one
/// point. UIKit's image-context drawing logs "invalid context 0x0" for the
/// rest, so every screen that bakes a bitmap asks this first.
BOOL TGChatDrawableSize(CGSize size);

#ifdef __cplusplus
}
#endif
