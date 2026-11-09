//
// TGBackgroundStore.m - the background calls the wallpaper gallery needs.
//
#import "TGBackgroundStore.h"
#import "TGClient.h"
#import "TGDownloadPriority.h"
#import "TGPatternImage.h"

NSString *const TGBackgroundStoreChangedNotification =
		@"TGBackgroundStoreChanged";

static UIColor *TGBackgroundStoreColour(id value) {
	if (![value isKindOfClass:NSNumber.class])
		return nil;
	uint32_t rgb = (uint32_t)[value longLongValue];
	return [UIColor colorWithRed:((rgb >> 16) & 0xFF) / 255.0f
						   green:((rgb >> 8) & 0xFF) / 255.0f
							blue:(rgb & 0xFF) / 255.0f
						   alpha:1.0f];
}

/// The background's fill as the pattern renderer takes it. TDLib's wire
/// names stay in the "kind" so the store does not have to know them.
static NSDictionary *TGBackgroundStoreFill(NSDictionary *background) {
	NSDictionary *type = [background[@"type"] isKindOfClass:NSDictionary.class]
			? background[@"type"] : nil;
	NSDictionary *fill = [type[@"fill"] isKindOfClass:NSDictionary.class]
			? type[@"fill"] : nil;
	if (!fill)
		return nil;
	NSString *kind = fill[@"@type"];
	NSMutableArray *colours = [NSMutableArray array];
	if ([kind isEqualToString:@"backgroundFillSolid"]){
		UIColor *colour = TGBackgroundStoreColour(fill[@"color"]);
		if (colour)
			[colours addObject:colour];
	} else if ([kind isEqualToString:@"backgroundFillGradient"]){
		UIColor *top = TGBackgroundStoreColour(fill[@"top_color"]);
		UIColor *bottom = TGBackgroundStoreColour(fill[@"bottom_color"]);
		if (top) [colours addObject:top];
		if (bottom) [colours addObject:bottom];
	} else if ([kind isEqualToString:@"backgroundFillFreeformGradient"]){
		NSArray *raw = fill[@"colors"];
		if ([raw isKindOfClass:NSArray.class])
			for (id value in raw){
				UIColor *colour = TGBackgroundStoreColour(value);
				if (colour)
					[colours addObject:colour];
			}
	}
	if (!colours.count)
		return nil;
	return @{
		@"kind"   : [kind isKindOfClass:NSString.class] ? kind : @"",
		@"colors" : colours,
		@"angle"  : [fill[@"rotation_angle"] isKindOfClass:NSNumber.class]
				? fill[@"rotation_angle"] : @0,
	};
}

static NSNumber *TGBackgroundStorePatternFileId(NSDictionary *background) {
	NSDictionary *type = [background[@"type"] isKindOfClass:NSDictionary.class]
			? background[@"type"] : nil;
	NSDictionary *document = [type[@"document"] isKindOfClass:NSDictionary.class]
			? type[@"document"] : background[@"document"];
	if (![document isKindOfClass:NSDictionary.class])
		return nil;
	NSNumber *fileId = document[@"document"][@"id"];
	if (![fileId isKindOfClass:NSNumber.class] || fileId.longLongValue <= 0)
		fileId = document[@"thumbnail"][@"file"][@"id"];
	return [fileId isKindOfClass:NSNumber.class] && fileId.longLongValue > 0
			? fileId : nil;
}

@interface TGBackgroundStore ()
- (void)decodePatternAtPath:(NSString *)path fileId:(NSNumber *)fileId;
@end

@implementation TGBackgroundStore {
	BOOL _changePosted;
	NSCache *_patternData;
	NSCache *_baked;
	NSMutableSet *_requested;
	NSMutableSet *_pendingBakes;
}

+ (TGBackgroundStore *)shared {
	static TGBackgroundStore *store = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ store = [[TGBackgroundStore alloc] init]; });
	return store;
}

- (id)init {
	self = [super init];
	if (!self)
		return nil;
	_patternData = [[NSCache alloc] init];
	_baked = [[NSCache alloc] init];
	_requested = [NSMutableSet set];
	_pendingBakes = [NSMutableSet set];
	// 32-bit budget: pattern documents 1 MB, baked grid pictures 1 MB. The
	// theme store's 8 MB and the two Settings caches' 6 MB make sixteen.
	BOOL small = sizeof(void *) == 4;
	_patternData.totalCostLimit = small ? 1 * 1024 * 1024 : 16 * 1024 * 1024;
	_baked.totalCostLimit = small ? 1 * 1024 * 1024 : 16 * 1024 * 1024;
	return self;
}

- (void)installedBackgroundsForDarkTheme:(BOOL)darkTheme
							  completion:(void (^)(NSArray *,
												   NSString *))completion {
	[[TGClient shared] installedBackgroundsForDarkTheme:darkTheme
			completion:^(NSArray *backgrounds, NSString *error){
		if (completion)
			completion(backgrounds ?: @[], error);
	}];
}

- (void)setDefaultBackground:(NSDictionary *)background
				forDarkTheme:(BOOL)darkTheme
				  completion:(void (^)(NSDictionary *,
									   NSString *))completion {
	[[TGClient shared] setDefaultBackground:background forDarkTheme:darkTheme
			completion:^(NSDictionary *installed, NSString *error){
		if (completion)
			completion(installed, error);
	}];
}

- (void)removeInstalledBackground:(int64_t)backgroundId
					   completion:(void (^)(BOOL, NSString *))completion {
	[[TGClient shared] removeInstalledBackground:backgroundId
			completion:^(BOOL ok, NSString *error){
		if (completion)
			completion(ok, error);
	}];
}

- (int64_t)defaultBackgroundIdForDarkTheme:(BOOL)darkTheme {
	NSDictionary *state = [TGClient shared].defaultBackground;
	if (![state isKindOfClass:NSDictionary.class])
		return 0;
	BOOL isDark = [state[@"for_dark_theme"] boolValue];
	if (isDark != darkTheme)
		return 0;
	NSDictionary *background = state[@"background"];
	NSNumber *backgroundId = [background isKindOfClass:NSDictionary.class]
			? background[@"id"] : nil;
	return [backgroundId isKindOfClass:NSNumber.class]
			? backgroundId.longLongValue : 0;
}

- (void)loadThumbnailForBackground:(NSDictionary *)background
						completion:(void (^)(UIImage *))completion {
	NSNumber *fileId = background[@"fileId"];
	if (![fileId isKindOfClass:NSNumber.class] || fileId.longLongValue <= 0){
		if (completion)
			completion(nil);
		return;
	}
	[[TGClient shared] downloadFile:fileId.integerValue
			priority:TGDownloadPriorityOnScreen
			completion:^(NSString *path){
		UIImage *image = path.length
				? [UIImage imageWithContentsOfFile:path] : nil;
		if (completion)
			completion(image);
	}];
}

#pragma mark - pattern documents

- (UIImage *)patternThumbnailForBackground:(NSDictionary *)background
									 size:(CGSize)size
									 dark:(BOOL)dark {
	if (size.width <= 0 || size.height <= 0 ||
			![background[@"typeName"] isEqualToString:@"pattern"])
		return nil;
	NSString *key = [NSString stringWithFormat:@"%@|%.0fx%.0f|%d",
			background[@"id"] ?: @"", size.width, size.height, dark];
	UIImage *cached = [_baked objectForKey:key];
	if (cached)
		return cached;

	NSNumber *fileId = TGBackgroundStorePatternFileId(background);
	if (![fileId isKindOfClass:NSNumber.class])
		return nil;
	NSData *patternData = [_patternData objectForKey:fileId];
	if (!patternData.length){
		if (![_requested containsObject:fileId]){
			[_requested addObject:fileId];
			__weak typeof(self) weakSelf = self;
			[[TGClient shared] downloadFile:fileId.integerValue
					priority:TGDownloadPriorityOnScreen
					completion:^(NSString *path){
				TGBackgroundStore *me = weakSelf;
				if (!me)
					return;
				[me->_requested removeObject:fileId];
				if (path.length)
					[me decodePatternAtPath:path fileId:fileId];
			}];
		}
		return nil;
	}
	if ([_pendingBakes containsObject:key])
		return nil;

	[_pendingBakes addObject:key];
	NSDictionary *fill = TGBackgroundStoreFill(background);
	NSDictionary *type = background[@"type"];
	NSNumber *intensityNumber = type[@"intensity"];
	CGFloat intensity = [intensityNumber isKindOfClass:NSNumber.class]
			? fabs([intensityNumber doubleValue]) / 100.0f : 0.5f;
	BOOL inverted = [type[@"is_inverted"] boolValue] ||
			([intensityNumber isKindOfClass:NSNumber.class] &&
					[intensityNumber doubleValue] < 0);
	__weak typeof(self) weakSelf = self;
	dispatch_async(TGPatternWorkQueue(), ^{
		TGBackgroundStore *me = weakSelf;
		if (!me)
			return;
		CGImageRef mask = TGPatternCreateMask(patternData, size);
		CGImageRef composite = TGPatternCreateWallpaper(size, fill[@"colors"],
				fill[@"kind"], [fill[@"angle"] doubleValue], mask,
				intensity, inverted);
		if (mask)
			CGImageRelease(mask);
		UIImage *image = composite ? [UIImage imageWithCGImage:composite] : nil;
		if (composite)
			CGImageRelease(composite);
		dispatch_async(dispatch_get_main_queue(), ^{
			[me->_pendingBakes removeObject:key];
			if (!image)
				return;
			NSUInteger cost = (NSUInteger)(size.width * size.height * 4);
			[me->_baked setObject:image forKey:key cost:cost];
			[me postChangedSoon];
		});
	});
	return nil;
}

- (void)decodePatternAtPath:(NSString *)path fileId:(NSNumber *)fileId {
	__weak typeof(self) weakSelf = self;
	dispatch_async(TGPatternWorkQueue(), ^{
		TGBackgroundStore *me = weakSelf;
		if (!me)
			return;
		NSData *data = [NSData dataWithContentsOfFile:path];
		if (!data.length)
			return;
		NSData *unpacked = TGPatternGunzip(data);
		if (!unpacked.length)
			return;
		dispatch_async(dispatch_get_main_queue(), ^{
			[me->_patternData setObject:unpacked forKey:fileId
								   cost:unpacked.length];
			[me postChangedSoon];
		});
	});
}

/// Every finished bake used to post at once, and each post repainted the
/// page, which asked for images again; a cache eviction then restarted the
/// cycle. One post per 0.1 s is all a repaint needs.
- (void)postChangedSoon {
	if (_changePosted)
		return;
	_changePosted = YES;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
			dispatch_get_main_queue(), ^{
		self->_changePosted = NO;
		[[NSNotificationCenter defaultCenter] postNotificationName:TGBackgroundStoreChangedNotification object:self];
	});
}

@end
