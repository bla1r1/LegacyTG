//
// TGAutoProxyManager.h - automatic proxy fallback and bootstrap list loader.
//
// Listens to TDLib connection state updates: if direct connection stays in
// Connecting past a short grace window, probes saved and bootstrap MTProto
// (Fake-TLS) / SOCKS5 proxies via testProxy and enables the first working one.
//
#import <Foundation/Foundation.h>
#import "TGClientTypes.h"

extern NSString *const TGAutoProxyStatusChangedNotification;

typedef void (^TGAutoProxyListCompletion)(NSArray *proxies);
typedef void (^TGAutoProxyTestCompletion)(BOOL works);
typedef void (^TGAutoProxyAddCompletion)(NSInteger proxyId);
typedef void (^TGAutoProxyFetchCompletion)(NSData *data, NSError *error);

/// Abstraction over TDLib proxy operations so TGAutoProxyManager can be tested
/// in isolation on the host without a live TDLib instance.
@protocol TGAutoProxyBackend <NSObject>
- (void)fetchSavedProxies:(TGAutoProxyListCompletion)completion;
- (void)testProxy:(NSDictionary *)proxy completion:(TGAutoProxyTestCompletion)completion;
- (void)enableProxyWithId:(NSInteger)proxyId;
- (void)addAndEnableProxy:(NSDictionary *)proxy completion:(TGAutoProxyAddCompletion)completion;
- (void)fetchBootstrapDataFromURL:(NSURL *)url completion:(TGAutoProxyFetchCompletion)completion;
@end

@interface TGAutoProxyManager : NSObject

+ (instancetype)shared;

/// Designated initializer for unit tests with custom defaults and backend.
- (instancetype)initWithUserDefaults:(NSUserDefaults *)defaults
							 backend:(id<TGAutoProxyBackend>)backend;

@property (nonatomic, assign, getter=isEnabled) BOOL enabled;
@property (nonatomic, copy) NSString *bootstrapURL;
@property (nonatomic, assign) NSTimeInterval fallbackDelay;
@property (nonatomic, assign) NSTimeInterval cooldownInterval;

@property (nonatomic, copy, readonly) NSString *statusText;
@property (nonatomic, assign, readonly, getter=isProbing) BOOL probing;
@property (nonatomic, copy, readonly) NSDictionary *activeProxy;
@property (nonatomic, copy, readonly) NSArray *cachedBootstrapProxies;

/// Starts observing TGConnectionStateChangedNotification. Safe to call multiple times.
- (void)startObserving;

/// Feeds a connection state directly (also called by the notification observer).
- (void)handleConnectionState:(TGConnectionState)state;

/// Immediately starts probing saved and bootstrap proxies, bypassing the delay
/// and cooldown.
- (void)triggerFallbackNow;

/// Clears cached bootstrap proxies and resets failure cooldown.
- (void)resetState;

#pragma mark - Link & Bootstrap Parsing

/// Parses tg://proxy?..., https://t.me/proxy?..., tg://socks?...,
/// https://t.me/socks?... or "host:port" into a normalised proxy dictionary:
/// @{@"server", @"port", @"kind", @"username", @"password", @"secret"}.
/// Returns nil when server or port is missing or invalid.
+ (NSDictionary *)parseProxyLink:(NSString *)link;

/// Parses a bootstrap response (JSON array of strings/dicts, {"proxies":[...]},
/// or newline-separated proxy links) into normalised proxy dictionaries.
+ (NSArray *)parseBootstrapPayload:(NSData *)data;

/// Merges saved proxies with bootstrap candidates, keeping saved proxies first
/// and deduplicating by server:port:kind.
+ (NSArray *)mergeCandidates:(NSArray *)saved withBootstrap:(NSArray *)bootstrap;

@end
