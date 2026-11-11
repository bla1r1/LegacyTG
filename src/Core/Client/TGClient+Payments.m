//
// TGClient+Payments.m - the four payment reads and the offer write.
//
// Every method here names the server's sentence on failure. A saved order
// that is not there is a 404 like any other, a card number the provider does
// not know is an error, and addOffer on a message that is not a suggested
// post is refused - none of those is a boolean that only says "no".
//
#import "TGClient+Payments.h"
#import "TGClientInternal.h"

@implementation TGClient (Payments)

@end

// vim:ft=objc
