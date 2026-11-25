//
// TGAutoProxyManager.m - automatic proxy fallback and bootstrap list loader.
//
#import "TGAutoProxyManager.h"
#import "TGSettingsStore.h"
#import "TGClientNotifications.h"

NSString *const TGAutoProxyStatusChangedNotification = @"TGAutoProxyStatusChangedNotification";

static NSString *const TGAutoProxyEnabledKey = @"TGAutoProxyEnabled";
static NSString *const TGAutoProxyBootstrapURLKey = @"TGAutoProxyBootstrapURL";
static NSString *const TGAutoProxyCachedBootstrapKey = @"TGAutoProxyCachedBootstrap";

static NSTimeInterval const TGDefaultFallbackDelay = 5.0;
static NSTimeInterval const TGDefaultCooldownInterval = 30.0;
static NSTimeInterval const TGBootstrapFetchTimeout = 8.0;

@interface TGDefaultAutoProxyBackend : NSObject <TGAutoProxyBackend>
@end

@implementation TGDefaultAutoProxyBackend

- (void)fetchSavedProxies:(TGAutoProxyListCompletion)completion {
	[[TGSettingsStore shared] proxiesWithCompletion:completion];
}

- (void)testProxy:(NSDictionary *)proxy completion:(TGAutoProxyTestCompletion)completion {
	[[TGSettingsStore shared] testProxyAtServer:proxy[@"server"]
										   port:[proxy[@"port"] integerValue]
										   kind:proxy[@"kind"]
									   username:proxy[@"username"]
									   password:proxy[@"password"]
										 secret:proxy[@"secret"]
									 completion:completion];
}

- (void)enableProxyWithId:(NSInteger)proxyId {
	[[TGSettingsStore shared] enableProxy:proxyId];
}

- (void)addAndEnableProxy:(NSDictionary *)proxy completion:(TGAutoProxyAddCompletion)completion {
	[[TGSettingsStore shared] addProxyAtServer:proxy[@"server"]
										  port:[proxy[@"port"] integerValue]
										  kind:proxy[@"kind"]
									  username:proxy[@"username"]
									  password:proxy[@"password"]
										secret:proxy[@"secret"]
										enable:YES
									completion:completion];
}

- (void)fetchBootstrapDataFromURL:(NSURL *)url completion:(TGAutoProxyFetchCompletion)completion {
	NSURLRequest *req = [NSURLRequest requestWithURL:url
										 cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
									 timeoutInterval:TGBootstrapFetchTimeout];
	// iOS 6 compatibility: NSURLSession arrived in iOS 7.
	Class sessionClass = NSClassFromString(@"NSURLSession");
	if (sessionClass) {
		NSURLSession *session = [sessionClass sharedSession];
		NSURLSessionDataTask *task = [session dataTaskWithRequest:req
												completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
			dispatch_async(dispatch_get_main_queue(), ^{
				if (completion)
					completion(data, error);
			});
		}];
		[task resume];
		return;
	}
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSError *error = nil;
		NSURLResponse *response = nil;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
		NSData *data = [NSURLConnection sendSynchronousRequest:req
											 returningResponse:&response
														 error:&error];
#pragma clang diagnostic pop
		dispatch_async(dispatch_get_main_queue(), ^{
			if (completion)
				completion(data, error);
		});
	});
}

@end

@interface TGAutoProxyManager ()
@property (nonatomic, strong) NSUserDefaults *defaults;
@property (nonatomic, strong) id<TGAutoProxyBackend> backend;
@property (nonatomic, assign) BOOL observing;
@property (nonatomic, assign, readwrite, getter=isProbing) BOOL probing;
@property (nonatomic, copy, readwrite) NSString *statusText;
@property (nonatomic, copy, readwrite) NSDictionary *activeProxy;
@property (nonatomic, strong) NSTimer *fallbackTimer;
@property (nonatomic, strong) NSDate *lastFailedSweepDate;
@property (nonatomic, assign) NSUInteger probeGeneration;
@end

@implementation TGAutoProxyManager

+ (instancetype)shared {
	static TGAutoProxyManager *instance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		instance = [[self alloc] initWithUserDefaults:[NSUserDefaults standardUserDefaults]
											  backend:[[TGDefaultAutoProxyBackend alloc] init]];
	});
	return instance;
}

- (instancetype)initWithUserDefaults:(NSUserDefaults *)defaults
							 backend:(id<TGAutoProxyBackend>)backend {
	self = [super init];
	if (self) {
		_defaults = defaults ?: [NSUserDefaults standardUserDefaults];
		_backend = backend ?: [[TGDefaultAutoProxyBackend alloc] init];
		_fallbackDelay = TGDefaultFallbackDelay;
		_cooldownInterval = TGDefaultCooldownInterval;
		_statusText = @"Direct connection";
		[_defaults registerDefaults:@{TGAutoProxyEnabledKey : @YES}];
	}
	return self;
}

- (void)dealloc {
	[self.fallbackTimer invalidate];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Configuration

- (BOOL)isEnabled {
	return [self.defaults boolForKey:TGAutoProxyEnabledKey];
}

- (void)setEnabled:(BOOL)enabled {
	[self.defaults setBool:enabled forKey:TGAutoProxyEnabledKey];
	if (!enabled) {
		[self cancelFallbackTimer];
		self.probeGeneration++;
		self.probing = NO;
		if (!self.activeProxy)
			[self updateStatusText:@"Auto-Proxy disabled"];
	} else {
		[self updateStatusText:self.activeProxy
				? [NSString stringWithFormat:@"Active: %@:%@",
						self.activeProxy[@"server"], self.activeProxy[@"port"]]
				: @"Direct connection"];
	}
}

- (NSString *)bootstrapURL {
	return [self.defaults stringForKey:TGAutoProxyBootstrapURLKey] ?: @"";
}

- (void)setBootstrapURL:(NSString *)bootstrapURL {
	NSString *trimmed = [bootstrapURL stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
	if (trimmed.length)
		[self.defaults setObject:trimmed forKey:TGAutoProxyBootstrapURLKey];
	else
		[self.defaults removeObjectForKey:TGAutoProxyBootstrapURLKey];
}

- (NSArray *)cachedBootstrapProxies {
	NSArray *stored = [self.defaults arrayForKey:TGAutoProxyCachedBootstrapKey];
	return [stored isKindOfClass:NSArray.class] ? stored : @[];
}

- (void)saveCachedBootstrapProxies:(NSArray *)proxies {
	if (proxies.count)
		[self.defaults setObject:proxies forKey:TGAutoProxyCachedBootstrapKey];
	else
		[self.defaults removeObjectForKey:TGAutoProxyCachedBootstrapKey];
}

#pragma mark - Connection State Observation

- (void)startObserving {
	if (self.observing)
		return;
	self.observing = YES;
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(connectionStateNotification:)
												 name:TGConnectionStateChangedNotification
											   object:nil];
}

- (void)connectionStateNotification:(NSNotification *)note {
	TGConnectionState state = (TGConnectionState)[note.userInfo[@"state"] integerValue];
	[self handleConnectionState:state];
}

- (void)handleConnectionState:(TGConnectionState)state {
	if (state == TGConnectionStateReady) {
		[self cancelFallbackTimer];
		self.probeGeneration++;
		self.probing = NO;
		self.lastFailedSweepDate = nil;
		if (self.activeProxy) {
			[self updateStatusText:[NSString stringWithFormat:@"Active: %@:%@",
					self.activeProxy[@"server"], self.activeProxy[@"port"]]];
		} else {
			[self updateStatusText:@"Direct connection"];
		}
		return;
	}

	if (state == TGConnectionStateWaitingForNetwork) {
		[self cancelFallbackTimer];
		[self updateStatusText:@"Waiting for network"];
		return;
	}

	if (state == TGConnectionStateConnecting || state == TGConnectionStateUpdating) {
		if (state == TGConnectionStateConnecting && self.isEnabled && !self.probing) {
			[self scheduleFallbackTimerIfNeeded];
		}
	}
}

- (void)scheduleFallbackTimerIfNeeded {
	if (self.fallbackTimer)
		return;
	if (self.lastFailedSweepDate &&
		[[NSDate date] timeIntervalSinceDate:self.lastFailedSweepDate] < self.cooldownInterval) {
		return;
	}
	[self updateStatusText:@"Connecting..."];
	NSTimeInterval delay = self.fallbackDelay > 0 ? self.fallbackDelay : 0.01;
	self.fallbackTimer = [NSTimer scheduledTimerWithTimeInterval:delay
														  target:self
														selector:@selector(fallbackTimerFired:)
														userInfo:nil
														 repeats:NO];
}

- (void)cancelFallbackTimer {
	[self.fallbackTimer invalidate];
	self.fallbackTimer = nil;
}

- (void)fallbackTimerFired:(NSTimer *)timer {
	self.fallbackTimer = nil;
	if (!self.isEnabled || self.probing)
		return;
	[self startProbingWithAllowRemoteFetch:YES];
}

- (void)triggerFallbackNow {
	[self cancelFallbackTimer];
	self.lastFailedSweepDate = nil;
	[self startProbingWithAllowRemoteFetch:YES];
}

- (void)resetState {
	[self cancelFallbackTimer];
	self.probeGeneration++;
	self.probing = NO;
	self.activeProxy = nil;
	self.lastFailedSweepDate = nil;
	[self saveCachedBootstrapProxies:@[]];
	[self updateStatusText:@"Direct connection"];
}

- (void)updateStatusText:(NSString *)text {
	if ([_statusText isEqualToString:text])
		return;
	_statusText = [text copy];
	[[NSNotificationCenter defaultCenter] postNotificationName:TGAutoProxyStatusChangedNotification
														object:self
													  userInfo:@{@"statusText" : _statusText ?: @""}];
}

#pragma mark - Probing

- (void)startProbingWithAllowRemoteFetch:(BOOL)allowRemoteFetch {
	self.probeGeneration++;
	NSUInteger gen = self.probeGeneration;
	self.probing = YES;
	[self updateStatusText:@"Checking proxies..."];

	__weak typeof(self) weakSelf = self;
	[self.backend fetchSavedProxies:^(NSArray *saved) {
		TGAutoProxyManager *me = weakSelf;
		if (!me || me.probeGeneration != gen)
			return;
		NSArray *candidates = [TGAutoProxyManager mergeCandidates:saved ?: @[]
													withBootstrap:me.cachedBootstrapProxies];
		if (candidates.count > 0) {
			[me probeCandidates:candidates
						atIndex:0
					savedProxies:saved ?: @[]
				allowRemoteFetch:allowRemoteFetch
					  generation:gen];
			return;
		}
		if (allowRemoteFetch && me.bootstrapURL.length > 0) {
			[me fetchRemoteBootstrapAndProbeWithSaved:saved ?: @[]
										alreadyTested:@[]
										   generation:gen];
			return;
		}
		[me finishProbeWithFailure];
	}];
}

- (void)probeCandidates:(NSArray *)candidates
				atIndex:(NSUInteger)index
		   savedProxies:(NSArray *)saved
	   allowRemoteFetch:(BOOL)allowRemoteFetch
			 generation:(NSUInteger)gen {
	if (self.probeGeneration != gen)
		return;
	if (index >= candidates.count) {
		if (allowRemoteFetch && self.bootstrapURL.length > 0) {
			[self fetchRemoteBootstrapAndProbeWithSaved:saved
										  alreadyTested:candidates
											 generation:gen];
			return;
		}
		[self finishProbeWithFailure];
		return;
	}

	NSDictionary *candidate = candidates[index];
	__weak typeof(self) weakSelf = self;
	[self.backend testProxy:candidate completion:^(BOOL works) {
		TGAutoProxyManager *me = weakSelf;
		if (!me || me.probeGeneration != gen)
			return;
		if (works) {
			[me activateWorkingProxy:candidate savedProxies:saved generation:gen];
			return;
		}
		[me probeCandidates:candidates
					atIndex:index + 1
			   savedProxies:saved
		   allowRemoteFetch:allowRemoteFetch
				 generation:gen];
	}];
}

- (void)fetchRemoteBootstrapAndProbeWithSaved:(NSArray *)saved
								alreadyTested:(NSArray *)tested
								   generation:(NSUInteger)gen {
	NSURL *url = [NSURL URLWithString:self.bootstrapURL];
	if (!url || (![url.scheme.lowercaseString isEqualToString:@"https"] &&
				 ![url.scheme.lowercaseString isEqualToString:@"http"])) {
		[self finishProbeWithFailure];
		return;
	}
	[self updateStatusText:@"Fetching proxy list..."];
	__weak typeof(self) weakSelf = self;
	[self.backend fetchBootstrapDataFromURL:url completion:^(NSData *data, NSError *error) {
		TGAutoProxyManager *me = weakSelf;
		if (!me || me.probeGeneration != gen)
			return;
		if (error || !data.length) {
			[me finishProbeWithFailure];
			return;
		}
		NSArray *fetched = [TGAutoProxyManager parseBootstrapPayload:data];
		if (!fetched.count) {
			[me finishProbeWithFailure];
			return;
		}
		[me saveCachedBootstrapProxies:fetched];
		NSMutableSet *testedKeys = [NSMutableSet set];
		for (NSDictionary *p in tested) {
			NSString *key = [TGAutoProxyManager keyForProxy:p];
			if (key)
				[testedKeys addObject:key];
		}
		NSMutableArray *fresh = [NSMutableArray array];
		for (NSDictionary *p in fetched) {
			NSString *key = [TGAutoProxyManager keyForProxy:p];
			if (key && ![testedKeys containsObject:key])
				[fresh addObject:p];
		}
		if (!fresh.count) {
			[me finishProbeWithFailure];
			return;
		}
		[me updateStatusText:@"Checking fetched proxies..."];
		[me probeCandidates:fresh
					atIndex:0
			   savedProxies:saved
		   allowRemoteFetch:NO
				 generation:gen];
	}];
}

- (void)activateWorkingProxy:(NSDictionary *)candidate
				savedProxies:(NSArray *)saved
				  generation:(NSUInteger)gen {
	NSString *targetKey = [TGAutoProxyManager keyForProxy:candidate];
	NSInteger existingId = 0;
	for (NSDictionary *s in saved) {
		if ([[TGAutoProxyManager keyForProxy:s] isEqualToString:targetKey]) {
			existingId = [s[@"id"] integerValue];
			break;
		}
	}

	self.activeProxy = candidate;
	self.probing = NO;
	self.lastFailedSweepDate = nil;
	NSString *label = [NSString stringWithFormat:@"Active: %@:%@",
			candidate[@"server"], candidate[@"port"]];

	if (existingId > 0) {
		[self.backend enableProxyWithId:existingId];
		[self updateStatusText:label];
		return;
	}

	__weak typeof(self) weakSelf = self;
	[self.backend addAndEnableProxy:candidate completion:^(NSInteger proxyId) {
		TGAutoProxyManager *me = weakSelf;
		if (!me || me.probeGeneration != gen)
			return;
		if (proxyId <= 0) {
			[me finishProbeWithFailure];
			return;
		}
		[me updateStatusText:label];
	}];
}

- (void)finishProbeWithFailure {
	self.probing = NO;
	self.lastFailedSweepDate = [NSDate date];
	[self updateStatusText:@"No working proxy found"];
}

#pragma mark - Link & Bootstrap Parsing

+ (NSString *)keyForProxy:(NSDictionary *)proxy {
	NSString *server = [proxy[@"server"] lowercaseString];
	NSInteger port = [proxy[@"port"] integerValue];
	NSString *kind = [proxy[@"kind"] lowercaseString] ?: @"socks5";
	if (!server.length || port <= 0)
		return nil;
	return [NSString stringWithFormat:@"%@:%ld:%@", server, (long)port, kind];
}

+ (NSString *)percentDecoded:(NSString *)value {
	if (!value.length)
		return @"";
	NSString *plusFixed = [value stringByReplacingOccurrencesOfString:@"+" withString:@" "];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	return [plusFixed stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] ?: value;
#pragma clang diagnostic pop
}

+ (NSDictionary *)normaliseProxyDictionary:(NSDictionary *)raw {
	if (![raw isKindOfClass:NSDictionary.class])
		return nil;
	NSString *server = [[raw[@"server"] description] stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSInteger port = [raw[@"port"] integerValue];
	if (!server.length || port <= 0 || port > 65535)
		return nil;

	NSString *secret = [raw[@"secret"] isKindOfClass:NSString.class] ? raw[@"secret"] : @"";
	NSString *username = [raw[@"username"] isKindOfClass:NSString.class]
			? raw[@"username"]
			: ([raw[@"user"] isKindOfClass:NSString.class] ? raw[@"user"] : @"");
	NSString *password = [raw[@"password"] isKindOfClass:NSString.class]
			? raw[@"password"]
			: ([raw[@"pass"] isKindOfClass:NSString.class] ? raw[@"pass"] : @"");
	NSString *kind = [raw[@"kind"] isKindOfClass:NSString.class]
			? [raw[@"kind"] lowercaseString]
			: (secret.length ? @"mtproto" : @"socks5");
	if (![kind isEqualToString:@"mtproto"] && ![kind isEqualToString:@"http"])
		kind = @"socks5";

	return @{
		@"server"   : server,
		@"port"     : @(port),
		@"kind"     : kind,
		@"username" : username ?: @"",
		@"password" : password ?: @"",
		@"secret"   : secret ?: @"",
	};
}

+ (NSDictionary *)parseProxyLink:(NSString *)link {
	NSString *trimmed = [link stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!trimmed.length)
		return nil;

	NSURL *url = [NSURL URLWithString:trimmed];
	if (url && url.query.length) {
		NSMutableDictionary *fields = [NSMutableDictionary dictionary];
		for (NSString *pair in [url.query componentsSeparatedByString:@"&"]) {
			NSRange eq = [pair rangeOfString:@"="];
			if (eq.location == NSNotFound)
				continue;
			NSString *key = [[pair substringToIndex:eq.location] lowercaseString];
			NSString *val = [self percentDecoded:[pair substringFromIndex:eq.location + 1]];
			if (key.length)
				fields[key] = val ?: @"";
		}
		return [self normaliseProxyDictionary:fields];
	}

	// Fallback: "host:port"
	NSArray *parts = [trimmed componentsSeparatedByString:@":"];
	if (parts.count == 2) {
		NSString *host = [parts[0] stringByTrimmingCharactersInSet:
				[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		NSInteger port = [parts[1] integerValue];
		if (host.length && port > 0 && port <= 65535) {
			return [self normaliseProxyDictionary:@{
				@"server" : host,
				@"port"   : @(port),
				@"kind"   : @"socks5",
			}];
		}
	}
	return nil;
}

+ (NSArray *)parseBootstrapPayload:(NSData *)data {
	if (!data.length)
		return @[];

	NSMutableArray *parsed = [NSMutableArray array];
	NSMutableSet *seen = [NSMutableSet set];

	void (^appendItem)(NSDictionary *) = ^(NSDictionary *item) {
		if (!item)
			return;
		NSString *key = [self keyForProxy:item];
		if (!key || [seen containsObject:key])
			return;
		[seen addObject:key];
		[parsed addObject:item];
	};

	id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
	NSArray *entries = nil;
	if ([json isKindOfClass:NSArray.class]) {
		entries = json;
	} else if ([json isKindOfClass:NSDictionary.class] &&
			   [json[@"proxies"] isKindOfClass:NSArray.class]) {
		entries = json[@"proxies"];
	}

	if (entries) {
		for (id entry in entries) {
			if ([entry isKindOfClass:NSString.class]) {
				appendItem([self parseProxyLink:entry]);
			} else if ([entry isKindOfClass:NSDictionary.class]) {
				appendItem([self normaliseProxyDictionary:entry]);
			}
		}
		return parsed;
	}

	NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	if (!text.length)
		return @[];
	NSArray *lines = [text componentsSeparatedByCharactersInSet:
			[NSCharacterSet newlineCharacterSet]];
	for (NSString *line in lines) {
		NSString *trimmed = [line stringByTrimmingCharactersInSet:
				[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		if (!trimmed.length || [trimmed hasPrefix:@"#"])
			continue;
		appendItem([self parseProxyLink:trimmed]);
	}
	return parsed;
}

+ (NSArray *)mergeCandidates:(NSArray *)saved withBootstrap:(NSArray *)bootstrap {
	NSMutableArray *merged = [NSMutableArray array];
	NSMutableSet *seen = [NSMutableSet set];

	void (^appendList)(NSArray *) = ^(NSArray *list) {
		for (NSDictionary *item in list) {
			NSDictionary *norm = [self normaliseProxyDictionary:item];
			if (!norm)
				continue;
			NSString *key = [self keyForProxy:norm];
			if (!key || [seen containsObject:key])
				continue;
			[seen addObject:key];
			[merged addObject:norm];
		}
	};

	appendList(saved);
	appendList(bootstrap);
	return merged;
}

@end
