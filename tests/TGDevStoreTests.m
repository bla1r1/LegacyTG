// TGDevStoreTests.m - the Dev screens' store seam.
//
// The Dev screens are request viewers: every row sends one TDLib request and
// prints the answer. The tests below read the request the store sent and
// assert its @type and fields, which is the whole contract.
#import "TGTestRunner.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGDevStore.h"

@interface TGDevStoreTests : XCTestCase @end

static NSDictionary *TDSDecode(NSData *data) {
	NSString *json = [[NSString alloc] initWithData:data
										   encoding:NSUTF8StringEncoding];
	NSString *trimmed = [json componentsSeparatedByString:@"\0"][0];
	return [NSJSONSerialization JSONObjectWithData:
			[trimmed dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
}

static NSDictionary *TDSRequest(NSString *type) {
	NSDictionary *found = nil;
	for (NSData *data in [TGClient shared].outbox){
		NSDictionary *request = TDSDecode(data);
		if ([request[@"@type"] isEqualToString:type])
			found = request;
	}
	return found;
}

@implementation TGDevStoreTests

- (void)setUp {
	[[TGClient shared].outbox removeAllObjects];
	[[TGClient shared].pendingRequests removeAllObjects];
}

- (void)testBotTokenIsTrimmed {
	[[TGDevStore shared] checkAuthenticationBotToken:@"  123:abc  "
										  completion:^(BOOL ok, NSString *error){}];
	NSDictionary *request = TDSRequest(@"checkAuthenticationBotToken");
	XCTAssertNotNil(request);
	XCTAssertEqualObjects(request[@"token"], @"123:abc");
}

- (void)testEmptyBotTokenDoesNotReachTheOutbox {
	[[TGDevStore shared] checkAuthenticationBotToken:@"   "
										  completion:^(BOOL ok, NSString *error){}];
	XCTAssertNil(TDSRequest(@"checkAuthenticationBotToken"));
}

- (void)testMenuButtonCarriesTheTextAndURL {
	[[TGDevStore shared] setMenuButtonForBot:5 text:@"Open" url:@"https://example.com"
								  completion:^(BOOL ok, NSString *error){}];
	NSDictionary *request = TDSRequest(@"setMenuButton");
	XCTAssertNotNil(request);
	XCTAssertEqual([request[@"user_id"] longLongValue], 5LL);
	XCTAssertEqualObjects(request[@"menu_button"][@"@type"], @"botMenuButton");
	XCTAssertEqualObjects(request[@"menu_button"][@"text"], @"Open");
	XCTAssertEqualObjects(request[@"menu_button"][@"url"], @"https://example.com");
}

- (void)testBotUpdatesStatusCarriesTheCount {
	[[TGDevStore shared] setBotUpdatesStatus:3 errorMessage:@"slow"
								  completion:^(BOOL ok, NSString *error){}];
	NSDictionary *request = TDSRequest(@"setBotUpdatesStatus");
	XCTAssertNotNil(request);
	XCTAssertEqual([request[@"pending_update_count"] integerValue], 3);
	XCTAssertEqualObjects(request[@"error_message"], @"slow");
}

- (void)testBrowserSettingChangesTheOpeningMode {
	[[TGDevStore shared] setWebBrowserSettingsOpenExternal:YES
									   displayCloseButton:NO
											  completion:^(BOOL ok, NSString *error){}];
	NSDictionary *request = TDSRequest(@"changeWebBrowserSettings");
	XCTAssertNotNil(request);
	XCTAssertEqualObjects(request[@"open_external_browser"], @YES);
	XCTAssertEqualObjects(request[@"display_close_button"], @NO);
}

- (void)testSquareIntSendsTheValue {
	[[TGDevStore shared] testSquareInt:12
						   completion:^(int32_t result, NSString *error){}];
	NSDictionary *request = TDSRequest(@"testSquareInt");
	XCTAssertNotNil(request);
	XCTAssertEqual([request[@"x"] intValue], 12);
}

- (void)testCarrierTextMessageNamesTheCarrier {
	[[TGDevStore shared] processWebProxyCarrierMessage:4 text:@"hello"
											completion:^(BOOL ok, NSString *error){}];
	NSDictionary *request = TDSRequest(@"processWebProxyCarrierMessage");
	XCTAssertNotNil(request);
	XCTAssertEqual([request[@"carrier_id"] integerValue], 4);
	XCTAssertEqualObjects(request[@"message"][@"@type"], @"webProxyCarrierMessageText");
	XCTAssertEqualObjects(request[@"message"][@"text"], @"hello");
}

- (void)testCarrierErrorCarriesTheKind {
	[[TGDevStore shared] reportWebProxyCarrierError:4 kind:@"loadFailed"
											message:@"no page"
										 completion:^(BOOL ok, NSString *error){}];
	NSDictionary *request = TDSRequest(@"reportWebProxyCarrierError");
	XCTAssertNotNil(request);
	XCTAssertEqualObjects(request[@"error"][@"@type"], @"webProxyCarrierErrorLoadFailed");
	XCTAssertEqualObjects(request[@"error"][@"message"], @"no page");
}

- (void)testReadFilePartAsksForTheSlice {
	[[TGDevStore shared] readFilePartOfFile:9 offset:0 count:320
								 completion:^(NSData *data){}];
	NSDictionary *request = TDSRequest(@"readFilePart");
	XCTAssertNotNil(request);
	XCTAssertEqual([request[@"file_id"] integerValue], 9);
	XCTAssertEqual([request[@"offset"] longLongValue], 0LL);
	XCTAssertEqual([request[@"count"] integerValue], 320);
}

- (void)testGenerateTextFileStartsAPreliminaryUpload {
	[[TGDevStore shared] generateTextFileNamed:@"note.txt" contents:@"hello"
									  progress:^(NSInteger fileId, float progress,
												 NSString *stage){}
									completion:^(NSInteger fileId, NSString *path,
												 NSError *error){}];
	NSDictionary *request = TDSRequest(@"preliminaryUploadFile");
	XCTAssertNotNil(request);
	XCTAssertEqualObjects(request[@"file"][@"@type"], @"inputFileGenerated");
	XCTAssertEqualObjects(request[@"file"][@"conversion"], @"legacy-text");
	XCTAssertEqualObjects(request[@"file_type"][@"@type"], @"fileTypeDocument");
}

- (void)testHideSuggestedActionSendsTheAction {
	NSDictionary *action = @{@"@type" : @"suggestedActionCustom",
							 @"action" : @{@"@type" : @"customAction",
										   @"name" : @"check"}};
	[[TGDevStore shared] hideSuggestedAction:action
								  completion:^(BOOL ok, NSString *error){}];
	NSDictionary *request = TDSRequest(@"hideSuggestedAction");
	XCTAssertNotNil(request);
	XCTAssertEqualObjects(request[@"action"][@"@type"], @"customAction");
}

- (void)testDisplayNameIsTheClientsCache {
	[[TGDevStore shared] setDisplayName:@"Dev Bot" forUserId:77];
	XCTAssertEqualObjects([TGClient shared].usersById[@77], @"Dev Bot");
}

@end
