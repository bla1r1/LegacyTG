#import "TGClient+StoriesNotifications.h"
#import "TGClient+StoriesSupport.h"
#import "TGClientInternal.h"

@implementation TGClient (StoriesNotifications)

#pragma mark - notifications

- (void)storyNotificationExceptionsWithCompletion:(void (^)(NSArray *))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getStoryNotificationSettingsExceptions"}
	   completion:^(NSDictionary *result){
		NSArray *chatIds = result[@"chat_ids"];
		if (![chatIds isKindOfClass:NSArray.class] || !chatIds.count){
			if (completion) completion(@[]);
			return;
		}
		NSArray *wanted = [chatIds subarrayWithRange:
				NSMakeRange(0, MIN(chatIds.count, (NSUInteger)50))];
		NSMutableArray *rows = [NSMutableArray array];
		__block NSUInteger outstanding = wanted.count;
		for (NSNumber *chatId in wanted){
			[weakSelf request:@{@"@type" : @"getChat", @"chat_id" : chatId}
				   completion:^(NSDictionary *chat){
				if ([chat[@"@type"] isEqualToString:@"chat"]){
					NSDictionary *settings = chat[@"notification_settings"];
					NSMutableDictionary *row = [@{
						@"id" : chat[@"id"] ?: @(0),
						@"title" : chat[@"title"] ?: @"",
						@"muteStories" : settings[@"mute_stories"] ?: @NO,
						@"muteFor" : settings[@"mute_for"] ?: @(0),
					} mutableCopy];
					NSNumber *photoId = TGStoryChatPhotoFileId(chat);
					if (photoId)
						row[@"photoFileId"] = photoId;
					[rows addObject:row];
				}
				if (--outstanding == 0){
					[rows sortUsingComparator:^NSComparisonResult(NSDictionary *a,
																  NSDictionary *b){
						return [a[@"title"] compare:b[@"title"]];
					}];
					if (completion) completion(rows);
				}
			}];
		}
	}];
}

@end
