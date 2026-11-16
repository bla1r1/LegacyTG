//
// TGKeyboardDismissal - close the keyboard by dragging the content or tapping
// empty space, on every screen that scrolls.
//
// iOS 7 has keyboardDismissMode; iOS 6 has nothing, and a phone or number pad
// has no return key, so a field there kept its keyboard until the screen went
// away. TGTableViewController installs this on every table; a screen built on
// its own scroll view (login) calls it once.
//
#import <UIKit/UIKit.h>

/// Interactive drag-to-dismiss on iOS 7+, plain drop on drag on iOS 6, and a
/// tap outside fields, text views, search bars and buttons ends editing.
/// Neither cancels a touch: rows, buttons and fields work as before.
void TGInstallKeyboardDismissal(UIScrollView *scrollView);
