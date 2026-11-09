//
// TGDMTopicsViewController - the topic list of a channel direct messages
// chat, opened from the channel profile.
//
#import <UIKit/UIKit.h>
#import "TGRowsViewController.h"
#import "TGLocalization.h"

@interface TGDMTopicsViewController : TGRowsViewController

@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, copy)   NSString *chatTitle;

@end

/// Each topic's title and subtitle, in the order the list draws them.
static inline NSArray *TGDMTopicsRowModels(NSArray *topics) {
	NSMutableArray *rows = [NSMutableArray arrayWithCapacity:topics.count];
	for (NSDictionary *topic in topics){
		NSString *name = topic[@"senderName"];
		NSDictionary *last = topic[@"lastMessage"];
		NSString *preview = [last isKindOfClass:NSDictionary.class]
				? last[@"text"] : nil;
		NSInteger unread = [topic[@"unread"] integerValue];
		NSString *detail = preview.length ? preview
				: TGLocalized(@"No messages here yet...");
		if (unread > 0)
			detail = [NSString stringWithFormat:@"%@ · %@",
					[NSString stringWithFormat:TGLocalized(@"%@ unread messages"),
							@(unread)], detail];
		else if ([topic[@"isMarkedUnread"] boolValue])
			detail = [NSString stringWithFormat:@"%@ · %@",
					TGLocalized(@"Unread"), detail];
		[rows addObject:@{
			@"title" : name.length ? name : TGLocalized(@"Topic"),
			@"detail" : detail,
		}];
	}
	return rows;
}

/// The empty list's footer: loading until the first request answers.
static inline NSString *TGDMTopicsFooter(BOOL loaded, NSUInteger count) {
	if (count)
		return nil;
	return loaded ? TGLocalized(@"No topics here yet")
			: TGLocalized(@"Loading...");
}
