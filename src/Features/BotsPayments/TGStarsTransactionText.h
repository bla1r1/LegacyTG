//
// TGStarsTransactionText.h - one Telegram Stars ledger row as text.
//
// The console used to join date, the raw TDLib short type and an unsigned
// amount into one string, so a purchase looked exactly like a sale and a
// refund looked like income. This turns one transaction into the three parts
// an official row draws: a localized type title, a date subtitle and a signed
// amount. Pure so the incoming/outgoing/refund cases can be host-tested.
//
#import <Foundation/Foundation.h>
#import "TGLocalization.h"

/// TDLib's short type ("giftPurchase") as the pack spells it ("Gift Purchase").
static inline NSString *TGStarsTransactionTitle(NSDictionary *transaction) {
	NSString *type = [transaction[@"type"] isKindOfClass:NSString.class]
			? transaction[@"type"] : @"";
	NSString *name = type;
	if ([name hasPrefix:@"starTransactionType"])
		name = [name substringFromIndex:@"starTransactionType".length];
	if (!name.length)
		return TGLocalized(@"Stars Transactions");

	NSMutableString *spaced = [NSMutableString string];
	for (NSUInteger i = 0; i < name.length; i++) {
		unichar c = [name characterAtIndex:i];
		if (i > 0 && c >= 'A' && c <= 'Z')
			[spaced appendString:@" "];
		[spaced appendFormat:@"%C", c];
	}
	NSString *title = [spaced stringByReplacingCharactersInRange:NSMakeRange(0, 1)
			withString:[[spaced substringToIndex:1] uppercaseString]];
	if ([transaction[@"isRefund"] boolValue])
		return TGLocalized(@"Refund");
	return TGLocalized(title);
}

/// TDLib's star_amount is signed: spending is negative, income and refunds
/// positive. The sign is the direction; the type name says nothing reliable.
static inline NSDictionary *TGStarsTransactionRow(NSDictionary *transaction) {
	long long stars = [transaction[@"starCount"] isKindOfClass:NSNumber.class]
			? [transaction[@"starCount"] longLongValue] : 0;
	BOOL outgoing = stars < 0;
	NSString *amount = TGLocalizedFormat(@"%@ Stars", @(llabs(stars)));
	return @{
		@"title" : TGStarsTransactionTitle(transaction),
		@"subtitle" : transaction[@"dateText"] ?: @"",
		@"amount" : [(outgoing ? @"-" : @"+") stringByAppendingString:amount],
		@"isOutgoing" : @(outgoing),
		@"isRefund" : @([transaction[@"isRefund"] boolValue]),
	};
}
