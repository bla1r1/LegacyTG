// TGClientAccountSlotsTests.m — several accounts on one device, one TDLib
// client at a time. These pin the slot arithmetic and the reset boundary so
// an account's data cannot bleed into another's.
//
// They run in the TGClientTests binary (tests/Makefile), which compiles the
// real TGClient and its categories. Each test works the two defaults keys the
// accounts category owns — TGAccountSlots and TGActiveAccountSlot — and puts
// whatever was there back afterwards, so the host's own preferences survive.
#import "TGTestRunner.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGStoreTestSupport.h"
#import "TGAccountStore.h"
#import "TGState.h"
#import <objc/runtime.h>

@interface TGClientAccountSlotsTests : XCTestCase @end

/// A shared client with the in-memory surfaces these tests read back emptied,
/// the way the other client suites start.
static TGClient *SlotsClient(void) {
	TGClient *c = TGClient.shared;
	[c.outbox removeAllObjects];
	[c.pendingRequests removeAllObjects];
	[c.chatsById removeAllObjects];
	[c.usersById removeAllObjects];
	c.me = @{@"id" : @(1001)};
	return c;
}

@implementation TGClientAccountSlotsTests {
	id _savedSlots;
	id _savedActive;
}

- (void)setUp {
	[super setUp];
	NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
	_savedSlots = [d objectForKey:@"TGAccountSlots"];
	_savedActive = [d objectForKey:@"TGActiveAccountSlot"];
	[d removeObjectForKey:@"TGAccountSlots"];
	[d removeObjectForKey:@"TGActiveAccountSlot"];
}

- (void)tearDown {
	NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
	if (_savedSlots)
		[d setObject:_savedSlots forKey:@"TGAccountSlots"];
	else
		[d removeObjectForKey:@"TGAccountSlots"];
	if (_savedActive)
		[d setObject:_savedActive forKey:@"TGActiveAccountSlot"];
	else
		[d removeObjectForKey:@"TGActiveAccountSlot"];
	[super tearDown];
}

// ─── database directory ──────────────────────────────────────────────────────

- (void)testDatabaseDirectory_Slot0KeepsTdlibAndSlot2GetsSuffix {
	// Slot 0 keeps the pre-accounts path so an existing install's database
	// is still found; slot N > 0 gets its own directory.
	XCTAssertEqualObjects(TGAccountDatabaseDirectory(@"Documents", 0),
			@"Documents/tdlib");
	XCTAssertEqualObjects(TGAccountDatabaseDirectory(@"Documents", 2),
			@"Documents/tdlib-2");
}

/// The database held the session in Documents, which iTunes and iCloud back
/// up. It is moved once; a move that cannot happen keeps the old place, and a
/// database already at the new place is not replaced.
- (void)testDatabaseDirectory_MovesOutOfDocumentsOnce {
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:
			[NSString stringWithFormat:@"tg-move-%u", arc4random()]];
	NSString *oldDir = [tmp stringByAppendingPathComponent:@"Documents/tdlib"];
	NSString *newRoot = [tmp stringByAppendingPathComponent:@"Library/Accounts"];
	NSString *newDir = [newRoot stringByAppendingPathComponent:@"tdlib"];
	[fm createDirectoryAtPath:oldDir withIntermediateDirectories:YES attributes:nil error:nil];
	[fm createDirectoryAtPath:newRoot withIntermediateDirectories:YES attributes:nil error:nil];
	[@"old" writeToFile:[oldDir stringByAppendingPathComponent:@"td.binlog"]
			 atomically:YES encoding:NSUTF8StringEncoding error:nil];

	XCTAssertEqualObjects(TGAccountMoveDatabase(oldDir, newDir), newDir);
	XCTAssertFalse([fm fileExistsAtPath:oldDir]);
	XCTAssertEqualObjects([NSString stringWithContentsOfFile:
			[newDir stringByAppendingPathComponent:@"td.binlog"]
			encoding:NSUTF8StringEncoding error:nil], @"old");

	// A fresh install has nothing to move and opens the new place.
	XCTAssertEqualObjects(TGAccountMoveDatabase(oldDir, newDir), newDir);

	// An old build ran again and made Documents/tdlib: the new one is kept.
	[fm createDirectoryAtPath:oldDir withIntermediateDirectories:YES attributes:nil error:nil];
	[@"stale" writeToFile:[oldDir stringByAppendingPathComponent:@"td.binlog"]
			   atomically:YES encoding:NSUTF8StringEncoding error:nil];
	XCTAssertEqualObjects(TGAccountMoveDatabase(oldDir, newDir), newDir);
	XCTAssertEqualObjects([NSString stringWithContentsOfFile:
			[newDir stringByAppendingPathComponent:@"td.binlog"]
			encoding:NSUTF8StringEncoding error:nil], @"old");

	// No parent for the destination: the move fails and the old place is used.
	NSString *nowhere = [tmp stringByAppendingPathComponent:@"missing/parent/tdlib"];
	XCTAssertEqualObjects(TGAccountMoveDatabase(oldDir, nowhere), oldDir);
	XCTAssertTrue([fm fileExistsAtPath:oldDir]);

	[fm removeItemAtPath:tmp error:nil];
}

/// A cache added to TGState and not to its reset is one account's data shown
/// under the next. Every declared property is filled, then reset must leave
/// each one nil or empty - whatever is added later included.
- (void)testStateReset_LeavesNoPropertyBehind {
	TGState *state = [TGState shared];
	unsigned int count = 0;
	objc_property_t *properties = class_copyPropertyList([TGState class], &count);
	XCTAssertGreaterThan(count, (unsigned int)20);
	NSMutableArray *names = [NSMutableArray array];
	for (unsigned int i = 0; i < count; i++){
		NSString *name = @(property_getName(properties[i]));
		NSString *attributes = @(property_getAttributes(properties[i]));
		[names addObject:name];
		id value = [state valueForKey:name];
		if ([attributes rangeOfString:@"Mutable"].location != NSNotFound ||
			[attributes rangeOfString:@"LruCache"].location != NSNotFound){
			XCTAssertNotNil(value);
			if ([value isKindOfClass:NSMutableArray.class])
				[value addObject:@(1)];
			else
				[value setObject:@(1) forKey:@(1)];
		} else if ([attributes rangeOfString:@"NSArray"].location != NSNotFound){
			[state setValue:@[@(1)] forKey:name];
		} else {
			[state setValue:@{@"id" : @(1)} forKey:name];
		}
	}
	free(properties);

	[state reset];

	for (NSString *name in names){
		id value = [state valueForKey:name];
		XCTAssertTrue(value == nil || [value count] == 0);
	}
}

// ─── addAccount ──────────────────────────────────────────────────────────────

- (void)testAddAccount_NeverReturnsTheActiveSlot {
	[[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"TGActiveAccountSlot"];
	// An install that signed out of slot 0 leaves an empty list; the active
	// slot still counts as taken, so the new account lands in slot 1.
	NSInteger slot = [TGAccountStore addAccount];
	XCTAssertEqual(slot, 1);

	// The active slot was not in the list, so addAccount recorded it too.
	NSArray *slots = [TGAccountStore accountSlots];
	BOOL has0 = NO, has1 = NO;
	for (NSDictionary *entry in slots){
		NSInteger s = [entry[@"slot"] integerValue];
		if (s == 0) has0 = YES;
		if (s == 1) has1 = YES;
	}
	XCTAssertTrue(has0);
	XCTAssertTrue(has1);
}

- (void)testAddAccount_ReturnsMinusOneWhenAllThreeAreTaken {
	[[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"TGActiveAccountSlot"];
	[[NSUserDefaults standardUserDefaults] setObject:@[
		@{@"slot" : @0}, @{@"slot" : @1}, @{@"slot" : @2},
	] forKey:@"TGAccountSlots"];
	XCTAssertEqual([TGAccountStore addAccount], (NSInteger)-1);
}

// ─── recordActiveAccountFromMe ───────────────────────────────────────────────

- (void)testRecordActiveAccountFromMe_UpdatesOnlyTheActiveSlotRow {
	[[NSUserDefaults standardUserDefaults] setInteger:1 forKey:@"TGActiveAccountSlot"];
	[[NSUserDefaults standardUserDefaults] setObject:@[
		@{@"slot" : @0, @"title" : @"Old0", @"phone" : @"+0"},
		@{@"slot" : @1, @"title" : @"", @"phone" : @""},
		@{@"slot" : @2, @"title" : @"Old2", @"phone" : @"+2"},
	] forKey:@"TGAccountSlots"];

	TGClient *c = SlotsClient();
	[c recordActiveAccountFromMe:
			@{@"first_name" : @"Alice", @"username" : @"alice", @"phone" : @"+100"}];

	NSArray *slots = [TGAccountStore accountSlots];
	for (NSDictionary *entry in slots){
		NSInteger s = [entry[@"slot"] integerValue];
		if (s == 0){
			XCTAssertEqualObjects(entry[@"title"], @"Old0");
			XCTAssertEqualObjects(entry[@"phone"], @"+0");
		} else if (s == 1){
			XCTAssertEqualObjects(entry[@"title"], @"Alice");
			XCTAssertEqualObjects(entry[@"phone"], @"+100");
		} else if (s == 2){
			XCTAssertEqualObjects(entry[@"title"], @"Old2");
			XCTAssertEqualObjects(entry[@"phone"], @"+2");
		}
	}
}

// ─── resetStateForAccountSwitch ──────────────────────────────────────────────

- (void)testResetStateForAccountSwitch_EmptiesChatsUsersAndMe {
	TGClient *c = SlotsClient();
	c.chatsById[@1] = [@{@"title" : @"one"} mutableCopy];
	c.chatsById[@2] = [@{@"title" : @"two"} mutableCopy];
	c.usersById[@1] = @"User One";
	c.usersById[@2] = @"User Two";

	[[TGAccountStore shared] resetStateForAccountSwitch];

	XCTAssertNil(c.me);
	XCTAssertEqual(c.chatsById.count, (NSUInteger)0);
	XCTAssertEqual(c.usersById.count, (NSUInteger)0);
}

@end
