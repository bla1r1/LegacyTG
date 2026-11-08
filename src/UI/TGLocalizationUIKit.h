//
// TGLocalizationUIKit.h - translate the UIKit chrome that is already on screen.
//
// New text is translated as UIKit receives it (the swizzles in the .m), but a
// screen built before the language pack finished loading would keep English
// labels. One walk of the window tree after the pack arrives fixes those.
#import <UIKit/UIKit.h>

/// Re-applies the current language to every visible label, button, text field,
/// search bar, segmented control, navigation item and tab item.
void TGLocalizeInterface(void);

/// The same for one view and its subviews.
void TGLocalizeViewTree(UIView *view);
