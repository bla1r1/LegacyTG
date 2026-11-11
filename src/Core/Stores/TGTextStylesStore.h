//
// TGTextStylesStore.h - the account's custom text composition styles.
//
// Telegram streams the used styles through updateTextCompositionStyles; the
// store keeps the list the views read and owns the requests that create, edit,
// find, preview, add and remove one. A screen never builds the TDLib object.
//
#import <Foundation/Foundation.h>
#import "TGClientNotifications.h"

@interface TGTextStylesStore : NSObject

+ (instancetype)shared;

/// The styles this account may use, kept live by updateTextCompositionStyles.
/// Each entry: "name", "title", "emojiId", "isCustom", "isCreator",
/// "installCount", "prompt", "creatorUserId".
@property (nonatomic, readonly) NSArray *textCompositionStyles;

/// Creates a style. TDLib answers the whole object, so the screen does not
/// wait for the update to draw it.
- (void)createTextCompositionStyle:(NSString *)title
						   emojiId:(int64_t)customEmojiId
							prompt:(NSString *)prompt
					   showCreator:(BOOL)showCreator
						completion:(void (^)(NSDictionary *style,
											 NSString *error))completion;

- (void)editTextCompositionStyleNamed:(NSString *)name
								title:(NSString *)title
							  emojiId:(int64_t)customEmojiId
							   prompt:(NSString *)prompt
						  showCreator:(BOOL)showCreator
						   completion:(void (^)(NSDictionary *style,
												NSString *error))completion;

- (void)deleteTextCompositionStyleNamed:(NSString *)name
							 completion:(void (^)(BOOL ok,
												  NSString *error))completion;

/// Telegram's 404 means there is no style by that name. It is returned as an
/// error sentence so the manager can show it rather than an empty row.
- (void)searchTextCompositionStyleNamed:(NSString *)name
							 completion:(void (^)(NSDictionary *style,
												  NSString *error))completion;

/// An example of the style in use. `number` is 0-based; the screen walks it
/// until Telegram answers 404.
- (void)textCompositionStyleExampleNamed:(NSString *)name
								  number:(NSInteger)number
							  completion:(void (^)(NSDictionary *example,
												   NSString *error))completion;

/// Puts the style into the used list the composer's style picker reads.
- (void)addTextCompositionStyleNamed:(NSString *)name
						  completion:(void (^)(BOOL ok,
											   NSString *error))completion;

/// Takes it out again. A style this account created is deleted, not removed.
- (void)removeTextCompositionStyleNamed:(NSString *)name
							 completion:(void (^)(BOOL ok,
												  NSString *error))completion;

@end
