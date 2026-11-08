#import "TGProfileLogic.h"

static NSString *TGProfileTrimmed(NSString *text) {
	if (![text isKindOfClass:NSString.class])
		return nil;
	return [text stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

NSString *TGProfileShortLinkText(NSString *link) {
	NSString *text = TGProfileTrimmed(link);
	if (!text.length)
		return nil;

	NSString *rest = text;
	NSString *lower = text.lowercaseString;
	NSRange scheme = [text rangeOfString:@"://"];
	if (scheme.location != NSNotFound){
		NSString *name = [[text substringToIndex:scheme.location] lowercaseString];
		rest = [text substringFromIndex:NSMaxRange(scheme)];
		// tg://resolve?domain=name is the share format the older clients
		// hand out; the card prints the t.me address everyone can read.
		if ([name isEqualToString:@"tg"] && [rest hasPrefix:@"resolve"]){
			NSRange domain = [rest rangeOfString:@"domain="];
			if (domain.location != NSNotFound){
				NSString *username = [rest substringFromIndex:NSMaxRange(domain)];
				username = [username componentsSeparatedByString:@"&"].firstObject;
				if (username.length)
					return [@"https://t.me/" stringByAppendingString:username];
			}
		}
	}

	if ([rest.lowercaseString hasPrefix:@"www."])
		rest = [rest substringFromIndex:4];

	BOOL hadScheme = (scheme.location != NSNotFound);
	BOOL telegramHost = NO;
	NSArray *hosts = @[@"t.me/", @"telegram.me/", @"telegram.dog/", @"telegram.org/"];
	for (NSString *host in hosts){
		if ([rest.lowercaseString hasPrefix:host]){
			rest = [rest substringFromIndex:host.length];
			telegramHost = YES;
			break;
		}
	}
	if (hadScheme && !telegramHost)
		return text;

	while ([rest hasPrefix:@"/"])
		rest = [rest substringFromIndex:1];
	if ([rest hasPrefix:@"@"])
		rest = [rest substringFromIndex:1];
	if (!rest.length)
		return nil;
	return [@"https://t.me/" stringByAppendingString:rest];
}

NSArray *TGProfileGroupInfoRows(NSDictionary *info) {
	if (![info isKindOfClass:NSDictionary.class])
		return @[];
	NSMutableArray *rows = [NSMutableArray array];

	int64_t communityId = [info[@"communityId"] longLongValue];
	NSString *communityName = TGProfileTrimmed(info[@"communityName"]) ?: @"";
	if (communityId != 0 || communityName.length){
		[rows addObject:@{
			@"kind"        : @"community",
			@"label"       : communityName.length ? communityName : @"Community",
			@"value"       : info[@"communitySubtitle"] ?: @"",
			@"communityId" : @(communityId),
		}];
	}

	NSString *username = TGProfileTrimmed(info[@"username"]);
	if ([username hasPrefix:@"@"])
		username = [username substringFromIndex:1];
	NSString *link = username.length
			? TGProfileShortLinkText(username)
			: TGProfileShortLinkText(info[@"inviteLink"]);
	if (link.length){
		[rows addObject:@{
			@"kind"  : @"invite",
			@"label" : @"Link",
			@"value" : link,
		}];
	}

	NSString *description = info[@"description"];
	if ([description isKindOfClass:NSString.class] && description.length){
		[rows addObject:@{
			@"kind"  : @"about",
			@"label" : @"Description",
			@"value" : description,
		}];
	}

	BOOL canManage = [info[@"canManage"] boolValue];
	BOOL isChannel = [info[@"isChannel"] boolValue];
	if (canManage){
		[rows addObject:@{
			@"kind"  : @"settings",
			@"label" : (isChannel ? @"Channel Settings" : @"Group Settings"),
			@"value" : @"",
		}];
	}

	NSString *linkedTitle = info[@"linkedChatTitle"];
	if ([linkedTitle isKindOfClass:NSString.class] && linkedTitle.length){
		[rows addObject:@{
			@"kind"  : @"linkedChat",
			@"label" : (isChannel ? @"Discussion Group" : @"Linked Channel"),
			@"value" : linkedTitle,
		}];
	}

	NSInteger similarCount = [info[@"similarChannelsCount"] integerValue];
	NSString *similarValue = info[@"similarChannelsValue"];
	if (isChannel && similarCount > 0 && [similarValue isKindOfClass:NSString.class])
		[rows addObject:@{
			@"kind"  : @"similarChannels",
			@"label" : @"Similar Channels",
			@"value" : similarValue,
		}];
	return rows;
}

BOOL TGProfileMediaKindSupportsSearch(NSString *kind) {
	return [kind isEqualToString:@"files"] || [kind isEqualToString:@"music"] ||
			[kind isEqualToString:@"links"];
}

NSArray *TGProfileMediaRowsMatchingQuery(NSArray *rows, NSString *query,
										 NSString *kind) {
	if (![rows isKindOfClass:NSArray.class])
		return @[];
	if (!TGProfileMediaKindSupportsSearch(kind))
		return rows;
	NSString *needle = [TGProfileTrimmed(query) lowercaseString];
	if (!needle.length)
		return rows;
	NSMutableArray *matches = [NSMutableArray array];
	for (NSDictionary *row in rows){
		if (![row isKindOfClass:NSDictionary.class])
			continue;
		NSString *text = row[@"docName"] ?: row[@"audioTitle"] ?: row[@"text"] ?: @"";
		NSString *performer = row[@"audioPerformer"] ?: @"";
		if (![text isKindOfClass:NSString.class]) text = @"";
		if (![performer isKindOfClass:NSString.class]) performer = @"";
		if ([text.lowercaseString rangeOfString:needle].location != NSNotFound ||
				[performer.lowercaseString rangeOfString:needle].location != NSNotFound)
			[matches addObject:row];
	}
	return matches;
}
