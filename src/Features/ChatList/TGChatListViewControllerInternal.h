#ifndef TGCHATLISTVIEWCONTROLLERINTERNAL_H
#define TGCHATLISTVIEWCONTROLLERINTERNAL_H

#import "TGChatListViewController.h"
#import "TGChatViewController.h"
#import "TGChatListStore.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGContactsViewController.h"
#import "TGTopicsViewController.h"
#import "TGPopupMenu.h"
#import "TGSnackbar.h"
#import "TGSearchViewController.h"
#import "TGChatRowCell.h"
#import "TGStoryStripRowCell.h"
#import "TGEmptyView.h"
#import "TGImageLruCache.h"
#import <QuartzCore/QuartzCore.h>

@interface TGChatListViewController () <UISearchBarDelegate, UIGestureRecognizerDelegate>

@property (nonatomic, strong) TGEmptyView *emptyView;
@property (nonatomic, strong) NSArray *chats;
@property (nonatomic, assign) BOOL showsArchive;      // this IS the archive screen
@property (nonatomic, assign) NSInteger folderId;     // 0 = no folder
@property (nonatomic, assign) BOOL editingChats;
@property (nonatomic, strong) UIButton *editButton;
@property (nonatomic, strong) UIToolbar *editBar;
// A folder pill being dragged to a new slot: where on the pill the finger
// grabbed it, and the frame it lifted from.
@property (nonatomic, assign) CGFloat folderDragOffset;
@property (nonatomic, assign) CGRect folderDragFrame;
@property (nonatomic, strong) TGImageLruCache *avatars;   // fileId -> UIImage (cap 120)
@property (nonatomic, strong) NSMutableSet *avatarsRequested;
@property (nonatomic, strong) UISearchBar *searchBar;
/// The navigation bar's two lines: the list's name, and - only while TDLib is
/// not ready - the connection state beneath it. The state used to replace the
/// name, so a chosen folder was forgotten by the next reconnect.
@property (nonatomic, strong) UIView *listTitleView;
@property (nonatomic, strong) UILabel *listTitleLabel;
@property (nonatomic, strong) UIButton *listLockButton;
@property (nonatomic, strong) UIButton *listStoryAvatar;
/// The story strip is a pull-down sheet: collapsed into the title avatar,
/// expanded above the search field only while somebody else has a story.
@property (nonatomic, assign) BOOL storiesExpanded;
@property (nonatomic, strong) TGStoryStripRowCell *headerStoriesCell;
@property (nonatomic, strong) UILabel *listSubtitleLabel;
@property (nonatomic, copy) NSString *connectionLine;
- (void)buildListTitleView;
- (void)refreshListTitleView;
/// The title-view padlock used when a passcode is set.
UIImage *TGChatListLockIcon(CGFloat side, UIColor *colour);
@property (nonatomic, strong) NSArray *searchResults;   // nil = not searching
@property (nonatomic, strong) NSDictionary *actionChat; // long-pressed row
/// On iOS below 8 the table cannot draw row actions, so this screen swipes
/// one row itself. The cell is weak: the reuse pool may outlive a reload.
@property (nonatomic, weak) TGChatRowCell *swipeActionsCell;
@property (nonatomic, strong) NSDictionary *swipeActionsChat;
@property (nonatomic, strong) UIPanGestureRecognizer *swipeActionsPan;
/// The tap that closed a row must not also select the row and open the chat.
@property (nonatomic, assign) BOOL swipeActionsSuppressSelection;
@property (nonatomic, assign) int64_t chatPendingDeletion;
@property (nonatomic, assign) CGFloat headerHeight;
@property (nonatomic, assign) CGFloat parkOffset;  // scroll that hides search + archive strip
@property (nonatomic, assign) BOOL userRevealed;   // the strip was pulled out on purpose; keep it
@property (nonatomic, assign) BOOL folderHighlightPending;
@property (nonatomic, assign) NSInteger folderHighlightPreviousId;
@property (nonatomic, assign) BOOL folderListFadePending;
/// The stories strip was just pulled out or walked away; the next header
/// rebuild fades instead of replacing the strip in one frame.
@property (nonatomic, assign) BOOL storiesFadePending;
@property (nonatomic, strong) NSArray *mergedChats;   // all chats: main + folders
@property (nonatomic, copy) NSString *mergedSignature;
@property (nonatomic, assign) BOOL mergeInFlight;
/// The last list written to disk, drawn on the first frame before TDLib's
/// loadChats has answered. Cleared as soon as the live list arrives.
@property (nonatomic, strong) NSArray *cachedChats;
/// YES once TDLib has answered with a list (even an empty one) or the
/// connection reached ready; before that the empty state is a false claim.
@property (nonatomic, assign) BOOL listAnswered;
@property (nonatomic, assign) NSTimeInterval snapshotWrittenAt;
/// The stories strip's rows, newest first. Loaded from -activeStoryRowsForList:
/// and only re-read when the last read is a few seconds old, because the
/// chat list reloads for every chat update and each strip read is up to 60
/// getChatActiveStories calls.
@property (nonatomic, strong) NSArray *storyRows;
@property (nonatomic, strong) NSDate *storyRowsReadAt;
@property (nonatomic, assign) BOOL storyRowsLoading;

- (void)reload;
- (void)reloadStoriesIfNeeded;
- (void)showStoryRow:(NSDictionary *)row;
- (void)runStoryRowMenu:(NSDictionary *)row;
- (void)openStoryComposer;
- (void)openStoriesMenu;
- (void)mergeAllFolderChats;
- (void)rebuildTableHeader;
- (void)folderTabTapped:(UIButton *)pill;
- (void)hideHeaderAboveFrom:(CGFloat)previousHeight;
- (void)refreshEditToolbar;
- (NSArray *)visibleChats;
- (NSArray *)headerRows;
- (void)openArchive;
- (void)openSavedMessages;
- (void)reloadTableDebounced;
- (void)fetchMissingAvatars;

@end

@interface TGChatListViewController (Actions)

- (void)runFolderChoice:(NSInteger)choice;
- (NSString *)titleForCurrentList;
- (void)rowHeld:(UILongPressGestureRecognizer *)hold;
- (void)showActionsForRow:(NSInteger)row;
- (void)runChatAction:(NSString *)action;
- (void)confirmDeleteChat:(int64_t)chatId;
- (void)installLegacySwipeActions;
- (void)closeSwipeActionsAnimated:(BOOL)animated;
- (void)openSwipeActionsAtRow:(NSInteger)row;
- (NSArray *)loadChatSnapshot;
- (void)saveChatSnapshot:(NSArray *)chats;
- (NSDictionary *)collapsedStoryRow;
- (void)openChatInfo:(NSDictionary *)c;
- (void)buildHeaderButtons;
- (void)buildListTitleView;
- (void)refreshListTitleView;
- (void)reload;
- (void)reloadTableDebounced;
- (void)applyFolderListFadeIfNeeded;
- (void)hideEditBarAnimated;
- (void)mergeAllFolderChats;
- (NSArray *)headerRows;
- (BOOL)hasArchiveRow;
- (void)reloadStoriesIfNeeded;
- (void)showStoryRow:(NSDictionary *)row;
- (void)runStoryRowMenu:(NSDictionary *)row;
- (void)openStoryComposer;
- (void)openStoriesMenu;
- (void)openArchive;
- (void)fetchMissingAvatars;
- (NSArray *)visibleChats;
- (void)configureStoriesCell:(TGStoryStripRowCell *)strip;
- (void)reloadVisibleRows;
- (void)hideHeaderAboveFrom:(CGFloat)previousHeight;

@end

@interface TGChatListViewController (Search)

- (void)styleSearchBar;

@end

#endif // TGCHATLISTVIEWCONTROLLERINTERNAL_H
