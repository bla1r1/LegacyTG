//
// TGProfileTabs.h - which tabs a profile shows, in the official client's order.
//
#import <Foundation/Foundation.h>

/// The tab kinds, first to last. `ownPublicProfile` is My Profile: what you publish
/// and your archive, without the Saved Messages chat that shares your user id.
/// `mainKind` is the name from main_profile_tab, which moves its tab to the front.
FOUNDATION_EXPORT NSArray *TGProfileTabKinds(BOOL hasStories, BOOL hasGifts, BOOL hasCommonGroups,
		BOOL ownPublicProfile, NSString *mainKind);

/// The tab strip's entries, @{title, kind}, for those kinds; a channel with
/// similar channels gets that tab last.
FOUNDATION_EXPORT NSArray *TGProfileMediaTabs(NSArray *kinds, BOOL similarChannels);

/// The tab to show: the stored one under its current name (td_api's posts are
/// stories, gifs live in media), or the first tab once the stored one is gone.
FOUNDATION_EXPORT NSString *TGProfileSelectedTabKind(NSString *stored, NSArray *tabs);

/// Stories and the archive are story tiles.
FOUNDATION_EXPORT BOOL TGProfileTabIsStories(NSString *kind);

/// Media, stories, the archive and gifts draw as a grid, the rest as a list.
FOUNDATION_EXPORT BOOL TGProfileTabIsGrid(NSString *kind);
