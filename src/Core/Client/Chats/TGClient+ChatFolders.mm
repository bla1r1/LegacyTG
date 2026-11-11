#import "TGClient+ChatFolders.h"
#import "TGClientInternal.h"
#include <vector>
#include <algorithm>
#ifndef typeof
#define typeof __typeof__
#endif



/// The kind of the last message, for the list's preview glyph. A text row
/// has no glyph; every other kind names the picture or symbol the row draws.
static NSString *TGChatPreviewKind(NSDictionary *last) {
	NSDictionary *content = [last[@"content"] isKindOfClass:NSDictionary.class]
			? last[@"content"] : nil;
	NSString *type = content[@"@type"];
	if (![type isKindOfClass:NSString.class] || !type.length)
		return @"";
	if ([type isEqualToString:@"messageText"])
		return @"text";
	if ([type isEqualToString:@"messagePhoto"]) return @"photo";
	if ([type isEqualToString:@"messageVideo"]) return @"video";
	if ([type isEqualToString:@"messageAnimation"]) return @"gif";
	if ([type isEqualToString:@"messageVoiceNote"]) return @"voice";
	if ([type isEqualToString:@"messageVideoNote"]) return @"videoNote";
	if ([type isEqualToString:@"messageSticker"]) return @"sticker";
	if ([type isEqualToString:@"messageDocument"]) return @"file";
	if ([type isEqualToString:@"messageAudio"]) return @"audio";
	if ([type isEqualToString:@"messagePoll"]) return @"poll";
	if ([type isEqualToString:@"messageLocation"] ||
		[type isEqualToString:@"messageVenue"] ||
		[type isEqualToString:@"messageLiveLocation"]) return @"location";
	if ([type isEqualToString:@"messageContact"]) return @"contact";
	if ([type isEqualToString:@"messageGame"]) return @"game";
	if ([type isEqualToString:@"messageCall"]) return @"call";
	if ([type isEqualToString:@"messageDice"]) return @"dice";
	if ([type isEqualToString:@"messageChecklist"]) return @"checklist";
	if ([type hasPrefix:@"messageGift"] || [type hasPrefix:@"messageGiveaway"])
		return @"gift";
	return @"media";
}

/// The smallest file behind a media preview. A photo names its size record; a
/// video, GIF, document or sticker names its thumbnail. Nil for text, a poll
/// and the kinds the row draws as a glyph only.
static NSNumber *TGChatPreviewFileId(NSDictionary *last) {
	NSDictionary *content = [last[@"content"] isKindOfClass:NSDictionary.class]
			? last[@"content"] : nil;
	if (!content) return nil;
	NSString *type = content[@"@type"];
	NSNumber *fileId = nil;
	if ([type isEqualToString:@"messagePhoto"]){
		NSArray *sizes = content[@"photo"][@"sizes"];
		if ([sizes isKindOfClass:NSArray.class] && sizes.count)
			fileId = sizes.firstObject[@"photo"][@"id"];
	} else if ([type isEqualToString:@"messageVideo"]){
		fileId = content[@"video"][@"thumbnail"][@"file"][@"id"];
	} else if ([type isEqualToString:@"messageAnimation"]){
		fileId = content[@"animation"][@"thumbnail"][@"file"][@"id"];
	} else if ([type isEqualToString:@"messageDocument"]){
		fileId = content[@"document"][@"thumbnail"][@"file"][@"id"];
	} else if ([type isEqualToString:@"messageAudio"]){
		fileId = content[@"audio"][@"album_cover_thumbnail"][@"file"][@"id"];
	} else if ([type isEqualToString:@"messageSticker"]){
		fileId = content[@"sticker"][@"thumbnail"][@"file"][@"id"];
	}
	return [fileId isKindOfClass:NSNumber.class] && fileId.longLongValue > 0
			? fileId : nil;
}

@implementation TGClient (ChatFolders)

#pragma mark - chat folders, the writing half

/// A folder as TDLib wants one back. Every field of chatFolder has to be
/// present on an edit - it replaces the folder rather than patching it - so
/// this builds a whole one and the callers change what they mean to change.
static NSDictionary *TGFolderObject(NSString *name, NSString *icon,
									NSArray *chatIds, NSDictionary *basedOn) {
	NSMutableDictionary *folder = [(basedOn ?: @{}) mutableCopy];
	folder[@"@type"] = @"chatFolder";
	if (name.length)
		folder[@"name"] = @{@"@type" : @"chatFolderName",
							@"text"  : @{@"@type" : @"formattedText",
										 @"text"  : name},
							@"animate_custom_emoji" : @NO};
	if (icon.length)
		folder[@"icon"] = @{@"@type" : @"chatFolderIcon", @"name" : icon};
	if (chatIds)
		folder[@"included_chat_ids"] = chatIds;

	// Defaults for whatever a new folder did not say. A folder with every
	// include_* off and no chats in it is one TDLib rejects.
	NSDictionary *defaults = @{
		@"color_id"             : @(-1),
		@"is_shareable"         : @NO,
		@"pinned_chat_ids"      : @[],
		@"included_chat_ids"    : @[],
		@"excluded_chat_ids"    : @[],
		@"exclude_muted"        : @NO,
		@"exclude_read"         : @NO,
		@"exclude_archived"     : @NO,
		@"include_contacts"     : @NO,
		@"include_non_contacts" : @NO,
		@"include_bots"         : @NO,
		@"include_groups"       : @NO,
		@"include_channels"     : @NO,
	};
	for (NSString *key in defaults)
		if (!folder[key])
			folder[key] = defaults[key];

	// chatFolderInfo carries an id and chatFolder does not; an edit built on
	// what getChatFolder answered would otherwise send it back.
	[folder removeObjectForKey:@"id"];
	[folder removeObjectForKey:@"has_my_invite_links"];
	return folder;
}

- (void)createFolderNamed:(NSString *)name
					 icon:(NSString *)icon
				withChats:(NSArray *)chatIds
			   completion:(void (^)(NSInteger folderId))completion {
	if (!name.length){
		if (completion) completion(0);
		return;
	}
	[self request:@{@"@type"  : @"createChatFolder",
					@"folder" : TGFolderObject(name, icon, chatIds ?: @[], nil)}
	   completion:^(NSDictionary *result){
		if (completion)
			completion([result[@"id"] integerValue]);
	}];
}

/// The folder as it stands, so an edit can be built on it rather than
/// replacing the parts it was not asked about.
- (void)folderDetails:(NSInteger)folderId
		   completion:(void (^)(NSDictionary *folder))completion {
	[self request:@{@"@type" : @"getChatFolder", @"chat_folder_id" : @(folderId)}
	   completion:^(NSDictionary *result){
		if (completion)
			completion([result[@"@type"] isEqualToString:@"chatFolder"] ? result : nil);
	}];
}

/// Reads the folder, changes the one thing, sends the whole of it back -
/// which is the only way editChatFolder works.
- (void)editFolder:(NSInteger)folderId
			  name:(NSString *)name
			 chats:(NSArray *)chatIds
		completion:(void (^)(BOOL ok))completion {
	__weak typeof(self) weakSelf = self;
	[self folderDetails:folderId completion:^(NSDictionary *current){
		TGClient *me = weakSelf;
		if (!me || !current){
			if (completion) completion(NO);
			return;
		}
		[me request:@{@"@type"          : @"editChatFolder",
					  @"chat_folder_id" : @(folderId),
					  @"folder"         : TGFolderObject(name, nil, chatIds, current)}
		completion:^(NSDictionary *result){
			if (completion)
				completion([result[@"@type"] isEqualToString:@"chatFolderInfo"]);
		}];
	}];
}

/// Deleting a folder does not leave the chats in it; `leaveChatIds` is for
/// the ones you also want out of, and is usually empty.
- (void)deleteFolder:(NSInteger)folderId leavingChats:(NSArray *)leaveChatIds {
	[self send:@{
		@"@type"          : @"deleteChatFolder",
		@"chat_folder_id" : @(folderId),
		@"leave_chat_ids" : leaveChatIds ?: @[],
	}];
}

/// The order of the pill strip. "All chats" is a position in that order
/// rather than a folder, which is what main_chat_list_position is.
- (void)reorderFolderIds:(NSArray *)folderIds mainListAt:(NSInteger)position {
	if (!folderIds.count)
		return;
	[self send:@{
		@"@type"                  : @"reorderChatFolders",
		@"chat_folder_ids"        : folderIds,
		@"main_chat_list_position": @(position),
	}];
}

/// The strip was dragged into a new order. Local first, wire second: the
/// strip re-renders from self.folders, so the drag must land there before
/// anything else happens - and the wire request answers only later, which
/// would otherwise snap the pills back while the flight is underway. A
/// folder the dragged order forgot rides at the end; losing one from the
/// strip is worse than a slot TDLib never asked to hold.
- (void)reorderFoldersToLocalIds:(NSArray *)folderIds
					 mainListAt:(NSInteger)position {
	NSMutableArray *out = [NSMutableArray array];
	for (NSNumber *entry in folderIds ?: @[]){
		for (NSDictionary *folder in self.folders)
			if ([folder[@"id"] integerValue] ==
					[entry longLongValue]){
				if ([out indexOfObject:folder] == NSNotFound)
					[out addObject:folder];
				break;
			}
	}
	for (NSDictionary *folder in self.folders)
		if ([out indexOfObject:folder] == NSNotFound)
			[out addObject:folder];
	self.folders = out;
	[self chatsChanged];
	[self send:@{
		@"@type"                  : @"reorderChatFolders",
		@"chat_folder_ids"        : folderIds ?: @[],
		@"main_chat_list_position": @(position),
	}];
}

/// The badge on a folder pill or "All chats" counts a chat list, and TDLib
/// keeps that count per list - readChatList zeroes it in one request, the
/// way a chat's own unread count zeroes behind readChat. folderId 0 is the
/// main list, which is what the strip's "All chats" stands for; archived
/// asks for the Archive list on its own, which the archive screen shows.
- (void)refreshArchiveChatListSettings:(void (^)(void))completion {
	[self request:@{@"@type" : @"getArchiveChatListSettings"}
	   completion:^(NSDictionary *result){
		self.archiveSettings =
				[result isKindOfClass:NSDictionary.class] &&
				result.count ? result : @{};
		if (completion)
			completion();
	}];
}

/// One TDLib object holds all three, so one call sets all three: flipping a
/// switch on the page reads the page's copy, flips its bit and sends the
/// whole object again.
- (void)setArchiveSettingsArchiveAndMute:(BOOL)archiveAndMute
					 keepUnmutedArchived:(BOOL)keepUnmuted
				   keepFolderChatsArchived:(BOOL)keepFolders {
	NSDictionary *settings = @{
		@"@type" : @"archiveChatListSettings",
		@"archive_and_mute_new_chats_from_unknown_users" : @(archiveAndMute),
		@"keep_unmuted_chats_archived"                   : @(keepUnmuted),
		@"keep_chats_from_folders_archived"              : @(keepFolders),
	};
	// The local copy moves first: the switches re-render off
	// archiveSettings, so a change that only goes out on the wire would
	// flicker back while the round trip is still in the air.
	self.archiveSettings = settings;
	[self send:@{@"@type" : @"setArchiveChatListSettings",
				 @"settings" : settings}];
}

/// Telegram's own suggestions - Unread, Personal, Groups and so on - each
/// with the sentence their client shows under it. Entries carry "title",
/// "description" and "folder", the last being ready for createChatFolder.
- (void)recommendedFoldersWithCompletion:(void (^)(NSArray *folders))completion {
	[self request:@{@"@type" : @"getRecommendedChatFolders"}
	   completion:^(NSDictionary *result){
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *entry in result[@"chat_folders"]){
			NSDictionary *folder = entry[@"folder"];
			if (![folder isKindOfClass:NSDictionary.class])
				continue;
			[out addObject:@{
				@"title"       : TGPlainTitle(folder[@"name"]) ?: @"",
				@"description" : entry[@"description"] ?: @"",
				@"folder"      : folder,
			}];
		}
		if (completion)
			completion(out);
	}];
}

/// Adopts one of those suggestions as it stands.
- (void)createRecommendedFolder:(NSDictionary *)folder
					 completion:(void (^)(NSInteger folderId))completion {
	if (![folder isKindOfClass:NSDictionary.class]){
		if (completion) completion(0);
		return;
	}
	[self request:@{@"@type"  : @"createChatFolder",
					@"folder" : TGFolderObject(nil, nil, nil, folder)}
	   completion:^(NSDictionary *result){
		if (completion)
			completion([result[@"id"] integerValue]);
	}];
}

- (void)closeChat:(int64_t)chatId {
	[self send:@{
		@"@type"   : @"closeChat",
		@"chat_id" : @(chatId),
	}];
}

/// Archiving is a move between the two chat lists, not a flag on the chat.
/// TDLib answers with updateChatPosition, so the list rebuilds itself.
- (void)setChat:(int64_t)chatId archived:(BOOL)archived {
	[self send:@{
		@"@type"     : @"addChatToList",
		@"chat_id"   : @(chatId),
		@"chat_list" : @{@"@type" : (archived ? @"chatListArchive" : @"chatListMain")},
	}];
}

/// setChatNotificationSettings replaces the whole record. Muting therefore
/// rewrites every field from the chat's current record; sending only the mute
/// pair reset the custom sound, previews, story flags and mention switches.
static NSDictionary *TGChatNotificationSettingsRecord(NSDictionary *current, BOOL muted) {
	if (![current isKindOfClass:NSDictionary.class])
		current = @{};
	return @{
		@"@type"                : @"chatNotificationSettings",
		@"use_default_mute_for" : @NO,
		@"mute_for"             : @(muted ? 365 * 24 * 3600 : 0),
		@"use_default_sound"    : current[@"use_default_sound"] ?: @YES,
		@"sound_id"             : current[@"sound_id"] ?: @(0),
		@"use_default_show_preview" : current[@"use_default_show_preview"] ?: @YES,
		@"show_preview"         : current[@"show_preview"] ?: @YES,
		@"use_default_mute_stories" : current[@"use_default_mute_stories"] ?: @YES,
		@"mute_stories"         : current[@"mute_stories"] ?: @NO,
		@"use_default_story_sound" : current[@"use_default_story_sound"] ?: @YES,
		@"story_sound_id"       : current[@"story_sound_id"] ?: @(0),
		@"use_default_show_story_poster" :
				current[@"use_default_show_story_poster"] ?: @YES,
		@"show_story_poster"    : current[@"show_story_poster"] ?: @YES,
		@"use_default_disable_pinned_message_notifications" :
				current[@"use_default_disable_pinned_message_notifications"] ?: @YES,
		@"disable_pinned_message_notifications" :
				current[@"disable_pinned_message_notifications"] ?: @NO,
		@"use_default_disable_mention_notifications" :
				current[@"use_default_disable_mention_notifications"] ?: @YES,
		@"disable_mention_notifications" :
				current[@"disable_mention_notifications"] ?: @NO,
	};
}

- (void)setChat:(int64_t)chatId muted:(BOOL)muted {
	NSDictionary *current = self.chatsById[@(chatId)][@"notificationSettings"];
	[self send:@{
		@"@type" : @"setChatNotificationSettings",
		@"chat_id" : @(chatId),
		@"notification_settings" :
				TGChatNotificationSettingsRecord(current, muted),
	}];
}

/// Member count for a group, so the chat header can carry a subtitle.
- (void)memberCountForChat:(int64_t)chatId completion:(void (^)(NSInteger count))completion {
	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
	   completion:^(NSDictionary *chat){
		NSDictionary *type = chat[@"type"];
		NSString *t = type[@"@type"];
		if ([t isEqualToString:@"chatTypeBasicGroup"]){
			[self request:@{@"@type" : @"getBasicGroupFullInfo",
							@"basic_group_id" : type[@"basic_group_id"]}
			   completion:^(NSDictionary *full){
				if (completion) completion([full[@"members"] count]);
			}];
		} else if ([t isEqualToString:@"chatTypeSupergroup"]){
			[self request:@{@"@type" : @"getSupergroupFullInfo",
							@"supergroup_id" : type[@"supergroup_id"]}
			   completion:^(NSDictionary *full){
				if (completion) completion([full[@"member_count"] integerValue]);
			}];
		} else if (completion){
			completion(0);
		}
	}];
}

/// A group's ChatMemberStatus is a member when it is not left or banned; a
/// restricted member says so itself. This is deliberately permissive for a
/// record without a status, so a malformed answer cannot invent a Join bar.
static BOOL TGGroupStatusIsMember(NSDictionary *status) {
	NSString *kind = status[@"@type"];
	if ([kind isEqualToString:@"chatMemberStatusLeft"] ||
		[kind isEqualToString:@"chatMemberStatusBanned"])
		return NO;
	if ([kind isEqualToString:@"chatMemberStatusRestricted"])
		return [status[@"is_member"] boolValue];
	if ([kind isEqualToString:@"chatMemberStatusCreator"] &&
		status[@"is_member"])
		return [status[@"is_member"] boolValue];
	return YES;
}

/// The chat kind is always asked of getChat: a public chat opened from a
/// profile is not in chatsById, and the cached-row miss used to read as a
/// private chat with a presence line and "Mute channel". Nothing goes into
/// chatsById: that is the chat list's source, and a channel you only looked at
/// must not join it.
- (void)chatKindForChat:(int64_t)chatId
			 completion:(void (^)(NSDictionary *kind))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
	   completion:^(NSDictionary *chat){
		TGClient *me = weakSelf;
		if (!me || ![chat[@"@type"] isEqualToString:@"chat"]){
			if (completion) completion(nil);
			return;
		}

		NSDictionary *type = chat[@"type"];
		NSString *typeName = type[@"@type"];
		BOOL isSupergroup = [typeName isEqualToString:@"chatTypeSupergroup"];
		BOOL isBasicGroup = [typeName isEqualToString:@"chatTypeBasicGroup"];
		BOOL isGroup = isSupergroup || isBasicGroup;
		BOOL isChannel = isSupergroup && [type[@"is_channel"] boolValue];

		NSMutableDictionary *answer = [@{
			@"isGroup"     : @(isGroup),
			@"isChannel"   : @(isChannel),
			@"isMember"    : @YES,
			@"memberCount" : @0,
			@"status"      : @"",
			@"silent"      : @([chat[@"default_disable_notification"] boolValue]),
		} mutableCopy];
		if (!isGroup){
			if (completion) completion(answer);
			return;
		}

		void (^collect)(NSDictionary *) = ^(NSDictionary *group){
			TGClient *again = weakSelf;
			if (!again || !group[@"id"]){
				if (completion) completion(nil);
				return;
			}
			NSDictionary *status = [group[@"status"] isKindOfClass:NSDictionary.class]
					? group[@"status"] : @{};
			BOOL member = TGGroupStatusIsMember(status);
			BOOL isDirectGroup = [group[@"is_direct_messages_group"] boolValue];
			if (isDirectGroup) {
				member = YES;
				answer[@"isDirectMessages"] = @YES;
			}
			answer[@"isMember"] = @(member);
			answer[@"status"] = status[@"@type"] ?: @"";
			// An anonymous owner or admin posts as the group; the composer
			// says so ("Send anonymously").
			BOOL anonymous = [status[@"is_anonymous"] boolValue] ||
					([status[@"rights"] isKindOfClass:NSDictionary.class] &&
					 [status[@"rights"][@"is_anonymous"] boolValue]);
			answer[@"canBeAnonymous"] = @(anonymous && !isChannel);
			answer[@"memberCount"] = group[@"member_count"] ?: @0;
			if (completion) completion(answer);
		};

		if (isSupergroup){
			[me request:@{@"@type" : @"getSupergroup",
						  @"supergroup_id" : type[@"supergroup_id"]}
			 completion:collect];
		} else {
			[me request:@{@"@type" : @"getBasicGroup",
						  @"basic_group_id" : type[@"basic_group_id"]}
			 completion:collect];
		}
	}];
}

- (void)joinChat:(int64_t)chatId completion:(void (^)(BOOL ok, BOOL requestSent))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"joinChat", @"chat_id" : @(chatId)}
	   completion:^(NSDictionary *result){
		NSString *kind = result[@"@type"];
		BOOL ok = [kind isEqualToString:@"ok"] || [kind isEqualToString:@"chatJoinResultSuccess"];
		BOOL reqSent = [kind isEqualToString:@"chatJoinResultRequestSent"] ||
			([kind isEqualToString:@"error"] && [result[@"message"] isKindOfClass:NSString.class] &&
			 [result[@"message"] rangeOfString:@"INVITE_REQUEST_SENT"].location != NSNotFound);
		if (ok) {
			[weakSelf send:@{
				@"@type"     : @"addChatToList",
				@"chat_id"   : @(chatId),
				@"chat_list" : @{@"@type" : @"chatListMain"},
			}];
		}
		if (completion)
			completion(ok, reqSent);
	}];
}

/// The chat's action bar: its kind, the words a join request says, and the
/// account details a report-and-block dialog carries for the contacts form.
- (void)mergeActionBar:(NSDictionary *)bar intoChatRow:(NSMutableDictionary *)row {
	NSString *kind = [bar isKindOfClass:NSDictionary.class] ? bar[@"@type"] : @"";
	if (!kind.length){
		[row removeObjectForKey:@"actionBarKind"];
		[row removeObjectForKey:@"actionBarText"];
		[row removeObjectForKey:@"actionBarAccount"];
		return;
	}
	row[@"actionBarKind"] = kind;
	if ([kind isEqualToString:@"chatActionBarReportAddBlock"]){
		NSString *first = bar[@"account_info"][@"first_name"] ?: @"";
		NSString *last  = bar[@"account_info"][@"last_name"] ?: @"";
		NSString *name  = [[NSString stringWithFormat:@"%@ %@", first, last]
				stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		row[@"actionBarAccount"] = @{
			@"name"  : name.length ? name : @"",
			@"first" : first,
			@"last"  : last,
			@"phone" : bar[@"account_info"][@"phone_number"] ?: @"",
		};
	} else {
		[row removeObjectForKey:@"actionBarAccount"];
	}
	if ([kind isEqualToString:@"chatActionBarJoinRequest"])
		row[@"actionBarText"] = bar[@"title"] ?: @"";
	else
		[row removeObjectForKey:@"actionBarText"];
}

/// The chat with yourself is Saved Messages everywhere in Telegram, not a
/// conversation under your own name and photo. mergeChat can run before the
/// getMe answer supplies the id, so this also runs when me arrives.
- (void)markSavedMessagesRow {
	int64_t savedId = [self savedMessagesChatId];
	if (savedId == 0)
		return;
	NSMutableDictionary *info = self.chatsById[@(savedId)];
	if (!info)
		return;
	info[@"title"] = @"Saved Messages";
	info[@"isSaved"] = @YES;
	[info removeObjectForKey:@"photoFileId"];
	// Everything in Saved Messages is yours, so there is no "You" author.
	[info removeObjectForKey:@"lastAuthor"];
	[self markChatRowDirty:savedId];
}

- (void)mergeChat:(NSDictionary *)chat {
	if (![chat isKindOfClass:NSDictionary.class])
		return;

	NSNumber *chatId = chat[@"id"];
	if (!chatId)
		return;

	NSMutableDictionary *info = self.chatsById[chatId];
	if (!info){
		info = [NSMutableDictionary dictionary];
		self.chatsById[chatId] = info;
	}

	info[@"id"] = chatId;
	if (chat[@"title"])
		info[@"title"] = chat[@"title"];

	// The bar over a chat nobody knows: report spam, add to contacts, share
	// a phone number. Telegram hands the kind over with the chat and again
	// in an update, so both write through the same helper.
	[self mergeActionBar:chat[@"action_bar"] intoChatRow:info];
	if (chat[@"title"])
		info[@"title"] = chat[@"title"];

	// The chat with yourself is Saved Messages everywhere in Telegram, not a
	// conversation under your own name and photo.
	if ([chatId longLongValue] == [self savedMessagesChatId] &&
		[self savedMessagesChatId] != 0)
		[self markSavedMessagesRow];
	// The badge after the title: a premium person's status, a channel's.
	// Kept as the bare id so the list's saved snapshot can carry it.
	if ([chat[@"emoji_status"] isKindOfClass:NSDictionary.class])
		info[@"emojiStatusId"] = @(TGEmojiStatusCustomEmojiId(chat[@"emoji_status"]));
	if (chat[@"unread_count"])
		info[@"unread"] = chat[@"unread_count"];
	if (chat[@"unread_mention_count"])
		info[@"unreadMentions"] = chat[@"unread_mention_count"];
	if (chat[@"unread_reaction_count"])
		info[@"unreadReactions"] = chat[@"unread_reaction_count"];
	if (chat[@"unread_poll_vote_count"])
		info[@"unreadPollVotes"] = chat[@"unread_poll_vote_count"];
	if ([chat[@"chat_lists"] isKindOfClass:NSArray.class]){
		info[@"chatLists"] = chat[@"chat_lists"];
		NSMutableArray *folderIds = [NSMutableArray array];
		for (id item in chat[@"chat_lists"]){
			if (![item isKindOfClass:NSDictionary.class])
				continue;
			NSNumber *folderId = item[@"chat_folder_id"];
			if ([folderId isKindOfClass:NSNumber.class])
				[folderIds addObject:folderId];
		}
		if (folderIds.count)
			info[@"folderIds"] = folderIds;
	}
	// The dot you put there yourself, which is not the unread count: a chat
	// with nothing unread can still be marked, and the menu has to know.
	if (chat[@"is_marked_as_unread"])
		info[@"markedUnread"] = chat[@"is_marked_as_unread"];
	if (chat[@"last_read_outbox_message_id"])
		info[@"readOutbox"] = chat[@"last_read_outbox_message_id"];
	if (chat[@"last_read_inbox_message_id"])
		info[@"readInbox"] = chat[@"last_read_inbox_message_id"];

	NSString *chatType = chat[@"type"][@"@type"];
	if (chatType){
		info[@"isGroup"] = @(![chatType isEqualToString:@"chatTypePrivate"] &&
							 ![chatType isEqualToString:@"chatTypeSecret"]);
		// Secrets speak their own dialect to the server, and the search is
		// the one request that has to know: searchSecretMessages is the
		// only spelling TDLib answers there.
		info[@"isSecret"] = @([chatType isEqualToString:@"chatTypeSecret"]);
		// A channel opens without a composer until TDLib says who may post.
		info[@"isChannel"] = @([chatType isEqualToString:@"chatTypeSupergroup"] &&
							   [chat[@"type"][@"is_channel"] boolValue]);
	}

	// A forum keeps several threads in one chat, so it opens on a topic list
	// rather than a merged stream. The flag is on the supergroup, not here:
	// the chat only names which supergroup it is, and reading is_forum off the
	// chat - which has no such field - meant no forum was ever recognised.
	NSNumber *supergroupId = chat[@"type"][@"supergroup_id"];
	if (supergroupId){
		info[@"supergroupId"] = supergroupId;
		NSNumber *known = self.forumSupergroups[supergroupId];
		if (known){
			info[@"isForum"] = known;
		} else {
			// Not seen yet: ask, and the answer updates the row in place.
			__weak typeof(self) weakSelf = self;
			[self request:@{@"@type" : @"getSupergroup",
							@"supergroup_id" : supergroupId}
			   completion:^(NSDictionary *group){
				TGClient *me = weakSelf;
				if (!me || !group[@"id"])
					return;
				me.forumSupergroups[group[@"id"]] = @([group[@"is_forum"] boolValue]);
				NSMutableDictionary *row = me.chatsById[chatId];
				row[@"isForum"] = @([group[@"is_forum"] boolValue]);
				[me rebuildChats];
			}];
		}
	}
	if (chat[@"positions"]){
		info[@"order"] = @(TGMainListOrder(chat[@"positions"]));
		info[@"archiveOrder"] = @(TGArchiveOrder(chat[@"positions"]));
		info[@"isPinned"] = @(TGPinnedInMain(chat[@"positions"]));
	}
	if (chat[@"notification_settings"]){
		info[@"notificationSettings"] = chat[@"notification_settings"];
		info[@"isMuted"] = @([chat[@"notification_settings"][@"mute_for"] integerValue] > 0);
	}
	if (chat[@"reply_markup_message_id"])
		info[@"replyMarkupMessageId"] = chat[@"reply_markup_message_id"];

	// Small avatar, if the chat has one. Downloaded lazily; the id is enough
	// for the UI to ask for it later.
	NSNumber *photoFile = chat[@"photo"][@"small"][@"id"];
	if (photoFile)
		info[@"photoFileId"] = photoFile;

	NSString *draft = chat[@"draft_message"][@"input_message_text"][@"text"][@"text"];
	info[@"draft"] = draft ?: @"";

	NSDictionary *last = chat[@"last_message"];
	if ([last isKindOfClass:NSDictionary.class]){
		info[@"text"] = [self previewForLastMessage:last inChat:info];
		info[@"date"] = last[@"date"] ?: @(0);
	} else {
		[info removeObjectForKey:@"previewCustomEmoji"];
	}

	if (self.updateCoalescer) {
		[self.updateCoalescer markChatDirty:[chat[@"id"] longLongValue]];
		[self.updateCoalescer markOrderDirty];
	}
	[self rebuildChats];
}

/// In a group the list shows who spoke last - "Назар: text" - which is the
/// only way to tell a busy group apart at a glance. The speaker and the bare
/// text are also kept apart ("lastAuthor", "previewText") so the list can set
/// the name in its own colour; your own messages are "You" anywhere but in
/// Saved Messages, where everything is yours.
- (NSString *)previewForLastMessage:(NSDictionary *)last inChat:(NSMutableDictionary *)info {
	NSString *text = TGMessagePreview(last);
	info[@"previewText"] = text ?: @"";
	info[@"previewKind"] = TGChatPreviewKind(last);
	NSNumber *previewFileId = TGChatPreviewFileId(last);
	if (previewFileId)
		info[@"previewFileId"] = previewFileId;
	else
		[info removeObjectForKey:@"previewFileId"];
	NSString *reactionSummary = TGReactionSummary(last);
	if (reactionSummary.length)
		info[@"previewReactionSummary"] = reactionSummary;
	else
		[info removeObjectForKey:@"previewReactionSummary"];
	NSNumber *pollVotes = last[@"content"][@"poll"][@"total_voter_count"];
	if ([pollVotes isKindOfClass:NSNumber.class] && pollVotes.integerValue > 0)
		info[@"previewPollVotes"] = pollVotes;
	else
		[info removeObjectForKey:@"previewPollVotes"];
	info[@"lastFailed"] = @([last[@"sending_state"][@"@type"]
			isEqualToString:@"messageSendingStateFailed"]);
	info[@"lastId"] = last[@"id"] ?: @(0);
	info[@"lastOutgoing"] = @([last[@"is_outgoing"] boolValue]);
	[info removeObjectForKey:@"lastAuthor"];

	NSDictionary *content = [last[@"content"] isKindOfClass:NSDictionary.class] ? last[@"content"] : nil;
	NSDictionary *formatted = nil;
	if (content) {
		NSString *ctype = content[@"@type"];
		if ([ctype isEqualToString:@"messageText"]) {
			formatted = [content[@"text"] isKindOfClass:NSDictionary.class] ? content[@"text"] : nil;
		} else if ([content[@"caption"] isKindOfClass:NSDictionary.class]) {
			formatted = content[@"caption"];
		}
	}
	NSString *messageText = [formatted isKindOfClass:NSDictionary.class] ? formatted[@"text"] : nil;
	NSArray *entities = [formatted isKindOfClass:NSDictionary.class] ? formatted[@"entities"] : nil;
	NSArray *customEmoji = TGPreviewCustomEmoji(text, messageText, entities);
	if (customEmoji.count) {
		info[@"previewCustomEmoji"] = customEmoji;
	} else {
		[info removeObjectForKey:@"previewCustomEmoji"];
	}

	// "Alice joined the group" already names Alice; "Alice: " in front of it
	// would say it twice, and "You: You pinned..." reads worse.
	if (TGServicePreview(last))
		return text;
	if ([last[@"is_outgoing"] boolValue]){
		if (![info[@"isSaved"] boolValue])
			info[@"lastAuthor"] = @"You";
		return text;
	}
	if (![info[@"isGroup"] boolValue])
		return text;

	int64_t sender = [last[@"sender_id"][@"user_id"] longLongValue];
	NSString *who = [self nameForUserId:sender];
	if (!who.length){
		// Not known yet: fetch it, and put it on the row when it lands.
		// Rebuilding alone was not enough - it re-sorts the lists and does
		// not run this method again, so a group whose speaker was unknown
		// when the chat arrived stayed nameless until some later update
		// happened to rewrite its preview.
		__weak typeof(self) weakSelf = self;
		int64_t chatId = [info[@"id"] longLongValue];
		[self ensureUserName:sender completion:^{
			TGClient *me = weakSelf;
			if (!me)
				return;
			NSString *name = [me nameForUserId:sender];
			// mergeChat may have replaced the dictionary since; the one in
			// the table is the one the list reads.
			NSMutableDictionary *row = chatId ? me.chatsById[@(chatId)] : info;
			if (name.length && [row isKindOfClass:NSMutableDictionary.class])
				row[@"lastAuthor"] = name;
			[me rebuildChats];
		}];
		return text;
	}
	info[@"lastAuthor"] = who;
	return [NSString stringWithFormat:@"%@: %@", who, text];
}

- (int64_t)lastReadInboxForChat:(int64_t)chatId {
	return [self.chatsById[@(chatId)][@"readInbox"] longLongValue];
}

- (void)applyChatUpdate:(NSDictionary *)update {
	NSNumber *chatId = update[@"chat_id"];
	if (!chatId)
		return;

	NSMutableDictionary *info = self.chatsById[chatId];
	if (!info){
		info = [NSMutableDictionary dictionary];
		info[@"id"] = chatId;
		self.chatsById[chatId] = info;
	}

	if (update[@"title"])
		info[@"title"] = update[@"title"];
	if (update[@"unread_count"])
		info[@"unread"] = update[@"unread_count"];
	if (update[@"is_marked_as_unread"])
		info[@"markedUnread"] = update[@"is_marked_as_unread"];
	// The @ and the reaction badge are counted apart from unread_count: a
	// mention in a muted group is the one thing that still has to shout.
	if (update[@"unread_mention_count"])
		info[@"unreadMentions"] = update[@"unread_mention_count"];
	if (update[@"unread_reaction_count"])
		info[@"unreadReactions"] = update[@"unread_reaction_count"];
	// updateChatPhoto carries the whole chatPhotoInfo; a chat whose photo was
	// removed sends a null, which has to clear the cached id rather than keep
	// the old face.
	if ([update[@"photo"] isKindOfClass:NSDictionary.class]){
		NSNumber *small = update[@"photo"][@"small"][@"id"];
		if (small)
			info[@"photoFileId"] = small;
	} else if ([update[@"@type"] isEqualToString:@"updateChatPhoto"]){
		[info removeObjectForKey:@"photoFileId"];
	}
	// Group facts the profile reads: who may post, how long messages live,
	// how many of the members are online right now.
	if ([update[@"permissions"] isKindOfClass:NSDictionary.class])
		info[@"permissions"] = update[@"permissions"];
	// The running video chat is an object that a null removes, like the
	// photo and the badge below: the group settings screen opens the call by
	// reading this field off the row.
	if ([update[@"video_chat"] isKindOfClass:NSDictionary.class])
		info[@"videoChat"] = update[@"video_chat"];
	else if ([update[@"@type"] isEqualToString:@"updateChatVideoChat"])
		[info removeObjectForKey:@"videoChat"];
	if (update[@"message_auto_delete_time"])
		info[@"autoDeleteTime"] = update[@"message_auto_delete_time"];
	if (update[@"online_member_count"])
		info[@"onlineMembers"] = update[@"online_member_count"];
	if (update[@"unread_poll_vote_count"])
		info[@"unreadPollVotes"] = update[@"unread_poll_vote_count"];
	if ([update[@"chat_lists"] isKindOfClass:NSArray.class])
		info[@"chatLists"] = update[@"chat_lists"];
	if (update[@"default_disable_notification"])
		info[@"defaultSilent"] = update[@"default_disable_notification"];
	// Fields the list does not draw yet, kept true in the row all the same:
	// the flag arrives update-side and the screen that starts reading one
	// re-reads on TGFullInfoChangedNotification without another merge. The
	// object fields follow the photo pattern - the object sets it, the
	// update's own type arriving cleans it, because a null clears there.
	if ([update[@"block_list"] isKindOfClass:NSDictionary.class])
		info[@"blockList"] = update[@"block_list"];
	else if ([update[@"@type"] isEqualToString:@"updateChatBlockList"])
		[info removeObjectForKey:@"blockList"];
	if (update[@"has_protected_content"])
		info[@"hasProtectedContent"] = update[@"has_protected_content"];
	if (update[@"has_scheduled_messages"])
		info[@"hasScheduledMessages"] = update[@"has_scheduled_messages"];
	if (update[@"view_as_topics"])
		info[@"viewAsTopics"] = update[@"view_as_topics"];
	if (update[@"is_translatable"])
		info[@"isTranslatable"] = update[@"is_translatable"];
	if (update[@"has_welcome_messages"])
		info[@"hasWelcomeMessages"] = update[@"has_welcome_messages"];
	if ([update[@"available_reactions"] isKindOfClass:NSDictionary.class])
		info[@"availableReactions"] = update[@"available_reactions"];
	else if ([update[@"@type"] isEqualToString:@"updateChatAvailableReactions"])
		[info removeObjectForKey:@"availableReactions"];
	// A chat's badge is an object that a null removes, the same shape as the
	// photo and the background above it.
	if ([update[@"emoji_status"] isKindOfClass:NSDictionary.class]){
		info[@"emojiStatus"] = update[@"emoji_status"];
		info[@"emojiStatusId"] = @(TGEmojiStatusCustomEmojiId(update[@"emoji_status"]));
	} else if ([update[@"@type"] isEqualToString:@"updateChatEmojiStatus"]){
		[info removeObjectForKey:@"emojiStatus"];
		[info removeObjectForKey:@"emojiStatusId"];
	}
	if (update[@"theme"])
		info[@"chatTheme"] = update[@"theme"];
	if (update[@"accent_color_id"])
		info[@"accentColorId"] = update[@"accent_color_id"];
	if (update[@"message_sender_id"])
		info[@"messageSender"] = update[@"message_sender_id"];
	if ([update[@"background"] isKindOfClass:NSDictionary.class])
		info[@"chatBackground"] = update[@"background"];
	else if ([update[@"@type"] isEqualToString:@"updateChatBackground"])
		[info removeObjectForKey:@"chatBackground"];
	if (update[@"welcome_messages"] || update[@"messages"])
		info[@"welcomeMessages"] = update[@"welcome_messages"] ?: update[@"messages"];
	// Removed from a list: the order for that list is gone, and without
	// clearing it the row stays on the strip it was just taken off. A chat
	// added to a list carries no order yet - its position follows.
	if ([update[@"@type"] isEqualToString:@"updateChatRemovedFromList"]){
		NSString *listType = update[@"chat_list"][@"@type"];
		if ([listType isEqualToString:@"chatListArchive"])
			info[@"archiveOrder"] = @0;
		else if ([listType isEqualToString:@"chatListMain"])
			info[@"order"] = @0;
	}
	// Typed on another device, or here and then left: the list shows it and
	// the composer is filled from it on open.
	if ([update[@"@type"] isEqualToString:@"updateChatDraftMessage"]){
		NSString *draft = update[@"draft_message"][@"input_message_text"][@"text"][@"text"];
		info[@"draft"] = draft ?: @"";
	}
	if (update[@"last_read_inbox_message_id"])
		info[@"readInbox"] = update[@"last_read_inbox_message_id"];
	if (update[@"last_read_outbox_message_id"]){
		info[@"readOutbox"] = update[@"last_read_outbox_message_id"];
		[[NSNotificationCenter defaultCenter] postNotificationName:TGChatReadOutboxChangedNotification
				object:self userInfo:@{@"chatId": chatId}];
	}

	NSDictionary *last = update[@"last_message"];
	if ([last isKindOfClass:NSDictionary.class]){
		info[@"text"] = [self previewForLastMessage:last inChat:info];
		info[@"date"] = last[@"date"] ?: @(0);
	}

	if ([update[@"notification_settings"] isKindOfClass:NSDictionary.class]){
		info[@"notificationSettings"] = update[@"notification_settings"];
		info[@"isMuted"] = @([update[@"notification_settings"][@"mute_for"] integerValue] > 0);
	}
	if (update[@"positions"]){
		info[@"order"] = @(TGMainListOrder(update[@"positions"]));
		info[@"archiveOrder"] = @(TGArchiveOrder(update[@"positions"]));
		info[@"isPinned"] = @(TGPinnedInMain(update[@"positions"]));
	}
	NSDictionary *position = update[@"position"];
	if ([position isKindOfClass:NSDictionary.class]){
		NSString *listType = position[@"list"][@"@type"];
		if ([listType isEqualToString:@"chatListArchive"]){
			info[@"archiveOrder"] = @(TGArchiveOrder(@[position]));
		} else if ([listType isEqualToString:@"chatListMain"]){
			info[@"order"] = @(TGMainListOrder(@[position]));
			info[@"isPinned"] = @(TGPinnedInMain(@[position]));
			// Main and archive are mutually exclusive: a chat that just got a
			// main position died out of the archive, and the stale
			// archiveOrder would otherwise keep it on the archive strip.
			info[@"archiveOrder"] = @0;
		}
		// A chatListFolder position says nothing about the main list: zero
		// order with a pinned reset here used to unpin the chat wholesale
		// every time its folder reshuffled.
	}

	if (self.updateCoalescer) {
		[self.updateCoalescer markChatDirty:[chatId longLongValue]];
		[self.updateCoalescer markOrderDirty];
	}
	[self rebuildChats];
}

- (void)rebuildChats {
	if (self.batchingUpdates){
		self.chatsNeedRebuild = YES;
		return;
	}
	self.chatsNeedRebuild = NO;

	NSArray *all = self.chatsById.allValues;
	NSUInteger count = all.count;
	if (count == 0){
		self.chats = @[];
		self.archivedChats = @[];
		[self chatsChanged];
		if (self.onArchiveChanged) self.onArchiveChanged();
		return;
	}

	struct ChatOrderEntry {
		int64_t order;
		int64_t id_;
		__unsafe_unretained NSDictionary *chat;
	};

	std::vector<ChatOrderEntry> mainVec;
	std::vector<ChatOrderEntry> archiveVec;
	mainVec.reserve(count);
	archiveVec.reserve(count / 4);

	int64_t savedId = [self savedMessagesChatId];
	for (NSDictionary *c in all){
		int64_t cid = [c[@"id"] longLongValue];
		BOOL isSaved = [c[@"isSaved"] boolValue] || (cid == savedId && savedId != 0);
		BOOL isPinned = [c[@"isPinned"] boolValue];
		BOOL hasDraft = [c[@"draft"] length] > 0;
		BOOL hasMessage = [c[@"text"] length] > 0 || [c[@"date"] longLongValue] > 0;
		// Do not show phantom empty chats (e.g. deleted/transferred groups without history)
		if (!isSaved && !isPinned && !hasDraft && !hasMessage)
			continue;

		int64_t archiveOrder = [c[@"archiveOrder"] longLongValue];
		if (archiveOrder > 0){
			archiveVec.push_back({archiveOrder, cid, c});
		} else {
			int64_t mainOrder = [c[@"order"] longLongValue];
			if (mainOrder > 0){
				mainVec.push_back({mainOrder, cid, c});
			}
		}
	}

	auto byOrderDesc = [](const ChatOrderEntry &a, const ChatOrderEntry &b){
		if (a.order != b.order) return a.order > b.order;   // newest first
		return a.id_ > b.id_;
	};

	std::sort(mainVec.begin(), mainVec.end(), byOrderDesc);
	std::sort(archiveVec.begin(), archiveVec.end(), byOrderDesc);

	NSMutableArray *main = [NSMutableArray arrayWithCapacity:mainVec.size()];
	for (const auto &e : mainVec){
		[main addObject:e.chat];
	}

	NSMutableArray *archived = [NSMutableArray arrayWithCapacity:archiveVec.size()];
	for (const auto &e : archiveVec){
		[archived addObject:e.chat];
	}

	self.chats = main;
	self.archivedChats = archived;

	[self chatsChanged];
	if (self.onArchiveChanged)
		self.onArchiveChanged();
}

- (NSNumber *)photoFileIdForChat:(int64_t)chatId {
	// The cache is the source of truth: the wrapper lists (.chats holding
	// only the un-foldered portion, archive the pulled-up one) came and went
	// with the active folder, and a chat opened through a folder used to
	// lose its photo to a nil lookup and render as initials.
	NSDictionary *info = self.chatsById[@(chatId)];
	return info[@"photoFileId"];
}

@end
