// TGSendStoreTests.m - the send lifecycle: send, refusal, retry, delivery.
//
// The store is the one place a bubble's failed mark and its retry path both
// read. Requests sit in the outbox; the answers arrive through handleUpdate
// exactly as the receive loop delivers them.
#import "TGTestRunner.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGSendStore.h"

@interface TGSendStoreTests : XCTestCase {
	NSMutableArray *_states;
}
@end

static TGClient *TGSSClient(void) {
	TGClient *c = TGClient.shared;
	[c.outbox removeAllObjects];
	[c.pendingRequests removeAllObjects];
	return c;
}

static NSDictionary *TGSSDecode(NSData *data) {
	NSString *json = [[NSString alloc] initWithData:data
										   encoding:NSUTF8StringEncoding];
	NSString *trimmed = [json componentsSeparatedByString:@"\0"][0];
	return [NSJSONSerialization JSONObjectWithData:
			[trimmed dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
}

static NSDictionary *TGSSRequest(TGClient *c, NSString *type, BOOL answered) {
	NSDictionary *found = nil;
	for (NSData *data in c.outbox){
		NSDictionary *request = TGSSDecode(data);
		if (![request[@"@type"] isEqualToString:type])
			continue;
		if (answered && !request[@"@extra"])
			continue;
		found = request;
	}
	return found;
}

static NSDictionary *TGSSMessage(int64_t messageId, int64_t chatId,
							  NSString *sendingType, NSDictionary *error) {
	NSMutableDictionary *m = [@{
		@"@type"       : @"message",
		@"id"          : @(messageId),
		@"chat_id"     : @(chatId),
		@"date"        : @(1700000000),
		@"is_outgoing" : @YES,
		@"content"     : @{
			@"@type" : @"messageText",
			@"text"  : @{@"@type" : @"formattedText", @"text" : @"hello"},
		},
	} mutableCopy];
	if (sendingType){
		NSMutableDictionary *state = [@{@"@type" : sendingType} mutableCopy];
		if (error){
			state[@"error"] = error;
			state[@"can_retry"] = @YES;
		}
		m[@"sending_state"] = state;
	}
	return m;
}

/// Answers the last request that carried @extra, the way tdjson's result does.
static void TGSSAnswer(TGClient *c, NSDictionary *answer) {
	NSDictionary *sent = nil;
	for (NSData *data in c.outbox){
		NSDictionary *request = TGSSDecode(data);
		if (request[@"@extra"])
			sent = request;
	}
	if (!sent)
		return;
	NSMutableDictionary *reply = [answer mutableCopy];
	reply[@"@extra"] = sent[@"@extra"];
	[c handleUpdate:reply];
}

@implementation TGSendStoreTests

- (void)setUp {
	[super setUp];
	_states = [NSMutableArray array];
	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(sendStateChanged:)
				name:TGSendStoreMessageStateChangedNotification
			  object:nil];
	TGSSClient();
	[[TGSendStore shared] reset];
}

- (void)tearDown {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	_states = nil;
	[super tearDown];
}

- (void)sendStateChanged:(NSNotification *)note {
	[_states addObject:note.userInfo[TGSendStoreStateKey] ?: @(TGSendStateUnknown)];
}

#pragma mark - the lifecycle

- (void)testSendFailedRetrySent {
	TGClient *c = TGSSClient();
	NSDictionary *text = @{@"@type" : @"formattedText", @"text" : @"hello",
						   @"entities" : @[]};

	[[TGSendStore shared] sendFormattedText:text
									 toChat:7 thread:0 replyTo:0
							schedulingState:nil];
	NSDictionary *send = TGSSRequest(c, @"sendMessage", YES);
	XCTAssertNotNil(send, @"sendMessage must reach the outbox");
	XCTAssertEqual([send[@"chat_id"] longLongValue], 7LL);

	TGSSAnswer(c, TGSSMessage(500, 7, @"messageSendingStatePending", nil));
	XCTAssertEqual([[TGSendStore shared] stateForMessageId:500 inChat:7],
				   TGSendStateSending);
	XCTAssertEqualObjects(_states, (@[@(TGSendStateSending)]));

	[c handleUpdate:@{
		@"@type"          : @"updateMessageSendFailed",
		@"message"        : TGSSMessage(500, 7, @"messageSendingStateFailed",
				@{@"@type" : @"error", @"code" : @(429),
				  @"message" : @"Too Many Requests"}),
		@"old_message_id" : @(500),
		@"error"          : @{@"@type" : @"error", @"code" : @(429),
							  @"message" : @"Too Many Requests"},
	}];
	XCTAssertEqual([[TGSendStore shared] stateForMessageId:500 inChat:7],
				   TGSendStateFailed);
	XCTAssertEqualObjects([[TGSendStore shared] failureReasonForMessageId:500
																  inChat:7],
						  @"Too Many Requests");
	XCTAssertTrue([[TGSendStore shared] canRetryMessageId:500 inChat:7]);
	XCTAssertEqualObjects(_states, (@[@(TGSendStateSending),
									  @(TGSendStateFailed)]));

	[[TGSendStore shared] retryMessageId:500 inChat:7];
	NSDictionary *resend = TGSSRequest(c, @"resendMessages", NO);
	XCTAssertNotNil(resend, @"the retry must ask TDLib to resend");
	XCTAssertEqualObjects(resend[@"message_ids"], (@[@(500)]));
	XCTAssertEqual([[TGSendStore shared] stateForMessageId:500 inChat:7],
				   TGSendStateSending);

	[c handleUpdate:@{
		@"@type"          : @"updateMessageSendSucceeded",
		@"message"        : TGSSMessage(501, 7, nil, nil),
		@"old_message_id" : @(500),
	}];
	XCTAssertEqual([[TGSendStore shared] stateForMessageId:501 inChat:7],
				   TGSendStateSent);
	XCTAssertEqual([[TGSendStore shared] stateForMessageId:500 inChat:7],
				   TGSendStateUnknown,
				   @"the temporary id must not keep a record");
	XCTAssertEqualObjects(_states, (@[@(TGSendStateSending),
									  @(TGSendStateFailed),
									  @(TGSendStateSending),
									  @(TGSendStateSent)]));
}

/// updateMessageSendFailed carries the reason at the update level as well;
/// the message's sending_state may only say it failed.
- (void)testFailureReasonFallsBackToTheUpdateError {
	TGClient *c = TGSSClient();
	[[TGSendStore shared] sendFormattedText:
			@{@"@type" : @"formattedText", @"text" : @"hi", @"entities" : @[]}
									 toChat:8 thread:0 replyTo:0
							schedulingState:nil];
	TGSSAnswer(c, TGSSMessage(600, 8, @"messageSendingStatePending", nil));

	[c handleUpdate:@{
		@"@type"          : @"updateMessageSendFailed",
		@"message"        : TGSSMessage(600, 8, @"messageSendingStateFailed", nil),
		@"old_message_id" : @(600),
		@"error"          : @{@"@type" : @"error", @"code" : @(403),
							  @"message" : @"CHAT_WRITE_FORBIDDEN"},
	}];
	XCTAssertEqualObjects([[TGSendStore shared] failureReasonForMessageId:600
																  inChat:8],
						  @"CHAT_WRITE_FORBIDDEN");
}

- (void)testDeleteForgetsTheTrackedFailure {
	TGClient *c = TGSSClient();
	[[TGSendStore shared] sendFormattedText:
			@{@"@type" : @"formattedText", @"text" : @"hi", @"entities" : @[]}
									 toChat:9 thread:0 replyTo:0
							schedulingState:nil];
	TGSSAnswer(c, TGSSMessage(700, 9, @"messageSendingStatePending", nil));
	[c handleUpdate:@{
		@"@type"          : @"updateMessageSendFailed",
		@"message"        : TGSSMessage(700, 9, @"messageSendingStateFailed",
				@{@"@type" : @"error", @"message" : @"Nope"}),
		@"old_message_id" : @(700),
	}];
	XCTAssertEqual([[TGSendStore shared] stateForMessageId:700 inChat:9],
				   TGSendStateFailed);

	[[TGSendStore shared] deleteMessages:@[@(700)] inChat:9 revoke:YES];
	NSDictionary *request = TGSSRequest(c, @"deleteMessages", NO);
	XCTAssertNotNil(request);
	XCTAssertEqualObjects(request[@"message_ids"], (@[@(700)]));
	XCTAssertEqual([[TGSendStore shared] stateForMessageId:700 inChat:9],
				   TGSendStateUnknown);
	XCTAssertEqualObjects([[TGSendStore shared] failureReasonForMessageId:700
																  inChat:9], @"");
}

- (void)testAdoptedHistorySeedsFailedWithoutOverwritingLiveState {
	NSDictionary *failed = TGSSMessage(800, 10, @"messageSendingStateFailed",
			@{@"@type" : @"error", @"message" : @"File is too big"});

	[[TGSendStore shared] adoptMessages:@[failed] inChat:10];
	XCTAssertEqual([[TGSendStore shared] stateForMessageId:800 inChat:10],
				   TGSendStateFailed);
	XCTAssertEqualObjects([[TGSendStore shared] failureReasonForMessageId:800
																  inChat:10],
						  @"File is too big");

	// The same page arriving after a retry must not put the failure back.
	[[TGSendStore shared] resendMessages:@[@(800)] inChat:10];
	XCTAssertEqual([[TGSendStore shared] stateForMessageId:800 inChat:10],
				   TGSendStateSending);
	[[TGSendStore shared] adoptMessages:@[failed] inChat:10];
	XCTAssertEqual([[TGSendStore shared] stateForMessageId:800 inChat:10],
				   TGSendStateSending);
}

- (void)testScheduledSendKeepsTheThreadReplyAndSchedule {
	TGClient *c = TGSSClient();
	NSDictionary *whenOnline = [TGClient scheduledWhenOnline];
	[[TGSendStore shared] sendText:@"later" toChat:11 thread:22 replyTo:33
				   schedulingState:whenOnline];

	NSDictionary *request = TGSSRequest(c, @"sendMessage", YES);
	XCTAssertNotNil(request);
	XCTAssertEqual([request[@"message_thread_id"] longLongValue], 22LL);
	XCTAssertEqual([request[@"reply_to"][@"message_id"] longLongValue], 33LL);
	XCTAssertEqualObjects(request[@"scheduling_state"][@"@type"],
						  @"messageSchedulingStateSendWhenOnline");
}

- (void)testMediaSendUsesTheSameOutboundStore {
	TGClient *c = TGSSClient();
	[[TGSendStore shared] sendStickerWithFileId:123 toChat:12 thread:0];

	NSDictionary *request = TGSSRequest(c, @"sendMessage", NO);
	XCTAssertNotNil(request);
	XCTAssertEqual([request[@"chat_id"] longLongValue], 12LL);
	XCTAssertEqualObjects(request[@"input_message_content"][@"@type"],
						  @"inputMessageSticker");
}

@end
