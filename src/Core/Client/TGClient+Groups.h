//
// TGClient+Groups.h - the client surface for basic groups, supergroups and their invite links.
//
#import "TGClient+Base.h"

/// A chatMemberStatus dictionary as the one word a row shows:
/// "owner", "admin", "restricted", "banned", "left" or "member".
FOUNDATION_EXPORT NSString *TGMemberStatusName(NSDictionary *status);

@interface TGClient (Groups)

/// The supergroup id behind a chat id, asked for rather than guessed: the
/// toggles in TGClient+Usernames and the flags below all name a supergroup
/// while a screen only holds the chat. 0 for a basic group.
- (void)supergroupIdForChat:(int64_t)chatId
				 completion:(void (^)(int64_t supergroupId))completion;

/// What three supergroup switches sit on right now, so a row can name the
/// flip rather than the state. NO/NO/NO/NO when the chat is not a supergroup.
/// Whether new members see the history before they joined. A supergroup or a
/// channel only, and an administrator's switch.
/// Aggressive anti-spam is a supergroup-only switch, and TDLib says whether
/// this group may carry it at all. `canToggle` is read from the same full
/// info the switch writes through.
- (void)setChat:(int64_t)chatId
	aggressiveAntiSpam:(BOOL)on
			 completion:(void (^)(BOOL ok, NSString *error))completion;

/// The deleted-message entries in the group's event log that Telegram says
/// may be reported. Each row carries "messageId", "date", "text", "sender"
/// and "canReport"; only canReport rows are returned because the rest have
/// no request that succeeds.
/// The basic group's own record: "id", "title" (from its chat), "members",
/// "status" (one word), "active" and "upgradedTo" (0 until it became a
/// supergroup). Nil on an error.
/// Join or leave a channel or supergroup.
- (void)setChat:(int64_t)chatId joined:(BOOL)joined;

/// Pin or unpin a chat in the main list.
- (void)setChat:(int64_t)chatId pinned:(BOOL)pinned;

/// Mute forever, or unmute.
- (void)setChat:(int64_t)chatId muted:(BOOL)muted;

/// Messages in this chat delete themselves after `seconds`; 0 turns it off.
- (void)setChat:(int64_t)chatId autoDeleteSeconds:(NSInteger)seconds;

/// Move a chat into the archive, or back out of it.
- (void)setChat:(int64_t)chatId archived:(BOOL)archived;

/// The blue dot you put there yourself; it survives until the chat is opened.
- (void)setChat:(int64_t)chatId markedUnread:(BOOL)unread;

/// Makes a basic group - their New Group - holding `userIds`. TDLib refuses
/// an empty one, so at least one other person is required. The completion
/// gets the new chat's id, and the ids of anyone whose privacy settings
/// refused the invitation.
/// A supergroup, or a channel with `isChannel`.
- (void)createSupergroupNamed:(NSString *)title
				  description:(NSString *)description
					isChannel:(BOOL)isChannel
				   completion:(void (^)(int64_t chatId))completion;

/// Past 200 members, or for a username or admins with rights, a basic group
/// has to become a supergroup. The chat id changes, hence the answer.
/// The picker's batch, in one request. Same failed-half answer.
/// One member's own record; nil when there is no such member.
/// What members may do, as a preset word: "all", "text" or "read". The
/// fifteen booleans TDLib keeps are built from it.
/// Handing a chat over, with the password two-factor asks for. Final.
/// Members of a chat, filtered by `query`; an empty query is the whole list.
/// Entries carry "id", "name" and "status" (owner/admin/member/...).
/// Only the administrators - a different request, and the only one that says
/// who the owner is. Entries carry "id", "name", "owner" and "editable".
/// "administrator", "member" or "left". Anything else is refused rather than
/// guessed at, because the wrong word here removes people.
/// Not the same as removing: a banned member cannot return on a link.
- (void)setChat:(int64_t)chatId title:(NSString *)title
	 completion:(void (^)(BOOL ok))completion;

/// A supergroup or channel only; a basic group has nowhere to put one.
- (void)setChat:(int64_t)chatId description:(NSString *)description
	 completion:(void (^)(BOOL ok))completion;

- (void)setChat:(int64_t)chatId photoAtPath:(NSString *)path
	 completion:(void (^)(BOOL ok))completion;

/// Every link the chat has, flattened to "link", "name", "members",
/// "memberLimit", "primary", "revoked" and "requests".
/// A link of its own, revocable without taking the primary one down with it.
/// A `memberLimit` of zero is no limit.
/// Replaces the chat's primary link; the old one stops working at once.
/// What is behind a link before joining it.
/// People waiting at a link that creates join requests: "id", "name", "date".
- (void)joinRequestsForChat:(int64_t)chatId
				 completion:(void (^)(NSArray *requests))completion;

- (void)processJoinRequest:(int64_t)userId inChat:(int64_t)chatId approve:(BOOL)approve;

/// The sticker pack a supergroup shows above its composer. `setId` is a pack
/// id from getOwnedStickerSets; 0 clears it. A basic group has nowhere to
/// put one, so the answer is NO rather than a request Telegram would refuse.
/// The custom emoji pack a supergroup uses for reactions and its emoji
/// status. Same id shape and same basic-group refusal as the regular one.
@end
