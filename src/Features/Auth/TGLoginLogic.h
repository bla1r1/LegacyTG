//
// TGLoginLogic.h - the sign-in form's stacking rule, out of the view.
//
// One primary action per screen: the bottom Continue on a wide layout, the
// navigation bar's Next below 360 pt, where the keyboard leaves no room for a
// pinned button. The audit found the hidden button still taking its row, so
// "Forgot password?" sat one row lower, under the keyboard of a 3.5-inch
// screen.
//
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

/// Below this width the action is the bar's Next.
FOUNDATION_EXPORT const CGFloat TGLoginNarrowWidth;

FOUNDATION_EXPORT BOOL TGLoginUsesBarNext(CGFloat width);

/// The bottom button shows on a one-field step (phone, password, register,
/// email, email code, recovery) laid out wide. The code step sends itself.
FOUNDATION_EXPORT BOOL TGLoginShowsBottomButton(BOOL fieldStep, CGFloat width);

/// Where the stack continues after the button's row: `y` unchanged when the
/// button is not shown, else below the row and one stack step.
FOUNDATION_EXPORT CGFloat TGLoginYAfterActionRow(CGFloat y, CGFloat width);
