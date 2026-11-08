//
// TGGiftText.h - the two strings the gift detail screen builds.
//
#import <Foundation/Foundation.h>
#import "TGLocalization.h"

/// A unique gift's Value is its fiat worth, not sell_star_count. Both the
/// amount and the currency have to be there; official drops the row rather
/// than showing a resale star count in its place.
static inline BOOL TGGiftHasValue(NSDictionary *gift) {
	id amount = gift[@"valueAmount"];
	id currency = gift[@"valueCurrency"];
	return [amount isKindOfClass:NSNumber.class] &&
			[amount doubleValue] > 0 &&
			[currency isKindOfClass:NSString.class] &&
			[(NSString *)currency length] > 0;
}

/// TDLib sends value_amount in the currency's smallest units, as it does for
/// invoices, so the app's price formatter is the one to use here.
FOUNDATION_EXPORT NSString *TGMessageCardPrice(NSString *currency, int64_t amount);

static inline NSString *TGGiftValueText(NSDictionary *gift) {
	if (!TGGiftHasValue(gift))
		return nil;
	return TGMessageCardPrice(gift[@"valueCurrency"],
			[gift[@"valueAmount"] longLongValue]);
}

/// Gift_View_From.lowercased() with the name: "from Name". By key: the
/// English "From" is shared, and "from %@" maps to a bare "%@" in Russian.
static inline NSString *TGGiftSenderText(NSString *name) {
	if (!name.length)
		return nil;
	NSString *from = [TGLocalizedKey(@"Gift.View.From", @"From") lowercaseString];
	return [NSString stringWithFormat:@"%@ %@", from, name];
}
