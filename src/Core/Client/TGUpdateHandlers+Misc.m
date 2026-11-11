//
// TGUpdateHandlers+Misc.m - one family of update* branches.
//
#import "TGUpdateHandlers.h"
#import "TGUpdateHandlersSupport.h"
#import "TGClient.h"
#import "TGClientInternal.h"

NSString *const TGCallUpdateNotification = @"TGCallUpdateNotification";
NSString *const TGFileDownloadedNotification = @"TGFileDownloadedNotification";
NSString *const TGFileUploadProgressNotification = @"TGFileUploadProgressNotification";
NSString *const TGFileGenerationUpdateNotification = @"TGFileGenerationUpdateNotification";
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

@implementation TGUpdateHandlers (Misc)

- (BOOL)handleMiscUpdates:(NSString *)type obj:(NSDictionary *)obj {
	switch (TGUpdateTypeFor(type.UTF8String, type.length)){
	case TGUpdateFile: {
		NSDictionary *file = obj[@"file"];
		NSInteger fid = [file[@"id"] integerValue];
		NSDictionary *local = file[@"local"];
		if (self.client.onFileProgress && [local[@"is_downloading_active"] boolValue]){
			double expected = [file[@"expected_size"] doubleValue];
			double got = [local[@"downloaded_size"] doubleValue];
			if (expected > 0)
				self.client.onFileProgress(fid, (float)(got / expected));
		}
		if ([file[@"remote"][@"is_uploading_active"] boolValue]){
			double expected = [file[@"expected_size"] doubleValue];
			double uploaded = [file[@"remote"][@"uploaded_size"] doubleValue];
			if (self.client.onFileUploadProgress && expected > 0)
				self.client.onFileUploadProgress(fid, (float)(uploaded / expected));
			[[NSNotificationCenter defaultCenter]
					postNotificationName:TGFileUploadProgressNotification object:self
								  userInfo:@{@"fileId" : @(fid), @"file" : file}];
			if (expected > 0)
				[self.client noteUploadProgress:fid fraction:(float)(uploaded / expected)];
		}
		BOOL done = [local[@"is_downloading_completed"] boolValue];
		NSString *path = local[@"path"];
		if (done && path.length){
			[[NSNotificationCenter defaultCenter]
					postNotificationName:TGFileDownloadedNotification
								  object:self
								userInfo:@{@"fileId" : @(fid), @"path" : path}];
		}
		return YES;
	}

	case TGUpdateFileGenerationStart: {
		// TDLib asks the app to produce a file. +Files owns the pending
		// request, writes the parts and finishes the generation.
		[[NSNotificationCenter defaultCenter]
				postNotificationName:TGFileGenerationUpdateNotification object:self
						  userInfo:@{@"update" : obj}];
		return YES;
	}

	case TGUpdateFileGenerationStop: {
		// The generation is no longer needed: drop the pending blocks so a
		// screen waiting on it learns it stopped rather than hangs.
		[[NSNotificationCenter defaultCenter]
				postNotificationName:TGFileGenerationUpdateNotification object:self
						  userInfo:@{@"update" : obj}];
		return YES;
	}

	case TGUpdateChatAction: {
		// TDLib names the action; the client turns it into the phrase every
		// other client shows.
		NSString *kind = obj[@"action"][@"@type"];
		NSString *phrase = nil;
		if ([kind isEqualToString:@"chatActionTyping"])
			phrase = @"typing...";
		else if ([kind isEqualToString:@"chatActionRecordingVoiceNote"])
			phrase = @"recording audio...";
		else if ([kind isEqualToString:@"chatActionRecordingVideoNote"] ||
				 [kind isEqualToString:@"chatActionRecordingVideo"])
			phrase = @"recording video...";
		else if ([kind isEqualToString:@"chatActionUploadingPhoto"])
			phrase = @"sending a photo...";
		else if ([kind hasPrefix:@"chatActionUploading"])
			phrase = @"sending a file...";
		// chatActionCancel and anything unknown clear it.
		int64_t actingChat = [obj[@"chat_id"] longLongValue];
		int64_t actor = [obj[@"sender_id"][@"user_id"] longLongValue];
		NSMutableDictionary *acting = self.client.chatsById[@(actingChat)];
		// A group says who is typing; a private chat does not need to name the
		// only other person in it. Your own action is not shown to you.
		if (phrase && actor && [acting[@"isGroup"] boolValue] &&
				actor != [self.client.me[@"id"] longLongValue]){
			NSString *name = [self.client nameForUserId:actor];
			if (name.length)
				phrase = [NSString stringWithFormat:@"%@: %@", name, phrase];
		}
		// The chat list shows this in place of the preview, so it has to live
		// on the chat rather than only reach whichever chat is open.
		if (acting){
			acting[@"action"] = phrase ?: @"";
			[self.client markChatRowDirty:actingChat];
		}
		if (self.client.onChatAction)
			self.client.onChatAction(actingChat, phrase);
		return YES;
	}

	// Whether a supergroup is a forum is a property of the supergroup, not of
	// the chat, and it arrives in an update of its own. Chats already built
	// from that supergroup have to be told.
	case TGUpdateSupergroup: {
		NSDictionary *group = obj[@"supergroup"];
		NSNumber *groupId = group[@"id"];
		if (!groupId)
			return YES;
		BOOL isForum = [group[@"is_forum"] boolValue];
		if ([self.client.forumSupergroups[groupId] boolValue] == isForum &&
			self.client.forumSupergroups[groupId])
			return YES;
		self.client.forumSupergroups[groupId] = @(isForum);

		for (NSMutableDictionary *chat in self.client.chatsById.allValues){
			if (![chat[@"supergroupId"] isEqual:groupId])
				continue;
			chat[@"isForum"] = @(isForum);
			[self.client markChatRowDirty:[chat[@"id"] longLongValue]];
		}
		return YES;
	}

	// A private chat's id is the user's id, so presence lands straight on the
	// chat the list is drawing.
	case TGUpdateUserStatus: {
		int64_t userId = [obj[@"user_id"] longLongValue];
		if (self.client.rawUsersById[@(userId)] && [obj[@"status"] isKindOfClass:NSDictionary.class]){
			NSMutableDictionary *cachedUser = [self.client.rawUsersById[@(userId)] mutableCopy];
			cachedUser[@"status"] = obj[@"status"];
			self.client.rawUsersById[@(userId)] = cachedUser;
		}
		NSMutableDictionary *chat = self.client.chatsById[obj[@"user_id"]];
		// Presence screens (chat header, profile status) hear this even when
		// the user sits in no loaded chat.
		[[NSNotificationCenter defaultCenter]
				postNotificationName:TGUserStatusChangedNotification
							  object:nil
							userInfo:@{@"userId" : @(userId)}];
		if (!chat)
			return YES;
		BOOL online = [obj[@"status"][@"@type"] isEqualToString:@"userStatusOnline"];
		if ([chat[@"isOnline"] boolValue] == online)
			return YES;
		chat[@"isOnline"] = @(online);
		[self.client markChatRowDirty:userId];
		return YES;
	}

	case TGUpdateChatActionBar: {
		// The bar over a chat nobody knows follows the update, not only the
		// fetch; whichever chat is open hears the notification and redraws.
		int64_t chatId = [obj[@"chat_id"] longLongValue];
		NSMutableDictionary *row = self.client.chatsById[@(chatId)];
		if (row){
			[self.client mergeActionBar:obj[@"action_bar"] intoChatRow:row];
			[self.client markChatRowDirty:chatId];
		}
		[[NSNotificationCenter defaultCenter]
				postNotificationName:TGChatActionBarChangedNotification
							  object:@(chatId)];
		return YES;
	}

	case TGUpdateChatFolders: {
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *f in obj[@"chat_folders"]){
			NSString *title = TGUFolderTitle(f);
			// A raw dump only when tdlib's nested naming defeats us again -
			// the syslog line then tells the exact key it moved to.
			if (!title.length)
				NSLog(@"TGClient: B3 chat_folders raw: %@", f);
			[out addObject:@{@"id" : @(f[@"id"] ? [f[@"id"] longLongValue] : 0),
							 @"title" : title}];
		}
		self.client.folders = out;
		NSLog(@"TGClient: %lu folders", (unsigned long)out.count);
		// The chat list learns the pill strip and the All chats merge from
		// this update too; silently returning left both stale until the
		// user wandered into a folder and back. The call site is main.
		[self.client chatsChanged];
		return YES;
	}
	case TGUpdateGroupCall:
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGCallUpdateNotification object:self
						  userInfo:@{@"update" : obj}];
		return YES;
	case TGUpdateGroupCallParticipant:
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGCallUpdateNotification object:self
						  userInfo:@{@"update" : obj}];
		return YES;
	case TGUpdateGroupCallParticipants:
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGCallUpdateNotification object:self
						  userInfo:@{@"update" : obj}];
		return YES;
	case TGUpdateNewGroupCallMessage:
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGCallUpdateNotification object:self
						  userInfo:@{@"update" : obj}];
		return YES;
	case TGUpdateGroupCallMessagesDeleted:
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGCallUpdateNotification object:self
						  userInfo:@{@"update" : obj}];
		return YES;
	case TGUpdateGroupCallMessageSendFailed:
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGCallUpdateNotification object:self
						  userInfo:@{@"update" : obj}];
		return YES;
	case TGUpdateDirectMessagesChatTopic:
		[self.client applyDirectMessagesChatTopic:obj[@"topic"]];
		return YES;
	case TGUpdateTextCompositionStyles:
		[self.client applyTextCompositionStylesUpdate:obj];
		return YES;
	case TGUpdateStakeDiceState:
		[self.client applyStakeDiceStateUpdate:obj];
		return YES;
	case TGUpdateChatEmojiStatus: {
		// The badge on a chat: keep it on the row, and tell an open profile.
		[self.client applyChatUpdate:obj];
		NSNumber *chatId = obj[@"chat_id"];
		if (chatId)
			[[NSNotificationCenter defaultCenter]
					postNotificationName:TGFullInfoChangedNotification object:self
								userInfo:@{@"kind" : @"chat", @"id" : chatId}];
		return YES;
	}
	case TGUpdateUnreadChatCount: {
		NSLog(@"TGClient: %@ total=%@ list=%@", type, obj[@"total_count"],
				obj[@"chat_list"][@"@type"]);
		return YES;
	}
	default:
		return YES;

	}
	return NO;
}

@end

// vim:ft=objc
