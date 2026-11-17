#import "TGInternalLinkRoute.h"

static NSString *TGLinkString(NSDictionary *type, NSString *key) {
	id value = type[key];
	return [value isKindOfClass:NSString.class] ? value : @"";
}

/// settingsSection* to the page official opens for it (TelegramUI
/// OpenResolvedUrl.swift, .settings(section)); the chat maps the name to its
/// own page. A section this client has no page for opens Settings itself.
static NSString *TGLinkSettingsPage(NSDictionary *section) {
	NSString *kind = [section isKindOfClass:NSDictionary.class] ? section[@"@type"] : nil;
	if (![kind isKindOfClass:NSString.class])
		return @"root";
	NSDictionary *pages = @{
		@"settingsSectionAppearance"         : @"appearance",
		@"settingsSectionChatFolders"        : @"folders",
		@"settingsSectionDataAndStorage"     : @"data",
		@"settingsSectionLanguage"           : @"language",
		@"settingsSectionNotifications"      : @"notifications",
		@"settingsSectionPowerSaving"        : @"powerSaving",
		@"settingsSectionPrivacyAndSecurity" : @"privacy",
		@"settingsSectionDevices"            : @"sessions",
		@"settingsSectionEditProfile"        : @"editProfile",
	};
	return pages[kind] ?: @"root";
}

/// The page a subsection opens when this client has one (official resolves
/// "<section>/<subsection>" in handleSettingsPathUrl and opens that item's
/// screen). Rows of a page - toggles, "edit", a reset - open the section page,
/// which is where official focuses them. The privacy rules carry their key.
static NSDictionary *TGLinkSettingsSubpage(NSString *page, NSString *subsection) {
	NSString *head = [[subsection componentsSeparatedByString:@"/"] firstObject];
	if (!head.length)
		return nil;
	NSDictionary *byPage = @{
		@"privacy" : @{
			@"blocked"  : @{@"page" : @"blocked"},
			@"passcode" : @{@"page" : @"passcode"},
			@"last-seen"      : @{@"page" : @"privacyRule", @"rule" : @"ShowStatus"},
			@"profile-photos" : @{@"page" : @"privacyRule", @"rule" : @"ShowProfilePhoto"},
			@"phone-number"   : @{@"page" : @"privacyRule", @"rule" : @"ShowPhoneNumber"},
			@"birthday"       : @{@"page" : @"privacyRule", @"rule" : @"ShowBirthdate"},
			@"calls"          : @{@"page" : @"privacyRule", @"rule" : @"AllowCalls"},
			@"invites"        : @{@"page" : @"privacyRule", @"rule" : @"AllowChatInvites"},
			@"forwards"       : @{@"page" : @"privacyRule", @"rule" : @"ShowLinkInForwardedMessages"},
		},
		@"data" : @{
			@"proxy"          : @{@"page" : @"proxy"},
			@"save-to-photos" : @{@"page" : @"autosave"},
			@"storage"        : @{@"page" : @"storage"},
		},
		@"appearance" : @{
			@"wallpapers"      : @{@"page" : @"wallpaper"},
			@"night-mode"      : @{@"page" : @"autoNight"},
			@"auto-night-mode" : @{@"page" : @"autoNight"},
		},
	};
	return byPage[page][head];
}

NSDictionary *TGInternalLinkRoute(NSDictionary *type) {
	if (![type isKindOfClass:NSDictionary.class])
		return nil;
	NSString *kind = TGLinkString(type, @"@type");

	if ([kind isEqualToString:@"internalLinkTypeInstantView"]) {
		NSString *url = TGLinkString(type, @"url");
		if (!url.length)
			return nil;
		return @{@"route" : @"instantView", @"url" : url,
				 @"fallback" : TGLinkString(type, @"fallback_url")};
	}
	if ([kind isEqualToString:@"internalLinkTypeStory"]) {
		NSString *username = TGLinkString(type, @"story_poster_username");
		int64_t storyId = [type[@"story_id"] longLongValue];
		if (!username.length || !storyId)
			return nil;
		return @{@"route" : @"story", @"username" : username, @"storyId" : @(storyId)};
	}
	// A live story link names only the poster: their current stories open,
	// the live one among them.
	if ([kind isEqualToString:@"internalLinkTypeLiveStory"]) {
		NSString *username = TGLinkString(type, @"story_poster_username");
		return username.length ? @{@"route" : @"story", @"username" : username, @"storyId" : @0} : nil;
	}
	if ([kind isEqualToString:@"internalLinkTypeDirectMessagesChat"]) {
		NSString *username = TGLinkString(type, @"channel_username");
		return username.length ? @{@"route" : @"directMessages", @"username" : username} : nil;
	}
	if ([kind isEqualToString:@"internalLinkTypeSettings"]) {
		NSDictionary *section = [type[@"section"] isKindOfClass:NSDictionary.class]
				? type[@"section"] : nil;
		NSString *page = TGLinkSettingsPage(section);
		NSDictionary *sub = TGLinkSettingsSubpage(page, TGLinkString(section, @"subsection"));
		if (sub) {
			NSMutableDictionary *route = [sub mutableCopy];
			route[@"route"] = @"settings";
			return route;
		}
		return @{@"route" : @"settings", @"page" : page};
	}
	if ([kind isEqualToString:@"internalLinkTypeCallsPage"])
		return @{@"route" : @"tab", @"name" : @"calls"};
	// "new" is official's Add Contact form (OpenResolvedUrl.swift, .contacts(.new)).
	if ([kind isEqualToString:@"internalLinkTypeContactsPage"])
		return @{@"route" : @"tab", @"name" : @"contacts",
				 @"section" : TGLinkString(type, @"section")};
	if ([kind isEqualToString:@"internalLinkTypeMyProfilePage"])
		return @{@"route" : @"tab", @"name" : @"profile"};
	return nil;
}
