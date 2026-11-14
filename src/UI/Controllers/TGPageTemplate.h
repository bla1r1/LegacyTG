//
// TGPageTemplate.h - the six page shapes every screen is built from, and the
// parts each one switches on.
//
// A screen picks a kind, fills in the strings and turns parts on or off; the
// chrome (table style, background, bar buttons, what sits above and below
// the rows) follows from TGPageChromeFor, so two screens of one kind cannot
// drift apart. TGPageViewController builds the page; this file is the rules,
// with no UIKit, so the host suite checks them.
//
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

typedef NS_ENUM(NSInteger, TGPageKind) {
	/// A settings page: grouped cards, an optional intro, a bar button.
	TGPageKindSettings = 0,
	/// People or chats: white rows on the page, optional search, empty state.
	TGPageKindList,
	/// One thing in detail: the page header, its info cards, a danger action.
	TGPageKindDetail,
	/// Choosing: search, check rows, an action pinned under the list.
	TGPageKindPicker,
	/// Entering: fields, a footer note, Done in the bar.
	TGPageKindForm,
	/// Pictures: scopes in a bar strip, grid rows, an empty state.
	TGPageKindGallery,
};
#define TGPageKindCount 6

typedef NS_ENUM(NSInteger, TGPageSearch) {
	TGPageSearchNone = 0,
	/// Under the navigation bar, scrolling with the rows (contacts, pickers).
	TGPageSearchInList,
	/// In the navigation bar itself, with Cancel (global search, languages).
	TGPageSearchInBar,
};

typedef NS_ENUM(NSInteger, TGPageLeftItem) {
	TGPageLeftBack = 0,   ///< pushed: the system Back
	TGPageLeftClose,      ///< first screen of a sheet: Close
	TGPageLeftNone,       ///< a search in the bar takes the room
};

@interface TGPageTemplate : NSObject

@property (nonatomic, assign) TGPageKind kind;
@property (nonatomic, copy) NSString *title;

/// The page header (TGPageHeaderView): any part may be nil. `headerArtSide`
/// 0 means no picture.
@property (nonatomic, assign) CGFloat headerArtSide;
@property (nonatomic, copy) NSString *headerTitle;
@property (nonatomic, copy) NSString *headerSubtitle;
@property (nonatomic, copy) NSString *headerText;

/// The intro row of a settings page (TGKindPageHeader): a settings icon name
/// and the official sentence.
@property (nonatomic, copy) NSString *introIcon;
@property (nonatomic, copy) NSString *introText;

@property (nonatomic, assign) TGPageSearch search;
@property (nonatomic, copy) NSString *searchPlaceholder;
/// Scope titles for the bar strip under the search or the header; nil for none.
@property (nonatomic, copy) NSArray *scopeTitles;

/// What the page says when every section is empty.
@property (nonatomic, copy) NSString *emptyTitle;
@property (nonatomic, copy) NSString *emptySubtitle;

/// The right bar button (Edit, Done, +); nil for none.
@property (nonatomic, copy) NSString *barActionTitle;
/// The button pinned under the list (Send, Add); nil for none.
@property (nonatomic, copy) NSString *bottomActionTitle;

/// A kind's defaults: its table style and the parts it usually has on.
+ (instancetype)templateWithKind:(TGPageKind)kind;

@end

/// What the page draws around its rows, decided from the template alone.
typedef struct {
	/// Grouped cards (Settings, Detail, Form, Gallery) or a plain list.
	BOOL grouped;
	/// A plain list's rows stay white on the page background.
	BOOL whiteRowsOnPage;
	TGPageLeftItem leftItem;
	BOOL rightItem;
	/// Above the rows, top to bottom; each is on or off.
	BOOL header, searchInList, scopes;
	/// The pinned action bar under the list, and the height it takes.
	BOOL bottomBar;
	CGFloat bottomBarHeight;
	/// A search in the bar replaces the title.
	BOOL titleInBar;
} TGPageChrome;

FOUNDATION_EXPORT TGPageChrome TGPageChromeFor(TGPageTemplate *page, BOOL firstInSheet);

/// The empty state shows when the page has a title for it and no section
/// has a row.
FOUNDATION_EXPORT BOOL TGPageShowsEmpty(TGPageTemplate *page, NSArray *sections);

/// The kind's name for the dev gallery and logs.
FOUNDATION_EXPORT NSString *TGPageKindName(TGPageKind kind);
