//
// TGAdminRightsViewController.h - the administrator rights Telegram applies
// when this account's bot is added to a group or a channel.
//
#ifndef TGADMINRIGHTSVIEWCONTROLLER_H
#define TGADMINRIGHTSVIEWCONTROLLER_H

#import <Foundation/Foundation.h>

/// The preset name the row shows on its right.
static inline NSString *TGAdminPresetLabel(NSString *preset) {
	if ([preset isEqualToString:@"readonly"]) return @"Read-Only Mode";
	if ([preset isEqualToString:@"posting"])  return @"Posting Members";
	if ([preset isEqualToString:@"full"])     return @"Admin";
	if ([preset isEqualToString:@"standard"]) return @"Default";
	return @"Default";
}

static inline NSArray *TGAdminRightsRowTitles(void) {
	return @[@"Admin Rights", @"Admin Rights"];
}

/// Group preset first, then channel, in the official section order.
static inline NSArray *TGAdminRightsRowDetails(NSString *groupPreset,
		NSString *channelPreset) {
	return @[TGAdminPresetLabel(groupPreset), TGAdminPresetLabel(channelPreset)];
}

#ifndef TGROW_MODELS_ONLY
#import <UIKit/UIKit.h>
#import "TGRowsViewController.h"

@interface TGAdminRightsViewController : TGRowsViewController
@end
#endif

#endif // TGADMINRIGHTSVIEWCONTROLLER_H
