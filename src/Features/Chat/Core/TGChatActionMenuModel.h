//
// TGChatActionMenuModel.h - the one-card message menu, ordered like official.
//
// The ordering used to live in two lists across two cards: the first card in
// TGChatActionsHoldMenu and a second behind "More". Both screens and the host
// tests now build from this one table so a row cannot drift out of position or
// appear twice.
//
#import <Foundation/Foundation.h>

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

#ifdef __cplusplus
}
#endif
