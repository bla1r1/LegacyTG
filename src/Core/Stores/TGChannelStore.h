//
// TGChannelStore.h - the Channels feature's store surface.
//
// A similar-channels list reads each channel's record and, when one is
// opened, tells Telegram which recommendation it followed. Both requests
// live here so the screen never reaches around the store.
//
#import <Foundation/Foundation.h>

@interface TGChannelStore : NSObject

+ (instancetype)shared;

/// The full chat object for a channel, nil when TDLib refused the id.
- (void)chatInfoForId:(int64_t)chatId
		   completion:(void (^)(NSDictionary *chat))completion;

/// Records that the recommendation `openedChatId` was opened from `chatId`.
- (void)openSimilarChat:(int64_t)openedChatId fromChat:(int64_t)chatId;

@end
