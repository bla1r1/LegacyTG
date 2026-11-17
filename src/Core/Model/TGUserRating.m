#import "TGUserRating.h"
#import "TGLocalization.h"

NSDictionary *TGUserRatingFrom(NSDictionary *r) {
	if (![r isKindOfClass:NSDictionary.class])
		return nil;
	NSMutableDictionary *out = [@{
		@"level"   : @([r[@"level"] intValue]),
		@"rating"  : @([r[@"rating"] longLongValue]),
		@"current" : @([r[@"current_level_rating"] longLongValue]),
	} mutableCopy];
	if (![r[@"is_maximum_level_reached"] boolValue])
		out[@"next"] = @([r[@"next_level_rating"] longLongValue]);
	return out;
}

double TGUserRatingFraction(NSDictionary *r) {
	long long rating = [r[@"rating"] longLongValue];
	long long current = [r[@"current"] longLongValue];
	NSNumber *next = r[@"next"];
	if (rating < 0)
		return 0.5;
	if (!next || next.longLongValue <= current || next.longLongValue <= rating)
		return 1.0;
	return MAX(0.0, (double)(rating - current) / (double)(next.longLongValue - current));
}

NSString *TGUserRatingLevelText(NSDictionary *r) {
	int level = [r[@"level"] intValue];
	if (level < 0)
		return TGLocalizedKey(@"ProfileLevelInfo.NegativeRating", @"Negative rating");
	return TGLocalizedPluralValue(@"Level %@", @"Level %@", [@(level) stringValue], level);
}

static NSString *TGRatingNumber(long long value) {
	NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
	f.numberStyle = NSNumberFormatterDecimalStyle;
	return [f stringFromNumber:@(value)] ?: [@(value) stringValue];
}

NSString *TGUserRatingProgressText(NSDictionary *r) {
	NSString *now = TGRatingNumber([r[@"rating"] longLongValue]);
	NSNumber *next = r[@"next"];
	return next ? [NSString stringWithFormat:@"%@ / %@", now, TGRatingNumber(next.longLongValue)] : now;
}

/// Official's preview sentence ends in a "[Preview >]()" link to the future
/// rating, a mode this screen does not have; the link goes, the words stay.
static NSString *TGWithoutLink(NSString *text) {
	NSRange link = [text rangeOfString:@" ["];
	return link.location == NSNotFound ? text : [text substringToIndex:link.location];
}

NSString *TGUserRatingPendingText(NSDictionary *r, NSDictionary *pending,
		int64_t pendingDate, NSTimeInterval now) {
	if (!r || !pending || pendingDate <= (int64_t)now)
		return nil;
	long long points = [pending[@"rating"] longLongValue] - [r[@"rating"] longLongValue];
	if (points <= 0)
		return nil;
	NSInteger days = (NSInteger)((pendingDate - (int64_t)now) / (24 * 60 * 60));
	NSString *count = TGRatingNumber(points);
	if (days == 0)
		return TGLocalizedPluralValue(@"The rating updates today.\n%@ point is pending.",
				@"The rating updates today.\n%@ points are pending.", count, (NSInteger)points);
	NSString *daysText = TGLocalizedPluralValue(@"%@ day", @"%@ days", [@(days) stringValue], days);
	NSString *pointsText = TGLocalizedPluralValue(@"%@ point is", @"%@ points are", count, (NSInteger)points);
	NSString *sentence = [NSString stringWithFormat:
			TGLocalizedKey(@"ProfileLevelInfo.MyDescriptionPreview",
					@"The rating will update in %@.\n%@ pending. [Preview >]()"),
			daysText, pointsText];
	return TGWithoutLink(sentence);
}
