#import "TGLiveStoryViewController.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGStoryStore.h"

@interface TGLiveStoryViewController ()
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, assign) int32_t groupCallId;
@property (nonatomic, assign) int32_t storyId;
@property (nonatomic, copy) NSString *rtmpUrl;
@property (nonatomic, copy) NSString *streamKey;
@end

@implementation TGLiveStoryViewController

- (instancetype)initWithChatId:(int64_t)chatId groupCallId:(int32_t)groupCallId {
	self = [super init];
	if (self){
		_chatId = chatId;
		_groupCallId = groupCallId;
		self.title = @"Live Stream";
		self.emptyText = @"No Results";
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.listFooter = nil;
	[self rebuildRows];
}

- (void)rebuildRows {
	NSMutableArray *rows = [NSMutableArray array];
	__weak typeof(self) weakSelf = self;

	[rows addObject:@{@"title" : @"Status",
					  @"detail" : self.groupCallId
							  ? [NSString stringWithFormat:@"LIVE · story %d · call %d",
									  self.storyId, self.groupCallId]
							  : @"Not started"}];
	[rows addObject:@{@"title" : @"Start Live Story As",
					  @"detail" : @"Telegram creates the live story",
					  @"tap" : ^{ [weakSelf startLiveStory]; }}];
	if (self.groupCallId){
		[rows addObject:@{@"title" : @"Join",
						  @"detail" : @"Returns the tgcalls join payload",
						  @"tap" : ^{ [weakSelf joinLiveStory]; }}];
		[rows addObject:@{@"title" : @"Streamer",
						  @"detail" : @"Who is broadcasting",
						  @"tap" : ^{ [weakSelf loadStreamer]; }}];
		[rows addObject:@{@"title" : @"Load Message Senders",
						  @"detail" : @"Who messages may be sent as",
						  @"tap" : ^{ [weakSelf loadMessageSenders]; }}];
		[rows addObject:@{@"title" : @"Top Members",
						  @"detail" : @"Stars spent on the live story",
						  @"tap" : ^{ [weakSelf loadTopDonors]; }}];
		[rows addObject:@{@"title" : @"Add 1★ Pending Reaction",
						  @"detail" : @"Then commit or cancel it",
						  @"tap" : ^{ [weakSelf addPendingReaction]; }}];
		[rows addObject:@{@"title" : @"Commit Pending Reactions",
						  @"detail" : @"Send everything pending",
						  @"tap" : ^{ [weakSelf commitPendingReactions]; }}];
		[rows addObject:@{@"title" : @"Cancel Pending Reactions",
						  @"detail" : @"Drop the pending stars",
						  @"tap" : ^{ [weakSelf removePendingReactions]; }}];
	}
	[rows addObject:@{@"title" : @"Get RTMP URL",
					  @"detail" : self.rtmpUrl.length ? self.rtmpUrl
							  : @"Asks Telegram for the stream address",
					  @"tap" : ^{ [weakSelf loadRtmpUrl]; }}];
	[rows addObject:@{@"title" : @"Replace RTMP URL",
					  @"detail" : @"Invalidates the current stream key",
					  @"tap" : ^{ [weakSelf replaceRtmpUrl]; }}];
	self.listRows = rows;
	[self.tableView reloadData];
}

- (void)appendTitle:(NSString *)title detail:(NSString *)detail {
	NSMutableArray *rows = [self.listRows mutableCopy];
	NSMutableDictionary *row = [@{@"title" : title ?: @"",
								   @"detail" : detail ?: @""} mutableCopy];
	[rows addObject:row];
	self.listRows = rows;
	[self.tableView reloadData];
}

#pragma mark - start and join

- (void)startLiveStory {
	NSArray *choices = @[@"RTMP stream", @"Group call"];
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:choices title:@"Start Live Story As"
				destructiveIndex:-1 inView:self.view onChoice:^(NSInteger choice){
		TGLiveStoryViewController *me = weakSelf;
		if (!me)
			return;
		BOOL rtmp = choice == 0;
		[[TGStoryStore shared]startLiveStoryInChat:me.chatId
										privacy:@"everyone"
										userIds:@[]
								 protectContent:NO
										 rtmp:rtmp
							   enableMessages:YES
								paidMessageStars:0
									completion:^(NSDictionary *answer){
			if (![answer[@"ok"] boolValue]){
				[TGAlertSheet showMessage:answer[@"error"] ?: @"An error occurred."
									title:@"Live Stream" inView:me.view];
				[me appendTitle:@"An error occurred"
						 detail:answer[@"error"] ?: @"An error occurred."];
				return;
			}
			NSDictionary *story = answer[@"story"] ?: @{};
			me.groupCallId = [answer[@"groupCallId"] intValue];
			me.storyId = [story[@"storyId"] intValue];
			[me appendTitle:@"Started"
					 detail:[NSString stringWithFormat:@"Story %d, group call %d",
							 me.storyId, me.groupCallId]];
			[me rebuildRows];
			if (rtmp)
				[me loadRtmpUrl];
		}];
	}];
}

- (void)joinLiveStory {
	__weak typeof(self) weakSelf = self;
	[[TGStoryStore shared]joinLiveStoryCall:self.groupCallId
							  completion:^(NSString *payload, NSString *error){
		TGLiveStoryViewController *me = weakSelf;
		if (!me)
			return;
		if (!payload.length){
			[TGAlertSheet showMessage:error ?: @"An error occurred."
								title:@"Join" inView:me.view];
			[me appendTitle:@"An error occurred" detail:error ?: @"An error occurred."];
			return;
		}
		[me appendTitle:@"Join Payload"
				 detail:payload.length > 500
						 ? [payload substringToIndex:500] : payload];
		[UIPasteboard generalPasteboard].string = payload;
	}];
}

#pragma mark - server data

- (void)loadStreamer {
	__weak typeof(self) weakSelf = self;
	[[TGStoryStore shared]liveStoryStreamerForCall:self.groupCallId
									completion:^(NSDictionary *streamer, NSString *error){
		TGLiveStoryViewController *me = weakSelf;
		if (!me)
			return;
		if (!streamer){
			[TGAlertSheet showMessage:error ?: @"An error occurred."
								title:@"Streamer" inView:me.view];
			return;
		}
		[me appendTitle:streamer[@"name"] ?: @"Streamer"
				 detail:[NSString stringWithFormat:@"%@%@%@",
						 [streamer[@"isSpeaking"] boolValue] ? @"speaking · " : @"",
						 [streamer[@"isMuted"] boolValue] ? @"muted · " : @"",
						 streamer[@"bio"] ?: @""]];
	}];
}

- (void)loadRtmpUrl {
	__weak typeof(self) weakSelf = self;
	[[TGStoryStore shared]liveStoryRtmpUrlForChat:self.chatId
									completion:^(NSDictionary *url, NSString *error){
		TGLiveStoryViewController *me = weakSelf;
		if (!me)
			return;
		if (!url){
			[TGAlertSheet showMessage:error ?: @"An error occurred."
								title:@"RTMP URL" inView:me.view];
			return;
		}
		me.rtmpUrl = url[@"url"] ?: @"";
		me.streamKey = url[@"streamKey"] ?: @"";
		[me appendTitle:@"RTMP URL" detail:me.rtmpUrl];
		[me appendTitle:@"Stream Key" detail:me.streamKey];
		[me rebuildRows];
		[UIPasteboard generalPasteboard].string =
				[NSString stringWithFormat:@"%@/%@", me.rtmpUrl, me.streamKey];
	}];
}

- (void)replaceRtmpUrl {
	__weak typeof(self) weakSelf = self;
	void (^confirm)(void) = ^{
		TGLiveStoryViewController *me = weakSelf;
		if (!me)
			return;
		[[TGStoryStore shared]replaceLiveStoryRtmpUrlForChat:me.chatId
											   completion:^(NSDictionary *url, NSString *error){
			if (!url){
				[TGAlertSheet showMessage:error ?: @"An error occurred."
									title:@"RTMP URL" inView:me.view];
				return;
			}
			me.rtmpUrl = url[@"url"] ?: @"";
			me.streamKey = url[@"streamKey"] ?: @"";
			[me appendTitle:@"New RTMP URL" detail:me.rtmpUrl];
			[me rebuildRows];
		}];
	};
	[TGAlertSheet showConfirm:@"Do you want to revoke the stream key?"
						title:@"Replace RTMP URL"
					   action:@"Replace"
				  destructive:YES
					   inView:self.view
					onConfirm:confirm];
}

- (void)loadMessageSenders {
	__weak typeof(self) weakSelf = self;
	[[TGStoryStore shared]liveStoryAvailableMessageSendersForCall:self.groupCallId
												   completion:^(NSArray *senders, NSString *error){
		TGLiveStoryViewController *me = weakSelf;
		if (!me)
			return;
		if (!senders.count){
			[TGAlertSheet showMessage:error ?: @"An error occurred."
								title:@"Send Message As..." inView:me.view];
			return;
		}
		NSMutableArray *titles = [NSMutableArray array];
		for (NSDictionary *sender in senders)
			[titles addObject:[NSString stringWithFormat:@"%@%@",
					sender[@"name"] ?: @"Sender",
					[sender[@"needsPremium"] boolValue] ? @" · Premium" : @""]];
		[TGAlertSheet showChoices:titles title:@"Send Message As..."
					destructiveIndex:-1 inView:me.view onChoice:^(NSInteger choice){
			if (choice < 0 || choice >= (NSInteger)senders.count)
				return;
			NSDictionary *sender = senders[choice];
			[[TGStoryStore shared]setLiveStoryMessageSender:sender
												 forCall:me.groupCallId
											  completion:^(BOOL ok, NSString *why){
				[TGAlertSheet showMessage:ok
						? @"Saved"
						: (why ?: @"An error occurred.")
									title:@"Send Message As..." inView:me.view];
			}];
		}];
	}];
}

- (void)loadTopDonors {
	__weak typeof(self) weakSelf = self;
	[[TGStoryStore shared]liveStoryTopDonorsForCall:self.groupCallId
									 completion:^(NSDictionary *donors, NSString *error){
		TGLiveStoryViewController *me = weakSelf;
		if (!me)
			return;
		if (!donors){
			[TGAlertSheet showMessage:error ?: @"An error occurred."
								title:@"Top Members" inView:me.view];
			return;
		}
		[me appendTitle:@"Top Members"
				 detail:[NSString stringWithFormat:@"%@ stars",
						 donors[@"totalStarCount"] ?: @(0)]];
		for (NSDictionary *donor in donors[@"donors"] ?: @[])
			[me appendTitle:donor[@"name"] ?: @"Member"
					 detail:[NSString stringWithFormat:@"%@ stars%@%@%@",
							 donor[@"stars"] ?: @(0),
							 [donor[@"isTop"] boolValue] ? @" · top" : @"",
							 [donor[@"isMe"] boolValue] ? @" · you" : @"",
							 [donor[@"isAnonymous"] boolValue] ? @" · anonymous" : @""]];
	}];
}

#pragma mark - pending reactions

- (void)addPendingReaction {
	__weak typeof(self) weakSelf = self;
	[[TGStoryStore shared]addPendingLiveStoryReactionInCall:self.groupCallId
												   stars:1
											  completion:^(BOOL ok, NSString *error){
		TGLiveStoryViewController *me = weakSelf;
		if (!ok){
			[TGAlertSheet showMessage:error ?: @"An error occurred."
								title:@"Live Stream Reaction" inView:me.view];
			return;
		}
		[me appendTitle:@"Pending" detail:nil];
	}];
}

- (void)commitPendingReactions {
	__weak typeof(self) weakSelf = self;
	[[TGStoryStore shared]commitPendingLiveStoryReactionsInCall:self.groupCallId
												  completion:^(BOOL ok, NSString *error){
		TGLiveStoryViewController *me = weakSelf;
		if (!ok){
			[TGAlertSheet showMessage:error ?: @"An error occurred."
								title:@"Live Stream Reaction" inView:me.view];
			return;
		}
		[me appendTitle:@"Saved" detail:nil];
	}];
}

- (void)removePendingReactions {
	__weak typeof(self) weakSelf = self;
	[[TGStoryStore shared]removePendingLiveStoryReactionsInCall:self.groupCallId
												  completion:^(BOOL ok, NSString *error){
		TGLiveStoryViewController *me = weakSelf;
		if (!ok){
			[TGAlertSheet showMessage:error ?: @"An error occurred."
								title:@"Live Stream Reaction" inView:me.view];
			return;
		}
		[me appendTitle:@"Canceled" detail:nil];
	}];
}

@end
