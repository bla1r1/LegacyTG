#import "TGLoginLogic.h"
#import "TGLocalization.h"
#import "TGStyle.h"

const CGFloat TGLoginNarrowWidth = 360.0f;

BOOL TGLoginUsesBarNext(CGFloat width) {
	return width < TGLoginNarrowWidth;
}

NSInteger TGLoginCodeFocusedBox(NSUInteger typed, NSInteger boxes) {
	return (NSInteger)typed < boxes ? (NSInteger)typed : -1;
}

BOOL TGLoginShowsBottomButton(BOOL fieldStep, CGFloat width) {
	return fieldStep && !TGLoginUsesBarNext(width);
}

CGFloat TGLoginYAfterActionRow(CGFloat y, CGFloat width) {
	return TGLoginUsesBarNext(width) ? y : y + TGMetricRow + TGMetricStackStep;
}

/// The sentence over a word or phrase code, with official's hint at its
/// start when TDLib gives one (Login.EnterWordBeginningText).
NSString *TGLoginWordCodeSentence(NSDictionary *type, NSString *phone) {
	BOOL phrase = [type[@"@type"] isEqualToString:@"authenticationCodeTypeSmsPhrase"];
	NSString *start = phrase ? type[@"first_word"] : type[@"first_letter"];
	if ([start isKindOfClass:NSString.class] && start.length)
		return TGLocalizedFormat(phrase
				? @"We've sent you an SMS with a secret phrase that starts with **\"%1$@\"** to your phone **%2$@**."
				: @"We've sent you an SMS with a secret word that starts with **\"%1$@\"** to your phone **%2$@**.",
				start, phone ?: @"");
	return TGLocalizedFormat(phrase
			? @"We've sent you an SMS with a secret phrase to your phone **%@**."
			: @"We've sent you an SMS with a secret word to your phone **%@**.", phone ?: @"");
}

NSString *TGLoginResetInterval(NSInteger seconds) {
	if (seconds < 3600){
		NSInteger m = MAX(1, seconds / 60);
		return TGLocalizedPluralValue(@"in 1 minute", @"in %@ minutes",
				[NSString stringWithFormat:@"%ld", (long)m], m);
	}
	if (seconds < 86400){
		NSInteger h = MAX(1, seconds / 3600);
		return TGLocalizedPluralValue(@"in 1 hour", @"in %@ hours",
				[NSString stringWithFormat:@"%ld", (long)h], h);
	}
	NSInteger d = MAX(1, seconds / 86400);
	return TGLocalizedPluralValue(@"in 1 day", @"in %@ days",
			[NSString stringWithFormat:@"%ld", (long)d], d);
}

NSString *TGLoginEmailResetPendingText(NSInteger resetIn) {
	NSString *when;
	if (resetIn <= 0)
		when = TGLocalized(@"Please wait...");
	else if (resetIn < 86400)
		when = TGLocalizedFormat(@"in %@", [NSString stringWithFormat:@"%ld:%02ld",
				(long)(resetIn / 60), (long)(resetIn % 60)]);
	else
		when = TGLoginResetInterval(resetIn);
	return TGLocalizedFormat(@"Email will be reset %@", when);
}

NSString *TGCountryRowTitle(NSDictionary *country) {
	NSString *name = country[@"name"];
	return [name isKindOfClass:NSString.class] ? name : @"";
}

NSArray *TGCountrySections(NSArray *countries, NSString *query) {
	NSArray *sorted = [countries sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b){
		return [a[@"name"] ?: @"" localizedCaseInsensitiveCompare:b[@"name"] ?: @""];
	}];
	NSString *needle = [query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	if (needle.length){
		// "+49", "49" and "ger" all find Germany.
		NSString *digits = [needle stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"+"]];
		NSMutableArray *found = [NSMutableArray array];
		for (NSDictionary *country in sorted){
			NSString *name = country[@"name"] ?: @"";
			NSString *prefix = country[@"prefix"] ?: @"";
			if ([name rangeOfString:needle options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location != NSNotFound ||
					(digits.length && [prefix rangeOfString:digits].location != NSNotFound))
				[found addObject:country];
		}
		return found.count ? @[@{@"title" : @"", @"countries" : found}] : @[];
	}
	NSMutableArray *sections = [NSMutableArray array];
	for (NSDictionary *country in sorted){
		NSString *name = country[@"name"] ?: @"";
		NSString *letter = name.length
				? [[name substringWithRange:[name rangeOfComposedCharacterSequenceAtIndex:0]] uppercaseString] : @"#";
		NSDictionary *last = sections.lastObject;
		if (![last[@"title"] isEqualToString:letter])
			[sections addObject:@{@"title" : letter, @"countries" : [NSMutableArray array]}];
		[sections.lastObject[@"countries"] addObject:country];
	}
	return sections;
}
