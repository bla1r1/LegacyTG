//
// TGListViewController.h - a grouped list built from data, not from a screen.
//
// Tier 2's answer surfaces - an event log, statistics, similar chats, folder
// links, members of a link, message positions - are all the same table: a
// title, an optional second line, and sometimes a tap. One controller keeps
// them from growing seven copies of the same data-source boilerplate.
//
// The controller is a TGRowsViewController: the flat entries below are turned
// into shared rows, so the look is the one every other list gets. The rest of
// the entry-list API (rows, emptyText, listFooter, offersCopy) lives on
// TGRowsViewController, where a migrated screen can reach it directly.
//
#import <UIKit/UIKit.h>
#import "TGRowsViewController.h"

@interface TGListViewController : TGRowsViewController

/// Shown in the navigation bar.
@property (nonatomic, copy) NSString *listTitle;

/// Entries are dictionaries: "title" (required), "detail", "destructive"
/// (NSNumber BOOL) and "tap" (a void block). The setter forwards to the
/// shared listRows, which turns them into rows.
@property (nonatomic, strong) NSArray *rows;

@end
