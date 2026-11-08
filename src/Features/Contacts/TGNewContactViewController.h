//
// TGNewContactViewController - a new contact: first name, last name, phone.
//
#import <UIKit/UIKit.h>

@interface TGNewContactViewController : UITableViewController

/// Where the fields start, when the chat adds a name it already knows.
/// Set before the view loads.
@property (nonatomic, copy) NSString *first;
@property (nonatomic, copy) NSString *last;
@property (nonatomic, copy) NSString *phone;

/// An existing contact to edit instead of a new one to import. When set, the
/// form updates this user's name and phone with addContact rather than
/// resolving a number first.
@property (nonatomic, assign) int64_t userId;

@end
