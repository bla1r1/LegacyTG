#ifndef TGPROFILEVIEWCONTROLLERINTERNAL_H
#define TGPROFILEVIEWCONTROLLERINTERNAL_H

#import "TGProfileViewController.h"
#import "TGProfileStore.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGCallViewController.h"
#import "TGPopupMenu.h"
#import "TGForwardPicker.h"
#import "TGStyle.h"
#import "TGStreamingVoicePlayer.h"
#import "TGEditProfileViewController.h"
#import "TGCapabilities.h"

@class TGProfileHeaderView;

static const CGFloat kActionTile = TGMetricActionTile;

// ── the profile's own geometry ───────────────────────────────────────────────
// The header stacks a picture, a name and a status line; the lists below it
// carry a thumbnail each. Built out of TGStyle's scales, named here because
// no other screen stacks them this way.

/// The picture's gap from the top of the header, then the name under it, then
/// the status line, then the row of action tiles.
static const CGFloat kAvatarTop     = TGMetricPadLarge;
static const CGFloat kNameTop       = TGMetricPad;
static const CGFloat kStatusTop     = TGMetricPad + TGMetricLineTitle;
static const CGFloat kActionsTop    = TGMetricPad + TGMetricLineTitle + TGMetricLineBody
		+ TGMetricPadMedium;
/// The side inset the header's text keeps, which is its own and not the
/// table's: the labels are centred, so this only stops a long name touching
/// the edge.
static const CGFloat kHeaderTextInset = TGMetricPadMedium;
/// The pill bar that picks a media tab, on a header of its own.
static const CGFloat kMediaTabsRow = TGMetricFolderTabRow;
static const CGFloat kMediaTabs    = TGMetricSearchScopeHeight;
/// A verified badge or an emoji status drawn beside the name, baked as a
/// static image rather than a masked layer on a scrolling header.
static const CGFloat kNameBadge     = TGMetricLineCaption;
/// The saved-music strip under the action plates: one glyph, the track, the
/// artist and a chevron, in a row tall enough to hit on a 3.5" screen.
static const CGFloat kMusicStripHeight = TGMetricRow;
static const CGFloat kMusicStripGlyph  = TGMetricSearchIconSize;
/// A story's thumbnail, and the emoji tile a gift is drawn into.
static const CGFloat kStoryThumb    = TGMetricListAvatar;
static const CGFloat kGiftTile      = TGMetricListAvatar;
static const CGFloat kGiftTileInset = TGMetricBorderWidth;
/// The glyph beside a link in the media list.
static const CGFloat kLinkGlyph     = 24.0f;
/// The "Copied" toast, which is as wide as that word needs and no wider.
static const CGFloat kToastWidth    = 120.0f;
static const CGFloat kToastHeight   = 34.0f;

static const NSInteger kSectionCommunity       = 0;
static const NSInteger kSectionPersonalChannel = 1;
static const NSInteger kSectionDetails         = 2;
static const NSInteger kSectionDanger          = 3;
static const NSInteger kSectionDirectMessages  = 4;
static const NSInteger kSectionStories         = 5;
static const NSInteger kSectionGifts           = 6;
static const NSInteger kSectionMembers         = 7;
static const NSInteger kSectionMedia           = 8;

static const NSInteger kStoryGridCols  = 3;
static const CGFloat   kStoryGridGap   = TGMetricCollageGap;

/// The address a piece of text links to; nil when it has none.
NSURL *TGProfileFirstURL(NSString *text, NSArray *entities);

@interface TGProfileViewController () <TGStreamingVoicePlayerDelegate, UISearchBarDelegate>

@property (nonatomic, strong) NSMutableSet *thumbnailsRequested;
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, assign) int64_t userId;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSArray *details;   // label/value pairs
@property (nonatomic, strong) NSArray *photos;    // flattened messages
@property (nonatomic, strong) NSArray *files;
@property (nonatomic, strong) NSArray *voice;
@property (nonatomic, strong) NSArray *links;
@property (nonatomic, strong) NSArray *music;     // audio messages (Music tab)
@property (nonatomic, strong) NSArray *groupsInCommon;
@property (nonatomic, strong) NSMutableDictionary *coverImages;
@property (nonatomic, assign) BOOL isLoadingMoreMedia;
/// The categories the bar is showing, in order: each is @{"title", "kind"}.
/// Built fresh on every render by currentMediaTabs.
@property (nonatomic, copy)   NSString *mainMediaKind;
/// The bar search for the Files, Music and Links panes; nil shows everything.
@property (nonatomic, copy)   NSString *mediaSearchQuery;
/// The pane's search field is open. Cancel hides the field and returns the
/// unfiltered list; a tab switch does the same.
@property (nonatomic, assign) BOOL mediaSearchActive;
@property (nonatomic, strong) UISearchBar *mediaSearchBar;
/// Kinds whose page has already been asked for, so a re-selected tab does not
/// re-request its list on every switch (item 8: fetch when opened).
@property (nonatomic, strong) NSMutableSet *loadedMediaKinds;
@property (nonatomic, strong) NSMutableSet *loadingMediaKinds;
/// The total a tab reports, keyed by kind, for the subtitle under the header.
@property (nonatomic, strong) NSMutableDictionary *mediaCounts;
@property (nonatomic, strong) NSArray *members;
@property (nonatomic, strong) NSArray *gifts;
@property (nonatomic, copy) NSString *giftsNextOffset;
@property (nonatomic, strong) NSArray *stories;
@property (nonatomic, strong) NSArray *archivedStories;
/// The first saved track from userFullInfo, shown under the action plates
/// before the full profile-audio page answers.
@property (nonatomic, strong) NSDictionary *firstProfileAudio;
@property (nonatomic, assign) BOOL blocked;
@property (nonatomic, strong) TGProfileHeaderView *headerView;
@property (nonatomic, strong) NSMutableDictionary *mediaImages;
// What the status line would say without the network: the last seen that
// answered, or the member count. The network override for TDLib-not-ready
// lives in statusLabelOwnerChanged (B4).
@property (nonatomic, strong) NSString *restingStatus;
- (void)statusLabelOwnerChanged:(NSNotification *)note;
- (void)updateNavigationItem;
- (void)showQRCodeForValue:(NSString *)value;
- (void)mediaSearchTapped;
/// The pane's search field, created once and re-used across reloads so the
/// keyboard survives a keystroke.
- (UISearchBar *)ensureMediaSearchBar;
@property (nonatomic, assign) BOOL muted;
@property (nonatomic, strong) NSString *phoneNumber;
/// The note kept on this person's profile, and whether a private picture is
/// already set. Both are read back from userFullInfo and change the menu.
@property (nonatomic, copy) NSString *personalNote;
@property (nonatomic, assign) BOOL hasPersonalPhoto;
/// Which user action the photo picker is answering: "suggest", "personal".
@property (nonatomic, copy) NSString *pendingPhotoAction;

// Wave 1 additions: what the header and card read from the two profile calls.
@property (nonatomic, assign) NSInteger onlineCount;
@property (nonatomic, assign) NSInteger commonGroupCount;
@property (nonatomic, assign) BOOL isVerified;
@property (nonatomic, assign) BOOL isScam;
@property (nonatomic, assign) BOOL isFake;
@property (nonatomic, assign) BOOL isContact;
@property (nonatomic, assign) int64_t directMessagesChatId;
@property (nonatomic, assign) BOOL hasDirectMessages;
@property (nonatomic, assign) BOOL canManageDirectMessages;
@property (nonatomic, assign) int64_t communityId;
@property (nonatomic, copy) NSString *communityName;
@property (nonatomic, copy) NSString *communitySubtitle;
@property (nonatomic, assign) NSInteger personalChannelMemberCount;
@property (nonatomic, copy) NSString *personalChannelPreview;
@property (nonatomic, strong) NSArray *similarChatIds;
@property (nonatomic, strong) NSMutableDictionary *chatAvatars;
@property (nonatomic, strong) NSMutableSet *requestedChatAvatars;
@property (nonatomic, strong) NSMutableDictionary *similarChannelAvatars;
@property (nonatomic, strong) NSMutableSet *similarChannelsRequested;
@property (nonatomic, strong) UIImage *similarChannelsCompositeImage;
@property (nonatomic, assign) BOOL isBot;
@property (nonatomic, assign) BOOL birthdayToday;
@property (nonatomic, assign) int64_t emojiStatusId;
@property (nonatomic, strong) UIImage *emojiStatusImage;
@property (nonatomic, assign) CGFloat mediaTabsOffset;
@property (nonatomic, strong) UIImage *avatarImage;
@property (nonatomic, strong) NSNumber *avatarFileId;
/// Whether the owner allows calls and video calls; the tiles follow these
/// instead of the device's own codec support.
@property (nonatomic, assign) BOOL canCall;
@property (nonatomic, assign) BOOL canVideoCall;
/// The person's personal channel: "chatId", "title", "photoFileId". nil when
/// none is set.
@property (nonatomic, strong) NSDictionary *personalChannel;
/// The bio's entities, so the wrapped row keeps its links and mentions.
@property (nonatomic, strong) NSArray *bioEntities;
@property (nonatomic, strong) NSArray *noteEntities;
/// The active username, kept apart from the rows so the full-info pass can
/// rebuild the card without a second getUser.
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSArray *activeUsernames;
@property (nonatomic, copy) NSString *businessLocation;
/// The voice/round note playing from the Voice tab, and which message id.
@property (nonatomic, strong) TGStreamingVoicePlayer *voicePlayer;
@property (nonatomic, assign) int64_t playingVoiceId;

- (void)buildHeader;
- (void)openDirectMessages;
- (void)loadDetails;
- (void)reloadTableDebounced;
- (void)doReloadTable;
- (void)rebuildSections;
- (void)showMemberActionsFor:(NSDictionary *)member;
- (void)applyAvatarImageAtPath:(NSString *)path;
- (void)musicStripTapped;
- (void)handleActionKey:(NSString *)action;
- (void)loadSimilarChannelsAvatars;
- (void)openCommunity;
- (void)openDetailKind:(NSString *)kind;
- (void)openChat:(int64_t)chatId title:(NSString *)title message:(int64_t)messageId;
- (void)openMediaRow:(NSInteger)index;
- (void)copyDetailValue:(NSString *)value;
- (void)setMainTabKind:(NSString *)kind;
- (NSInteger)mediaSectionIndex;
- (void)avatarTapped;

/// The description the group profile's details section reads.
@property (nonatomic, copy) NSString *chatDescription;
/// A group's total member count. The member list is capped at what Telegram
/// returned first, so the header cannot count the rows.
@property (nonatomic, assign) NSInteger memberCount;
/// "owner", "admin", "member" or nil while getChatMember is still running.
/// Used for the same gating Group Settings does: only an administrator's
/// menu offers adding people or deleting the group.
@property (nonatomic, copy) NSString *myStatus;
@property (nonatomic, strong) NSDictionary *myRights;
@property (nonatomic, assign) BOOL canManage;
/// The group's public @name from getSupergroup, nil until that read answers.
/// The info card prints https://t.me/<name>; an empty string means "asked,
/// this group has no public name", so the read is not repeated.
@property (nonatomic, copy) NSString *groupUsername;
@property (nonatomic, assign) BOOL canInvite;
@property (nonatomic, assign) BOOL isGroup;
@property (nonatomic, assign) BOOL isChannel;
@property (nonatomic, strong) NSDictionary *chatPermissions;
@property (nonatomic, assign) int64_t linkedChatId;
@property (nonatomic, copy) NSString *linkedChatTitle;
/// The invite link the info card and menu copy; kept apart from the rows so
/// a reload can name it without rebuilding the card.
@property (nonatomic, copy) NSString *inviteLink;
@property (nonatomic, assign) BOOL descriptionExpanded;

- (void)loadOwnRole;
- (void)updateGroupStatus;
- (BOOL)isOwner;
- (BOOL)isOwnProfile;
- (void)editProfileTapped;
- (void)addStoryTapped;
- (void)leaveChatTapped;
- (void)reloadCommunityRow;
- (void)loadCommunityPhotoOrAvatars;
- (void)openChat:(int64_t)chatId title:(NSString *)title message:(int64_t)messageId;

@end

@interface TGProfileViewController (Actions)

- (void)showMoreMenuFrom:(UIView *)tile;
- (void)runMoreAction:(NSString *)title;
- (void)addMemberTapped;
- (void)messageTapped;
- (void)addToContactsTapped;

@end

@interface TGProfileViewController (Media)

- (NSDictionary *)giftOwnerSenderId;
- (void)loadMedia;
- (void)fetchAllMediaCounts;
- (void)fetchMediaForKind:(NSString *)kind;
- (void)mediaTabSelected:(NSString *)kind;
- (BOOL)showsSavedMessages;
- (void)reloadOwnStories;
- (void)loadVisibleMediaTabIfNeeded;
- (NSArray *)currentMediaTabs;
- (NSString *)selectedMediaKind;
- (BOOL)selectedTabIsGrid;
- (NSArray *)selectedMediaRows;
- (NSArray *)mediaContentRows;
- (void)openMediaGridItemAtIndex:(NSInteger)index kind:(NSString *)kind;
- (void)openStoryAtIndex:(NSInteger)index;
- (void)handleStoryHoldAtIndex:(NSInteger)index;
- (void)loadMoreMediaForCurrentTab;
- (NSString *)linkDomainForMessage:(NSDictionary *)message;
- (void)fetchEmojiStatusImage:(int64_t)emojiId;
- (NSArray *)basicDetailsRows;
- (NSArray *)fullDetailsRowsWithBio:(NSString *)bio birthday:(NSString *)birthday;
- (void)fetchPersonalChannel:(int64_t)chatId;
- (void)checkAndCompositeSimilarChannelsAvatars;
- (void)loadAvatarForChatId:(int64_t)chatId kind:(NSString *)kind;
- (void)downloadMediaImage:(NSNumber *)fileId;

@end

#endif // TGPROFILEVIEWCONTROLLERINTERNAL_H
