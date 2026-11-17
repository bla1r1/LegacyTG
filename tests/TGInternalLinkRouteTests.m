// TGInternalLinkRouteTests.m - where an in-app link opens, from TDLib's
// InternalLinkType (official TelegramUI OpenResolvedUrl.swift).
#import "TGTestRunner.h"
#import "TGInternalLinkRoute.h"

@interface TGInternalLinkRouteTests : XCTestCase @end

@implementation TGInternalLinkRouteTests

- (void)testInstantView_CarriesTheFallback {
	NSDictionary *route = TGInternalLinkRoute(@{ @"@type" : @"internalLinkTypeInstantView",
			@"url" : @"https://t.me/iv?url=x", @"fallback_url" : @"https://example.com/x" });
	XCTAssertEqualObjects(route[@"route"], @"instantView");
	XCTAssertEqualObjects(route[@"fallback"], @"https://example.com/x");
}

- (void)testStory_PosterAndId {
	NSDictionary *route = TGInternalLinkRoute(@{ @"@type" : @"internalLinkTypeStory",
			@"story_poster_username" : @"durov", @"story_id" : @(12) });
	XCTAssertEqualObjects(route[@"route"], @"story");
	XCTAssertEqualObjects(route[@"username"], @"durov");
	XCTAssertEqualObjects(route[@"storyId"], @12);
	XCTAssertNil(TGInternalLinkRoute(@{ @"@type" : @"internalLinkTypeStory",
			@"story_poster_username" : @"durov", @"story_id" : @(0) }));
}

- (void)testLiveStory_OpensThePostersStories {
	NSDictionary *route = TGInternalLinkRoute(@{ @"@type" : @"internalLinkTypeLiveStory",
			@"story_poster_username" : @"news" });
	XCTAssertEqualObjects(route[@"route"], @"story");
	XCTAssertEqualObjects(route[@"storyId"], @0);
}

- (void)testDirectMessages_ChannelUsername {
	NSDictionary *route = TGInternalLinkRoute(@{ @"@type" : @"internalLinkTypeDirectMessagesChat",
			@"channel_username" : @"shop" });
	XCTAssertEqualObjects(route[@"route"], @"directMessages");
	XCTAssertEqualObjects(route[@"username"], @"shop");
}

- (void)testSettings_SectionToPage {
	NSDictionary *privacy = TGInternalLinkRoute(@{ @"@type" : @"internalLinkTypeSettings",
			@"section" : @{ @"@type" : @"settingsSectionPrivacyAndSecurity", @"subsection" : @"" } });
	XCTAssertEqualObjects(privacy[@"page"], @"privacy");
	NSDictionary *devices = TGInternalLinkRoute(@{ @"@type" : @"internalLinkTypeSettings",
			@"section" : @{ @"@type" : @"settingsSectionDevices", @"subsection" : @"" } });
	XCTAssertEqualObjects(devices[@"page"], @"sessions");
	NSDictionary *premium = TGInternalLinkRoute(@{ @"@type" : @"internalLinkTypeSettings",
			@"section" : @{ @"@type" : @"settingsSectionPremium" } });
	XCTAssertEqualObjects(premium[@"page"], @"root");
}

- (void)testPages_ContactsCallsProfile {
	NSDictionary *contacts = TGInternalLinkRoute(@{ @"@type" : @"internalLinkTypeContactsPage",
			@"section" : @"new" });
	XCTAssertEqualObjects(contacts[@"name"], @"contacts");
	XCTAssertEqualObjects(contacts[@"section"], @"new");
	XCTAssertEqualObjects(TGInternalLinkRoute(@{ @"@type" : @"internalLinkTypeCallsPage",
			@"section" : @"" })[@"name"], @"calls");
	XCTAssertEqualObjects(TGInternalLinkRoute(@{ @"@type" : @"internalLinkTypeMyProfilePage",
			@"section" : @"" })[@"name"], @"profile");
}

- (void)testOtherTypesKeepTheOldPath {
	XCTAssertNil(TGInternalLinkRoute(@{ @"@type" : @"internalLinkTypePublicChat", @"chat_username" : @"x" }));
	XCTAssertNil(TGInternalLinkRoute(nil));
}

/// A subsection with its own page opens it (official handleSettingsPathUrl);
/// a row of a page opens the page.
- (void)testSettings_SubsectionToItsPage {
	NSDictionary *(^route)(NSString *, NSString *) = ^(NSString *section, NSString *sub){
		return TGInternalLinkRoute(@{@"@type" : @"internalLinkTypeSettings",
				@"section" : @{@"@type" : section, @"subsection" : sub}});
	};
	XCTAssertEqualObjects(route(@"settingsSectionPrivacyAndSecurity", @"blocked/edit")[@"page"], @"blocked");
	NSDictionary *rule = route(@"settingsSectionPrivacyAndSecurity", @"last-seen/never");
	XCTAssertEqualObjects(rule[@"page"], @"privacyRule");
	XCTAssertEqualObjects(rule[@"rule"], @"ShowStatus");
	XCTAssertEqualObjects(route(@"settingsSectionPrivacyAndSecurity", @"2sv")[@"page"], @"privacy");
	XCTAssertEqualObjects(route(@"settingsSectionDataAndStorage", @"proxy/add-proxy")[@"page"], @"proxy");
	XCTAssertEqualObjects(route(@"settingsSectionDataAndStorage", @"storage")[@"page"], @"storage");
	XCTAssertEqualObjects(route(@"settingsSectionDataAndStorage", @"save-to-photos/chats")[@"page"], @"autosave");
	XCTAssertEqualObjects(route(@"settingsSectionAppearance", @"wallpapers/set")[@"page"], @"wallpaper");
	XCTAssertEqualObjects(route(@"settingsSectionAppearance", @"auto-night-mode")[@"page"], @"autoNight");
	XCTAssertEqualObjects(route(@"settingsSectionNotifications", @"in-app-sounds")[@"page"], @"notifications");
	XCTAssertEqualObjects(route(@"settingsSectionDevices", @"terminate-sessions")[@"page"], @"sessions");
	XCTAssertEqualObjects(route(@"settingsSectionAppearance", @"")[@"page"], @"appearance");
}

@end
