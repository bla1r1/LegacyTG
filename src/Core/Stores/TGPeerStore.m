//
// TGPeerStore.m - users and chats as a screen sees them, and their faces.
//
// The record is rebuilt from TGClient's caches on every read, so it is never
// a stale copy. Pictures are the only state held here: an LRU of decoded
// squares and one wait list per file id, because a member list asks for the
// same handful of people every time it scrolls.
//
#import "TGPeerStore.h"
#import "TGClient.h"
#import "TGClient+Peers.h"
#import "TGImageLruCache.h"
#import "TGStatusText.h"
#import "TGDownloadPriority.h"
#import <math.h>
#import <TargetConditionals.h>

NSString *const TGPeerStoreChangedNotification = @"TGPeerStoreChangedNotification";

#pragma mark - initials and raw fields

/// The same rule TGIcons uses for a placeholder: the first alphanumeric
/// letter, plus the first letter of the next word. Kept here so the record
/// does not need UIKit to answer what a screen would draw.
static NSString *TGPeerInitials(NSString *title) {
	if (!title.length)
		return @"?";
	NSString *trimmed = [title stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!trimmed.length)
		return @"?";
	NSString *first = nil;
	for (NSUInteger i = 0; i < trimmed.length; ) {
		NSRange range = [trimmed rangeOfComposedCharacterSequenceAtIndex:i];
		NSString *glyph = [trimmed substringWithRange:range];
		if (range.length == 1 &&
			[[NSCharacterSet alphanumericCharacterSet]
					characterIsMember:[glyph characterAtIndex:0]]){
			first = glyph.uppercaseString;
			break;
		}
		i += range.length;
	}
	if (!first){
		NSRange range = [trimmed rangeOfComposedCharacterSequenceAtIndex:0];
		return [trimmed substringWithRange:range];
	}
	NSArray *words = [trimmed componentsSeparatedByCharactersInSet:
			[NSCharacterSet whitespaceCharacterSet]];
	for (NSUInteger w = 1; w < words.count; w++){
		NSString *word = words[w];
		for (NSUInteger j = 0; j < word.length; ){
			NSRange range = [word rangeOfComposedCharacterSequenceAtIndex:j];
			NSString *glyph = [word substringWithRange:range];
			if (range.length == 1 &&
				[[NSCharacterSet alphanumericCharacterSet]
						characterIsMember:[glyph characterAtIndex:0]])
				return [NSString stringWithFormat:@"%@%@",
						first, glyph.uppercaseString];
			j += range.length;
		}
	}
	return first;
}

static NSString *TGPeerActiveUsername(NSDictionary *user) {
	NSArray *active = user[@"usernames"][@"active_usernames"];
	if ([active isKindOfClass:NSArray.class] && active.count)
		return active[0];
	NSString *legacy = user[@"username"];
	return [legacy isKindOfClass:NSString.class] ? legacy : nil;
}

static NSString *TGPeerUserTitle(NSDictionary *user) {
	NSString *first = user[@"first_name"] ?: @"";
	NSString *last = user[@"last_name"] ?: @"";
	NSString *title = [[NSString stringWithFormat:@"%@ %@", first, last]
			stringByTrimmingCharactersInSet:
					[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (title.length)
		return title;
	return TGPeerActiveUsername(user) ?: @"";
}

static int64_t TGPeerEmojiStatus(NSDictionary *record) {
	if (![record isKindOfClass:NSDictionary.class])
		return 0;
	if (record[@"emojiStatusId"])
		return [record[@"emojiStatusId"] longLongValue];
	NSDictionary *status = record[@"emoji_status"];
	if (![status isKindOfClass:NSDictionary.class])
		return 0;
	NSDictionary *type = status[@"type"];
	if (![type isKindOfClass:NSDictionary.class])
		return 0;
	if ([type[@"@type"] isEqualToString:@"emojiStatusTypeCustomEmoji"])
		return [type[@"custom_emoji_id"] longLongValue];
	return 0;
}

static BOOL TGPeerRecordVerified(NSDictionary *record) {
	if (![record isKindOfClass:NSDictionary.class])
		return NO;
	if ([record[@"is_verified"] boolValue])
		return YES;
	return [record[@"verification_status"][@"is_verified"] boolValue];
}

static BOOL TGPeerRecordOnline(NSDictionary *record) {
	if (![record isKindOfClass:NSDictionary.class])
		return NO;
	if ([record[@"isOnline"] boolValue])
		return YES;
	return [record[@"status"][@"@type"] isEqualToString:@"userStatusOnline"];
}

#pragma mark - picture decode

/// A square crop, decoded and drawn once away from the main thread. UIImage's
/// own decode is lazy and would land on the main thread at draw time, which is
/// a dropped frame on an A4. Host tests have no UIKit drawing; they inject a
/// loader and only count downloads, so this half is device-only.
static UIImage *TGPeerAvatarImageAtPath(NSString *path, CGFloat side) {
#if TARGET_OS_IPHONE
	if (!path.length || side <= 0)
		return nil;
	UIImage *image = [UIImage imageWithContentsOfFile:path];
	if (!image)
		return nil;
	CGSize source = image.size;
	if (source.width <= 0 || source.height <= 0)
		return nil;
	CGSize square = CGSizeMake(side, side);
	CGFloat ratio = MAX(square.width / source.width, square.height / source.height);
	CGSize drawn = CGSizeMake(source.width * ratio, source.height * ratio);
	CGPoint origin = CGPointMake((square.width - drawn.width) * 0.5f,
								 (square.height - drawn.height) * 0.5f);

	UIGraphicsBeginImageContextWithOptions(square, NO, [UIScreen mainScreen].scale);
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextAddEllipseInRect(context, CGRectMake(0, 0, side, side));
	CGContextClip(context);
	[image drawInRect:CGRectMake(origin.x, origin.y, drawn.width, drawn.height)];
	UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return result;
#else
	(void)path;
	(void)side;
	return nil;
#endif
}

#pragma mark - record

static TGPeer *TGPeerFromRecords(NSDictionary *user, NSDictionary *chat,
								 NSInteger memberCountOverride);

@interface TGPeer ()
- (instancetype)initWithPeerId:(int64_t)peerId
                         isUser:(BOOL)isUser
                      isChannel:(BOOL)isChannel
                        isGroup:(BOOL)isGroup
                        isSaved:(BOOL)isSaved
                          title:(NSString *)title
                       username:(NSString *)username
                       verified:(BOOL)verified
                  emojiStatusId:(int64_t)emojiStatusId
                         online:(BOOL)online
                   lastSeenText:(NSString *)lastSeenText
                    memberCount:(NSInteger)memberCount;
@end

@implementation TGPeer

- (instancetype)initWithPeerId:(int64_t)peerId
                         isUser:(BOOL)isUser
                      isChannel:(BOOL)isChannel
                        isGroup:(BOOL)isGroup
                        isSaved:(BOOL)isSaved
                          title:(NSString *)title
                       username:(NSString *)username
                       verified:(BOOL)verified
                  emojiStatusId:(int64_t)emojiStatusId
                         online:(BOOL)online
                   lastSeenText:(NSString *)lastSeenText
                    memberCount:(NSInteger)memberCount {
	self = [super init];
	if (!self)
		return nil;
	_peerId = peerId;
	_isUser = isUser;
	_isChannel = isChannel;
	_isGroup = isGroup;
	_isSaved = isSaved;
	_title = [title copy] ?: @"";
	_initials = [TGPeerInitials(title) copy];
	_username = [username copy];
	_verified = verified;
	_emojiStatusId = emojiStatusId;
	_online = online;
	_lastSeenText = [lastSeenText copy];
	_memberCount = memberCount;
	return self;
}

+ (instancetype)peerFromUser:(NSDictionary *)user {
	return TGPeerFromRecords(user, nil, 0);
}

+ (instancetype)peerFromChat:(NSDictionary *)chat {
	return TGPeerFromRecords(nil, chat, 0);
}

@end

static TGPeer *TGPeerFromRecords(NSDictionary *user, NSDictionary *chat,
								 NSInteger memberCountOverride) {
	if (![user isKindOfClass:NSDictionary.class])
		user = nil;
	if (![chat isKindOfClass:NSDictionary.class])
		chat = nil;
	if (!user && !chat)
		return nil;

	NSString *chatType = chat[@"type"][@"@type"];
	BOOL supergroup = [chatType isEqualToString:@"chatTypeSupergroup"];
	BOOL basicGroup = [chatType isEqualToString:@"chatTypeBasicGroup"];
	BOOL isGroup = [chat[@"isGroup"] boolValue] || supergroup || basicGroup;
	BOOL isChannel = [chat[@"isChannel"] boolValue] ||
			(supergroup && [chat[@"type"][@"is_channel"] boolValue]);
	BOOL privateChat = [chatType isEqualToString:@"chatTypePrivate"] ||
			[chatType isEqualToString:@"chatTypeSecret"];
	BOOL isUser = user != nil || privateChat;
	if (isGroup)
		isUser = NO;

	NSString *title = chat[@"title"];
	if (!title.length && user)
		title = TGPeerUserTitle(user);
	if (!title.length)
		title = @"";

	NSString *username = TGPeerActiveUsername(user);
	if (!username.length && [chat[@"username"] isKindOfClass:NSString.class])
		username = chat[@"username"];

	int64_t emojiStatusId = TGPeerEmojiStatus(chat);
	if (!emojiStatusId)
		emojiStatusId = TGPeerEmojiStatus(user);

	BOOL online = TGPeerRecordOnline(chat) || TGPeerRecordOnline(user);
	NSString *lastSeen = nil;
	if (user[@"status"])
		lastSeen = TGStatusTextFromTDStatus(user[@"status"]);
	else if (online)
		lastSeen = @"online";

	NSInteger memberCount = memberCountOverride;
	if (memberCount <= 0)
		memberCount = [chat[@"memberCount"] integerValue];
	if (memberCount <= 0)
		memberCount = [chat[@"member_count"] integerValue];

	int64_t peerId = [chat[@"id"] longLongValue];
	if (!peerId)
		peerId = [user[@"id"] longLongValue];

	return [[TGPeer alloc] initWithPeerId:peerId
								   isUser:isUser
								isChannel:isChannel
								  isGroup:isGroup
								  isSaved:[chat[@"isSaved"] boolValue]
									title:title
								 username:username
								 verified:TGPeerRecordVerified(chat) ||
										  TGPeerRecordVerified(user)
							emojiStatusId:emojiStatusId
								   online:online
							 lastSeenText:lastSeen
							  memberCount:memberCount];
}

#pragma mark - avatar waiters

@interface TGPeerAvatarRequest : NSObject
@property (nonatomic, assign) int64_t peerId;
@property (nonatomic, assign) CGFloat side;
@property (nonatomic, copy) void (^completion)(UIImage *);
@end

@implementation TGPeerAvatarRequest
@end

#pragma mark - store

@interface TGPeerStore ()
- (void)notePeerChanged:(int64_t)peerId;
- (void)flushChangedPeers;
@end

static void (^TGPeerStoreAvatarLoader)(NSInteger fileId,
		void (^completion)(NSString *path)) = nil;

@implementation TGPeerStore {
	TGImageLruCache *_photos;
	NSMutableDictionary *_photoFileIds;      // peer id -> file id | NSNull
	NSMutableDictionary *_lookupWaiters;     // peer id -> request array
	NSMutableDictionary *_downloadWaiters;   // file id -> request array
	NSMutableSet *_changedPeers;
	NSMutableDictionary *_memberCounts;
	BOOL _flushScheduled;
}

+ (TGPeerStore *)shared {
	static TGPeerStore *store = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ store = [[TGPeerStore alloc] init]; });
	return store;
}

/// Test seam: let a suite answer a download without TDLib or a real file.
+ (void)setAvatarLoaderForTesting:(void (^)(NSInteger fileId,
		void (^completion)(NSString *path)))loader {
	TGPeerStoreAvatarLoader = [loader copy];
}

- (instancetype)init {
	self = [super init];
	if (!self)
		return nil;
	_photos = [[TGImageLruCache alloc] initWithCapacity:120];
	_photoFileIds = [NSMutableDictionary dictionary];
	_lookupWaiters = [NSMutableDictionary dictionary];
	_downloadWaiters = [NSMutableDictionary dictionary];
	_changedPeers = [NSMutableSet set];
	_memberCounts = [NSMutableDictionary dictionary];

	// A decoded picture is a convenience, never the only copy.
	__weak typeof(self) weakSelf = self;
	[[NSNotificationCenter defaultCenter]
			addObserverForName:@"UIApplicationDidReceiveMemoryWarningNotification"
						object:nil queue:[NSOperationQueue mainQueue]
					usingBlock:^(NSNotification *note) {
		TGPeerStore *me = weakSelf;
		[me->_photos removeAllObjects];
	}];

	// TDLib already batches raw events before they reach the main queue. These
	// observers add one coalescing step at the store, so a burst of presence
	// or chat changes still yields one TGPeerStoreChangedNotification.
	[[NSNotificationCenter defaultCenter]
			addObserverForName:TGChatsChangedNotification
						object:nil queue:[NSOperationQueue mainQueue]
					usingBlock:^(NSNotification *note) {
		TGPeerStore *me = weakSelf;
		TGClient *client = [TGClient shared];
		for (NSDictionary *chat in client.chats)
			[me notePeerChanged:[chat[@"id"] longLongValue]];
		for (NSDictionary *chat in client.archivedChats)
			[me notePeerChanged:[chat[@"id"] longLongValue]];
	}];
	[[NSNotificationCenter defaultCenter]
			addObserverForName:TGUserStatusChangedNotification
						object:nil queue:[NSOperationQueue mainQueue]
					usingBlock:^(NSNotification *note) {
		[weakSelf notePeerChanged:
				[note.userInfo[@"userId"] longLongValue]];
	}];
	[[NSNotificationCenter defaultCenter]
			addObserverForName:TGChatMembersChangedNotification
						object:nil queue:[NSOperationQueue mainQueue]
					usingBlock:^(NSNotification *note) {
		[weakSelf notePeerChanged:
				[note.userInfo[@"chatId"] longLongValue]];
	}];
	return self;
}

#pragma mark - records

- (TGPeer *)peerForId:(int64_t)peerId {
	if (!peerId)
		return nil;
	TGClient *client = [TGClient shared];
	NSDictionary *user = [client peerUserRecordForId:peerId];
	NSDictionary *chat = [client peerChatRecordForId:peerId];
	if (!user && !chat)
		return nil;
	NSInteger memberCount = [_memberCounts[@(peerId)] integerValue];
	return TGPeerFromRecords(user, chat, memberCount);
}

- (BOOL)peerHasAvatar:(int64_t)peerId {
	return [[TGClient shared] peerPhotoFileIdForId:peerId] != nil;
}

- (void)refreshPeerForId:(int64_t)peerId
              completion:(void (^)(TGPeer *))completion {
	TGPeer *peer = [self peerForId:peerId];
	if (!peer){
		if (completion) completion(nil);
		return;
	}
	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	if (peer.isGroup || peer.isChannel){
		[client peerMemberCountForChatId:peerId completion:^(NSInteger count){
			TGPeerStore *me = weakSelf;
			if (!me)
				return;
			if (count > 0)
				me->_memberCounts[@(peerId)] = @(count);
			TGPeer *fresh = [me peerForId:peerId];
			if (completion) completion(fresh);
		}];
		return;
	}
	[client peerStatusForUserId:peerId completion:^(NSString *text){
		TGPeer *fresh = [weakSelf peerForId:peerId];
		if (completion) completion(fresh);
	}];
}

#pragma mark - avatar cache

- (NSString *)cacheKeyForPeer:(int64_t)peerId side:(CGFloat)side {
	return [NSString stringWithFormat:@"%lld:%ld", (long long)peerId,
			(long)lround(side)];
}

- (UIImage *)cachedAvatarForPeer:(int64_t)peerId side:(CGFloat)side {
	if (!peerId || side <= 0)
		return nil;
	return [_photos objectForKey:[self cacheKeyForPeer:peerId side:side]];
}

- (void)loadAvatarForPeer:(int64_t)peerId
                     side:(CGFloat)side
               completion:(void (^)(UIImage *))completion {
	if (!peerId || side <= 0){
		if (completion) completion(nil);
		return;
	}
	UIImage *cached = [self cachedAvatarForPeer:peerId side:side];
	if (cached){
		if (completion) completion(cached);
		return;
	}

	TGPeerAvatarRequest *request = [[TGPeerAvatarRequest alloc] init];
	request.peerId = peerId;
	request.side = side;
	request.completion = completion;

	NSNumber *key = @(peerId);
	NSNumber *known = _photoFileIds[key];
	if (known){
		[self requestFile:known forRequest:request];
		return;
	}

	// One photo-id lookup per peer: rows that appear together wait here.
	NSMutableArray *waiters = _lookupWaiters[key];
	if (waiters){
		[waiters addObject:request];
		return;
	}
	_lookupWaiters[key] = [NSMutableArray arrayWithObject:request];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] peerPhotoFileIdForId:peerId completion:^(NSNumber *fileId){
		TGPeerStore *me = weakSelf;
		if (!me)
			return;
		NSArray *queued = [me->_lookupWaiters[key] copy];
		[me->_lookupWaiters removeObjectForKey:key];
		NSNumber *photo = ([fileId isKindOfClass:NSNumber.class] &&
				fileId.integerValue > 0) ? fileId : nil;
		if (photo)
			me->_photoFileIds[key] = photo;
		else
			[me->_photoFileIds removeObjectForKey:key];
		for (TGPeerAvatarRequest *one in queued)
			[me requestFile:photo forRequest:one];
	}];
}

- (void)requestFile:(NSNumber *)fileId forRequest:(TGPeerAvatarRequest *)request {
	if (!fileId){
		if (request.completion) request.completion(nil);
		return;
	}
	UIImage *cached = [self cachedAvatarForPeer:request.peerId side:request.side];
	if (cached){
		if (request.completion) request.completion(cached);
		return;
	}

	NSNumber *key = @(fileId.integerValue);
	NSMutableArray *waiters = _downloadWaiters[key];
	if (waiters){
		[waiters addObject:request];
		return;
	}
	waiters = [NSMutableArray arrayWithObject:request];
	_downloadWaiters[key] = waiters;

	__weak typeof(self) weakSelf = self;
	void (^done)(NSString *) = ^(NSString *path){
		TGPeerStore *me = weakSelf;
		if (!me)
			return;
		NSArray *queued = [me->_downloadWaiters[key] copy];
		[me->_downloadWaiters removeObjectForKey:key];
		if (!path.length){
			for (TGPeerAvatarRequest *one in queued)
				if (one.completion) one.completion(nil);
			return;
		}
		// One file, possibly several sizes. Each decode is off the main
		// thread; the cache write and the completion are main-queue work.
		for (TGPeerAvatarRequest *one in queued){
			CGFloat side = one.side;
			dispatch_async(dispatch_get_global_queue(
					DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
				UIImage *image = TGPeerAvatarImageAtPath(path, side);
				dispatch_async(dispatch_get_main_queue(), ^{
					TGPeerStore *last = weakSelf;
					if (!last)
						return;
					[last finishRequest:one image:image];
				});
			});
		}
	};

	if (TGPeerStoreAvatarLoader){
		TGPeerStoreAvatarLoader(fileId.integerValue, done);
		return;
	}
	[[TGClient shared] downloadFile:fileId.integerValue
						   priority:TGDownloadPriorityAvatar
						 completion:done];
}

- (void)finishRequest:(TGPeerAvatarRequest *)request image:(UIImage *)image {
	if (image)
		[_photos setObject:image forKey:
				[self cacheKeyForPeer:request.peerId side:request.side]];
	if (request.completion)
		request.completion(image);
}

- (void)reset {
	[_photos removeAllObjects];
	[_photoFileIds removeAllObjects];
	[_lookupWaiters removeAllObjects];
	[_downloadWaiters removeAllObjects];
	[_memberCounts removeAllObjects];
	[_changedPeers removeAllObjects];
}

#pragma mark - coalesced change post

- (void)notePeerChanged:(int64_t)peerId {
	if (!peerId)
		return;
	[_changedPeers addObject:@(peerId)];
	if (_flushScheduled)
		return;
	_flushScheduled = YES;
	__weak typeof(self) weakSelf = self;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
			(int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[weakSelf flushChangedPeers];
	});
}

- (void)flushChangedPeers {
	_flushScheduled = NO;
	if (!_changedPeers.count)
		return;
	NSArray *ids = [_changedPeers allObjects];
	[_changedPeers removeAllObjects];
	[[NSNotificationCenter defaultCenter]
			postNotificationName:TGPeerStoreChangedNotification
						  object:self
						userInfo:@{@"ids" : ids}];
}

@end
