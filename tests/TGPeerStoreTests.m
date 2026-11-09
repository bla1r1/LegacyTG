//
// TGPeerStoreTests.m - the peer record, its coalesced changes and one download
// per file id.
//
// The record builders are pure, so the first two tests never touch TDLib. The
// avatar test injects a loader; no file is read and no network is reached.
//
#import "TGTestRunner.h"
#import "TGPeerStore.h"
#import "TGClient.h"
#import "TGClientInternal.h"

/// Private seams defined in TGPeerStore.m. Declared here so the test can
/// drive the coalescer and count downloads without exposing them to screens.
@interface TGPeerStore (TGPeerStoreTesting)
+ (void)setAvatarLoaderForTesting:(void (^)(NSInteger fileId,
		void (^completion)(NSString *path)))loader;
- (void)notePeerChanged:(int64_t)peerId;
- (void)flushChangedPeers;
@end

@interface TGPeerStoreTests : XCTestCase @end

@implementation TGPeerStoreTests

- (void)setUp {
	[super setUp];
	[[TGPeerStore shared] reset];
	[[TGPeerStore shared] flushChangedPeers];
}

- (void)tearDown {
	[TGPeerStore setAvatarLoaderForTesting:nil];
	[[TGPeerStore shared] reset];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super tearDown];
}

- (void)testUserRecordFromTDLibShape {
	NSDictionary *user = @{
		@"@type" : @"user",
		@"id" : @(42),
		@"first_name" : @"Ada",
		@"last_name" : @"Lovelace",
		@"usernames" : @{@"active_usernames" : @[@"ada"]},
		@"is_verified" : @YES,
		@"emoji_status" : @{
			@"@type" : @"emojiStatus",
			@"type" : @{
				@"@type" : @"emojiStatusTypeCustomEmoji",
				@"custom_emoji_id" : @(123456),
			},
		},
		@"status" : @{@"@type" : @"userStatusOnline"},
	};
	TGPeer *peer = [TGPeer peerFromUser:user];
	XCTAssertNotNil(peer);
	XCTAssertEqual(peer.peerId, (int64_t)42);
	XCTAssertTrue(peer.isUser);
	XCTAssertFalse(peer.isGroup);
	XCTAssertFalse(peer.isChannel);
	XCTAssertEqualObjects(peer.title, @"Ada Lovelace");
	XCTAssertEqualObjects(peer.initials, @"AL");
	XCTAssertEqualObjects(peer.username, @"ada");
	XCTAssertTrue(peer.verified);
	XCTAssertEqual(peer.emojiStatusId, (int64_t)123456);
	XCTAssertTrue(peer.online);
	XCTAssertEqualObjects(peer.lastSeenText, @"online");
	XCTAssertEqual(peer.memberCount, (NSInteger)0);
}

- (void)testChatRecordFromTDLibShape {
	NSDictionary *chat = @{
		@"@type" : @"chat",
		@"id" : @(-1007),
		@"title" : @"Legacy Builders",
		@"type" : @{
			@"@type" : @"chatTypeSupergroup",
			@"supergroup_id" : @(7),
			@"is_channel" : @NO,
		},
		@"member_count" : @(1234),
	};
	TGPeer *peer = [TGPeer peerFromChat:chat];
	XCTAssertNotNil(peer);
	XCTAssertEqual(peer.peerId, (int64_t)-1007);
	XCTAssertFalse(peer.isUser);
	XCTAssertTrue(peer.isGroup);
	XCTAssertFalse(peer.isChannel);
	XCTAssertEqualObjects(peer.title, @"Legacy Builders");
	XCTAssertEqualObjects(peer.initials, @"LB");
	XCTAssertEqual(peer.memberCount, (NSInteger)1234);
}

- (void)testInitialsSkipLeadingSymbols {
	NSDictionary *user = @{
		@"@type" : @"user",
		@"id" : @(43),
		@"first_name" : @"\U0001F600Bob",
		@"last_name" : @"",
	};
	TGPeer *peer = [TGPeer peerFromUser:user];
	XCTAssertEqualObjects(peer.initials, @"B");
}

- (void)testChangeBurstPostsOneNotificationWithEveryId {
	TGPeerStore *store = [TGPeerStore shared];
	__block NSInteger posts = 0;
	__block NSArray *lastIds = nil;
	id observer = [[NSNotificationCenter defaultCenter]
			addObserverForName:TGPeerStoreChangedNotification
						object:store queue:nil
					usingBlock:^(NSNotification *note) {
		posts++;
		lastIds = note.userInfo[@"ids"];
	}];

	for (NSInteger i = 1; i <= 40; i++)
		[store notePeerChanged:i];
	[store flushChangedPeers];

	[[NSNotificationCenter defaultCenter] removeObserver:observer];
	XCTAssertEqual(posts, (NSInteger)1);
	XCTAssertEqual(lastIds.count, (NSUInteger)40);
	XCTAssertEqual([NSSet setWithArray:lastIds].count, (NSUInteger)40);
}

- (void)testParallelRequestsShareOneDownloadPerFileId {
	int64_t peerId = 901;
	NSInteger fileId = 777;
	[TGClient shared].userPhotosById[@(peerId)] = @(fileId);

	__block NSInteger loads = 0;
	[TGPeerStore setAvatarLoaderForTesting:^(NSInteger askedFileId,
			void (^completion)(NSString *path)) {
		XCTAssertEqual(askedFileId, fileId);
		loads++;
		// A real download finishes after the callers of this tick have all
		// registered; deliver the fake path the same way.
		dispatch_async(dispatch_get_main_queue(), ^{
			completion(@"/nonexistent/TGPeerStoreTests-avatar.png");
		});
	}];

	__block NSInteger completions = 0;
	for (NSInteger i = 0; i < 6; i++){
		[[TGPeerStore shared] loadAvatarForPeer:peerId side:48
									completion:^(UIImage *image){
			(void)image;
			completions++;
		}];
	}

	NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:2.0];
	while (completions < 6 && [deadline timeIntervalSinceNow] > 0)
		[[NSRunLoop currentRunLoop] runUntilDate:
				[NSDate dateWithTimeIntervalSinceNow:0.01]];

	XCTAssertEqual(loads, (NSInteger)1);
	XCTAssertEqual(completions, (NSInteger)6);
	[[TGClient shared].userPhotosById removeObjectForKey:@(peerId)];
}

@end
