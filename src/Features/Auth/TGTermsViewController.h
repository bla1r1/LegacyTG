//
// TGTermsViewController.h - the terms Telegram sends after sign-in.
//
// The update names an id that has to be accepted before the account goes on;
// this is the screen that shows the text and sends it back.
//
#import <UIKit/UIKit.h>
#import "TGViewController.h"

@interface TGTermsViewController : TGViewController

@property (nonatomic, copy) NSString *termsText;
/// Runs once, when Accept is tapped, before the screen goes away.
@property (nonatomic, copy) void (^onAccept)(void);
/// Runs when Decline is tapped, before the screen goes away. Optional.
@property (nonatomic, copy) void (^onDecline)(void);

@end
