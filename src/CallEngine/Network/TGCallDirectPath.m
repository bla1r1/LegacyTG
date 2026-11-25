#import "TGCallDirectPath.h"
#import "TGCallStun.h"

#include <arpa/inet.h>
#include <errno.h>
#include <ifaddrs.h>
#include <netdb.h>
#include <net/if.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

// Checks every 200 ms until a path is chosen, then one a second to keep it
// (WebRTC's consent freshness answers them). 3 s without a packet from the
// chosen address and the media goes back to the reflector.
static const NSTimeInterval kCheckInterval = 0.2;
static const NSTimeInterval kKeepInterval = 1.0;
static const NSTimeInterval kSilence = 3.0;

// RFC 8445 5.1.2.1 type preferences: host 126, srflx 100; local preference
// 65535, component 1. Both outrank the reflector's 41877760, so the peer
// prefers them once they work.
static const uint32_t kHostPriority = (126u << 24) | (65535u << 8) | 255u;
static const uint32_t kSrflxPriority = (100u << 24) | (65535u << 8) | 255u;

static BOOL TGSameAddress(const struct sockaddr_in *a, const struct sockaddr_in *b) {
	return a->sin_port == b->sin_port && a->sin_addr.s_addr == b->sin_addr.s_addr;
}

/// The host bench's way to lose the direct path mid-call:
/// TG_SHIM_DIRECT_DIES_MS after start, nothing more gets through it.
static BOOL TGDirectDead(double startedAt) {
#if !TARGET_OS_IPHONE
	const char *at = getenv("TG_SHIM_DIRECT_DIES_MS");
	return at && ([NSProcessInfo processInfo].systemUptime - startedAt) * 1000 > atof(at);
#else
	return NO;
#endif
}

@implementation TGCallDirectPath {
	double _startedAt;
	int _socket;
	uint16_t _port;
	NSThread *_reader;
	NSTimer *_timer;
	NSMutableArray *_peers;       // NSData of sockaddr_in; under @synchronized(self)
	NSMutableArray *_stunServers; // NSData of sockaddr_in; under @synchronized(self)
	NSArray *_stunNames;          // [host, port] as given, resolved by the reader
	struct sockaddr_in _chosen;   // under @synchronized(self)
	NSMutableArray *_sentTransactions; // NSData of 12-byte txIds; under @synchronized(self)
	BOOL _hasChosen;
	double _lastHeard, _lastCheck;
	uint64_t _tieBreaker;
	BOOL _haveSrflx;
	volatile BOOL _stopped;
}

- (instancetype)init {
	if ((self = [super init])){
		_socket = -1;
		_peers = [NSMutableArray array];
		_stunServers = [NSMutableArray array];
		_sentTransactions = [NSMutableArray array];
		arc4random_buf(&_tieBreaker, sizeof(_tieBreaker));
	}
	return self;
}

- (BOOL)active {
	@synchronized (self) {
		return _hasChosen;
	}
}

static NSData *TGAddress(NSString *ip, int port) {
	struct sockaddr_in a;
	memset(&a, 0, sizeof(a));
#ifdef __APPLE__
	a.sin_len = sizeof(a);
#endif
	a.sin_family = AF_INET;
	a.sin_port = htons((uint16_t)port);
	if (port <= 0 || port > 65535 || inet_pton(AF_INET, ip.UTF8String, &a.sin_addr) != 1)
		return nil;
	return [NSData dataWithBytes:&a length:sizeof(a)];
}

+ (instancetype)pathForCallState:(NSDictionary *)state ufrag:(NSString *)ufrag pwd:(NSString *)pwd
                     controlling:(BOOL)controlling
                           media:(void (^)(const uint8_t *bytes, size_t length))media
                       candidate:(void (^)(NSString *line))candidate {
	if (![state[@"allow_p2p"] boolValue])
		return nil;
	NSMutableArray *stun = [NSMutableArray array];
	for (NSDictionary *server in state[@"servers"]){
		NSDictionary *type = server[@"type"];
		if ([type[@"@type"] isEqualToString:@"callServerTypeWebrtc"] && [type[@"supports_stun"] boolValue] &&
		    [server[@"ip_address"] length])
			[stun addObject:@[server[@"ip_address"], server[@"port"] ?: @0]];
	}
	TGCallDirectPath *path = [[TGCallDirectPath alloc] init];
	path.localUfrag = ufrag;
	path.localPwd = pwd;
	path.controlling = controlling;
	path.onMedia = media;
	path.onCandidate = candidate;
	path.onPathChanged = ^(BOOL direct){
		NSLog(@"TGCallDirectPath: media %@", direct ? @"direct, peer to peer" : @"back on the reflector");
	};
	return [path startWithStunServers:stun] ? path : nil;
}

- (BOOL)startWithStunServers:(NSArray *)stunServers {
	_socket = socket(AF_INET, SOCK_DGRAM, 0);
	if (_socket < 0)
		return NO;
	struct sockaddr_in local;
	memset(&local, 0, sizeof(local));
	local.sin_family = AF_INET;
	local.sin_addr.s_addr = htonl(INADDR_ANY);
	if (bind(_socket, (struct sockaddr *)&local, sizeof(local)) != 0){
		close(_socket);
		_socket = -1;
		return NO;
	}
	socklen_t size = sizeof(local);
	getsockname(_socket, (struct sockaddr *)&local, &size);
	_port = ntohs(local.sin_port);
	_startedAt = [NSProcessInfo processInfo].systemUptime;
	// The same receive timeout as the reflector's socket, for the same
	// reason: it is how the reader notices -stop.
	struct timeval timeout = { 0, 100000 };
	setsockopt(_socket, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
	int bufferSize = 512 * 1024;
	setsockopt(_socket, SOL_SOCKET, SO_RCVBUF, &bufferSize, sizeof(bufferSize));

	_stunNames = [stunServers copy];

	_reader = [[NSThread alloc] initWithTarget:self selector:@selector(readLoop) object:nil];
	_reader.name = @"tg.call.direct";
	_reader.threadPriority = 0.9;
	[_reader start];
	_timer = [NSTimer scheduledTimerWithTimeInterval:kCheckInterval target:self
	                                        selector:@selector(tick) userInfo:nil repeats:YES];
	NSLog(@"TGCallDirectPath: socket on port %u, %lu STUN servers", _port, (unsigned long)stunServers.count);
	return YES;
}

- (NSString *)candidateWithIp:(NSString *)ip port:(uint16_t)port type:(NSString *)type
                     priority:(uint32_t)priority foundation:(uint32_t)foundation {
	return [NSString stringWithFormat:
			@"candidate:%u 1 udp %u %@ %u typ %@ generation 0 ufrag %@ network-id 1 network-cost 10",
			foundation, priority, ip, port, type, self.localUfrag ?: @""];
}

- (NSArray *)hostCandidates {
	NSMutableArray *lines = [NSMutableArray array];
	struct ifaddrs *list = NULL;
	if (_socket < 0 || getifaddrs(&list) != 0)
		return lines;
	uint32_t foundation = 1;
	for (struct ifaddrs *i = list; i; i = i->ifa_next){
		if (!i->ifa_addr || i->ifa_addr->sa_family != AF_INET)
			continue;
		if (!(i->ifa_flags & IFF_UP) || (i->ifa_flags & IFF_LOOPBACK))
			continue;
		char text[INET_ADDRSTRLEN] = {0};
		inet_ntop(AF_INET, &((struct sockaddr_in *)i->ifa_addr)->sin_addr, text, sizeof(text));
		[lines addObject:[self candidateWithIp:@(text) port:_port type:@"host"
		                              priority:kHostPriority - foundation foundation:foundation]];
		foundation++;
	}
	freeifaddrs(list);
	return lines;
}

- (void)addPeerCandidate:(NSString *)line {
	NSArray *parts = [line componentsSeparatedByString:@" "];
	if (parts.count < 8 || [line rangeOfString:@"typ relay"].location != NSNotFound)
		return;
	NSData *address = TGAddress(parts[4], [parts[5] intValue]);   // IPv6 and names fail here
	if (!address)
		return;
	@synchronized (self) {
		for (NSData *known in _peers)
			if ([known isEqualToData:address])
				return;
		[_peers addObject:address];
	}
	NSLog(@"TGCallDirectPath: will check %@:%@ (%@)", parts[4], parts[5], parts[7]);
}

#pragma mark - Checks

- (void)askStunServers {
	if (_haveSrflx)
		return;
	uint8_t request[20] = { 0x00, 0x01, 0x00, 0x00, 0x21, 0x12, 0xA4, 0x42 };
	arc4random_buf(request + 8, 12);
	NSArray *servers;
	@synchronized (self) {
		servers = [_stunServers copy];
	}
	for (NSData *server in servers)
		sendto(_socket, request, sizeof(request), 0, (const struct sockaddr *)server.bytes, (socklen_t)server.length);
}

- (void)tick {
	if (_stopped)
		return;
	double now = [NSProcessInfo processInfo].systemUptime;
	BOOL lost = NO;
	NSArray *targets;
	@synchronized (self) {
		if (_hasChosen && now - _lastHeard > kSilence){
			_hasChosen = NO;
			lost = YES;
		}
		if (_hasChosen){
			if (now - _lastCheck < kKeepInterval)
				return;
			targets = @[[NSData dataWithBytes:&_chosen length:sizeof(_chosen)]];
		} else {
			targets = [_peers copy];
		}
		_lastCheck = now;
	}
	if (lost){
		NSLog(@"TGCallDirectPath: nothing for %.0f s, back to the reflector", kSilence);
		if (self.onPathChanged)
			self.onPathChanged(NO);
	}
	if (!_haveSrflx && fmod(now, 1.0) < kCheckInterval)
		[self askStunServers];
	NSString *peerPwd = self.peerPwd;
	if (!peerPwd.length || !targets.count)
		return;
	NSString *username = [NSString stringWithFormat:@"%@:%@", self.peerUfrag ?: @"", self.localUfrag ?: @""];
	NSData *check = [TGCallStun bindingRequestWithUsername:username password:peerPwd
	                                            tieBreaker:_tieBreaker useCandidate:self.controlling
	                                           controlling:self.controlling];
	NSData *txId = [TGCallStun transactionIdOf:check];
	if (txId) {
		@synchronized (self) {
			[_sentTransactions addObject:txId];
			if (_sentTransactions.count > 64)
				[_sentTransactions removeObjectAtIndex:0];
		}
	}
	for (NSData *target in targets)
		sendto(_socket, check.bytes, check.length, 0, (const struct sockaddr *)target.bytes, (socklen_t)target.length);
}

/// Our address as the STUN server saw it (XOR-MAPPED-ADDRESS, IPv4).
static BOOL TGMappedAddress(const uint8_t *p, size_t length, char *ip, uint16_t *port) {
	size_t at = 20;
	while (at + 4 <= length){
		uint16_t type = (uint16_t)((p[at] << 8) | p[at + 1]);
		uint16_t size = (uint16_t)((p[at + 2] << 8) | p[at + 3]);
		if (at + 4 + size > length)
			return NO;
		if (type == 0x0020 && size >= 8 && p[at + 5] == 0x01){
			*port = (uint16_t)(((p[at + 6] << 8) | p[at + 7]) ^ 0x2112);
			struct in_addr address;
			uint32_t raw;
			memcpy(&raw, p + at + 8, 4);
			address.s_addr = raw ^ htonl(0x2112A442);
			inet_ntop(AF_INET, &address, ip, INET_ADDRSTRLEN);
			return YES;
		}
		at += 4 + ((size + 3) & ~3u);
	}
	return NO;
}

- (void)choose:(const struct sockaddr_in *)from why:(NSString *)why {
	BOOL changed;
	@synchronized (self) {
		double now = [NSProcessInfo processInfo].systemUptime;
		// A path that is alive stays: a peer with two candidates answers on
		// both, and switching on every answer had the call hop between them.
		// Its own answer counts as a sign of life, or a peer that has not
		// put media on the pair yet looked dead after 3 s.
		if (_hasChosen && !TGSameAddress(&_chosen, from) && now - _lastHeard < 1.0)
			return;
		changed = !_hasChosen || !TGSameAddress(&_chosen, from);
		_chosen = *from;
		_hasChosen = YES;
		_lastHeard = [NSProcessInfo processInfo].systemUptime;
	}
	if (!changed)
		return;
	char text[INET_ADDRSTRLEN] = {0};
	inet_ntop(AF_INET, &from->sin_addr, text, sizeof(text));
	NSLog(@"TGCallDirectPath: direct to %s:%u (%@)", text, ntohs(from->sin_port), why);
	dispatch_async(dispatch_get_main_queue(), ^{
		if (self.onPathChanged)
			self.onPathChanged(YES);
	});
}

/// The servers come as names (s278706.turn.t.me), not addresses: resolved
/// here, on the reader thread, so the lookup never holds up the main one.
- (void)resolveStunServers {
	for (NSArray *server in _stunNames){
		if (server.count != 2)
			continue;
		NSData *address = TGAddress(server[0], [server[1] intValue]);
		if (!address){
			struct addrinfo hints, *found = NULL;
			memset(&hints, 0, sizeof(hints));
			hints.ai_family = AF_INET;
			hints.ai_socktype = SOCK_DGRAM;
			if (getaddrinfo([server[0] UTF8String], NULL, &hints, &found) == 0 && found){
				struct sockaddr_in a = *(struct sockaddr_in *)found->ai_addr;
				a.sin_port = htons((uint16_t)[server[1] intValue]);
				address = [NSData dataWithBytes:&a length:sizeof(a)];
			}
			if (found)
				freeaddrinfo(found);
		}
		if (address){
			@synchronized (self) {
				[_stunServers addObject:address];
			}
		} else {
			NSLog(@"TGCallDirectPath: cannot resolve %@", server[0]);
		}
	}
	[self askStunServers];
}

- (BOOL)isStunServer:(const struct sockaddr_in *)from {
	NSArray *servers;
	@synchronized (self) {
		servers = [_stunServers copy];
	}
	for (NSData *server in servers)
		if (TGSameAddress(server.bytes, from))
			return YES;
	return NO;
}

- (void)readLoop {
	[self resolveStunServers];
	uint8_t buffer[2048];
	while (!_stopped){
		struct sockaddr_in from;
		socklen_t fromLength = sizeof(from);
		ssize_t got = recvfrom(_socket, buffer, sizeof(buffer), 0, (struct sockaddr *)&from, &fromLength);
		if (got < 0){
			if (errno == EBADF || errno == ENOTSOCK)
				break;
			if (errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR)
				usleep(100000);   // the network is changing; wait it out
			continue;
		}
		if (got < 1 || fromLength < sizeof(from) || TGDirectDead(_startedAt))
			continue;
		BOOL stun = got >= 20 && (buffer[0] & 0xC0) == 0 && buffer[4] == 0x21 && buffer[5] == 0x12 &&
		            buffer[6] == 0xA4 && buffer[7] == 0x42;
		if (!stun){
			BOOL fromChosen;
			@synchronized (self) {
				fromChosen = _hasChosen && TGSameAddress(&_chosen, &from);
				if (fromChosen)
					_lastHeard = [NSProcessInfo processInfo].systemUptime;
			}
			if (!fromChosen){
				// The peer put its media on a pair before we chose one: that
				// is its choice of path, as long as the address is one it
				// gave us or has checked from.
				BOOL known = NO;
				@synchronized (self) {
					for (NSData *peer in _peers)
						known = known || TGSameAddress(peer.bytes, &from);
				}
				if (!known)
					continue;
				[self choose:&from why:@"media"];
			}
			if (self.onMedia)
				self.onMedia(buffer, (size_t)got);
			continue;
		}
		NSData *packet = [NSData dataWithBytes:buffer length:(NSUInteger)got];
		int type = [TGCallStun messageTypeOf:packet];
		if (type == 0x0101 && [self isStunServer:&from]){
			char ip[INET_ADDRSTRLEN] = {0};
			uint16_t port = 0;
			if (!_haveSrflx && TGMappedAddress(buffer, (size_t)got, ip, &port)){
				_haveSrflx = YES;
				NSString *line = [self candidateWithIp:@(ip) port:port type:@"srflx"
				                              priority:kSrflxPriority foundation:100];
				NSLog(@"TGCallDirectPath: we are %s:%u outside", ip, port);
				dispatch_async(dispatch_get_main_queue(), ^{
					if (self.onCandidate)
						self.onCandidate(line);
				});
			}
			continue;
		}
		NSData *address = [NSData dataWithBytes:&from length:sizeof(from)];
		if (type == 0x0001){
			NSString *localPwd = self.localPwd;
			NSString *expectedUser = (self.localUfrag.length && self.peerUfrag.length)
					? [NSString stringWithFormat:@"%@:%@", self.localUfrag, self.peerUfrag]
					: nil;
			if (![TGCallStun verifyPacket:packet password:localPwd expectedUsername:expectedUser])
				continue;
			// Their check: answer it, and remember where it came from (a
			// peer-reflexive address when it is not one they listed).
			NSData *response = [TGCallStun bindingResponseTo:packet password:localPwd
			                                             fromAddress:address];
			if (response)
				sendto(_socket, response.bytes, response.length, 0, (const struct sockaddr *)&from, sizeof(from));
			@synchronized (self) {
				BOOL known = NO;
				for (NSData *peer in _peers)
					known = known || [peer isEqualToData:address];
				if (!known)
					[_peers addObject:address];
				if (_hasChosen && TGSameAddress(&_chosen, &from))
					_lastHeard = [NSProcessInfo processInfo].systemUptime;
			}
			if (!self.controlling && [TGCallStun hasUseCandidate:packet])
				[self choose:&from why:@"nominated by the peer"];
		} else if (type == 0x0101){
			if (![TGCallStun verifyPacket:packet password:self.peerPwd expectedUsername:nil])
				continue;
			NSData *txId = [TGCallStun transactionIdOf:packet];
			BOOL knownTx = NO;
			if (txId) {
				@synchronized (self) {
					knownTx = [_sentTransactions containsObject:txId];
				}
			}
			if (!knownTx)
				continue;
			[self choose:&from why:@"check answered"];
		}
	}
}

- (BOOL)send:(const uint8_t *)bytes length:(size_t)length {
	struct sockaddr_in to;
	@synchronized (self) {
		if (!_hasChosen)
			return NO;
		if (TGDirectDead(_startedAt))
			return YES;   // swallowed, as a dead network would
		to = _chosen;
	}
	return sendto(_socket, bytes, length, 0, (const struct sockaddr *)&to, sizeof(to)) == (ssize_t)length;
}

- (void)stop {
	_stopped = YES;
	[_timer invalidate];
	_timer = nil;
	int handle = _socket;
	_socket = -1;
	if (handle >= 0){
		shutdown(handle, SHUT_RDWR);
		close(handle);
	}
}

- (void)dealloc {
	[self stop];
}

@end
