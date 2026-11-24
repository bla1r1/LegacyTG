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
extern NSString *const TGProfileHeaderPremium;     // NSNumber BOOL
extern NSString *const TGProfileHeaderBotVerification; // UIImage, a verifier bot's mark before the name
extern NSString *const TGProfileHeaderCoverColour; // UIColor profile cover tint
extern NSString *const TGProfileHeaderStatus;      // NSString
extern NSString *const TGProfileHeaderStatusColour; // UIColor
extern NSString *const TGProfileHeaderActions;     // NSArray of tile dicts
extern NSString *const TGProfileHeaderActionTitle; // NSString
extern NSString *const TGProfileHeaderActionGlyph; // NSString menu glyph
extern NSString *const TGProfileHeaderActionKey;   // NSString routing key
extern NSString *const TGProfileHeaderMusic;       // NSDictionary or nil
extern NSString *const TGProfileHeaderMusicTitle;
extern NSString *const TGProfileHeaderMusicPerformer;
extern NSString *const TGProfileHeaderLevel;       // NSNumber star rating level, or absent

#ifdef __cplusplus
}
#endif

@interface TGProfileHeaderView : UIView

@property (nonatomic, copy) void (^avatarTap)(void);
@property (nonatomic, copy) void (^actionTap)(NSString *key);
/// The tile the last actionTap came from, for a menu to hang from it.
@property (nonatomic, weak, readonly) UIView *lastTappedTile;
@property (nonatomic, copy) void (^musicTap)(void);
/// The star rating's level badge after the status line.
@property (nonatomic, copy) void (^levelTap)(void);

/// The status line is updated in place on presence changes, without a rebuild.
@property (nonatomic, copy) NSString *statusText;
@property (nonatomic, strong) UIColor *statusColour;
@property (nonatomic, strong) UIImage *avatarImage;

/// The header height for a width and model. Pure, so a screen can size the
/// table header before the view exists.
+ (CGFloat)heightForWidth:(CGFloat)width model:(NSDictionary *)model;

- (void)configureWithModel:(NSDictionary *)model;

/// Plays a profile picture's clip over the still, silent and looped, from
/// `seconds` (the frame the picture rests on).
- (void)playAvatarVideoAtPath:(NSString *)path from:(double)seconds;

/// Plays a sticker photo: its fill's colours (0xRRGGBB, top to bottom) in the
/// circle, the sticker looping at two thirds of the picture over it.
- (void)playAvatarSticker:(NSString *)path colours:(NSArray *)colours;

@end

// vim:ft=objc
