#import "TGCallMessagesViewController.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"

@interface TGCallMessagesViewController ()
@property (nonatomic, strong) NSDictionary *call;
@property (nonatomic, copy) NSString *statusText;
@property (nonatomic, strong) NSArray *observers;
@end

@implementation TGCallMessagesViewController

- (instancetype)initWithChatId:(int64_t)chatId groupCallId:(int32_t)groupCallId {
	self = [super init];
	if (self){
		_chatId = chatId;
		_groupCallId = groupCallId;
		self.listTitle = @"Calls";
		self.emptyText = @"No messages here yet...";
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	[self observe];
	[self load];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)observe {
	__weak typeof(self) weakSelf = self;
	void (^changed)(NSNotification *) = ^(NSNotification *note){
		TGCallMessagesViewController *me = weakSelf;
		if (!me)
			return;
		int32_t callId = [note.userInfo[TGGroupCallIdKey] intValue];
		if (callId && callId != me.groupCallId)
			return;
		NSString *error = note.userInfo[TGGroupCallErrorKey];
		if (error.length)
			me.statusText = error;
		[me rebuildRows];
	};
	self.observers = @[
		[[NSNotificationCenter defaultCenter]
				addObserverForName:TGGroupCallMessagesChangedNotification
							object:nil queue:[NSOperationQueue mainQueue] usingBlock:changed],
		[[NSNotificationCenter defaultCenter]
				addObserverForName:TGGroupCallChangedNotification
							object:nil queue:[NSOperationQueue mainQueue] usingBlock:changed],
	];
}

- (void)load {
	if (!self.groupCallId){
		[self rebuildRows];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] groupCall:self.groupCallId completion:^(NSDictionary *call, NSString *error){
		TGCallMessagesViewController *me = weakSelf;
		if (!me)
			return;
		me.call = call;
		if (!call && error.length)
			me.statusText = error;
		[me rebuildRows];
	}];
}

- (NSString *)statusLine {
	if (self.statusText.length)
		return self.statusText;
	if (!self.call)
		return @"Loading...";
	if ([self.call[@"isLiveStory"] boolValue])
		return nil;
	return nil;
}

- (void)rebuildRows {
	NSMutableArray *rows = [NSMutableArray array];
	__weak typeof(self) weakSelf = self;
	BOOL canSend = [self.call[@"areMessagesAllowed"] boolValue] &&
			[self.call[@"canSendMessages"] boolValue];
	if (canSend){
		[rows addObject:@{@"title" : @"Send Message",
						  @"detail" : @"Message",
						  @"tap" : ^{ [weakSelf compose]; }}];
	}
	for (NSDictionary *message in [[TGClient shared] groupCallMessageSnapshot:self.groupCallId]){
		NSString *text = message[@"text"];
		NSString *sender = message[@"senderName"];
		[rows addObject:@{@"title" : sender.length ? sender : @"Participants",
						  @"detail" : text.length ? text : @"Star Reaction",
						  @"tap" : ^{ [weakSelf showActionsForMessage:message]; }}];
	}
	self.rows = rows;
	self.listFooter = [self statusLine];
	[self.tableView reloadData];
}

#pragma mark - sending

- (void)compose {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Message" message:nil
				placeholder:@"Message" text:nil action:@"Submit" inView:self.view
				 onSubmit:^(NSString *text){
		TGCallMessagesViewController *me = weakSelf;
		if (!me)
			return;
		[[TGClient shared] sendGroupCallMessage:text inCall:me.groupCallId
								 paidStarCount:0
									completion:^(BOOL ok, NSString *error){
			TGCallMessagesViewController *again = weakSelf;
			if (!again)
				return;
			if (!ok){
				again.statusText = error ?: @"An error occurred.";
				[TGAlertSheet showMessage:again.statusText title:@"Message"
									inView:again.view];
			} else {
				again.statusText = @"Done";
			}
			[again rebuildRows];
		}];
	}];
}

#pragma mark - deleting

- (void)showActionsForMessage:(NSDictionary *)message {
	NSMutableArray *titles = [NSMutableArray array];
	NSMutableArray *keys = [NSMutableArray array];
	[titles addObject:@"Copy"];
	[keys addObject:@"copy"];
	if ([message[@"canBeDeleted"] boolValue] || [self.call[@"canDeleteMessages"] boolValue]){
		[titles addObject:@"Delete Message"];
		[keys addObject:@"delete"];
		[titles addObject:@"Report Spam"];
		[keys addObject:@"deleteReport"];
		[titles addObject:@"Delete All Messages"];
		[keys addObject:@"deleteSender"];
	}
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:titles title:message[@"senderName"]
			destructiveIndex:-1 inView:self.view
					 onChoice:^(NSInteger index){
		TGCallMessagesViewController *me = weakSelf;
		if (!me || index < 0 || index >= (NSInteger)keys.count)
			return;
		NSString *key = keys[(NSUInteger)index];
		if ([key isEqualToString:@"copy"]){
			[UIPasteboard generalPasteboard].string = message[@"text"] ?: @"";
			[TGAlertSheet showMessage:@"Text copied." title:nil inView:me.view];
		} else if ([key isEqualToString:@"delete"]){
			[me deleteMessage:message report:NO];
		} else if ([key isEqualToString:@"deleteReport"]){
			[me deleteMessage:message report:YES];
		} else if ([key isEqualToString:@"deleteSender"]){
			[me deleteFromSender:message[@"sender"]];
		}
	}];
}

- (void)deleteMessage:(NSDictionary *)message report:(BOOL)report {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] deleteGroupCallMessages:@[message[@"messageId"] ?: @(0)]
										inCall:self.groupCallId reportSpam:report
									completion:^(BOOL ok, NSString *error){
		TGCallMessagesViewController *me = weakSelf;
		if (!me)
			return;
		me.statusText = ok ? @"Done" : (error ?: @"An error occurred.");
		[me rebuildRows];
	}];
}

- (void)deleteFromSender:(NSDictionary *)sender {
	if (![sender isKindOfClass:NSDictionary.class])
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] deleteGroupCallMessagesBySender:sender inCall:self.groupCallId
											reportSpam:NO
											completion:^(BOOL ok, NSString *error){
		TGCallMessagesViewController *me = weakSelf;
		if (!me)
			return;
		me.statusText = ok ? @"Done"
				: (error ?: @"An error occurred.");
		[me rebuildRows];
	}];
}

@end

// vim:ft=objc
