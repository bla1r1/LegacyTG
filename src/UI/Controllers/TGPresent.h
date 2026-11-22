//
// TGPresent.h - how a screen opens something, by what it is.
//
// Screens in src/Features never call presentViewController: or build a
// navigation controller. Each kind of thing official opens one way has one
// call here:
//
//   a form to fill in, or a page to read    +presentModal:kind:from:
//   a screen, pushed if there is a stack    +openController:from:
//   a flow with its own container           +presentFlow:from:
//   the actions of a button or a long press +showMenu:fromBarItem:... / fromView:
//   a photo or video from the library       +pickMediaFrom:...
//   sharing a file or link                  +shareItems:from:sourceView:
//   a file another app can open             +openDocument:from:sourceView:
//   any other system picker (contacts,       +presentSystem:from:sourceView:
//     documents, music, camera flows)
//
// The rest already has its one place:
//
//   confirming a delete                     TGAlertSheet showConfirm:... destructive:YES
//   picking one of several values           TGAlertSheet showChoices:
//   something to read and dismiss           TGAlertSheet showMessage:
//   attachments and other bottom sheets     a TGSheet subclass
//
#import <UIKit/UIKit.h>
#import "TGPresentRules.h"

typedef NS_ENUM(NSInteger, TGMediaSource) {
	TGMediaSourceLibrary = 0,
	TGMediaSourceCamera,
};

@interface TGPresent : NSObject

/// The controller on top of everything `host` is under, which is the only
/// one that can present.
+ (UIViewController *)topControllerFrom:(UIViewController *)host;

/// Wraps `root` in the app's navigation controller and presents it over
/// the top controller. A form gets Cancel on the left and puts its own Done;
/// an info page gets Close; a bare one gets nothing and an unstyled bar, for
/// a canvas to dress. A left button `root` already has is kept. Returns the
/// navigation controller, nil without a host.
+ (UINavigationController *)presentModal:(UIViewController *)root
									kind:(TGModalKind)kind
									from:(UIViewController *)host;

/// A flow that brings its own container (a camera flow, a tab controller),
/// presented as it is over the top controller above `host`.
+ (void)presentFlow:(UIViewController *)flow from:(UIViewController *)host;

/// Pushes `controller` when `host` is on a stack, otherwise presents it as
/// an info page. Never a silent no-op.
+ (void)openController:(UIViewController *)controller from:(UIViewController *)host;

/// Closes the modal `controller` is in, whatever its depth in that modal.
+ (void)dismissModal:(UIViewController *)controller;

/// The action menu of a bar button: TGPopupMenu hanging under it, the way
/// official's ⋯ opens a context menu. `items` are TGPopupMenu items.
+ (void)showMenu:(NSArray *)items
	 fromBarItem:(UIBarButtonItem *)item
			side:(TGBarSide)side
	onController:(UIViewController *)controller
		onChoice:(void (^)(NSInteger index, NSString *title))choice;

/// The action menu of a row, tile or long-pressed view, hanging under it.
+ (void)showMenu:(NSArray *)items
		fromView:(UIView *)source
	onController:(UIViewController *)controller
		onChoice:(void (^)(NSInteger index, NSString *title))choice;

/// The same from plain titles (TGMenuItems: glyph by word, one red). A nil
/// `source` hangs the card in the middle of the screen.
+ (void)showMenuTitles:(NSArray *)titles
	  destructiveIndex:(NSInteger)destructiveIndex
			  fromView:(UIView *)source
		  onController:(UIViewController *)controller
			  onChoice:(void (^)(NSInteger index))choice;

/// The same card at a point the screen worked out itself (a row's own spot,
/// a canvas's button), in `host`'s coordinates.
+ (void)showMenu:(NSArray *)items
		 atPoint:(CGPoint)point
		  inView:(UIView *)host
		onChoice:(void (^)(NSInteger index, NSString *title))choice;

/// A list of things (voters, reactions, members, links) as a pushed screen
/// of rows, the way official shows a peer or item list, instead of a sheet
/// that cuts names short. `onPick` nil makes the rows read-only with a Copy
/// button; otherwise a tap pops the list and passes the index.
+ (void)showList:(NSArray *)lines
		   title:(NSString *)title
destructiveIndex:(NSInteger)destructiveIndex
			from:(UIViewController *)host
		  onPick:(void (^)(NSInteger index))onPick;

/// The system photo library or camera. `videos` lets a movie be picked or
/// shot as well as a still. `onPick` gets the picker's info dictionary after
/// the picker has gone, so it may present the next thing; a cancel runs
/// nothing. Returns NO when the source is not on this device.
+ (BOOL)pickMediaFrom:(UIViewController *)host
			   source:(TGMediaSource)source
			   videos:(BOOL)videos
		   sourceView:(UIView *)sourceView
			   onPick:(void (^)(NSDictionary *info))onPick;

/// The system share sheet for URLs, text or images. `sourceView` is what an
/// iPad's popover points at; nil means the host's view.
+ (void)shareItems:(NSArray *)items
			  from:(UIViewController *)host
		sourceView:(UIView *)sourceView;

/// A controller the system draws (a people, document or music picker, or an
/// image picker whose delegate is the screen), presented the one way this
/// device allows: a popover on an iPad before iOS 8, otherwise modally from
/// the top controller with its popover pointed at `sourceView`.
+ (void)presentSystem:(UIViewController *)controller
				 from:(UIViewController *)host
		   sourceView:(UIView *)sourceView;

/// Closes what +presentSystem: opened, popover or not. A delegate that used
/// to say [picker dismissViewControllerAnimated:] says this instead.
+ (void)dismissSystem:(UIViewController *)controller;

/// The same, then `after` once it has gone (at once for a popover).
+ (void)dismissSystem:(UIViewController *)controller completion:(void (^)(void))after;

/// A local file: Quick Look when it can preview it, otherwise the Open In
/// menu from `sourceView`. Returns NO when neither is possible.
+ (BOOL)openDocument:(NSURL *)url
				from:(UIViewController *)host
		  sourceView:(UIView *)sourceView;

@end

// vim:ft=objc
