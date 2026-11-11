// TGContactsStoreTests.m - the Contacts screen's store seam.
//
// Each test sends one store call and reads the request the store put in the
// client's outbox: the shape of the request is the contract the screen has
// with Telegram, so that is what is asserted.
#import "TGTestRunner.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGContactsStore.h"

@interface TGContactsStoreTests : XCTestCase @end

static NSDictionary *TCSDecode(NSData *data) {
	NSString *json = [[NSString alloc] initWithData:data
										   encoding:NSUTF8StringEncoding];
	NSString *trimmed = [json componentsSeparatedByString:@"\0"][0];
	return [NSJSONSerialization JSONObjectWithData:
			[trimmed dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
}

static NSDictionary *TCSRequest(NSString *type) {
	NSDictionary *found = nil;
	for (NSData *data in [TGClient shared].outbox){
		NSDictionary *request = TCSDecode(data);
		if ([request[@"@type"] isEqualToString:type])
			found = request;
	}
	return found;
}

@implementation TGContactsStoreTests

- (void)setUp {
	[[TGClient shared].outbox removeAllObjects];
	[[TGClient shared].pendingRequests removeAllObjects];
}

- (void)testContactsAsksForTheList {
	[[TGContactsStore shared] contactsWithCompletion:^(NSArray *users){}];
	NSDictionary *request = TCSRequest(@"getContacts");
	XCTAssertNotNil(request);
}

- (void)testImportedCountAsksTheAccount {
	[[TGContactsStore shared] importedContactCountWithCompletion:^(NSInteger count){}];
	NSDictionary *request = TCSRequest(@"getImportedContactCount");
	XCTAssertNotNil(request);
}

- (void)testAddContactCarriesTheUserAndTheName {
	[[TGContactsStore shared] addContactWithUserId:42
										 firstName:@"Ann"
										  lastName:@"Lee"
											 phone:@"+1555"
										completion:^(BOOL ok){}];
	NSDictionary *request = TCSRequest(@"addContact");
	XCTAssertNotNil(request);
	XCTAssertEqual([request[@"user_id"] longLongValue], 42LL);
	XCTAssertEqualObjects(request[@"contact"][@"@type"], @"importedContact");
	XCTAssertEqualObjects(request[@"contact"][@"first_name"], @"Ann");
	XCTAssertEqualObjects(request[@"contact"][@"last_name"], @"Lee");
	XCTAssertEqualObjects(request[@"contact"][@"phone_number"], @"+1555");
	XCTAssertEqualObjects(request[@"share_phone_number"], @NO);
}

- (void)testImportContactSendsOneImportedContact {
	[[TGContactsStore shared] importContactNamed:@" Ann "
										lastName:@" Lee "
										   phone:@"+1 555"
									  completion:^(int64_t userId){}];
	NSDictionary *request = TCSRequest(@"importContacts");
	XCTAssertNotNil(request);
	NSArray *contacts = request[@"contacts"];
	XCTAssertEqual(contacts.count, (NSUInteger)1);
	NSDictionary *contact = contacts.firstObject;
	XCTAssertEqualObjects(contact[@"@type"], @"importedContact");
	XCTAssertEqualObjects(contact[@"phone_number"], @"+1555");
	XCTAssertEqualObjects(contact[@"first_name"], @"Ann");
	XCTAssertEqualObjects(contact[@"last_name"], @"Lee");
}

- (void)testImportContactWithoutNameAnswersZeroWithoutARequest {
	[[TGContactsStore shared] importContactNamed:@""
										lastName:@""
										   phone:@"+1555"
									  completion:^(int64_t userId){
		XCTAssertEqual(userId, 0LL);
	}];
	XCTAssertNil(TCSRequest(@"importContacts"));
}

- (void)testAddUserIsTheSingleMemberForm {
	[[TGContactsStore shared] addUser:7 toChat:9 completion:^(BOOL ok, NSArray *refused){}];
	NSDictionary *request = TCSRequest(@"addChatMember");
	XCTAssertNotNil(request);
	XCTAssertEqual([request[@"chat_id"] longLongValue], 9LL);
	XCTAssertEqual([request[@"user_id"] longLongValue], 7LL);
	XCTAssertEqual([request[@"forward_limit"] integerValue], 100);
}

- (void)testAddUsersIsOneBatchRequest {
	[[TGContactsStore shared] addUsers:@[@7, @8] toChat:9
							completion:^(BOOL ok, NSArray *refused){}];
	NSDictionary *request = TCSRequest(@"addChatMembers");
	XCTAssertNotNil(request);
	XCTAssertEqual([request[@"chat_id"] longLongValue], 9LL);
	XCTAssertEqualObjects(request[@"user_ids"], (@[@7, @8]));
	XCTAssertEqual([request[@"forward_limit"] integerValue], 100);
}

- (void)testCreateGroupNamesTheChat {
	[[TGContactsStore shared] createGroupNamed:@"Team" withUsers:@[@7]
									completion:^(int64_t chatId, NSArray *failed){}];
	NSDictionary *request = TCSRequest(@"createNewBasicGroupChat");
	XCTAssertNotNil(request);
	XCTAssertEqualObjects(request[@"title"], @"Team");
	XCTAssertEqualObjects(request[@"user_ids"], (@[@7]));
	XCTAssertEqual([request[@"message_auto_delete_time"] integerValue], 0);
}

@end
