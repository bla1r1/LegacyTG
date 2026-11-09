//
// TGProfileHeaderView.h - the profile page header: picture, name, status and
// the row of action tiles, with the saved-music strip underneath.
//
// A profile screen hands it a model and three blocks; it never builds a label
// or a tile itself. The same header is what My Profile and a peer's profile
// show, so the two cannot drift.
//
#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

extern NSString *const TGProfileHeaderName;
extern NSString *const TGProfileHeaderAvatar;      // UIImage
extern NSString *const TGProfileHeaderInitials;    // NSString fallback picture
extern NSString *const TGProfileHeaderColourId;    // NSNumber avatar colour id
extern NSString *const TGProfileHeaderEmojiStatusId; // NSNumber
extern NSString *const TGProfileHeaderVerified;    // NSNumber BOOL
extern NSString *const TGProfileHeaderStatus;      // NSString
extern NSString *const TGProfileHeaderStatusColour; // UIColor
extern NSString *const TGProfileHeaderActions;     // NSArray of tile dicts
extern NSString *const TGProfileHeaderActionTitle; // NSString
extern NSString *const TGProfileHeaderActionGlyph; // NSString menu glyph
extern NSString *const TGProfileHeaderActionKey;   // NSString routing key
extern NSString *const TGProfileHeaderMusic;       // NSDictionary or nil
extern NSString *const TGProfileHeaderMusicTitle;
extern NSString *const TGProfileHeaderMusicPerformer;

#ifdef __cplusplus
}
#endif

@interface TGProfileHeaderView : UIView

@property (nonatomic, copy) void (^avatarTap)(void);
@property (nonatomic, copy) void (^actionTap)(NSString *key);
@property (nonatomic, copy) void (^musicTap)(void);

/// The status line is updated in place on presence changes, without a rebuild.
@property (nonatomic, copy) NSString *statusText;
@property (nonatomic, strong) UIColor *statusColour;
@property (nonatomic, strong) UIImage *avatarImage;

/// The header height for a width and model. Pure, so a screen can size the
/// table header before the view exists.
+ (CGFloat)heightForWidth:(CGFloat)width model:(NSDictionary *)model;

- (void)configureWithModel:(NSDictionary *)model;

@end

// vim:ft=objc
