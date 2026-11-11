//
// TGUpdateHandlers+Core.m - one family of update* branches.
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

@implementation TGUpdateHandlers (Core)

- (BOOL)handleCoreUpdates:(NSString *)type obj:(NSDictionary *)obj {
	switch (TGUpdateTypeFor(type.UTF8String, type.length)){

	case TGUpdateAuthorizationState: {
		[self.client handleAuthState:obj[@"authorization_state"]];
		return YES;
	}
	case TGUpdateUser: {
		NSDictionary *u = obj[@"user"];
		if (u[@"id"]){
			if (!self.client.rawUsersById)
				self.client.rawUsersById = [[TGObjectLruCache alloc] initWithCapacity:TGRawUserCacheCap];
			self.client.rawUsersById[u[@"id"]] = u;
		}
		NSString *name = [[NSString stringWithFormat:@"%@ %@",
				u[@"first_name"] ?: @"", u[@"last_name"] ?: @""]
				stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		if (!name.length)
			name = TGUFirstActiveUsername(u) ?: @"";
		if (u[@"id"] && name.length)
			self.client.usersById[u[@"id"]] = name;
		[self.client cacheProfilePhoto:u];
		if (u[@"id"] && self.client.updateCoalescer) {
			[self.client.updateCoalescer markUserDirty:[u[@"id"] longLongValue]];
		}
		return YES;
	}

	// Live message updates - without these a chat only refreshes when reopened.
	case TGUpdateNewMessage: {
		NSDictionary *m = obj[@"message"];
		if (m[@"chat_id"]){
			NSNumber *chatId = m[@"chat_id"];
			NSMutableDictionary *info = self.client.chatsById[chatId];
			if (info){
				info[@"text"] = [self.client previewForLastMessage:m inChat:info];
				info[@"date"] = m[@"date"] ?: @(0);
				info[@"lastId"] = m[@"id"] ?: @(0);
				info[@"lastOutgoing"] = @([m[@"is_outgoing"] boolValue]);
				if (self.client.updateCoalescer) {
					[self.client.updateCoalescer markChatDirty:[chatId longLongValue]];
					[self.client.updateCoalescer markOrderDirty];
				}
			}
		}
		if (self.client.onMessage && m)
			self.client.onMessage([m[@"chat_id"] longLongValue], TGFlattenMessage(m), 0);
		[self.client handleInAppNotificationForNewMessage:m];
		return YES;
	}
	case TGUpdateMessageSendSucceeded:
	case TGUpdateMessageSendFailed: {
		// The echo we showed carries a temporary id, larger than any real one,
		// and a pending sending_state. The server's id arrives only here, so
		// without this branch the bubble keeps its clock and every later
		// request about it (reply, delete, read) names an id that is gone.
		// A failed send keeps the old id and comes back with the failed flag.
		NSDictionary *m = obj[@"message"];
		int64_t oldId  = [obj[@"old_message_id"] longLongValue];
		BOOL sent = [obj[@"@type"] isEqualToString:@"updateMessageSendSucceeded"];
		[self.client noteSendFinished:oldId sent:sent];
		if (!m)
			return YES;
		int64_t chatId = [m[@"chat_id"] longLongValue];
		NSDictionary *flat = TGFlattenMessage(m);
		if (self.client.onMessage){
			if (oldId)
				self.client.onMessage(chatId, nil, oldId);
			self.client.onMessage(chatId, flat, 0);
		}
		// The send store keeps its own table; it hears the same update here
		// rather than taking the chat's single onMessage slot.
		NSMutableDictionary *info = [@{
			@"chatId"       : @(chatId),
			@"message"      : flat,
			@"oldMessageId" : @(oldId),
			@"succeeded"    : @(sent),
		} mutableCopy];
		if ([obj[@"error"] isKindOfClass:NSDictionary.class])
			info[@"error"] = obj[@"error"];
		[[NSNotificationCenter defaultCenter]
				postNotificationName:TGMessageSendStateChangedNotification
							  object:self userInfo:info];
		return YES;
	}
	case TGUpdateMessageContent: {
		// Content changed in place (a photo finished uploading, a text edited).
		if (self.client.onMessage)
			self.client.onMessage([obj[@"chat_id"] longLongValue], nil, 0);
		return YES;
	}
	case TGUpdateDeleteMessages: {
		if ([obj[@"is_permanent"] boolValue] && self.client.onMessage){
			int64_t chatId = [obj[@"chat_id"] longLongValue];
			for (NSNumber *mid in obj[@"message_ids"]){
				// Deleted while uploading: nothing left to wait for, and the
				// sender did it, so it is not a failure to report.
				[self.client noteSendFinished:[mid longLongValue] sent:YES];
				self.client.onMessage(chatId, nil, [mid longLongValue]);
			}
		}
		return YES;
	}

	default:
		break;
	}
	return NO;
}

@end

// vim:ft=objc
