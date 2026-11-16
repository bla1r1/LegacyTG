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
/// The code step's sentence for an SMS word or phrase code, with the
/// official hint at its start when TDLib gives first_letter / first_word.
FOUNDATION_EXPORT NSString *TGLoginWordCodeSentence(NSDictionary *codeType, NSString *phone);

/// "in 5 minutes", "in 3 hours", "in 6 days" (unmuteIntervalString,
/// MuteExpires.*), for the email reset waits.
FOUNDATION_EXPORT NSString *TGLoginResetInterval(NSInteger seconds);

/// Under the email code field while a reset is pending
/// (emailAddressResetStatePending.reset_in): "Email will be reset in 4:59"
/// within a day, "... in 6 days" past it, "Please wait..." at zero.
FOUNDATION_EXPORT NSString *TGLoginEmailResetPendingText(NSInteger resetIn);

/// The Country list's sections, as official sorts them: by name, one section
/// per first letter ({"title": "G", "countries": [...]}). A query keeps the
/// countries whose name or calling code contains it, in one untitled section.
/// Entries are TGAccountStore's ("code", "name", "prefix", "flag").
FOUNDATION_EXPORT NSArray *TGCountrySections(NSArray *countries, NSString *query);
