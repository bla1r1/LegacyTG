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

- (void)testSignedInAndClosedShowChatList {
	XCTAssertEqual(TGAuthScreenForState(TGAuthStateReady, YES, NO), TGAuthScreenMain);
	XCTAssertEqual(TGAuthScreenForState(TGAuthStateClosed, NO, NO), TGAuthScreenMain);
	XCTAssertEqual(TGAuthScreenForState(TGAuthStateLoggingOut, NO, NO), TGAuthScreenMain);
}

- (void)testUnknownStateLeavesScreen {
	XCTAssertEqual(TGAuthScreenForState(TGAuthStateUnknown, NO, NO), TGAuthScreenKeep);
}

@end
