// TGChecklistPresentationTests.m - the progress line, the done rule and the
// toggle rule, pinned without a phone.
//
// The chat draws these strings and marks in a bubble; a wrong word is only
// visible on a device, so the pure functions are tested here.
#import "TGTestRunner.h"
#import "TGChecklistPresentation.h"

@interface TGChecklistPresentationTests : XCTestCase
@end

static NSDictionary *clTask(id completedBy, id completionDate) {
	return @{
		@"completedByUserId" : completedBy ?: @0,
		@"completionDate"    : completionDate ?: @0,
	};
}

static NSDictionary *clChecklist(NSArray *tasks) {
	return @{@"tasks" : tasks ?: @[]};
}

@implementation TGChecklistPresentationTests

#pragma mark - progress line

- (void)testProgress_NoTasksIsNoneCompleted {
	XCTAssertEqualObjects(TGChecklistProgressLine(clChecklist(@[])),
			@"No tasks completed");
}

- (void)testProgress_NilChecklistIsNoneCompleted {
	XCTAssertEqualObjects(TGChecklistProgressLine(nil), @"No tasks completed");
}

- (void)testProgress_MissingTasksKeyIsNoneCompleted {
	XCTAssertEqualObjects(TGChecklistProgressLine(@{}), @"No tasks completed");
}

- (void)testProgress_AllOpenIsNoneCompleted {
	NSDictionary *list = clChecklist(@[clTask(@0, @0), clTask(@0, @0), clTask(@0, @0)]);
	XCTAssertEqualObjects(TGChecklistProgressLine(list), @"No tasks completed");
}

- (void)testProgress_OneOfThree {
	NSDictionary *list = clChecklist(@[clTask(@42, @0), clTask(@0, @0), clTask(@0, @0)]);
	XCTAssertEqualObjects(TGChecklistProgressLine(list), @"1 of 3 completed");
}

- (void)testProgress_TwoOfThree {
	NSDictionary *list = clChecklist(@[clTask(@42, @0), clTask(@0, @1700000000),
			clTask(@0, @0)]);
	XCTAssertEqualObjects(TGChecklistProgressLine(list), @"2 of 3 completed");
}

- (void)testProgress_ThreeOfThree {
	NSDictionary *list = clChecklist(@[clTask(@42, @0), clTask(@0, @1700000000),
			clTask(@"43", @0)]);
	XCTAssertEqualObjects(TGChecklistProgressLine(list), @"3 of 3 completed");
}

- (void)testProgress_OneOfOne {
	NSDictionary *list = clChecklist(@[clTask(@42, @0)]);
	XCTAssertEqualObjects(TGChecklistProgressLine(list), @"1 of 1 completed");
}

- (void)testProgress_DateAloneCountsAsDone {
	NSDictionary *list = clChecklist(@[clTask(@0, @1700000001)]);
	XCTAssertEqualObjects(TGChecklistProgressLine(list), @"1 of 1 completed");
}

/// A malformed entry still sits in the task list, so the total must include
/// it; it just cannot be counted as done.
- (void)testProgress_MalformedTaskCountsInTheTotal {
	NSDictionary *list = clChecklist(@[clTask(@42, @0), [NSNull null]]);
	XCTAssertEqualObjects(TGChecklistProgressLine(list), @"1 of 2 completed");
}

- (void)testProgress_StringValuesAreRead {
	NSDictionary *list = clChecklist(@[clTask(@"42", @"1700000002")]);
	XCTAssertEqualObjects(TGChecklistProgressLine(list), @"1 of 1 completed");
}

#pragma mark - task done

- (void)testTaskDone_UserNumberIsDone {
	XCTAssertTrue(TGChecklistTaskDone(clTask(@42, @0)));
}

- (void)testTaskDone_UserStringIsDone {
	XCTAssertTrue(TGChecklistTaskDone(clTask(@"42", @0)));
}

- (void)testTaskDone_DateIsDone {
	XCTAssertTrue(TGChecklistTaskDone(clTask(@0, @1700000000)));
}

- (void)testTaskDone_ZeroUserAndZeroDateIsOpen {
	XCTAssertFalse(TGChecklistTaskDone(clTask(@0, @0)));
}

- (void)testTaskDone_ZeroUserStringAndZeroDateStringIsOpen {
	XCTAssertFalse(TGChecklistTaskDone(clTask(@"0", @"0")));
}

- (void)testTaskDone_EmptyTaskIsOpen {
	XCTAssertFalse(TGChecklistTaskDone(@{}));
}

- (void)testTaskDone_NilTaskIsOpen {
	XCTAssertFalse(TGChecklistTaskDone(nil));
}

- (void)testTaskDone_WrongTypeIsOpen {
	XCTAssertFalse(TGChecklistTaskDone((NSDictionary *)@"done"));
}

#pragma mark - toggle rule

- (void)testCanToggle_YesNumber {
	XCTAssertTrue(TGChecklistCanToggle(@{@"canMarkTasksAsDone" : @YES}));
}

- (void)testCanToggle_YesString {
	XCTAssertTrue(TGChecklistCanToggle(@{@"canMarkTasksAsDone" : @"true"}));
}

- (void)testCanToggle_NoNumber {
	XCTAssertFalse(TGChecklistCanToggle(@{@"canMarkTasksAsDone" : @NO}));
}

- (void)testCanToggle_MissingKey {
	XCTAssertFalse(TGChecklistCanToggle(@{}));
}

- (void)testCanToggle_NilChecklist {
	XCTAssertFalse(TGChecklistCanToggle(nil));
}

- (void)testCanToggle_OtherPermissionDoesNotGrantIt {
	NSDictionary *list = @{@"canAddTasks" : @YES,
			@"othersCanMarkTasksAsDone" : @YES};
	XCTAssertFalse(TGChecklistCanToggle(list));
}

@end
