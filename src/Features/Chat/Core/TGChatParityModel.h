//
// TGChatParityModel.h - decisions shared by the chat screens and the host
// tests. Nothing here touches UIKit: a wrong date order, a delete choice or a
// stale layout cache is a model bug before it is a drawing one.
//
#import <Foundation/Foundation.h>

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

#ifdef __cplusplus
}
#endif
