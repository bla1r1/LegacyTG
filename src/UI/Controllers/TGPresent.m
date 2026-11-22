//
// TGPresent.m
//
#import "TGPresent.h"
#import <objc/runtime.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "TGBarItem.h"
#import "TGNavController.h"
#import "TGPopupMenu.h"
#import "TGControls.h"
#import "TGTheme.h"
#import "TGRowsViewController.h"
#import "TGStyle.h"

static char kTGPresentHelperKey;

static BOOL TGPresentNeedsPopover(void) {
	return TGSystemPickerNeedsPopover(
			UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad,
			[[[UIDevice currentDevice] systemVersion] integerValue]);
}

/// What a popover points at: the source view, or the middle of the screen.
static CGRect TGPresentSourceRect(UIView *sourceView, UIView *anchor) {
	if (sourceView)
		return sourceView.bounds;
	return CGRectMake(CGRectGetMidX(anchor.bounds), CGRectGetMidY(anchor.bounds),
			TGMetricHairline, TGMetricHairline);
}

/// Lives as long as the thing it answers for: the picker's delegate, the
/// pre-iOS 8 popover, the document controller. UIKit holds all three weakly.
@interface TGPresentHelper : NSObject <UIImagePickerControllerDelegate,
		UINavigationControllerDelegate, UIPopoverControllerDelegate,
		UIDocumentInteractionControllerDelegate>
@property (nonatomic, copy) void (^onPick)(NSDictionary *info);
@property (nonatomic, strong) UIPopoverController *popover;
@property (nonatomic, strong) UIDocumentInteractionController *document;
@property (nonatomic, weak) UIViewController *host;
@end

@implementation TGPresentHelper

- (void)close:(UIViewController *)picker then:(void (^)(void))after {
	if (self.popover){
		[self.popover dismissPopoverAnimated:YES];
		self.popover = nil;
		if (after)
			after();
	} else {
		[picker dismissViewControllerAnimated:YES completion:after];
	}
}

- (void)imagePickerController:(UIImagePickerController *)picker
		didFinishPickingMediaWithInfo:(NSDictionary *)info {
	void (^onPick)(NSDictionary *) = self.onPick;
	// The helper is the picker's associated object: keep it until the
	// block has run, the picker may be gone by then.
	TGPresentHelper *me = self;
	[self close:picker then:^{
		if (onPick)
			onPick(info);
		me.onPick = nil;
	}];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
	[self close:picker then:nil];
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popover {
	self.popover = nil;
}

- (UIViewController *)documentInteractionControllerViewControllerForPreview:
		(UIDocumentInteractionController *)controller {
	return self.host;
}

@end

@interface UIViewController (TGPresentClose)
- (void)tg_closeModal:(id)sender;
@end

@implementation UIViewController (TGPresentClose)
- (void)tg_closeModal:(id)sender {
	[TGPresent dismissModal:self];
}
@end

/// The drawn card, not the plain TGPopupMenu call: that one hands a bare
/// list to the system action sheet, and an action menu hangs from its source
/// the way official's context menu does.
static void TGPresentCard(NSArray *items, CGPoint at, UIView *host,
		void (^choice)(NSInteger, NSString *)) {
	[TGPopupMenu showItems:items atPoint:at inView:host headerView:nil reactions:nil
		  selectedReaction:nil onReaction:nil onDefaultReaction:nil onChoice:choice];
}

/// Official's context menu: the screen dims, the thing the finger is on
/// stays lit where it is, and the card hangs from it. The lit copy is a
/// picture of the source taken now, so the dim never covers it.
static void TGPresentCardFrom(NSArray *items, UIView *source, UIView *host,
		void (^choice)(NSInteger, NSString *)) {
	CGRect rect = CGRectIntegral([source convertRect:source.bounds toView:host]);
	// The dim goes round the source in four bands rather than over it, so the
	// real control stays lit with its own border, gloss and corners; a
	// picture of it (renderInContext) loses the corner clip on iOS 6.
	UIView *dim = [[UIView alloc] initWithFrame:host.bounds];
	dim.alpha = TGAlphaTransparent;
	UIColor *wash = [[TGTheme shared] holdDimColour];
	CGFloat w = host.bounds.size.width, h = host.bounds.size.height;
	CGRect bands[4] = {
		CGRectMake(0, 0, w, CGRectGetMinY(rect)),
		CGRectMake(0, CGRectGetMaxY(rect), w, h - CGRectGetMaxY(rect)),
		CGRectMake(0, CGRectGetMinY(rect), CGRectGetMinX(rect), rect.size.height),
		CGRectMake(CGRectGetMaxX(rect), CGRectGetMinY(rect), w - CGRectGetMaxX(rect),
				rect.size.height),
	};
	for (int b = 0; b < 4; b++){
		UIView *band = [[UIView alloc] initWithFrame:bands[b]];
		band.backgroundColor = wash;
		[dim addSubview:band];
	}
	[host addSubview:dim];

	TGMotionQuick(^{ dim.alpha = TGAlphaOpaque; }, nil);
	[TGPopupMenu showItems:items anchoredAt:rect inView:host headerView:nil reactions:nil
		  selectedReaction:nil onReaction:nil onDefaultReaction:nil onChoice:choice
				 onDismiss:^{
		TGMotionQuick(^{ dim.alpha = TGAlphaTransparent; },
				^(BOOL finished){ [dim removeFromSuperview]; });
	}];
}

@implementation TGPresent

+ (UIViewController *)topControllerFrom:(UIViewController *)host {
	UIViewController *top = host ?: [UIApplication sharedApplication].keyWindow.rootViewController;
	while (top.presentedViewController && !top.presentedViewController.isBeingDismissed)
		top = top.presentedViewController;
	return top;
}

+ (UINavigationController *)presentModal:(UIViewController *)root
									kind:(TGModalKind)kind
									from:(UIViewController *)host {
	[TGPopupMenu dismiss];   // a menu never outlives the screen it opened
	UIViewController *top = [self topControllerFrom:host];
	if (!root || !top)
		return nil;
	TGBarRole role;
	if (TGModalDismissRole(kind, &role) && !root.navigationItem.leftBarButtonItem)
		root.navigationItem.leftBarButtonItem = [TGBarItem itemWithRole:role
				target:root action:@selector(tg_closeModal:)];
	TGNavController *nav = [[TGNavController alloc] initWithRootViewController:root];
	// A bare modal is a canvas (story viewer, player) and dresses its own bar.
	if (kind != TGModalBare)
		[[TGTheme shared] styleNavigationBar:nav.navigationBar];
	[top presentViewController:nav animated:YES completion:nil];
	return nav;
}

+ (void)presentFlow:(UIViewController *)flow from:(UIViewController *)host {
	[TGPopupMenu dismiss];   // a menu never outlives the screen it opened
	UIViewController *top = [self topControllerFrom:host];
	if (flow && top)
		[top presentViewController:flow animated:YES completion:nil];
}

+ (void)openController:(UIViewController *)controller from:(UIViewController *)host {
	[TGPopupMenu dismiss];   // a menu never outlives the screen it opened
	if (!controller || !host)
		return;
	UINavigationController *stack = host.navigationController;
	if (stack)
		[stack pushViewController:controller animated:YES];
	else
		[self presentModal:controller kind:TGModalInfo from:host];
}

+ (void)dismissModal:(UIViewController *)controller {
	UIViewController *modal = controller.navigationController ?: controller;
	UIViewController *presenter = modal.presentingViewController;
	if (presenter)
		[presenter dismissViewControllerAnimated:YES completion:nil];
}

+ (void)showMenu:(NSArray *)items
	 fromBarItem:(UIBarButtonItem *)item
			side:(TGBarSide)side
	onController:(UIViewController *)controller
		onChoice:(void (^)(NSInteger, NSString *))choice {
	UIView *host = controller.navigationController.view ?: controller.view;
	UIView *view = item.customView;
	if (!view && [item respondsToSelector:@selector(view)]){
		id v = [item valueForKey:@"view"];
		view = [v isKindOfClass:UIView.class] ? v : nil;
	}
	if (view.window && host){
		TGPresentCardFrom(items, view, host, choice);
		return;
	}
	CGRect frame = [TGBarItem frameOfItem:item onController:controller
									side:side inView:host];
	TGPresentCard(items, TGMenuAnchorUnder(frame), host, choice);
}

+ (void)showMenu:(NSArray *)items
		fromView:(UIView *)source
	onController:(UIViewController *)controller
		onChoice:(void (^)(NSInteger, NSString *))choice {
	UIView *host = controller.navigationController.view ?: controller.view;
	if (source.window && host){
		TGPresentCardFrom(items, source, host, choice);
		return;
	}
	TGPresentCard(items, TGMenuAnchorUnder(host.bounds), host, choice);
}

+ (void)showMenuTitles:(NSArray *)titles
	  destructiveIndex:(NSInteger)destructiveIndex
			  fromView:(UIView *)source
		  onController:(UIViewController *)controller
			  onChoice:(void (^)(NSInteger))choice {
	NSArray *items = TGMenuItems(titles, destructiveIndex);
	void (^pick)(NSInteger, NSString *) = ^(NSInteger index, NSString *title){
		if (choice)
			choice(index);
	};
	if (source.window){
		[self showMenu:items fromView:source onController:controller onChoice:pick];
		return;
	}
	// No source named: a list's chosen row is where the finger was.
	if ([controller isKindOfClass:UITableViewController.class]){
		UITableView *table = ((UITableViewController *)controller).tableView;
		NSIndexPath *path = table.indexPathForSelectedRow;
		UITableViewCell *cell = path ? [table cellForRowAtIndexPath:path] : nil;
		if (cell.window){
			[self showMenu:items fromView:cell onController:controller onChoice:pick];
			return;
		}
	}
	UIView *host = controller.navigationController.view ?: controller.view;
	TGPresentCard(items, CGPointMake(CGRectGetMidX(host.bounds), CGRectGetMidY(host.bounds)),
			host, pick);
}

+ (void)showList:(NSArray *)lines
		   title:(NSString *)title
destructiveIndex:(NSInteger)destructiveIndex
			from:(UIViewController *)host
		  onPick:(void (^)(NSInteger))onPick {
	TGRowsViewController *list = [[TGRowsViewController alloc] init];
	list.title = title;
	NSArray *entries = TGListEntries(lines, destructiveIndex);
	if (onPick){
		NSMutableArray *tappable = [NSMutableArray arrayWithCapacity:entries.count];
		__weak TGRowsViewController *weakList = list;
		[entries enumerateObjectsUsingBlock:^(NSDictionary *entry, NSUInteger i, BOOL *stop){
			NSMutableDictionary *row = [entry mutableCopy];
			row[@"tap"] = [^{
				TGRowsViewController *me = weakList;
				if (me.navigationController.viewControllers.count > 1)
					[me.navigationController popViewControllerAnimated:YES];
				else
					[self dismissModal:me];
				onPick((NSInteger)i);
			} copy];
			[tappable addObject:row];
		}];
		entries = tappable;
	} else {
		list.offersCopy = YES;
	}
	list.listRows = entries;
	[self openController:list from:[self navigationHostFor:host]];
}

/// The controller with a stack under `host`: a canvas hands its top
/// controller, which may be a modal on its own.
+ (UIViewController *)navigationHostFor:(UIViewController *)host {
	UIViewController *top = [self topControllerFrom:host];
	if ([top isKindOfClass:UINavigationController.class])
		return ((UINavigationController *)top).topViewController;
	return top;
}

+ (void)showMenu:(NSArray *)items
		 atPoint:(CGPoint)point
		  inView:(UIView *)host
		onChoice:(void (^)(NSInteger, NSString *))choice {
	if (host)
		TGPresentCard(items, point, host, choice);
}

+ (void)presentSystem:(UIViewController *)controller
				 from:(UIViewController *)host
		   sourceView:(UIView *)sourceView {
	if (controller && host)
		[self presentSystem:controller from:host sourceView:sourceView
					 helper:[[TGPresentHelper alloc] init]];
}

+ (void)presentSystem:(UIViewController *)controller
				 from:(UIViewController *)host
		   sourceView:(UIView *)sourceView
			   helper:(TGPresentHelper *)helper {
	UIViewController *top = [self topControllerFrom:host];
	UIView *anchor = sourceView ?: top.view;
	CGRect rect = TGPresentSourceRect(sourceView, anchor);
	// Only the library and the share sheet raise outside a popover; people,
	// document and music pickers and the camera stay full screen.
	BOOL library = [controller isKindOfClass:UIImagePickerController.class] &&
			((UIImagePickerController *)controller).sourceType
					!= UIImagePickerControllerSourceTypeCamera;
	BOOL share = [controller isKindOfClass:UIActivityViewController.class];
	if ((library || share) && TGPresentNeedsPopover()){
		UIPopoverController *popover = [[UIPopoverController alloc]
				initWithContentViewController:controller];
		popover.delegate = helper;
		helper.popover = popover;
		objc_setAssociatedObject(controller, &kTGPresentHelperKey, helper,
				OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		[popover presentPopoverFromRect:rect inView:anchor
			   permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
		return;
	}
	if ([controller respondsToSelector:@selector(popoverPresentationController)]){
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
		// ios7-guarded: respondsToSelector above, nil on a phone.
		UIPopoverPresentationController *pop = controller.popoverPresentationController;
#pragma clang diagnostic pop
		pop.sourceView = anchor;
		pop.sourceRect = rect;
	}
	[top presentViewController:controller animated:YES completion:nil];
}

+ (void)dismissSystem:(UIViewController *)controller {
	[self dismissSystem:controller completion:nil];
}

+ (void)dismissSystem:(UIViewController *)controller completion:(void (^)(void))after {
	TGPresentHelper *helper = objc_getAssociatedObject(controller, &kTGPresentHelperKey);
	if (helper.popover){
		[helper.popover dismissPopoverAnimated:YES];
		helper.popover = nil;
		if (after)
			after();
		return;
	}
	[controller dismissViewControllerAnimated:YES completion:after];
}

+ (BOOL)pickMediaFrom:(UIViewController *)host
			   source:(TGMediaSource)source
			   videos:(BOOL)videos
		   sourceView:(UIView *)sourceView
			   onPick:(void (^)(NSDictionary *))onPick {
	UIImagePickerControllerSourceType type = source == TGMediaSourceCamera
			? UIImagePickerControllerSourceTypeCamera
			: UIImagePickerControllerSourceTypePhotoLibrary;
	if (!host || ![UIImagePickerController isSourceTypeAvailable:type])
		return NO;
	UIImagePickerController *picker = [[UIImagePickerController alloc] init];
	picker.sourceType = type;
	// Without the movie type the library shows photos only and the camera
	// takes stills only.
	picker.mediaTypes = videos ? @[(NSString *)kUTTypeImage, (NSString *)kUTTypeMovie]
			: @[(NSString *)kUTTypeImage];
	TGPresentHelper *helper = [[TGPresentHelper alloc] init];
	helper.onPick = onPick;
	picker.delegate = helper;
	objc_setAssociatedObject(picker, &kTGPresentHelperKey, helper,
			OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	// The camera is full screen on every iPad; only the library is a popover.
	if (source == TGMediaSourceCamera){
		[[self topControllerFrom:host] presentViewController:picker animated:YES completion:nil];
		return YES;
	}
	[self presentSystem:picker from:host sourceView:sourceView helper:helper];
	return YES;
}

+ (void)shareItems:(NSArray *)items
			  from:(UIViewController *)host
		sourceView:(UIView *)sourceView {
	if (!host || !items.count)
		return;
	UIActivityViewController *share = [[UIActivityViewController alloc]
			initWithActivityItems:items applicationActivities:nil];
	TGPresentHelper *helper = [[TGPresentHelper alloc] init];
	if (TGPresentNeedsPopover()){
		// iOS 6-7 leave a finished share sheet standing in its popover.
		__weak TGPresentHelper *weakHelper = helper;
		share.completionHandler = ^(NSString *activityType, BOOL completed){
			[weakHelper.popover dismissPopoverAnimated:YES];
			weakHelper.popover = nil;
		};
	}
	[self presentSystem:share from:host sourceView:sourceView helper:helper];
}

+ (BOOL)openDocument:(NSURL *)url
				from:(UIViewController *)host
		  sourceView:(UIView *)sourceView {
	if (!url || !host)
		return NO;
	TGPresentHelper *helper = [[TGPresentHelper alloc] init];
	helper.host = [self topControllerFrom:host];
	helper.document = [UIDocumentInteractionController interactionControllerWithURL:url];
	helper.document.delegate = helper;
	// One open document per screen: the next replaces it.
	objc_setAssociatedObject(host, &kTGPresentHelperKey, helper,
			OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	if ([helper.document presentPreviewAnimated:YES])
		return YES;
	UIView *anchor = sourceView ?: helper.host.view;
	CGRect rect = TGPresentSourceRect(sourceView, anchor);
	return [helper.document presentOpenInMenuFromRect:rect inView:anchor animated:YES];
}

@end
