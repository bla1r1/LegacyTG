// TGVideoAvatarTests.m - which clip a moving profile picture plays and
// where it starts (official PeerInfoAvatarListNode).
#import "TGTestRunner.h"
#import "TGVideoAvatar.h"

@interface TGVideoAvatarTests : XCTestCase @end

@implementation TGVideoAvatarTests

- (void)testSmallClipFirstAndTheMainFrame {
	NSDictionary *photo = @{@"@type" : @"chatPhoto",
		@"animation" : @{@"length" : @800, @"file" : @{@"id" : @11}, @"main_frame_timestamp" : @1.5},
		@"small_animation" : @{@"length" : @160, @"file" : @{@"id" : @12}, @"main_frame_timestamp" : @1.5}};
	NSDictionary *clip = TGVideoAvatarFrom(photo);
	XCTAssertEqualObjects(clip[@"fileId"], @12);
	XCTAssertEqualObjects(clip[@"frame"], @1.5);
	NSDictionary *largeOnly = TGVideoAvatarFrom(@{@"animation" : @{@"file" : @{@"id" : @11}}});
	XCTAssertEqualObjects(largeOnly[@"fileId"], @11);
	XCTAssertNil(TGVideoAvatarFrom(@{@"@type" : @"chatPhoto", @"sizes" : @[]}), @"a still photo plays nothing");
}

- (void)testOnlyARecordThatSaysItMovesIsAskedFor {
	XCTAssertTrue(TGVideoAvatarAnnounced(@{@"@type" : @"profilePhoto", @"has_animation" : @YES}));
	XCTAssertFalse(TGVideoAvatarAnnounced(@{@"@type" : @"chatPhotoInfo", @"has_animation" : @NO}));
	XCTAssertFalse(TGVideoAvatarAnnounced(nil));
}

/// A photo made from a sticker of a set: the set, the sticker and the fill
/// behind it, then that sticker's file in the set (official AvatarVideoNode).
- (void)testStickerPhotoNamesItsStickerAndFill {
	NSDictionary *photo = @{@"@type" : @"chatPhoto", @"sticker" : @{@"@type" : @"chatPhotoSticker",
		@"type" : @{@"@type" : @"chatPhotoStickerTypeRegularOrMask", @"sticker_set_id" : @"5", @"sticker_id" : @"9"},
		@"background_fill" : @{@"@type" : @"backgroundFillGradient", @"top_color" : @1, @"bottom_color" : @2}}};
	NSDictionary *avatar = TGStickerAvatarFrom(photo);
	XCTAssertEqualObjects(avatar[@"setId"], @5);
	XCTAssertEqualObjects(avatar[@"stickerId"], @9);
	XCTAssertEqualObjects(avatar[@"colours"], (@[@1, @2]));
	XCTAssertNil(TGStickerAvatarFrom(@{@"sticker" : @{@"type" : @{@"@type" : @"chatPhotoStickerTypeCustomEmoji",
		@"custom_emoji_id" : @"3"}}}));

	NSArray *set = @[@{@"id" : @"8", @"sticker" : @{@"id" : @80}, @"format" : @{@"@type" : @"stickerFormatTgs"}},
					 @{@"id" : @"9", @"sticker" : @{@"id" : @90}, @"format" : @{@"@type" : @"stickerFormatWebm"}}];
	NSDictionary *pick = TGStickerAvatarPick(set, 9);
	XCTAssertEqualObjects(pick[@"fileId"], @90);
	XCTAssertEqualObjects(pick[@"format"], @"webm");
	XCTAssertNil(TGStickerAvatarPick(set, 7));
}

@end
