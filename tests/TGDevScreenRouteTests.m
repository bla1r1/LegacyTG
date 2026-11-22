//
// TGDevScreenRouteTests.m - itglegacy://vc/<Class> picks only screens it can
// open on its own, and hands a chat to the ones that take one. The route
// passes UIViewController as the base; here a plain stand-in plays it.
//
#import "TGTestRunner.h"
#import "TGDevScreenRoute.h"

@interface TGWalkProbeBase : NSObject
@end
@implementation TGWalkProbeBase
@end

@interface TGWalkProbeChatScreen : TGWalkProbeBase
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, copy) NSString *chatTitle;
@end
@implementation TGWalkProbeChatScreen
@end

@interface TGWalkProbeInitScreen : TGWalkProbeBase
@property (nonatomic, assign) int64_t given;
@property (nonatomic, copy) NSString *givenTitle;
- (instancetype)initWithChatId:(int64_t)chatId title:(NSString *)title;
@end
@implementation TGWalkProbeInitScreen
- (instancetype)initWithChatId:(int64_t)chatId title:(NSString *)title {
	if ((self = [super init])){
		_given = chatId;
		_givenTitle = [title copy];
	}
	return self;
}
@end

@interface TGDevScreenRouteTests : XCTestCase
@end

@implementation TGDevScreenRouteTests

- (void)testOnlyOurScreensResolve {
	Class base = [TGWalkProbeBase class];
	XCTAssertTrue(TGDevScreenClass(@"TGWalkProbeChatScreen", base) == [TGWalkProbeChatScreen class]);
	XCTAssertTrue(TGDevScreenClass(@"NSObject", base) == Nil, @"not ours");
	XCTAssertTrue(TGDevScreenClass(@"TGDevScreenRouteTests", base) == Nil, @"not a screen");
	XCTAssertTrue(TGDevScreenClass(@"TGNoSuchScreenAnywhere", base) == Nil);
	XCTAssertTrue(TGDevScreenClass(nil, base) == Nil);
}

/// Chat and call screens without their live state would crash the walk and
/// lose every shot after them; they keep their own routes.
- (void)testScreensWithTheirOwnRoutesAreRefused {
	Class base = [NSObject class];
	XCTAssertTrue(TGDevScreenClass(@"TGChatViewController", base) == Nil);
	XCTAssertTrue(TGDevScreenClass(@"TGCallViewController", base) == Nil);
	XCTAssertTrue(TGDevScreenClass(@"TGLoginViewController", base) == Nil);
}

- (void)testChatReachesTheScreenThroughItsInitialiser {
	TGWalkProbeInitScreen *screen = TGDevScreenMake([TGWalkProbeInitScreen class], 777, @"Walk");
	XCTAssertEqual(screen.given, 777LL);
	XCTAssertEqualObjects(screen.givenTitle, @"Walk");
}

- (void)testChatReachesTheScreenThroughItsProperty {
	TGWalkProbeChatScreen *screen = TGDevScreenMake([TGWalkProbeChatScreen class], -1001, @"Group");
	XCTAssertEqual(screen.chatId, -1001LL);
	XCTAssertEqualObjects(screen.chatTitle, @"Group");
	TGWalkProbeChatScreen *none = TGDevScreenMake([TGWalkProbeChatScreen class], 0, nil);
	XCTAssertEqual(none.chatId, 0LL, @"no chat, nothing set");
}

@end
