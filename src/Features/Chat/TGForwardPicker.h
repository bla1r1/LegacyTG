//
// TGForwardPicker - choose a chat to forward into.
//
#import <Foundation/Foundation.h>
#import "TGLocalization.h"

/// One "Recent chats" heading; the flat list has no second heading and a live
/// query - or an empty result - has none at all.
static inline NSString *TGForwardPickerSectionHeader(NSString *query,
		NSUInteger matchCount) {
	if (query.length || matchCount == 0)
		return nil;
	return TGLocalized(@"Recent chats");
}

#ifndef TGROW_MODELS_ONLY
#import <UIKit/UIKit.h>
#import "TGRowsViewController.h"

@interface TGForwardPicker : TGRowsViewController
@property (nonatomic, copy) void (^onPicked)(int64_t chatId);
/// The chat the messages came from; it is not a destination and never appears
/// in the recent strip.
@property (nonatomic, assign) int64_t sourceChatId;
@end
#endif
