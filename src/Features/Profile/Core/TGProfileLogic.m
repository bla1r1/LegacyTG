#import "TGProfileLogic.h"
#import "TGRows.h"
#import "TGBadge.h"
#import "TGLocalization.h"

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

NSArray *TGProfileUserInfoRows(NSDictionary *info) {
	if (![info isKindOfClass:NSDictionary.class])
		return @[];
	NSMutableArray *rows = [NSMutableArray array];

	NSString *phone = TGProfileTrimmed(info[@"phoneNumber"]);
	if (phone.length){
		[rows addObject:@{
			@"kind"  : @"phone",
			@"label" : @"Mobile",
			@"value" : [phone hasPrefix:@"+"] ? phone : [@"+" stringByAppendingString:phone],
		}];
	}

	NSArray *activeUsernames = [info[@"activeUsernames"] isKindOfClass:NSArray.class]
			? info[@"activeUsernames"] : @[];
	NSString *mainUsername = TGProfileTrimmed(info[@"username"]);
	if ([mainUsername hasPrefix:@"@"])
		mainUsername = [mainUsername substringFromIndex:1];
	if (!mainUsername.length)
		for (id value in activeUsernames)
			if ([value isKindOfClass:NSString.class] && [value length]){
				mainUsername = value;
				break;
			}
	// One Username row; the official item puts extra usernames under the
	// same value, not in rows of their own.
	if (mainUsername.length){
		[rows addObject:@{
			@"kind"  : @"username",
			@"label" : @"Username",
			@"value" : [@"@" stringByAppendingString:mainUsername],
		}];
	}

	NSString *birthday = TGProfileTrimmed(info[@"birthday"]);
	if (birthday.length){
		[rows addObject:@{
			@"kind"  : @"birthday",
			@"label" : @"Birthday",
			@"value" : birthday,
		}];
	}

	BOOL isOwnProfile = [info[@"isOwnProfile"] boolValue];
	BOOL isBot = [info[@"isBot"] boolValue];
	// A scam or fake account puts its warning where About would be.
	BOOL isScam = [info[@"isScam"] boolValue];
	BOOL isFake = [info[@"isFake"] boolValue];
	BOOL hasWarning = isScam || isFake;
	if (hasWarning){
		[rows addObject:@{
			@"kind"  : @"warning",
			@"label" : @"",
			@"value" : isScam ? @"Scam" : @"Fake",
		}];
	}

	NSString *bio = TGProfileTrimmed(info[@"bio"]);
	if (bio.length && !hasWarning){
		[rows addObject:@{
			@"kind"  : @"bio",
			@"label" : (isOwnProfile ? @"About" : @"Bio"),
			@"value" : bio,
		}];
	}

	NSString *note = TGProfileTrimmed(info[@"note"]);
	if (note.length){
		[rows addObject:@{
			@"kind"  : @"note",
			@"label" : @"Note",
			@"value" : note,
		}];
	}

	NSString *location = TGProfileTrimmed(info[@"businessLocation"]);
	if (location.length){
		[rows addObject:@{
			@"kind"  : @"businessLocation",
			@"label" : @"Location",
			@"value" : location,
		}];
	}

	BOOL isContact = [info[@"isContact"] boolValue];
	if (!isContact && !isOwnProfile && !isBot){
		[rows addObject:@{@"kind" : @"addContact", @"label" : @"",
				@"value" : @"Add to Contacts"}];
		// A stranger's card ends with Block User; a contact keeps it in More.
		[rows addObject:@{@"kind" : @"block", @"label" : @"",
				@"value" : ([info[@"blocked"] boolValue] ? @"Unblock" : @"Block User")}];
	}
	return rows;
}

NSArray *TGProfileGroupInfoRows(NSDictionary *info) {
	if (![info isKindOfClass:NSDictionary.class])
		return @[];
	NSMutableArray *rows = [NSMutableArray array];

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
	return rows;
}

NSString *TGProfileRowGlyphName(NSString *kind) {
	(void)kind;
	return nil;
}

NSString *TGProfileDisplayName(NSDictionary *user, NSString *phone) {
	NSString *first = TGProfileTrimmed(user[@"first_name"]) ?: @"";
	NSString *last = TGProfileTrimmed(user[@"last_name"]) ?: @"";
	NSString *name;
	if (first.length && last.length)
		name = [NSString stringWithFormat:@"%@ %@", first, last];
	else
		name = first.length ? first : last;
	NSString *trimmed = TGProfileTrimmed(name);
	if (trimmed.length)
		return trimmed;
	NSString *number = TGProfileTrimmed(phone);
	if (!number.length)
		number = TGProfileTrimmed(user[@"phone_number"]);
	if (!number.length)
		return @"";
	return [number hasPrefix:@"+"] ? number : [@"+" stringByAppendingString:number];
}

BOOL TGProfileMediaKindSupportsSearch(NSString *kind) {
	return [kind isEqualToString:@"files"] || [kind isEqualToString:@"music"] ||
			[kind isEqualToString:@"links"];
}

static BOOL TGProfileValueIsAccountText(NSString *kind) {
	static NSSet *kinds = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		kinds = [NSSet setWithObjects:@"phone", @"username", @"birthday",
				@"invite", @"link", @"bio", @"note", @"about",
				@"businessLocation", nil];
	});
	return [kinds containsObject:kind ?: @""];
}

NSDictionary *TGProfileInfoRowModel(NSDictionary *detail) {
	if (![detail isKindOfClass:NSDictionary.class])
		return nil;
	NSString *kind = detail[@"kind"] ?: @"";
	NSString *label = detail[@"label"] ?: @"";
	NSString *value = detail[@"value"] ?: @"";
	NSMutableDictionary *row = [TGSubtitleRow(label.length ? label : value,
			label.length ? value : nil, nil) mutableCopy];
	row[@"profileKind"] = kind;
	// Official card: label small above, value at body size; the value is the
	// accent colour unless it is prose (bio, about, note).
	if (label.length){
		row[TGRowLabelAbove] = @YES;
		BOOL prose = [kind isEqualToString:@"about"] || [kind isEqualToString:@"bio"] ||
				[kind isEqualToString:@"note"];
		if (!prose)
			row[TGRowDetailAccent] = @YES;
	}
	if ([kind isEqualToString:@"settings"])
		row[TGRowOpens] = @YES;
	if ([kind isEqualToString:@"about"] || [kind isEqualToString:@"bio"] ||
			[kind isEqualToString:@"note"])
		row[TGRowDetailLines] = @4;
	if (TGProfileValueIsAccountText(kind)){
		if (label.length)
			row[TGRowRawDetail] = @YES;
		else
			row[TGRowRawTitle] = @YES;
	}
	return row;
}

NSDictionary *TGProfileMemberRowModel(NSDictionary *member,
									  int64_t statusEmojiId) {
	if (![member isKindOfClass:NSDictionary.class])
		return nil;
	int64_t userId = [member[@"id"] longLongValue];
	NSString *name = [member[@"name"] isKindOfClass:NSString.class]
			? [member[@"name"] stringByTrimmingCharactersInSet:
					[NSCharacterSet whitespaceAndNewlineCharacterSet]] : nil;
	NSMutableDictionary *row = [TGPeerRow(@(userId), name ?: @"", nil, nil)
			mutableCopy];
	row[TGRowAvatarUser] = @YES;
	row[TGRowAccessory] = TGRowAccessoryDisclosure;
	if (statusEmojiId > 0)
		row[TGRowStatusEmojiId] = @(statusEmojiId);
	NSString *status = member[@"status"];
	NSString *tag = [member[@"tag"] isKindOfClass:NSString.class]
			? [member[@"tag"] stringByTrimmingCharactersInSet:
					[NSCharacterSet whitespaceAndNewlineCharacterSet]] : nil;
	if ([status isEqualToString:@"owner"]){
		row[TGRowBadge] = tag.length ? tag : TGLocalized(@"Owner");
		row[TGRowBadgeVariant] = @(TGBadgeVariantAccent);
		row[TGRowBadgeInline] = @YES;
	} else if ([status isEqualToString:@"admin"]){
		row[TGRowBadge] = tag.length ? tag : TGLocalized(@"Admin");
		row[TGRowBadgeVariant] = @(TGBadgeVariantMuted);
		row[TGRowBadgeInline] = @YES;
	}
	return row;
}

NSDictionary *TGProfileDangerRowModel(void) {
	return TGRedRow(TGLocalized(@"Delete Contact"), nil);
}

NSMutableDictionary *TGProfileMediaTabRowModel(NSArray *tabs,
		NSString *selectedKind) {
	NSArray *safeTabs = [tabs isKindOfClass:NSArray.class] ? tabs : @[];
	NSString *selected = [selectedKind isKindOfClass:NSString.class]
			? selectedKind : nil;
	if (!selected.length && safeTabs.count)
		selected = safeTabs[0][@"kind"];
	return TGTabStripRow(safeTabs, selected, nil);
}

NSArray *TGProfileGridRowModels(NSArray *items, NSInteger columns,
		NSDictionary *(^tileForIndex)(NSInteger index),
		void (^tap)(NSInteger index)) {
	if (![items isKindOfClass:NSArray.class])
		return @[];
	NSInteger width = MAX((NSInteger)1, columns);
	NSMutableArray *rows = [NSMutableArray array];
	for (NSInteger start = 0; start < (NSInteger)items.count;
			start += width){
		NSInteger end = MIN(start + width, (NSInteger)items.count);
		NSMutableArray *tiles = [NSMutableArray arrayWithCapacity:
				(NSUInteger)(end - start)];
		for (NSInteger index = start; index < end; index++){
			NSDictionary *tile = tileForIndex ? tileForIndex(index) : nil;
			[tiles addObject:[tile isKindOfClass:NSDictionary.class]
					? tile : @{}];
		}
		NSInteger blockStart = start;
		NSMutableDictionary *row = TGGridRow(tiles, width,
				^(NSInteger localIndex){
			if (tap)
				tap(blockStart + localIndex);
		});
		[rows addObject:row];
	}
	return rows;
}

static id TGProfileFixtureHandler(NSDictionary *fixture, NSString *key) {
	NSDictionary *handlers = fixture[@"handlers"];
	return [handlers isKindOfClass:NSDictionary.class] ? handlers[key] : nil;
}

static void TGProfileAttachFixtureTap(NSMutableDictionary *row,
		NSDictionary *fixture, NSString *key, id argument) {
	id handler = TGProfileFixtureHandler(fixture, key);
	if (!handler)
		return;
	void (^tap)(id) = handler;
	row[TGRowTap] = ^{ tap(argument); };
}

NSArray *TGProfileSectionsForFixture(NSDictionary *fixture) {
	if (![fixture isKindOfClass:NSDictionary.class])
		return @[];
	NSMutableArray *sections = [NSMutableArray array];

	NSDictionary *community = [fixture[@"community"]
			isKindOfClass:NSDictionary.class] ? fixture[@"community"] : nil;
	if ([community[@"id"] longLongValue] != 0){
		NSMutableDictionary *row = TGPeerRow(community[@"id"],
				community[@"title"] ?: TGLocalized(@"Community"),
				community[@"subtitle"], nil);
		row[TGRowAvatarUser] = @YES;
		row[TGRowAccessory] = TGRowAccessoryDisclosure;
		if (community[@"avatar"])
			row[TGRowAvatarImage] = community[@"avatar"];
		TGProfileAttachFixtureTap(row, fixture, @"community", nil);
		[sections addObject:TGSection(nil, nil, @[row])];
	}

	NSDictionary *channel = [fixture[@"personalChannel"]
			isKindOfClass:NSDictionary.class] ? fixture[@"personalChannel"] : nil;
	if ([channel[@"chatId"] longLongValue] != 0){
		NSMutableDictionary *row = TGPeerRow(channel[@"chatId"],
				channel[@"title"] ?: TGLocalized(@"Channel"),
				channel[@"subtitle"], nil);
		row[TGRowAccessory] = TGRowAccessoryDisclosure;
		if (channel[@"avatar"])
			row[TGRowAvatarImage] = channel[@"avatar"];
		TGProfileAttachFixtureTap(row, fixture, @"channel", nil);
		[sections addObject:TGSection(TGLocalized(@"Channel"), nil, @[row])];
	}

	NSArray *details = [fixture[@"details"] isKindOfClass:NSArray.class]
			? fixture[@"details"] : @[];
	if (details.count){
		NSMutableArray *rows = [NSMutableArray arrayWithCapacity:details.count];
		for (NSDictionary *detail in details){
			NSMutableDictionary *row = [TGProfileInfoRowModel(detail) mutableCopy];
			if (!row)
				continue;
			row[@"profileDetail"] = detail;
			TGProfileAttachFixtureTap(row, fixture, @"detail",
					detail[@"kind"] ?: @"");
			[rows addObject:row];
		}
		[sections addObject:TGSection(nil, nil, rows)];
	}

	if ([fixture[@"danger"] boolValue]){
		NSMutableDictionary *row = [TGProfileDangerRowModel() mutableCopy];
		TGProfileAttachFixtureTap(row, fixture, @"danger", nil);
		[sections addObject:TGSection(nil, nil, @[row])];
	}

	NSArray *members = [fixture[@"members"] isKindOfClass:NSArray.class]
			? fixture[@"members"] : @[];
	if (members.count){
		NSMutableArray *rows = [NSMutableArray arrayWithCapacity:members.count];
		for (NSUInteger index = 0; index < members.count; index++){
			NSDictionary *member = members[index];
			int64_t emojiId = [member[@"statusEmojiId"] longLongValue];
			NSMutableDictionary *row = [TGProfileMemberRowModel(member, emojiId)
					mutableCopy];
			if (!row)
				continue;
			NSString *name = member[@"name"];
			if (![row[TGRowTitle] length] && [name isKindOfClass:NSString.class])
				row[TGRowTitle] = name;
			row[@"profileMember"] = member;
			TGProfileAttachFixtureTap(row, fixture, @"member", @(index));
			[rows addObject:row];
		}
		NSInteger count = [fixture[@"memberCount"] integerValue];
		if (count <= 0)
			count = (NSInteger)members.count;
		BOOL isChannel = [fixture[@"isChannel"] boolValue];
		NSString *header = TGLocalizedPlural(
				isChannel ? @"%d subscriber" : @"%d member",
				isChannel ? @"%d subscribers" : @"%d members", count);
		[sections addObject:TGSection(header, nil, rows)];
	}

	NSArray *tabs = [fixture[@"mediaTabs"] isKindOfClass:NSArray.class]
			? fixture[@"mediaTabs"] : @[];
	if (tabs.count){
		NSMutableDictionary *strip = TGProfileMediaTabRowModel(tabs,
				fixture[@"mediaKind"]);
		id tabTap = TGProfileFixtureHandler(fixture, @"mediaTab");
		if (tabTap)
			strip[TGRowTabStripTap] = tabTap;
		id tabHold = TGProfileFixtureHandler(fixture, @"mediaTabHold");
		if (tabHold)
			strip[TGRowTabStripHold] = tabHold;
		if (fixture[@"tabStripOffset"])
			strip[TGRowTabStripOffset] = fixture[@"tabStripOffset"];
		NSMutableArray *rows = [NSMutableArray arrayWithObject:strip];
		NSArray *content = [fixture[@"mediaRows"] isKindOfClass:NSArray.class]
				? fixture[@"mediaRows"] : @[];
		[rows addObjectsFromArray:content];
		[sections addObject:TGSection(nil, nil, rows)];
	}

	return sections;
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
