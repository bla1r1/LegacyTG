//
// TGControls.h - the small buttons and the motion screens share.
//
// Screens in src/Features do not build a UIButton or run their own
// animation: they ask for the kind of button they need, and move things with
// one of the app's two speeds, so a bar sliding in on one screen moves the
// way it does on the next.
//
#import <UIKit/UIKit.h>

/// An image with no plate: a close cross, a lock beside a title, a face.
/// `image` may be nil for a button filled in later.
FOUNDATION_EXPORT UIButton *TGGlyphButton(UIImage *image, CGRect frame, id target, SEL action);

/// Words with no plate, in `font`, the bar-button colour unless set later.
FOUNDATION_EXPORT UIButton *TGTextButton(NSString *title, UIFont *font, id target, SEL action);

/// A round glossy button with a white glyph (the selection bar's Delete and
/// Forward). `fill` is a theme colour.
FOUNDATION_EXPORT UIButton *TGRoundGlyphButton(NSString *glyph, UIColor *fill,
		CGFloat side, CGFloat glyphSide, NSString *label, id target, SEL action);

/// A rectangle of accent with white words (a sheet's Send).
FOUNDATION_EXPORT UIButton *TGAccentButton(NSString *title, UIFont *font, id target, SEL action);

/// A highlight-only surface: nothing at rest, the accent plate under a
/// finger (a menu's header row).
FOUNDATION_EXPORT UIButton *TGPlateButton(CGFloat height, id target, SEL action);

/// A capsule for a strip of filters (chat folders): accent when chosen, a
/// card with a hairline when not. TGPillPaint repaints it on a switch.
FOUNDATION_EXPORT UIButton *TGPillButton(NSString *title, UIFont *font, CGRect frame,
		BOOL active, id target, SEL action);
FOUNDATION_EXPORT void TGPillPaint(UIButton *pill, BOOL active);

/// Text to read, not to change: selectable where the system allows (iOS 7),
/// body font, its own scroll (terms, an instant page, an AI result).
FOUNDATION_EXPORT UITextView *TGReaderTextView(CGRect frame);

/// Text to write in a form: editable, body font (a self-destructing note).
FOUNDATION_EXPORT UITextView *TGEditorTextView(CGRect frame);

/// An invisible field that only brings up a keyboard and reports keys (the
/// passcode dots draw what was typed).
FOUNDATION_EXPORT UITextField *TGKeyCatcher(UIKeyboardType keyboard, id target, SEL changed);

/// An on/off switch outside a row (a row's switch comes with TGRows).
FOUNDATION_EXPORT UISwitch *TGSwitchMake(BOOL on, id target, SEL changed);

/// A slider over whole steps 0...steps-1, the accent on its filled side.
FOUNDATION_EXPORT UISlider *TGStepSlider(CGRect frame, NSInteger steps, NSInteger step,
		id target, SEL changed);

/// The grey spinner content shows while it waits; it hides when stopped.
FOUNDATION_EXPORT UIActivityIndicatorView *TGSpinnerMake(void);

/// The composer's strip, gloss and top line, for a panel that takes the
/// composer's place (the selection bar), sized to `frame` and stretching
/// with it.
FOUNDATION_EXPORT UIView *TGComposerStripView(CGRect frame);

/// The quick move: a bar sliding over the tab bar, a checkbox or a row
/// fading in, a lifted message settling (TGAnimationDurationFast).
FOUNDATION_EXPORT void TGMotionQuick(void (^changes)(void), void (^done)(BOOL finished));

/// The same, easing out: something lifted under the finger.
FOUNDATION_EXPORT void TGMotionLift(void (^changes)(void), void (^done)(BOOL finished));

/// The sheet's move: a backdrop dimming in, a bar replacing the composer
/// (TGAnimationDurationNormal).
FOUNDATION_EXPORT void TGMotionSheet(void (^changes)(void), void (^done)(BOOL finished));

// vim:ft=objc
