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
	TGAuthScreenLogin
};

/// `loginOpen`: the login screen is already the root. `devShowcase`: the dev
/// build's fixture chats should stay reachable while signed out.
FOUNDATION_EXTERN TGAuthScreen TGAuthScreenForState(TGAuthState state, BOOL loginOpen, BOOL devShowcase);
