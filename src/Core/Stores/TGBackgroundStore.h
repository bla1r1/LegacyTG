//
// TGBackgroundStore.h - what the Chat Wallpapers screen may ask for.
//
#import <UIKit/UIKit.h>

/// Posted on the main queue after a server pattern finishes decoding or a
/// baked thumbnail lands in the cache.
extern NSString *const TGBackgroundStoreChangedNotification;

@interface TGBackgroundStore : NSObject

+ (TGBackgroundStore *)shared;

/// The account's installed backgrounds for one side of the theme.
- (void)installedBackgroundsForDarkTheme:(BOOL)darkTheme
							  completion:(void (^)(NSArray *backgrounds,
												   NSString *error))completion;

/// Make an installed background the default for chats.
- (void)setDefaultBackground:(NSDictionary *)background
				forDarkTheme:(BOOL)darkTheme
				  completion:(void (^)(NSDictionary *installed,
									   NSString *error))completion;

/// Drop one background from the account's list.
- (void)removeInstalledBackground:(int64_t)backgroundId
					   completion:(void (^)(BOOL ok, NSString *error))completion;

/// The id Telegram last said is the default for this side, or 0.
- (int64_t)defaultBackgroundIdForDarkTheme:(BOOL)darkTheme;

/// Download the background's preview thumbnail and decode it once.
- (void)loadThumbnailForBackground:(NSDictionary *)background
						completion:(void (^)(UIImage *image))completion;

/// The server pattern baked over its fill at `size`. Nil until the pattern
/// document has downloaded and decoded; the caller draws the fill meanwhile
/// and listens for TGBackgroundStoreChangedNotification.
- (UIImage *)patternThumbnailForBackground:(NSDictionary *)background
									 size:(CGSize)size
									 dark:(BOOL)dark;

@end
