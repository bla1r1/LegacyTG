//
// TGGroupSettingsViewController.h - the group's own screen: its identity,
// its members, the switches that change how it behaves, and the tools that
// act on the chat as a whole.
//
// The profile's More menu used to carry each of these as one row. A group
// has enough settings to deserve a screen, and a settings screen can show
// what a row is set to instead of asking the server after a tap.
//
#import <UIKit/UIKit.h>

@class TGGroupSettingsViewController;

@interface TGGroupSwitch : UISwitch
@property (nonatomic, copy) NSString *key;
@end
