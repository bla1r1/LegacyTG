// TGAutoProxyManagerTests.m - link parsing, bootstrap decoding, and fallback state machine.
#import "TGTestRunner.h"
#import "TGAutoProxyManager.h"

@interface TGMockAutoProxyBackend : NSObject <TGAutoProxyBackend>
@property (nonatomic, copy) NSArray *savedProxies;
@property (nonatomic, copy) NSSet *workingServers;
@property (nonatomic, copy) NSData *bootstrapData;
@property (nonatomic, strong) NSError *bootstrapError;

@property (nonatomic, assign) NSInteger enabledProxyId;
@property (nonatomic, strong) NSMutableArray *testedServers;
@property (nonatomic, strong) NSMutableArray *addedProxies;
@property (nonatomic, assign) NSInteger fetchCount;
@end

@implementation TGMockAutoProxyBackend

- (instancetype)init {
	self = [super init];
	if (self) {
		_testedServers = [NSMutableArray array];
		_addedProxies = [NSMutableArray array];
	}
	return self;
}

- (void)fetchSavedProxies:(TGAutoProxyListCompletion)completion {
	if (completion)
		completion(self.savedProxies ?: @[]);
}

- (void)testProxy:(NSDictionary *)proxy completion:(TGAutoProxyTestCompletion)completion {
	NSString *server = proxy[@"server"] ?: @"";
	[self.testedServers addObject:server];
	if (completion)
		completion([self.workingServers containsObject:server]);
}

- (void)enableProxyWithId:(NSInteger)proxyId {
	self.enabledProxyId = proxyId;
}

- (void)addAndEnableProxy:(NSDictionary *)proxy completion:(TGAutoProxyAddCompletion)completion {
	[self.addedProxies addObject:proxy];
	if (completion)
		completion(42);
}

- (void)fetchBootstrapDataFromURL:(NSURL *)url completion:(TGAutoProxyFetchCompletion)completion {
	self.fetchCount++;
	if (completion)
		completion(self.bootstrapData, self.bootstrapError);
}

@end

@interface TGAutoProxyManagerTests : XCTestCase
@end

@implementation TGAutoProxyManagerTests

- (NSUserDefaults *)isolatedDefaults {
	NSString *suite = [NSString stringWithFormat:@"TGAutoProxyTests-%@", [[NSUUID UUID] UUIDString]];
	NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
	return defaults;
}

- (void)testParseProxyLinkMtprotoSocks5AndHostPort {
	NSDictionary *mt = [TGAutoProxyManager parseProxyLink:
			@"https://t.me/proxy?server=1.2.3.4&port=443&secret=ee1234567890abcdef"];
	XCTAssertNotNil(mt);
	XCTAssertEqualObjects(mt[@"server"], @"1.2.3.4");
	XCTAssertEqual([mt[@"port"] integerValue], 443);
	XCTAssertEqualObjects(mt[@"kind"], @"mtproto");
	XCTAssertEqualObjects(mt[@"secret"], @"ee1234567890abcdef");

	NSDictionary *socks = [TGAutoProxyManager parseProxyLink:
			@"tg://socks?server=proxy.example.com&port=1080&user=alice&pass=s3cr3t"];
	XCTAssertNotNil(socks);
	XCTAssertEqualObjects(socks[@"server"], @"proxy.example.com");
	XCTAssertEqual([socks[@"port"] integerValue], 1080);
	XCTAssertEqualObjects(socks[@"kind"], @"socks5");
	XCTAssertEqualObjects(socks[@"username"], @"alice");
	XCTAssertEqualObjects(socks[@"password"], @"s3cr3t");

	NSDictionary *raw = [TGAutoProxyManager parseProxyLink:@"10.0.0.1:8080"];
	XCTAssertNotNil(raw);
	XCTAssertEqualObjects(raw[@"server"], @"10.0.0.1");
	XCTAssertEqual([raw[@"port"] integerValue], 8080);
	XCTAssertEqualObjects(raw[@"kind"], @"socks5");

	XCTAssertNil([TGAutoProxyManager parseProxyLink:@""]);
	XCTAssertNil([TGAutoProxyManager parseProxyLink:@"https://t.me/proxy?server=1.2.3.4&port=99999"]);
}

- (void)testParseBootstrapPayloadJsonAndPlainText {
	NSString *plain = @"# comment\n"
					  @"tg://proxy?server=1.1.1.1&port=443&secret=eeaa\n"
					  @"https://t.me/proxy?server=1.1.1.1&port=443&secret=eeaa\n"
					  @"tg://socks?server=2.2.2.2&port=1080\n";
	NSArray *fromText = [TGAutoProxyManager parseBootstrapPayload:
			[plain dataUsingEncoding:NSUTF8StringEncoding]];
	XCTAssertEqual(fromText.count, (NSUInteger)2);
	XCTAssertEqualObjects(fromText[0][@"server"], @"1.1.1.1");
	XCTAssertEqualObjects(fromText[1][@"server"], @"2.2.2.2");

	NSString *jsonStr = @"{\"proxies\":["
						@"\"tg://proxy?server=3.3.3.3&port=443&secret=eebb\","
						@"{\"server\":\"4.4.4.4\",\"port\":8443,\"kind\":\"mtproto\",\"secret\":\"eecc\"}"
						@"]}";
	NSArray *fromJson = [TGAutoProxyManager parseBootstrapPayload:
			[jsonStr dataUsingEncoding:NSUTF8StringEncoding]];
	XCTAssertEqual(fromJson.count, (NSUInteger)2);
	XCTAssertEqualObjects(fromJson[0][@"server"], @"3.3.3.3");
	XCTAssertEqualObjects(fromJson[1][@"server"], @"4.4.4.4");
	XCTAssertEqual([fromJson[1][@"port"] integerValue], 8443);
}

- (void)testMergeCandidatesPrioritizesSavedAndDeduplicates {
	NSArray *saved = @[
		@{@"server" : @"1.1.1.1", @"port" : @443, @"kind" : @"mtproto", @"secret" : @"eeaa"},
	];
	NSArray *boot = @[
		@{@"server" : @"1.1.1.1", @"port" : @443, @"kind" : @"mtproto", @"secret" : @"eeaa"},
		@{@"server" : @"2.2.2.2", @"port" : @443, @"kind" : @"mtproto", @"secret" : @"eebb"},
	];
	NSArray *merged = [TGAutoProxyManager mergeCandidates:saved withBootstrap:boot];
	XCTAssertEqual(merged.count, (NSUInteger)2);
	XCTAssertEqualObjects(merged[0][@"server"], @"1.1.1.1");
	XCTAssertEqualObjects(merged[1][@"server"], @"2.2.2.2");
}

- (void)testTriggerFallbackEnablesExistingWorkingSavedProxy {
	TGMockAutoProxyBackend *backend = [[TGMockAutoProxyBackend alloc] init];
	backend.savedProxies = @[
		@{@"id" : @10, @"server" : @"dead.example", @"port" : @443, @"kind" : @"mtproto", @"secret" : @"ee11"},
		@{@"id" : @25, @"server" : @"good.example", @"port" : @443, @"kind" : @"mtproto", @"secret" : @"ee22"},
	];
	backend.workingServers = [NSSet setWithObject:@"good.example"];

	TGAutoProxyManager *mgr = [[TGAutoProxyManager alloc] initWithUserDefaults:[self isolatedDefaults]
																	   backend:backend];
	[mgr triggerFallbackNow];

	XCTAssertEqual(backend.enabledProxyId, (NSInteger)25);
	XCTAssertEqual(backend.addedProxies.count, (NSUInteger)0);
	XCTAssertEqualObjects(mgr.activeProxy[@"server"], @"good.example");
	XCTAssertFalse(mgr.isProbing);
	XCTAssertEqualObjects(mgr.statusText, @"Active: good.example:443");
}

- (void)testTriggerFallbackFetchesBootstrapWhenSavedFailAndAddsWorkingProxy {
	TGMockAutoProxyBackend *backend = [[TGMockAutoProxyBackend alloc] init];
	backend.savedProxies = @[
		@{@"id" : @10, @"server" : @"dead.example", @"port" : @443, @"kind" : @"mtproto", @"secret" : @"ee11"},
	];
	backend.workingServers = [NSSet setWithObject:@"fresh.example"];
	backend.bootstrapData = [@"tg://proxy?server=fresh.example&port=443&secret=ee99"
			dataUsingEncoding:NSUTF8StringEncoding];

	TGAutoProxyManager *mgr = [[TGAutoProxyManager alloc] initWithUserDefaults:[self isolatedDefaults]
																	   backend:backend];
	mgr.bootstrapURL = @"https://example.com/proxies.txt";
	[mgr triggerFallbackNow];

	XCTAssertEqual(backend.fetchCount, (NSInteger)1);
	XCTAssertEqual(backend.addedProxies.count, (NSUInteger)1);
	XCTAssertEqualObjects(backend.addedProxies[0][@"server"], @"fresh.example");
	XCTAssertEqualObjects(mgr.statusText, @"Active: fresh.example:443");
	XCTAssertEqual(mgr.cachedBootstrapProxies.count, (NSUInteger)1);
}

- (void)testDisabledAutoProxyDoesNotStartProbingOnConnecting {
	TGMockAutoProxyBackend *backend = [[TGMockAutoProxyBackend alloc] init];
	TGAutoProxyManager *mgr = [[TGAutoProxyManager alloc] initWithUserDefaults:[self isolatedDefaults]
																	   backend:backend];
	mgr.enabled = NO;
	[mgr handleConnectionState:TGConnectionStateConnecting];

	XCTAssertFalse(mgr.isProbing);
	XCTAssertEqual(backend.testedServers.count, (NSUInteger)0);
	XCTAssertEqualObjects(mgr.statusText, @"Auto-Proxy disabled");
}

- (void)testReadyStateUpdatesStatusAndClearsProbing {
	TGMockAutoProxyBackend *backend = [[TGMockAutoProxyBackend alloc] init];
	TGAutoProxyManager *mgr = [[TGAutoProxyManager alloc] initWithUserDefaults:[self isolatedDefaults]
																	   backend:backend];
	[mgr handleConnectionState:TGConnectionStateConnecting];
	[mgr handleConnectionState:TGConnectionStateReady];

	XCTAssertFalse(mgr.isProbing);
	XCTAssertEqualObjects(mgr.statusText, @"Direct connection");
}

@end
