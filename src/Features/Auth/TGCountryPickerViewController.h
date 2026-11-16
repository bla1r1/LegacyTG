//
// TGCountryPickerViewController - the phone step's Country list, as official's
// AuthorizationSequenceCountrySelectionController draws it: pushed, a search
// bar on top, every country A-Z under letter headers with the index on the
// right, flag and name with the calling code at the end of the row.
//
#import "TGRowsViewController.h"

@interface TGCountryPickerViewController : TGRowsViewController

/// `countries` are TGAccountStore's entries: "code", "name", "prefix", "flag".
/// `picked` gets the chosen entry; the controller pops itself first.
- (instancetype)initWithCountries:(NSArray *)countries
						   picked:(void (^)(NSDictionary *country))picked;

@end
