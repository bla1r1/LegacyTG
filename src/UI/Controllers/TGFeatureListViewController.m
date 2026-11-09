//
// TGFeatureListViewController.m
//
#import "TGFeatureListViewController.h"
#import "TGRows.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGLocalization.h"
#import "TGSnackbar.h"

NSMutableDictionary *TGFeatureRow(NSString *title, NSString *detail, void (^tap)(void)) {
	return [TGTapRow(title, detail, tap) mutableCopy];
}

NSMutableDictionary *TGFeatureOpenRow(NSString *title, NSString *detail, void (^tap)(void)) {
	return [TGOpenRow(title, detail, tap) mutableCopy];
}

NSMutableDictionary *TGFeatureAction(NSString *title, void (^tap)(void)) {
	return [TGActionRow(title, tap) mutableCopy];
}

NSMutableDictionary *TGFeatureCheck(NSString *title, NSString *detail, BOOL checked,
								  void (^tap)(void)) {
	return [TGCheckRow(title, detail, checked, tap) mutableCopy];
}

NSDictionary *TGFeatureSection(NSString *header, NSString *footer, NSArray *rows) {
	return TGSection(header, footer, rows);
}

@implementation TGFeatureListViewController
@end

#pragma mark - result screen

@interface TGFeatureResultViewController ()
@property (nonatomic, strong) UITextView *textView;
@end

@implementation TGFeatureResultViewController

- (instancetype)initWithTitle:(NSString *)title body:(NSString *)body {
	self = [super initWithNibName:nil bundle:nil];
	if (!self)
		return nil;
	self.title = title;
	_body = [body copy];
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	self.view.backgroundColor = [[TGTheme shared] groupedBackgroundColour];

	self.textView = [[UITextView alloc] initWithFrame:UIEdgeInsetsInsetRect(
			self.view.bounds, UIEdgeInsetsMake(TGMetricPadLarge, TGMetricPadLarge,
											   TGMetricPadLarge, TGMetricPadLarge))];
	self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
									 UIViewAutoresizingFlexibleHeight;
	self.textView.editable = NO;
	self.textView.font = TGFontBody();
	self.textView.textColor = [[TGTheme shared] primaryTextColour];
	self.textView.backgroundColor = [[TGTheme shared] cardBackgroundColour];
	self.textView.text = self.body ?: @"";
	[self.view addSubview:self.textView];

	UIBarButtonItem *copy = [[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Copy")
			style:UIBarButtonItemStyleBordered
		   target:self action:@selector(copyText)];
	self.navigationItem.rightBarButtonItem = copy;
	if (self.onSend){
		UIBarButtonItem *send = [[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Send")
				style:UIBarButtonItemStyleDone
			   target:self action:@selector(sendText)];
		self.navigationItem.rightBarButtonItems = @[send, copy];
	}
}

- (void)copyText {
	[UIPasteboard generalPasteboard].string = self.textView.text ?: @"";
	UIView *host = self.navigationController.view ?: self.view;
	[TGSnackbar showInView:host text:TGLocalized(@"Copied to clipboard.")
				  seconds:2 onCommit:nil];
}

- (void)sendText {
	if (self.onSend)
		self.onSend(self.textView.text ?: @"");
	[self.navigationController popViewControllerAnimated:YES];
}

@end
