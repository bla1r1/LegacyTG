//
// TGScheduledViewController - what a chat has waiting to be sent.
//
#import <Foundation/Foundation.h>
#import "TGLocalization.h"
#import "TGUIFormat.h"

/// The two lines of one waiting message: the text (or its official fallback)
/// and the day, clock and relative span in the shared format.
static inline NSString *TGScheduledRowDetail(NSTimeInterval stamp,
		NSTimeInterval now) {
	NSString *when = TGUIFormatScheduledWhen(stamp, now);
	NSString *until = TGUIFormatScheduledRelative(stamp, now);
	return when.length
			? (until.length ? [NSString stringWithFormat:@"%@  ·  %@", when, until]
					: when)
			: until;
}

static inline NSArray *TGScheduledRowModels(NSArray *messages,
		NSTimeInterval now) {
	NSMutableArray *rows = [NSMutableArray arrayWithCapacity:messages.count];
	for (NSDictionary *message in messages){
		NSString *text = message[@"text"];
		[rows addObject:@{
			@"title" : text.length ? text : TGLocalized(@"Message"),
			@"detail" : TGScheduledRowDetail(
					[message[@"date"] doubleValue], now),
		}];
	}
	return rows;
}

#ifndef TGROW_MODELS_ONLY
#import <UIKit/UIKit.h>
#import "TGRowsViewController.h"

@interface TGScheduledViewController : TGRowsViewController

@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, copy)   NSString *chatTitle;

@end
#endif
