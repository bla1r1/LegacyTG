// TGServiceMessageTextTests.m — the sentence each service bubble shows.
//
// TDLib sends one content type per action, and the chat has to turn it into
// a sentence without ever naming the type or an id. These tests pin the
// wording for every type the app handles, including the ones that only
// differ by a currency or a singular noun.
#import "TGTestRunner.h"
#import "TGServiceMessageText.h"

@interface TGServiceMessageTextTests : XCTestCase @end

static TGServiceUserName svcUsers(void) {
	return ^NSString *(int64_t userId) {
		if (userId == 1001) return @"Alice";
		if (userId == 1002) return @"Bob";
		if (userId == 1003) return @"Carol";
		if (userId == 1004) return @"Dave";
		if (userId == 5368324170671202286LL) return @"Eve";
		return nil;
	};
}

static TGServiceChatTitle svcChats(void) {
	return ^NSString *(int64_t chatId) {
		if (chatId == 2001) return @"News";
		if (chatId == 2002) return @"Design";
		return nil;
	};
}

static NSDictionary *svcMessage(NSDictionary *content) {
	return @{
		@"@type"          : @"message",
		@"id"             : @(1),
		@"date"           : @(1700000000),
		@"is_outgoing"    : @NO,
		@"is_channel_post": @NO,
		@"sender_id"      : @{@"@type" : @"messageSenderUser", @"user_id" : @(1001)},
		@"content"        : content,
	};
}

static NSString *svcSentence(NSDictionary *content) {
	return TGServiceMessageText(svcMessage(content), svcUsers(), svcChats());
}

static NSDictionary *svcFormatted(NSString *text) {
	return @{@"@type" : @"formattedText", @"text" : text ?: @""};
}

static NSDictionary *svcSenderUser(int64_t userId) {
	return @{@"@type" : @"messageSenderUser", @"user_id" : @(userId)};
}

@implementation TGServiceMessageTextTests

#pragma mark - chats and members

- (void)testBasicGroupChatCreate {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageBasicGroupChatCreate",
		@"title" : @"News",
		@"member_user_ids" : @[@(1001), @(1002)],
	}), @"Alice created the group \"News\"");
}

- (void)testSupergroupChatCreate {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageSupergroupChatCreate",
		@"title" : @"News",
	}), @"Alice created the group \"News\"");
}

- (void)testChatChangeTitle {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageChatChangeTitle",
		@"title" : @"News",
	}), @"Alice changed the group name to \"News\"");
}

- (void)testChatChangePhoto {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageChatChangePhoto",
		@"photo" : @{@"@type" : @"chatPhoto", @"id" : @(9)},
	}), @"Alice changed the group photo");
}

- (void)testChatDeletePhoto {
	XCTAssertEqualObjects(svcSentence(@{@"@type" : @"messageChatDeletePhoto"}),
			@"Alice removed the group photo");
}

- (void)testChatAddMembers {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageChatAddMembers",
		@"member_user_ids" : @[@(1002), @(1003)],
	}), @"Alice added Bob and Carol");
}

- (void)testChatAddThreeMembers {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageChatAddMembers",
		@"member_user_ids" : @[@(1002), @(1003), @(1004)],
	}), @"Alice added Bob, Carol and Dave");
}

- (void)testChatJoinByLink {
	XCTAssertEqualObjects(svcSentence(@{@"@type" : @"messageChatJoinByLink"}),
			@"Alice joined the group via invite link");
}

- (void)testChatJoinByRequest {
	XCTAssertEqualObjects(svcSentence(@{@"@type" : @"messageChatJoinByRequest"}),
			@"Alice was accepted to the group");
}

- (void)testChatDeleteMember {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageChatDeleteMember",
		@"user_id" : @(1002),
	}), @"Alice removed Bob");
}

- (void)testChatDeleteMemberSelfLeaves {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageChatDeleteMember",
		@"user_id" : @(1001),
	}), @"Alice left the group");
}

- (void)testChatUpgradeTo {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageChatUpgradeTo",
		@"supergroup_id" : @(3001),
	}), @"This group was upgraded to a supergroup");
}

- (void)testChatUpgradeFrom {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageChatUpgradeFrom",
		@"title" : @"News",
		@"basic_group_id" : @(3001),
	}), @"Alice created the supergroup \"News\"");
}

- (void)testPinMessage {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messagePinMessage",
		@"message_id" : @(42),
	}), @"Alice pinned a message");
}

- (void)testScreenshotTaken {
	XCTAssertEqualObjects(svcSentence(@{@"@type" : @"messageScreenshotTaken"}),
			@"Alice took a screenshot");
}

- (void)testChatSetBackground {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageChatSetBackground",
		@"old_background_message_id" : @(0),
		@"background" : @{@"@type" : @"chatBackground"},
		@"only_for_self" : @NO,
	}), @"Alice set a new chat background");
}

- (void)testChatSetTheme {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageChatSetTheme",
		@"theme" : @{@"@type" : @"chatThemeEmoji", @"name" : @"Cat"},
	}), @"Alice changed the chat theme");
}

- (void)testChatSetThemeReset {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageChatSetTheme",
		@"theme" : [NSNull null],
	}), @"Alice reset the chat theme");
}

- (void)testChatSetMessageAutoDeleteTime {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageChatSetMessageAutoDeleteTime",
		@"message_auto_delete_time" : @(86400),
		@"from_user_id" : @(0),
	}), @"Alice set messages to auto-delete in 1 day");
}

- (void)testAutoDeleteWeek {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageChatSetMessageAutoDeleteTime",
		@"message_auto_delete_time" : @(604800),
		@"from_user_id" : @(0),
	}), @"Alice set messages to auto-delete in 1 week");
}

- (void)testAutoDeleteMonth {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageChatSetMessageAutoDeleteTime",
		@"message_auto_delete_time" : @(2592000),
		@"from_user_id" : @(0),
	}), @"Alice set messages to auto-delete in 1 month");
}

- (void)testAutoDeleteOff {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageChatSetMessageAutoDeleteTime",
		@"message_auto_delete_time" : @(0),
		@"from_user_id" : @(0),
	}), @"Alice turned off auto-delete");
}

- (void)testChatBoost {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageChatBoost",
		@"boost_count" : @(2),
	}), @"Alice boosted the group 2 times");
}

#pragma mark - topics

- (void)testForumTopicCreated {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageForumTopicCreated",
		@"name" : @"News",
		@"is_name_implicit" : @NO,
		@"icon" : @{@"@type" : @"forumTopicIcon",
					@"color" : @(0), @"custom_emoji_id" : @(0)},
	}), @"Alice created the topic \"News\"");
}

- (void)testForumTopicEdited {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageForumTopicEdited",
		@"name" : @"Updates",
		@"edit_icon_custom_emoji_id" : @NO,
		@"icon_custom_emoji_id" : @(0),
	}), @"Alice renamed the topic to \"Updates\"");
}

- (void)testForumTopicIconEdited {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageForumTopicEdited",
		@"name" : @"",
		@"edit_icon_custom_emoji_id" : @YES,
		@"icon_custom_emoji_id" : @(5368324170671202286LL),
	}), @"Alice changed the topic icon");
}

- (void)testForumTopicClosed {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageForumTopicIsClosedToggled",
		@"is_closed" : @YES,
	}), @"Alice closed the topic");
}

- (void)testForumTopicReopened {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageForumTopicIsClosedToggled",
		@"is_closed" : @NO,
	}), @"Alice reopened the topic");
}

- (void)testForumTopicHidden {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageForumTopicIsHiddenToggled",
		@"is_hidden" : @YES,
	}), @"Alice hid the topic");
}

- (void)testForumTopicShown {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageForumTopicIsHiddenToggled",
		@"is_hidden" : @NO,
	}), @"Alice showed the topic");
}

#pragma mark - suggestions and custom actions

- (void)testSuggestProfilePhoto {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageSuggestProfilePhoto",
		@"photo" : @{@"@type" : @"chatPhoto", @"id" : @(9)},
	}), @"Alice suggested a new profile photo");
}

- (void)testSuggestBirthdate {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageSuggestBirthdate",
		@"birthdate" : @{@"@type" : @"birthdate",
						 @"day" : @(1), @"month" : @(1), @"year" : @(1990)},
	}), @"Alice suggested a birthdate");
}

- (void)testCustomServiceAction {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageCustomServiceAction",
		@"text" : @"Alice did something",
	}), @"Alice did something");
}

- (void)testGameScore {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageGameScore",
		@"game_message_id" : @(42),
		@"game_id" : @(7),
		@"score" : @(100),
	}), @"Alice scored 100 in a game");
}

#pragma mark - money and gifts

- (void)testPaymentSuccessful {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messagePaymentSuccessful",
		@"invoice_chat_id" : @(2001),
		@"invoice_message_id" : @(42),
		@"currency" : @"USD",
		@"total_amount" : @(499),
		@"subscription_until_date" : @(0),
		@"is_recurring" : @NO,
		@"is_first_recurring" : @NO,
		@"invoice_name" : @"Pro",
	}), @"Alice paid $4.99 for \"Pro\"");
}

- (void)testPaymentSuccessfulBotEuro {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messagePaymentSuccessfulBot",
		@"currency" : @"EUR",
		@"total_amount" : @(499),
		@"subscription_until_date" : @(0),
		@"is_recurring" : @NO,
		@"is_first_recurring" : @NO,
		@"invoice_payload" : @"payload",
		@"shipping_option_id" : @"",
		@"order_info" : [NSNull null],
		@"telegram_payment_charge_id" : @"tg",
		@"provider_payment_charge_id" : @"provider",
	}), @"Alice paid \u20ac4.99");
}

- (void)testPaymentOtherCurrency {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messagePaymentSuccessfulBot",
		@"currency" : @"GBP",
		@"total_amount" : @(1234),
	}), @"Alice paid 12.34 GBP");
}

- (void)testPaymentRefunded {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messagePaymentRefunded",
		@"owner_id" : svcSenderUser(1001),
		@"currency" : @"USD",
		@"total_amount" : @(499),
		@"invoice_payload" : @"payload",
		@"telegram_payment_charge_id" : @"tg",
		@"provider_payment_charge_id" : @"provider",
	}), @"Alice received a refund of $4.99");
}

- (void)testGiftedPremium {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageGiftedPremium",
		@"gifter_user_id" : @(1001),
		@"receiver_user_id" : @(1002),
		@"text" : svcFormatted(@""),
		@"currency" : @"USD",
		@"amount" : @(499),
		@"cryptocurrency" : @"",
		@"cryptocurrency_amount" : @(0),
		@"month_count" : @(3),
		@"day_count" : @(0),
		@"sticker" : [NSNull null],
	}), @"Alice gifted Bob 3 months of Telegram Premium");
}

- (void)testGiftedPremiumDays {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageGiftedPremium",
		@"gifter_user_id" : @(1001),
		@"receiver_user_id" : @(1002),
		@"text" : svcFormatted(@""),
		@"currency" : @"USD",
		@"amount" : @(499),
		@"cryptocurrency" : @"",
		@"cryptocurrency_amount" : @(0),
		@"month_count" : @(0),
		@"day_count" : @(7),
		@"sticker" : [NSNull null],
	}), @"Alice gifted Bob 7 days of Telegram Premium");
}

- (void)testPremiumGiftCode {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messagePremiumGiftCode",
		@"creator_id" : svcSenderUser(1001),
		@"text" : svcFormatted(@""),
		@"is_from_giveaway" : @NO,
		@"is_unclaimed" : @NO,
		@"currency" : @"USD",
		@"amount" : @(499),
		@"cryptocurrency" : @"",
		@"cryptocurrency_amount" : @(0),
		@"month_count" : @(12),
		@"day_count" : @(0),
		@"sticker" : [NSNull null],
		@"code" : @"CODE",
	}), @"Alice received a gift code for 12 months of Telegram Premium");
}

- (void)testGiftedStars {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageGiftedStars",
		@"gifter_user_id" : @(1001),
		@"receiver_user_id" : @(1002),
		@"currency" : @"USD",
		@"amount" : @(499),
		@"cryptocurrency" : @"",
		@"cryptocurrency_amount" : @(0),
		@"star_count" : @(50),
		@"transaction_id" : @"tx",
		@"sticker" : [NSNull null],
	}), @"Alice gifted Bob 50 Stars");
}

- (void)testGiftedOneStar {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageGiftedStars",
		@"gifter_user_id" : @(1001),
		@"receiver_user_id" : @(1002),
		@"currency" : @"USD",
		@"amount" : @(499),
		@"cryptocurrency" : @"",
		@"cryptocurrency_amount" : @(0),
		@"star_count" : @(1),
		@"transaction_id" : @"tx",
		@"sticker" : [NSNull null],
	}), @"Alice gifted Bob 1 Star");
}

- (void)testGiftedGrams {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageGiftedGrams",
		@"gifter_user_id" : @(1001),
		@"receiver_user_id" : @(1002),
		@"gram_amount" : @(5000000000LL),
		@"transaction_id" : @"tx",
		@"sticker" : [NSNull null],
	}), @"Alice gifted Bob 5 TON");
}

- (void)testGiveawayPrizeStars {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageGiveawayPrizeStars",
		@"star_count" : @(50),
		@"transaction_id" : @"tx",
		@"boosted_chat_id" : @(2001),
		@"giveaway_message_id" : @(42),
		@"is_unclaimed" : @NO,
		@"sticker" : [NSNull null],
	}), @"Alice received 50 Stars from a giveaway");
}

- (void)testGiveawayCreated {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageGiveawayCreated",
		@"star_count" : @(100),
	}), @"Alice started a giveaway of 100 Stars");
}

- (void)testGiveawayCompleted {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageGiveawayCompleted",
		@"giveaway_message_id" : @(42),
		@"winner_count" : @(5),
		@"is_star_giveaway" : @NO,
		@"unclaimed_prize_count" : @(0),
	}), @"Alice's giveaway has ended: 5 winners");
}

#pragma mark - bots, web apps and passport

- (void)testContactRegistered {
	XCTAssertEqualObjects(svcSentence(@{@"@type" : @"messageContactRegistered"}),
			@"Alice joined Telegram");
}

- (void)testBotWriteAccessAllowed {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageBotWriteAccessAllowed",
		@"reason" : @{@"@type" : @"botWriteAccessAllowReasonAcceptedRequest"},
	}), @"Alice allowed the bot to send messages");
}

- (void)testBotWriteAccessWebsite {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageBotWriteAccessAllowed",
		@"reason" : @{@"@type" : @"botWriteAccessAllowReasonConnectedWebsite",
					 @"domain_name" : @"example.com"},
	}), @"You allowed this bot to message you when you logged in on example.com.");
}

- (void)testWebAppDataSent {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageWebAppDataSent",
		@"button_text" : @"Open",
	}), @"Alice sent data to the bot");
}

- (void)testWebAppDataReceived {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageWebAppDataReceived",
		@"button_text" : @"Open",
		@"data" : @"payload",
	}), @"Alice received data from the bot");
}

- (void)testPassportDataSent {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messagePassportDataSent",
		@"types" : @[@{@"@type" : @"passportElementTypePassport"}],
	}), @"Alice sent passport data");
}

- (void)testPassportDataReceived {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messagePassportDataReceived",
		@"elements" : @[],
		@"credentials" : @{@"@type" : @"encryptedCredentials",
						   @"data" : @"data", @"hash" : @"hash", @"secret" : @"secret"},
	}), @"Alice received passport data");
}

#pragma mark - proximity and video chats

- (void)testProximityAlertTriggered {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageProximityAlertTriggered",
		@"traveler_id" : svcSenderUser(1002),
		@"watcher_id" : svcSenderUser(1003),
		@"distance" : @(100),
	}), @"Bob is within 100 m of Carol");
}

- (void)testVideoChatScheduled {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageVideoChatScheduled",
		@"group_call_id" : @(7),
		@"start_date" : @(1700000000),
	}), @"Alice scheduled a video chat");
}

- (void)testVideoChatStarted {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageVideoChatStarted",
		@"group_call_id" : @(7),
	}), @"Alice started a video chat");
}

- (void)testVideoChatEnded {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageVideoChatEnded",
		@"duration" : @(720),
	}), @"Video chat ended (12 minutes)");
}

- (void)testInviteVideoChatParticipants {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageInviteVideoChatParticipants",
		@"group_call_id" : @(7),
		@"user_ids" : @[@(1002), @(1003)],
	}), @"Alice invited Bob and Carol to the video chat");
}

#pragma mark - expired media

- (void)testExpiredPhoto {
	XCTAssertEqualObjects(svcSentence(@{@"@type" : @"messageExpiredPhoto"}),
			@"Photo has expired");
}

- (void)testExpiredVideo {
	XCTAssertEqualObjects(svcSentence(@{@"@type" : @"messageExpiredVideo"}),
			@"Video has expired");
}

- (void)testExpiredVideoNote {
	XCTAssertEqualObjects(svcSentence(@{@"@type" : @"messageExpiredVideoNote"}),
			@"Expired video message");
}

- (void)testExpiredVoiceNote {
	XCTAssertEqualObjects(svcSentence(@{@"@type" : @"messageExpiredVoiceNote"}),
			@"Expired voice message");
}

#pragma mark - ownership and communities

- (void)testChatOwnerChanged {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageChatOwnerChanged",
		@"new_owner_user_id" : @(1002),
	}), @"Alice transferred the group to Bob");
}

- (void)testChatOwnerLeft {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageChatOwnerLeft",
		@"new_owner_user_id" : @(1002),
	}), @"Alice left the group. Bob is the new owner");
}

- (void)testChatOwnerLeftWithoutSuccessor {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageChatOwnerLeft",
		@"new_owner_user_id" : @(0),
	}), @"Alice left the group");
}

- (void)testChatAddedToCommunity {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageChatAddedToCommunity",
		@"community_id" : @(2001),
	}), @"Alice added the group to a community");
}

- (void)testChatRemovedFromCommunity {
	XCTAssertEqualObjects(svcSentence(@{@"@type" : @"messageChatRemovedFromCommunity"}),
			@"Alice removed the group from the community");
}

- (void)testChatJoinFromCommunity {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageChatJoinFromCommunity",
		@"community_id" : @(2001),
	}), @"Alice joined the group from a community");
}

#pragma mark - protection and paid messages

- (void)testHasProtectedContentEnabled {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageChatHasProtectedContentToggled",
		@"request_message_id" : @(0),
		@"old_has_protected_content" : @NO,
		@"new_has_protected_content" : @YES,
	}), @"Alice enabled content protection");
}

- (void)testHasProtectedContentDisabled {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageChatHasProtectedContentToggled",
		@"request_message_id" : @(0),
		@"old_has_protected_content" : @YES,
		@"new_has_protected_content" : @NO,
	}), @"Alice disabled content protection");
}

- (void)testProtectedContentDisableRequested {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageChatHasProtectedContentDisableRequested",
		@"is_expired" : @NO,
	}), @"Alice requested to disable content protection");
}

- (void)testProtectedContentDisableRequestExpired {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageChatHasProtectedContentDisableRequested",
		@"is_expired" : @YES,
	}), @"Alice's request to disable content protection has expired");
}

- (void)testDirectMessagePriceEnabled {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageDirectMessagePriceChanged",
		@"is_enabled" : @YES,
		@"paid_message_star_count" : @(50),
	}), @"Alice enabled paid direct messages at 50 Stars per message");
}

- (void)testDirectMessagePriceDisabled {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageDirectMessagePriceChanged",
		@"is_enabled" : @NO,
		@"paid_message_star_count" : @(0),
	}), @"Alice disabled paid direct messages");
}

- (void)testPaidMessagePriceChanged {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messagePaidMessagePriceChanged",
		@"paid_message_star_count" : @(5),
	}), @"Alice changed price to 5 Stars per message");
}

- (void)testPaidMessagesMadeFree {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messagePaidMessagePriceChanged",
		@"paid_message_star_count" : @(0),
	}), @"Alice made messages free");
}

- (void)testPaidMessagesRefunded {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messagePaidMessagesRefunded",
		@"message_count" : @(3),
		@"star_count" : @(50),
	}), @"Alice refunded 50 Stars for 3 messages");
}

- (void)testUnpaidMessagesAllowedByLink {
	XCTAssertEqualObjects(svcSentence(@{@"@type" : @"messageUnpaidMessagesAllowedByLink"}),
			@"Alice allowed unpaid messages via link");
}

#pragma mark - suggested posts

- (void)testSuggestedPostApprovalFailed {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageSuggestedPostApprovalFailed",
		@"suggested_post_message_id" : @(42),
		@"price" : @{@"@type" : @"suggestedPostPriceStar", @"star_count" : @(50)},
	}), @"Alice's suggested post could not be approved");
}

- (void)testSuggestedPostApproved {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageSuggestedPostApproved",
		@"suggested_post_message_id" : @(42),
		@"price" : @{@"@type" : @"suggestedPostPriceStar", @"star_count" : @(50)},
		@"send_date" : @(1700000000),
	}), @"Alice's suggested post was approved");
}

- (void)testSuggestedPostDeclined {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageSuggestedPostDeclined",
		@"suggested_post_message_id" : @(42),
		@"comment" : @"No",
	}), @"Alice's suggested post was declined");
}

- (void)testSuggestedPostPaid {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageSuggestedPostPaid",
		@"suggested_post_message_id" : @(42),
		@"star_amount" : @{@"@type" : @"starAmount",
						   @"star_count" : @(50), @"nanostar_count" : @(0)},
		@"gram_amount" : @(0),
	}), @"Alice received 50 Stars for the suggested post");
}

- (void)testSuggestedPostRefunded {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageSuggestedPostRefunded",
		@"suggested_post_message_id" : @(42),
		@"reason" : @{@"@type" : @"suggestedPostRefundReasonPostDeleted"},
	}), @"Alice's payment for the suggested post was refunded");
}

#pragma mark - checklists and polls

- (void)testChecklistTasksAdded {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageChecklistTasksAdded",
		@"checklist_message_id" : @(42),
		@"tasks" : @[
			@{@"@type" : @"checklistTask", @"id" : @(1),
			  @"text" : svcFormatted(@"Milk")},
			@{@"@type" : @"checklistTask", @"id" : @(2),
			  @"text" : svcFormatted(@"Bread")},
		],
	}), @"Alice added 2 tasks to a checklist");
}

- (void)testChecklistTasksDone {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageChecklistTasksDone",
		@"checklist_message_id" : @(42),
		@"marked_as_done_task_ids" : @[@(1)],
		@"marked_as_not_done_task_ids" : @[],
	}), @"Alice marked 1 task as done");
}

- (void)testChecklistTasksDoneAndNotDone {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageChecklistTasksDone",
		@"checklist_message_id" : @(42),
		@"marked_as_done_task_ids" : @[@(1), @(2)],
		@"marked_as_not_done_task_ids" : @[@(3)],
	}), @"Alice marked 2 tasks as done and 1 task as not done");
}

- (void)testPollOptionAdded {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messagePollOptionAdded",
		@"poll_message_id" : @(42),
		@"option_id" : @"1",
		@"text" : svcFormatted(@"Red"),
	}), @"Alice added the poll option \"Red\"");
}

- (void)testPollOptionDeleted {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messagePollOptionDeleted",
		@"poll_message_id" : @(42),
		@"option_id" : @"1",
		@"text" : svcFormatted(@"Blue"),
	}), @"Alice deleted the poll option \"Blue\"");
}

#pragma mark - bots, TON and gifts

- (void)testManagedBotCreated {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageManagedBotCreated",
		@"bot_user_id" : @(4001),
		@"manager_bot_user_id" : @(1002),
	}), @"Alice created a bot managed by Bob");
}

- (void)testTonConnectRequest {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageTonConnectRequest",
		@"session_id" : @(5368324170671202286LL),
		@"state" : @{@"@type" : @"tonConnectRequestStateAccepted"},
		@"dapp_name" : @"Example",
		@"topic" : @"topic",
		@"trace_id" : @"trace",
	}), @"Alice received a request from Example via TON Connect");
}

- (void)testTonWalletTransfer {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageTonWalletTransfer",
		@"sender_user_id" : @(1001),
		@"transaction_id" : @"tx",
		@"peer_address" : @"EQC...",
		@"amount" : @(5000000000LL),
		@"comment" : @"",
		@"is_comment_encrypted" : @NO,
	}), @"Alice transferred 5 TON");
}

- (void)testRefundedUpgradedGift {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageRefundedUpgradedGift",
		@"gift" : @{@"@type" : @"gift", @"id" : @(1)},
		@"sender_id" : svcSenderUser(1001),
		@"receiver_id" : svcSenderUser(1002),
		@"origin" : @{@"@type" : @"upgradedGiftOriginTransfer"},
	}), @"Alice's gift was refunded");
}

- (void)testUpgradedGiftPurchaseOffer {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageUpgradedGiftPurchaseOffer",
		@"gift" : @{@"@type" : @"upgradedGift", @"id" : @(1)},
		@"state" : @{@"@type" : @"giftPurchaseOfferStatePending"},
		@"price" : @{@"@type" : @"giftResalePriceStar", @"star_count" : @(50)},
		@"expiration_date" : @(1700000000),
	}), @"Alice offered 50 Stars for a gift");
}

- (void)testUpgradedGiftPurchaseOfferRejected {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageUpgradedGiftPurchaseOfferRejected",
		@"gift" : @{@"@type" : @"upgradedGift", @"id" : @(1)},
		@"price" : @{@"@type" : @"giftResalePriceStar", @"star_count" : @(50)},
		@"offer_message_id" : @(42),
		@"was_expired" : @NO,
	}), @"Alice's offer to buy a gift was rejected");
}

- (void)testUpgradedGiftPurchaseOfferExpired {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageUpgradedGiftPurchaseOfferRejected",
		@"gift" : @{@"@type" : @"upgradedGift", @"id" : @(1)},
		@"price" : @{@"@type" : @"giftResalePriceGram", @"gram_cent_count" : @(500)},
		@"offer_message_id" : @(42),
		@"was_expired" : @YES,
	}), @"Alice's offer to buy a gift has expired");
}

- (void)testUnsupported {
	XCTAssertEqualObjects(svcSentence(@{@"@type" : @"messageUnsupported"}),
			@"This message is not supported by your version of Telegram. Please update to the latest version.");
}

#pragma mark - actor and channel rules

- (void)testOutgoingUsesYou {
	NSMutableDictionary *m = [svcMessage(@{
		@"@type" : @"messageChatChangeTitle",
		@"title" : @"News",
	}) mutableCopy];
	m[@"is_outgoing"] = @YES;
	XCTAssertEqualObjects(TGServiceMessageText(m, svcUsers(), svcChats()),
			@"You changed the group name to \"News\"");
}

- (void)testUnknownActorUsesSomeone {
	NSMutableDictionary *m = [svcMessage(@{
		@"@type" : @"messageChatChangeTitle",
		@"title" : @"News",
	}) mutableCopy];
	m[@"sender_id"] = svcSenderUser(9999);
	XCTAssertEqualObjects(TGServiceMessageText(m, svcUsers(), svcChats()),
			@"Someone changed the group name to \"News\"");
}

- (void)testChannelWording {
	NSMutableDictionary *m = [svcMessage(@{
		@"@type" : @"messageBasicGroupChatCreate",
		@"title" : @"News",
		@"member_user_ids" : @[@(1001)],
	}) mutableCopy];
	m[@"is_channel_post"] = @YES;
	XCTAssertEqualObjects(TGServiceMessageText(m, svcUsers(), svcChats()),
			@"Alice created the channel \"News\"");
}

- (void)testChannelDeletePhotoWording {
	NSMutableDictionary *m = [svcMessage(@{
		@"@type" : @"messageChatDeletePhoto",
	}) mutableCopy];
	m[@"is_channel_post"] = @YES;
	XCTAssertEqualObjects(TGServiceMessageText(m, svcUsers(), svcChats()),
			@"Alice removed the channel photo");
}

- (void)testChatSenderUsesChatTitle {
	NSMutableDictionary *m = [svcMessage(@{
		@"@type" : @"messageChatDeletePhoto",
	}) mutableCopy];
	m[@"sender_id"] = @{@"@type" : @"messageSenderChat", @"chat_id" : @(2001)};
	XCTAssertEqualObjects(TGServiceMessageText(m, svcUsers(), svcChats()),
			@"News removed the group photo");
}

- (void)testInt64UserIdAsString {
	NSMutableDictionary *m = [svcMessage(@{
		@"@type" : @"messageChatChangeTitle",
		@"title" : @"News",
	}) mutableCopy];
	m[@"sender_id"] = @{@"@type" : @"messageSenderUser",
						@"user_id" : @"5368324170671202286"};
	XCTAssertEqualObjects(TGServiceMessageText(m, svcUsers(), svcChats()),
			@"Eve changed the group name to \"News\"");
}

- (void)testInt64ContentIdAsString {
	XCTAssertEqualObjects(svcSentence(@{
		@"@type" : @"messageChatDeleteMember",
		@"user_id" : @"5368324170671202286",
	}), @"Alice removed Eve");
}

- (void)testNonServiceContentReturnsNil {
	NSDictionary *content = @{
		@"@type" : @"messageText",
		@"text" : svcFormatted(@"hello"),
	};
	XCTAssertTrue(TGServiceMessageText(svcMessage(content), svcUsers(), svcChats()) == nil);
}

@end
