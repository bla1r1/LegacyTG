//
// TGFeatureListViewController.h - the Tier 2 lists, now a TGRowsViewController.
//
// Communities, quick replies and the message tools are settings-shaped lists:
// a title, a value on the right, and a tap. They describe rows with the shared
// model and this controller renders them.
//
#import <UIKit/UIKit.h>
#import "TGRowsViewController.h"
#import "TGRows.h"

// The old names stay as thin aliases so the screens that already build these
// rows do not carry a second vocabulary.
#define TGFeatureRowTitle       TGRowTitle
#define TGFeatureRowDetail      TGRowDetail
#define TGFeatureRowKind        TGRowKind
#define TGFeatureRowTap         TGRowTap
#define TGFeatureRowChecked     TGRowChecked
#define TGFeatureRowSubtitle    TGRowSubtitle
#define TGFeatureRowDestructive TGRowDestructive
#define TGFeatureRowOpens       TGRowOpens

#define TGFeatureKindPlain       TGKindPlain
#define TGFeatureKindDisclosure  TGKindDisclosure
#define TGFeatureKindCheck       TGKindCheck
#define TGFeatureKindAction      TGKindAction
#define TGFeatureKindDestructive TGKindDestructive

NSMutableDictionary *TGFeatureRow(NSString *title, NSString *detail, void (^tap)(void));
NSMutableDictionary *TGFeatureOpenRow(NSString *title, NSString *detail, void (^tap)(void));
NSMutableDictionary *TGFeatureAction(NSString *title, void (^tap)(void));
NSMutableDictionary *TGFeatureCheck(NSString *title, NSString *detail, BOOL checked,
								  void (^tap)(void));
NSDictionary *TGFeatureSection(NSString *header, NSString *footer, NSArray *rows);

@interface TGFeatureListViewController : TGRowsViewController
@end

/// A read-only text screen with Copy, and Send when the caller has a chat to
/// put the text in.
@interface TGFeatureResultViewController : UIViewController

@property (nonatomic, copy) NSString *body;
@property (nonatomic, copy) void (^onSend)(NSString *text);

- (instancetype)initWithTitle:(NSString *)title body:(NSString *)body;

@end
