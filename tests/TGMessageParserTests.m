// TGMessageParserTests.m — TGFlattenMessage, which nothing covered.
//
// Every bubble in the app is drawn from the dictionary this function returns,
// and a hundred-odd TDLib content types funnel through it. It had two fields
// under test (the ones added with the reaction and retry work) and none of
// the rest, although it is where a renamed TDLib key goes unnoticed - which
// is exactly how B3 happened one level up, in the folder titles.
//
// These are the invariants a chat is unreadable without: a caption beats the
// content's own words, a reply keeps what it answers, a forward says who
// from, and content nobody wrote a branch for says what it is instead of
// drawing an empty bubble.
#import "TGTestRunner.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGStatChart.h"
#import "TGChatEventText.h"

@interface TGMessageParserTests : XCTestCase @end

/// A message as TDLib sends one, with `content` filled in by the test.
static NSDictionary *fxMsg(NSDictionary *content, NSDictionary *extra) {
	NSMutableDictionary *m = [@{
		@"@type"       : @"message",
		@"id"          : @(5),
		@"date"        : @(1700000000),
		@"is_outgoing" : @NO,
		@"content"     : content ?: @{},
	} mutableCopy];
	for (NSString *key in extra)
		m[key] = extra[key];
	return m;
}

static NSDictionary *fxTextContent(NSString *text) {
	return @{@"@type" : @"messageText",
			 @"text"  : @{@"@type" : @"formattedText", @"text" : text ?: @""}};
}

@implementation TGMessageParserTests

#pragma mark - what the bubble says

- (void)testFlatten_PlainTextCarriesStraightThrough {
	NSDictionary *flat = TGFlattenMessage(fxMsg(fxTextContent(@"hello"), nil));
	XCTAssertEqualObjects(flat[@"text"], @"hello");
	XCTAssertEqualObjects(flat[@"kind"], @"messageText");
	XCTAssertFalse([flat[@"service"] boolValue]);
	XCTAssertEqual([flat[@"id"] longLongValue], 5LL);
}

/// A custom emoji sent alone: its .tgs may be one the renderer cannot draw,
/// and the system has no glyph for many of them on iOS 6 (U+2604 among
/// them), so the custom emoji id is the only way back to its still picture.
- (void)testFlatten_AnimatedCustomEmojiKeepsItsEmojiId {
	NSDictionary *sticker = @{
		@"format"    : @{@"@type" : @"stickerFormatTgs"},
		@"sticker"   : @{@"id" : @(41)},
		@"thumbnail" : @{@"file" : @{@"id" : @(1321)}},
		@"full_type" : @{@"@type" : @"stickerFullTypeCustomEmoji",
						 @"custom_emoji_id" : @"5224607267797606837"},
	};
	NSDictionary *flat = TGFlattenMessage(fxMsg(@{@"@type" : @"messageAnimatedEmoji",
			@"emoji" : @"\u2604\uFE0F", @"animated_emoji" : @{@"sticker" : sticker}}, nil));
	XCTAssertEqual([flat[@"stickerEmojiId"] longLongValue], 5224607267797606837LL);
	XCTAssertEqualObjects(flat[@"docName"], @"tgs");

	NSDictionary *plain = TGFlattenMessage(fxMsg(@{@"@type" : @"messageSticker",
			@"sticker" : @{@"format" : @{@"@type" : @"stickerFormatTgs"},
						   @"sticker" : @{@"id" : @(42)}}}, nil));
	XCTAssertEqual([plain[@"stickerEmojiId"] longLongValue], 0LL);
}

- (void)testFlatten_LiveLocationCarriesItsStatusKeys {
	NSDictionary *flat = TGFlattenMessage(fxMsg(@{@"@type" : @"messageLiveLocation", @"expires_in" : @600,
		@"location" : @{@"@type" : @"liveLocation", @"live_period" : @900, @"heading" : @45,
			@"proximity_alert_radius" : @500,
			@"location" : @{@"@type" : @"location", @"latitude" : @1.0, @"longitude" : @2.0}}},
		@{@"edit_date" : @1700000100}));
	XCTAssertEqual([flat[@"live"][@"expiresIn"] longLongValue], 600LL);
	XCTAssertEqual([flat[@"live"][@"heading"] longLongValue], 45LL);
	XCTAssertEqual([flat[@"editDate"] longLongValue], 1700000100LL);
}

- (void)testFlatten_SpoilerPhotoIsMarked {
	NSDictionary *flat = TGFlattenMessage(fxMsg(@{@"@type" : @"messagePhoto", @"has_spoiler" : @YES,
		@"photo" : @{@"@type" : @"photo", @"sizes" : @[]}}, nil));
	XCTAssertEqualObjects(flat[@"hasSpoiler"], @YES);
	XCTAssertEqualObjects(TGFlattenMessage(fxMsg(fxTextContent(@"hi"), nil))[@"hasSpoiler"], @NO);
}

- (void)testFlatten_VideoCallSaysVideoCall {
	NSDictionary *flat = TGFlattenMessage(fxMsg(@{@"@type" : @"messageCall", @"is_video" : @YES,
		@"duration" : @65, @"discard_reason" : @{@"@type" : @"callDiscardReasonHungUp"}},
		@{@"is_outgoing" : @YES}));
	XCTAssertEqualObjects(flat[@"text"], @"Outgoing video call, 1:05");
}

- (void)testFlatten_MissedVideoCall {
	NSDictionary *flat = TGFlattenMessage(fxMsg(@{@"@type" : @"messageCall", @"is_video" : @YES,
		@"duration" : @0, @"discard_reason" : @{@"@type" : @"callDiscardReasonMissed"}}, nil));
	XCTAssertEqualObjects(flat[@"text"], @"Missed video call");
}

- (void)testFlatten_VoiceCallKeepsItsWords {
	NSDictionary *flat = TGFlattenMessage(fxMsg(@{@"@type" : @"messageCall", @"is_video" : @NO,
		@"duration" : @0, @"discard_reason" : @{@"@type" : @"callDiscardReasonMissed"}},
		@{@"is_outgoing" : @YES}));
	XCTAssertEqualObjects(flat[@"text"], @"Cancelled call");
}

/// A protected chat's message and a one-time picture arrive with
/// can_be_saved false; the menu and the viewer read canBeSaved to keep
/// Copy, Forward and Save away from them.
- (void)testFlatten_ProtectedMessageCannotBeSaved {
	NSDictionary *flat = TGFlattenMessage(fxMsg(fxTextContent(@"secret"), @{@"can_be_saved" : @NO}));
	XCTAssertEqualObjects(flat[@"canBeSaved"], @NO);
}

- (void)testFlatten_OrdinaryMessageCanBeSaved {
	NSDictionary *flat = TGFlattenMessage(fxMsg(fxTextContent(@"hi"), @{@"can_be_saved" : @YES}));
	XCTAssertEqualObjects(flat[@"canBeSaved"], @YES);
}

/// Local messages TDLib never described carry no flag and stay ours to copy.
- (void)testFlatten_MissingSaveFlagMeansSaveable {
	NSDictionary *flat = TGFlattenMessage(fxMsg(fxTextContent(@"hi"), nil));
	XCTAssertEqualObjects(flat[@"canBeSaved"], @YES);
}

/// A caption beats whatever the content type would have said, because the
/// caption is what the sender wrote.
- (void)testFlatten_ACaptionWinsOverTheContentsOwnWords {
	NSDictionary *flat = TGFlattenMessage(fxMsg(@{
			@"@type"   : @"messageDocument",
			@"caption" : @{@"text" : @"the slides"},
			@"document": @{@"file_name" : @"deck.pdf",
						   @"document" : @{@"id" : @(9), @"size" : @(2048)}}}, nil));
	XCTAssertEqualObjects(flat[@"text"], @"the slides");
	XCTAssertEqualObjects(flat[@"docName"], @"deck.pdf");
	XCTAssertEqual([flat[@"docSize"] longLongValue], 2048LL);
}

/// A picture with no caption says nothing: the image is the message, and a
/// line of text under it would be noise.
- (void)testFlatten_APhotoWithNoCaptionHasNoText {
	NSDictionary *flat = TGFlattenMessage(fxMsg(@{
			@"@type" : @"messagePhoto",
			@"photo" : @{@"sizes" : @[@{@"type" : @"x", @"width" : @(800),
										@"height" : @(600),
										@"photo" : @{@"id" : @(11)}}]}}, nil));
	XCTAssertEqualObjects(flat[@"text"], @"");
	XCTAssertFalse([flat[@"photoId"] isEqual:[NSNull null]],
				   @"a photo must carry a file id to draw");
}

/// The one that keeps the app honest as TDLib grows: a content type nobody
/// has written a branch for reads as its own name in words, as a service
/// line, rather than as an empty bubble.
- (void)testFlatten_UnknownContentBecomesAServiceLineRatherThanNothing {
	// A type no TDLib release has yet; video chats now have a sentence.
	NSDictionary *flat = TGFlattenMessage(fxMsg(@{
			@"@type" : @"messageMeteorShowerStarted"}, nil));
	XCTAssertTrue([flat[@"service"] boolValue]);
	XCTAssertEqualObjects(flat[@"text"], TGPhraseFromTypeName(@"messageMeteorShowerStarted"));
	XCTAssertTrue([flat[@"text"] length] > 0);
}

/// A self-destructing photo that has gone says so; an empty bubble would read
/// as a bug.
- (void)testFlatten_ExpiredMediaSaysSoAsAService {
	NSDictionary *flat = TGFlattenMessage(fxMsg(@{
			@"@type" : @"messageExpiredPhoto"}, nil));
	XCTAssertTrue([flat[@"service"] boolValue]);
	// Telegram names the kind of media that expired.
	XCTAssertEqualObjects(flat[@"text"], @"Photo has expired");
}

#pragma mark - replies

- (void)testFlatten_AReplyKeepsTheIdItAnswers {
	NSDictionary *flat = TGFlattenMessage(fxMsg(fxTextContent(@"yes"), @{
			@"reply_to" : @{@"@type" : @"messageReplyToMessage",
							@"message_id" : @(4)}}));
	XCTAssertEqual([flat[@"replyId"] longLongValue], 4LL);
}

/// Newer TDLib carries the quoted text inline, which saves the chat a fetch.
- (void)testFlatten_AnInlineQuoteIsKept {
	NSDictionary *flat = TGFlattenMessage(fxMsg(fxTextContent(@"yes"), @{
			@"reply_to" : @{@"@type" : @"messageReplyToMessage",
							@"message_id" : @(4),
							@"quote" : @{@"text" : @{@"text" : @"are you coming?"}}}}));
	XCTAssertEqualObjects(flat[@"replyText"], @"are you coming?");
}

/// Quoted entities are preserved alongside quoteText for custom emoji rendering.
- (void)testFlatten_AnInlineQuoteKeepsQuoteEntities {
	NSArray *entities = @[@{
		@"@type"  : @"textEntity",
		@"offset" : @0,
		@"length" : @3,
		@"type"   : @{@"@type" : @"textEntityTypeCustomEmoji", @"custom_emoji_id" : @"123"},
	}];
	NSDictionary *flat = TGFlattenMessage(fxMsg(fxTextContent(@"yes"), @{
			@"reply_to" : @{@"@type" : @"messageReplyToMessage",
							@"message_id" : @(4),
							@"quote" : @{@"text" : @{@"text" : @"are you coming?",
													 @"entities" : entities}}}}));
	XCTAssertEqualObjects(flat[@"replyText"], @"are you coming?");
	XCTAssertEqualObjects(flat[@"quoteEntities"], entities);
}

/// A reply to a story is not a reply to a message, and treating it as one
/// would have the chat fetching a message id that does not exist.
- (void)testFlatten_AReplyToSomethingOtherThanAMessageIsNotAReply {
	NSDictionary *flat = TGFlattenMessage(fxMsg(fxTextContent(@"nice"), @{
			@"reply_to" : @{@"@type" : @"messageReplyToStory",
							@"story_id" : @(9)}}));
	XCTAssertEqualObjects(flat[@"replyId"], [NSNull null]);
	XCTAssertEqualObjects(flat[@"replyText"], @"");
}

#pragma mark - forwards

- (void)testFlatten_AForwardFromAHiddenUserUsesTheNameTheySent {
	NSDictionary *flat = TGFlattenMessage(fxMsg(fxTextContent(@"look"), @{
			@"forward_info" : @{@"origin" : @{@"@type" : @"messageOriginHiddenUser",
											  @"sender_name" : @"Someone"}}}));
	XCTAssertEqualObjects(flat[@"forward"], @"Someone");
}

/// A channel forward is signed when there is a signature and named as a
/// channel when there is not - either way the line is not blank.
- (void)testFlatten_AChannelForwardIsSignedOrNamedButNeverBlank {
	NSDictionary *signed_ = TGFlattenMessage(fxMsg(fxTextContent(@"news"), @{
			@"forward_info" : @{@"origin" : @{@"@type" : @"messageOriginChannel",
											  @"author_signature" : @"Ed"}}}));
	XCTAssertEqualObjects(signed_[@"forward"], @"Ed");

	NSDictionary *unsigned_ = TGFlattenMessage(fxMsg(fxTextContent(@"news"), @{
			@"forward_info" : @{@"origin" : @{@"@type" : @"messageOriginChannel",
											  @"author_signature" : @""}}}));
	XCTAssertEqualObjects(unsigned_[@"forward"], @"a channel");
}

/// A user whose name has not arrived yet still forwards from someone.
- (void)testFlatten_AForwardFromAnUnknownUserStillNamesSomeone {
	NSDictionary *flat = TGFlattenMessage(fxMsg(fxTextContent(@"look"), @{
			@"forward_info" : @{@"origin" : @{@"@type" : @"messageOriginUser",
											  @"sender_user_id" : @(424242)}}}));
	XCTAssertEqualObjects(flat[@"forward"], @"a user");
}

- (void)testFlatten_NoForwardIsAnEmptyStringAndNotNil {
	// The cell reads -length on this, so nil would be a silent empty line and
	// a dictionary without the key would throw on insertion.
	NSDictionary *flat = TGFlattenMessage(fxMsg(fxTextContent(@"hi"), nil));
	XCTAssertEqualObjects(flat[@"forward"], @"");
}

#pragma mark - edited, albums, polls

- (void)testFlatten_EditedComesFromTheDateRatherThanAFlag {
	XCTAssertFalse([TGFlattenMessage(fxMsg(fxTextContent(@"hi"), nil))[@"edited"] boolValue]);
	XCTAssertTrue([TGFlattenMessage(fxMsg(fxTextContent(@"hi"),
			@{@"edit_date" : @(1700000001)}))[@"edited"] boolValue]);
	// Zero is not an edit; TDLib sends it for everything unedited.
	XCTAssertFalse([TGFlattenMessage(fxMsg(fxTextContent(@"hi"),
			@{@"edit_date" : @(0)}))[@"edited"] boolValue]);
}

/// Several pictures sent together share an album id, which is how the chat
/// knows to draw them as one block.
- (void)testFlatten_AnAlbumIdIsCarriedThrough {
	NSDictionary *flat = TGFlattenMessage(fxMsg(@{
			@"@type" : @"messagePhoto",
			@"photo" : @{@"sizes" : @[@{@"type" : @"x", @"width" : @(100),
										@"height" : @(100),
										@"photo" : @{@"id" : @(11)}}]}},
			@{@"media_album_id" : @"7788"}));
	XCTAssertEqualObjects(flat[@"albumId"], @"7788");
}

- (void)testFlatten_APollKeepsItsQuestionOptionsAndState {
	NSDictionary *flat = TGFlattenMessage(fxMsg(@{
			@"@type" : @"messagePoll",
			@"poll"  : @{@"question" : @{@"text" : @"Tea?"},
						 @"total_voter_count" : @(3),
						 @"is_closed" : @YES,
						 @"is_anonymous" : @NO,
						 @"options" : @[@{@"text" : @{@"text" : @"Yes"},
										  @"vote_percentage" : @(66)},
										@{@"text" : @{@"text" : @"No"},
										  @"vote_percentage" : @(34)}]}}, nil));
	XCTAssertEqualObjects(flat[@"pollQuestion"], @"Tea?");
	XCTAssertEqual([flat[@"pollOptions"] count], (NSUInteger)2);
	XCTAssertEqual([flat[@"pollTotal"] integerValue], (NSInteger)3);
	XCTAssertTrue([flat[@"pollClosed"] boolValue]);
	XCTAssertFalse([flat[@"pollAnonymous"] boolValue]);
	// A poll is not a service message, whatever its text looks like.
	XCTAssertFalse([flat[@"service"] boolValue]);
}

#pragma mark - reactions

- (void)testReactionSummary_IsEmojiAndCountMostUsedFirst {
	NSString *summary = TGReactionSummary(@{@"interaction_info" :
			@{@"reactions" : @{@"reactions" : @[
					@{@"type" : @{@"emoji" : @"\U0001F44D"}, @"total_count" : @(3)},
					@{@"type" : @{@"emoji" : @"\U00002764"}, @"total_count" : @(1)}]}}});
	XCTAssertEqualObjects(summary, @"\U0001F44D 3  \U00002764 1");
}

/// A custom emoji has no character to draw, so it is counted under a star
/// rather than leaving a gap in the line.
- (void)testReactionSummary_CustomEmojiIsCountedUnderAStar {
	NSString *summary = TGReactionSummary(@{@"interaction_info" :
			@{@"reactions" : @{@"reactions" : @[
					@{@"type" : @{@"@type" : @"reactionTypeCustomEmoji"},
					  @"total_count" : @(2)}]}}});
	XCTAssertEqualObjects(summary, @"\U00002B50 2");
}

- (void)testReactionSummary_NoReactionsIsNilRatherThanAnEmptyLine {
	XCTAssertNil(TGReactionSummary(@{}));
	XCTAssertNil(TGReactionSummary(@{@"interaction_info" :
			@{@"reactions" : @{@"reactions" : @[]}}}));
	// A shape that is not a list at all must not throw.
	XCTAssertNil(TGReactionSummary(@{@"interaction_info" :
			@{@"reactions" : @{@"reactions" : @"nonsense"}}}));
}

#pragma mark - the type-name fallback

/// The fallback that keeps unknown content readable. It is the reason a new
/// TDLib release does not leave blank bubbles behind.
- (void)testPhraseFromTypeName_SplitsCamelCaseAndDropsThePrefix {
	XCTAssertEqualObjects(TGPhraseFromTypeName(@"messageVideoChatStarted"),
						  @"Video chat started");
	XCTAssertEqualObjects(TGPhraseFromTypeName(@"messagePinMessage"),
						  @"Pin message");
	// Not a message type at all, and still readable.
	XCTAssertEqualObjects(TGPhraseFromTypeName(@"somethingElse"),
						  @"Something else");
	XCTAssertEqualObjects(TGPhraseFromTypeName(@"message"), @"Message");
}

#pragma mark - a track

/// Everything the track bubble draws comes from here, and until the bubble
/// existed none of it was read: a song drew as the document it also is, and
/// the cover TDLib sends was never put on screen.
- (void)testFlatten_ATrackCarriesItsTitlePerformerCoverAndLength {
	NSDictionary *flat = TGFlattenMessage(fxMsg(@{
			@"@type" : @"messageAudio",
			@"audio" : @{@"file_name" : @"track01.mp3",
						 @"title"     : @"Teardrop",
						 @"performer" : @"Massive Attack",
						 @"duration"  : @(330),
						 @"audio"     : @{@"id" : @(21)},
						 @"album_cover_thumbnail" : @{@"file" : @{@"id" : @(22)}}}}, nil));

	XCTAssertEqualObjects(flat[@"kind"], @"messageAudio");
	XCTAssertEqualObjects(flat[@"audioTitle"], @"Teardrop");
	XCTAssertEqualObjects(flat[@"audioPerformer"], @"Massive Attack");
	XCTAssertEqual([flat[@"duration"] integerValue], (NSInteger)330);
	XCTAssertEqual([flat[@"albumCoverId"] integerValue], (NSInteger)22);
	// It is still a file, because that is what gets downloaded to play it.
	XCTAssertEqual([flat[@"docId"] integerValue], (NSInteger)21);
}

/// A track with no tags falls back to the file name, which is what the bubble
/// puts on its first line rather than leaving it blank.
- (void)testFlatten_ATrackWithNoTagsStillHasAName {
	NSDictionary *flat = TGFlattenMessage(fxMsg(@{
			@"@type" : @"messageAudio",
			@"audio" : @{@"file_name" : @"track01.mp3",
						 @"duration"  : @(12),
						 @"audio"     : @{@"id" : @(21)}}}, nil));
	XCTAssertEqualObjects(flat[@"text"], @"track01.mp3");
	XCTAssertEqualObjects(flat[@"audioTitle"], @"");
	XCTAssertEqualObjects(flat[@"audioPerformer"], @"");
	// Nothing to draw rather than a zero that would look like a real cover.
	XCTAssertEqualObjects(flat[@"albumCoverId"], [NSNull null]);
}

/// A track is not a service message, however little it carries.
- (void)testFlatten_ATrackIsNotAServiceLine {
	NSDictionary *flat = TGFlattenMessage(fxMsg(@{
			@"@type" : @"messageAudio",
			@"audio" : @{@"audio" : @{@"id" : @(21)}}}, nil));
	XCTAssertFalse([flat[@"service"] boolValue]);
}

#pragma mark - reaction chips and views

/// The chip under a bubble needs the group's count, whether it is yours, and
/// - for a group with one reactor - who that was and their picture. The view
/// count rides here too because the menu's "Viewed by N" row reads it.
- (void)testFlatten_ReactionGroupsCarryTheSoleReactorAndTheViewCount {
	TGClient *c = TGClient.shared;
	[c.usersById removeAllObjects];
	[c.userPhotosById removeAllObjects];
	c.usersById[@(6)] = @"Ann Lee";
	c.userPhotosById[@(6)] = @(77);

	NSDictionary *flat = TGFlattenMessage(fxMsg(fxTextContent(@"hi"), @{
		@"interaction_info" : @{
			@"view_count" : @(12),
			@"reactions" : @{@"reactions" : @[
				@{@"type" : @{@"@type" : @"reactionTypeEmoji", @"emoji" : @"\U0001F44D"},
				  @"total_count" : @(1),
				  @"is_chosen" : @YES,
				  @"recent_sender_ids" : @[
					  @{@"@type" : @"messageSenderUser", @"user_id" : @(6)}]},
				@{@"type" : @{@"@type" : @"reactionTypeEmoji", @"emoji" : @"\U0001F525"},
				  @"total_count" : @(3),
				  @"recent_sender_ids" : @[
					  @{@"@type" : @"messageSenderUser", @"user_id" : @(8)},
					  @{@"@type" : @"messageSenderUser", @"user_id" : @(9)}]}]}}}));

	NSArray *groups = flat[@"reactionGroups"];
	XCTAssertEqual(groups.count, (NSUInteger)2);
	XCTAssertEqual([flat[@"viewCount"] integerValue], (NSInteger)12);

	NSDictionary *one = groups[0];
	XCTAssertEqualObjects(one[@"emoji"], @"\U0001F44D");
	XCTAssertEqual([one[@"count"] integerValue], (NSInteger)1);
	XCTAssertTrue([one[@"chosen"] boolValue]);
	XCTAssertEqual([one[@"userId"] longLongValue], 6LL,
				   @"one reactor is the person a chip names");
	XCTAssertEqualObjects(one[@"name"], @"Ann Lee");
	XCTAssertEqual([one[@"avatarFileId"] integerValue], (NSInteger)77);
	XCTAssertTrue([one[@"sender"] isKindOfClass:NSDictionary.class]);

	NSDictionary *many = groups[1];
	XCTAssertEqual([many[@"count"] integerValue], (NSInteger)3);
	XCTAssertEqual([many[@"userId"] longLongValue], 0LL,
				   @"three reactors are a count, not one face");
	XCTAssertFalse([many[@"chosen"] boolValue]);
}

/// A custom reaction has no character, so the id travels and the chip draws
/// a star. The group is still tappable, because the reactor list can be asked
/// for by custom_emoji_id.
- (void)testFlatten_CustomReactionKeepsItsIdAndFallsBackToAStar {
	NSDictionary *flat = TGFlattenMessage(fxMsg(fxTextContent(@"hi"), @{
		@"interaction_info" : @{@"reactions" : @{@"reactions" : @[
			@{@"type" : @{@"@type" : @"reactionTypeCustomEmoji",
						  @"custom_emoji_id" : @(999)},
			  @"total_count" : @(1)}]}}}));
	NSDictionary *group = flat[@"reactionGroups"][0];
	XCTAssertEqualObjects(group[@"emoji"], @"");
	XCTAssertEqual([group[@"customEmojiId"] longLongValue], 999LL);
	XCTAssertEqual([group[@"count"] integerValue], (NSInteger)1);
	XCTAssertEqual([group[@"userId"] longLongValue], 0LL,
				   @"no named sender, so the chip counts instead of guessing");
}

/// A message without reactions carries an empty list and zero views, so the
/// cell has one branch to check instead of a nil that would crash a count.
- (void)testFlatten_NoReactionsIsAnEmptyGroupList {
	NSDictionary *flat = TGFlattenMessage(fxMsg(fxTextContent(@"hi"), nil));
	XCTAssertEqualObjects(flat[@"reactionGroups"], @[]);
	XCTAssertEqual([flat[@"viewCount"] integerValue], (NSInteger)0);
}

- (void)testFlatten_AuthorSignatureAndViewsPresent {
	NSDictionary *flat = TGFlattenMessage(fxMsg(fxTextContent(@"channel news"), @{
		@"author_signature" : @"Chief Editor",
		@"interaction_info" : @{@"view_count" : @(1250)}
	}));
	XCTAssertEqualObjects(flat[@"authorSignature"], @"Chief Editor");
	XCTAssertEqualObjects(flat[@"viewCount"], @(1250));
}

- (void)testFlatten_AuthorSignatureAbsentWhenMissingOrEmpty {
	NSDictionary *flat = TGFlattenMessage(fxMsg(fxTextContent(@"unsigned post"), nil));
	XCTAssertEqualObjects(flat[@"authorSignature"], @"");
	XCTAssertEqualObjects(flat[@"viewCount"], @(0));

	NSDictionary *emptySig = TGFlattenMessage(fxMsg(fxTextContent(@"empty"), @{
		@"author_signature" : @""
	}));
	XCTAssertEqualObjects(emptySig[@"authorSignature"], @"");
}

- (void)testFlatten_AuthorSignatureHandlesNullAndWrongTypes {
	NSDictionary *flat = TGFlattenMessage(fxMsg(fxTextContent(@"post"), @{
		@"author_signature" : [NSNull null],
		@"interaction_info" : [NSNull null]
	}));
	XCTAssertEqualObjects(flat[@"authorSignature"], @"");
	XCTAssertEqualObjects(flat[@"viewCount"], @(0));
}

- (void)testFlatten_ViewCountPresentAndAbsent {
	NSDictionary *withViews = TGFlattenMessage(fxMsg(fxTextContent(@"views"), @{
		@"interaction_info" : @{@"view_count" : @(42)}
	}));
	XCTAssertEqualObjects(withViews[@"viewCount"], @(42));

	NSDictionary *withoutViews = TGFlattenMessage(fxMsg(fxTextContent(@"no views"), @{}));
	XCTAssertEqualObjects(withoutViews[@"viewCount"], @(0));
}

- (void)testFlatten_RichMessageUnpacksBlocks {
	NSDictionary *richContent = @{
		@"@type" : @"messageRichMessage",
		@"blocks" : @[
			@{@"text" : @{@"text" : @"First block"}},
			@{@"text" : @"Second block"}
		]
	};
	NSDictionary *flat = TGFlattenMessage(fxMsg(richContent, nil));
	XCTAssertEqualObjects(flat[@"text"], @"First block\nSecond block");
	XCTAssertEqualObjects(flat[@"kind"], @"messageRichMessage");
}

- (void)testFlatten_LinkPreviewExtracted {
	NSDictionary *content = @{
		@"@type" : @"messageText",
		@"text"  : @{@"@type" : @"formattedText", @"text" : @"Check this out"},
		@"link_preview" : @{
			@"site_name"   : @"GitHub",
			@"title"       : @"iTgLegacy",
			@"description" : @"Telegram for iOS 6",
			@"url"         : @"https://github.com/dmytrom/iTgLegacy"
		}
	};
	NSDictionary *flat = TGFlattenMessage(fxMsg(content, nil));
	XCTAssertEqualObjects(flat[@"linkPreviewSite"], @"GitHub");
	XCTAssertEqualObjects(flat[@"linkPreviewTitle"], @"iTgLegacy");
	XCTAssertEqualObjects(flat[@"linkPreviewDesc"], @"Telegram for iOS 6");
	XCTAssertEqualObjects(flat[@"linkPreviewUrl"], @"https://github.com/dmytrom/iTgLegacy");
}

- (void)testFlatten_EphemeralContentAddsOnlyYouPrefix {
	NSDictionary *content = @{
		@"@type" : @"messageText",
		@"text"  : @{@"@type" : @"formattedText", @"text" : @"Secret note"}
	};
	NSDictionary *flat = TGFlattenMessage(fxMsg(content, @{@"ephemeral_content" : @YES}));
	XCTAssertEqualObjects(flat[@"text"], @"(Only you) Secret note");
}

- (void)testFlatten_SenderTagExtracted {
	NSDictionary *flat = TGFlattenMessage(fxMsg(fxTextContent(@"hi"), @{
		@"sender_tag" : @"Admin"
	}));
	XCTAssertEqualObjects(flat[@"senderTag"], @"Admin");
}

- (void)testFlatten_DocumentWithCaption {
	NSDictionary *content = @{
		@"@type" : @"messageDocument",
		@"document" : @{
			@"file_name" : @"test.pdf",
			@"document"  : @{@"id" : @(123), @"size" : @(2048)}
		},
		@"caption" : @{
			@"@type" : @"formattedText",
			@"text"  : @"Here is the document caption"
		}
	};
	NSDictionary *flat = TGFlattenMessage(fxMsg(content, @{@"media_album_id" : @"998877"}));
	XCTAssertEqualObjects(flat[@"kind"], @"messageDocument");
	XCTAssertEqualObjects(flat[@"docName"], @"test.pdf");
	XCTAssertEqualObjects(flat[@"caption"], @"Here is the document caption");
	XCTAssertEqualObjects(flat[@"text"], @"Here is the document caption");
	XCTAssertEqualObjects(flat[@"albumId"], @"998877");
}

#pragma mark - file thumbnails, captions and transcription

/// A PDF with a preview carries the file id the tile downloads. Without it
/// the document cell has nothing to draw but the generic glyph.
- (void)testFlatten_DocumentThumbnailFileIdIsCarried {
	NSDictionary *flat = TGFlattenMessage(fxMsg(@{
			@"@type" : @"messageDocument",
			@"document" : @{
				@"file_name" : @"scan.pdf",
				@"document"  : @{@"id" : @(5), @"size" : @(4096)},
				@"thumbnail" : @{@"file" : @{@"id" : @(77)}}}}, nil));
	XCTAssertTrue([flat[@"docThumbFileId"] isKindOfClass:NSNumber.class]);
	XCTAssertEqual([flat[@"docThumbFileId"] longLongValue], 77LL);
	XCTAssertEqualObjects(flat[@"docName"], @"scan.pdf");
}

- (void)testFlatten_DocumentWithoutThumbnailHasZero {
	NSDictionary *flat = TGFlattenMessage(fxMsg(@{
			@"@type" : @"messageDocument",
			@"document" : @{
				@"file_name" : @"notes.txt",
				@"document"  : @{@"id" : @(6), @"size" : @(10)}}}, nil));
	XCTAssertEqual([flat[@"docThumbFileId"] longLongValue], 0LL);
}

- (void)testFlatten_DocumentThumbnailWithoutFileIdHasZero {
	NSDictionary *flat = TGFlattenMessage(fxMsg(@{
			@"@type" : @"messageDocument",
			@"document" : @{
				@"document"  : @{@"id" : @(6)},
				@"thumbnail" : @{@"file" : @{}}}}, nil));
	XCTAssertEqual([flat[@"docThumbFileId"] longLongValue], 0LL);
}

- (void)testFlatten_VoiceNoteCarriesItsCaption {
	NSDictionary *flat = TGFlattenMessage(fxMsg(@{
			@"@type" : @"messageVoiceNote",
			@"caption" : @{@"@type" : @"formattedText", @"text" : @"Listen to this"},
			@"voice_note" : @{@"voice" : @{@"id" : @(9)},
							  @"duration" : @(14), @"waveform" : @""}}, nil));
	XCTAssertEqualObjects(flat[@"caption"], @"Listen to this");
	XCTAssertEqualObjects(flat[@"text"], @"Listen to this");
	XCTAssertEqual([flat[@"docId"] longLongValue], 9LL);
}

- (void)testFlatten_AudioCarriesItsCaption {
	NSDictionary *flat = TGFlattenMessage(fxMsg(@{
			@"@type" : @"messageAudio",
			@"caption" : @{@"@type" : @"formattedText", @"text" : @"Best track"},
			@"audio" : @{@"title" : @"Teardrop", @"performer" : @"Massive Attack",
						  @"duration" : @(330), @"audio" : @{@"id" : @(21)}}}, nil));
	XCTAssertEqualObjects(flat[@"caption"], @"Best track");
	XCTAssertEqualObjects(flat[@"text"], @"Best track");
	XCTAssertEqualObjects(flat[@"audioTitle"], @"Teardrop");
}

/// A finished transcript is the words under the voice row, never the caption.
- (void)testFlatten_VoiceNoteTranscriptionText {
	NSDictionary *flat = TGFlattenMessage(fxMsg(@{
			@"@type" : @"messageVoiceNote",
			@"voice_note" : @{@"voice" : @{@"id" : @(9)}, @"duration" : @(3),
				@"speech_recognition_result" : @{
					@"@type" : @"speechRecognitionResultText",
					@"text"  : @"hello there"}}}, nil));
	XCTAssertEqualObjects(flat[@"transcription"], @"hello there");
	XCTAssertFalse([flat[@"transcriptionPending"] boolValue]);
}

- (void)testFlatten_VoiceNoteTranscriptionPendingCarriesPartialText {
	NSDictionary *flat = TGFlattenMessage(fxMsg(@{
			@"@type" : @"messageVoiceNote",
			@"voice_note" : @{@"voice" : @{@"id" : @(9)}, @"duration" : @(3),
				@"speech_recognition_result" : @{
					@"@type" : @"speechRecognitionResultPending",
					@"partial_text" : @"hello"}}}, nil));
	XCTAssertEqualObjects(flat[@"transcription"], @"hello");
	XCTAssertTrue([flat[@"transcriptionPending"] boolValue]);
}

- (void)testFlatten_VoiceNoteTranscriptionPendingWithoutText {
	NSDictionary *flat = TGFlattenMessage(fxMsg(@{
			@"@type" : @"messageVoiceNote",
			@"voice_note" : @{@"voice" : @{@"id" : @(9)}, @"duration" : @(3),
				@"speech_recognition_result" : @{
					@"@type" : @"speechRecognitionResultPending"}}}, nil));
	XCTAssertEqualObjects(flat[@"transcription"], @"");
	XCTAssertTrue([flat[@"transcriptionPending"] boolValue]);
}

- (void)testFlatten_VoiceNoteTranscriptionErrorIsEmpty {
	NSDictionary *flat = TGFlattenMessage(fxMsg(@{
			@"@type" : @"messageVoiceNote",
			@"voice_note" : @{@"voice" : @{@"id" : @(9)}, @"duration" : @(3),
				@"speech_recognition_result" : @{
					@"@type" : @"speechRecognitionResultError",
					@"error" : @{@"message" : @"not available"}}}}, nil));
	XCTAssertEqualObjects(flat[@"transcription"], @"");
	XCTAssertFalse([flat[@"transcriptionPending"] boolValue]);
}

- (void)testFlatten_VoiceNoteWithoutTranscriptionIsEmpty {
	NSDictionary *flat = TGFlattenMessage(fxMsg(@{
			@"@type" : @"messageVoiceNote",
			@"voice_note" : @{@"voice" : @{@"id" : @(9)}, @"duration" : @(3)}}, nil));
	XCTAssertEqualObjects(flat[@"transcription"], @"");
	XCTAssertFalse([flat[@"transcriptionPending"] boolValue]);
}

- (void)testFlatten_VoiceNoteKeepsCaptionAndTranscriptionApart {
	NSDictionary *flat = TGFlattenMessage(fxMsg(@{
			@"@type" : @"messageVoiceNote",
			@"caption" : @{@"@type" : @"formattedText", @"text" : @"Listen"},
			@"voice_note" : @{@"voice" : @{@"id" : @(9)}, @"duration" : @(3),
				@"speech_recognition_result" : @{
					@"@type" : @"speechRecognitionResultText",
					@"text"  : @"the words"}}}, nil));
	XCTAssertEqualObjects(flat[@"caption"], @"Listen");
	XCTAssertEqualObjects(flat[@"transcription"], @"the words");
}

#pragma mark - dice sticker

- (void)testFlatten_DiceRegularStickerBecomesAnimatedRow {
	NSDictionary *flat = TGFlattenMessage(fxMsg(@{
			@"@type" : @"messageDice",
			@"emoji" : @"\U0001F3B2",
			@"value" : @5,
			@"final_state" : @{
				@"@type"   : @"diceStickersRegular",
				@"sticker" : @{
					@"@type"     : @"sticker",
					@"sticker"   : @{@"@type" : @"file", @"id" : @7001},
					@"format"    : @{@"@type" : @"stickerFormatTgs"},
					@"thumbnail" : @{@"file" : @{@"id" : @7002}},
				},
			},
	}, nil));
	XCTAssertEqualObjects(flat[@"kind"], @"messageDice");
	XCTAssertEqual([flat[@"docId"] longLongValue], 7001LL);
	XCTAssertEqualObjects(flat[@"docName"], @"tgs");
	XCTAssertEqual([flat[@"photoId"] longLongValue], 7002LL);
	XCTAssertEqualObjects(flat[@"text"], @"");
	XCTAssertFalse([flat[@"service"] boolValue]);
}

- (void)testFlatten_DiceWebmStickerUsesWebmName {
	NSDictionary *flat = TGFlattenMessage(fxMsg(@{
			@"@type" : @"messageDice",
			@"final_state" : @{
				@"@type"   : @"diceStickersRegular",
				@"sticker" : @{
					@"@type"     : @"sticker",
					@"sticker"   : @{@"@type" : @"file", @"id" : @"7101"},
					@"format"    : @{@"@type" : @"stickerFormatWebm"},
					@"thumbnail" : @{@"file" : @{@"id" : @7102}},
				},
			},
	}, nil));
	XCTAssertEqual([flat[@"docId"] longLongValue], 7101LL);
	XCTAssertEqualObjects(flat[@"docName"], @"webm");
	XCTAssertEqual([flat[@"photoId"] longLongValue], 7102LL);
	XCTAssertEqualObjects(flat[@"text"], @"");
}

- (void)testFlatten_DiceSlotMachineUsesBackground {
	NSDictionary *flat = TGFlattenMessage(fxMsg(@{
			@"@type" : @"messageDice",
			@"final_state" : @{
				@"@type"      : @"diceStickersSlotMachine",
				@"background" : @{
					@"@type"     : @"sticker",
					@"sticker"   : @{@"@type" : @"file", @"id" : @9001},
					@"format"    : @{@"@type" : @"stickerFormatWebm"},
					@"thumbnail" : @{@"file" : @{@"id" : @9002}},
				},
			},
	}, nil));
	XCTAssertEqual([flat[@"docId"] longLongValue], 9001LL);
	XCTAssertEqualObjects(flat[@"docName"], @"webm");
	XCTAssertEqualObjects(flat[@"text"], @"");
}

- (void)testFlatten_DiceMissingFinalStateUsesInitialState {
	NSDictionary *flat = TGFlattenMessage(fxMsg(@{
			@"@type" : @"messageDice",
			@"initial_state" : @{
				@"@type"   : @"diceStickersRegular",
				@"sticker" : @{
					@"@type"     : @"sticker",
					@"sticker"   : @{@"@type" : @"file", @"id" : @7201},
					@"format"    : @{@"@type" : @"stickerFormatTgs"},
					@"thumbnail" : @{@"file" : @{@"id" : @7202}},
				},
			},
	}, nil));
	XCTAssertEqual([flat[@"docId"] longLongValue], 7201LL);
	XCTAssertEqualObjects(flat[@"docName"], @"tgs");
}

- (void)testFlatten_DiceWebpStickerIsTheThumbnail {
	NSDictionary *flat = TGFlattenMessage(fxMsg(@{
			@"@type" : @"messageDice",
			@"final_state" : @{
				@"@type"   : @"diceStickersRegular",
				@"sticker" : @{
					@"@type"   : @"sticker",
					@"sticker" : @{@"@type" : @"file", @"id" : @7301},
					@"format"  : @{@"@type" : @"stickerFormatWebp"},
				},
			},
	}, nil));
	XCTAssertEqual([flat[@"photoId"] longLongValue], 7301LL);
	XCTAssertEqualObjects(flat[@"text"], @"");
	XCTAssertTrue([flat[@"docId"] isKindOfClass:NSNull.class]);
}

- (void)testFlatten_DiceWithoutStickerKeepsValueText {
	NSDictionary *flat = TGFlattenMessage(fxMsg(@{
			@"@type" : @"messageDice",
			@"emoji" : @"\U0001F3B2",
			@"value" : @5,
	}, nil));
	XCTAssertEqualObjects(flat[@"text"], @"\U0001F3B2  5");
	XCTAssertTrue([flat[@"docId"] isKindOfClass:NSNull.class]);
	XCTAssertEqualObjects(flat[@"docName"], @"");
}

#pragma mark - caption above the picture

- (void)testCaptionAbove_PhotoWithShowCaptionAboveMediaIsMarked {
	NSDictionary *content = @{
		@"@type" : @"messagePhoto",
		@"show_caption_above_media" : @YES,
		@"photo" : @{@"@type" : @"photo", @"sizes" : @[]},
		@"caption" : @{@"@type" : @"formattedText", @"text" : @"Photo caption"}
	};
	NSDictionary *flat = TGFlattenMessage(fxMsg(content, nil));
	XCTAssertEqualObjects(flat[@"captionAbove"], @YES);
}

- (void)testCaptionAbove_VideoWithShowCaptionAboveMediaIsMarked {
	NSDictionary *content = @{
		@"@type" : @"messageVideo",
		@"show_caption_above_media" : @YES,
		@"video" : @{@"@type" : @"video", @"width" : @320, @"height" : @240, @"duration" : @10},
		@"caption" : @{@"@type" : @"formattedText", @"text" : @"Video caption"}
	};
	NSDictionary *flat = TGFlattenMessage(fxMsg(content, nil));
	XCTAssertEqualObjects(flat[@"captionAbove"], @YES);
}

- (void)testCaptionAbove_AnimationWithoutShowCaptionAboveMediaIsFalse {
	NSDictionary *content = @{
		@"@type" : @"messageAnimation",
		@"show_caption_above_media" : @NO,
		@"animation" : @{@"@type" : @"animation", @"width" : @320, @"height" : @240},
		@"caption" : @{@"@type" : @"formattedText", @"text" : @"GIF caption"}
	};
	NSDictionary *flat = TGFlattenMessage(fxMsg(content, nil));
	XCTAssertEqualObjects(flat[@"captionAbove"], @NO);
}

- (void)testCaptionAbove_TextRowIsFalse {
	NSDictionary *flat = TGFlattenMessage(fxMsg(fxTextContent(@"hello"), nil));
	XCTAssertEqualObjects(flat[@"captionAbove"], @NO);
}

- (void)testCaptionAbove_AnimationWithShowCaptionAboveMediaIsTrue {
	NSDictionary *content = @{
		@"@type" : @"messageAnimation",
		@"show_caption_above_media" : @YES,
		@"animation" : @{@"@type" : @"animation", @"width" : @320, @"height" : @240},
		@"caption" : @{@"@type" : @"formattedText", @"text" : @"GIF caption"}
	};
	NSDictionary *flat = TGFlattenMessage(fxMsg(content, nil));
	XCTAssertEqualObjects(flat[@"captionAbove"], @YES);
}

- (void)testCaptionAbove_TextRowWithFlagIsStillFalse {
	NSMutableDictionary *content = [fxTextContent(@"plain text") mutableCopy];
	content[@"show_caption_above_media"] = @YES;
	NSDictionary *flat = TGFlattenMessage(fxMsg(content, nil));
	XCTAssertEqualObjects(flat[@"captionAbove"], @NO);
}

#pragma mark - paid media

static NSDictionary *pmPaidMediaItem(NSString *type, int width, int height, NSString *base64Thumb) {
	NSMutableDictionary *item = [@{
		@"@type" : type ?: @"paidMediaPreview",
		@"width" : @(width),
		@"height" : @(height),
	} mutableCopy];
	if (base64Thumb.length) {
		item[@"minithumbnail"] = @{
			@"@type" : @"minithumbnail",
			@"width" : @(width > 0 ? 32 : 0),
			@"height" : @(height > 0 ? 24 : 0),
			@"data" : base64Thumb,
		};
	}
	return item;
}

static NSDictionary *pmPaidMediaMsgContent(id starCount, NSString *caption, NSArray *media) {
	NSMutableDictionary *c = [@{
		@"@type" : @"messagePaidMedia",
		@"star_count" : starCount ?: @0,
		@"media" : media ?: @[],
	} mutableCopy];
	if (caption) {
		c[@"caption"] = @{@"@type" : @"formattedText", @"text" : caption};
	}
	return c;
}

- (void)testPaidMedia_GetsDimensionsFromFirstItemAndPaidPreview {
	NSDictionary *content = pmPaidMediaMsgContent(@(50), @"Exclusive photo", @[
		pmPaidMediaItem(@"paidMediaPreview", 640, 480, nil)
	]);
	NSDictionary *flat = TGFlattenMessage(fxMsg(content, nil));
	XCTAssertEqualObjects(flat[@"mediaWidth"], @(640));
	XCTAssertEqualObjects(flat[@"mediaHeight"], @(480));
	XCTAssertEqualObjects(flat[@"paidPreview"], @YES);
	XCTAssertEqualObjects(flat[@"starCount"], @(50));
	XCTAssertEqualObjects(flat[@"caption"], @"Exclusive photo");
	XCTAssertEqualObjects(flat[@"text"], @"Exclusive photo");
	XCTAssertFalse([flat[@"service"] boolValue]);
}

- (void)testPaidMedia_WithoutCaptionHasEmptyTextAndNotService {
	NSDictionary *content = pmPaidMediaMsgContent(@(100), nil, @[
		pmPaidMediaItem(@"paidMediaPreview", 320, 240, nil)
	]);
	NSDictionary *flat = TGFlattenMessage(fxMsg(content, nil));
	XCTAssertEqualObjects(flat[@"mediaWidth"], @(320));
	XCTAssertEqualObjects(flat[@"mediaHeight"], @(240));
	XCTAssertEqualObjects(flat[@"paidPreview"], @YES);
	XCTAssertEqualObjects(flat[@"starCount"], @(100));
	XCTAssertEqualObjects(flat[@"caption"], @"");
	XCTAssertEqualObjects(flat[@"text"], @"");
	XCTAssertFalse([flat[@"service"] boolValue]);
}

- (void)testPaidMedia_MultipleItemsTakesFirstItemDimensions {
	NSDictionary *content = pmPaidMediaMsgContent(@(25), nil, @[
		pmPaidMediaItem(@"paidMediaPreview", 1080, 720, nil),
		pmPaidMediaItem(@"paidMediaPreview", 400, 300, nil)
	]);
	NSDictionary *flat = TGFlattenMessage(fxMsg(content, nil));
	XCTAssertEqualObjects(flat[@"mediaWidth"], @(1080));
	XCTAssertEqualObjects(flat[@"mediaHeight"], @(720));
	XCTAssertEqualObjects(flat[@"paidPreview"], @YES);
	XCTAssertEqualObjects(flat[@"starCount"], @(25));
	NSArray *items = flat[@"paidMedia"][@"items"];
	XCTAssertEqual(items.count, (NSUInteger)2);
}

- (void)testPaidMedia_StringStarCountConvertedAndKept {
	NSDictionary *content = pmPaidMediaMsgContent(@"42", nil, @[
		pmPaidMediaItem(@"paidMediaPreview", 500, 300, @"aGk=")
	]);
	NSDictionary *flat = TGFlattenMessage(fxMsg(content, nil));
	XCTAssertEqualObjects(flat[@"mediaWidth"], @(500));
	XCTAssertEqualObjects(flat[@"mediaHeight"], @(300));
	XCTAssertEqualObjects(flat[@"paidPreview"], @YES);
	XCTAssertEqual([flat[@"starCount"] longLongValue], 42LL);
	XCTAssertEqual([flat[@"paidMedia"][@"starCount"] longLongValue], 42LL);
}

- (void)testPaidMedia_SingleStarKept {
	NSDictionary *content = pmPaidMediaMsgContent(@(1), nil, @[
		pmPaidMediaItem(@"paidMediaPreview", 200, 200, nil)
	]);
	NSDictionary *flat = TGFlattenMessage(fxMsg(content, nil));
	XCTAssertEqualObjects(flat[@"starCount"], @(1));
	XCTAssertEqualObjects(flat[@"paidPreview"], @YES);
	XCTAssertEqualObjects(flat[@"mediaWidth"], @(200));
	XCTAssertEqualObjects(flat[@"mediaHeight"], @(200));
}

#pragma mark - Community ID flattening

- (void)testChatAddedToCommunity_FlattensCommunityId {
	NSDictionary *content = @{
		@"@type" : @"messageChatAddedToCommunity",
		@"community_id" : @(12345),
	};
	NSDictionary *flat = TGFlattenMessage(fxMsg(content, nil));
	XCTAssertEqualObjects(flat[@"kind"], @"messageChatAddedToCommunity");
	XCTAssertEqualObjects(flat[@"communityId"], @(12345));
}

- (void)testChatJoinFromCommunity_FlattensCommunityId {
	NSDictionary *content = @{
		@"@type" : @"messageChatJoinFromCommunity",
		@"community_id" : @(67890),
	};
	NSDictionary *flat = TGFlattenMessage(fxMsg(content, nil));
	XCTAssertEqualObjects(flat[@"kind"], @"messageChatJoinFromCommunity");
	XCTAssertEqualObjects(flat[@"communityId"], @(67890));
}

- (void)testChatAddedToCommunity_StringCommunityId {
	NSDictionary *content = @{
		@"@type" : @"messageChatAddedToCommunity",
		@"community_id" : @"9876543210",
	};
	NSDictionary *flat = TGFlattenMessage(fxMsg(content, nil));
	XCTAssertEqualObjects(flat[@"kind"], @"messageChatAddedToCommunity");
	XCTAssertEqual([flat[@"communityId"] longLongValue], 9876543210LL);
}


#pragma mark - parity fields

- (void)testExtras_BoostImportRepliersAndUnreadMarks {
	NSDictionary *row = TGFlattenMessage(fxMsg(fxTextContent(@"hi"), @{
		@"sender_boost_count" : @4,
		@"import_info" : @{@"@type" : @"messageImportInfo", @"sender_name" : @"Ann", @"date" : @1500000000},
		@"unread_reactions" : @[@{@"@type" : @"unreadReaction"}, @{@"@type" : @"unreadReaction"}],
		@"contains_unread_poll_votes" : @YES,
		@"interaction_info" : @{@"reply_info" : @{@"reply_count" : @5, @"recent_replier_ids" : @[
			@{@"@type" : @"messageSenderUser", @"user_id" : @7},
			@{@"@type" : @"messageSenderChat", @"chat_id" : @-100},
			@{@"@type" : @"messageSenderUser", @"user_id" : @8},
			@{@"@type" : @"messageSenderUser", @"user_id" : @9}]}},
	}));
	XCTAssertEqualObjects(row[@"boostCount"], @4);
	XCTAssertEqualObjects(row[@"importDate"], @1500000000);
	XCTAssertEqualObjects(row[@"unreadReactions"], @2);
	XCTAssertEqualObjects(row[@"unreadPollVotes"], @YES);
	XCTAssertEqualObjects(row[@"recentRepliers"], (@[@7, @-100, @8]));
	NSDictionary *plain = TGFlattenMessage(fxMsg(fxTextContent(@"hi"), nil));
	XCTAssertNil(plain[@"boostCount"]);
	XCTAssertNil(plain[@"recentRepliers"]);
}

// A retry that TDLib will refuse again is not offered as one.
- (void)testFailedSendBlocker_StarsAndSenderBlockReplyDoesNot {
	NSDictionary *base = @{@"@type" : @"messageSendingStateFailed", @"can_retry" : @YES};
	XCTAssertEqualObjects(TGFailedSendBlocker(base), @"");
	NSMutableDictionary *stars = [base mutableCopy];
	stars[@"required_paid_message_star_count"] = @25;
	XCTAssertEqualObjects(TGFailedSendBlocker(stars), @"stars");
	NSMutableDictionary *sender = [base mutableCopy];
	sender[@"need_another_sender"] = @YES;
	XCTAssertEqualObjects(TGFailedSendBlocker(sender), @"sender");
	NSMutableDictionary *reply = [base mutableCopy];
	reply[@"need_drop_reply"] = @YES;
	XCTAssertEqualObjects(TGFailedSendBlocker(reply), @"");
	NSDictionary *row = TGFlattenMessage(fxMsg(fxTextContent(@"x"), @{@"sending_state" : stars}));
	XCTAssertEqualObjects(row[@"failBlocker"], @"stars");
	XCTAssertEqualObjects(row[@"failStars"], @25);
}

- (void)testReplyKeyboard_CarriesResizeAndPersistent {
	NSDictionary *kb = TGFlattenReplyMarkup(@{@"@type" : @"replyMarkupShowKeyboard",
		@"rows" : @[@[@{@"text" : @"A"}]], @"resize_keyboard" : @YES, @"is_persistent" : @YES})[@"replyKeyboard"];
	XCTAssertEqualObjects(kb[@"resize"], @YES);
	XCTAssertEqualObjects(kb[@"persistent"], @YES);
}

- (void)testLinkPreview_PictureSizeAndPlace {
	NSDictionary *content = @{@"@type" : @"messageText",
		@"text" : @{@"@type" : @"formattedText", @"text" : @"https://x.org"},
		@"link_preview" : @{@"url" : @"https://x.org", @"title" : @"X",
			@"has_large_media" : @YES, @"show_large_media" : @YES,
			@"show_media_above_description" : @YES,
			@"type" : @{@"@type" : @"linkPreviewTypeArticle", @"photo" : @{@"sizes" : @[
				@{@"width" : @90, @"height" : @60, @"photo" : @{@"id" : @11}},
				@{@"width" : @600, @"height" : @400, @"photo" : @{@"id" : @12}},
				@{@"width" : @1280, @"height" : @853, @"photo" : @{@"id" : @13}}]}}}};
	NSDictionary *row = TGFlattenMessage(fxMsg(content, nil));
	XCTAssertEqualObjects(row[@"linkPreviewPhotoId"], @12);
	XCTAssertEqualObjects(row[@"linkPreviewLarge"], @YES);
	XCTAssertEqualObjects(row[@"linkPreviewAbove"], @YES);
	NSMutableDictionary *lp = [content[@"link_preview"] mutableCopy];
	lp[@"has_large_media"] = @NO;
	NSMutableDictionary *fixed = [content mutableCopy];
	fixed[@"link_preview"] = lp;
	XCTAssertEqualObjects(TGFlattenMessage(fxMsg(fixed, nil))[@"linkPreviewLarge"], @NO);
}


#pragma mark - parity fields

- (void)testTimersVideoStartAndManualQuote {
	NSDictionary *row = TGFlattenMessage(fxMsg(@{@"@type" : @"messageVideo",
		@"video" : @{@"duration" : @90}, @"start_timestamp" : @30,
		@"caption" : @{@"@type" : @"formattedText", @"text" : @""}}, @{
		@"auto_delete_in" : @3600.0,
		@"reply_to" : @{@"@type" : @"messageReplyToMessage", @"message_id" : @3,
			@"quote" : @{@"@type" : @"textQuote", @"text" : @{@"@type" : @"formattedText",
				@"text" : @"part"}, @"position" : @0, @"is_manual" : @YES}}}));
	XCTAssertEqualObjects(row[@"startSeconds"], @30);
	XCTAssertEqualObjects(row[@"replyQuoteManual"], @YES);
	double left = [row[@"deleteAt"] doubleValue] - [[NSDate date] timeIntervalSince1970];
	XCTAssertTrue(left > 3590 && left <= 3600, @"%f", left);
	// self_destruct_in wins: the opened timed photo goes first.
	NSDictionary *both = TGFlattenMessage(fxMsg(fxTextContent(@"x"),
		@{@"auto_delete_in" : @3600.0, @"self_destruct_in" : @5.0}));
	XCTAssertTrue([both[@"deleteAt"] doubleValue] - [[NSDate date] timeIntervalSince1970] <= 5);
}

// ChatMessageRestrictedBubbleContentNode: the reason, in italics, instead
// of the content.
- (void)testRestrictedMessage_ShowsTheReason {
	NSDictionary *row = TGFlattenMessage(fxMsg(@{@"@type" : @"messagePhoto",
		@"photo" : @{@"sizes" : @[@{@"width" : @100, @"height" : @100, @"photo" : @{@"id" : @9}}]},
		@"caption" : @{@"@type" : @"formattedText", @"text" : @""}}, @{
		@"restriction_info" : @{@"@type" : @"restrictionInfo",
			@"restriction_reason" : @"This message is unavailable.", @"has_sensitive_content" : @NO}}));
	XCTAssertEqualObjects(row[@"text"], @"This message is unavailable.");
	XCTAssertEqualObjects(row[@"kind"], @"messageText");
	XCTAssertTrue([row[@"photoId"] isKindOfClass:NSNull.class]);
	XCTAssertEqualObjects(row[@"entities"][0][@"type"][@"@type"], @"textEntityTypeItalic");
}


#pragma mark - statistics graphs

- (void)testStatChart_ParsesTelegramChartJson {
	NSString *json = @"{\"columns\":[[\"x\",1,2,3],[\"y0\",5,9,7],[\"y1\",1,2,30]],"
		"\"types\":{\"x\":\"x\",\"y0\":\"line\",\"y1\":\"bar\"},"
		"\"names\":{\"y0\":\"Joined\",\"y1\":\"Left\"},\"colors\":{\"y0\":\"#4BA0E9\"}}";
	NSDictionary *chart = TGStatChartParse(json);
	XCTAssertEqual([chart[@"x"] count], (NSUInteger)3);
	XCTAssertEqual([chart[@"series"] count], (NSUInteger)2);
	XCTAssertEqualObjects(chart[@"series"][0][@"name"], @"Joined");
	XCTAssertEqualObjects(chart[@"series"][0][@"colour"], @"#4BA0E9");
	XCTAssertEqualObjects(chart[@"series"][1][@"type"], @"bar");
	XCTAssertEqual(TGStatChartMax(chart), 30.0);
	XCTAssertNil(TGStatChartParse(@"{\"columns\":[[\"y0\",1]]}"));
	XCTAssertNil(TGStatChartParse(@"not json"));
}


- (void)testActionBarFields_UnarchiveRequestDateAccount {
	NSDictionary *add = TGActionBarFields(@{@"@type" : @"chatActionBarReportAddBlock", @"can_unarchive" : @YES,
		@"account_info" : @{@"registration_month" : @3, @"registration_year" : @2021,
			@"phone_number_country_code" : @"UA", @"last_name_change_date" : @5, @"last_photo_change_date" : @6}});
	XCTAssertEqualObjects(add[@"actionBarCanUnarchive"], @YES);
	XCTAssertEqualObjects(add[@"actionBarAccount"][@"country"], @"UA");
	XCTAssertEqualObjects(add[@"actionBarAccount"][@"registrationYear"], @2021);
	NSDictionary *join = TGActionBarFields(@{@"@type" : @"chatActionBarJoinRequest", @"title" : @"Cats",
		@"is_channel" : @YES, @"request_date" : @1700000000});
	XCTAssertEqualObjects(join[@"actionBarRequestDate"], @1700000000);
	XCTAssertEqualObjects(join[@"actionBarIsChannel"], @YES);
	XCTAssertNil(join[@"actionBarCanUnarchive"]);
	XCTAssertEqual(TGActionBarFields(nil).count, (NSUInteger)0);
}

- (void)testTrack_CarriesTheCoverMinithumbnail {
	NSDictionary *row = TGFlattenMessage(fxMsg(@{@"@type" : @"messageAudio", @"audio" : @{@"duration" : @10,
		@"album_cover_minithumbnail" : @{@"width" : @40, @"height" : @40, @"data" : @"AAAA"}},
		@"caption" : @{@"@type" : @"formattedText", @"text" : @""}}, nil));
	XCTAssertEqualObjects(row[@"albumCoverMini"][@"data"], @"AAAA");
}


- (void)testUnreadMentionMark {
	XCTAssertEqualObjects(TGFlattenMessage(fxMsg(fxTextContent(@"@me"), @{@"contains_unread_mention" : @YES}))[@"unreadMention"], @YES);
	XCTAssertNil(TGFlattenMessage(fxMsg(fxTextContent(@"x"), nil))[@"unreadMention"]);
}


- (void)testBatch8Flatten_PsaReactorsBusinessBotSwitchTarget {
	NSDictionary *row = TGFlattenMessage(fxMsg(fxTextContent(@"x"), @{
		@"forward_info" : @{@"origin" : @{@"@type" : @"messageOriginChannel"}, @"public_service_announcement_type" : @"default"},
		@"interaction_info" : @{@"reactions" : @{@"reactions" : @[], @"can_get_added_reactions" : @NO}}}));
	XCTAssertEqualObjects(row[@"forwardPsa"], @"default");
	XCTAssertEqualObjects(row[@"reactorsHidden"], @YES);
	NSDictionary *bot = TGBusinessBotBarFields(@{@"bot_user_id" : @9, @"is_bot_paused" : @YES,
		@"can_bot_reply" : @YES, @"manage_url" : @"https://t.me/x"})[@"businessBot"];
	XCTAssertEqualObjects(bot[@"botId"], @9);
	XCTAssertEqualObjects(bot[@"paused"], @YES);
	XCTAssertEqual(TGBusinessBotBarFields(nil).count, (NSUInteger)0);
	NSDictionary *kb = TGFlattenReplyMarkup(@{@"@type" : @"replyMarkupInlineKeyboard", @"rows" : @[@[
		@{@"text" : @"Share", @"type" : @{@"@type" : @"inlineKeyboardButtonTypeSwitchInline", @"query" : @"q",
			@"target_chat" : @{@"@type" : @"targetChatChosen"}}}]]});
	XCTAssertEqualObjects(kb[@"inlineRows"][0][0][@"chooseChat"], @YES);
}


#pragma mark - Recent Actions (Channel.AdminLog.*)

static NSString *evName(int64_t uid) { return uid == 7 ? @"Bob" : @"Eve"; }

/// A colour change says only the new colour and icon, with a dot for the
/// swatch (ChatRecentActionsHistoryTransition changeNameColor/ProfileColor).
- (void)testEventLine_ColourChangeNamesTheNewSwatchAndIcon {
	NSDictionary *line = TGChatEventLine(@{@"@type" : @"chatEventAccentColorChanged",
		@"old_accent_color_id" : @1, @"new_accent_color_id" : @4,
		@"old_background_custom_emoji_id" : @"0", @"new_background_custom_emoji_id" : @"0"},
		@"Ann", YES, nil);
	XCTAssertEqualObjects(line[@"title"], @"Ann changed the channel name color to \u25CF");
	XCTAssertEqualObjects(line[@"swatch"][@"location"], @([line[@"title"] length] - 1));
	XCTAssertEqualObjects(line[@"swatch"][@"colorId"], @4);
	XCTAssertFalse([line[@"swatch"][@"profile"] boolValue]);

	line = TGChatEventLine(@{@"@type" : @"chatEventProfileAccentColorChanged",
		@"new_profile_accent_color_id" : @2, @"new_profile_background_custom_emoji_id" : @"55",
		@"iconEmoji" : @"\U0001F431"}, @"Ann", YES, nil);
	XCTAssertEqualObjects(line[@"title"],
			@"Ann changed the channel profile color and icon to \u25CF \U0001F431");
	XCTAssertTrue([line[@"swatch"][@"profile"] boolValue]);

	line = TGChatEventLine(@{@"@type" : @"chatEventProfileAccentColorChanged",
		@"new_profile_accent_color_id" : @(-1), @"new_profile_background_custom_emoji_id" : @"0"},
		@"Ann", YES, nil);
	XCTAssertEqualObjects(line[@"title"], @"Ann changed the removed profile color and icon");
	XCTAssertNil(line[@"swatch"]);
}

- (void)testEventLine_OfficialSentences {
	NSString *(^names)(int64_t) = ^NSString *(int64_t uid){ return evName(uid); };
	NSDictionary *line = TGChatEventLine(@{@"@type" : @"chatEventTitleChanged", @"new_title" : @"Cats"}, @"Ann", NO, names);
	XCTAssertEqualObjects(line[@"title"], @"Ann changed group name to \"Cats\"");
	line = TGChatEventLine(@{@"@type" : @"chatEventDescriptionChanged", @"old_description" : @"old",
		@"new_description" : @"new"}, @"Ann", YES, names);
	XCTAssertEqualObjects(line[@"title"], @"Ann edited channel description");
	XCTAssertEqualObjects(line[@"detail"], @"new\nPrevious description: old");
	line = TGChatEventLine(@{@"@type" : @"chatEventUsernameChanged", @"old_username" : @"a", @"new_username" : @""}, @"Ann", NO, names);
	XCTAssertEqualObjects(line[@"title"], @"Ann removed group link");
	XCTAssertEqualObjects(line[@"detail"], @"Previous link: t.me/a");
	line = TGChatEventLine(@{@"@type" : @"chatEventSlowModeDelayChanged", @"new_slow_mode_delay" : @60}, @"Ann", NO, names);
	XCTAssertEqualObjects(line[@"title"], @"Ann set slowmode to 1 minute");
	line = TGChatEventLine(@{@"@type" : @"chatEventMemberPromoted", @"user_id" : @7,
		@"old_status" : @{@"@type" : @"chatMemberStatusMember"},
		@"new_status" : @{@"@type" : @"chatMemberStatusAdministrator"}}, @"Ann", NO, names);
	XCTAssertEqualObjects(line[@"title"], @"Ann promoted Bob");
	line = TGChatEventLine(@{@"@type" : @"chatEventMemberRestricted", @"member_id" : @{@"user_id" : @7},
		@"old_status" : @{@"@type" : @"chatMemberStatusMember"},
		@"new_status" : @{@"@type" : @"chatMemberStatusBanned"}}, @"Ann", NO, names);
	XCTAssertEqualObjects(line[@"title"], @"Ann banned Bob");
	line = TGChatEventLine(@{@"@type" : @"chatEventPermissionsChanged",
		@"old_permissions" : @{@"can_send_basic_messages" : @YES},
		@"new_permissions" : @{@"can_send_basic_messages" : @NO, @"can_send_polls" : @YES}}, @"Ann", NO, names);
	XCTAssertEqualObjects(line[@"detail"], @"-Send Messages\n+Send Polls");
	line = TGChatEventLine(@{@"@type" : @"chatEventForumTopicToggleIsClosed",
		@"topic_info" : @{@"name" : @"News", @"is_closed" : @YES}}, @"Ann", NO, names);
	XCTAssertEqualObjects(line[@"title"], @"Ann closed topic News");
	line = TGChatEventLine(@{@"@type" : @"chatEventMemberJoinedByInviteLink", @"via_chat_folder_invite_link" : @YES,
		@"invite_link" : @{@"invite_link" : @"t.me/+x"}}, @"Ann", NO, names);
	XCTAssertEqualObjects(line[@"title"], @"Ann joined via invite link t.me/+x (community)");
	line = TGChatEventLine(@{@"@type" : @"chatEventMessageEdited", @"old_message" : @{@"content" : @{@"text" : @{@"text" : @"hi"}}},
		@"new_message" : @{@"content" : @{@"text" : @{@"text" : @"hello"}}}}, @"Ann", NO, names);
	XCTAssertEqualObjects(line[@"detail"], @"hello\nOriginal message: hi");
}

/// Lines that read wrong or fell back to the bare type name.
- (void)testEventLine_ChannelPhotoTogglesAndInvites {
	NSString *(^names)(int64_t) = ^NSString *(int64_t uid){ return evName(uid); };
	XCTAssertEqualObjects(TGChatEventLine(@{@"@type" : @"chatEventPhotoChanged"}, @"Ann", YES, names)[@"title"],
			@"Channel photo removed");
	XCTAssertEqualObjects(TGChatEventLine(@{@"@type" : @"chatEventMemberInvited", @"user_id" : @7}, @"Ann", NO, names)[@"title"],
			@"Ann invited Bob");
	XCTAssertEqualObjects(TGChatEventLine(@{@"@type" : @"chatEventIsAllHistoryAvailableToggled",
			@"is_all_history_available" : @YES}, @"Ann", NO, names)[@"title"],
			@"Ann made the group history visible for new members");
	XCTAssertEqualObjects(TGChatEventLine(@{@"@type" : @"chatEventHasProtectedContentToggled",
			@"has_protected_content" : @NO}, @"Ann", YES, names)[@"title"], @"Ann allowed message forwarding");
	XCTAssertEqualObjects(TGChatEventLine(@{@"@type" : @"chatEventIsForumToggled", @"is_forum" : @YES},
			@"Ann", NO, names)[@"title"], @"Ann enabled topics");
	XCTAssertEqualObjects(TGChatEventLine(@{@"@type" : @"chatEventVideoChatParticipantVolumeLevelChanged",
			@"participant_id" : @{@"user_id" : @7}, @"volume_level" : @5000}, @"Ann", NO, names)[@"title"],
			@"Ann changed Bob volume to 50%");
	XCTAssertEqualObjects(TGChatEventLine(@{@"@type" : @"chatEventMemberJoinedByRequest",
			@"approver_user_id" : @7}, @"Ann", NO, names)[@"title"],
			@"Ann joined via public request, approved by Bob");
	// Newer than this client: still a sentence, never "Ann: AccentColorChanged".
	XCTAssertEqualObjects(TGChatEventLine(@{@"@type" : @"chatEventFutureThingChanged"}, @"Ann", YES, names)[@"title"],
			@"Ann future thing changed");
}

/// Video, audio and files are media too; only photos used to count.
- (void)testEventLine_AnyMediaKindIsSendMedia {
	NSDictionary *line = TGChatEventLine(@{@"@type" : @"chatEventPermissionsChanged",
		@"old_permissions" : @{@"can_send_videos" : @YES},
		@"new_permissions" : @{@"can_send_videos" : @NO}}, @"Ann", NO, nil);
	XCTAssertEqualObjects(line[@"detail"], @"-Send Media");
	line = TGChatEventLine(@{@"@type" : @"chatEventMessageEdited",
		@"old_message" : @{@"content" : @{@"caption" : @{@"text" : @"a"}}},
		@"new_message" : @{@"content" : @{@"caption" : @{@"text" : @"b"}}}}, @"Ann", NO, nil);
	XCTAssertEqualObjects(line[@"title"], @"Ann edited caption:");
	XCTAssertEqualObjects(line[@"detail"], @"b\nOriginal caption: a");
}

@end

// vim:ft=objc
