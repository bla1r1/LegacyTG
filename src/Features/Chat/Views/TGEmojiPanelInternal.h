#import "TGEmojiPanel.h"
#import <UIKit/UIKit.h>

@interface TGEmojiPanel () <UIScrollViewDelegate>
@property (nonatomic, assign) TGEmojiPanelTab tab;
@property (nonatomic, strong) UIScrollView *strip;
@property (nonatomic, strong) UIScrollView *grid;
@property (nonatomic, strong) UIView *tabs;
@property (nonatomic, strong) UIView *stripLine;
@property (nonatomic, strong) UIView *tabsLine;
@property (nonatomic, strong) NSArray *tabButtons;
@property (nonatomic, strong) UIButton *backspace;
@property (nonatomic, strong) UILabel *emptyLabel;

/// What the grid shows right now, and the strip entry it came from.
@property (nonatomic, strong) NSArray *items;
/// Stickers are one continuous feed the way their client shows it, so the
/// grid is cut into named sections over the flat `items`: each entry carries
/// a title, the range it covers, and the y it was laid out at, which is what
/// the strip scrolls to and highlights from.
@property (nonatomic, strong) NSArray *sections;
@property (nonatomic, assign) BOOL syncingStrip;
/// Where every item sits, worked out once per layout. Only the cells on
/// screen exist as views: a set of a hundred stickers times a dozen sets is
/// more buttons than an A5 will build in one run loop turn, and building
/// them all again for every set that answered froze the whole app.
@property (nonatomic, strong) NSArray *frames;
@property (nonatomic, strong) NSMutableDictionary *cells;   // index -> button
@property (nonatomic, strong) NSMutableArray *pool;         // buttons off screen
@property (nonatomic, assign) BOOL relayoutQueued;
@property (nonatomic, assign) NSTimeInterval menuOpenUntil;
@property (nonatomic, assign) NSInteger stripIndex;
@property (nonatomic, strong) NSMutableSet *requested;   // grid indexes asked for

@property (nonatomic, strong) NSArray *stickerSets;      // installed, as the store gives them
@property (nonatomic, strong) NSArray *customEmojiSets;
@property (nonatomic, assign) BOOL customEmojiLoaded;
@property (nonatomic, strong) NSString *gifQuery;        // nil for the saved ones
/// Telegram's categories once they have arrived. Empty means the built-in set
/// from TGEmojiData is still what the strip draws.
@property (nonatomic, strong) NSArray *serverCategories;
/// The word the emoji tab is searching for, or nil for the category grid.
@property (nonatomic, strong) NSString *emojiQuery;
/// An emoji the sticker tab is searching for, or nil for the usual feed of
/// favourites, recents and installed sets.
@property (nonatomic, strong) NSString *stickerQuery;
/// Bumped every time the grid is rebuilt, so an answer for an older grid
/// is dropped rather than drawn into the wrong cell.
@property (nonatomic, assign) NSUInteger generation;
// A set pill being dragged along the strip: where the finger grabbed it,
// and the frame it lifted from.
@property (nonatomic, assign) CGFloat stickerDragOffset;
@property (nonatomic, assign) CGRect stickerDragFrame;
- (void)reloadGrid;
- (void)setNeedsFeedRelayout;
- (void)updateStripHighlight;
- (void)loadItemsForStripIndex:(NSInteger)index;
- (void)loadImageForFile:(NSInteger)fileId into:(UIButton *)button generation:(NSUInteger)generation;
- (void)reloadStrip;
- (void)selectTab:(TGEmojiPanelTab)tab;
- (void)stickerListsChanged;
- (void)applyTheme;
- (void)loadCustomEmojiSetsIfNeeded;
- (void)loadCustomEmojiFeed;
- (NSArray *)emojiCategories;
- (void)loadEmojiCategoriesIfNeeded;
- (NSArray *)stripEntries;
- (void)loadStickerFeed;
- (void)updateVisibleCells;
- (void)buildCellAtIndex:(NSUInteger)index frame:(CGRect)frame;
- (void)syncStripToScroll;
- (NSDictionary *)sectionForItemIndex:(NSInteger)index;
- (void)itemTapped:(UIButton *)button;
- (void)gridHeld:(UILongPressGestureRecognizer *)hold;
- (CGSize)cellSize;
- (void)showStickerPreview:(NSDictionary *)info caption:(NSString *)caption;
- (void)askForGifSearch;
- (void)askForStickerSearch;
- (void)askForEmojiSearch;
- (void)askInstallForStickerSet:(NSDictionary *)set;
- (void)loadEmojiSearch;
- (void)loadStickerSearch;
- (void)showEmojiCardForEmoji:(NSString *)emoji atButton:(UIButton *)button;
- (BOOL)stickerIsFavourite:(NSInteger)fileId;
- (void)showArchivedPacks;
- (void)showEmojiTagsOfStickerWithFileId:(NSInteger)fileId title:(NSString *)emoji;
- (void)showOutlineOfStickerWithFileId:(NSInteger)fileId;
- (void)tabTapped:(UIButton *)button;
- (void)stripTapped:(UIButton *)button;
- (void)stickerSetDragged:(UILongPressGestureRecognizer *)gesture;
- (void)loadVisibleImages;
- (void)backspaceTapped;
- (void)customEmojiLoaded:(NSNotification *)note;
@end
