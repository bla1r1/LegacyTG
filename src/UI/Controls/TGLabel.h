//
// TGLabel.h - text on a screen by what it is, not by font and colour.
//
// Screens in src/Features never build a UILabel: they ask for a role and get
// the font from TGStyle and the colour from TGTheme every other screen with
// the same kind of text gets. Alignment, lines and frame stay the screen's:
// that is layout, not look.
//
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, TGLabelRole) {
	TGLabelTitle = 0,      ///< a screen's big line (passcode, storage total)
	TGLabelHeader,         ///< a heading inside content (version, size sample)
	TGLabelRow,            ///< text at row size
	TGLabelRowStrong,      ///< a name at row size
	TGLabelBody,           ///< running text
	TGLabelBodySecondary,  ///< a sentence about the content (empty hints)
	TGLabelSubhead,        ///< a secondary line under a heading
	TGLabelCaption,        ///< small grey text: footers, counts, notes
	TGLabelCaptionStrong,  ///< a small badge label
	TGLabelMeta,           ///< the smallest grey text in content
	TGLabelMicro,          ///< a scale mark
	TGLabelBarTitle,       ///< a title drawn into the navigation bar
	TGLabelBarSubtitle,    ///< the line under it
};

/// A clear-backed label for `role`, frame zero. Bar roles carry the bar's
/// text shadow.
FOUNDATION_EXPORT UILabel *TGLabelMake(TGLabelRole role);

/// The same with its frame and text set.
FOUNDATION_EXPORT UILabel *TGLabelWith(TGLabelRole role, CGRect frame, NSString *text);

/// The iOS 6 etched look (a light shadow under the letters) that text on the
/// page background takes outside a card.
FOUNDATION_EXPORT void TGLabelEtch(UILabel *label);

// vim:ft=objc
