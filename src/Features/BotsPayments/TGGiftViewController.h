//
// TGGiftViewController.h - detail screen for a received gift.
//
#import <Foundation/Foundation.h>
#import "TGGiftText.h"

/// The detail row titles in the order the card draws them. A regular gift has
/// Date and Value; a collectible adds Owner and Telegram (the hosting chat)
/// when known, Model, Symbol and Backdrop, Availability when the kind has a
/// limit, and Value only when the gift carries both an amount and a currency
/// (official GiftViewScreen's unique table, after our Date).
static inline NSArray *TGGiftDetailRowTitles(NSDictionary *gift) {
	NSMutableArray *titles = [NSMutableArray arrayWithObject:TGLocalized(@"Date")];
	if ([gift[@"isCollectible"] boolValue]){
		if ([gift[@"ownerUserId"] longLongValue] || [gift[@"ownerChatId"] longLongValue] ||
				[gift[@"ownerName"] length])
			[titles addObject:TGLocalizedKey(@"Gift.Unique.Owner", @"Owner")];
		if ([gift[@"hostUserId"] longLongValue] || [gift[@"hostChatId"] longLongValue])
			[titles addObject:TGLocalizedKey(@"Gift.Unique.Telegram", @"Telegram")];
		[titles addObjectsFromArray:@[
			TGLocalized(@"Model"), TGLocalized(@"Symbol"),
			TGLocalized(@"Backdrop"),
		]];
		if ([gift[@"issuedTotal"] longLongValue] > 0)
			[titles addObject:TGLocalizedKey(@"Gift.Unique.Availability", @"Availability")];
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
