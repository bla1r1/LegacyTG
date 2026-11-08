//
// TGPollPresentation.m - the words and marks a poll shows.
//
// Every value read here may be NSNull or a JSON string, so the readers below
// never trust the class they are handed.
//
#import "TGPollPresentation.h"
#import "TGLocalization.h"

static long long TGPollLongLong(id value) {
	if ([value isKindOfClass:NSNumber.class] || [value isKindOfClass:NSString.class])
		return [value longLongValue];
	return 0;
}

static BOOL TGPollBool(id value) {
	if ([value isKindOfClass:NSNumber.class] || [value isKindOfClass:NSString.class])
		return [value boolValue];
	return NO;
}

static NSArray *TGPollOptions(NSDictionary *poll) {
	id options = [poll isKindOfClass:NSDictionary.class] ? poll[@"options"] : nil;
	return [options isKindOfClass:NSArray.class] ? options : @[];
}

static NSDictionary *TGPollOptionAt(NSDictionary *poll, NSUInteger index) {
	NSArray *options = TGPollOptions(poll);
	if (index >= options.count)
		return nil;
	id option = options[index];
	return [option isKindOfClass:NSDictionary.class] ? option : nil;
}

static BOOL TGPollOptionChosen(NSDictionary *option) {
	return TGPollBool(option[@"isChosen"]);
}

static BOOL TGPollAnyChosen(NSDictionary *poll) {
	for (NSDictionary *option in TGPollOptions(poll))
		if (TGPollOptionChosen(option))
			return YES;
	return NO;
}

NSString *TGPollOptionText(NSDictionary *option) {
	if (![option isKindOfClass:NSDictionary.class])
		return @"";
	id text = option[@"text"];
	if ([text isKindOfClass:NSString.class])
		return text;
	if ([text isKindOfClass:NSDictionary.class]) {
		id inner = text[@"text"];
		return [inner isKindOfClass:NSString.class] ? inner : @"";
	}
	return @"";
}

NSString *TGPollKindLine(NSDictionary *poll) {
	if (![poll isKindOfClass:NSDictionary.class])
		return @"Poll";
	if (TGPollBool(poll[@"isClosed"]))
		return @"Final results";
	BOOL anonymous = TGPollBool(poll[@"isAnonymous"]);
	if (TGPollBool(poll[@"isQuiz"]))
		return anonymous ? @"Anonymous Quiz" : @"Quiz";
	return anonymous ? @"Anonymous Poll" : @"Poll";
}

NSString *TGPollVotesLine(NSDictionary *poll) {
	long long count = [poll isKindOfClass:NSDictionary.class]
			? TGPollLongLong(poll[@"totalVoterCount"]) : 0;
	if (count < 0)
		count = 0;
	BOOL quiz = [poll isKindOfClass:NSDictionary.class] && TGPollBool(poll[@"isQuiz"]);
	NSString *value = [NSString stringWithFormat:@"%lld", count];
	if (quiz) {
		if (count == 0)
			return @"Nobody answered yet";
		return TGLocalizedFormat(@"%@ answered", value);
	}
	if (count == 0)
		return @"No votes";
	return TGLocalizedPluralValue(@"%@ vote", @"%@ votes", value, (NSInteger)count);
}

NSString *TGPollClosesLine(NSDictionary *poll, NSTimeInterval now) {
	if (![poll isKindOfClass:NSDictionary.class])
		return nil;
	if (TGPollBool(poll[@"isClosed"]))
		return nil;
	NSTimeInterval closeDate = (NSTimeInterval)TGPollLongLong(poll[@"closeDate"]);
	if (closeDate <= 0 || closeDate <= now)
		return nil;

	long long left = (long long)(closeDate - now);
	if (left < 0)
		left = 0;
	if (left >= 86400) {
		long long days = left / 86400;
		return TGLocalizedPluralValue(@"ends in %@ day", @"ends in %@ days",
				[NSString stringWithFormat:@"%lld", days], (NSInteger)days);
	}
	long long hours = left / 3600;
	long long minutes = (left % 3600) / 60;
	long long seconds = left % 60;
	NSString *clock = hours > 0
			? [NSString stringWithFormat:@"%lld:%02lld:%02lld", hours, minutes, seconds]
			: [NSString stringWithFormat:@"%lld:%02lld", minutes, seconds];
	return TGLocalizedFormat(@"ends in %@", clock);
}

BOOL TGPollShowsResults(NSDictionary *poll) {
	if (![poll isKindOfClass:NSDictionary.class])
		return NO;
	if (TGPollBool(poll[@"isClosed"]))
		return YES;
	return TGPollAnyChosen(poll);
}

TGPollMark TGPollMarkForOption(NSDictionary *poll, NSUInteger index) {
	if (!TGPollShowsResults(poll))
		return TGPollMarkNone;
	NSDictionary *option = TGPollOptionAt(poll, index);
	if (!option)
		return TGPollMarkNone;

	BOOL chosen = TGPollOptionChosen(option);
	if (TGPollBool(poll[@"isQuiz"])) {
		long long correct = TGPollLongLong(poll[@"correctOption"]);
		if (correct >= 0 && (long long)index == correct)
			return TGPollMarkCorrect;
		return chosen ? TGPollMarkWrong : TGPollMarkNone;
	}
	return chosen ? TGPollMarkChosen : TGPollMarkNone;
}

NSArray *TGPollVoteIndexes(NSIndexSet *pending) {
	if (![pending isKindOfClass:NSIndexSet.class] || !pending.count)
		return @[];
	NSMutableArray *indexes = [NSMutableArray array];
	[pending enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
		[indexes addObject:@(index)];
	}];
	return indexes;
}

BOOL TGPollCanRetract(NSDictionary *poll) {
	if (![poll isKindOfClass:NSDictionary.class])
		return NO;
	if (TGPollBool(poll[@"isClosed"]) || TGPollBool(poll[@"isQuiz"]))
		return NO;
	if (!TGPollBool(poll[@"allowsRevoting"]))
		return NO;
	return TGPollAnyChosen(poll);
}
