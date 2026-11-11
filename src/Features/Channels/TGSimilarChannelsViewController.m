//
// TGSimilarChannelsViewController.m - List of recommended similar channels.
//
#import "TGSimilarChannelsViewController.h"
#import "TGLocalization.h"
#import "TGChannelStore.h"
#import "TGStyle.h"
#import "TGChatViewController.h"
#import "TGRows.h"

@interface TGSimilarChannelsViewController ()
@property (nonatomic, strong) NSMutableDictionary *chatDetails;
@end

@implementation TGSimilarChannelsViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Similar Channels";
	self.chatDetails = [NSMutableDictionary dictionary];
	[self loadAllChannels];
	[self rebuildSections];
}

- (int64_t)chatIdAtIndex:(NSInteger)index {
	if (index < 0 || index >= (NSInteger)self.channelChatIds.count)
		return 0;
	id item = self.channelChatIds[(NSUInteger)index];
	if ([item isKindOfClass:[NSDictionary class]])
		return [item[@"id"] longLongValue];
	return [item longLongValue];
}

- (void)loadAllChannels {
	for (NSInteger i = 0; i < (NSInteger)self.channelChatIds.count; i++) {
		int64_t chatId = [self chatIdAtIndex:i];
		if (!chatId) continue;
		__weak typeof(self) weakSelf = self;
		[[TGChannelStore shared] chatInfoForId:chatId
									completion:^(NSDictionary *chat){
			if (![chat isKindOfClass:[NSDictionary class]])
				return;
			dispatch_async(dispatch_get_main_queue(), ^{
				TGSimilarChannelsViewController *me = weakSelf;
				if (!me) return;
				me.chatDetails[@(chatId)] = chat;
				[me rebuildSections];
			});
		}];
	}
}

#pragma mark - rows

- (void)rebuildSections {
	__weak typeof(self) weakSelf = self;
	NSArray *ids = self.channelChatIds ?: @[];
	NSMutableArray *rows = [NSMutableArray array];
	for (NSUInteger i = 0; i < ids.count; i++){
		id rawItem = ids[i];
		NSDictionary *item = [rawItem isKindOfClass:[NSDictionary class]]
				? rawItem : nil;
		int64_t chatId = [self chatIdAtIndex:(NSInteger)i];
		NSDictionary *chat = self.chatDetails[@(chatId)];
		// A peer row: the channel's initials until a chat avatar store can
		// hand the picture to every list the same way.
		NSMutableDictionary *row = TGPeerRow(@(chatId),
				TGSimilarChannelTitle(item, chat),
				TGSimilarChannelDetail(item, chat),
				^{ [weakSelf openChannelAtIndex:(NSInteger)i]; });
		row[TGRowAccessory] = TGRowAccessoryDisclosure;
		[rows addObject:row];
	}
	NSString *header = ids.count ? [NSString stringWithFormat:
			TGLocalized(@"%@ channels"), @(ids.count)] : nil;
	self.sections = @[TGSection(header, nil, rows)];
	[self reloadRows];
}

#pragma mark - actions

- (void)openChannelAtIndex:(NSInteger)index {
	if (index < 0 || index >= (NSInteger)self.channelChatIds.count)
		return;
	int64_t chatId = [self chatIdAtIndex:index];
	[[TGChannelStore shared] openSimilarChat:chatId fromChat:self.originalChatId];

	id rawItem = self.channelChatIds[(NSUInteger)index];
	NSDictionary *itemDict = [rawItem isKindOfClass:[NSDictionary class]]
			? rawItem : nil;
	NSDictionary *chat = self.chatDetails[@(chatId)];
	NSString *title = TGSimilarChannelTitle(itemDict, chat);
	TGChatViewController *chatVC = [[TGChatViewController alloc] init];
	chatVC.chatId = chatId;
	chatVC.chatTitle = title;
	chatVC.isGroup = YES;
	chatVC.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:chatVC animated:YES];
}

@end
