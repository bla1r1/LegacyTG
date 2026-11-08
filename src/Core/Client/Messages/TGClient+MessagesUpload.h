#import <CoreGraphics/CoreGraphics.h>
#import "TGClient+Base.h"

@interface TGClient (MessagesUpload)

/// The upload's last reported fraction for a send, or 0 when it is unknown.
- (CGFloat)sendProgressForMessage:(int64_t)messageId;

@end
