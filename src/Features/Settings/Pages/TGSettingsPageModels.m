//
// TGSettingsPageModels.m - see the header. Pure Foundation; no UIKit.
//
#import "TGSettingsPageModels.h"
#import "TGSettingsFormatting.h"

NSString *const TGPageModelHeader = @"header";
NSString *const TGPageModelFooter = @"footer";
NSString *const TGPageModelRows = @"rows";

NSString *const TGPageModelRowTitle = @"title";
NSString *const TGPageModelRowDetail = @"detail";
NSString *const TGPageModelRowKind = @"kind";
NSString *const TGPageModelRowIcon = @"icon";
NSString *const TGPageModelRowColour = @"colour";
NSString *const TGPageModelRowOn = @"on";
NSString *const TGPageModelRowAction = @"action";
NSString *const TGPageModelRowIndex = @"index";

static NSDictionary *TGPageSection(NSString *header, NSString *footer,
								   NSArray *rows) {
	NSMutableDictionary *section = [NSMutableDictionary dictionary];
	if (header)
		section[TGPageModelHeader] = header;
	if (footer)
		section[TGPageModelFooter] = footer;
	section[TGPageModelRows] = rows ?: @[];
	return section;
}

static NSMutableDictionary *TGPageRow(NSString *kind, NSString *title,
									  NSString *action) {
	NSMutableDictionary *row = [@{
		TGPageModelRowKind : kind,
		TGPageModelRowTitle : title ?: @"",
	} mutableCopy];
	if (action)
		row[TGPageModelRowAction] = action;
	return row;
}

/// The proxy row's type and state, as ProxySettingsServerItem words it.
static NSString *TGProxyDetail(NSDictionary *proxy, BOOL connected) {
	NSString *kind = proxy[@"kind"];
	NSString *type = [kind isEqualToString:@"mtproto"] ? @"MTProto"
			: ([kind isEqualToString:@"http"] ? @"HTTP"
			: ([kind isEqualToString:@"web"] ? @"Web" : @"SOCKS5"));
	BOOL enabled = [proxy[@"enabled"] boolValue];
	// A record without an answer is still being checked, not a 0 ms server.
	BOOL pending = ![proxy[@"pingState"] isEqualToString:@"done"];
	double ping = [proxy[@"ping"] doubleValue];
	return TGProxyRowStatusText(enabled, enabled ? (pending || !connected) : pending,
			ping, type);
}

NSArray *TGPowerSavingPageModel(BOOL stickersOn, BOOL gifsOn, BOOL wallpaperOn, BOOL vintage) {
	NSMutableArray *rows = [NSMutableArray array];

	// EnergySavingSettingsScreen lists videos, GIFs, stickers, emoji,
	// effects, preload and background work. This app only implements the
	// GIF, sticker and wallpaper switches, so those keep the official
	// relative order. The wallpaper switch is the only door to turning
	// wallpaper rendering off on a slow device.
	NSMutableDictionary *gifs = TGPageRow(@"switchinfo", @"Autoplay GIFs", @"gifs");
	gifs[TGPageModelRowDetail] =
			@"Autoplay and loop GIFs in chats and in the keyboard.";
	gifs[TGPageModelRowIcon] = @"video";
	gifs[TGPageModelRowColour] = @"orchid";
	gifs[TGPageModelRowOn] = @(gifsOn);
	[rows addObject:gifs];
	if (vintage)
		return @[TGPageSection(@"Options", nil, rows)];

	NSMutableDictionary *stickers = TGPageRow(@"switchinfo",
			@"Loop Animated Stickers", @"stickers");
	stickers[TGPageModelRowDetail] =
			@"Animated stickers will play continuously in chats.";
	stickers[TGPageModelRowIcon] = @"sticker";
	stickers[TGPageModelRowColour] = @"green";
	stickers[TGPageModelRowOn] = @(stickersOn);
	[rows addObject:stickers];

	NSMutableDictionary *wallpaper = TGPageRow(@"switchinfo",
			@"Chat Wallpaper", @"wallpaper");
	wallpaper[TGPageModelRowIcon] = @"chat";
	wallpaper[TGPageModelRowColour] = @"sky";
	wallpaper[TGPageModelRowOn] = @(wallpaperOn);
	[rows addObject:wallpaper];

	return @[TGPageSection(@"Options", nil, rows)];
}

NSArray *TGFoldersPageModel(NSArray *folders, NSArray *recommended,
							NSDictionary *chatCounts, BOOL tagsOn, BOOL dev) {
	NSMutableArray *rows = [NSMutableArray array];

	// ChatListFilterPresetListController has one add row, before the list.
	[rows addObject:TGPageRow(@"add", @"Create New Folder", @"createFolder")];

	for (NSUInteger index = 0; index < folders.count; index++){
		NSDictionary *folder = folders[index];
		NSString *title = folder[@"title"];
		if (!title.length)
			continue;
		NSNumber *count = chatCounts[@([folder[@"id"] integerValue])];
		NSString *detail = count ? (count.integerValue ? count.stringValue : @"") : nil;
		NSMutableDictionary *row = TGPageRow(@"disclosure", title, @"openFolder");
		if (detail)
			row[TGPageModelRowDetail] = detail;
		row[TGPageModelRowIcon] = @"folder";
		row[TGPageModelRowColour] = @"cyan";
		row[TGPageModelRowIndex] = @(index);
		[rows addObject:row];
	}

#if TG_DEV
	if (dev)
		[rows addObject:TGPageRow(@"add", @"Add Folder", @"addFolderLink")];
#else
	(void)dev;
#endif

	NSString *folderFooter = folders.count
			? @"Tap 'Edit' to change the order or delete folders." : nil;
	NSMutableArray *sections = [NSMutableArray array];
	// ChatListFilterPresetListController opens with its header item.
	NSMutableDictionary *intro = TGPageRow(@"pageHeader", nil, nil);
	intro[TGPageModelRowDetail] =
			@"Create folders for different groups of chats and quickly switch between them.";
	intro[TGPageModelRowIcon] = @"folder";
	intro[TGPageModelRowColour] = @"cyan";
	[sections addObject:TGPageSection(nil, nil, @[intro])];
	[sections addObject:TGPageSection(@"Folders", folderFooter, rows)];

	if (recommended.count){
		NSMutableArray *suggested = [NSMutableArray array];
		for (NSUInteger index = 0; index < recommended.count; index++){
			NSDictionary *entry = recommended[index];
			NSString *title = entry[@"title"];
			if (!title.length)
				continue;
			NSMutableDictionary *row = TGPageRow(@"disclosure", title,
					@"createRecommended");
			NSString *description = entry[@"description"];
			if (description.length)
				row[TGPageModelRowDetail] = description;
			row[TGPageModelRowIndex] = @(index);
			[suggested addObject:row];
		}
		if (suggested.count)
			[sections addObject:TGPageSection(@"RECOMMENDED FOLDERS", nil,
					suggested)];
	}

	NSMutableDictionary *tags = TGPageRow(@"switch", @"Show Folder Tags",
			@"toggleTags");
	tags[TGPageModelRowOn] = @(tagsOn);
	[sections addObject:TGPageSection(nil, nil, @[tags])];

	return sections;
}

NSArray *TGProxyPageModel(NSArray *proxies, BOOL useProxy, BOOL connected,
						  BOOL dev) {
	NSMutableDictionary *use = TGPageRow(@"switch", @"Use Proxy", @"useProxy");
	use[TGPageModelRowOn] = @(useProxy);

	NSMutableArray *rows = [NSMutableArray array];
	// ProxyListSettingsController puts Add Proxy before the saved servers.
	[rows addObject:TGPageRow(@"add", @"Add Proxy", @"addProxy")];

	NSUInteger index = 0;
	for (NSDictionary *proxy in proxies){
		NSString *server = proxy[@"server"] ?: @"?";
		NSString *name = [NSString stringWithFormat:@"%@:%@", server,
				proxy[@"port"] ?: @0];
		NSMutableDictionary *row = TGPageRow(@"disclosure", name, @"openProxy");
		row[TGPageModelRowDetail] = TGProxyDetail(proxy, connected);
		row[TGPageModelRowIndex] = @(index);
		[rows addObject:row];
		index++;
	}

	(void)dev;
	// The web proxy carrier is a developer console. It lives on the dev
	// settings page, not in the proxy list.
	return @[
		TGPageSection(nil, nil, @[use]),
		TGPageSection(@"Saved Proxies", nil, rows),
	];
}

NSString *TGPageModelCompactBytes(long long bytes) {
	NSString *text = TGBytes(bytes);
	NSRange space = [text rangeOfString:@" "];
	if (space.location == NSNotFound)
		return text;
	NSString *number = [text substringToIndex:space.location];
	NSString *unit = [text substringFromIndex:space.location];
	NSRange separator = [number rangeOfString:@","];
	if (separator.location == NSNotFound)
		separator = [number rangeOfString:@"."];
	if (separator.location != NSNotFound){
		NSMutableString *trimmed = [number mutableCopy];
		while (trimmed.length > separator.location + 1 &&
			   [trimmed hasSuffix:@"0"])
			[trimmed deleteCharactersInRange:
					NSMakeRange(trimmed.length - 1, 1)];
		if ([trimmed hasSuffix:@","] || [trimmed hasSuffix:@"."])
			[trimmed deleteCharactersInRange:
					NSMakeRange(trimmed.length - 1, 1)];
		number = trimmed;
	}
	return [number stringByAppendingString:unit];
}

NSArray *TGSessionsOtherThanCurrent(NSArray *sessions, BOOL unconfirmed,
									BOOL confirmed) {
	NSMutableArray *out = [NSMutableArray array];
	for (NSDictionary *session in sessions){
		if ([session[@"isCurrent"] boolValue])
			continue;
		if ([session[@"isUnconfirmed"] boolValue] ? unconfirmed : confirmed)
			[out addObject:session];
	}
	return out;
}

NSInteger TGFoldersPageFolderIndex(NSInteger section, NSInteger row,
								   NSUInteger folderCount) {
	if (section != TGFoldersPageListSection)
		return -1;
	NSInteger index = row - TGFoldersPageFirstFolderRow;
	return index >= 0 && index < (NSInteger)folderCount ? index : -1;
}

NSInteger TGFoldersPageDropRow(NSInteger proposedSection, NSInteger proposedRow,
							   NSUInteger folderCount) {
	NSInteger first = TGFoldersPageFirstFolderRow;
	NSInteger last = first + (NSInteger)folderCount - 1;
	if (proposedSection < TGFoldersPageListSection)
		return first;
	if (proposedSection > TGFoldersPageListSection)
		return last;
	return MAX(first, MIN(last, proposedRow));
}

NSString *TGFreezeDetail(NSDictionary *state) {
	if (![state isKindOfClass:NSDictionary.class])
		return @"Unknown";
	return [state[@"is_frozen"] boolValue] ? @"Frozen" : @"Not frozen";
}

NSString *TGSubscriptionDetail(NSDictionary *record) {
	if (![record isKindOfClass:NSDictionary.class])
		return @"None";
	if ([record[@"is_payment_failed"] boolValue])
		return @"Payment failed";
	if ([record[@"is_canceled"] boolValue])
		return @"Canceled";
	if ([record[@"is_restored"] boolValue])
		return @"Restored";
	return @"Active";
}

NSString *TGAgeVerificationDetail(NSDictionary *parameters) {
	if (![parameters isKindOfClass:NSDictionary.class])
		return @"Not set";
	NSInteger minAge = [parameters[@"min_age"] integerValue];
	if (minAge <= 0)
		return @"No minimum";
	return [NSString stringWithFormat:@"Age %ld+", (long)minAge];
}

NSString *TGSoundName(NSDictionary *sound) {
	NSString *title = sound[@"title"];
	if (title.length)
		return title;
	return [NSString stringWithFormat:@"Sound %@", sound[@"id"] ?: @(0)];
}

NSString *TGNotificationGroupLabel(NSString *type) {
	if ([type isEqualToString:@"notificationGroupTypeMessages"]) return @"Messages";
	if ([type isEqualToString:@"notificationGroupTypeMentions"]) return @"Mention";
	if ([type isEqualToString:@"notificationGroupTypeSecretChat"]) return @"Secret Chats";
	if ([type isEqualToString:@"notificationGroupTypeCalls"]) return @"Calls";
	return type.length ? type : @"Notifications";
}


NSString *TGPrivacyRuleFooterText(NSString *setting) {
	NSString *english = nil;
	if ([setting isEqualToString:@"ShowStatus"])
		english = @"Unless you are a Premium user, you won't see Last Seen or Online statuses for people with whom you don't share yours. Approximate times will be shown instead (recently, within a week, within a month).";
	else if ([setting isEqualToString:@"ShowProfilePhoto"])
		english = @"You can restrict who can see your profile photo with granular precision.";
	else if ([setting isEqualToString:@"ShowPhoneNumber"])
		english = @"Users who have your number saved in their contacts will also see it on Telegram.";
	else if ([setting isEqualToString:@"AllowChatInvites"])
		english = @"You can restrict who can add you to groups and channels with granular precision.";
	return english ? TGLocalized(english) : nil;
}

BOOL TGPrivacyOffersPublicPhoto(NSString *setting, NSString *ruleType, NSUInteger neverCount) {
	return [setting isEqualToString:@"ShowProfilePhoto"] &&
			(![ruleType isEqualToString:@"everybody"] || neverCount > 0);
}

NSString *TGRecentCallKindKey(BOOL missed, BOOL outgoing) {
	return missed ? @"Missed Call" : (outgoing ? @"Outgoing Call" : @"Incoming Call");
}

NSDictionary *TGRecentCallRowText(NSString *kind, BOOL missed, NSString *when,
		NSString *duration) {
	NSString *subtitle = (!missed && duration.length)
			? [NSString stringWithFormat:@"%@ (%@)", kind, duration] : kind;
	return @{@"subtitle" : subtitle ?: @"", @"trailing" : when ?: @""};
}
