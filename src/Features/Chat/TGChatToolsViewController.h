//
// TGChatToolsViewController.h - the per-chat half of Tier 2.
//
// Reached from Group Settings. Everything here changes the chat itself or
// reads what Telegram keeps about it: the event log, statistics, similar
// chats, slow mode, reactions, protected content, themes, the discussion
// group, the location, the local note, member positions and the photo tools.
//
#import <UIKit/UIKit.h>
#import "TGRowsViewController.h"
#import "TGLocalization.h"

@interface TGChatToolsViewController : TGRowsViewController

@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, copy) NSString *chatTitle;
/// Whether the chat is a group or a channel; a private chat has no event log
/// or statistics, and the rows say so rather than failing later.
@property (nonatomic, assign) BOOL isGroup;

@end

/// The section list as plain data. The controller attaches the actions; the
/// order, headers and every title/detail come from here, so a host test can
/// pin them without UIKit.
static inline NSArray *TGChatToolsSectionsModel(NSDictionary *state) {
	NSInteger slowMode = [state[@"slowMode"] integerValue];
	BOOL reactionsAll = [state[@"reactionsAll"] boolValue];
	BOOL protectedContent = [state[@"protectedContent"] boolValue];
	BOOL translatable = [state[@"translatable"] boolValue];
	BOOL defaultSilent = [state[@"defaultSilent"] boolValue];
	NSInteger accentId = [state[@"accentId"] integerValue];
	NSInteger profileAccentId = [state[@"profileAccentId"] integerValue];
	NSString *themeName = state[@"themeName"] ?: @"Default";
	int64_t discussionChatId = [state[@"discussionChatId"] longLongValue];
	NSString *note = state[@"note"] ?: @"";

	NSString *slowModeText = slowMode
			? TGLocalizedFormat(@"%@s", @(slowMode)) : TGLocalized(@"Off");
	return @[
		@{@"header" : TGLocalized(@"Channels"), @"rows" : @[
			@{@"title" : TGLocalized(@"Suggested Chats"), @"opens" : @YES},
		]},
		@{@"header" : TGLocalized(@"Moderation"), @"rows" : @[
			@{@"title" : TGLocalized(@"Slow Mode"), @"detail" : slowModeText},
			@{@"title" : TGLocalized(@"Available Reactions"),
			  @"detail" : reactionsAll ? TGLocalized(@"All")
					  : TGLocalized(@"Some Reactions")},
			@{@"title" : TGLocalized(@"Restrict Saving Content"),
			  @"switch" : @YES, @"on" : @(protectedContent)},
			@{@"title" : TGLocalized(@"Translate"),
			  @"switch" : @YES, @"on" : @(translatable)},
			@{@"title" : TGLocalized(@"Send Without Sound"),
			  @"switch" : @YES, @"on" : @(defaultSilent)},
		]},
		@{@"header" : TGLocalized(@"Appearance"), @"rows" : @[
			@{@"title" : TGLocalized(@"Accent Color"),
			  @"detail" : [NSString stringWithFormat:@"%ld", (long)accentId]},
			@{@"title" : TGLocalized(@"Change Profile Color"),
			  @"detail" : [NSString stringWithFormat:@"%ld", (long)profileAccentId]},
			@{@"title" : TGLocalized(@"Color Theme"), @"detail" : themeName},
			@{@"title" : TGLocalized(@"Wallpaper"), @"detail" : TGLocalized(@"Set")},
			@{@"title" : TGLocalized(@"Reset Chat Wallpapers")},
		]},
		@{@"header" : TGLocalized(@"This Chat"), @"rows" : @[
			@{@"title" : TGLocalized(@"Discussion Group"),
			  @"detail" : discussionChatId ? TGLocalized(@"Linked")
					  : TGLocalized(@"None")},
			@{@"title" : TGLocalized(@"Location")},
			@{@"title" : TGLocalized(@"Local Note"),
			  @"detail" : note.length ? note : TGLocalized(@"None")},
			@{@"title" : TGLocalized(@"Owner After Leaving")},
		]},
		@{@"header" : TGLocalized(@"Photo"), @"rows" : @[
			@{@"title" : TGLocalized(@"Emoji")},
			@{@"title" : TGLocalized(@"Report Profile Photo")},
		]},
		@{@"header" : TGLocalized(@"Join Requests"), @"rows" : @[
			@{@"title" : TGLocalized(@"Approve")},
			@{@"title" : TGLocalized(@"Decline All")},
			@{@"title" : TGLocalized(@"Join Requests")},
		]},
		@{@"header" : TGLocalized(@"Chat Folders"), @"rows" : @[
			@{@"title" : TGLocalized(@"Add to Folder")},
		]},
	];
}
