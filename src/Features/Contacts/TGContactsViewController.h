//
// TGContactsViewController - contacts list controller backed by TDLib.
//
#import <UIKit/UIKit.h>
#import "TGRowsViewController.h"

@interface TGContactsViewController : TGRowsViewController

/// Picking people for a new group instead of opening a chat: a tap ticks a
/// row, and Create in the navigation bar asks for the group's name. Set
/// before the view loads.
@property (nonatomic, assign) BOOL picksGroupMembers;

/// The pencil's New Message: New Group and New Channel stand above the
/// contacts, as official's compose screen has them. New Channel runs this.
@property (nonatomic, copy) void (^onNewChannel)(void);

/// Picking people to add to a chat that already exists. Same ticking, but
/// Add puts them straight into `addingToChatId`.
@property (nonatomic, assign) int64_t addingToChatId;

@end
