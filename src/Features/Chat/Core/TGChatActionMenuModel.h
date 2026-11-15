//
// TGChatActionMenuModel.h - the one-card message menu, ordered like official.
//
// The ordering used to live in two lists across two cards: the first card in
// TGChatActionsHoldMenu and a second behind "More". Both screens and the host
// tests now build from this one table so a row cannot drift out of position or
// appear twice.
//
#import <UIKit/UIKit.h>
#import "TGStyle.h"

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
	/// Set once getMessageProperties answered: Copy and Delete then follow
	/// TDLib instead of guesses.
	BOOL hasProperties;
	BOOL canCopy;
	BOOL canDeleteForSelf;
	BOOL canDeleteForAll;
	/// The rest of messageProperties the card reads: Replace Photo, the
	/// viewers line, Report Reaction, View Thread, the read date, and the
	/// copy-protection tip (by you, by the other side).
	BOOL canEditMedia;
	BOOL canGetViewers;
	BOOL canReportReactions;
	BOOL canGetThread;
	BOOL canGetReadDate;
	BOOL protectedByMe;
	BOOL protectedByOther;
} TGChatActionMenuContext;

/// Where a held bubble of `bubble`'s size sits while its menu is open, as
/// official ContextControllerExtractedPresentationNode places it: where it
/// was, unless the reaction bar (`above`) or the card under it (`below`)
/// would leave [top, bottom]; then the bubble moves just enough. When both
/// cannot fit, the top wins and the card scrolls.
CGFloat TGHoldLiftY(CGRect bubble, CGFloat above, CGFloat below, CGFloat top, CGFloat bottom);

/// TDLib's messageProperties over the guesses: reply, edit, pin, copy and
/// the two deletes. Nil leaves the context as it was.
void TGChatActionMenuApplyProperties(TGChatActionMenuContext *context,
		NSDictionary *properties);

/// The delete sheet's choices as official offers them for one message:
/// "Delete for Everyone" (or "for All" in a group) when it can be revoked,
/// "Delete for me" when it can go from this side only. Each is
/// {title, revoke}. Without properties both are offered, Saved Messages
/// offers one plain Delete.
NSArray<NSDictionary *> *TGMessageDeleteChoices(BOOL isSaved, BOOL isGroup,
		NSDictionary *properties);

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

/// The line under Delete for a message on a timer: "auto-deletes in 0:42",
/// "auto-deletes in 1:02:09", "auto-deletes in 2 days"
/// (Conversation.AutoremoveRemaining*).
NSString *TGAutoDeleteText(NSTimeInterval seconds);

/// Official's tooltip after a free transcription: "You have 3 free voice
/// transcriptions left this week." Nil for an unknown count (-1).
NSString *TGFreeTranscriptionsText(NSInteger left);

/// The tip official puts on the hold menu in a private chat with copying
/// turned off: by you, or by the other side. Nil otherwise.
NSString *TGCopyProtectionTip(TGChatActionMenuContext context, NSString *peerName);

/// "read 12:30" over an own message in a private chat (getMessageReadDate).
NSString *TGReadDateText(NSTimeInterval readDate);

/// Conversation.FreeTranscriptionCooldownTooltip and WaitOrSubscribe as one
/// plain sentence, for an account with no free transcription left (`left`
/// 0); nil while one is left, the count is unknown (-1) or the reset passed.
NSString *TGTranscriptionCooldownText(NSInteger left, NSInteger weekly,
		NSTimeInterval resetDate, NSTimeInterval now);

/// "0:42" for the slow mode wait, as official's tooltip writes it.
NSString *TGSlowModeWaitText(NSTimeInterval seconds);

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

/// The composer's buttons: the paperclip on the left, and the text's own
/// inset from the well's left edge.
static const CGFloat kAttachWidth     = 34.0f;
static const CGFloat kComposerInset   = TGMetricPadSmall;
static const CGFloat kFieldLeftPad    = TGMetricPadMedium;

/// The width the text wraps at in a bar `barWidth` wide: the one-line well
/// less the text's left inset and the sticker toggle at its right end.
CGFloat TGChatComposerTextWidth(CGFloat barWidth);

/// Every frame of a composer holding `lines` lines in a bar `width` wide
/// whose bottom edge is at `bottom`. Field and controls are bottom-aligned;
/// the AI entry sits one slot above the paperclip; the table fills what is
/// above the bar.
typedef struct {
	CGFloat barHeight;
	BOOL scrolls;
	CGRect bar, well, text, sticker, attach, ai, send, table;
} TGChatComposerFrames;

TGChatComposerFrames TGChatComposerPlace(CGFloat width, CGFloat bottom, NSInteger lines);

/// The reply / edit strip above the composer: an accent stripe, then who is
/// being answered over what they said, and a close button on the right.
static const CGFloat kComposeBannerHeight = TGMetricRow;
static const CGFloat kBannerStripeX   = TGMetricPadMedium + TGMetricPadTiny;
static const CGFloat kBannerStripeTop = TGMetricPad;
static const CGFloat kBannerTextX     = 22.0f;
static const CGFloat kBannerTitleTop  = TGMetricPadSmall;

typedef struct {
	CGRect plate, stripe, title, subtitle, close;
} TGChatComposeBannerFrames;

/// The strip riding on a bar whose top is at `barTop`, `width` wide. One
/// line (no subtitle) centres the title; two share the strip.
TGChatComposeBannerFrames TGChatComposeBannerPlace(CGFloat width, CGFloat barTop,
		BOOL twoLines);

/// The bar and the table over a keyboard `keyboardHeight` tall in a view
/// `viewSize` big, for a bar `barHeight` tall.
void TGChatComposerAboveKeyboard(CGSize viewSize, CGFloat barHeight,
		CGFloat keyboardHeight, CGRect *bar, CGRect *table);

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
