//
// TGCustomEmojiStore.m - one getCustomEmojiStickers per burst of ids, the
// still thumbnail of each, decoded off the main thread at the size asked for.
//
#import "TGCustomEmojiStore.h"
#include <pthread.h>
#import <TargetConditionals.h>
#import "TGClient.h"
#import "TGImageLruCache.h"
#import "TGBitmapFile.h"
#if TARGET_OS_IPHONE
#import "TGIcons.h"
#import "UIImage+WebP.h"
#import "TGDownloadStore.h"
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
/// Ids already sent to TDLib. A row redrawn while its answer was on the way
/// asked again: three getCustomEmojiStickers for the same ids, three
/// downloads, three decodes, and a redraw of the screen after each.
@property (nonatomic, strong) NSMutableSet *asked;
@property (nonatomic, strong) NSMutableSet *failed;          // ids TDLib gave no picture for
@property (nonatomic, strong) NSMutableSet *loadedSoFar;     // ids ready since the last notification
/// "id:side" pictures on the decode queue. TDLib's answer to the launch
/// batch asked for every wanted size again while the saved thumbnail of
/// each was still decoding: the WebP decoded and the PNG re-encoded on
/// every launch, ~1 s of the iPod touch 4's one core in a chat's first scroll.
@property (nonatomic, strong) NSMutableSet *decoding;
/// The names in the saved pictures' folder, read once off the main thread;
/// nil until then. Asking the disk for each picture not in memory (two
/// stats) was 27% of the main thread scrolling the panel's custom emoji tab.
@property (nonatomic, strong) NSMutableSet *savedNames;
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

static NSString *TGCustomEmojiDiskCacheDir(void) {
	static NSString *dir = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		NSString *caches = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
				NSUserDomainMask, YES) firstObject];
		dir = [caches stringByAppendingPathComponent:@"custom_emoji"];
		[[NSFileManager defaultManager] createDirectoryAtPath:dir
				withIntermediateDirectories:YES attributes:nil error:nil];
	});
	return dir;
}

/// A picture saved at its size as raw premultiplied BGRA. Saved as PNG, the
/// ~70 pictures of a chat's first screens took ~14 ms each to decode again
/// after every launch on the iPod touch 4, 1 s of its one core competing
/// with the first scroll; raw, a read and a CGImage around the bytes.
static NSString *TGCustomEmojiThumbnailPath(int64_t emojiId, CGFloat side) {
	return [TGCustomEmojiDiskCacheDir() stringByAppendingPathComponent:
			[NSString stringWithFormat:@"%lld_%.0f.bgra", (long long)emojiId, side]];
}

/// What earlier builds saved; decoded once more and saved raw.
static NSString *TGCustomEmojiPngThumbnailPath(int64_t emojiId, CGFloat side) {
	return [TGCustomEmojiDiskCacheDir() stringByAppendingPathComponent:
			[NSString stringWithFormat:@"%lld_%.0f.png", (long long)emojiId, side]];
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

- (void)clearMemoryCaches {
	[self.pictures removeAllObjects];
}

- (void)reset {
	self.pictures = [[TGImageLruCache alloc] initWithCapacity:kCachedPictures];
	self.paths = [NSMutableDictionary dictionary];
	self.wanted = [NSMutableDictionary dictionary];
	self.queued = [NSMutableSet set];
	self.asked = [NSMutableSet set];
	self.failed = [NSMutableSet set];
	self.loadedSoFar = [NSMutableSet set];
	self.decoding = [NSMutableSet set];
	self.animations = [NSMutableDictionary dictionary];
	// Keyed by emoji id, which is global, but the files belong to this
	// account's TDLib directory: an account switch (reset) starts empty.
	BOOL first = self.knownPaths == nil;
	NSMutableDictionary *known = self.knownPaths = [NSMutableDictionary dictionary];
	if (!first)
		return;
	// The first use is a chat's first cellForRow: parsing the plist there
	// was 92 ms of one 458 ms frame on the iPod touch 4. A picture saved at
	// its size never needs it, so the paths can arrive a moment later.
	__weak typeof(self) weakSelf = self;
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
		NSArray *names = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:TGCustomEmojiDiskCacheDir() error:NULL];
		NSMutableSet *nameSet = [NSMutableSet setWithArray:names ?: @[]];
		dispatch_async(dispatch_get_main_queue(), ^{
			TGCustomEmojiStore *me = weakSelf;
			if (me.knownPaths == known && !me.savedNames)
				me.savedNames = nameSet;
		});
		NSDictionary *saved = [NSDictionary dictionaryWithContentsOfFile:TGCustomEmojiPathsFile()];
		if (![saved isKindOfClass:NSDictionary.class])
			return;
		dispatch_async(dispatch_get_main_queue(), ^{
			TGCustomEmojiStore *me = weakSelf;
			if (me.knownPaths != known)
				return;
			for (NSString *key in saved)
				if (!known[key])
					known[key] = saved[key];
		});
	});
}

/// Whether a saved picture is on disk: from the folder's names once read,
/// from the disk until then.
- (BOOL)pictureSavedAt:(NSString *)path {
	NSSet *names = self.savedNames;
	return names ? [names containsObject:path.lastPathComponent]
			: [[NSFileManager defaultManager] fileExistsAtPath:path];
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
		if (![self.failed containsObject:key] && ![self.queued containsObject:key] &&
				![self.asked containsObject:key]) {
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

/// One picture at a time. On the global queue a screenful of emoji became
/// five threads decoding at once on the A4's one core, 1.5 s of CPU switched
/// between them while the chat's first scroll needed it.
static dispatch_queue_t TGCustomEmojiDecodeQueue(void) {
	static dispatch_queue_t queue;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		queue = dispatch_queue_create("org.legacy.itg.emoji-decode", DISPATCH_QUEUE_SERIAL);
		dispatch_set_target_queue(queue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0));
	});
	return queue;
}

static NSString *TGPictureKey(int64_t emojiId, CGFloat side) {
	return [NSString stringWithFormat:@"%lld:%.0f", emojiId, side];
}

/// The picture cache's key. Asked for every visible cell on every scroll
/// frame: building the "id:side" string there was 9-15% of the custom emoji
/// tab's scroll on the iPod touch 4. Ids are random 64-bit numbers, so the
/// mix collides no more often than the string's hash did.
static int64_t TGPictureCacheKey(int64_t emojiId, CGFloat side) {
	return (int64_t)((uint64_t)emojiId ^ ((uint64_t)lround(side) * 0x9E3779B97F4A7C15ULL));
}

- (UIImage *)imageForId:(int64_t)emojiId side:(CGFloat)side {
	if (emojiId == 0 || side <= 0)
		return nil;
	UIImage *picture = [self.pictures objectForInt64Key:TGPictureCacheKey(emojiId, side)];
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

	// A picture an earlier run saved at this size: read and decode it off
	// the main thread like any other. Read here, the PNG decoded at first
	// draw, 4% of the first scroll of a chat on the iPod touch 4.
	NSString *thumbFile = TGCustomEmojiThumbnailPath(emojiId, side);
	if (![self pictureSavedAt:thumbFile])
		thumbFile = TGCustomEmojiPngThumbnailPath(emojiId, side);
	if ([self pictureSavedAt:thumbFile]) {
		[self decodePath:thumbFile forId:emojiId side:side];
		return nil;
	}

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
	if (asked || [self.asked containsObject:key])
		return nil;
	[self.queued addObject:key];
	if (self.queued.count >= 20) {
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(sendBatch) object:nil];
		[self sendBatch];
	} else if (self.queued.count == 1) {
		[self performSelector:@selector(sendBatch) withObject:nil afterDelay:0.15];
	}
	return nil;
}

/// A screenful of pictures lands within a few hundred ms, and every open
/// screen (the chat, its title, contacts, the chat list) answered each one:
/// 7% of a chat's first scroll on the iPod touch 4. One notification per
/// 0.1 s carries them all: "id" when there is one, "ids" when there are more.
- (void)noteLoaded:(NSNumber *)emojiId {
	[self.loadedSoFar addObject:emojiId];
	if (self.loadedSoFar.count == 1)
		[self performSelector:@selector(postLoaded) withObject:nil afterDelay:0.1];
}

- (void)postLoaded {
	NSSet *ids = [self.loadedSoFar copy];
	[self.loadedSoFar removeAllObjects];
	if (!ids.count)
		return;
	[[NSNotificationCenter defaultCenter] postNotificationName:TGCustomEmojiLoadedNotification object:self
			userInfo:ids.count == 1 ? @{ @"id" : ids.anyObject } : @{ @"ids" : ids }];
}

- (void)sendBatch {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(sendBatch) object:nil];
	NSArray *ids = [[self.queued allObjects] subarrayWithRange:
			NSMakeRange(0, MIN(self.queued.count, kBatchLimit))];
	[self.queued minusSet:[NSSet setWithArray:ids]];
	[self.asked addObjectsFromArray:ids];
	if (self.queued.count)
		[self performSelector:@selector(sendBatch) withObject:nil afterDelay:0.15];

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
				[self noteLoaded:key];
			}
			continue;
		}

		__weak typeof(self) weakSelf = self;
		[[TGDownloadStore shared] downloadFile:thumb.integerValue
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

/// Sides a text layout measured (16.6, 17.0) share one picture; a side left
/// wanted after its picture landed was decoded again from the source later.
- (void)forgetWantedSidesOf:(int64_t)emojiId key:(NSString *)picKey {
	NSMutableSet *sides = self.wanted[@(emojiId)];
	for (NSNumber *s in [sides allObjects])
		if ([TGPictureKey(emojiId, s.floatValue) isEqualToString:picKey])
			[sides removeObject:s];
}

- (void)setDecodesHeld:(BOOL)held {
	static BOOL sHeld;
	if (held == sHeld)
		return;
	sHeld = held;
	if (held)
		dispatch_suspend(TGCustomEmojiDecodeQueue());
	else
		dispatch_resume(TGCustomEmojiDecodeQueue());
}

- (void)decodePath:(NSString *)path forId:(int64_t)emojiId side:(CGFloat)side {
	NSString *picKey = TGPictureKey(emojiId, side);
	if ([self.decoding containsObject:picKey])
		return;
	[self.decoding addObject:picKey];
#if TARGET_OS_IPHONE
	CGFloat scale = [UIScreen mainScreen].scale;
	__weak typeof(self) weakSelf = self;
	dispatch_async(TGCustomEmojiDecodeQueue(), ^{
		pthread_setname_np("tg.emoji-decode");
		NSString *thumbFile = TGCustomEmojiThumbnailPath(emojiId, side);
		UIImage *picture = nil;
		CGImageRef saved = [path isEqualToString:thumbFile] ? TGBitmapCreate(path) : NULL;
		if (saved) {
			picture = [UIImage imageWithCGImage:saved scale:scale orientation:UIImageOrientationUp];
			CGImageRelease(saved);
		} else {
			UIImage *raw = nil;
			if ([path.pathExtension.lowercaseString isEqualToString:@"webp"]) {
				raw = [UIImage convertFromWebP:path compressedData:nil error:nil];
			} else {
				raw = [UIImage imageWithContentsOfFile:path]
						?: [UIImage convertFromWebP:path compressedData:nil error:nil];
			}
			picture = raw ? [TGIcons decodedImage:raw fittingSize:CGSizeMake(side, side)
											 fill:NO scale:scale] : nil;
			if (picture)
				if (TGBitmapWrite(picture.CGImage, thumbFile)) {
					NSString *name = thumbFile.lastPathComponent;
					dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf.savedNames addObject:name]; });
				}
		}
		dispatch_async(dispatch_get_main_queue(), ^{
			TGCustomEmojiStore *me = weakSelf;
			if (!me)
				return;
			[me.decoding removeObject:picKey];
			[me forgetWantedSidesOf:emojiId key:picKey];
			if (![me.wanted[@(emojiId)] count])
				[me.wanted removeObjectForKey:@(emojiId)];
			if (!picture) {
				// A saved file the system cleared away: not a failed emoji,
				// the next ask goes to its source.
				if ([me.savedNames containsObject:path.lastPathComponent]) {
					[me.savedNames removeObject:path.lastPathComponent];
					return;
				}
				[me.failed addObject:@(emojiId)];
				return;
			}
			[me.pictures setObject:picture forInt64Key:TGPictureCacheKey(emojiId, side)];
			[me noteLoaded:@(emojiId)];
		});
	});
#else
	CGFloat scale = 2.0f;
	__weak typeof(self) weakSelf = self;
	dispatch_async(TGCustomEmojiDecodeQueue(), ^{
		pthread_setname_np("tg.emoji-decode");
		CGImageRef saved = TGBitmapCreate(path);
		UIImage *picture = saved ? [[NSImage alloc] initWithCGImage:saved size:NSZeroSize]
				: [[NSImage alloc] initWithContentsOfFile:path];
		if (saved)
			CGImageRelease(saved);
		dispatch_async(dispatch_get_main_queue(), ^{
			TGCustomEmojiStore *me = weakSelf;
			if (!me)
				return;
			[me.decoding removeObject:picKey];
			[me forgetWantedSidesOf:emojiId key:picKey];
			if (![me.wanted[@(emojiId)] count])
				[me.wanted removeObjectForKey:@(emojiId)];
			if (!picture) {
				// A saved file the system cleared away: not a failed emoji,
				// the next ask goes to its source.
				if ([me.savedNames containsObject:path.lastPathComponent]) {
					[me.savedNames removeObject:path.lastPathComponent];
					return;
				}
				[me.failed addObject:@(emojiId)];
				return;
			}
			[me.pictures setObject:picture forInt64Key:TGPictureCacheKey(emojiId, side)];
			[me noteLoaded:@(emojiId)];
		});
	});
#endif
}

@end
