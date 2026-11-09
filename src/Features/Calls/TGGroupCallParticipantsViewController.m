#import "TGGroupCallParticipantsViewController.h"
#import "TGClient.h"
#import "TGLocalization.h"
#import "TGAlertSheet.h"
#import "TGRows.h"
#import "TGTheme.h"
#import "TGGroupCallParticipantCell.h"

@interface TGGroupCallParticipantsViewController ()
@property (nonatomic, strong) NSArray *participants;
@property (nonatomic, strong) NSArray *listedSenders;
@property (nonatomic, strong) NSDictionary *call;
@property (nonatomic, copy) NSString *footerText;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, strong) NSArray *observers;
- (void)refresh;
- (void)rebuildSections;
- (void)showActionsForParticipant:(NSDictionary *)participant;
@end

@implementation TGGroupCallParticipantsViewController

- (instancetype)initWithChatId:(int64_t)chatId groupCallId:(int32_t)groupCallId {
	self = [super init];
	if (self){
		_chatId = chatId;
		_groupCallId = groupCallId;
		self.title = TGLocalized(@"Participants");
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	[self observe];
	[self load];
}

- (void)dealloc {
	for (id observer in self.observers)
		[[NSNotificationCenter defaultCenter] removeObserver:observer];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)observe {
	__weak typeof(self) weakSelf = self;
	void (^changed)(NSNotification *) = ^(NSNotification *note){
		TGGroupCallParticipantsViewController *me = weakSelf;
		if (!me)
			return;
		int32_t callId = [note.userInfo[TGGroupCallIdKey] intValue];
		if (callId && callId != me.groupCallId)
			return;
		[me refresh];
	};
	self.observers = @[
		[[NSNotificationCenter defaultCenter]
				addObserverForName:TGGroupCallParticipantsChangedNotification
							object:nil queue:[NSOperationQueue mainQueue] usingBlock:changed],
		[[NSNotificationCenter defaultCenter]
				addObserverForName:TGGroupCallChangedNotification
							object:nil queue:[NSOperationQueue mainQueue] usingBlock:changed],
	];
}

- (void)load {
	if (!self.groupCallId)
		return;
	self.loading = YES;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] groupCall:self.groupCallId completion:^(NSDictionary *call, NSString *error){
		TGGroupCallParticipantsViewController *me = weakSelf;
		if (!me)
			return;
		me.loading = NO;
		me.call = call;
		if (!call){
			me.footerText = error ?: TGLocalized(@"An error occurred.");
			[me refresh];
			return;
		}
		if ([call[@"isJoined"] boolValue]){
			[[TGClient shared] loadGroupCallParticipants:me.groupCallId limit:100
					completion:^(BOOL ok, NSString *why){
				TGGroupCallParticipantsViewController *again = weakSelf;
				if (!again)
					return;
				if (!ok)
					again.footerText = why;
				[again refresh];
			}];
		} else if (![call[@"isVideoChat"] boolValue]){
			// A call that is not bound to a chat has a participants request
			// of its own: getGroupCallParticipants takes the inputGroupCall
			// and answers ids. A video chat has no such request until this
			// account joins it.
			[[TGClient shared] groupCallParticipantsWithInput:
					TGGroupCallInput(me.groupCallId, 0) limit:100
					completion:^(NSDictionary *answer, NSString *why){
				TGGroupCallParticipantsViewController *again = weakSelf;
				if (!again)
					return;
				if (!answer){
					again.footerText = why;
					[again refresh];
					return;
				}
				again.listedSenders = answer[@"senders"];
				again.footerText = nil;
				[again refresh];
			}];
		} else {
			me.footerText = nil;
			[me refresh];
		}
	}];
}

- (void)refresh {
	NSArray *rows = [[TGClient shared] groupCallParticipantSnapshot:self.groupCallId];
	if (!rows.count && self.listedSenders.count)
		rows = [self rowsFromSenders:self.listedSenders];
	self.participants = rows;
	if (!self.footerText.length){
		NSInteger count = [self.call[@"participantCount"] integerValue];
		if (count > 0)
			self.footerText = nil;
	}
	[self rebuildSections];
	[self.tableView reloadData];
}

- (NSArray *)rowsFromSenders:(NSArray *)senders {
	NSMutableArray *rows = [NSMutableArray array];
	int64_t meId = [[TGClient shared].me[@"id"] longLongValue];
	for (NSDictionary *sender in senders){
		if (![sender isKindOfClass:NSDictionary.class])
			continue;
		BOOL chat = [sender[@"@type"] isEqualToString:@"messageSenderChat"];
		int64_t userId = [sender[@"user_id"] longLongValue];
		int64_t chatId = [sender[@"chat_id"] longLongValue];
		NSString *name = chat ? [[TGClient shared] titleForChat:chatId]
							  : [[TGClient shared] nameForUserId:userId];
		NSMutableDictionary *row = [NSMutableDictionary dictionary];
		row[@"sender"] = sender;
		row[@"name"] = name ?: @"";
		row[@"userId"] = @(userId);
		row[@"chatId"] = @(chatId);
		row[@"kind"] = chat ? @"chat" : @"user";
		row[@"isCurrentUser"] = @(!chat && userId == meId);
		row[@"isSpeaking"] = @NO;
		row[@"isHandRaised"] = @NO;
		row[@"isMutedForAllUsers"] = @NO;
		row[@"isMutedForCurrentUser"] = @NO;
		row[@"hasVideo"] = @NO;
		row[@"volumeLevel"] = @(10000);
		[rows addObject:row];
	}
	return rows;
}

- (void)rebuildSections {
	NSMutableArray *rows = [NSMutableArray array];
	__weak typeof(self) weakSelf = self;
	for (NSDictionary *participant in self.participants){
		NSString *name = participant[@"name"];
		if (!name.length)
			name = [participant[@"kind"] isEqualToString:@"chat"]
					? TGLocalized(@"Channel") : TGLocalized(@"Participant");
		int64_t userId = [participant[@"userId"] longLongValue];
		int64_t chatId = [participant[@"chatId"] longLongValue];
		int64_t peerId = userId ?: chatId;
		NSMutableDictionary *row = TGPeerRow(@(peerId), name,
				TGGroupCallParticipantDetail(participant), nil);
		row[TGRowAvatarUser] = @(userId != 0);
		BOOL speaking = [participant[@"isSpeaking"] boolValue] &&
				![participant[@"isMutedForAllUsers"] boolValue];
		row[TGRowOnline] = @(speaking);
		if ([participant[@"isCurrentUser"] boolValue])
			row[TGRowTitleColour] = [TGTheme shared].accentColour;
		NSDictionary *captured = participant;
		row[TGRowTap] = ^{
			[weakSelf showActionsForParticipant:captured];
		};
		[rows addObject:row];
	}
	self.sections = @[TGSection(nil, self.footerText, rows)];
}

#pragma mark - one person's actions

- (void)showActionsForParticipant:(NSDictionary *)participant {
	NSMutableArray *titles = [NSMutableArray array];
	NSMutableArray *keys = [NSMutableArray array];
	BOOL mutedAll = [participant[@"isMutedForAllUsers"] boolValue];
	BOOL mutedMe = [participant[@"isMutedForCurrentUser"] boolValue];
	BOOL current = [participant[@"isCurrentUser"] boolValue];

	if (!current && ([participant[@"canBeMutedForAllUsers"] boolValue] ||
					 [participant[@"canBeUnmutedForAllUsers"] boolValue])){
		[titles addObject:(mutedAll ? TGLocalized(@"Unmute All")
				: TGLocalized(@"Mute All"))];
		[keys addObject:@"muteAll"];
	}
	if (!current && ([participant[@"canBeMutedForCurrentUser"] boolValue] ||
					 [participant[@"canBeUnmutedForCurrentUser"] boolValue])){
		[titles addObject:(mutedMe ? TGLocalized(@"Unmute for Me")
				: TGLocalized(@"Mute for Me"))];
		[keys addObject:@"muteMe"];
	}
	BOOL owned = [self.call[@"isOwned"] boolValue];
	if (owned && !current && [participant[@"userId"] longLongValue]){
		[titles addObject:TGLocalized(@"Ban")];
		[keys addObject:@"ban"];
	}

	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:titles title:participant[@"name"]
			destructiveIndex:-1 inView:self.view
					 onChoice:^(NSInteger index){
		TGGroupCallParticipantsViewController *me = weakSelf;
		if (!me || index < 0 || index >= (NSInteger)keys.count)
			return;
		NSString *key = keys[(NSUInteger)index];
		if ([key isEqualToString:@"muteAll"] || [key isEqualToString:@"muteMe"])
			[me toggleMuteForParticipant:participant forAll:[key isEqualToString:@"muteAll"]];
		else if ([key isEqualToString:@"ban"])
			[me banParticipant:participant];
	}];
}

- (void)toggleMuteForParticipant:(NSDictionary *)participant forAll:(BOOL)forAll {
	BOOL muted = forAll ? [participant[@"isMutedForAllUsers"] boolValue]
						: [participant[@"isMutedForCurrentUser"] boolValue];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] toggleGroupCallParticipant:participant[@"sender"]
										   inCall:self.groupCallId
										  isMuted:!muted
									   completion:^(BOOL ok, NSString *error){
		TGGroupCallParticipantsViewController *me = weakSelf;
		if (!me)
			return;
		if (!ok){
			[TGAlertSheet showMessage:error ?: TGLocalized(@"An error occurred.")
								title:TGLocalized(@"Mute") inView:me.view];
			return;
		}
		[me load];
	}];
}

- (void)banParticipant:(NSDictionary *)participant {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:nil
						title:TGLocalized(@"Ban") action:TGLocalized(@"Ban")
				  destructive:YES
					   inView:self.view onConfirm:^{
		TGGroupCallParticipantsViewController *me = weakSelf;
		if (!me)
			return;
		[[TGClient shared] banGroupCallParticipants:
				@[participant[@"userId"] ?: @(0)] inCall:me.groupCallId
				completion:^(BOOL ok, NSString *error){
			if (!ok)
				[TGAlertSheet showMessage:error ?: TGLocalized(@"An error occurred.")
									title:TGLocalized(@"Ban") inView:me.view];
			else
				[me load];
		}];
	}];
}

@end

// vim:ft=objc
