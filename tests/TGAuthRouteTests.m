// TGAuthRouteTests.m - a signed-out release launch opens login, not the chat list.
//
// The release 1.3 IPA opened on "Chats / Loading..." on a fresh install: the
// WaitPhoneNumber branch kept the dev showcase's chat list without a TG_DEV
// guard, and the login screen was only reachable from Settings.
#import "TGTestRunner.h"
#import "TGAuthRoute.h"

@interface TGAuthRouteTests : XCTestCase
@end

@implementation TGAuthRouteTests

- (void)testReleaseSignedOutLaunchOpensLogin {
	XCTAssertEqual(TGAuthScreenForState(TGAuthStateWaitPhoneNumber, NO, NO), TGAuthScreenLogin);
}

- (void)testReleaseLaterSignInStepsOpenLoginEvenWhenNotYetShown {
	TGAuthState steps[] = {
		TGAuthStateWaitCode, TGAuthStateWaitPassword, TGAuthStateWaitEmailAddress,
		TGAuthStateWaitEmailCode, TGAuthStateWaitRegistration,
		TGAuthStateWaitOtherDeviceConfirmation,
	};
	for (size_t i = 0; i < sizeof(steps) / sizeof(steps[0]); i++)
		XCTAssertEqual(TGAuthScreenForState(steps[i], NO, NO), TGAuthScreenLogin);
}

- (void)testDevShowcaseKeepsChatListWhileSignedOut {
	XCTAssertEqual(TGAuthScreenForState(TGAuthStateWaitPhoneNumber, NO, YES), TGAuthScreenMain);
	XCTAssertEqual(TGAuthScreenForState(TGAuthStateWaitCode, NO, YES), TGAuthScreenMain);
}

- (void)testOpenLoginStaysOpenInEveryBuild {
	XCTAssertEqual(TGAuthScreenForState(TGAuthStateWaitPhoneNumber, YES, YES), TGAuthScreenLogin);
	XCTAssertEqual(TGAuthScreenForState(TGAuthStateWaitCode, YES, NO), TGAuthScreenLogin);
}

- (void)testSignedInShowsChatList {
	XCTAssertEqual(TGAuthScreenForState(TGAuthStateReady, YES, NO), TGAuthScreenMain);
}

/// Log Out put the empty chat list up until the next client asked for a phone.
- (void)testLogOutWaitsOnASpinnerInRelease {
	XCTAssertEqual(TGAuthScreenForState(TGAuthStateClosed, NO, NO), TGAuthScreenLoading);
	XCTAssertEqual(TGAuthScreenForState(TGAuthStateLoggingOut, NO, NO), TGAuthScreenLoading);
	XCTAssertEqual(TGAuthScreenForState(TGAuthStateClosed, NO, YES), TGAuthScreenMain);
}

- (void)testUnknownStateLeavesScreen {
	XCTAssertEqual(TGAuthScreenForState(TGAuthStateUnknown, NO, NO), TGAuthScreenKeep);
}

- (void)testFirstLaunchWaitsForTheAuthStateInsteadOfTheChatList {
	XCTAssertEqual(TGLaunchScreenForSession(NO, NO), TGAuthScreenLoading);
}

- (void)testSignedInLaunchOpensTheChatListAtOnce {
	XCTAssertEqual(TGLaunchScreenForSession(YES, NO), TGAuthScreenMain);
}

- (void)testDevLaunchKeepsTheShowcaseChats {
	XCTAssertEqual(TGLaunchScreenForSession(NO, YES), TGAuthScreenMain);
	XCTAssertEqual(TGLaunchScreenForSession(YES, YES), TGAuthScreenMain);
}

/// After Log Out the dev build kept the old account's screens and never
/// opened login: the showcase stood in for login for the rest of the run.
- (void)testLogOutOpensLoginEvenInTheDevBuild {
	BOOL showcase = TGAuthShowcaseStandsIn(YES, YES);
	XCTAssertFalse(showcase);
	XCTAssertEqual(TGAuthScreenForState(TGAuthStateLoggingOut, NO, showcase), TGAuthScreenLoading);
	XCTAssertEqual(TGAuthScreenForState(TGAuthStateClosed, NO, showcase), TGAuthScreenLoading);
	XCTAssertEqual(TGAuthScreenForState(TGAuthStateWaitPhoneNumber, NO, showcase), TGAuthScreenLogin);
	// A fresh dev launch with no account still opens on the showcase.
	XCTAssertTrue(TGAuthShowcaseStandsIn(YES, NO));
	XCTAssertFalse(TGAuthShowcaseStandsIn(NO, NO));
}

@end
