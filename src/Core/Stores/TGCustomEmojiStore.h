//
// TGCustomEmojiStore - still pictures of custom emoji for the screens that
// draw them: an emoji status beside a name, a custom emoji inside a message.
// Views ask this store, never TGClient.
//

/// Posted on the main thread when a picture asked for earlier is ready.
/// userInfo "id" is the custom emoji id as an NSNumber, or "ids" an NSSet of
/// them when several were ready within 0.1 s.
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
extern NSString *const TGCustomEmojiLoadedNotification;

@interface TGCustomEmojiStore : NSObject

+ (instancetype)shared;

/// The picture at `side` points, or nil while it loads. A nil starts the load
/// once; TGCustomEmojiLoadedNotification follows when it is ready. Ids asked
/// for within 50 ms go to TDLib as one getCustomEmojiStickers call.
- (id)imageForId:(int64_t)emojiId side:(CGFloat)side;

/// The sticker animation info { @"fileId": @(fileId), @"format": @"tgs"|"webm" }
/// or nil for static (webp) or unknown.
- (NSDictionary *)animationForId:(int64_t)emojiId;

/// Ingest stickers returned by TDLib (e.g. from getCustomEmojiStickers or tests).
- (void)receiveStickers:(NSArray *)stickers forIds:(NSArray *)ids;

/// Holds the decode queue while a table moves; pictures asked meanwhile
/// decode once it stands still. Main thread.
- (void)setDecodesHeld:(BOOL)held;

/// Forgets every picture and pending request, for an account switch.
- (void)reset;

/// Drops decoded in-memory emoji bitmaps to reduce RAM footprint in background.
- (void)clearMemoryCaches;

@end
