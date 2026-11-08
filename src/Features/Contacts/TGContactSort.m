#import "TGContactSort.h"

NSInteger TGContactPresenceRank(NSDictionary *status) {
	if (![status isKindOfClass:[NSDictionary class]])
		return 6;
	NSString *type = status[@"@type"];
	if ([type isEqualToString:@"userStatusOnline"])
		return 0;
	if ([type isEqualToString:@"userStatusRecently"])
		return 2;
	if ([type isEqualToString:@"userStatusLastWeek"])
		return 3;
	if ([type isEqualToString:@"userStatusLastMonth"])
		return 4;
	if ([type isEqualToString:@"userStatusOffline"])
		return 5;
	return 6;
}

NSString *TGContactDisplayName(NSDictionary *user) {
	if (![user isKindOfClass:[NSDictionary class]])
		return @"";
	NSString *first = user[@"first_name"] ?: @"";
	NSString *last  = user[@"last_name"] ?: @"";
	NSString *name  = [[NSString stringWithFormat:@"%@ %@", first, last]
			stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	if (name.length)
		return name;
	if ([user[@"username"] length])
		return [NSString stringWithFormat:@"@%@", user[@"username"]];
	return user[@"phone"] ?: @"";
}

static double TGContactWasOnline(NSDictionary *status) {
	if ([status isKindOfClass:[NSDictionary class]] &&
			[status[@"@type"] isEqualToString:@"userStatusOffline"])
		return [status[@"was_online"] doubleValue];
	return 0;
}

NSComparisonResult TGContactCompareByLastSeen(NSDictionary *a, NSDictionary *b) {
	NSInteger rankA = TGContactPresenceRank(a[@"status"]);
	NSInteger rankB = TGContactPresenceRank(b[@"status"]);
	if (rankA != rankB)
		return rankA < rankB ? NSOrderedAscending : NSOrderedDescending;
	if (rankA == 5) {
		double wasA = TGContactWasOnline(a[@"status"]);
		double wasB = TGContactWasOnline(b[@"status"]);
		if (wasA != wasB)
			return wasA > wasB ? NSOrderedAscending : NSOrderedDescending;
	}
	return [TGContactDisplayName(a) localizedCaseInsensitiveCompare:
			TGContactDisplayName(b)];
}

NSArray *TGContactsSortedByLastSeen(NSArray *users) {
	return [users sortedArrayUsingComparator:^NSComparisonResult(id a, id b){
		return TGContactCompareByLastSeen(a, b);
	}];
}

NSArray *TGContactsSortedByName(NSArray *users) {
	return [users sortedArrayUsingComparator:^NSComparisonResult(id a, id b){
		return [TGContactDisplayName(a) localizedCaseInsensitiveCompare:
				TGContactDisplayName(b)];
	}];
}
