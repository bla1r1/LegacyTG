//
// TGCallViewController - the screen for one call.
//
#import <UIKit/UIKit.h>

@class TGCallViewController;

@interface TGCallMiniBar : NSObject
@property (nonatomic, assign) int64_t userId;
@property (nonatomic, copy) NSString *peerName;
+ (instancetype)shared;
- (void)showForUserId:(int64_t)userId name:(NSString *)name;
- (void)hide;
- (void)stopClock;
@end
