// TGSettingsStoreTests.m - the request shapes the settings pages send.
//
// The store owns every TDLib object a settings row writes, so these tests read
// the outbox and assert the @type and the fields, not just that a call ran.
// Requests that carry @extra are answered the way tdjson answers them, which
// is what lets the read-then-write flows (notification scopes, privacy rules)
// reach their second request.
#import "TGTestRunner.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGSettingsStore.h"
#import "TGAccountStore.h"
#import "TGSessionsStore.h"
#import "TGTextStylesStore.h"

@interface TGSettingsStoreTests : XCTestCase
@end

static TGClient *TGSTClient(void) {
	TGClient *c = TGClient.shared;
	[c.outbox removeAllObjects];
	[c.pendingRequests removeAllObjects];
	return c;
}

static NSDictionary *TGSTDecode(NSData *data) {
	NSString *json = [[NSString alloc] initWithData:data
										   encoding:NSUTF8StringEncoding];
	NSString *trimmed = [json componentsSeparatedByString:@"\0"][0];
	return [NSJSONSerialization JSONObjectWithData:
			[trimmed dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
}

/// The last request of a type, or nil. Every request in the outbox is decoded
/// fresh; the store never reuses a buffer.
static NSDictionary *TGSTRequest(TGClient *c, NSString *type) {
	NSDictionary *found = nil;
	for (NSData *data in c.outbox){
		NSDictionary *request = TGSTDecode(data);
		if (![request[@"@type"] isEqualToString:type])
			continue;
		found = request;
	}
	return found;
}

/// Answers the last request that carried @extra, the way tdjson's result does.
static void TGSTAnswer(TGClient *c, NSDictionary *answer) {
	NSDictionary *sent = nil;
	for (NSData *data in c.outbox){
		NSDictionary *request = TGSTDecode(data);
		if (request[@"@extra"])
			sent = request;
	}
	if (!sent)
		return;
	NSMutableDictionary *reply = [answer mutableCopy];
	reply[@"@extra"] = sent[@"@extra"];
	[c handleUpdate:reply];
}

@implementation TGSettingsStoreTests

- (void)setUp {
	[super setUp];
	TGSTClient();
}

#pragma mark - options

- (void)testOptionReadAndWrite {
	TGClient *c = TGSTClient();
	[[TGSettingsStore shared] optionValue:@"disable_top_chats" completion:nil];
	NSDictionary *read = TGSTRequest(c, @"getOption");
	XCTAssertEqualObjects(read[@"name"], @"disable_top_chats");

	[[TGSettingsStore shared] setOption:@"disable_top_chats" boolValue:YES];
	NSDictionary *write = TGSTRequest(c, @"setOption");
	XCTAssertEqualObjects(write[@"name"], @"disable_top_chats");
	XCTAssertEqualObjects(write[@"value"][@"@type"], @"optionValueBoolean");
	XCTAssertTrue([write[@"value"][@"value"] boolValue]);
}

#pragma mark - autosave

- (void)testAutosaveScopeShape {
	TGClient *c = TGSTClient();
	[[TGSettingsStore shared] setAutosaveSettingsForScope:@"private"
												   photos:YES
												   videos:NO
											 maxVideoSize:1234
											   completion:nil];
	NSDictionary *request = TGSTRequest(c, @"setAutosaveSettings");
	XCTAssertEqualObjects(request[@"scope"][@"@type"],
						  @"autosaveSettingsScopePrivateChats");
	XCTAssertTrue([request[@"settings"][@"autosave_photos"] boolValue]);
	XCTAssertFalse([request[@"settings"][@"autosave_videos"] boolValue]);
	XCTAssertEqual([request[@"settings"][@"max_video_file_size"] longLongValue],
				   1234LL);
	XCTAssertEqualObjects(request[@"settings"][@"@type"],
						  @"scopeAutosaveSettings");

	[[TGSettingsStore shared] clearAutosaveSettingsExceptionsWithCompletion:nil];
	XCTAssertNotNil(TGSTRequest(c, @"clearAutosaveSettingsExceptions"));
}

#pragma mark - notification scopes

- (void)testMutedScopeReadsThenWrites {
	TGClient *c = TGSTClient();
	[[TGSettingsStore shared] setScope:@"groups" muted:YES];

	NSDictionary *read = TGSTRequest(c, @"getScopeNotificationSettings");
	XCTAssertEqualObjects(read[@"scope"][@"@type"],
						  @"notificationSettingsScopeGroupChats");
	TGSTAnswer(c, @{
		@"@type" : @"scopeNotificationSettings",
		@"mute_for" : @0,
		@"show_preview" : @YES,
	});

	NSDictionary *write = TGSTRequest(c, @"setScopeNotificationSettings");
	XCTAssertNotNil(write, "the scope write must follow the read");
	XCTAssertEqualObjects(write[@"scope"][@"@type"],
						  @"notificationSettingsScopeGroupChats");
	XCTAssertEqual([write[@"notification_settings"][@"mute_for"] longLongValue],
				   365LL * 24 * 3600);
}

- (void)testNotificationPreviewSwitch {
	TGClient *c = TGSTClient();
	[[TGSettingsStore shared] setScope:@"channels" showPreview:NO];
	TGSTAnswer(c, @{@"@type" : @"scopeNotificationSettings",
					@"show_preview" : @YES});
	NSDictionary *write = TGSTRequest(c, @"setScopeNotificationSettings");
	XCTAssertFalse([write[@"notification_settings"][@"show_preview"] boolValue]);
	XCTAssertEqualObjects(write[@"scope"][@"@type"],
						  @"notificationSettingsScopeChannelChats");
}

#pragma mark - privacy

- (void)testPrivacyRuleKeepsExceptions {
	TGClient *c = TGSTClient();
	[[TGSettingsStore shared] setPrivacyRule:@"ShowPhoneNumber" to:@"contacts"
								  completion:nil];

	NSDictionary *read = TGSTRequest(c, @"getUserPrivacySettingRules");
	XCTAssertEqualObjects(read[@"setting"][@"@type"],
						  @"userPrivacySettingShowPhoneNumber");
	TGSTAnswer(c, @{
		@"@type" : @"userPrivacySettingRules",
		@"rules" : @[@{@"@type" : @"userPrivacySettingRuleAllowUsers",
					   @"user_ids" : @[@42]}],
	});

	NSDictionary *write = TGSTRequest(c, @"setUserPrivacySettingRules");
	XCTAssertEqualObjects(write[@"setting"][@"@type"],
						  @"userPrivacySettingShowPhoneNumber");
	XCTAssertEqualObjects(write[@"rules"][@"@type"], @"userPrivacySettingRules");
	NSArray *rules = write[@"rules"][@"rules"];
	XCTAssertEqual(rules.count, (NSUInteger)2);
	XCTAssertEqualObjects(rules.firstObject[@"@type"],
						  @"userPrivacySettingRuleAllowUsers");
	XCTAssertEqualObjects(rules.lastObject[@"@type"],
						  @"userPrivacySettingRuleAllowContacts");
}

#pragma mark - sessions

- (void)testSessionListShape {
	TGClient *c = TGSTClient();
	__block NSUInteger rows = 0;
	__block NSInteger ttl = 0;
	[[TGSessionsStore shared] sessionsWithInactiveTtlCompletion:
			^(NSArray *sessions, NSInteger days){
		rows = sessions.count;
		ttl = days;
	}];
	XCTAssertNotNil(TGSTRequest(c, @"getActiveSessions"));
	TGSTAnswer(c, @{
		@"@type" : @"activeSessions",
		@"inactive_session_ttl_days" : @30,
		@"sessions" : @[@{
			@"id" : @7,
			@"application_name" : @"LegacyTG",
			@"platform" : @"iOS",
			@"is_current" : @YES,
		}],
	});
	XCTAssertEqual(rows, (NSUInteger)1);
	XCTAssertEqual(ttl, 30);
}

- (void)testSessionActions {
	TGClient *c = TGSTClient();
	[[TGSessionsStore shared] terminateSession:7];
	NSDictionary *terminate = TGSTRequest(c, @"terminateSession");
	XCTAssertEqual([terminate[@"session_id"] longLongValue], 7LL);

	[[TGSessionsStore shared] toggleSession:7 canAcceptSecretChats:NO];
	NSDictionary *secret = TGSTRequest(c, @"toggleSessionCanAcceptSecretChats");
	XCTAssertEqual([secret[@"session_id"] longLongValue], 7LL);
	XCTAssertFalse([secret[@"can_accept_secret_chats"] boolValue]);

	[[TGSessionsStore shared] terminateAllOtherSessions:nil];
	XCTAssertNotNil(TGSTRequest(c, @"terminateAllOtherSessions"));
}

- (void)testSessionIdleTimeout {
	TGClient *c = TGSTClient();
	[[TGSessionsStore shared] setInactiveSessionTtlDays:45 completion:nil];
	NSDictionary *request = TGSTRequest(c, @"setInactiveSessionTtl");
	XCTAssertEqual([request[@"inactive_session_ttl_days"] integerValue], 45);
}

#pragma mark - language

- (void)testLanguagePackInfoShape {
	TGClient *c = TGSTClient();
	[[TGSettingsStore shared] languagePackInfo:@"fr" completion:nil];
	NSDictionary *request = TGSTRequest(c, @"getLanguagePackInfo");
	XCTAssertEqualObjects(request[@"language_pack_id"], @"fr");
}

#pragma mark - proxy

- (void)testAddProxyShape {
	TGClient *c = TGSTClient();
	[[TGSettingsStore shared] addProxyAtServer:@"1.2.3.4"
										 port:1080
										 kind:@"socks5"
									 username:@"u"
									 password:@"p"
									   secret:@""
									   enable:YES
								   completion:nil];
	NSDictionary *request = TGSTRequest(c, @"addProxy");
	XCTAssertNotNil(request);
	XCTAssertEqualObjects(request[@"proxy"][@"server"], @"1.2.3.4");
	XCTAssertEqual([request[@"proxy"][@"port"] integerValue], 1080);
	XCTAssertTrue([request[@"enable"] boolValue]);
	XCTAssertEqualObjects(request[@"proxy"][@"@type"], @"proxy");
}

#pragma mark - storage

- (void)testStorageRequests {
	TGClient *c = TGSTClient();
	[[TGSettingsStore shared] storageStatsWithCompletion:nil];
	XCTAssertNotNil(TGSTRequest(c, @"getStorageStatisticsFast"));

	[[TGSettingsStore shared] clearCacheOfTypes:@[@"fileTypePhoto"] completion:nil];
	NSDictionary *optimize = TGSTRequest(c, @"optimizeStorage");
	NSArray *types = optimize[@"file_types"];
	XCTAssertEqualObjects(types.firstObject[@"@type"], @"fileTypePhoto");
	XCTAssertEqual([optimize[@"size"] longLongValue], -1LL);
}

#pragma mark - folders

- (void)testFolderRequests {
	TGClient *c = TGSTClient();
	[[TGSettingsStore shared] createFolderNamed:@"News" icon:@"newspaper"
									  withChats:@[@11] completion:nil];
	NSDictionary *create = TGSTRequest(c, @"createChatFolder");
	XCTAssertEqualObjects(create[@"folder"][@"name"][@"text"][@"text"], @"News");

	[[TGSettingsStore shared] deleteFolder:5 leavingChats:@[@11]];
	NSDictionary *remove = TGSTRequest(c, @"deleteChatFolder");
	XCTAssertEqual([remove[@"chat_folder_id"] integerValue], 5);
	XCTAssertEqualObjects(remove[@"leave_chat_ids"], (@[@11]));

	[[TGSettingsStore shared] reorderFolderIds:@[@5, @6] mainListAt:1];
	NSDictionary *order = TGSTRequest(c, @"reorderChatFolders");
	XCTAssertEqualObjects(order[@"chat_folder_ids"], (@[@5, @6]));
	XCTAssertEqual([order[@"main_chat_list_position"] integerValue], 1);
}

#pragma mark - tools

- (void)testFolderChatCountShape {
	TGClient *c = TGSTClient();
	NSDictionary *folder = @{@"id" : @5, @"title" : @"News"};
	[[TGSettingsStore shared] chatCountForFolder:folder completion:nil];
	NSDictionary *request = TGSTRequest(c, @"getChatFolderChatCount");
	XCTAssertEqualObjects(request[@"folder"][@"@type"], @"chatFolder");
	XCTAssertEqual([request[@"folder"][@"id"] integerValue], 5);
}

#pragma mark - text styles

- (void)testCreateTextStyleShape {
	TGClient *c = TGSTClient();
	[[TGTextStylesStore shared] createTextCompositionStyle:@"Shout"
												  emojiId:99
												   prompt:@"loud"
											  showCreator:YES
											   completion:nil];
	NSDictionary *request = TGSTRequest(c, @"createTextCompositionStyle");
	XCTAssertEqualObjects(request[@"title"], @"Shout");
	XCTAssertEqual([request[@"custom_emoji_id"] longLongValue], 99LL);
	XCTAssertEqualObjects(request[@"prompt"], @"loud");
	XCTAssertTrue([request[@"show_creator"] boolValue]);
}

#pragma mark - the account

- (void)testAccountPasswordAndLogout {
	TGClient *c = TGSTClient();
	[[TGAccountStore shared] hasPasswordWithCompletion:nil];
	XCTAssertNotNil(TGSTRequest(c, @"getPasswordState"));

	[[TGAccountStore shared] logOut];
	XCTAssertNotNil(TGSTRequest(c, @"logOut"));

	[[TGAccountStore shared] setUsername:@"legacy" completion:nil];
	NSDictionary *username = TGSTRequest(c, @"setUsername");
	XCTAssertEqualObjects(username[@"username"], @"legacy");
}

- (void)testAccountWebsitesAndSupport {
	TGClient *c = TGSTClient();
	[[TGAccountStore shared] connectedWebsitesWithCompletion:nil];
	XCTAssertNotNil(TGSTRequest(c, @"getConnectedWebsites"));

	[[TGAccountStore shared] disconnectWebsite:12 completion:nil];
	NSDictionary *website = TGSTRequest(c, @"disconnectWebsite");
	XCTAssertEqual([website[@"website_id"] integerValue], 12);

	[[TGAccountStore shared] supportNameWithCompletion:nil];
	XCTAssertNotNil(TGSTRequest(c, @"getSupportName"));
}

#pragma mark - system notifications

- (void)testNotificationGroupsAndSounds {
	TGClient *c = TGSTClient();
	[[TGSettingsStore shared] savedNotificationSoundsWithCompletion:nil];
	XCTAssertNotNil(TGSTRequest(c, @"getSavedNotificationSounds"));

	[[TGSettingsStore shared] removeNotification:8 inGroup:4 completion:nil];
	NSDictionary *remove = TGSTRequest(c, @"removeNotification");
	XCTAssertEqual([remove[@"notification_id"] integerValue], 8);
	XCTAssertEqual([remove[@"notification_group_id"] integerValue], 4);
}

@end
