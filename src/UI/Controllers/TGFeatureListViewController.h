//
// TGFeatureListViewController.h - the row model three Tier 2 screens share.
//
// Communities, quick replies and the message tools are all settings-shaped
// lists: a title, a value on the right, and a tap. Their rows are dictionaries
// rather than eight hand-written table views, the way Settings does it.
//
#import <UIKit/UIKit.h>

extern NSString *const TGFeatureRowTitle;
extern NSString *const TGFeatureRowDetail;
extern NSString *const TGFeatureRowKind;
extern NSString *const TGFeatureRowTap;
extern NSString *const TGFeatureRowChecked;
extern NSString *const TGFeatureRowSubtitle;
extern NSString *const TGFeatureRowDestructive;
extern NSString *const TGFeatureRowOpens;

extern NSString *const TGFeatureKindPlain;
extern NSString *const TGFeatureKindDisclosure;
extern NSString *const TGFeatureKindCheck;
extern NSString *const TGFeatureKindAction;
extern NSString *const TGFeatureKindDestructive;

NSMutableDictionary *TGFeatureRow(NSString *title, NSString *detail, void (^tap)(void));
NSMutableDictionary *TGFeatureOpenRow(NSString *title, NSString *detail, void (^tap)(void));
NSMutableDictionary *TGFeatureAction(NSString *title, void (^tap)(void));
NSMutableDictionary *TGFeatureCheck(NSString *title, NSString *detail, BOOL checked,
								  void (^tap)(void));
NSDictionary *TGFeatureSection(NSString *header, NSString *footer, NSArray *rows);

@interface TGFeatureListViewController : UITableViewController

/// Each section is "header", "footer" and "rows". Subclasses replace this
/// and call -reloadRows.
@property (nonatomic, strong) NSArray *sections;

- (void)reloadRows;
- (void)applyTheme;
- (void)toast:(NSString *)text;

@end

/// A read-only text screen with Copy, and Send when the caller has a chat to
/// put the text in.
@interface TGFeatureResultViewController : UIViewController

@property (nonatomic, copy) NSString *body;
@property (nonatomic, copy) void (^onSend)(NSString *text);

- (instancetype)initWithTitle:(NSString *)title body:(NSString *)body;

@end
