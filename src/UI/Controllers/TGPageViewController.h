//
// TGPageViewController.h - a page built from a TGPageTemplate.
//
// The screen gives the template, the sections and the blocks; this builds
// the chrome the template's kind calls for: the page header, a search in
// the list or in the bar, the scope strip, the bar buttons, the action
// pinned under the list and the empty state. TGPageChromeFor decides which.
//
#import "TGRowsViewController.h"
#import "TGPageTemplate.h"

@interface TGPageViewController : TGGridRowsViewController

- (instancetype)initWithTemplate:(TGPageTemplate *)page;

@property (nonatomic, strong, readonly) TGPageTemplate *page;

/// The page header's picture, drawn at the template's headerArtSide.
@property (nonatomic, strong) UIImage *headerArt;

@property (nonatomic, copy) void (^onSearch)(NSString *query);
@property (nonatomic, copy) void (^onScope)(NSInteger index);
@property (nonatomic, copy) void (^onBarAction)(void);
@property (nonatomic, copy) void (^onBottomAction)(void);

/// The pinned action is greyed until there is something to act on.
@property (nonatomic, assign) BOOL bottomActionEnabled;
@property (nonatomic, assign) NSInteger selectedScope;

@end
