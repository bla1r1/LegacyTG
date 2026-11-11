//
// TGUpdateHandlers+Chats.m - one family of update* branches.
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

@implementation TGUpdateHandlers (Chats)

- (BOOL)handleChatsUpdates:(NSString *)type obj:(NSDictionary *)obj {
	switch (TGUpdateTypeFor(type.UTF8String, type.length)){
	case TGUpdateNewChat: {
		[self.client mergeChat:obj[@"chat"]];
		return YES;
	}
	case TGUpdateChatReplyMarkup: {
		// A bot's keyboard arrived on a chat or was taken off it. The message
		// rides along whole, so the keyboard is read from it here.
		NSNumber *chatId = obj[@"chat_id"];
		NSMutableDictionary *chat = chatId ? self.client.chatsById[chatId] : nil;
		NSDictionary *message = [obj[@"reply_markup_message"] isKindOfClass:NSDictionary.class]
				? obj[@"reply_markup_message"] : nil;
		if (chat) {
			chat[@"replyMarkupMessageId"] = message[@"id"] ?: @0;
			chat[@"replyKeyboard"] = TGFlattenReplyMarkup(message[@"reply_markup"])[@"replyKeyboard"]
					?: [NSNull null];
		}
		if (chatId)
			[[NSNotificationCenter defaultCenter]
					postNotificationName:TGChatReplyMarkupChangedNotification
								  object:nil userInfo:@{@"chatId" : chatId}];
		return YES;
	}
	case TGUpdateChatLastMessage:
	case TGUpdateChatPosition:
	case TGUpdateChatTitle:
	case TGUpdateChatPhoto:
	case TGUpdateChatDraftMessage:
	case TGUpdateChatIsMarkedAsUnread:
	case TGUpdateChatUnreadMentionCount:
	case TGUpdateChatUnreadReactionCount:
	case TGUpdateChatReadInbox:
	case TGUpdateChatReadOutbox:
	case TGUpdateChatUnreadPollVoteCount:
	case TGUpdateChatAddedToList:
	case TGUpdateChatRemovedFromList:
	case TGUpdateChatNotificationSettings: {
		[self.client applyChatUpdate:obj];
		return YES;
	}
	case TGUpdateChatPermissions:
	case TGUpdateChatMessageAutoDeleteTime:
	case TGUpdateChatOnlineMemberCount:
	case TGUpdateChatVideoChat: {
		// Group-level facts the profile shows. They are chat fields, not full
		// info, so they are merged here and the screen is told the same way a
		// full record tells it.
		[self.client applyChatUpdate:obj];
		NSNumber *chatId = obj[@"chat_id"];
		if (chatId)
			[[NSNotificationCenter defaultCenter]
					postNotificationName:TGFullInfoChangedNotification object:self
								userInfo:@{@"kind" : @"chat", @"id" : chatId}];
		return YES;
	}
	// Chat fields nothing draws yet - block list, protected content, the
	// scheduled bar, view-as-topics, translation, reactions, theme, accent
	// colours, send-as, welcome messages, background. Merged into the row so
	// the screen that starts reading one is already fed, and told the same
	// way the group facts are told: an open profile re-reads.
	case TGUpdateChatBlockList:
	case TGUpdateChatHasProtectedContent:
	case TGUpdateChatHasScheduledMessages:
	case TGUpdateChatViewAsTopics:
	case TGUpdateChatIsTranslatable:
	case TGUpdateChatHasWelcomeMessages:
	case TGUpdateChatAvailableReactions:
	case TGUpdateChatTheme:
	case TGUpdateChatAccentColors:
	case TGUpdateChatMessageSender:
	case TGUpdateChatWelcomeMessages:
	case TGUpdateChatBackground: {
		[self.client applyChatUpdate:obj];
		NSNumber *chatId = obj[@"chat_id"];
		if (chatId)
			[[NSNotificationCenter defaultCenter]
					postNotificationName:TGFullInfoChangedNotification object:self
								userInfo:@{@"kind" : @"chat", @"id" : chatId}];
		return YES;
	}
	case TGUpdateMessageReaction:
	case TGUpdateMessageReactions:
	case TGUpdateMessageLiveLocationViewed:
	case TGUpdateAnimatedEmojiMessageClicked: {
		// Who reacted, who watched, what was tapped: all fields of the
		// message, so the open chat re-reads it - coalesced, the way a crowd
		// reacting to a channel post stays one nudge per chat.
		if (self.client.updateCoalescer)
			[self.client.updateCoalescer markMessageDirty:[obj[@"message_id"] longLongValue]
											inChat:[obj[@"chat_id"] longLongValue]];
		return YES;
	}
	case TGUpdateActiveLiveLocationMessages: {
		// The list of running live locations moved; every rider nudges its
		// own chat, the same shape a content change arrives in.
		for (NSDictionary *m in obj[@"messages"]){
			if (self.client.updateCoalescer)
				[self.client.updateCoalescer markMessageDirty:[m[@"message_id"] longLongValue]
												inChat:[m[@"chat_id"] longLongValue]];
		}
		return YES;
	}
	case TGUpdateUnreadMessageCount: {
		// The one global counter in the app: the badge. The update fires per
		// chat list, and only the main list's total is the badge's number -
		// a folder's slice shrinking it would be a lie. A missing or null
		// chat_list is the main list; zero in the field is a real count and
		// goes out as one.
		id list = obj[@"chat_list"];
		BOOL mainList = !list || [list isKindOfClass:[NSNull class]];
		if (!mainList && [list isKindOfClass:NSDictionary.class])
			mainList = [list[@"@type"] isEqualToString:@"chatListMain"];
		if (!mainList)
			return YES;
		[[NSNotificationCenter defaultCenter]
				postNotificationName:TGUnreadTotalChangedNotification object:self
							userInfo:@{@"count" : obj[@"unread_unmuted_count"] ?: @0}];
		return YES;
	}
	case TGUpdateSavedMessagesTopic:
	case TGUpdateSavedMessagesTopicCount:
	case TGUpdateSavedMessagesTags: {
		// A Saved Messages topic arrived, moved, or got a label: asked for by
		// loadSavedMessagesTopics, changing while the topics screen is open.
		// The tags update patches the row the tag belonged to.
		NSDictionary *topic = obj[@"topic"];
		NSString *topicId = [topic[@"id"] isKindOfClass:NSString.class] ?
				topic[@"id"] : [@(topic[@"id"] ? [topic[@"id"] longLongValue] : 0) stringValue];
		if (topicId && !self.client.savedTopicsById)
			self.client.savedTopicsById = [NSMutableDictionary dictionary];
		if (topicId && self.client.savedTopicsById){
			NSMutableDictionary *row = self.client.savedTopicsById[topicId] ?:
					[NSMutableDictionary dictionary];
			row[@"id"] = @(topicId.length ? [topicId longLongValue] : 0);
			NSString *type = topic[@"type"][@"@type"] ?: @"";
			NSString *title = @"Forwarded from";
			if ([type isEqualToString:@"savedMessagesTopicTypeMyNotes"])
				title = @"My Notes";
			else if ([type isEqualToString:@"savedMessagesTopicTypeAuthorHidden"])
				title = @"Author Hidden";
			else if ([type isEqualToString:@"savedMessagesTopicTypeSavedFromChat"]){
				NSString *chatTitle = [[TGClient shared] titleForChat:
						[topic[@"type"][@"chat_id"] longLongValue]];
				title = chatTitle.length ? chatTitle : @"Chat";
			}
			row[@"title"] = title;
			NSString *text = TGFlattenMessage(topic[@"last_message"])[@"text"];
			row[@"text"] = text ?: @"";
			if (topic[@"date"] && topic[@"date"] != [NSNull null])
				row[@"date"] = topic[@"date"];
			row[@"pinned"] = topic[@"is_pinned"];
			row[@"order"] = topic[@"order"];
			self.client.savedTopicsById[topicId] = row;
		}
		[[NSNotificationCenter defaultCenter]
				postNotificationName:TGSavedTopicsChangedNotification object:self];
		return YES;
	}
	// Three that used to sit in the marker block and now have somewhere to go.

	default:
		break;
	}
	return NO;
}

@end

// vim:ft=objc
