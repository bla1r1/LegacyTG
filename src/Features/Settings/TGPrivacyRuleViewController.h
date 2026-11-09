//
// TGPrivacyRuleViewController.h - detail screen for a privacy rule with exception lists.
//
#ifndef TGPRIVACYRULEVIEWCONTROLLER_H
#define TGPRIVACYRULEVIEWCONTROLLER_H

#import <Foundation/Foundation.h>
#import "TGLocalization.h"

static inline NSArray *TGPrivacyRuleOptionKeys(void) {
	return @[@"everybody", @"contacts", @"nobody"];
}

static inline NSArray *TGPrivacyRuleOptionTitles(void) {
	return @[TGLocalized(@"Everybody"), TGLocalized(@"My Contacts"),
			TGLocalized(@"Nobody")];
}

/// The count on Always Allow / Never Allow. "Never" is the official word for
/// an empty exception list, not a zero.
static inline NSString *TGPrivacyExceptionDetail(NSUInteger count) {
	if (!count)
		return TGLocalized(@"Never");
	return TGLocalizedPlural(@"%d user", @"%d users", (NSInteger)count);
}

/// Every row title on the page: the three rule choices, then the two lists.
static inline NSArray *TGPrivacyRuleRowTitles(NSString *ruleType,
		NSUInteger allowCount, NSUInteger restrictCount) {
	(void)ruleType;
	(void)allowCount;
	(void)restrictCount;
	NSMutableArray *titles = [NSMutableArray array];
	[titles addObjectsFromArray:TGPrivacyRuleOptionTitles()];
	[titles addObject:TGLocalized(@"Always Allow")];
	[titles addObject:TGLocalized(@"Never Allow")];
	return titles;
}

#ifndef TGROW_MODELS_ONLY
#import <UIKit/UIKit.h>
#import "TGRowsViewController.h"

@interface TGPrivacyRuleViewController : TGRowsViewController

- (instancetype)initWithSetting:(NSString *)setting title:(NSString *)title;

@property (nonatomic, copy) void (^onChanged)(NSString *setting, NSString *ruleType);

@end
#endif

#endif // TGPRIVACYRULEVIEWCONTROLLER_H
