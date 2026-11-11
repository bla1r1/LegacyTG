//
// TGUpdateHandlers+Account.m - one family of update* branches.
//
#import "TGUpdateHandlers.h"
#import "TGUpdateHandlersSupport.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGState.h"
#import "TGTransport.h"
#import "TGUpdateRouter.h"
#import "TGAccountSession.h"
#import "TGJson.h"
#import "TGOptions.h"
#import "TGBase64.h"
#import "TGCall.h"
#include "TGUpdateType.h"

@interface TGClient (TGUpdateHandlerPrivate)
- (void)markSavedMessagesRow;
@end

@implementation TGUpdateHandlers (Account)

- (BOOL)handleAccountUpdates:(NSString *)type obj:(NSDictionary *)obj {
	switch (TGUpdateTypeFor(type.UTF8String, type.length)){
	case TGUpdateDefaultReactionType: {
		// The reaction their bar leads with. Kept here so the picker can put
		// it first without asking the server again.
		NSString *emoji = obj[@"reaction_type"][@"emoji"];
		if ([emoji isKindOfClass:NSString.class] && emoji.length)
			self.client.reactionDefaultEmoji = emoji;
		return YES;
	}
	case TGUpdateAnimationSearchParameters: {
		// Which bot answers GIF search, and the emoji it suggests for it.
		NSString *provider = obj[@"provider"];
		if ([provider isKindOfClass:NSString.class] && provider.length)
			self.client.gifSearchProvider = provider;
		NSArray *emojis = obj[@"emojis"];
		if ([emojis isKindOfClass:NSArray.class])
			self.client.gifSearchEmojis = emojis;
		return YES;
	}
	case TGUpdateServiceNotification: {
		// The protocol says to show these as a popup: there is no chat they
		// belong to, so the window is the only place they can land.
		NSString *text = nil;
		id content = obj[@"content"];
		if ([content isKindOfClass:NSDictionary.class]){
			id body = content[@"text"];
			if ([body isKindOfClass:NSDictionary.class])
				text = body[@"text"];
			else if ([body isKindOfClass:NSString.class])
				text = body;
		}
		if (!text.length)
			text = obj[@"type"];
		if ([text isKindOfClass:NSString.class] && text.length)
			[[NSNotificationCenter defaultCenter]
					postNotificationName:TGServiceNotificationReceivedNotification
								object:self userInfo:@{@"text" : text}];
		return YES;
	}
	case TGUpdateTermsOfService: {
		// The protocol wants these shown before the account goes on. A
		// terms object that does not ask for a popup is accepted silently;
		// the rest go to the window, which is the only surface with no chat
		// to belong to.
		NSString *termsId = obj[@"terms_of_service_id"];
		NSDictionary *terms = [obj[@"terms_of_service"] isKindOfClass:NSDictionary.class]
				? obj[@"terms_of_service"] : @{};
		id body = terms[@"text"];
		NSString *text = [body isKindOfClass:NSDictionary.class] ? body[@"text"] : nil;
		if (![text isKindOfClass:NSString.class])
			text = @"";
		BOOL popup = [terms[@"show_popup"] boolValue];
		if (![termsId isKindOfClass:NSString.class] || !termsId.length)
			return YES;
		if (popup){
			[[NSNotificationCenter defaultCenter]
					postNotificationName:TGTermsOfServiceReceivedNotification
								object:self
							userInfo:@{@"id" : termsId, @"text" : text ?: @""}];
		} else {
			[self.client acceptTermsOfService:termsId completion:nil];
		}
		return YES;
	}
	case TGUpdateUserPrivacySettingRules: {
		// A rule flipped here or on another client; the privacy page holds
		// the copy, so it re-reads rather than guessing which row moved.
		[[NSNotificationCenter defaultCenter]
				postNotificationName:TGPrivacyRulesChangedNotification object:self];
		return YES;
	}
	case TGUpdateAccentColors: {
		// Appearance offers these as the account's accent; the ids are what
		// setAccentColor takes, and 0-6 stay implicit per the schema. The
		// colour records ride along so a swatch shows the real palette.
		NSArray *ids = obj[@"available_accent_color_ids"];
		if ([ids isKindOfClass:NSArray.class])
			self.client.accentColorIds = ids;
		if ([obj[@"colors"] isKindOfClass:NSArray.class])
			self.client.accentColors = obj[@"colors"];
		[[NSNotificationCenter defaultCenter]
				postNotificationName:TGAccentColorsChangedNotification object:self];
		return YES;
	}
	case TGUpdateProfileAccentColors: {
		NSArray *ids = obj[@"available_accent_color_ids"];
		if ([ids isKindOfClass:NSArray.class])
			self.client.profileAccentColorIds = ids;
		if ([obj[@"colors"] isKindOfClass:NSArray.class])
			self.client.profileAccentColors = obj[@"colors"];
		[[NSNotificationCenter defaultCenter]
				postNotificationName:TGAccentColorsChangedNotification object:self];
		return YES;
	}
	case TGUpdateContactCloseBirthdays: {
		// The count is the only thing the privacy page draws, and hiding the
		// strip is what an empty answer means. Keep the rows so a future
		// birthday strip has the names ready.
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *entry in obj[@"close_birthday_users"]){
			if (![entry isKindOfClass:NSDictionary.class])
				continue;
			NSNumber *userId = entry[@"user_id"];
			if (![userId isKindOfClass:NSNumber.class])
				continue;
			NSDictionary *birth = entry[@"birthdate"] ?: @{};
			[rows addObject:@{
				@"userId" : userId,
				@"day"    : birth[@"day"] ?: @0,
				@"month"  : birth[@"month"] ?: @0,
				@"year"   : birth[@"year"] ?: @0,
			}];
		}
		self.client.contactCloseBirthdays = rows;
		[[NSNotificationCenter defaultCenter]
				postNotificationName:TGContactCloseBirthdaysChangedNotification object:self];
		return YES;
	}
	case TGUpdateUnconfirmedSession: {
		// A login waiting to be confirmed. The devices list is where it can
		// be confirmed or signed out, so it re-reads while it is open.
		[[NSNotificationCenter defaultCenter]
				postNotificationName:TGSessionsChangedNotification object:self];
		return YES;
	}
	case TGUpdateApplicationVerificationRequired: {
		// Telegram wants a token from the platform's verification service.
		// There is no such service on this OS, so the request is handed to
		// the settings sheet, which asks the user for the token and sends
		// the server's answer back. The id is kept on the client so the row
		// can show what is pending after the scroll is gone.
		int64_t verificationId = [obj[@"verification_id"] longLongValue];
		NSString *nonce = [obj[@"nonce"] isKindOfClass:NSString.class]
				? obj[@"nonce"] : @"";
		[self.client noteApplicationVerificationWithId:verificationId nonce:nonce];
		[[NSNotificationCenter defaultCenter]
				postNotificationName:TGApplicationVerificationRequiredNotification
							  object:self
							userInfo:@{@"verificationId" : @(verificationId),
									   @"nonce" : nonce}];
		return YES;
	}
	case TGUpdateFreezeState: {
		// A restriction Telegram puts on the account, with the dates and the
		// appeal address it wants shown. Kept whole because the row is one
		// line but the sheet behind it has to answer "until when" and "where
		// do I appeal"; the Privacy page re-reads both.
		id appeal = obj[@"appeal_link"];
		self.client.freezeStateValue = @{
			@"is_frozen"     : @([obj[@"is_frozen"] boolValue]),
			@"freezing_date" : obj[@"freezing_date"] ?: @(0),
			@"deletion_date" : obj[@"deletion_date"] ?: @(0),
			@"appeal_link"   : [appeal isKindOfClass:NSString.class] ? appeal : @"",
		};
		[[NSNotificationCenter defaultCenter]
				postNotificationName:TGAccountStatusChangedNotification object:self];
		return YES;
	}
	case TGUpdateAgeVerificationParameters: {
		// The age gate: how old the country requires, which bot answers it,
		// and the country. A nil parameters clears the row rather than leaving
		// yesterday's minimum age on screen.
		id parameters = obj[@"parameters"];
		self.client.ageVerificationParametersValue =
				[parameters isKindOfClass:NSDictionary.class] ? parameters : nil;
		[[NSNotificationCenter defaultCenter]
				postNotificationName:TGAccountStatusChangedNotification object:self];
		return YES;
	}
	case TGUpdateApplicationRecaptchaVerificationRequired: {
		// Telegram wants a reCAPTCHA solved before the request goes through.
		// The request is not an age-verification token: it carries the action,
		// the site key and an id of its own, so it gets its own record and the
		// Privacy row shows exactly what the server asked for.
		id action = obj[@"action"];
		id keyId = obj[@"recaptcha_key_id"];
		self.client.recaptchaVerificationRequestValue = @{
			@"verification_id"  : @([obj[@"verification_id"] longLongValue]),
			@"action"           : [action isKindOfClass:NSString.class] ? action : @"",
			@"recaptcha_key_id" : [keyId isKindOfClass:NSString.class] ? keyId : @"",
		};
		[[NSNotificationCenter defaultCenter]
				postNotificationName:TGAccountStatusChangedNotification object:self];
		return YES;
	}
	case TGUpdateUserSubscription: {
		// A subscription changed, for this account or for someone it names.
		// The update is about a user id, so it is filed by that id; the
		// Privacy page asks for the signed-in one and shows its flags.
		if (!obj[@"user_id"])
			return YES;
		// int64 may arrive as a decimal string; the dictionary key has to be
		// the same NSNumber the screen asks about.
		NSNumber *userId = @([obj[@"user_id"] longLongValue]);
		id payload = obj[@"payload"];
		NSMutableDictionary *record = [@{
			@"payload"           : [payload isKindOfClass:NSString.class] ? payload : @"",
			@"is_canceled"       : @([obj[@"is_canceled"] boolValue]),
			@"is_restored"       : @([obj[@"is_restored"] boolValue]),
			@"is_payment_failed" : @([obj[@"is_payment_failed"] boolValue]),
		} mutableCopy];
		if (!self.client.userSubscriptionsById)
			self.client.userSubscriptionsById = [NSMutableDictionary dictionary];
		self.client.userSubscriptionsById[userId] = record;
		[[NSNotificationCenter defaultCenter]
				postNotificationName:TGAccountStatusChangedNotification object:self
							userInfo:@{@"userId" : userId}];
		return YES;
	}
	case TGUpdateAvailableMessageEffects: {
		// The effects the effect sheet may offer. Ids are kept as numbers so
		// the sheet can name one in getMessageEffect without re-parsing a
		// string; a second list is the sticker effects, which the same sheet
		// lists under their own label.
		self.client.reactionMessageEffectIds = TGUEffectIdList(obj[@"reaction_effect_ids"]);
		self.client.stickerMessageEffectIds = TGUEffectIdList(obj[@"sticker_effect_ids"]);
		[[NSNotificationCenter defaultCenter]
				postNotificationName:TGMessageEffectsChangedNotification object:self];
		return YES;
	}
	case TGUpdateDefaultBackground: {
		// Telegram's own background for new chats. The whole background is
		// kept because its name, id and type are what Appearance has to show;
		// for_dark_theme says which of the two defaults moved.
		id background = obj[@"background"];
		self.client.defaultBackgroundValue = @{
			@"for_dark_theme" : @([obj[@"for_dark_theme"] boolValue]),
			@"background"     : [background isKindOfClass:NSDictionary.class]
					? background : @{},
		};
		[[NSNotificationCenter defaultCenter]
				postNotificationName:TGAppearanceDefaultsChangedNotification object:self];
		return YES;
	}
	case TGUpdateEmojiChatThemes: {
		// The emoji chat themes Telegram offers. The names and their light and
		// dark settings are kept whole; Appearance lists the names and the
		// sheet behind one reads its settings.
		id themes = obj[@"chat_themes"];
		self.client.emojiChatThemesValue =
				[themes isKindOfClass:NSArray.class] ? themes : @[];
		[[NSNotificationCenter defaultCenter]
				postNotificationName:TGAppearanceDefaultsChangedNotification object:self];
		return YES;
	}
	case TGUpdateStopMessageDraft: {
		// A streaming draft was stopped. The cached text in the chat row is
		// what the composer would put back, so it is cleared here; the open
		// chat hears which text it was and clears the field only when the
		// field still holds that text, not something typed over it.
		if (!obj[@"chat_id"])
			return YES;
		int64_t chat = [obj[@"chat_id"] longLongValue];
		NSNumber *chatId = @(chat);
		NSString *previous = self.client.chatsById[chatId][@"draft"];
		if (![previous isKindOfClass:NSString.class])
			previous = @"";
		NSMutableDictionary *row = self.client.chatsById[chatId];
		if (row) {
			row[@"draft"] = @"";
			[self.client markChatRowDirty:chat];
		}
		NSDictionary *state = @{
			@"chat_id"       : @(chat),
			@"forum_topic_id": obj[@"forum_topic_id"] ?: @(0),
			@"draft_id"      : @([obj[@"draft_id"] longLongValue]),
			@"draft_text"    : previous,
		};
		self.client.stoppedMessageDraftValue = state;
		[[NSNotificationCenter defaultCenter]
				postNotificationName:TGChatDraftStoppedNotification object:self
							userInfo:state];
		return YES;
	}

	default:
		break;
	}
	return NO;
}

@end

// vim:ft=objc
