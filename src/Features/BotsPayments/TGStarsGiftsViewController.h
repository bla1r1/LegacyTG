//
// TGStarsGiftsViewController.h - the Premium, Stars and gift records a user
// account may read.
//
#import <Foundation/Foundation.h>

/// The ledger rows a screen hands to the shared row builder: the localized
/// type, the date subtitle and the signed amount on the trailing edge.
static inline NSArray *TGStarsLedgerRowModels(NSArray *rows) {
	NSMutableArray *models = [NSMutableArray arrayWithCapacity:rows.count];
	for (NSDictionary *row in rows){
		[models addObject:@{
			@"title" : row[@"title"] ?: @"",
			@"subtitle" : row[@"subtitle"] ?: @"",
			@"amount" : row[@"amount"] ?: @"",
			@"isOutgoing" : @([row[@"isOutgoing"] boolValue]),
		}];
	}
	return models;
}

#ifndef TGROW_MODELS_ONLY
#import "TGBusinessViewController.h"

@interface TGStarsGiftsViewController : TGBusinessBaseViewController
@end
#endif

// vim:ft=objc
