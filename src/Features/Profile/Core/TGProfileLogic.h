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

/// The business hours row (PeerInfoScreenBusinessHoursItem): "Open · 09:00 –
/// 18:00" or "Closed · Opens in 2 hours" from local_opening_hours (already in
/// the reader's zone), next_open_in and next_close_in, and the week under
/// "week" for the tap. Nil for a profile without hours.
FOUNDATION_EXPORT NSDictionary *TGBusinessHoursRow(NSDictionary *businessInfo, NSTimeInterval now);

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

/// The address a piece of text links to: a text link's own URL, or the first
/// URL typed in it, with http:// added when it has no scheme. Nil when none.
FOUNDATION_EXPORT NSURL *TGProfileFirstURL(NSString *text, NSArray *entities);

/// First and last name joined; either alone when the other is empty. No
/// username or phone fallback: the header shows those on their own rows.
FOUNDATION_EXPORT NSString *TGProfileUserName(NSDictionary *user);

/// The status line a user without presence has, in official's order
/// (PeerInfoData.swift): "support" for Telegram's support accounts, "N users"
/// for a bot with monthly users, else "bot". Nil for everyone else, whose
/// line is their last seen.
FOUNDATION_EXPORT NSString *TGProfileFixedStatus(NSDictionary *user);

/// A per-mille commission as official writes it: 100 -> "10", 125 -> "12.5".
FOUNDATION_EXPORT NSString *TGProfilePermilleText(NSInteger permille);

/// The profile photos as TGMediaViewer items, so a tap opens the picture
/// full screen and a swipe goes through the rest: a photo message each, the
/// small file as its placeholder and the big one as what it opens.
FOUNDATION_EXPORT NSArray *TGProfilePhotoViewerItems(NSArray *photos, int64_t userId);

/// m:ss for a track or voice note; nil for no length.
FOUNDATION_EXPORT NSString *TGProfileDurationText(NSNumber *seconds);

/// The edit screen's Birthday field: "March 5" or "March 5, 1990", no age,
/// through the pack's month keys. Nil when no day is set.
FOUNDATION_EXPORT NSString *TGProfileBirthdayFieldText(NSInteger day, NSInteger month,
		NSInteger year);

/// A profile photo's date in the app's language (medium style), or the
/// "Profile Photos" title for a photo with no date.
FOUNDATION_EXPORT NSString *TGProfilePhotoDateText(double date, NSString *language);
