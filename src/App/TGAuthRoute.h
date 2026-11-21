//
// TGAuthRoute - which top-level screen an authorization state asks for.
//
// Kept out of AppDelegate so the decision runs on the host test suite without
// UIKit. The dev build's showcase keeps the chat list up while signed out;
// a release build has no showcase chats, so a signed-out user gets login.
//
#import "TGClientTypes.h"

typedef NS_ENUM(NSInteger, TGAuthScreen) {
	/// Leave whatever is on screen (state not known yet).
	TGAuthScreenKeep = 0,
	TGAuthScreenMain,
	TGAuthScreenLogin,
	/// A spinner until TDLib names the auth state.
	TGAuthScreenLoading
};

/// `loginOpen`: the login screen is already the root. `devShowcase`: the dev
/// build's fixture chats should stay reachable while signed out.
FOUNDATION_EXTERN TGAuthScreen TGAuthScreenForState(TGAuthState state, BOOL loginOpen, BOOL devShowcase);

/// Whether the dev showcase may stand in for login. Only until this run signs
/// out: after Log Out the dev build stayed on the old account's screens (an
/// empty Saved Messages, the fixture chats) and never showed login.
FOUNDATION_EXTERN BOOL TGAuthShowcaseStandsIn(BOOL devBuild, BOOL signedOut);

/// The first screen, before TDLib has said anything. `authorized`: this
/// account slot reached authorizationStateReady before. Without it the chat
/// list would flash "Chats / Loading..." for ~1 s ahead of login.
FOUNDATION_EXTERN TGAuthScreen TGLaunchScreenForSession(BOOL authorized, BOOL devShowcase);
