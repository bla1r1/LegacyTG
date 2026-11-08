//
// TGProfileLogic.h - the profile's small decisions, out of UIKit so the host
// tests can check them.
//
// The card order, the t.me address and the Files/Music/Links filter are all
// data rules. A table view only draws the answer; keeping the rule here means
// a reload cannot quietly put a row back in the wrong place.
//
#import <Foundation/Foundation.h>

/// TDLib's invite link (or a public username) as the address the official
/// card prints: https://t.me/name. External URLs are returned unchanged.
FOUNDATION_EXPORT NSString *TGProfileShortLinkText(NSString *link);

/// The info card for a group or channel, in PeerInfoProfileItems order:
/// community, link, description, settings, then the rows this client keeps
/// on the profile (linked chat, similar channels).
///
/// Keys: communityId, communityName, communitySubtitle, inviteLink, username,
/// description, canManage, isChannel, linkedChatTitle, similarChannelsCount,
/// similarChannelsValue.
FOUNDATION_EXPORT NSArray *TGProfileGroupInfoRows(NSDictionary *info);

/// Files, Music and Links are the panes whose bar button opens a search.
FOUNDATION_EXPORT BOOL TGProfileMediaKindSupportsSearch(NSString *kind);

/// Filters the rows a pane already holds. An empty query returns them all;
/// document names, audio titles/performers and link text match case-insensitively.
FOUNDATION_EXPORT NSArray *TGProfileMediaRowsMatchingQuery(NSArray *rows,
														   NSString *query,
														   NSString *kind);
