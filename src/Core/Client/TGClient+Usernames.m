//
// TGClient+Usernames.m - account and supergroup usernames, the group profile
// switches, and the two default administrator-rights presets.
//
// Every request here names its failure. A username can be taken, a group can
// refuse a forum conversion, and default rights are bot-only: the screen needs
// Telegram's sentence rather than a boolean that says only "no".
//
#import "TGClient+Usernames.h"
#import "TGClientInternal.h"

/// The one string a profile tab is called by in a row, and the TDLib object
/// behind it. TDLib sends main_profile_tab as an object; the screens deal in
/// words so a choice list has something to show.
NSString *TGProfileTabName(NSDictionary *tab) {
	if (![tab isKindOfClass:NSDictionary.class])
		return @"posts";
	NSString *type = tab[@"@type"];
	if (![type hasPrefix:@"profileTab"])
		return @"posts";
	NSString *suffix = [type substringFromIndex:@"profileTab".length];
	if (!suffix.length)
		return @"posts";
	NSString *first = [[suffix substringToIndex:1] lowercaseString];
	return [first stringByAppendingString:[suffix substringFromIndex:1]];
}

NSDictionary *TGProfileTabObject(NSString *name) {
	static NSArray *known = nil;
	if (!known)
		known = @[@"posts", @"media", @"files", @"links", @"music", @"voice", @"gifs"];
	NSString *use = [name isKindOfClass:NSString.class] ? name : @"posts";
	if (![known containsObject:use])
		use = @"posts";
	NSString *suffix = [[use substringToIndex:1] uppercaseString];
	suffix = [suffix stringByAppendingString:[use substringFromIndex:1]];
	return @{@"@type" : [@"profileTab" stringByAppendingString:suffix]};
}

/// Every rights boolean TDLib expects. A missing one is not a default; it is
/// a malformed object that Telegram rejects.
static NSDictionary *TGRights(BOOL manage, BOOL info, BOOL post, BOOL edit,
							  BOOL deleteMessages, BOOL invite, BOOL restrictMembers,
							  BOOL pin, BOOL topics, BOOL promote, BOOL video,
							  BOOL postStories, BOOL editStories, BOOL deleteStories,
							  BOOL directMessages, BOOL tags, BOOL welcome,
							  BOOL anonymous) {
	return @{
		@"@type"                       : @"chatAdministratorRights",
		@"can_manage_chat"             : @(manage),
		@"can_change_info"             : @(info),
		@"can_post_messages"           : @(post),
		@"can_edit_messages"           : @(edit),
		@"can_delete_messages"         : @(deleteMessages),
		@"can_invite_users"            : @(invite),
		@"can_restrict_members"        : @(restrictMembers),
		@"can_pin_messages"            : @(pin),
		@"can_manage_topics"           : @(topics),
		@"can_promote_members"         : @(promote),
		@"can_manage_video_chats"      : @(video),
		@"can_post_stories"            : @(postStories),
		@"can_edit_stories"            : @(editStories),
		@"can_delete_stories"          : @(deleteStories),
		@"can_manage_direct_messages"  : @(directMessages),
		@"can_manage_tags"             : @(tags),
		@"can_send_welcome_messages"   : @(welcome),
		@"is_anonymous"                : @(anonymous),
	};
}

@implementation TGClient (Usernames)

#pragma mark - the account

#pragma mark - a supergroup or channel

#pragma mark - default administrator rights

+ (NSDictionary *)administratorRightsForPreset:(NSString *)preset {
	BOOL full = [preset isEqualToString:@"full"];
	BOOL posting = full || [preset isEqualToString:@"posting"];
	BOOL standard = posting || [preset isEqualToString:@"standard"];
	BOOL readOnly = [preset isEqualToString:@"readonly"];
	if (!standard && !readOnly)
		standard = YES;
	return TGRights(standard, standard, posting, posting, standard, standard,
					standard, standard, standard, full, standard,
					full, full, full, full, full, full, full);
}

@end
