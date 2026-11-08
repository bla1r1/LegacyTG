#import <UIKit/UIKit.h>

/// A QR code for `string`, `size` points square, black on white; nil when
/// the system has no generator. Shared by the login QR and the account QR.
UIImage *TGQRCodeImage(NSString *string, CGFloat size);
