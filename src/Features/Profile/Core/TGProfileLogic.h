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

/// A user's info card, in PeerInfoProfileItems order: phone, username,
/// birthday, about (or the scam/fake warning in its place), note, location,
/// then Add to Contacts and Block. Community and the personal channel are
/// separate sections, so they are not rows here.
///
/// Keys: phoneNumber, activeUsernames, username, isScam, isFake, birthday,
/// bio, note, businessLocation, isOwnProfile, isContact, isBot, blocked.
FOUNDATION_EXPORT NSArray *TGProfileUserInfoRows(NSDictionary *info);

/// The info card for a group or channel: link, description, settings. The
/// community is its own section, and the linked chat belongs to the edit
/// screen; similar channels are a media pane. Neither is an info row.
///
/// Keys: inviteLink, username, description, canManage, isChannel.
FOUNDATION_EXPORT NSArray *TGProfileGroupInfoRows(NSDictionary *info);

/// No info row carries a leading glyph in the official card. Kept as a named
/// rule so a row kind cannot quietly grow one again.
FOUNDATION_EXPORT NSString *TGProfileRowGlyphName(NSString *kind);

/// The name under the profile picture. An account without a name falls back
/// to its phone number, as the official header does.
FOUNDATION_EXPORT NSString *TGProfileDisplayName(NSDictionary *user, NSString *phone);

/// Files, Music and Links are the panes whose bar button opens a search.
FOUNDATION_EXPORT BOOL TGProfileMediaKindSupportsSearch(NSString *kind);

/// Filters the rows a pane already holds. An empty query returns them all;
/// document names, audio titles/performers and link text match case-insensitively.
FOUNDATION_EXPORT NSArray *TGProfileMediaRowsMatchingQuery(NSArray *rows,
														   NSString *query,
														   NSString *kind);

/// One info card entry as the shared row that draws it. A labelled value is
/// the title over its detail; an unlabelled one is the title alone. The
/// account's own text is marked raw so the cell cannot translate a bio.
FOUNDATION_EXPORT NSDictionary *TGProfileInfoRowModel(NSDictionary *detail);

/// A member of the group as a TGPeerRow: the face, the name, the role badge,
/// the emoji status and the chevron. The caller passes the emoji status id
/// because the pure model cannot ask TGClient.
FOUNDATION_EXPORT NSDictionary *TGProfileMemberRowModel(NSDictionary *member,
														int64_t statusEmojiId);

/// The red Delete Contact action at the bottom of a profile.
FOUNDATION_EXPORT NSDictionary *TGProfileDangerRowModel(void);

/// The tab strip row for a media pane. The caller sets its tap and hold blocks
/// and, optionally, the offset the strip should keep.
FOUNDATION_EXPORT NSMutableDictionary *TGProfileMediaTabRowModel(NSArray *tabs,
		NSString *selectedKind);

/// Chunks a media list into grid rows of `columns` tiles. `tileForIndex` builds
/// one TGGridRow tile for the global item index; `tap` receives the global
/// index of the tile that was tapped.
FOUNDATION_EXPORT NSArray *TGProfileGridRowModels(NSArray *items,
		NSInteger columns,
		NSDictionary *(^tileForIndex)(NSInteger index),
		void (^tap)(NSInteger index));

/// The profile sections for a fixture. The screen and the host tests read the
/// same order: community, personal channel, card, danger, members, media.
///
/// Keys: details (info dictionaries), community (@{id, title, subtitle,
/// avatar}), personalChannel (@{chatId, title, subtitle, avatar}), members
/// (member dictionaries), danger (BOOL), isChannel, memberCount, mediaTabs
/// (@{title, kind}), mediaKind and mediaRows (already-built content rows).
/// Handler keys: community, channel, detail (NSString kind), danger, member
/// (NSInteger index). Media rows carry their own taps.
FOUNDATION_EXPORT NSArray *TGProfileSectionsForFixture(NSDictionary *fixture);
