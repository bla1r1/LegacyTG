//
// TGProfileViewController - user/chat profile, media overview, and actions.
//
#import <UIKit/UIKit.h>

@class TGProfileViewController;

@interface TGProfileDetailCell : UITableViewCell
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, assign) CGFloat iconWidth;
@property (nonatomic, copy) NSString *rowKind;
@property (nonatomic, assign) int64_t rowChatId;
@property (nonatomic, strong) UIButton *rightButton;
@property (nonatomic, copy) void (^onRightButtonTapped)(void);
@end
