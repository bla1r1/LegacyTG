//
// TGAuthRoute.m
//
#import "TGAuthRoute.h"

TGAuthScreen TGAuthScreenForState(TGAuthState state, BOOL loginOpen, BOOL devShowcase) {
	switch (state){
		case TGAuthStateWaitPhoneNumber:
		case TGAuthStateWaitCode:
		case TGAuthStateWaitPassword:
		case TGAuthStateWaitEmailAddress:
		case TGAuthStateWaitEmailCode:
		case TGAuthStateWaitRegistration:
		case TGAuthStateWaitOtherDeviceConfirmation:
			// Official opens on the phone step; a fresh install that lands on
			// an empty chat list never finds Settings > Log in.
			if (loginOpen || !devShowcase)
				return TGAuthScreenLogin;
			return TGAuthScreenMain;
		case TGAuthStateReady:
			return TGAuthScreenMain;
		case TGAuthStateLoggingOut:
		case TGAuthStateClosed:
			// A fresh client's WaitPhoneNumber follows and brings login; the
			// chat list in between flashed empty for ~1 s after Log Out.
			return devShowcase ? TGAuthScreenMain : TGAuthScreenLoading;
		case TGAuthStateUnknown:
		default:
			return TGAuthScreenKeep;
	}
}

BOOL TGAuthShowcaseStandsIn(BOOL devBuild, BOOL signedOut) {
	return devBuild && !signedOut;
}

TGAuthScreen TGLaunchScreenForSession(BOOL authorized, BOOL devShowcase) {
	return (authorized || devShowcase) ? TGAuthScreenMain : TGAuthScreenLoading;
}
