#import "TGClient+Base.h"

@interface TGClient (StoriesNotifications)

/// Chats with story notification settings that differ from the scope default:
/// "id", "title", "photoFileId", "muteStories" and "muteFor".
- (void)storyNotificationExceptionsWithCompletion:(void (^)(NSArray *chats))completion;

@end
