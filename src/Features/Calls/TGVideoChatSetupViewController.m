#import "TGVideoChatSetupViewController.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGVideoChatStreamViewController.h"
#import "TGGroupCallViewController.h"

@interface TGVideoChatSetupViewController ()
@property (nonatomic, strong) NSDictionary *call;
@property (nonatomic, copy) NSString *chatTitle;
@property (nonatomic, copy) NSString *statusLine;
@property (nonatomic, copy) NSString *joinPayload;
@property (nonatomic, strong) NSArray *availableSenders;
@property (nonatomic, assign) BOOL busy;
@end

@implementation TGVideoChatSetupViewController

- (instancetype)initWithChatId:(int64_t)chatId groupCallId:(int32_t)groupCallId {
	self = [super init];
	if (self){
		_chatId = chatId;
		_groupCallId = groupCallId;
		self.listTitle = @"Video Chat";
		self.emptyText = @"None";
		_statusLine = nil;
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.listFooter = self.statusLine;
	[self reload];
}

- (void)reload {
	__weak typeof(self) weakSelf = self;
	if (self.chatId){
		[[TGClient shared] chatRecordForChat:self.chatId completion:^(NSDictionary *chat){
			TGVideoChatSetupViewController *me = weakSelf;
			if (!me)
				return;
			if ([chat[@"title"] isKindOfClass:NSString.class])
				me.chatTitle = chat[@"title"];
			int32_t fromChat = [chat[@"video_chat"][@"group_call_id"] intValue];
			if (!me.groupCallId && fromChat)
				me.groupCallId = fromChat;
			[me loadCall];
		}];
	} else {
		[self loadCall];
	}
}

- (void)loadCall {
	if (!self.groupCallId){
		[self rebuildRows];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] groupCall:self.groupCallId completion:^(NSDictionary *call, NSString *error){
		TGVideoChatSetupViewController *me = weakSelf;
		if (!me)
			return;
		me.call = call;
		if (!call && error.length)
			me.statusLine = error;
		[me rebuildRows];
	}];
}

- (void)setStatus:(NSString *)status {
	self.statusLine = status ?: @"";
	self.listFooter = self.statusLine;
	[self rebuildRows];
}

- (NSDictionary *)rowWithTitle:(NSString *)title detail:(NSString *)detail opens:(BOOL)opens tap:(void (^)(void))tap {
	NSMutableDictionary *row = [NSMutableDictionary dictionary];
	row[@"title"] = title ?: @"";
	if (detail.length)
		row[@"detail"] = detail;
	if (opens)
		row[@"opens"] = @YES;
	if (tap)
		row[@"tap"] = tap;
	return row;
}

- (NSDictionary *)rowWithTitle:(NSString *)title detail:(NSString *)detail tap:(void (^)(void))tap {
	return [self rowWithTitle:title detail:detail opens:NO tap:tap];
}

- (NSString *)callDetail:(NSString *)key yes:(NSString *)yes no:(NSString *)no {
	if (!self.call)
		return @"None";
	return [self.call[key] boolValue] ? yes : no;
}

- (void)rebuildRows {
	__weak typeof(self) weakSelf = self;
	NSMutableArray *rows = [NSMutableArray array];

	[rows addObject:[self rowWithTitle:@"Start Video Chat"
			detail:nil
			tap:^{ [weakSelf createVideoChat]; }]];
	[rows addObject:[self rowWithTitle:@"Create"
			detail:nil
			tap:^{ [weakSelf createStandaloneGroupCall]; }]];
	if (self.groupCallId){
		[rows addObject:[self rowWithTitle:@"Join"
				detail:nil
				tap:^{ [weakSelf joinCall]; }]];
		[rows addObject:[self rowWithTitle:@"Scheduled Video Chat"
				detail:nil
				tap:^{ [weakSelf startScheduled]; }]];
		[rows addObject:[self rowWithTitle:@"Video Chat Title"
				detail:self.call[@"title"] ?: @"None"
				tap:^{ [weakSelf editTitle]; }]];
	}

	if (self.groupCallId){
		[rows addObject:[self rowWithTitle:@"Participants"
				detail:nil
				tap:^{ [weakSelf chooseDefaultParticipant]; }]];
		[rows addObject:[self rowWithTitle:@"Invite"
				detail:nil
				tap:^{ [weakSelf inviteParticipants]; }]];
		[rows addObject:[self rowWithTitle:@"Invite Link"
				detail:self.call[@"inviteLink"] ?: @""
				tap:^{ [weakSelf fetchInviteLink]; }]];
		[rows addObject:[self rowWithTitle:@"Revoke Link"
				detail:nil
				tap:^{ [weakSelf revokeInviteLink]; }]];
		[rows addObject:[self rowWithTitle:@"Get RTMP URL"
				detail:nil
				tap:^{ [weakSelf fetchRtmpUrl]; }]];
		[rows addObject:[self rowWithTitle:@"Replace RTMP URL"
				detail:nil
				tap:^{ [weakSelf replaceRtmpUrl]; }]];
		[rows addObject:[self rowWithTitle:@"Start Recording"
				detail:nil
				tap:^{ [weakSelf startRecording]; }]];
		[rows addObject:[self rowWithTitle:@"Stop Recording"
				detail:nil
				tap:^{ [weakSelf endRecording]; }]];
		[rows addObject:[self rowWithTitle:@"Share Screen"
				detail:nil
				tap:^{ [weakSelf startScreenSharing]; }]];
		[rows addObject:[self rowWithTitle:@"Pause"
				detail:nil
				tap:^{ [weakSelf pauseScreenSharing]; }]];
		[rows addObject:[self rowWithTitle:@"Resume"
				detail:nil
				tap:^{ [weakSelf resumeScreenSharing]; }]];
		[rows addObject:[self rowWithTitle:@"Stop"
				detail:nil
				tap:^{ [weakSelf stopScreenSharing]; }]];
		[rows addObject:[self rowWithTitle:@"Messages"
				detail:[self callDetail:@"areMessagesAllowed" yes:@"On" no:@"Off"]
				tap:^{ [weakSelf toggleMessagesAllowed]; }]];
		[rows addObject:[self rowWithTitle:@"Muted"
				detail:[self callDetail:@"muteNewParticipants" yes:@"On" no:@"Off"]
				tap:^{ [weakSelf toggleMuteNewParticipants]; }]];
		[rows addObject:[self rowWithTitle:@"Notifications"
				detail:[self callDetail:@"enabledStartNotification" yes:@"On" no:@"Off"]
				tap:^{ [weakSelf toggleStartNotification]; }]];
		[rows addObject:[self rowWithTitle:@"Data"
				detail:nil
				opens:YES
				tap:^{ [weakSelf openStreams]; }]];
		[rows addObject:[self rowWithTitle:@"End"
				detail:nil
				tap:^{ [weakSelf endCall]; }]];
	}

	self.rows = rows;
}

#pragma mark - create

- (void)createVideoChat {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:@[@"Start Video Chat",
								@"Scheduled Video Chat",
								@"RTMP stream, start now",
								@"RTMP stream, in 1 hour"]
						title:@"Start Video Chat"
			   destructiveIndex:-1 inView:self.view onChoice:^(NSInteger index){
		TGVideoChatSetupViewController *me = weakSelf;
		if (!me)
			return;
		BOOL rtmp = index >= 2;
		BOOL scheduled = (index == 1 || index == 3);
		[TGAlertSheet showInput:@"Video Chat Title"
						message:nil
					placeholder:me.chatTitle ?: @"Video chat"
						   text:me.chatTitle action:@"Create" inView:me.view
					   onSubmit:^(NSString *text){
			TGVideoChatSetupViewController *again = weakSelf;
			if (!again)
				return;
			int32_t start = scheduled
					? (int32_t)([[NSDate date] timeIntervalSince1970] + 3600) : 0;
			[[TGClient shared] createVideoChatInChat:again.chatId title:text
					startDate:start isRtmp:rtmp completion:^(int32_t callId, NSString *error){
				TGVideoChatSetupViewController *got = weakSelf;
				if (!got)
					return;
				if (!callId){
					[got setStatus:error ?: @"An error occurred."];
					return;
				}
				got.groupCallId = callId;
				[got setStatus:@"Done"];
				[got loadCall];
				[got pushCallScreen];
			}];
		}];
	}];
}

- (void)createStandaloneGroupCall {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] createGroupCallWithParameters:TGGroupCallJoinParameters(0, @"", NO, NO)
			completion:^(NSDictionary *info, NSString *error){
		TGVideoChatSetupViewController *me = weakSelf;
		if (!me)
			return;
		if (!info){
			[me setStatus:error ?: @"An error occurred."];
			return;
		}
		me.groupCallId = [info[@"groupCallId"] intValue];
		me.joinPayload = info[@"joinPayload"];
		[me setStatus:@"Done"];
		[me loadCall];
	}];
}

- (void)joinCall {
	if (!self.groupCallId)
		return;
	__weak typeof(self) weakSelf = self;
	NSDictionary *parameters = TGGroupCallJoinParameters(0, @"", NO, NO);
	void (^done)(BOOL, NSString *) = ^(BOOL ok, NSString *error){
		TGVideoChatSetupViewController *me = weakSelf;
		if (!me)
			return;
		[me setStatus:(ok ? @"Done"
				: (error ?: @"An error occurred."))];
		[me loadCall];
	};
	if ([self.call[@"isVideoChat"] boolValue] || [self.call[@"isLiveStory"] boolValue]){
		[[TGClient shared] joinVideoChat:self.groupCallId participant:nil
							   parameters:parameters inviteHash:@""
							   completion:^(NSString *payload, NSString *error){
			TGVideoChatSetupViewController *me = weakSelf;
			if (me && payload.length)
				me.joinPayload = payload;
			done(error.length == 0, error);
		}];
	} else {
		[[TGClient shared] joinGroupCallWithInput:TGGroupCallInput(self.groupCallId, 0)
									   parameters:parameters
									   completion:^(NSDictionary *info, NSString *error){
			TGVideoChatSetupViewController *me = weakSelf;
			if (me && info[@"joinPayload"])
				me.joinPayload = info[@"joinPayload"];
			done(error.length == 0, error);
		}];
	}
}

- (void)startScheduled {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] startScheduledVideoChat:self.groupCallId
									completion:^(BOOL ok, NSString *error){
		[weakSelf setStatus:(ok ? @"Done"
				: (error ?: @"An error occurred."))];
		[weakSelf loadCall];
	}];
}

- (void)editTitle {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Video Chat Title" message:nil
				placeholder:@"Video Chat"
					   text:self.call[@"title"] action:@"Save" inView:self.view
				   onSubmit:^(NSString *text){
		TGVideoChatSetupViewController *me = weakSelf;
		if (!me)
			return;
		[[TGClient shared] setVideoChatTitle:text inCall:me.groupCallId
								  completion:^(BOOL ok, NSString *error){
			[me setStatus:(ok ? @"Done" : (error ?: @"An error occurred."))];
			[me loadCall];
		}];
	}];
}

#pragma mark - participants

- (void)loadAvailableSenders:(void (^)(void))done {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] videoChatAvailableParticipantsForChat:self.chatId
			completion:^(NSDictionary *answer, NSString *error){
		TGVideoChatSetupViewController *me = weakSelf;
		if (!me)
			return;
		me.availableSenders = answer[@"senders"] ?: @[];
		if (!answer)
			[me setStatus:error ?: @"An error occurred."];
		if (done)
			done();
	}];
}

- (NSString *)labelForSender:(NSDictionary *)sender {
	if ([sender[@"@type"] isEqualToString:@"messageSenderChat"])
		return [[TGClient shared] titleForChat:[sender[@"chat_id"] longLongValue]] ?: @"Chat";
	return [[TGClient shared] nameForUserId:[sender[@"user_id"] longLongValue]] ?: @"User";
}

- (void)chooseDefaultParticipant {
	__weak typeof(self) weakSelf = self;
	[self loadAvailableSenders:^{
		TGVideoChatSetupViewController *me = weakSelf;
		if (!me)
			return;
		NSMutableArray *titles = [NSMutableArray array];
		for (NSDictionary *sender in me.availableSenders)
			[titles addObject:[me labelForSender:sender]];
		if (!titles.count){
			[me setStatus:@"An error occurred."];
			return;
		}
		[TGAlertSheet showChoices:titles title:@"Join Video Chat"
				destructiveIndex:-1 inView:me.view onChoice:^(NSInteger index){
			if (index < 0 || index >= (NSInteger)me.availableSenders.count)
				return;
			NSDictionary *sender = me.availableSenders[(NSUInteger)index];
			[[TGClient shared] setVideoChatDefaultParticipant:sender forChat:me.chatId
					completion:^(BOOL ok, NSString *error){
				[me setStatus:(ok ? @"Done"
						: (error ?: @"An error occurred."))];
				[me loadCall];
			}];
		}];
	}];
}

- (void)inviteParticipants {
	__weak typeof(self) weakSelf = self;
	[self loadAvailableSenders:^{
		TGVideoChatSetupViewController *me = weakSelf;
		if (!me)
			return;
		NSMutableArray *titles = [NSMutableArray array];
		for (NSDictionary *sender in me.availableSenders)
			[titles addObject:[me labelForSender:sender]];
		if (!titles.count){
			[TGAlertSheet showInput:@"Invite" message:nil
					placeholder:@"123456789" text:nil action:@"Invite"
						   inView:me.view onSubmit:^(NSString *text){
				int64_t userId = text.longLongValue;
				if (userId <= 0)
					return;
				[[TGClient shared] inviteVideoChatParticipants:@[@(userId)]
						toCall:me.groupCallId completion:^(BOOL ok, NSString *error){
					[me setStatus:(ok ? @"Done" : (error ?: @"An error occurred."))];
				}];
			}];
			return;
		}
		[TGAlertSheet showChoices:titles title:@"Invite"
				destructiveIndex:-1 inView:me.view onChoice:^(NSInteger index){
			if (index < 0 || index >= (NSInteger)me.availableSenders.count)
				return;
			int64_t userId = [me.availableSenders[(NSUInteger)index][@"user_id"] longLongValue];
			if (!userId)
				return;
			[[TGClient shared] inviteVideoChatParticipants:@[@(userId)]
					toCall:me.groupCallId completion:^(BOOL ok, NSString *error){
				[me setStatus:(ok ? @"Done" : (error ?: @"An error occurred."))];
			}];
		}];
	}];
}

#pragma mark - links

- (void)fetchInviteLink {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:@[@"Unmute", @"Muted"]
						title:@"Invite Link" destructiveIndex:-1 inView:self.view
					 onChoice:^(NSInteger index){
		TGVideoChatSetupViewController *me = weakSelf;
		if (!me)
			return;
		[[TGClient shared] videoChatInviteLink:me.groupCallId canSelfUnmute:index == 0
									completion:^(NSString *link, NSString *error){
			if (!link.length){
				[me setStatus:error ?: @"An error occurred."];
				return;
			}
			[UIPasteboard generalPasteboard].string = link;
			[me setStatus:@"Link copied."];
		}];
	}];
}

- (void)revokeInviteLink {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:nil
						title:@"Revoke Link" action:@"Revoke" destructive:YES
					   inView:self.view onConfirm:^{
		TGVideoChatSetupViewController *me = weakSelf;
		if (!me)
			return;
		[[TGClient shared] revokeGroupCallInviteLink:me.groupCallId
										  completion:^(BOOL ok, NSString *error){
			[me setStatus:(ok ? @"Done"
					: (error ?: @"An error occurred."))];
			[me loadCall];
		}];
	}];
}

- (void)fetchRtmpUrl {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] videoChatRtmpUrlForChat:self.chatId
									completion:^(NSDictionary *answer, NSString *error){
		TGVideoChatSetupViewController *me = weakSelf;
		if (!me)
			return;
		if (!answer){
			[me setStatus:error ?: @"An error occurred."];
			return;
		}
		NSString *sentence = [NSString stringWithFormat:@"RTMP: %@  Key: %@",
				answer[@"url"], answer[@"streamKey"]];
		[UIPasteboard generalPasteboard].string =
				[NSString stringWithFormat:@"%@/%@", answer[@"url"], answer[@"streamKey"]];
		[me setStatus:sentence];
	}];
}

- (void)replaceRtmpUrl {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:nil
						title:@"Replace RTMP URL" action:@"Replace" destructive:YES
					   inView:self.view onConfirm:^{
		TGVideoChatSetupViewController *me = weakSelf;
		if (!me)
			return;
		[[TGClient shared] replaceVideoChatRtmpUrlForChat:me.chatId
				completion:^(NSDictionary *answer, NSString *error){
			if (!answer){
				[me setStatus:error ?: @"An error occurred."];
				return;
			}
			[me setStatus:[NSString stringWithFormat:@"New RTMP: %@  Key: %@",
					answer[@"url"], answer[@"streamKey"]]];
		}];
	}];
}

#pragma mark - recording and screen sharing

- (void)startRecording {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:@[@"Audio recording", @"Video recording, landscape",
								@"Video recording, portrait"]
						title:@"Start Recording" destructiveIndex:-1 inView:self.view
					 onChoice:^(NSInteger index){
		TGVideoChatSetupViewController *me = weakSelf;
		if (!me)
			return;
		[TGAlertSheet showInput:@"Title" message:nil
					placeholder:@"Title" text:nil action:@"Start"
						   inView:me.view onSubmit:^(NSString *text){
			[[TGClient shared] startGroupCallRecording:me.groupCallId title:text
					recordVideo:index > 0 portrait:index == 2
					completion:^(BOOL ok, NSString *error){
				[me setStatus:(ok ? @"Done"
						: (error ?: @"An error occurred."))];
				[me loadCall];
			}];
		}];
	}];
}

- (void)endRecording {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] endGroupCallRecording:self.groupCallId
								  completion:^(BOOL ok, NSString *error){
		TGVideoChatSetupViewController *me = weakSelf;
		if (!me)
			return;
		[me setStatus:(ok ? @"Done"
				: (error ?: @"An error occurred."))];
		[me loadCall];
	}];
}

- (void)startScreenSharing {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Share Screen"
					message:nil
				placeholder:@"Join payload"
					   text:self.joinPayload action:@"Start" inView:self.view
				   onSubmit:^(NSString *text){
		TGVideoChatSetupViewController *me = weakSelf;
		if (!me)
			return;
		[[TGClient shared] startGroupCallScreenSharing:me.groupCallId
				audioSourceId:0 payload:text completion:^(NSString *answer, NSString *error){
			if (error.length){
				[me setStatus:error];
				return;
			}
			if (answer.length)
				me.joinPayload = answer;
			[me setStatus:@"Done"];
			[me loadCall];
		}];
	}];
}

- (void)pauseScreenSharing {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] toggleGroupCallScreenSharingPaused:self.groupCallId paused:YES
											   completion:^(BOOL ok, NSString *error){
		[weakSelf setStatus:(ok ? @"Done"
				: (error ?: @"An error occurred."))];
	}];
}

- (void)resumeScreenSharing {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] toggleGroupCallScreenSharingPaused:self.groupCallId paused:NO
											   completion:^(BOOL ok, NSString *error){
		[weakSelf setStatus:(ok ? @"Done"
				: (error ?: @"An error occurred."))];
	}];
}

- (void)stopScreenSharing {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] endGroupCallScreenSharing:self.groupCallId
									  completion:^(BOOL ok, NSString *error){
		[weakSelf setStatus:(ok ? @"Done"
				: (error ?: @"An error occurred."))];
		[weakSelf loadCall];
	}];
}

#pragma mark - switches and endings

- (void)toggleMessagesAllowed {
	BOOL on = [self.call[@"areMessagesAllowed"] boolValue];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] toggleGroupCallMessagesAllowed:self.groupCallId allowed:!on
										   completion:^(BOOL ok, NSString *error){
		TGVideoChatSetupViewController *me = weakSelf;
		if (!me)
			return;
		[me setStatus:(ok ? @"Done"
				: (error ?: @"An error occurred."))];
		[me loadCall];
	}];
}

- (void)toggleMuteNewParticipants {
	BOOL on = [self.call[@"muteNewParticipants"] boolValue];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] toggleVideoChatMuteNewParticipants:self.groupCallId muted:!on
											   completion:^(BOOL ok, NSString *error){
		TGVideoChatSetupViewController *me = weakSelf;
		if (!me)
			return;
		[me setStatus:(ok ? @"Done"
				: (error ?: @"An error occurred."))];
		[me loadCall];
	}];
}

- (void)toggleStartNotification {
	BOOL on = [self.call[@"enabledStartNotification"] boolValue];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] toggleVideoChatStartNotification:self.groupCallId enabled:!on
											 completion:^(BOOL ok, NSString *error){
		TGVideoChatSetupViewController *me = weakSelf;
		if (!me)
			return;
		[me setStatus:(ok ? @"Done"
				: (error ?: @"An error occurred."))];
		[me loadCall];
	}];
}

- (void)endCall {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:nil
						title:@"End" action:@"End" destructive:YES
					   inView:self.view onConfirm:^{
		TGVideoChatSetupViewController *me = weakSelf;
		if (!me)
			return;
		[[TGClient shared] endGroupCall:me.groupCallId completion:^(BOOL ok, NSString *error){
			[me setStatus:(ok ? @"Call Ended" : (error ?: @"An error occurred."))];
			[me loadCall];
		}];
	}];
}

#pragma mark - navigation

- (void)pushCallScreen {
	TGGroupCallViewController *screen =
			[[TGGroupCallViewController alloc] initWithChatId:self.chatId
												 groupCallId:self.groupCallId];
	screen.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:screen animated:YES];
}

- (void)openStreams {
	TGVideoChatStreamViewController *screen =
			[[TGVideoChatStreamViewController alloc] initWithChatId:self.chatId
														groupCallId:self.groupCallId];
	screen.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:screen animated:YES];
}

@end

// vim:ft=objc
