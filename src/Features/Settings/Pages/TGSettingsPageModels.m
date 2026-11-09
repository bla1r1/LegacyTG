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

NSArray *TGPowerSavingPageModel(BOOL stickersOn, BOOL gifsOn, BOOL wallpaperOn) {
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
	[rows addObject:TGPageRow(@"action", @"Create New Folder", @"createFolder")];

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
		[rows addObject:TGPageRow(@"action", @"Add Folder", @"addFolderLink")];
#else
	(void)dev;
#endif

	NSString *folderFooter = folders.count
			? @"Tap 'Edit' to change the order or delete folders." : nil;
	NSMutableArray *sections = [NSMutableArray array];
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
	[rows addObject:TGPageRow(@"action", @"Add Proxy", @"addProxy")];

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
