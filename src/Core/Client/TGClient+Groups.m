//
// TGClient+Groups.m - making a group, who is in it, and the links that let
// people in.
//
// A chat could be left and read and nothing else: there was no request in
// this app that created one, added anyone, or produced a link. This is that
// half. Basic groups and supergroups differ in where their member list lives
// and in almost nothing else a screen cares about, so the calls here take a
// chat id and work out the rest.
//
#import "TGClientInternal.h"

/// A member as a MessageSender, which is the only way setChatMemberStatus and
/// banChatMember will name one.
NSDictionary *TGMemberSender(int64_t userId) {
	return @{@"@type" : @"messageSenderUser", @"user_id" : @(userId)};
}

/// A member's status as one short word, for a row that has to say what
/// someone is.
NSString *TGMemberStatusName(NSDictionary *status) {
	NSString *kind = status[@"@type"] ?: @"";
	if ([kind isEqualToString:@"chatMemberStatusCreator"])       return @"owner";
	if ([kind isEqualToString:@"chatMemberStatusAdministrator"]) return @"admin";
	if ([kind isEqualToString:@"chatMemberStatusRestricted"])    return @"restricted";
	if ([kind isEqualToString:@"chatMemberStatusBanned"])        return @"banned";
	if ([kind isEqualToString:@"chatMemberStatusLeft"])          return @"left";
	return @"member";
}

@implementation TGClient (Groups)

#pragma mark - making one

/// A basic group is what their New Group makes: up to 200 people, no
/// username, and it becomes a supergroup on its own when it needs to. It must
/// be created with at least one other member - TDLib refuses an empty one.
/// A supergroup or a channel: a username, no member ceiling worth the name,
/// and a history that outlives its members.
- (void)createSupergroupNamed:(NSString *)title
				  description:(NSString *)description
					isChannel:(BOOL)isChannel
				   completion:(void (^)(int64_t chatId))completion {
	if (!title.length){
		if (completion) completion(0);
		return;
	}
	[self request:@{
		@"@type"                    : @"createNewSupergroupChat",
		@"title"                    : title,
		@"is_forum"                 : @NO,
		@"is_channel"               : @(isChannel),
		@"description"              : description ?: @"",
		// A chat that is not tied to a place sends the origin with an empty
		// address; TDLib wants the field whether or not there is a pin.
		@"location"                 : @{
			@"@type"   : @"chatLocation",
			@"location": @{@"@type" : @"location",
						   @"latitude" : @0, @"longitude" : @0,
						   @"horizontal_accuracy" : @0},
			@"address" : @"",
		},
		@"message_auto_delete_time" : @(0),
		@"for_import"               : @NO,
	} completion:^(NSDictionary *result){
		if (completion)
			completion([result[@"id"] longLongValue]);
	}];
}

/// Past 200 members, or when a group needs a username or admins with rights,
/// a basic group has to become a supergroup. The chat id changes.
#pragma mark - who is in it

/// The basic group's record, which is what a basic-group id resolves to before
/// any chat exists in the local database. `getBasicGroupFullInfo` is the other
/// half the profile reads; this one carries the member count and the status
/// word the debug resolver shows beside the name.
/// `forwardLimit` is how much of the history the new member sees in a basic
/// group; a supergroup ignores it and shows everything.
/// The picker's batch, in one request instead of one request per tick.
/// Same failed-half answer as the single-member call, so one sheet covers
/// everyone the server said no to.
/// One member's own record - status, rights, the renewal date of a
/// restriction. The member list is the aggregate; this is the detail.
/// What members of a chat may do, as one of three presets - the full set of
/// fifteen booleans is not a sheet of switches anyone reads on a phone.
/// "All" and "read only" are the two ends, and "text" is the middle TDLib
/// itself keeps: messages and previews, no media.
/// Handing the whole chat over. TDLib demands the password once two-factor
/// authentication is on, which is the request's third field; the confirm
/// sheet says why this one cannot be undone.
/// Search inside a chat's members. An empty query is the whole list, which is
/// how a member screen fills itself. Entries carry "id", "name" and "status".
/// Only the administrators, which is a different request from the members and
/// the only one that says who the owner is. Entries carry "id", "name",
/// "owner" and "editable" - the last says whether this account may change
/// that administrator at all.
/// Promote to administrator, demote back to a plain member, or restrict.
/// `status` is "administrator", "member" or "left"; anything else is refused
/// rather than guessed at, because the wrong one here removes people.
/// Banning is not the same as removing: a banned member cannot come back on
/// an invite link. `revokeMessages` also deletes what they wrote.
#pragma mark - what it is called

/// The supergroup id behind a chat id, asked for rather than guessed:
/// toggles below name a supergroup, all the app has is the chat. A basic
/// group has no supergroup; the completion answers 0 and nobody is toggled.
- (void)supergroupIdForChat:(int64_t)chatId
				 completion:(void (^)(int64_t supergroupId))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
	   completion:^(NSDictionary *chat){
		NSString *kind = chat[@"type"][@"@type"];
		NSString *id_ = chat[@"type"][@"supergroup_id"];
		if ([kind isEqualToString:@"chatTypeSupergroup"] && id_){
			if (completion) completion([id_ longLongValue]);
			return;
		}
		// A basic group turns into a supergroup the moment this matters;
		// the row the list cached can name the newer shape for us.
		id row = weakSelf.chatsById[@(chatId)][@"supergroupId"];
		if ([row isKindOfClass:NSNumber.class] && [row longLongValue]){
			if (completion) completion([row longLongValue]);
			return;
		}
		if (completion) completion(0);
	}];
}

/// Signs what members post with their names, the way a channel wall works.
/// Members who cannot post otherwise - non-admins of a broadcast-style group
/// - are shown the composer only when this is on; on it is private and their
/// posts land in the admins' chat.
/// What the three toggles above sit on right now, read off the supergroup's
/// full record, so a menu row can say what the flip is about to do.
/// Whether the history before a member joined is visible to them. Their
/// client exposes this as a switch on a group that already has some.
- (void)setChat:(int64_t)chatId
		  title:(NSString *)title
	 completion:(void (^)(BOOL ok))completion {
	if (!title.length){
		if (completion) completion(NO);
		return;
	}
	[self request:@{@"@type" : @"setChatTitle", @"chat_id" : @(chatId),
					@"title" : title}
	   completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}

/// A description belongs to a supergroup or a channel; a basic group has
/// nowhere to put one and TDLib says so.
- (void)setChat:(int64_t)chatId
	description:(NSString *)description
	 completion:(void (^)(BOOL ok))completion {
	[self request:@{@"@type" : @"setChatDescription", @"chat_id" : @(chatId),
					@"description" : description ?: @""}
	   completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}

- (void)setChat:(int64_t)chatId
	photoAtPath:(NSString *)path
	 completion:(void (^)(BOOL ok))completion {
	if (!path.length){
		if (completion) completion(NO);
		return;
	}
	[self request:@{
		@"@type"   : @"setChatPhoto",
		@"chat_id" : @(chatId),
		@"photo"   : @{@"@type" : @"inputChatPhotoStatic",
					   @"photo" : @{@"@type" : @"inputFileLocal",
									@"path"  : path}},
	} completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}

#pragma mark - letting people in

/// Every link the chat has, the primary one among them. Entries are flattened
/// to "link", "name", "members", "memberLimit", "primary", "revoked" and
/// "requests".
/// A link of its own, so it can be revoked without taking the chat's primary
/// link down with it. A limit of zero is no limit.
/// The chat's primary link, replaced: the old one stops working at once. This
/// is what their "Revoke Link" on the main link does.
/// What is behind a link before joining it: the name, how many are in, and
/// whether this account is already one of them.
/// People waiting at a link that creates join requests. Entries carry "id",
/// "name" and "date".
- (void)joinRequestsForChat:(int64_t)chatId
				 completion:(void (^)(NSArray *requests))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{
		@"@type"       : @"getChatJoinRequests",
		@"chat_id"     : @(chatId),
		@"invite_link" : @"",
		@"query"       : @"",
		@"limit"       : @(50),
	} completion:^(NSDictionary *result){
		TGClient *me = weakSelf;
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *request in result[@"requests"]){
			int64_t userId = [request[@"user_id"] longLongValue];
			if (!userId)
				continue;
			[out addObject:@{
				@"id"   : @(userId),
				@"name" : [me nameForUserId:userId] ?: @"",
				@"date" : request[@"date"] ?: @(0),
			}];
		}
		if (completion)
			completion(out);
	}];
}

- (void)processJoinRequest:(int64_t)userId
					inChat:(int64_t)chatId
				   approve:(BOOL)approve {
	[self send:@{
		@"@type"   : @"processChatJoinRequest",
		@"chat_id" : @(chatId),
		@"user_id" : @(userId),
		@"approve" : @(approve),
	}];
}

/// A group's sticker shelf is set on the supergroup, not the chat, and this
/// client only ever holds the chat id. A basic group has no supergroup and no
/// shelf, so it answers NO without a request.
#pragma mark - aggressive anti-spam

- (void)setChat:(int64_t)chatId
	aggressiveAntiSpam:(BOOL)on
			 completion:(void (^)(BOOL, NSString *))completion {
	__weak typeof(self) weakSelf = self;
	[self supergroupIdForChat:chatId completion:^(int64_t supergroupId){
		if (!supergroupId){
			if (completion)
				completion(NO, @"Telegram reports anti-spam for supergroups only.");
			return;
		}
		[weakSelf request:@{
			@"@type" : @"toggleSupergroupHasAggressiveAntiSpamEnabled",
			@"supergroup_id" : @(supergroupId),
			@"has_aggressive_anti_spam_enabled" : @(on),
		} completion:^(NSDictionary *result){
			BOOL ok = ![result[@"@type"] isEqualToString:@"error"];
			NSString *message = result[@"message"];
			if (completion)
				completion(ok, ok ? nil : ([message isKindOfClass:NSString.class]
						? message : @"An error occurred."));
		}];
	}];
}

@end

// vim:ft=objc
