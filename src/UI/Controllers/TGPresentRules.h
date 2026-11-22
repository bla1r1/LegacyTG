//
// TGPresentRules.h - the rules behind src/UI's bar buttons and presenters:
// what a bar button means (its words, weight, side, glyph), how a modal is
// closed, where a menu hangs, when a system picker needs a popover.
//
// A screen asks for a role, never for a title and a style, so Cancel cannot
// be bold on one form and plain on the next. TGBarItem and TGPresent do the
// UIKit part; this file has none, so the host suite checks it. The words
// are official Telegram's Common.* strings.
//
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

typedef NS_ENUM(NSInteger, TGBarRole) {
	/// Leaves a pushed screen. TGNavController puts it under every push; a
	/// screen asks for it only where it replaces the system one.
	TGBarRoleBack = 0,
	/// Leaves a form without saving. Left side, plain.
	TGBarRoleCancel,
	/// Saves a form, or ends editing. Right side, bold.
	TGBarRoleDone,
	/// Starts editing a list. Right side, plain; Done takes its place.
	TGBarRoleEdit,
	/// Leaves a sheet that has nothing to save. Left side, plain.
	TGBarRoleClose,
	/// Opens the screen's action menu (TGPopupMenu under the button).
	TGBarRoleMore,
	/// Adds an item to the list on screen.
	TGBarRoleAdd,
	/// Hands what is on screen to the system share sheet.
	TGBarRoleShare,
	/// Searches what is on screen: UIKit's magnifier (official .icon(.search)).
	TGBarRoleSearch,
	/// Starts something new: UIKit's compose (the chat list's new message).
	TGBarRoleCompose,
	/// Posts a story: the official ring with a plus, bare in the bar
	/// (chat list, My Profile).
	TGBarRoleAddStory,
};
#define TGBarRoleCount 11

typedef NS_ENUM(NSInteger, TGBarSide) {
	TGBarSideLeft = 0,
	TGBarSideRight,
};

/// The official English for a text role (Cancel, Done, ...), nil for a glyph
/// or system role. Goes through TGLocalized at the point it is drawn.
FOUNDATION_EXPORT NSString *TGBarRoleTitle(TGBarRole role);

/// The TGIcons glyph a role draws instead of words, nil for a text or
/// system role.
FOUNDATION_EXPORT NSString *TGBarRoleGlyph(TGBarRole role);

/// What VoiceOver reads for a glyph role, and the title for a text one.
FOUNDATION_EXPORT NSString *TGBarRoleLabel(TGBarRole role);

/// Drawn by the system rather than by us: Add, Search and Compose are
/// UIKit's own +, magnifier and pencil.
FOUNDATION_EXPORT BOOL TGBarRoleIsSystemItem(TGBarRole role);

/// Drawn without the bar's button border: the glyph alone at the bar
/// button's height (Add Story's ring would sit inside a box otherwise).
FOUNDATION_EXPORT BOOL TGBarRoleIsBare(TGBarRole role);

/// Bold (UIBarButtonItemStyleDone): the one button that commits.
FOUNDATION_EXPORT BOOL TGBarRoleIsPrimary(TGBarRole role);

/// Where official puts it: leaving on the left, everything else right.
FOUNDATION_EXPORT TGBarSide TGBarRoleSide(TGBarRole role);

FOUNDATION_EXPORT NSString *TGBarRoleName(TGBarRole role);

/// How a controller opened modally is closed.
typedef NS_ENUM(NSInteger, TGModalKind) {
	/// Something to fill in: Cancel on the left; the form puts its own Done
	/// (TGBarRoleDone) on the right, since only it knows when Done is ready.
	TGModalForm = 0,
	/// Something to read: Close on the left, nothing to save.
	TGModalInfo,
	/// The controller draws its own way out (a picker, a canvas).
	TGModalBare,
};

/// The role of the button that dismisses a modal of `kind`. NO for a bare
/// modal, which gets none.
FOUNDATION_EXPORT BOOL TGModalDismissRole(TGModalKind kind, TGBarRole *role);

/// Where a menu opened from `source` (in the host's coordinates) points: the
/// middle of its bottom edge, so the card hangs under the button or row the
/// finger is on, the way official's context menu hangs from its source.
FOUNDATION_EXPORT CGPoint TGMenuAnchorUnder(CGRect source);

/// A bar button's frame when UIKit does not expose its view: a square of
/// the bar's height at the edge of `side`, inset by the bar's side margin.
FOUNDATION_EXPORT CGRect TGBarItemFallbackRect(CGRect bar, TGBarSide side);

/// The menu glyph a row of an action menu takes from its words, nil when
/// none fits: Delete and Remove a bin, Edit and Rename a pencil, Copy...,
/// Pin, Unpin, Mute, Unmute, Archive, Reply, Forward and Share theirs.
FOUNDATION_EXPORT NSString *TGMenuGlyphForTitle(NSString *title);

/// TGPopupMenu items for plain titles: each with its glyph, the one at
/// `destructiveIndex` red (-1 for none).
FOUNDATION_EXPORT NSArray *TGMenuItems(NSArray *titles, NSInteger destructiveIndex);

/// List-screen entries (TGRowsViewController listRows) from the lines a
/// sheet used to show: "Name · detail" splits at its first " · " into a
/// title and a grey detail, the line at `destructiveIndex` is red.
FOUNDATION_EXPORT NSArray *TGListEntries(NSArray *lines, NSInteger destructiveIndex);

/// A system picker or share sheet on an iPad before iOS 8 must come up in a
/// UIPopoverController: presenting it full screen raises. iOS 8 gave every
/// controller a popover presentation, and the phone never needs one.
FOUNDATION_EXPORT BOOL TGSystemPickerNeedsPopover(BOOL pad, NSInteger systemMajor);

// vim:ft=objc
