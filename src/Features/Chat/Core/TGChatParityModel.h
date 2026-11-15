//
// TGChatParityModel.h - decisions shared by the chat screens and the host
// tests. Nothing here touches UIKit: a wrong date order, a delete choice or a
// stale layout cache is a model bug before it is a drawing one.
//
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

#ifdef __cplusplus
extern "C" {
#endif

/// The message ids whose cached layout must be thrown away after new history.
/// An id that kept the same dictionary keeps its geometry; a new or edited
/// message is invalidated. Albums are grouped later, so raw ids are enough.
NSArray<NSNumber *> *TGChangedMessageIds(NSArray *oldMessages, NSArray *newMessages);

/// The date plate above a day of messages: "Today", "5 November" or
/// "5 November 2026" in the pack's own month and order. `now` is explicit so
/// the test does not depend on the machine's clock.
NSString *TGChatDateSeparatorTitle(NSTimeInterval stamp, NSTimeInterval now);

/// Chat.InputTextPaidMessagePlaceholder: "Message for 10 Stars" when the
/// person charges for messages; nil when they do not.
NSString *TGPaidMessagePlaceholder(int64_t stars);

/// The composer's word from the chat kind and posting rights.
NSString *TGChatComposerPlaceholder(BOOL isChannel, BOOL silentPosting,
		BOOL canBeAnonymous);

/// The choices that deleting one chat offers, in official's order. A private
/// chat can be deleted for both sides or just here; a group only has the
/// local "Delete N Chats" action.
NSArray<NSString *> *TGChatDeleteChoices(BOOL isPrivateChat, NSInteger count);

/// YES only when the row is a real chat and the table may draw its selection
/// circle. Editing multi-select is not a swipe: iOS 6/7 has no row actions,
/// but it still has the left check control.
BOOL TGChatRowIsSelectable(BOOL editing, BOOL canSwipe, BOOL validChatRow);

/// The forward picker's destination order: the list order, not the order the
/// thumbs were tapped in.
NSArray<NSNumber *> *TGSelectedChatIdsInOrder(NSArray *chats, NSSet *selected);

/// Story rows belong to the list that asked for them. A merge that keeps the
/// other list's rows puts archived stories under a folder and vice versa.
NSArray<NSDictionary *> *TGStoryRowsForList(NSArray *fresh, NSArray *old,
		NSString *list);

/// A late folder answer must not fill the folder now on screen.
BOOL TGChatFolderAnswerStillWanted(NSInteger askedFolder, NSInteger currentFolder);

/// A message search hit opens at the message, not at the chat's latest one.
BOOL TGChatSearchHitOpensMessage(NSDictionary *hit);

/// Delete-for-me waits for the undo plate to commit; delete-for-everyone is
/// already gone and cannot be taken back.
BOOL TGChatDeleteDefersToCommit(BOOL revoke);

/// A status notification refreshes a private chat's presence; a group or a
/// secret chat has no user status to re-ask.
BOOL TGChatStatusNotificationRefreshesPresence(NSString *noteName, BOOL isGroup,
		BOOL isSecret);

/// The channel bar's centre word for the current mute state.
NSString *TGChatChannelMuteTitle(BOOL muted);

/// Official's paid-message confirmation (Chat.PaidMessage.Confirm.Single.Text)
/// for one message at `stars`, with the pack's bold marks taken out: an
/// alert draws plain text.
NSString *TGPaidResendConfirmText(NSString *chatName, int64_t stars);

/// The forward header: "Forwarded from: X", or for a proxy's public service
/// announcement official's "Public Service Announcement From: X" (its
/// "Covid-19 Notification" for that type), on one line.
NSString *TGForwardHeaderLine(NSString *from, NSString *psaType);

/// The giveaway sheet's words (Chat.Giveaway.Info.*) from getGiveawayInfo
/// as the client flattens it: a win, a loss with how many winners already
/// used their links, or where you stand in a running one. Bold marks are
/// taken out for the alert.
NSString *TGGiveawayInfoText(NSDictionary *info, NSString *chatTitle);

/// The Business bot panel's status word (Chat.BusinessBotPanel.Status*):
/// paused, manages this chat, or only has access when it cannot reply.
NSString *TGBusinessBotStatus(NSDictionary *bot);

/// A secret chat's key picture: 144 colour indexes (0-3) for a 12x12
/// square, two bits per cell from key_hash's 36 bytes, low bits first, as
/// td_api.tl describes it. Fewer bytes leave the rest 0.
NSArray<NSNumber *> *TGSecretKeyCells(NSData *keyHash);

/// The first 32 bytes of key_hash as four lines of eight hex pairs, the
/// text official prints under the picture.
NSString *TGSecretKeyHex(NSData *keyHash);

/// Conversation.InviteRequestInfo: why a message from a group admin landed
/// here, with the day the join request was sent.
NSString *TGJoinRequestInfoText(NSString *chatTitle, NSString *day);

/// ChatUserInfoItem for a new contact: label/value rows ("Phone Number" and
/// the country, "Registration" and the month) and then the "User updated
/// name 3 days ago" notes, from the action bar's accountInfo. `country` is
/// the country's name, already looked up.
NSArray *TGNewContactCardRows(NSDictionary *account, NSString *country,
		NSTimeInterval now);

/// A bot keyboard's panel height and, in `keyPitch`, each row's pitch.
/// resize_keyboard sizes the panel to its rows (never past `standard`);
/// without it the panel is the system keyboard's height and few rows grow
/// to fill it, as ChatButtonKeyboardInputNode does.
CGFloat TGBotKeyboardPanelHeight(NSInteger rows, BOOL resize, CGFloat standard,
		CGFloat gap, CGFloat *keyPitch);

/// The jump-to buttons over the composer, bottom up: the down arrow when
/// the list is away from the bottom, then unread mentions, unread reactions
/// and unread poll votes (ChatHistoryNavigationButtons). Each slot's y offset
/// above the lowest place, or -1 for a button that is not shown.
void TGChatNavigationButtonOffsets(BOOL down, NSInteger mentions, NSInteger reactions,
		NSInteger pollVotes, CGFloat pitch, CGFloat *mentionsY, CGFloat *reactionsY,
		CGFloat *pollVotesY);

#ifdef __cplusplus
}
#endif
