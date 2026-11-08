//
// TGMemberListViewController - the people of a group or channel.
//
// Group Settings' Members row used to answer with a sheet of names, which is
// not a list: it could not scroll, show faces, or reach a profile without a
// second tap. This is the pane the official client opens from the same row.
//
#import <UIKit/UIKit.h>
#import "TGTableViewController.h"

@interface TGMemberListViewController : TGTableViewController

@property (nonatomic, assign) int64_t chatId;
/// The rows Group Settings already loaded, so the first paint is immediate.
@property (nonatomic, strong) NSArray *members;
/// "Members" or "Subscribers".
@property (nonatomic, copy) NSString *listTitle;
/// Add Member is the first row when this account may invite people.
@property (nonatomic, assign) BOOL canAddMembers;

@end
