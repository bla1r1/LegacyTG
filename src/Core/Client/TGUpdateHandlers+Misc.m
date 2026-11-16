//
// TGUpdateHandlers+Misc.m - one family of update* branches.
//
#import "TGUpdateHandlers.h"
#import "TGUpdateHandlersSupport.h"
#import "TGStatusText.h"
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

/// updateFile comes once per network chunk: dozens a second for one file,
/// several files at a time. A progress bar needs ten a second. A step is
/// passed on when 100 ms have gone by since the last one told, when the
/// fraction moved by 5 %, when it reached the end, or when it went backwards
/// (a restart). Completion is not progress and never comes through here.
///
/// A fixed table on the main queue: no boxing, no dictionary. The file that
/// was told longest ago gives up its slot.
enum { kProgressSlots = 16 };
typedef struct {
	NSInteger fileId;
	double at;
	float fraction;
} TGProgressMark;
static TGProgressMark sDownloadMarks[kProgressSlots];
static TGProgressMark sUploadMarks[kProgressSlots];

static BOOL TGProgressWorthTelling(TGProgressMark *marks, NSInteger fileId, float fraction) {
	double now = CFAbsoluteTimeGetCurrent();
	TGProgressMark *slot = NULL;
	TGProgressMark *oldest = &marks[0];
	for (int i = 0; i < kProgressSlots; i++){
		if (marks[i].fileId == fileId){
			slot = &marks[i];
			break;
		}
		if (marks[i].at < oldest->at)
			oldest = &marks[i];
	}
	if (!slot){
		slot = oldest;
		slot->fileId = fileId;
		slot->at = 0;
		slot->fraction = -1.0f;
	}
	BOOL soon = (now - slot->at) < 0.1;
	BOOL smallStep = fraction >= slot->fraction && (fraction - slot->fraction) < 0.05f;
	if (soon && smallStep && fraction < 1.0f)
		return NO;
	slot->at = now;
	slot->fraction = fraction;
	return YES;
}

@implementation TGUpdateHandlers (Misc)

- (BOOL)handleMiscUpdates:(NSString *)type kind:(TGUpdateType)kind obj:(NSDictionary *)obj {
	switch (kind){
	case TGUpdateFile: {
		NSDictionary *file = obj[@"file"];
		NSInteger fid = [file[@"id"] integerValue];
		NSDictionary *local = file[@"local"];
		if (self.client.onFileProgress && [local[@"is_downloading_active"] boolValue]){
			double expected = [file[@"expected_size"] doubleValue];
			double got = [local[@"downloaded_size"] doubleValue];
			if (expected > 0){
				float fraction = (float)(got / expected);
				if (TGProgressWorthTelling(sDownloadMarks, fid, fraction))
					self.client.onFileProgress(fid, fraction);
			}
		}
		if ([file[@"remote"][@"is_uploading_active"] boolValue]){
			double expected = [file[@"expected_size"] doubleValue];
			double uploaded = [file[@"remote"][@"uploaded_size"] doubleValue];
			float fraction = expected > 0 ? (float)(uploaded / expected) : 0.0f;
			// Nothing below is allocated for a step nobody would see.
			if (TGProgressWorthTelling(sUploadMarks, fid, fraction)){
				if (self.client.onFileUploadProgress && expected > 0)
					self.client.onFileUploadProgress(fid, fraction);
				[[NSNotificationCenter defaultCenter]
						postNotificationName:TGFileUploadProgressNotification object:self
									  userInfo:@{@"fileId" : @(fid), @"file" : file}];
				if (expected > 0)
					[self.client noteUploadProgress:fid fraction:fraction];
			}
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

	case TGUpdateSpeechRecognitionTrial: {
		NSNumber *left = obj[@"left_count"];
		if ([left isKindOfClass:NSNumber.class])
			self.client.speechTrialLeftValue = left;
		self.client.speechTrialWeekly = [obj[@"weekly_count"] integerValue];
		self.client.speechTrialResetDate = [obj[@"next_reset_date"] doubleValue];
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
		[self.client tellChat:actingChat action:phrase];
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
		NSNumber *ring = @(TGUStoryRing(group[@"active_story_state"]));
		BOOL forumSame = [self.client.forumSupergroups[groupId] boolValue] == isForum &&
				self.client.forumSupergroups[groupId];
		self.client.forumSupergroups[groupId] = @(isForum);

		for (NSMutableDictionary *chat in self.client.chatsById.allValues){
			if (![chat[@"supergroupId"] isEqual:groupId])
				continue;
			if (forumSame && [chat[@"storyRing"] isEqual:ring])
				continue;
			chat[@"isForum"] = @(isForum);
			chat[@"storyRing"] = ring;
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
		NSTimeInterval now = [NSDate date].timeIntervalSince1970;
		BOOL online = TGUserStatusOnlineAt(obj[@"status"], now);
		NSTimeInterval expires = online ? [obj[@"status"][@"expires"] doubleValue] : 0;
		chat[@"onlineUntil"] = @(expires);
		// TDLib says nothing when the online time runs out, so the dot would
		// stay lit until the next status: one check at the expiry instead.
		if (expires > now){
			TGClient *client = self.client;
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((expires - now + 1) * NSEC_PER_SEC)),
					dispatch_get_main_queue(), ^{
				NSMutableDictionary *row = client.chatsById[@(userId)];
				if (![row[@"onlineUntil"] isEqual:@(expires)] || ![row[@"isOnline"] boolValue])
					return;
				row[@"isOnline"] = @NO;
				[client markChatRowDirty:userId];
			});
		}
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

	case TGUpdateChatBusinessBotManageBar: {
		// The bar a Business bot keeps over a chat it answers in: same
		// redraw path as the action bar.
		int64_t chatId = [obj[@"chat_id"] longLongValue];
		NSMutableDictionary *row = self.client.chatsById[@(chatId)];
		if (row){
			[row removeObjectForKey:@"businessBot"];
			[row addEntriesFromDictionary:TGBusinessBotBarFields(obj[@"business_bot_manage_bar"])];
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
		// Not claimed: "error" has to fall through to handleUpdate's error
		// branch. Claiming everything here swallowed every unclaimed TDLib
		// error, and the login spinner waited forever on a wrong number (B40).
		break;
	}
	return NO;
}

@end

// vim:ft=objc
