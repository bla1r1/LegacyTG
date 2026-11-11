//
// TGGroupLogic.h - the small decisions of the group screens, out of UIKit so
// the host tests can check them.
//
#import <Foundation/Foundation.h>

/// The window "Clear History" sends for a choice: 0 = 1 week, 1 = 1 month,
/// 2 = today. "Today" is local midnight to `now`, not the last 24 hours.
FOUNDATION_EXPORT void TGClearHistoryWindowForChoice(NSInteger choiceIndex,
													 NSDate *now,
													 NSInteger *minDate,
													 NSInteger *maxDate);

/// The link the profile/settings screen copies or opens as the group's main
/// link: the primary when it is alive, otherwise the first alive link. An
/// all-revoked list has no main link.
FOUNDATION_EXPORT NSDictionary *TGInviteLinkPreferred(NSArray *links);

/// A details card built before the chat type answered used the group words;
/// it has to be rebuilt when the type changes and the card already exists.
FOUNDATION_EXPORT BOOL TGProfileTypeChangeNeedsDetailsReload(BOOL wasChannel,
															BOOL isChannel,
															NSUInteger detailsCount);

/// The name a member list row prints. TDLib's member record can carry an
/// empty name while the user record already knows one; the caller falls back
/// to the client and then to the pack's "Member".
FOUNDATION_EXPORT NSString *TGMemberRowName(NSDictionary *member);

/// The pack marks the name in confirmations as **bold**. The alert draws plain
/// text, so the key is looked up with the markers and they are removed after.
FOUNDATION_EXPORT NSString *TGStripBoldMarkers(NSString *text);

/// One member of the group as a TGPeerRow: face, name, role badge, emoji
/// status and chevron. The emoji status id is passed in so the model stays
/// pure; TGGroupStore is asked by the screen.
FOUNDATION_EXPORT NSDictionary *TGGroupMemberRowModel(NSDictionary *member,
													  int64_t statusEmojiId);

/// A group settings value row as the shared cell draws it: the title, the
/// value under it when it has one, the chevron when the tap opens a page and
/// the red title of a destructive action.
FOUNDATION_EXPORT NSDictionary *TGGroupInfoRowModel(NSString *title,
													NSString *detail,
													BOOL opens,
													BOOL destructive,
													BOOL disabled);
