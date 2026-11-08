//
// TGTermsViewController.m - the terms popup updateTermsOfService asks for.
//
// The text can run to pages, so it is a scroll view and not an alert: an
// alert would cut it at a few lines and the acceptance would be for a
// document nobody could read. Decline and Accept sit on the bottom bar, as
// official draws them.
#import "TGTermsViewController.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGButton.h"

@interface TGTermsViewController ()
@property (nonatomic, strong) UITextView *body;
@property (nonatomic, strong) UIView *bar;
@property (nonatomic, strong) TGButton *declineButton;
@property (nonatomic, strong) TGButton *acceptButton;
@end

@implementation TGTermsViewController

- (void)viewDidLoad {
	[super viewDidLoad];

	self.title = @"Terms of Service";

	CGFloat width = self.view.bounds.size.width;
	CGFloat height = self.view.bounds.size.height;
	CGFloat barHeight = TGMetricRow + TGMetricPadMedium;

	self.bar = [[UIView alloc] initWithFrame:
			CGRectMake(0, height - barHeight, width, barHeight)];
	self.bar.autoresizingMask = UIViewAutoresizingFlexibleWidth |
								UIViewAutoresizingFlexibleTopMargin;
	[self.view addSubview:self.bar];

	// The body keeps its own scroll, because the text can run to pages and
	// the acceptance is only meaningful if it can be read.
	UITextView *body = [[UITextView alloc] initWithFrame:
			CGRectMake(0, 0, width, height - barHeight)];
	body.autoresizingMask = UIViewAutoresizingFlexibleWidth |
							UIViewAutoresizingFlexibleHeight;
	body.editable = NO;
	body.font = TGFontBody();
	body.text = self.termsText ?: @"";
	body.textContainerInset = UIEdgeInsetsMake(TGMetricPad, TGMetricPad,
											   TGMetricPad, TGMetricPad);
	self.body = body;
	[self.view addSubview:body];

	CGFloat buttonWidth = TGHalf(width - TGDoubled(TGMetricGutter) - TGMetricPadSmall);
	self.declineButton = [TGButton buttonWithTitle:@"Decline"
										  variant:TGButtonVariantSecondary
											 size:TGButtonSizeLarge];
	self.declineButton.frame = CGRectMake(TGMetricGutter, TGMetricPadSmall,
										  buttonWidth, TGMetricRow);
	[self.declineButton addTarget:self action:@selector(declineTapped)
				 forControlEvents:UIControlEventTouchUpInside];
	[self.bar addSubview:self.declineButton];

	self.acceptButton = [TGButton buttonWithTitle:@"Accept"
										 variant:TGButtonVariantPrimary
											size:TGButtonSizeLarge];
	self.acceptButton.frame = CGRectMake(TGMetricGutter + buttonWidth + TGMetricPadSmall,
										 TGMetricPadSmall, buttonWidth, TGMetricRow);
	[self.acceptButton addTarget:self action:@selector(acceptTapped)
				forControlEvents:UIControlEventTouchUpInside];
	[self.bar addSubview:self.acceptButton];

	[self applyTheme];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyTheme) name:TGThemeChangedNotification object:nil];
}

- (void)applyTheme {
	TGTheme *theme = [TGTheme shared];
	self.view.backgroundColor = [theme listBackgroundColour];
	self.bar.backgroundColor = [theme barColour];
	self.body.backgroundColor = [theme listBackgroundColour];
	self.body.textColor = [theme primaryTextColour];
	[theme styleNavigationBar:self.navigationController.navigationBar];
}

- (void)acceptTapped {
	if (self.onAccept)
		self.onAccept();
	[self dismissSelf];
}

- (void)declineTapped {
	if (self.onDecline)
		self.onDecline();
	[self dismissSelf];
}

- (void)dismissSelf {
	if (self.navigationController.presentingViewController)
		[self.navigationController dismissViewControllerAnimated:YES completion:nil];
	else
		[self.navigationController popViewControllerAnimated:YES];
}

@end

// vim:ft=objc
