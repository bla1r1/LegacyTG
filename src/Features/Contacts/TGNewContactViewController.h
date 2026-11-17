//
// TGNewContactViewController - a new contact: first name, last name, phone.
//
#import <UIKit/UIKit.h>
#import "TGRowsViewController.h"

@interface TGNewContactViewController : TGRowsViewController

/// Where the fields start, when the chat adds a name it already knows.
/// Set before the view loads.
@property (nonatomic, copy) NSString *first;
@property (nonatomic, copy) NSString *last;
@property (nonatomic, copy) NSString *phone;

/// An existing contact to edit instead of a new one to import. When set, the
/// form updates this user's name and phone with addContact rather than
/// resolving a number first.
@property (nonatomic, assign) int64_t userId;

/// A profile whose owner hides their number from this account
/// (need_phone_number_privacy_exception) offers "Share My Phone Number",
/// on by default, under the fields (official NewContactScreen
/// shareViaException). `shareName` fills its footer.
@property (nonatomic, assign) BOOL offersPhoneShare;
@property (nonatomic, copy) NSString *shareName;

@end
