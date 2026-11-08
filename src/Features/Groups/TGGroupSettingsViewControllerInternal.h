#import "TGGroupSettingsViewController.h"
#import <UIKit/UIKit.h>

@interface TGGroupSettingsViewController () <UIImagePickerControllerDelegate,
		UINavigationControllerDelegate>
/// The chat record: its type says which rows this chat supports.
@property (nonatomic, strong) NSDictionary *chat;
/// chatProfile: description, member count, the primary invite link.
@property (nonatomic, copy) NSString *descriptionText;
/// supergroupSettingsForChat: usernames and the mode switches; nil for a
/// basic group, which has none of them.
@property (nonatomic, strong) NSDictionary *settings;
/// supergroupFullInfo: slow mode lives here and nowhere else.
@property (nonatomic, strong) NSDictionary *groupInfo;
@property (nonatomic, strong) NSArray *members;
/// Built fresh after every read; cellForRow reads a descriptor rather than
/// counting sections by hand.
@property (nonatomic, strong) NSArray *sections;
@property (nonatomic, copy) NSString *editable;
@property (nonatomic, strong) NSMutableArray *active;
@property (nonatomic, strong) NSMutableArray *disabled;
@property (nonatomic, copy) NSString *inviteLink;
@property (nonatomic, assign) NSInteger memberCount;
@property (nonatomic, assign) NSInteger joinRequestCount;
@property (nonatomic, assign) BOOL signMessages;
@property (nonatomic, assign) BOOL joinToSend;
@property (nonatomic, assign) BOOL allHistory;
/// Aggressive anti-spam is a supergroup-only switch; `canToggleAntiSpam`
/// comes from the same full record and keeps the switch disabled where
/// Telegram does not allow it.
@property (nonatomic, assign) BOOL aggressiveAntiSpam;
@property (nonatomic, assign) BOOL canToggleAntiSpam;
@property (nonatomic, assign) BOOL hasPhoto;
/// This account's own role in the chat. A plain member sees the group's
/// identity and people; the management rows belong to the owner and the
/// administrators, and Telegram would refuse every one of them to anybody
/// else. `myStatus` is "owner", "admin", "member" or nil until it arrives.
@property (nonatomic, copy) NSString *myStatus;
@property (nonatomic, strong) NSDictionary *myRights;
@property (nonatomic, assign) BOOL canManage;
/// The owner has every right; an administrator has only the boxes Telegram
/// ticked. A row whose right is missing is drawn disabled instead of
/// pretending the tap will work.
@property (nonatomic, assign) BOOL isOwner;
@property (nonatomic, assign) BOOL canChangeInfo;
@property (nonatomic, assign) BOOL canInvite;
@property (nonatomic, assign) BOOL canRestrict;
@property (nonatomic, assign) BOOL canDeleteMessages;
/// Kept because a switch's answer is not a full re-read: the local value
/// flips only after Telegram accepted it.
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) BOOL busy;
@property (nonatomic, assign) BOOL pickingPhoto;
@property (nonatomic, assign) BOOL editingNames;
- (void)runAction:(NSString *)action;
- (void)chooseMainTab;
- (void)load;
- (void)rebuild;
- (void)reloadTableDebounced;
- (void)doReloadTable;
- (BOOL)isSupergroupChat;
- (BOOL)isChannelChat;
- (BOOL)isBasicGroupChat;
- (void)showRefusal:(NSString *)error title:(NSString *)title;
- (void)switchChanged:(TGGroupSwitch *)sender;
- (void)setUsername:(NSString *)key active:(BOOL)on sender:(TGGroupSwitch *)sender;
- (void)setBehaviour:(NSString *)key on:(BOOL)on sender:(TGGroupSwitch *)sender;
- (void)updateEditButton;
- (void)toggleEditing;
- (void)addMembers;
- (void)findMember;
- (void)showMembersList;
- (void)choosePermissions;
- (void)chooseSlowMode;
- (void)confirmBroadcast;
- (void)showJoinRequests;
- (void)showWelcomeMessages;
- (void)openChatTools;
- (void)showSendAs;
- (void)chooseDirectMessages;
- (void)clearByDate;
- (void)chooseStickerSet:(BOOL)customEmoji;
- (void)importMessages;
- (void)beginImportFromPath:(NSString *)name inChat:(int64_t)chatId;
- (void)showInviteLink;
- (void)showAllInviteLinks;
- (void)showActionsForInviteLink:(NSDictionary *)link inChat:(int64_t)chatId;
- (void)showMembersOfInviteLink:(NSString *)url inChat:(int64_t)chatId;
- (void)showInviteLinkCounts;
- (void)createSubscriptionLink;
- (void)deleteAllRevokedLinks;
- (void)editName;
- (void)editDescription;
- (void)editPhoto;
- (void)chooseGroupType;
- (void)confirmUpgrade;
- (void)openGroupCall;
- (void)openVideoChatSetup;
- (void)editUsername;
- (void)removeUsername;
- (void)disableAllUsernames;
- (void)leaveChat;
- (void)deleteChatForEveryone;
@end
