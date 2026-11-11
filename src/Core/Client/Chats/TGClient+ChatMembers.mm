#import "TGClient+ChatMembers.h"
#import "TGClientInternal.h"
#ifndef typeof
#define typeof __typeof__
#endif


@implementation TGClient (ChatMembers)

#pragma mark - members

/// One TDLib member as a row. The role is the status word the group screen
/// and the badge both read, and "owner" is the one status that is allowed to
/// hand the group over - so it travels as a flag rather than being spelled
/// out again by every caller.
NSDictionary *TGMemberRowForMember(NSDictionary *member, NSString *name) {
	if (![member isKindOfClass:NSDictionary.class])
		return nil;
	int64_t userId = [member[@"member_id"][@"user_id"] longLongValue];
	if (!userId)
		return nil;
	NSDictionary *status = [member[@"status"] isKindOfClass:NSDictionary.class]
			? member[@"status"] : @{};
	NSString *word = TGMemberStatusName(status);
	// chatMember.tag is the member's tag, or the custom title when the
	// member is an administrator. It is what the badge shows instead of the
	// generic role word.
	NSString *tag = [member[@"tag"] isKindOfClass:NSString.class]
			? [member[@"tag"] stringByTrimmingCharactersInSet:
					[NSCharacterSet whitespaceAndNewlineCharacterSet]] : @"";
	return @{
		@"id"     : @(userId),
		@"name"   : name ?: @"",
		@"status" : word,
		@"tag"    : tag ?: @"",
		@"owner"  : @([word isEqualToString:@"owner"]),
	};
}

- (void)canSendInChat:(int64_t)chatId completion:(void (^)(BOOL, BOOL))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
	   completion:^(NSDictionary *chat){
		TGClient *me = weakSelf;
		if (!me) {
			if (completion) completion(NO, NO);
			return;
		}
		NSDictionary *type = chat[@"type"];
		BOOL isSupergroup = [type[@"@type"] isEqualToString:@"chatTypeSupergroup"];
		BOOL isChannel = isSupergroup && [type[@"is_channel"] boolValue];
		BOOL canSend = [chat[@"permissions"][@"can_send_basic_messages"] boolValue];
		if (isChannel) {
			canSend = [chat[@"can_be_edited"] boolValue] ||
					  [chat[@"permissions"][@"can_send_basic_messages"] boolValue];
		}
		if (canSend || !isSupergroup) {
			if (completion) completion(canSend, isChannel);
			return;
		}
		[me request:@{@"@type" : @"getSupergroup", @"supergroup_id" : type[@"supergroup_id"]}
		 completion:^(NSDictionary *group){
			BOOL directGroup = [group[@"is_direct_messages_group"] boolValue];
			if (completion) completion(directGroup, isChannel);
		}];
	}];
}

- (void)deleteChat:(int64_t)chatId {
	[self.chatsById removeObjectForKey:@(chatId)];
	[self rebuildChats];

	// A group has to be left as well, or it comes straight back on the next
	// message.
	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
	   completion:^(NSDictionary *chat){
		NSString *kind = chat[@"type"][@"@type"];
		BOOL isMembership = [kind isEqualToString:@"chatTypeSupergroup"] ||
							[kind isEqualToString:@"chatTypeBasicGroup"];
		[self send:@{
			@"@type"       : @"deleteChatHistory",
			@"chat_id"     : @(chatId),
			@"remove_from_chat_list" : @YES,
			@"revoke"      : @NO,
		}];
		if (isMembership)
			[self send:@{@"@type" : @"leaveChat", @"chat_id" : @(chatId)}];
	}];
}

/// Not leaving: the group or channel itself goes, for every member. TDLib
/// only allows it to the owner, and says so otherwise.
- (void)deleteChatForEveryone:(int64_t)chatId completion:(void (^)(NSString *error))completion {
	[self request:@{@"@type" : @"deleteChat", @"chat_id" : @(chatId)}
	   completion:^(NSDictionary *result){
		BOOL ok = [result[@"@type"] isEqualToString:@"ok"];
		if (ok) {
			[self.chatsById removeObjectForKey:@(chatId)];
			[self rebuildChats];
		}
		if (completion)
			completion(ok ? nil : (result[@"message"] ?: @"An error occurred."));
	}];
}

/// The pinned chats in this order, top first. Telegram takes the whole list;
/// a chat left out is unpinned.
- (void)setChat:(int64_t)chatId joined:(BOOL)joined {
	[self send:@{@"@type" : joined ? @"joinChat" : @"leaveChat", @"chat_id" : @(chatId)}];
}

- (void)pinnedMessageForChat:(int64_t)chatId
                  completion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getChatPinnedMessage", @"chat_id" : @(chatId)}
	   completion:^(NSDictionary *m){
		if (completion)
			completion([m[@"@type"] isEqualToString:@"message"] ? TGFlattenMessage(m) : nil);
	}];
}

- (void)setChat:(int64_t)chatId pinned:(BOOL)pinned {
	[self send:@{
		@"@type"     : @"toggleChatIsPinned",
		@"chat_list" : @{@"@type" : @"chatListMain"},
		@"chat_id"   : @(chatId),
		@"is_pinned" : @(pinned),
	}];
}

/// A folder is a chat list of its own in TDLib, so this is getChats against
/// that list; the rows themselves are the ones the client already holds.
- (void)chatsInFolder:(NSInteger)folderId completion:(void (^)(NSArray *))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{
		@"@type"     : @"getChats",
		@"chat_list" : @{@"@type" : @"chatListFolder",
						 @"chat_folder_id" : @(folderId)},
		@"limit"     : @(100),
	} completion:^(NSDictionary *result){
		TGClient *me = weakSelf;
		if (!me){
			if (completion) completion(@[]);
			return;
		}
		NSMutableArray *out = [NSMutableArray array];
		for (NSNumber *chatId in result[@"chat_ids"]){
			NSDictionary *info = me.chatsById[chatId];
			// An unknown id is still a chat the folder holds: this folder
			// walk is often the first time tdlib hears about it, and its
			// info update runs behind the answer. A pending placeholder
			// keeps the merge honest (it counts the drop and retries)
			// instead of shrinking folder lists silently.
			if (info)
				[out addObject:info];
			else
				[out addObject:@{@"id" : chatId, @"pending" : @YES}];
		}
		NSLog(@"TGClient: folder %ld holds %lu chats",
				(long)folderId, (unsigned long)out.count);
		if (completion) completion(out);
	}];
}

/// A topic made: its thread id is what every later edit answers through.
/// A topic made without a name is what tapping "General" makes, and TDLib
/// names it itself.
/// The default set is a sticker set under the hood; only the emoji character
/// and its id matter to the picker, so the thumbnails are left alone.
/// An empty name means "keep the old one", so this touches only the icon.
/// 0 is a real value here: it removes the emoji and leaves the colour.
/// Renaming a topic does not touch its icon; an emoji id renames with it.
/// Closing, pinning and deleting a topic: the one topic, said plainly.
/// A forum shown as one flow of messages instead of a list of topics - the
/// channel's own trick. What it is now is read off the chat, so the flip
/// asks first and then says what it did.
/// The channel's direct-messages group, switched on or off. A non-zero price
/// only travels with the "on" state; TDLib keeps the old price otherwise.
/// Whether a forum is being shown as topics right now, read off the chat.
- (void)chatProfile:(int64_t)chatId completion:(void (^)(NSDictionary *))completion {
	__weak typeof(self) weakSelf = self;
	// The online count only arrives as updateChatOnlineMemberCount and lives
	// on the cached list row, never on the getChat answer below.
	NSNumber *online = weakSelf.chatsById[@(chatId)][@"onlineMembers"];
	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
	   completion:^(NSDictionary *chat){
		NSString *kind = chat[@"type"][@"@type"];
		__block BOOL verified = NO;
		__block BOOL hasDM = NO;
		__block BOOL adminDM = NO;
		void (^answer)(NSDictionary *) = ^(NSDictionary *full){
			int64_t dmId = [full[@"direct_messages_chat_id"] longLongValue];
			int64_t commId = [full[@"community_id"] longLongValue];
			if (completion) completion(@{
				@"description" : full[@"description"] ?: @"",
				@"members"     : full[@"member_count"] ?: @0,
				@"inviteLink"  : full[@"invite_link"][@"invite_link"] ?: @"",
				@"online"      : online ?: @0,
				@"verified"    : @(verified),
				@"linkedChatId": full[@"linked_chat_id"] ?: @0,
				@"directMessagesChatId": @(dmId),
				@"communityId" : @(commId),
				@"hasDirectMessages": @(hasDM || dmId != 0),
				@"canManageDirectMessages": @(adminDM),
			});
		};

		if ([kind isEqualToString:@"chatTypeSupergroup"]){
			NSNumber *supergroupId = chat[@"type"][@"supergroup_id"];
			// The mark is on the supergroup record, not on its full info.
			[weakSelf request:@{@"@type" : @"getSupergroup", @"supergroup_id" : supergroupId}
				   completion:^(NSDictionary *group){
				verified = [group[@"verification_status"][@"is_verified"] boolValue];
				hasDM = [group[@"has_direct_messages_group"] boolValue];
				adminDM = [group[@"is_administered_direct_messages_group"] boolValue];
				[weakSelf request:@{@"@type" : @"getSupergroupFullInfo",
									@"supergroup_id" : supergroupId}
					   completion:answer];
			}];
		} else if ([kind isEqualToString:@"chatTypeBasicGroup"]){
			[weakSelf request:@{@"@type" : @"getBasicGroupFullInfo",
								@"basic_group_id" : chat[@"type"][@"basic_group_id"]}
				   completion:answer];
		} else {
			answer(@{});
		}
	}];
}

- (BOOL)isChatMuted:(int64_t)chatId {
	return [self.chatsById[@(chatId)][@"isMuted"] boolValue];
}

- (BOOL)chatIsSavedMessages:(int64_t)chatId {
	if (chatId != 0 && chatId == [self savedMessagesChatId])
		return YES;
	return [self.chatsById[@(chatId)][@"isSaved"] boolValue];
}

- (void)clearHistoryInChat:(int64_t)chatId {
	[self clearHistoryInChat:chatId revoke:NO];
}

- (void)clearHistoryInChat:(int64_t)chatId revoke:(BOOL)revoke {
	// Without remove_from_chat_list this empties the chat and leaves it there,
	// which is what "clear history" means as opposed to "delete chat".
	[self send:@{
		@"@type"                 : @"deleteChatHistory",
		@"chat_id"               : @(chatId),
		@"remove_from_chat_list" : @NO,
		@"revoke"                : @(revoke),
	}];
}

- (void)setChat:(int64_t)chatId autoDeleteSeconds:(NSInteger)seconds {
	[self send:@{
		@"@type"   : @"setChatMessageAutoDeleteTime",
		@"chat_id" : @(chatId),
		@"message_auto_delete_time" : @(seconds),
	}];
}

- (void)chatWithUsername:(NSString *)username
              completion:(void (^)(int64_t, NSString *))completion {
	// searchPublicChat resolves the name and puts the chat in the local
	// database in one step, which is what a link or a QR code needs.
	[self request:@{
		@"@type"    : @"searchPublicChat",
		@"username" : username ?: @"",
	} completion:^(NSDictionary *chat){
		if (completion)
			completion([chat[@"id"] longLongValue], chat[@"title"]);
	}];
}

- (void)joinChatByInviteLink:(NSString *)inviteLink
                  completion:(void (^)(int64_t, NSString *))completion {
	[self request:@{
		@"@type"       : @"joinChatByInviteLink",
		@"invite_link" : inviteLink ?: @"",
	} completion:^(NSDictionary *chat){
		if (completion)
			completion([chat[@"id"] longLongValue], chat[@"title"]);
	}];
}

- (void)openChat:(int64_t)chatId {
	[self send:@{
		@"@type"   : @"openChat",
		@"chat_id" : @(chatId),
	}];
}

/// The unsent message in the composer, kept on Telegram's side so it is there
/// on the next launch and on every other device. An empty text clears it.
- (void)setDraft:(NSString *)text
		  inChat:(int64_t)chatId
		  thread:(int64_t)threadId
		 replyTo:(int64_t)replyToId {
	NSMutableDictionary *request = [@{
		@"@type"             : @"setChatDraftMessage",
		@"chat_id"           : @(chatId),
		@"message_thread_id" : @(threadId),
	} mutableCopy];

	if (text.length){
		NSMutableDictionary *draft = [@{
			@"@type"                : @"draftMessage",
			@"input_message_text"   : @{
				@"@type" : @"inputMessageText",
				@"text"  : @{@"@type" : @"formattedText", @"text" : text},
			},
		} mutableCopy];
		if (replyToId != 0)
			draft[@"reply_to"] = @{@"@type" : @"inputMessageReplyToMessage",
								   @"message_id" : @(replyToId)};
		request[@"draft_message"] = draft;
	}
	// With no draft_message at all the draft is cleared, which is what an
	// empty composer means.

	[self send:request];

	// The chat list shows the draft in place of the last message, and the
	// update that confirms this takes a round trip.
	NSMutableDictionary *cached = [self.chatsById[@(chatId)] mutableCopy];
	if (cached){
		cached[@"draft"] = text ?: @"";
		self.chatsById[@(chatId)] = cached;
		[self rebuildChats];
	}
}

/// What was last typed into this chat and not sent, from whichever client
/// typed it. Empty when there is none.
- (NSString *)draftForChat:(int64_t)chatId {
	NSString *draft = self.chatsById[@(chatId)][@"draft"];
	return [draft isKindOfClass:NSString.class] ? draft : @"";
}

/// The blue dot you put there yourself. Telegram keeps it per chat, and it
/// survives until the chat is opened.
- (void)setChat:(int64_t)chatId markedUnread:(BOOL)unread {
	[self send:@{
		@"@type"                : @"toggleChatIsMarkedAsUnread",
		@"chat_id"              : @(chatId),
		@"is_marked_as_unread"  : @(unread),
	}];
}

/// Clears the @ and the reaction badge on a chat. Reading the messages does
/// not do it: Telegram counts mentions and reactions separately from unread.
- (void)readAllMentionsAndReactionsInChat:(int64_t)chatId {
	[self send:@{@"@type" : @"readAllChatMentions",  @"chat_id" : @(chatId)}];
	[self send:@{@"@type" : @"readAllChatReactions", @"chat_id" : @(chatId)}];
}

@end
