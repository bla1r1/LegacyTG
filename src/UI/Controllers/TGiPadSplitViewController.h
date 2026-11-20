//
// TGiPadSplitViewController.h
// LegacyTG - Master-Detail split controller for iPad layout
//
#import <UIKit/UIKit.h>

@interface TGiPadSplitViewController : UIViewController

+ (instancetype)shared;

@property (nonatomic, strong) UIViewController *masterViewController;
@property (nonatomic, strong) UINavigationController *detailNavigationController;
@property (nonatomic, readonly) int64_t activeChatId;

- (void)showChatWithId:(int64_t)chatId
                 title:(NSString *)title
               isGroup:(BOOL)isGroup
               isForum:(BOOL)isForum;

- (void)clearDetailToPlaceholder;

@end
