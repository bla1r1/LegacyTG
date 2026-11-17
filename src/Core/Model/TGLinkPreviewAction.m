#import "TGLinkPreviewAction.h"
#import "TGLocalization.h"

static NSString *TGLPKey(NSString *key, NSString *english) {
	return TGLocalizedKey(key, english);
}

NSDictionary *TGLinkPreviewAction(NSDictionary *lp) {
	if (![lp isKindOfClass:NSDictionary.class])
		return @{};
	NSDictionary *type = [lp[@"type"] isKindOfClass:NSDictionary.class] ? lp[@"type"] : @{};
	NSString *kind = [type[@"@type"] isKindOfClass:NSString.class] ? type[@"@type"] : @"";
	NSString *displayUrl = [lp[@"display_url"] isKindOfClass:NSString.class] ? lp[@"display_url"] : @"";

	if ([kind isEqualToString:@"linkPreviewTypeUser"]) {
		// A bot's page is "telegram_bot" to official, which has no button for it.
		if ([type[@"is_bot"] boolValue])
			return @{};
		return [displayUrl rangeOfString:@"?profile"].location != NSNotFound
				? @{@"action" : TGLPKey(@"Conversation.OpenProfile", @"OPEN PROFILE")}
				: @{@"action" : TGLPKey(@"Conversation.UserSendMessage", @"SEND MESSAGE")};
	}
	if ([kind isEqualToString:@"linkPreviewTypeChat"]) {
		NSDictionary *chatType = [type[@"type"] isKindOfClass:NSDictionary.class] ? type[@"type"] : @{};
		BOOL channel = [chatType[@"@type"] isEqualToString:@"inviteLinkChatTypeChannel"];
		if ([type[@"creates_join_request"] boolValue])
			return @{@"action" : channel
					? TGLPKey(@"Conversation.RequestToJoinChannel", @"REQUEST TO JOIN")
					: TGLPKey(@"Conversation.RequestToJoinGroup", @"REQUEST TO JOIN")};
		return @{@"action" : channel ? TGLPKey(@"Conversation.ViewChannel", @"VIEW CHANNEL")
				: TGLPKey(@"Conversation.ViewGroup", @"VIEW GROUP")};
	}
	if ([kind isEqualToString:@"linkPreviewTypeMessage"] ||
			([kind isEqualToString:@"linkPreviewTypePhoto"] && [displayUrl hasPrefix:@"t.me/"]))
		return @{@"action" : TGLPKey(@"Conversation.ViewMessage", @"VIEW MESSAGE")};
	if ([kind isEqualToString:@"linkPreviewTypeVideoChat"]) {
		NSString *title = [type[@"is_live_stream"] boolValue]
				? TGLPKey(@"Conversation.LiveStream", @"Live Stream")
				: TGLPKey(@"Conversation.VoiceChat", @"Voice Chat");
		NSString *action = [type[@"joins_as_speaker"] boolValue]
				? TGLPKey(@"Conversation.JoinVoiceChatAsSpeaker", @"JOIN AS SPEAKER")
				: TGLPKey(@"Conversation.JoinVoiceChatAsListener", @"JOIN AS LISTENER");
		return @{@"action" : action, @"title" : title};
	}
	if ([kind isEqualToString:@"linkPreviewTypeBackground"])
		return @{@"action" : TGLPKey(@"Conversation.ViewBackground", @"VIEW BACKGROUND"),
				 @"title" : TGLPKey(@"Conversation.ChatBackground", @"Chat Background"),
				 @"dropsText" : @YES};
	if ([kind isEqualToString:@"linkPreviewTypeTheme"])
		return @{@"action" : TGLPKey(@"Conversation.ViewTheme", @"VIEW THEME"),
				 @"title" : TGLPKey(@"Conversation.Theme", @"Color Theme"),
				 @"dropsText" : @YES};
	NSDictionary *simple = @{
		@"linkPreviewTypeWebApp"             : @[@"Conversation.OpenBotApp", @"OPEN APP"],
		@"linkPreviewTypeShareableChatFolder": @[@"Conversation.OpenChatFolder", @"VIEW CHAT LIST"],
		@"linkPreviewTypeStory"              : @[@"Chat.OpenStory", @"OPEN STORY"],
		@"linkPreviewTypeLiveStory"          : @[@"Chat.OpenStory", @"OPEN STORY"],
		@"linkPreviewTypeChannelBoost"       : @[@"Conversation.BoostChannel", @"BOOST"],
		@"linkPreviewTypeSupergroupBoost"    : @[@"Conversation.BoostChannel", @"BOOST"],
		@"linkPreviewTypeUpgradedGift"       : @[@"Conversation.ViewStarGift", @"VIEW COLLECTIBLE"],
		@"linkPreviewTypeGroupCall"          : @[@"Chat.ViewGroupCall", @"JOIN GROUP CALL"],
	};
	NSArray *pair = simple[kind];
	if (pair)
		return @{@"action" : TGLPKey(pair[0], pair[1])};
	if ([kind isEqualToString:@"linkPreviewTypeStickerSet"]) {
		// A set of custom emoji says Emojis (official isEmoji from the set).
		NSArray *stickers = [type[@"stickers"] isKindOfClass:NSArray.class] ? type[@"stickers"] : @[];
		NSDictionary *first = [stickers.firstObject isKindOfClass:NSDictionary.class] ? stickers.firstObject : nil;
		BOOL emoji = [first[@"full_type"][@"@type"] isEqualToString:@"stickerFullTypeCustomEmoji"];
		return @{@"action" : emoji ? TGLPKey(@"Conversation.ViewEmojis", @"VIEW EMOJIS")
				: TGLPKey(@"Conversation.ViewStickers", @"VIEW STICKERS")};
	}
	return @{};
}
