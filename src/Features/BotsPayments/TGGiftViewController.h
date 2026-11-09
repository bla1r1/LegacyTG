//
// TGGiftViewController.h - detail screen for a received gift.
//
#import <Foundation/Foundation.h>
#import "TGGiftText.h"

/// The detail row titles in the order the card draws them. A regular gift has
/// Date and Value; a collectible adds Model, Symbol and Backdrop, and Value
/// only when the gift carries both an amount and a currency.
static inline NSArray *TGGiftDetailRowTitles(NSDictionary *gift) {
	NSMutableArray *titles = [NSMutableArray arrayWithObject:TGLocalized(@"Date")];
	if ([gift[@"isCollectible"] boolValue]){
		[titles addObjectsFromArray:@[
			TGLocalized(@"Model"), TGLocalized(@"Symbol"),
			TGLocalized(@"Backdrop"),
		]];
		if (TGGiftHasValue(gift))
			[titles addObject:TGLocalized(@"Value")];
	} else {
		[titles addObject:TGLocalized(@"Value")];
	}
	return titles;
}

#ifndef TGROW_MODELS_ONLY
#import <UIKit/UIKit.h>
#import "TGRowsViewController.h"

@interface TGGiftViewController : TGRowsViewController

- (instancetype)initWithGift:(NSDictionary *)gift;

@end
#endif
