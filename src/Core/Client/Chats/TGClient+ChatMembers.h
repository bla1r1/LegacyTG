#import "TGClient+Base.h"

@interface TGClient (ChatMembers)

/// Chats of one folder.
- (void)chatsInFolder:(NSInteger)folderId completion:(void (^)(NSArray *chats))completion;

/// Topics of a forum supergroup - a forum holds several independent threads
/// in one chat. Each entry: "threadId", "name", "text", "unread", "date",
/// "unreadMentions", "unreadReactions", "unreadPollVotes", "pinned",
/// "general", "closed", "hidden", "created", "colour", "iconEmojiId" and the
/// raw "notificationSettings" record. Empty for a chat that is not a forum.
/// Clear the reaction marks on a topic. Called when the topic is opened:
/// reading the messages is what "read" means, and the row's badge has to go
/// with it rather than waiting for the next history read.
/// One topic read fresh: getForumTopic, the same fields the list row carries
/// plus the notification record. nil when Telegram refuses the id.
/// The t.me link to one topic, which is what Copy Link puts on the clipboard.
/// The two badges that are not reactions. readAllForumTopicReactions already
/// exists; these clear mentions and poll votes when their topic is opened.
/// setForumTopicNotificationSettings replaces the whole chatNotificationSettings
/// object, so `settings` is the complete record the screen built from the one
/// getForumTopic returned. The answer keeps Telegram's refusal text.
/// Writes the pinned order whole: the ids in `topicIds`, top first. A topic
/// left out is unpinned. Requires can_manage_topics.
/// Hides the General topic (and closes it) or brings it back. `isHidden` tells
/// the api which direction to go.
/// Making and minding a forum's topics. `colour` indexes the six hues TDLib
/// accepts, 0-5. `iconEmojiId` is one of the ids `forumTopicDefaultIcons`
/// answers, or 0 for a colour-only icon.
/// The custom emoji any account may use as a topic icon. Each entry:
/// "id" (the icon_custom_emoji_id) and "emoji" (its character).
/// Changes only the icon; the name stays. An emoji id of 0 removes it.
/// TDLib will not edit the General topic's icon, so a failure is normal there.
/// Renaming only, unless `iconEmojiId` says the icon changes with it.
/// A forum shown as one flow of messages instead of a list of topics.
/// Turns a channel's direct-messages group on or off; the group is where
/// readers' replies collect. `paidStars` is what a non-admin pays per
/// message, 0 for free. Owner only.
/// Whether the signed-in user may post in a chat. A channel you only follow
/// says NO, and the composer has to go away rather than fail on send.
- (void)canSendInChat:(int64_t)chatId completion:(void (^)(BOOL canSend, BOOL isChannel))completion;

/// Whether this chat is the Saved Messages chat, read off the row the list
/// keeps. NO when the chat is anything else or not loaded.
- (BOOL)chatIsSavedMessages:(int64_t)chatId;

/// Delete a chat's history for the current user, and leave it if it is a group.
- (void)deleteChat:(int64_t)chatId;

/// Members of a group or supergroup: "id", "name", "status" and "owner".
/// Empty for anything else. The role travels with the row so a list can draw
/// an owner or administrator badge beside the name without a second request.
/// The pinned message of a chat, flattened, or nil if there is none.
- (void)pinnedMessageForChat:(int64_t)chatId
                  completion:(void (^)(NSDictionary *message))completion;

/// Deletes a group or channel for every member. Owner only; `error` says
/// why not otherwise.
- (void)deleteChatForEveryone:(int64_t)chatId completion:(void (^)(NSString *error))completion;

/// The pinned chats in this order, top first; one left out is unpinned.
/// The same for a group or channel: "description", "members" (NSNumber) and
/// "inviteLink". There is deliberately no administrator count: the member
/// list carries each person's role instead.
- (void)chatProfile:(int64_t)chatId completion:(void (^)(NSDictionary *info))completion;

/// Muted state of one chat, as the list already knows it.
- (BOOL)isChatMuted:(int64_t)chatId;

/// Erase the messages of a chat without leaving it.
- (void)clearHistoryInChat:(int64_t)chatId;
/// revoke clears it for the other side too; TDLib honours it in private
/// chats only.
- (void)clearHistoryInChat:(int64_t)chatId revoke:(BOOL)revoke;

/// Look up a public chat by its @username, creating it locally if needed.
/// Answers 0 when there is no such account.
- (void)chatWithUsername:(NSString *)username
              completion:(void (^)(int64_t chatId, NSString *title))completion;

- (void)joinChatByInviteLink:(NSString *)inviteLink
                  completion:(void (^)(int64_t chatId, NSString *title))completion;

/// The unsent message in the composer, kept on Telegram's side so it is
/// there on the next launch and on every other device. Empty text clears it.
- (void)setDraft:(NSString *)text
		  inChat:(int64_t)chatId
		  thread:(int64_t)threadId
		 replyTo:(int64_t)replyToId;

/// What was last typed into this chat and not sent, by any client of this
/// account. Empty when there is none.
- (NSString *)draftForChat:(int64_t)chatId;

/// Clears the @ and the reaction badge. Reading the messages does not: those
/// two counts are kept apart from unread.
- (void)readAllMentionsAndReactionsInChat:(int64_t)chatId;

/// Informs TDLib that chat is opened or closed, freeing background resources.
- (void)openChat:(int64_t)chatId;

@end
