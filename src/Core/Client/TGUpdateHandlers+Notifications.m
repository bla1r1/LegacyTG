//
// TGUpdateHandlers+Notifications.m - one family of update* branches.
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

@implementation TGUpdateHandlers (Notifications)

- (BOOL)handleNotificationsUpdates:(NSString *)type obj:(NSDictionary *)obj {
	switch (TGUpdateTypeFor(type.UTF8String, type.length)){
	case TGUpdateAutosaveSettings: {
		// One scope, here or on another client. The exception list is not in
		// this update, so the page re-reads the whole record.
		[self.client applyAutosaveSettingsUpdate:obj];
		return YES;
	}
	case TGUpdateLanguagePackStrings: {
		// The strings that changed, not a whole pack. The Language page
		// re-reads the pack record and any string list it already showed.
		[self.client applyLanguagePackStringsUpdate:obj];
		return YES;
	}
	case TGUpdateMessageContainsUnreadPollVotes: {
		// The badge on a poll whose votes you have not looked at. Same storm
		// risk as a reaction count, same window.
		if (self.client.updateCoalescer)
			[self.client.updateCoalescer markMessageDirty:[obj[@"message_id"] longLongValue]
											inChat:[obj[@"chat_id"] longLongValue]];
		return YES;
	}
	case TGUpdateScopeNotificationSettings:
	case TGUpdateChatDefaultDisableNotification:
	case TGUpdateReactionNotificationSettings:
	case TGUpdateSavedNotificationSounds: {
		// The settings page re-reads all three scopes and the sounds list;
		// nothing finer is carried for it to read piecemeal.
		if ([type isEqualToString:@"updateReactionNotificationSettings"]){
			NSDictionary *settings = obj[@"notification_settings"];
			if ([settings isKindOfClass:NSDictionary.class])
				self.client.reactionNotificationSettingsValue = settings;
		}
		[[NSNotificationCenter defaultCenter]
				postNotificationName:TGNotificationSettingsChangedNotification object:self];
		if ([type isEqualToString:@"updateChatDefaultDisableNotification"])
			[self.client applyChatUpdate:obj];
		return YES;
	}
	case TGUpdateForumTopic:
	case TGUpdateForumTopicInfo:
	case TGUpdateTopicMessageCount: {
		// updateForumTopicInfo nests the chat one level down, in the info.
		NSNumber *chatId = obj[@"chat_id"] ?: obj[@"info"][@"chat_id"];
		[[NSNotificationCenter defaultCenter]
				postNotificationName:TGForumTopicsChangedNotification object:self
							userInfo:chatId ? @{@"chatId" : chatId} : nil];
		return YES;
	}
	case TGUpdateMessageMentionRead:
	case TGUpdateMessageUnreadReactions: {
		// Both carry the chat's new counter and the message that caused it:
		// the row's badge comes from the counter, the open chat has to drop
		// the mark on that one message.
		[self.client applyChatUpdate:obj];
		if (self.client.onMessage)
			self.client.onMessage([obj[@"chat_id"] longLongValue], nil, 0);
		return YES;
	}
	case TGUpdateMessageEdited:
	case TGUpdateMessageIsPinned:
	case TGUpdateMessageContentOpened: {
		// An edit date, a pin flag, a played voice note: the fields are on
		// the message, so the open chat re-reads it the way a content change
		// already does. Nothing to merge into the chat row.
		if (self.client.onMessage)
			self.client.onMessage([obj[@"chat_id"] longLongValue], nil, 0);
		return YES;
	}
	case TGUpdateMessageFactCheck:
	case TGUpdateMessageEphemeralContent:
	case TGUpdateMessageSuggestedPostInfo: {
		// A fact check, a bot's ephemeral half or a suggested-post offer is
		// another field on the message. The open chat re-reads that message;
		// the tools sheet then sees the same flags the server just changed.
		if (self.client.onMessage)
			self.client.onMessage([obj[@"chat_id"] longLongValue], nil, 0);
		return YES;
	}
	case TGUpdateMessageInteractionInfo: {
		// Reaction totals and a channel's view count live on the message and
		// were frozen at whatever the history fetch said, while this client
		// can already put a reaction on. Coalesced, not acted on per update.
		if (self.client.updateCoalescer)
			[self.client.updateCoalescer markMessageDirty:[obj[@"message_id"] longLongValue]
											inChat:[obj[@"chat_id"] longLongValue]];
		return YES;
	}
	case TGUpdateInstalledStickerSets:
	case TGUpdateTrendingStickerSets:
	case TGUpdateRecentStickers:
	case TGUpdateFavoriteStickers:
	case TGUpdateSavedAnimations:
	case TGUpdateStickerSet: {
		// Six lists, one notification: the panel asks for whichever tab it is
		// showing, so there is nothing finer to tell it.
		[[NSNotificationCenter defaultCenter]
				postNotificationName:TGStickerListsChangedNotification object:self];
		return YES;
	}
	case TGUpdateChatMember:
	case TGUpdateChatPendingJoinRequests:
	case TGUpdateNewChatJoinRequest:
	case TGUpdateChatJoinResult: {
		// updateChatJoinResult is the answer to our own join request, sent
		// the way the other three are: the chat's members sheet re-reads.
		NSNumber *chatId = obj[@"chat_id"];
		if (!chatId)
			return YES;
		[[NSNotificationCenter defaultCenter]
				postNotificationName:TGChatMembersChangedNotification object:self
							userInfo:@{@"chatId" : chatId}];
		return YES;
	}

	default:
		break;
	}
	return NO;
}

@end

// vim:ft=objc
