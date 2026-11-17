//
// TGInternalLinkRoute.h - where an in-app link opens, decided from TDLib's
// InternalLinkType rather than from the link's path.
//
// Pure: the chat asks getInternalLinkType, hands the answer here and acts on
// the route. Only the link types this client has a screen for get one; the
// rest answer nil and keep the old path.
//
#import <Foundation/Foundation.h>

/// @{route, ...} or nil. Routes:
///   instantView    url, fallback     - the reader; fallback opens when no page
///   story          username, storyId - storyId 0: the poster's current stories
///   directMessages username          - the channel's direct messages chat
///   settings       page              - "appearance", "folders", "data",
///                                      "language", "notifications",
///                                      "powerSaving", "privacy", "sessions",
///                                      "editProfile" or "root"; a
///                                      subsection with its own page gives
///                                      "blocked", "passcode", "proxy",
///                                      "autosave", "storage",
///                                      "wallpaper", "autoNight", or
///                                      "privacyRule" with rule (the
///                                      privacy setting key)
///   tab            name, section     - "calls", "contacts" (section "new" is
///                                      the Add Contact form), "profile"
FOUNDATION_EXPORT NSDictionary *TGInternalLinkRoute(NSDictionary *type);
