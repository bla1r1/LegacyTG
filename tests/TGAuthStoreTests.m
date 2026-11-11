// TGAuthStoreTests.m - the request shapes the sign-in screens depend on.
//
// TGAccountStore owns the authorization requests; the login screens name the
// step and the store builds the TDLib object. TDJSON is never loaded here, so
// the outbox holds exactly what the server would have seen.
#import "TGTestRunner.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGAccountStore.h"

@interface TGAuthStoreTests : XCTestCase
@end

static TGClient *TGAUClient(void) {
	TGClient *c = TGClient.shared;
	[c.outbox removeAllObjects];
	[c.pendingRequests removeAllObjects];
	return c;
}

static NSDictionary *TGAUDecode(NSData *data) {
	NSString *json = [[NSString alloc] initWithData:data
										   encoding:NSUTF8StringEncoding];
	NSString *trimmed = [json componentsSeparatedByString:@"\0"][0];
	return [NSJSONSerialization JSONObjectWithData:
			[trimmed dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
}

static NSDictionary *TGAURequest(TGClient *c, NSString *type) {
	NSDictionary *found = nil;
	for (NSData *data in c.outbox){
		NSDictionary *request = TGAUDecode(data);
		if ([request[@"@type"] isEqualToString:type])
			found = request;
	}
	return found;
}

/// Answers the last request that carried @extra, as tdjson's result does.
static void TGAUAnswer(TGClient *c, NSDictionary *answer) {
	NSDictionary *sent = nil;
	for (NSData *data in c.outbox){
		NSDictionary *request = TGAUDecode(data);
		if (request[@"@extra"])
			sent = request;
	}
	if (!sent)
		return;
	NSMutableDictionary *reply = [answer mutableCopy];
	reply[@"@extra"] = sent[@"@extra"];
	[c handleUpdate:reply];
}

@implementation TGAuthStoreTests

- (void)setUp {
	[super setUp];
	TGAUClient();
}

#pragma mark - the phone, code and password steps

- (void)testSendPhoneNumberRequestShape {
	TGClient *c = TGAUClient();
	c.available = YES;
	c.authState = TGAuthStateWaitPhoneNumber;
	[[TGAccountStore shared] sendPhoneNumber:@"+15551234567"];
	NSDictionary *request = TGAURequest(c, @"setAuthenticationPhoneNumber");
	XCTAssertNotNil(request);
	XCTAssertEqualObjects(request[@"phone_number"], @"+15551234567");
	c.available = NO;
}

- (void)testSendCodeRequestShape {
	TGClient *c = TGAUClient();
	[[TGAccountStore shared] sendCode:@"12345"];
	NSDictionary *request = TGAURequest(c, @"checkAuthenticationCode");
	XCTAssertNotNil(request);
	XCTAssertEqualObjects(request[@"code"], @"12345");
}

- (void)testSendPasswordRequestShape {
	TGClient *c = TGAUClient();
	[[TGAccountStore shared] sendPassword:@"hunter2"];
	NSDictionary *request = TGAURequest(c, @"checkAuthenticationPassword");
	XCTAssertNotNil(request);
	XCTAssertEqualObjects(request[@"password"], @"hunter2");
}

- (void)testResendCodeRequestShape {
	TGClient *c = TGAUClient();
	[[TGAccountStore shared] resendAuthenticationCode];
	NSDictionary *request = TGAURequest(c, @"resendAuthenticationCode");
	XCTAssertNotNil(request);
}

#pragma mark - registration, email and recovery

- (void)testRegisterRequestShape {
	TGClient *c = TGAUClient();
	[[TGAccountStore shared] registerWithFirstName:@"Ada"
										  lastName:@"Lovelace"
										completion:nil];
	NSDictionary *request = TGAURequest(c, @"registerUser");
	XCTAssertNotNil(request);
	XCTAssertEqualObjects(request[@"first_name"], @"Ada");
	XCTAssertEqualObjects(request[@"last_name"], @"Lovelace");
	XCTAssertFalse([request[@"disable_notification"] boolValue]);
}

- (void)testSendEmailAddressRequestShape {
	TGClient *c = TGAUClient();
	[[TGAccountStore shared] sendEmailAddress:@"ada@example.com"];
	NSDictionary *request = TGAURequest(c, @"setAuthenticationEmailAddress");
	XCTAssertNotNil(request);
	XCTAssertEqualObjects(request[@"email_address"], @"ada@example.com");
}

- (void)testSendEmailCodeRequestShape {
	TGClient *c = TGAUClient();
	[[TGAccountStore shared] sendEmailCode:@"54321"];
	NSDictionary *request = TGAURequest(c, @"checkAuthenticationEmailCode");
	XCTAssertNotNil(request);
	XCTAssertEqualObjects(request[@"code"][@"@type"],
						  @"emailAddressAuthenticationCode");
	XCTAssertEqualObjects(request[@"code"][@"code"], @"54321");
}

- (void)testPasswordRecoveryRequestShape {
	TGClient *c = TGAUClient();
	[[TGAccountStore shared] requestPasswordRecoveryWithCompletion:nil];
	NSDictionary *request = TGAURequest(c, @"requestAuthenticationPasswordRecovery");
	XCTAssertNotNil(request);
}

- (void)testRecoverPasswordRequestShape {
	TGClient *c = TGAUClient();
	[[TGAccountStore shared] recoverPasswordWithCode:@"654321" completion:nil];
	NSDictionary *checked =
			TGAURequest(c, @"checkAuthenticationPasswordRecoveryCode");
	XCTAssertNotNil(checked);
	XCTAssertEqualObjects(checked[@"recovery_code"], @"654321");
	TGAUAnswer(c, @{@"@type" : @"ok"});
	NSDictionary *request = TGAURequest(c, @"recoverAuthenticationPassword");
	XCTAssertNotNil(request);
	XCTAssertEqualObjects(request[@"recovery_code"], @"654321");
	XCTAssertEqualObjects(request[@"new_password"], @"");
	XCTAssertEqualObjects(request[@"new_hint"], @"");
}

#pragma mark - QR, web tokens and push codes

- (void)testRequestQrCodeRequestShape {
	TGClient *c = TGAUClient();
	[[TGAccountStore shared] requestQrCodeAuthentication];
	NSDictionary *request = TGAURequest(c, @"requestQrCodeAuthentication");
	XCTAssertNotNil(request);
	XCTAssertEqualObjects(request[@"other_user_ids"], @[]);
}

- (void)testConfirmQrLinkRequestShape {
	TGClient *c = TGAUClient();
	[[TGAccountStore shared] confirmQrCodeAuthenticationLink:@"tg://login?token=1"
												completion:nil];
	NSDictionary *request = TGAURequest(c, @"confirmQrCodeAuthentication");
	XCTAssertNotNil(request);
	XCTAssertEqualObjects(request[@"link"], @"tg://login?token=1");
}

- (void)testWebTokenRequestShape {
	TGClient *c = TGAUClient();
	[[TGAccountStore shared] checkAuthenticationWebToken:@"token"
												   dcId:2
											 completion:nil];
	NSDictionary *request = TGAURequest(c, @"checkAuthenticationWebToken");
	XCTAssertNotNil(request);
	XCTAssertEqualObjects(request[@"token"], @"token");
	XCTAssertEqual([request[@"dc_id"] intValue], 2);
}

- (void)testFirebaseSmsRequestShape {
	TGClient *c = TGAUClient();
	[[TGAccountStore shared] sendAuthenticationFirebaseSms:@"secret"
											   completion:nil];
	NSDictionary *request = TGAURequest(c, @"sendAuthenticationFirebaseSms");
	XCTAssertNotNil(request);
	XCTAssertEqualObjects(request[@"token"], @"secret");
}

- (void)testReportCodeMissingRequestShape {
	TGClient *c = TGAUClient();
	[[TGAccountStore shared] reportAuthenticationCodeMissing];
	NSDictionary *request = TGAURequest(c, @"reportAuthenticationCodeMissing");
	XCTAssertNotNil(request);
}

#pragma mark - countries

- (void)testPhoneNumberInfoRequestShape {
	TGClient *c = TGAUClient();
	[[TGAccountStore shared] phoneNumberInfoForPrefix:@"+1555" completion:nil];
	NSDictionary *request = TGAURequest(c, @"getPhoneNumberInfo");
	XCTAssertNotNil(request);
	XCTAssertEqualObjects(request[@"phone_number_prefix"], @"+1555");
}

- (void)testCountriesRequestShape {
	TGClient *c = TGAUClient();
	[[TGAccountStore shared] countriesWithCompletion:nil];
	NSDictionary *request = TGAURequest(c, @"getCountries");
	XCTAssertNotNil(request);
}

@end
