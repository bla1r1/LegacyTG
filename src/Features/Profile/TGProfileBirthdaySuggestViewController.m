#import "TGProfileBirthdaySuggestViewController.h"
#import "TGProfileStore.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"

@implementation TGProfileBirthdaySuggestViewController {
	UIDatePicker *_picker;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Suggest Birthday";
	self.view.backgroundColor = [[TGTheme shared] groupedBackgroundColour];

	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
			initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain
				   target:self action:@selector(cancel)];
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
			initWithTitle:@"Suggest" style:UIBarButtonItemStyleDone
				   target:self action:@selector(suggest)];

	_picker = [[UIDatePicker alloc] initWithFrame:CGRectMake(0, TGMetricPadLarge,
			self.view.bounds.size.width, TGMetricPickerHeight)];
	_picker.datePickerMode = UIDatePickerModeDate;
	_picker.maximumDate = [NSDate date];
	_picker.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.view addSubview:_picker];
}

- (void)cancel {
	[self.navigationController popViewControllerAnimated:YES];
}

- (void)suggest {
	NSDateComponents *parts = [[NSCalendar currentCalendar] components:
			(NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit)
			fromDate:_picker.date];
	__weak typeof(self) weakSelf = self;
	[[TGProfileStore shared] suggestBirthdateDay:parts.day month:parts.month
									  year:parts.year forUser:self.userId
								completion:^(BOOL ok, NSString *error){
		TGProfileBirthdaySuggestViewController *me = weakSelf;
		if (!me)
			return;
		[TGAlertSheet showMessage:(ok ? @"Done" : (error ?: @"An error occurred."))
							title:@"Suggest Birthday" inView:me.view];
		if (ok)
			[me.navigationController popViewControllerAnimated:YES];
	}];
}

@end
