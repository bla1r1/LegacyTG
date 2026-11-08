//
// TGCustomEmojiStore.m - one getCustomEmojiStickers per burst of ids, the
// still thumbnail of each, decoded off the main thread at the size asked for.
//
#import "TGCustomEmojiStore.h"
#import <TargetConditionals.h>
#import "TGClient.h"
#import "TGImageLruCache.h"
#if TARGET_OS_IPHONE
#import "TGIcons.h"
#import "UIImage+WebP.h"
#endif

NSString *const TGCustomEmojiLoadedNotification = @"TGCustomEmojiLoadedNotification";

/// About 300 KB at 20 pt @2x: the pictures on one chat screen and its list.
static const NSUInteger kCachedPictures = 192;
/// getCustomEmojiStickers takes up to 200 ids.
static const NSUInteger kBatchLimit = 200;

@interface TGCustomEmojiStore ()
@property (nonatomic, strong) TGImageLruCache *pictures;     // "id:side" -> image
@property (nonatomic, strong) NSMutableDictionary *paths;    // id -> file on disk
@property (nonatomic, strong) NSMutableDictionary *wanted;   // id -> set of sides
@property (nonatomic, strong) NSMutableSet *queued;          // ids waiting for the batch
@property (nonatomic, strong) NSMutableSet *failed;          // ids TDLib gave no picture for
@property (nonatomic, strong) NSMutableDictionary *animations; // id -> @{@"fileId": @(fileId), @"format": fmt}
/// id -> still picture's path from earlier runs. getCustomEmojiStickers
/// waits seconds behind the chat load at launch; a picture already on disk
/// does not have to.
@property (nonatomic, strong) NSMutableDictionary *knownPaths;
@end

static NSString *TGCustomEmojiPathsFile(void) {
	NSString *caches = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
			NSUserDomainMask, YES) firstObject];
	return [caches stringByAppendingPathComponent:@"custom-emoji-paths.plist"];
}

@implementation TGCustomEmojiStore

+ (instancetype)shared {
	static TGCustomEmojiStore *store = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ store = [[TGCustomEmojiStore alloc] init]; });
	return store;
}

- (instancetype)init {
	if ((self = [super init]))
		[self reset];
	return self;
}

- (void)reset {
	self.pictures = [[TGImageLruCache alloc] initWithCapacity:kCachedPictures];
	self.paths = [NSMutableDictionary dictionary];
	self.wanted = [NSMutableDictionary dictionary];
	self.queued = [NSMutableSet set];
	self.failed = [NSMutableSet set];
	self.animations = [NSMutableDictionary dictionary];
	// Keyed by emoji id, which is global, but the files belong to this
	// account's TDLib directory: an account switch (reset) starts empty.
	NSDictionary *saved = self.knownPaths ? nil
			: [NSDictionary dictionaryWithContentsOfFile:TGCustomEmojiPathsFile()];
	self.knownPaths = [saved isKindOfClass:NSDictionary.class]
			? [saved mutableCopy] : [NSMutableDictionary dictionary];
}

- (void)saveKnownPaths {
	NSDictionary *copy = [self.knownPaths copy];
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
		[copy writeToFile:TGCustomEmojiPathsFile() atomically:YES];
	});
}

static NSString *TGNormalizeStickerFormat(id formatObj) {
	NSString *f = nil;
	if ([formatObj isKindOfClass:NSDictionary.class]) {
		f = formatObj[@"@type"];
	} else if ([formatObj isKindOfClass:NSString.class]) {
		f = (NSString *)formatObj;
	}
	if (![f isKindOfClass:NSString.class])
		return @"";
	if ([f isEqualToString:@"stickerFormatTgs"] || [f isEqualToString:@"tgs"])
		return @"tgs";
	if ([f isEqualToString:@"stickerFormatWebm"] || [f isEqualToString:@"webm"])
		return @"webm";
	if ([f isEqualToString:@"stickerFormatWebp"] || [f isEqualToString:@"webp"])
		return @"webp";
	return f;
}

- (NSDictionary *)animationForId:(int64_t)emojiId {
	if (emojiId == 0)
		return nil;
	NSNumber *key = @(emojiId);
	NSDictionary *info = self.animations[key];
	if (!info || ![info isKindOfClass:NSDictionary.class]) {
		if (![self.failed containsObject:key] && ![self.queued containsObject:key]) {
			[self.queued addObject:key];
			if (self.queued.count == 1)
				[self performSelector:@selector(sendBatch) withObject:nil afterDelay:0.05];
		}
		return nil;
	}
	NSString *format = info[@"format"];
	if (![format isKindOfClass:NSString.class])
		return nil;
	if (![format isEqualToString:@"tgs"] && ![format isEqualToString:@"webm"])
		return nil;
	return info;
}

static NSString *TGPictureKey(int64_t emojiId, CGFloat side) {
	return [NSString stringWithFormat:@"%lld:%.0f", emojiId, side];
}

- (UIImage *)imageForId:(int64_t)emojiId side:(CGFloat)side {
	if (emojiId == 0 || side <= 0)
		return nil;
	UIImage *picture = self.pictures[TGPictureKey(emojiId, side)];
	if (picture)
		return picture;
	NSNumber *key = @(emojiId);
	if ([self.failed containsObject:key])
		return nil;

	NSMutableSet *sides = self.wanted[key];
	BOOL asked = sides != nil;
	if (!sides)
		self.wanted[key] = sides = [NSMutableSet set];
	if ([sides containsObject:@(side)])
		return nil;
	[sides addObject:@(side)];

	// The file is already here for another size: only the decode is new.
	NSString *path = self.paths[key];
	if (!path){
		NSString *known = self.knownPaths[[key stringValue]];
		if (known.length && [[NSFileManager defaultManager] fileExistsAtPath:known])
			self.paths[key] = path = known;
	}
	if (path){
		[self decodePath:path forId:emojiId side:side];
		return nil;
	}
	if (asked)
		return nil;
	[self.queued addObject:key];
	if (self.queued.count >= 20) {
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(sendBatch) object:nil];
		[self sendBatch];
	} else if (self.queued.count == 1) {
		[self performSelector:@selector(sendBatch) withObject:nil afterDelay:0.02];
	}
	return nil;
}

- (void)sendBatch {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(sendBatch) object:nil];
	NSArray *ids = [[self.queued allObjects] subarrayWithRange:
			NSMakeRange(0, MIN(self.queued.count, kBatchLimit))];
	[self.queued minusSet:[NSSet setWithArray:ids]];
	if (self.queued.count)
		[self performSelector:@selector(sendBatch) withObject:nil afterDelay:0.02];

#if TG_DEV
	NSLog(@"custom emoji: asking for %lu", (unsigned long)ids.count);
#endif
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] customEmojiStickersForIds:ids completion:^(NSArray *stickers){
		dispatch_async(dispatch_get_main_queue(), ^{
			[weakSelf receiveStickers:stickers forIds:ids];
		});
	}];
}

- (void)receiveStickers:(NSArray *)stickers forIds:(NSArray *)ids {
	NSMutableSet *missing = [NSMutableSet setWithArray:ids];
	for (NSDictionary *sticker in stickers){
		if (![sticker isKindOfClass:NSDictionary.class])
			continue;
		int64_t emojiId = 0;
		if (sticker[@"customEmojiId"]) {
			emojiId = [sticker[@"customEmojiId"] longLongValue];
		} else if ([sticker[@"full_type"] isKindOfClass:NSDictionary.class]) {
			emojiId = [sticker[@"full_type"][@"custom_emoji_id"] longLongValue];
		}
		if (emojiId == 0)
			continue;

		NSNumber *key = @(emojiId);
		[missing removeObject:key];

		int64_t fileId = 0;
		if (sticker[@"fileId"]) {
			fileId = [sticker[@"fileId"] longLongValue];
		} else if ([sticker[@"sticker"] isKindOfClass:NSDictionary.class]) {
			fileId = [sticker[@"sticker"][@"id"] longLongValue];
		}

		NSString *fmt = TGNormalizeStickerFormat(sticker[@"format"]);
		if (fileId != 0 && fmt.length) {
			self.animations[key] = @{
				@"fileId" : @(fileId),
				@"format" : fmt
			};
		}

		NSNumber *thumb = sticker[@"thumbId"];
		if (!thumb && [sticker[@"thumbnail"] isKindOfClass:NSDictionary.class]) {
			thumb = sticker[@"thumbnail"][@"file"][@"id"];
		}

		if (![thumb isKindOfClass:NSNumber.class] || !thumb.integerValue) {
			if ([fmt isEqualToString:@"tgs"] || [fmt isEqualToString:@"webm"]) {
				[[NSNotificationCenter defaultCenter]
						postNotificationName:TGCustomEmojiLoadedNotification object:self
									userInfo:@{@"id" : key}];
			}
			continue;
		}

		__weak typeof(self) weakSelf = self;
		[[TGClient shared] downloadFile:thumb.integerValue
							   priority:TGDownloadPriorityOnScreen
							 completion:^(NSString *path){
			dispatch_async(dispatch_get_main_queue(), ^{
				[weakSelf receivePath:path forId:key.longLongValue];
			});
		}];
	}
	// An animated emoji with no still thumbnail, or an id TDLib does not
	// know: the plain emoji in the text stays, and nobody asks again.
	[self.failed unionSet:missing];
#if TG_DEV
	NSLog(@"custom emoji: %lu stickers, %lu without a still picture",
			(unsigned long)stickers.count, (unsigned long)missing.count);
#endif
}

- (void)receivePath:(NSString *)path forId:(int64_t)emojiId {
	NSNumber *key = @(emojiId);
	if (!path.length){
		[self.failed addObject:key];
		return;
	}
	self.paths[key] = path;
	if (![self.knownPaths[[key stringValue]] isEqualToString:path]){
		self.knownPaths[[key stringValue]] = path;
		[NSObject cancelPreviousPerformRequestsWithTarget:self
				selector:@selector(saveKnownPaths) object:nil];
		[self performSelector:@selector(saveKnownPaths) withObject:nil afterDelay:2.0];
	}
	for (NSNumber *side in [self.wanted[key] copy])
		[self decodePath:path forId:emojiId side:side.floatValue];
}

- (void)decodePath:(NSString *)path forId:(int64_t)emojiId side:(CGFloat)side {
#if TARGET_OS_IPHONE
	CGFloat scale = [UIScreen mainScreen].scale;
	__weak typeof(self) weakSelf = self;
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		UIImage *raw = nil;
		if ([path.pathExtension.lowercaseString isEqualToString:@"webp"]) {
			raw = [UIImage convertFromWebP:path compressedData:nil error:nil];
		} else {
			raw = [UIImage imageWithContentsOfFile:path]
					?: [UIImage convertFromWebP:path compressedData:nil error:nil];
		}
		UIImage *picture = raw ? [TGIcons decodedImage:raw fittingSize:CGSizeMake(side, side)
												   fill:NO scale:scale] : nil;
		dispatch_async(dispatch_get_main_queue(), ^{
			TGCustomEmojiStore *me = weakSelf;
			if (!me)
				return;
			[me.wanted[@(emojiId)] removeObject:@(side)];
			if (![me.wanted[@(emojiId)] count])
				[me.wanted removeObjectForKey:@(emojiId)];
			if (!picture) {
				[me.failed addObject:@(emojiId)];
				return;
			}
			me.pictures[TGPictureKey(emojiId, side)] = picture;
			[[NSNotificationCenter defaultCenter]
					postNotificationName:TGCustomEmojiLoadedNotification object:me
								userInfo:@{@"id" : @(emojiId)}];
		});
	});
#else
	CGFloat scale = 2.0f;
	__weak typeof(self) weakSelf = self;
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		UIImage *raw = [[NSImage alloc] initWithContentsOfFile:path];
		UIImage *picture = raw;
		dispatch_async(dispatch_get_main_queue(), ^{
			TGCustomEmojiStore *me = weakSelf;
			if (!me)
				return;
			[me.wanted[@(emojiId)] removeObject:@(side)];
			if (![me.wanted[@(emojiId)] count])
				[me.wanted removeObjectForKey:@(emojiId)];
			if (!picture) {
				[me.failed addObject:@(emojiId)];
				return;
			}
			me.pictures[TGPictureKey(emojiId, side)] = picture;
			[[NSNotificationCenter defaultCenter]
					postNotificationName:TGCustomEmojiLoadedNotification object:me
								userInfo:@{@"id" : @(emojiId)}];
		});
	});
#endif
}

@end
