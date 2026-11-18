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

/// An attribute row's detail: the name, then its rarity where official puts
/// the badge (GiftViewScreen, rarity beside Model, Backdrop and Symbol).
static inline NSString *TGGiftAttributeDetail(NSString *name, NSString *rarity) {
	if (![name isKindOfClass:NSString.class])
		name = @"";
	if (![rarity isKindOfClass:NSString.class] || !rarity.length)
		return name;
	return name.length ? [NSString stringWithFormat:@"%@ \u00B7 %@", name, rarity] : rarity;
}

/// Gift.Unique.Issued with "issued/total", grouped as official groups them.
static inline NSString *TGGiftIssuedText(long long issued, long long total) {
	NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
	f.numberStyle = NSNumberFormatterDecimalStyle;
	NSString *pair = [NSString stringWithFormat:@"%@/%@",
			[f stringFromNumber:@(issued)], [f stringFromNumber:@(total)]];
	return [NSString stringWithFormat:TGLocalizedKey(@"Gift.Unique.Issued", @"%@ issued"), pair];
}

/// Gift.Unique.OriginalInfo[Sender][WithText]: who first gave the gift, to
/// whom, when, and the comment. No sender when it was given anonymously.
static inline NSString *TGGiftOriginalText(NSString *sender, NSString *receiver,
		NSString *date, NSString *comment) {
	receiver = receiver ?: @"";
	date = date ?: @"";
	BOOL hasComment = [comment isKindOfClass:NSString.class] && comment.length;
	if (sender.length) {
		return hasComment
				? [NSString stringWithFormat:TGLocalizedKey(@"Gift.Unique.OriginalInfoSenderWithText",
						@"Gifted by %1$@ to %2$@ on %3$@ with comment \"%4$@\"."), sender, receiver, date, comment]
				: [NSString stringWithFormat:TGLocalizedKey(@"Gift.Unique.OriginalInfoSender",
						@"Gifted by %1$@ to %2$@ on %3$@."), sender, receiver, date];
	}
	return hasComment
			? [NSString stringWithFormat:TGLocalizedKey(@"Gift.Unique.OriginalInfoWithText",
					@"Gifted to %1$@ on %2$@ with comment \"%3$@\"."), receiver, date, comment]
			: [NSString stringWithFormat:TGLocalizedKey(@"Gift.Unique.OriginalInfo",
					@"Gifted to %1$@ on %2$@."), receiver, date];
}

/// Gift.View.ReleasedBy with the channel's username: "released by @cats".
/// Official shows it under the title only when no sender line takes the
/// place (GiftViewScreen releasedBy, after the gift message's sender).
static inline NSString *TGGiftReleasedByText(NSString *username) {
	if (![username isKindOfClass:NSString.class] || !username.length)
		return nil;
	return [NSString stringWithFormat:TGLocalizedKey(@"Gift.View.ReleasedBy", @"released by %@"),
			[@"@" stringByAppendingString:username]];
}
