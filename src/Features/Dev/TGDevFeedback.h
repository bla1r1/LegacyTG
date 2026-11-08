//
// TGDevFeedback.h - circle what is wrong on the phone, for the developer.
//
// Dev builds only. Four quick taps anywhere (or one three-finger tap) freeze
// the screen into a picture; a finger circles the problem, a line of text
// says what it is, and Bad/Good marks it. Each note lands in
// Library/Caches/feedback/ as <stamp>.png (screen with the strokes) and
// <stamp>.json (comment, verdict, screen class and title, stroke boxes), and
// scripts/feedback.sh pulls them to the Mac.
//
#import <UIKit/UIKit.h>

#if TG_DEV
@interface TGDevFeedback : NSObject
/// Adds the two gestures to the window; call once after it is key.
+ (void)installInWindow:(UIWindow *)window;
@end
#endif
