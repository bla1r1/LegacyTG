//
// TGSimilarChannelsViewController.h - List of recommended similar channels.
//
#ifndef TGSIMILARCHANNELSVIEWCONTROLLER_H
#define TGSIMILARCHANNELSVIEWCONTROLLER_H

#import <Foundation/Foundation.h>
#import "TGLocalization.h"

/// The peer name: getChat's title, then the recommendation's own title, then
/// Telegram's generic word.
static inline NSString *TGSimilarChannelTitle(NSDictionary *item,
		NSDictionary *chat) {
	NSString *title = chat[@"title"] ?: item[@"title"];
	return title.length ? title : @"Channel";
}

/// The subscriber line under the name; a peer whose count is unknown keeps
/// the generic word instead of claiming zero.
static inline NSString *TGSimilarChannelDetail(NSDictionary *item,
		NSDictionary *chat) {
	NSInteger members = [item[@"members"] integerValue];
	if (members <= 0 && chat[@"member_count"])
		members = [chat[@"member_count"] integerValue];
	if (members > 0)
		return [NSString stringWithFormat:TGLocalized(@"%@ subscribers"),
				@(members)];
	return @"Channel";
}

/// The name on every recommended peer, in the order the list was handed over.
static inline NSArray *TGSimilarChannelRowTitles(NSArray *items,
		NSDictionary *details) {
	NSMutableArray *titles = [NSMutableArray array];
	for (id raw in items){
		NSDictionary *item = [raw isKindOfClass:[NSDictionary class]]
				? raw : nil;
		NSNumber *key = item ? @([item[@"id"] longLongValue]) : raw;
		NSDictionary *chat = details[key];
		[titles addObject:TGSimilarChannelTitle(item, chat)];
	}
	return titles;
}

#ifndef TGROW_MODELS_ONLY
#import <UIKit/UIKit.h>
#import "TGRowsViewController.h"

@interface TGSimilarChannelsViewController : TGRowsViewController

@property (nonatomic, assign) int64_t originalChatId;
@property (nonatomic, strong) NSArray *channelChatIds;

@end
#endif

#endif // TGSIMILARCHANNELSVIEWCONTROLLER_H
