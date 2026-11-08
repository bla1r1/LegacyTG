//
// TGInAppNotificationBanner.h - in-app notification banner for incoming messages.
//
#import <UIKit/UIKit.h>

@interface TGInAppNotificationBanner : UIView

+ (void)showForChatId:(int64_t)chatId
                title:(NSString *)title
                 text:(NSString *)text
               avatar:(UIImage *)avatar
             onTapped:(void (^)(int64_t chatId))onTapped;

+ (void)dismissCurrentAnimated:(BOOL)animated;

@end
