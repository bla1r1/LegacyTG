//
// TGDiceViewController - the stake dice panel for a channel direct messages
// chat: the state Telegram hands out and the prize table that goes with it.
//
#import <UIKit/UIKit.h>
#import "TGRowsViewController.h"
#import "TGLocalization.h"

@interface TGDiceViewController : TGRowsViewController

@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, copy)   NSString *chatTitle;

@end

/// The API counts in the smallest TON unit; the panel reads in TON, with
/// enough decimals to see a small suggested stake.
static inline NSString *TGDiceTONText(NSNumber *grams) {
	double value = [grams doubleValue] / 1000000000.0;
	return [NSString stringWithFormat:@"%.4f TON", value];
}

/// The five Status rows as title/detail pairs.
static inline NSArray *TGDiceStatusRows(NSDictionary *state, int64_t chatId) {
	return @[
		@{@"title" : TGLocalized(@"State hash"),
		  @"detail" : state[@"stateHash"] ?: TGLocalized(@"None")},
		@{@"title" : TGLocalized(@"Last stake"),
		  @"detail" : TGDiceTONText(state[@"stakeGramAmount"] ?: @(0))},
		@{@"title" : TGLocalized(@"Current streak"),
		  @"detail" : [NSString stringWithFormat:@"%@ of 3",
				  state[@"currentStreak"] ?: @(0)]},
		@{@"title" : TGLocalized(@"Streak prize"),
		  @"detail" : [NSString stringWithFormat:@"%@ per 1000",
				  state[@"streakPrizePerMille"] ?: @(0)]},
		@{@"title" : TGLocalized(@"Chat"),
		  @"detail" : chatId ? [NSString stringWithFormat:@"%lld", chatId]
				  : @"—"},
	];
}

static inline NSArray *TGDiceSuggestedRows(NSArray *amounts) {
	NSMutableArray *rows = [NSMutableArray arrayWithCapacity:amounts.count];
	for (NSNumber *amount in amounts)
		[rows addObject:@{@"title" : TGDiceTONText(amount)}];
	return rows;
}

static inline NSArray *TGDicePrizeRows(NSArray *prizes) {
	NSMutableArray *rows = [NSMutableArray arrayWithCapacity:prizes.count];
	for (NSUInteger index = 0; index < prizes.count; index++){
		[rows addObject:@{
			@"title" : [NSString stringWithFormat:TGLocalized(@"Face %ld"),
					(long)index + 1],
			@"detail" : [NSString stringWithFormat:
					TGLocalized(@"%@ per 1000 staked"), prizes[index]],
		}];
	}
	return rows;
}
