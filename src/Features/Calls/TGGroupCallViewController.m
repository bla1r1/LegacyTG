#import "TGGroupCallViewController.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGIcons.h"
#import "TGRows.h"
#import "TGRowsDataSource.h"
#import "TGGroupCallParticipantCell.h"
#import "TGGroupCallParticipantsViewController.h"
#import "TGVideoChatSetupViewController.h"
#import "TGCallMessagesViewController.h"
#import "TGVideoChatStreamViewController.h"
#import "TGCallStore.h"
#import "TGProfileStore.h"

/// The header carries the title and the one line of state; the table below
/// is the controls and the first people in the call.
static const CGFloat kGCCallHeaderHeight = 112.0f;
static const CGFloat kGCCallRowsShown = 5;
static const CGFloat kGCCallStatusHeight = TGMetricLineBody;
static const CGFloat kGCCallStatusLines = 2.0f;
static const CGFloat kGCCallNoteHeight = TGMetricLineCaption;

@interface TGGroupCallViewController ()
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) TGRowsDataSource *rowSource;
@property (nonatomic, strong) UIView *header;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *noteLabel;
@property (nonatomic, strong) NSDictionary *call;
@property (nonatomic, strong) NSArray *participants;
@property (nonatomic, strong) NSArray *sections;
@property (nonatomic, copy) NSString *chatTitle;
@property (nonatomic, copy) NSString *joinPayload;
@property (nonatomic, copy) NSString *loadError;
@property (nonatomic, strong) NSDate *openedAt;
@property (nonatomic, strong) NSTimer *ticker;
@property (nonatomic, strong) NSArray *observers;
@property (nonatomic, assign) BOOL busy;
@end

@implementation TGGroupCallViewController

- (instancetype)initWithChatId:(int64_t)chatId groupCallId:(int32_t)groupCallId {
	self = [super initWithNibName:nil bundle:nil];
	if (self){
		_chatId = chatId;
		_groupCallId = groupCallId;
		self.title = @"Group Call";
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.view.backgroundColor = [[TGTheme shared] groupedBackgroundColour];
	[self buildHeader];
	[self buildTable];
	[self observe];
	[self loadChatAndCall];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self startTicker];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[self stopTicker];
}

/// The clock is the only thing on this screen that needs a timer, and a timer
/// retains its target: leaving it running after the screen is popped keeps the
/// controller and the timer alive together. It runs only while the screen is.
- (void)startTicker {
	[self stopTicker];
	self.ticker = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self
			selector:@selector(tick) userInfo:nil repeats:YES];
}

- (void)stopTicker {
	[self.ticker invalidate];
	self.ticker = nil;
}

- (void)dealloc {
	[self.ticker invalidate];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)buildHeader {
	CGRect bounds = self.view.bounds;
	CGFloat gutter = TGMetricPadLarge;
	CGFloat width = bounds.size.width - TGDoubled(gutter);
	self.header = [[UIView alloc] initWithFrame:
			CGRectMake(0, 0, bounds.size.width, kGCCallHeaderHeight)];
	self.header.backgroundColor = [[TGTheme shared] groupedBackgroundColour];

	self.titleLabel = [[UILabel alloc] initWithFrame:
			CGRectMake(gutter, TGMetricPad, width, TGMetricLineHeader)];
	self.titleLabel.font = TGFontHeader();
	self.titleLabel.backgroundColor = [UIColor clearColor];
	[self.header addSubview:self.titleLabel];

	CGFloat statusY = TGMetricPad + TGMetricLineHeader + TGMetricPadSmall;
	self.statusLabel = [[UILabel alloc] initWithFrame:
			CGRectMake(gutter, statusY, width, kGCCallStatusHeight * kGCCallStatusLines)];
	self.statusLabel.font = TGFontSubhead();
	self.statusLabel.numberOfLines = 2;
	self.statusLabel.backgroundColor = [UIColor clearColor];
	[self.header addSubview:self.statusLabel];

	CGFloat noteY = statusY + kGCCallStatusHeight * kGCCallStatusLines + TGMetricPadSmall;
	self.noteLabel = [[UILabel alloc] initWithFrame:
			CGRectMake(gutter, noteY, width, kGCCallNoteHeight)];
	self.noteLabel.font = TGFontCaption();
	self.noteLabel.backgroundColor = [UIColor clearColor];
	[self.header addSubview:self.noteLabel];
}

- (void)buildTable {
	UIView *container = [[UIView alloc] initWithFrame:self.view.bounds];
	self.table = [[UITableView alloc] initWithFrame:container.bounds
											  style:UITableViewStyleGrouped];
	self.table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.table.tableHeaderView = self.header;
	self.rowSource = [[TGRowsDataSource alloc] initWithTableView:self.table];
	[self.view addSubview:self.table];
}

- (void)observe {
	__weak typeof(self) weakSelf = self;
	void (^changed)(NSNotification *) = ^(NSNotification *note){
		TGGroupCallViewController *me = weakSelf;
		if (!me)
			return;
		int32_t callId = [note.userInfo[TGGroupCallIdKey] intValue];
		if (callId && me.groupCallId && callId != me.groupCallId)
			return;
		if (callId)
			me.groupCallId = callId;
		[me reload];
	};
	self.observers = @[
		[[NSNotificationCenter defaultCenter]
				addObserverForName:TGGroupCallChangedNotification
							object:nil queue:[NSOperationQueue mainQueue] usingBlock:changed],
		[[NSNotificationCenter defaultCenter]
				addObserverForName:TGGroupCallParticipantsChangedNotification
							object:nil queue:[NSOperationQueue mainQueue] usingBlock:changed],
		[[NSNotificationCenter defaultCenter]
				addObserverForName:TGGroupCallMessagesChangedNotification
							object:nil queue:[NSOperationQueue mainQueue] usingBlock:changed],
		[[NSNotificationCenter defaultCenter]
				addObserverForName:TGThemeChangedNotification
							object:nil queue:[NSOperationQueue mainQueue]
						usingBlock:^(NSNotification *note){
			[weakSelf applyTheme];
		}],
	];
}

- (void)applyTheme {
	[[TGTheme shared] styleGroupedTable:self.table];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	self.header.backgroundColor = [[TGTheme shared] groupedBackgroundColour];
	[self updateHeader];
	// The participant rows carry the accent and the muted glyph as values, so
	// a theme change rebuilds them; reloading alone would keep the old colours.
	self.sections = [self buildSections];
	self.rowSource.sections = self.sections;
	[self.rowSource reloadRows];
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	CGFloat width = self.view.bounds.size.width;
	if (width <= 0)
		return;
	CGRect frame = self.header.frame;
	frame.size.width = width;
	self.header.frame = frame;
	self.table.tableHeaderView = self.header;
	CGFloat gutter = TGMetricPadLarge;
	CGFloat textWidth = width - TGDoubled(gutter);
	CGRect title = self.titleLabel.frame;
	title.size.width = textWidth;
	self.titleLabel.frame = title;
	CGRect status = self.statusLabel.frame;
	status.size.width = textWidth;
	self.statusLabel.frame = status;
	CGRect note = self.noteLabel.frame;
	note.size.width = textWidth;
	self.noteLabel.frame = note;
}

#pragma mark - loading

- (void)loadChatAndCall {
	if (!self.chatId){
		[self loadCall];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGProfileStore shared]chatRecordForChat:self.chatId completion:^(NSDictionary *chat){
		TGGroupCallViewController *me = weakSelf;
		if (!me)
			return;
		NSString *title = chat[@"title"];
		if (title.length)
			me.chatTitle = title;
		int32_t fromChat = [chat[@"video_chat"][@"group_call_id"] intValue];
		if (!me.groupCallId && fromChat)
			me.groupCallId = fromChat;
		[me loadCall];
	}];
}

- (void)loadCall {
	if (!self.groupCallId){
		[self reload];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGCallStore shared]groupCall:self.groupCallId completion:^(NSDictionary *call, NSString *error){
		TGGroupCallViewController *me = weakSelf;
		if (!me)
			return;
		me.call = call;
		me.loadError = call ? nil : (error ?: @"An error occurred.");
		if (!call){
			[TGAlertSheet showMessage:me.loadError title:@"Group Call" inView:me.view];
			[me reload];
			return;
		}
		if ([call[@"isJoined"] boolValue]){
			[[TGCallStore shared]loadGroupCallParticipants:me.groupCallId limit:100
					completion:^(BOOL ok, NSString *why){ [weakSelf reload]; }];
		}
		[me reload];
	}];
}

- (void)reload {
	self.participants = [[TGCallStore shared]groupCallParticipantSnapshot:self.groupCallId];
	if (!self.openedAt && self.call)
		self.openedAt = [NSDate date];
	[self updateHeader];
	self.sections = [self buildSections];
	self.rowSource.sections = self.sections;
	[self.rowSource reloadRows];
}

- (void)tick {
	[self updateHeader];
}

static NSString *TGGroupCallClock(NSTimeInterval seconds) {
	NSInteger total = (NSInteger)MAX(0, seconds);
	if (total >= 3600)
		return [NSString stringWithFormat:@"%ld:%02ld:%02ld",
				(long)(total / 3600), (long)((total % 3600) / 60), (long)(total % 60)];
	return [NSString stringWithFormat:@"%02ld:%02ld", (long)(total / 60), (long)(total % 60)];
}

/// "Starts in 5 minutes" rather than a device-locale date: the official line
/// is relative, and "Scheduled for %@" in the pack means message sending.
static NSString *TGGroupCallStartsText(int32_t stamp) {
	if (!stamp)
		return @"";
	NSInteger gap = MAX(0, stamp - (int32_t)[[NSDate date] timeIntervalSince1970]);
	NSInteger count;
	NSString *one, *other;
	if (gap < 3600){
		count = MAX(1, gap / 60);
		one = @"%@ minute";
		other = @"%@ minutes";
	} else if (gap < 86400){
		count = gap / 3600;
		one = @"%@ hour";
		other = @"%@ hours";
	} else {
		count = gap / 86400;
		one = @"%@ day";
		other = @"%@ days";
	}
	NSString *value = [NSString stringWithFormat:@"%ld", (long)count];
	NSString *unit = TGLocalizedPluralValue(one, other, value, count);
	return TGLocalizedFormat(@"Starts in %@", unit);
}

- (NSString *)speakingLine {
	NSMutableArray *names = [NSMutableArray array];
	for (NSDictionary *row in self.participants)
		if ([row[@"isSpeaking"] boolValue] && ![row[@"isMutedForAllUsers"] boolValue]){
			NSString *name = row[@"name"];
			if (name.length)
				[names addObject:name];
		}
	if (names.count)
		return TGLocalizedFormat(@"%@ speaking",
				[names componentsJoinedByString:@", "]);
	for (NSDictionary *speaker in self.call[@"recentSpeakers"])
		if ([speaker[@"isSpeaking"] boolValue])
			return @"Speaking";
	return @"";
}

- (void)updateHeader {
	if (!self.isViewLoaded)
		return;
	NSString *title = self.call[@"title"];
	if (!title.length)
		title = self.chatTitle;
	if (!title.length)
		title = @"Group Call";
	self.titleLabel.text = title;
	self.titleLabel.textColor = [[TGTheme shared] primaryTextColour];
	self.statusLabel.textColor = [[TGTheme shared] secondaryTextColour];
	self.noteLabel.textColor = [[TGTheme shared] secondaryTextColour];

	if (!self.call){
		// The connecting state belongs to the title, as the official header's
		// title-status line does; the subtitle stays empty until a call loads.
		self.titleLabel.text = self.groupCallId
				? (self.loadError.length ? self.loadError : @"Connecting")
				: @"Video Chat";
		self.statusLabel.text = nil;
		self.noteLabel.text = nil;
		return;
	}

	NSInteger count = [self.call[@"participantCount"] integerValue];
	NSMutableArray *line = [NSMutableArray array];
	if ([self.call[@"isActive"] boolValue]){
		[line addObject:TGLocalizedPluralValue(@"%@ participant", @"%@ participants",
				[NSString stringWithFormat:@"%ld", (long)count], count)];
		if ([self.call[@"isJoined"] boolValue]){
			NSInteger duration = [self.call[@"duration"] intValue];
			if (duration <= 0 && self.openedAt)
				duration = (NSInteger)MAX(0, -[self.openedAt timeIntervalSinceNow]);
			if (duration > 0)
				[line addObject:TGGroupCallClock(duration)];
		}
	} else if ([self.call[@"scheduledStartDate"] intValue] > 0){
		[line addObject:TGGroupCallStartsText(
				[self.call[@"scheduledStartDate"] intValue])];
	} else {
		[line addObject:@"Call Ended"];
		NSInteger duration = [self.call[@"duration"] intValue];
		if (duration > 0)
			[line addObject:TGLocalizedFormat(@"Duration: %@",
					TGGroupCallClock(duration))];
	}
	if ([self.call[@"recordDuration"] intValue] > 0){
		[line addObject:TGLocalized([self.call[@"isLiveStory"] boolValue]
				? @"Live stream is being recorded"
				: @"Video chat is being recorded")];
	}
	self.statusLabel.text = [line componentsJoinedByString:@" · "];

	NSString *speaking = [self speakingLine];
	if (speaking.length){
		self.noteLabel.text = speaking;
	} else if ([self.call[@"isJoined"] boolValue]) {
		self.noteLabel.text = nil;
	} else {
		self.noteLabel.text = nil;
	}
}

#pragma mark - sections

- (NSDictionary *)row:(NSString *)title detail:(NSString *)detail opens:(BOOL)opens tap:(void (^)(void))tap {
	if (!tap)
		return TGSubtitleRow(title, detail, nil);
	if (opens){
		return detail.length ? TGSubtitleOpenRow(title, detail, tap)
				: TGOpenRow(title, detail, tap);
	}
	return detail.length ? TGSubtitleRow(title, detail, tap)
			: TGTapRow(title, detail, tap);
}

- (NSDictionary *)row:(NSString *)title detail:(NSString *)detail tap:(void (^)(void))tap {
	return [self row:title detail:detail opens:NO tap:tap];
}

- (NSDictionary *)destructiveRow:(NSString *)title detail:(NSString *)detail tap:(void (^)(void))tap {
	NSMutableDictionary *row = [TGRedRow(title, tap) mutableCopy];
	if (detail.length)
		row[TGRowDetail] = detail;
	return row;
}

- (NSArray *)buildSections {
	NSMutableArray *sections = [NSMutableArray array];
	__weak typeof(self) weakSelf = self;

	if (!self.call && !self.groupCallId){
#if TG_DEV
		// Creating a call from setup is a bench tool; Telegram creates it and
		// drops straight into the call.
		[sections addObject:TGSection(@"Video Chat", nil,
				@[[self row:@"Start Video Chat"
					 detail:nil
					 opens:YES
					   tap:^{ [weakSelf openSetup]; }]])];
#endif
		return sections;
	}
	if (!self.call){
		if (self.loadError.length){
			[sections addObject:TGSection(@"Call", nil,
					@[[self row:@"Unavailable"
						 detail:self.loadError tap:nil]])];
		}
		return sections;
	}

	NSMutableArray *callRows = [NSMutableArray array];
	BOOL joined = [self.call[@"isJoined"] boolValue];
	BOOL active = [self.call[@"isActive"] boolValue];
	if (active){
		[callRows addObject:[self row:(joined ? @"Leave" : @"Join")
				detail:nil
				tap:^{ joined ? [weakSelf leaveCall] : [weakSelf joinCall]; }]];
	}
	if (!active && [self.call[@"scheduledStartDate"] intValue] > 0){
		[callRows addObject:[self row:@"Start"
				detail:nil tap:^{ [weakSelf startScheduled]; }]];
	}
	if (joined){
		NSDictionary *me = [[TGCallStore shared]currentGroupCallParticipant:self.groupCallId];
		BOOL muted = [me[@"isMutedForAllUsers"] boolValue] ||
					 [me[@"isMutedForCurrentUser"] boolValue];
		[callRows addObject:[self row:(muted ? @"Unmute" : @"Mute Yourself")
				detail:nil
				tap:^{ [weakSelf toggleSelfMuted]; }]];
		BOOL videoOn = [self.call[@"isMyVideoEnabled"] boolValue];
		[callRows addObject:[self row:@"Camera"
				detail:(videoOn ? @"On" : @"Off")
				tap:^{ [weakSelf toggleMyVideo]; }]];
		BOOL paused = [self.call[@"isMyVideoPaused"] boolValue];
		[callRows addObject:[self row:(paused ? @"Resume" : @"Pause Video")
				detail:nil
				tap:^{ [weakSelf toggleMyVideoPaused]; }]];
	}
	[sections addObject:TGSection(@"Call", nil, callRows)];

	NSMutableArray *people = [NSMutableArray array];
	UIImage *mutedIcon = [TGIcons microphoneOffOfSide:TGMetricLineCaption
			colour:[[TGTheme shared] secondaryTextColour]];
	NSInteger shown = MIN((NSInteger)self.participants.count, (NSInteger)kGCCallRowsShown);
	for (NSInteger i = 0; i < shown; i++){
		NSDictionary *participant = self.participants[(NSUInteger)i];
		NSMutableDictionary *row = TGGroupCallParticipantRow(participant,
				[[TGTheme shared] accentColour], mutedIcon);
		if (!row)
			continue;
		row[TGRowTap] = ^{ [weakSelf openParticipants]; };
		[people addObject:row];
	}
	NSInteger count = [self.call[@"participantCount"] integerValue];
	if (self.participants.count || count > shown){
		[people addObject:[self row:@"Participants"
				detail:[NSString stringWithFormat:@"%ld", (long)count]
				opens:YES
				tap:^{ [weakSelf openParticipants]; }]];
	}
	[sections addObject:TGSection(@"People", nil, people)];

	NSMutableArray *messages = [NSMutableArray array];
	NSArray *callMessages = [[TGCallStore shared]groupCallMessageSnapshot:self.groupCallId];
	NSInteger first = MAX(0, (NSInteger)callMessages.count - 3);
	for (NSInteger i = first; i < (NSInteger)callMessages.count; i++){
		NSDictionary *message = callMessages[(NSUInteger)i];
		[messages addObject:[self row:(message[@"senderName"] ?: @"Participants")
				detail:(message[@"text"] ?: @"Star Reaction")
				opens:YES
				tap:^{ [weakSelf openMessages]; }]];
	}
	[messages addObject:[self row:(callMessages.count ? @"Messages" : @"Send Message")
			detail:nil opens:YES tap:^{ [weakSelf openMessages]; }]];
	[sections addObject:TGSection(@"Messages", nil, messages)];

#if TG_DEV
	NSMutableArray *tools = [NSMutableArray array];
	[tools addObject:[self row:@"Manage"
						detail:nil
						 opens:YES
						   tap:^{ [weakSelf openSetup]; }]];
	[tools addObject:[self row:@"Data"
						detail:nil
						 opens:YES
						   tap:^{ [weakSelf openStreams]; }]];
	[sections addObject:TGSection(@"Settings", nil, tools)];
#endif

	NSMutableArray *invite = [NSMutableArray array];
	[invite addObject:[self row:@"Invite"
						 detail:nil
							tap:^{ [weakSelf inviteMember]; }]];
	[invite addObject:[self row:@"Copy Invite Link"
						 detail:self.call[@"inviteLink"] ?: @""
							tap:^{ [weakSelf copyInviteLink]; }]];
	[sections addObject:TGSection(@"Invite", nil, invite)];

	NSMutableArray *end = [NSMutableArray array];
	if (active){
		[end addObject:[self destructiveRow:@"End"
				detail:nil tap:^{ [weakSelf endCall]; }]];
		[sections addObject:TGSection(@"End", nil, end)];
	}
	return sections;
}

#pragma mark - call actions

- (void)joinCall {
	if (!self.groupCallId){
#if TG_DEV
		[self openSetup];
#endif
		return;
	}
	if (self.busy)
		return;
	self.busy = YES;
	__weak typeof(self) weakSelf = self;
	void (^done)(BOOL, NSString *) = ^(BOOL ok, NSString *error){
		TGGroupCallViewController *me = weakSelf;
		if (!me)
			return;
		me.busy = NO;
		if (!ok){
			[TGAlertSheet showMessage:error ?: @"An error occurred."
								title:@"Join" inView:me.view];
			return;
		}
		me.openedAt = [NSDate date];
		[me loadCall];
	};
	NSDictionary *parameters = TGGroupCallJoinParameters(0, @"", NO, NO);
	if ([self.call[@"isVideoChat"] boolValue] || [self.call[@"isLiveStory"] boolValue]){
		[[TGCallStore shared]joinVideoChat:self.groupCallId participant:nil
							   parameters:parameters inviteHash:@""
							   completion:^(NSString *payload, NSString *error){
			if (payload)
				weakSelf.joinPayload = payload;
			done(error.length == 0, error);
		}];
	} else {
		[[TGCallStore shared]joinGroupCallWithInput:TGGroupCallInput(self.groupCallId, 0)
									   parameters:parameters
									   completion:^(NSDictionary *info, NSString *error){
			if (info[@"joinPayload"])
				weakSelf.joinPayload = info[@"joinPayload"];
			done(error.length == 0, error);
		}];
	}
}

- (void)leaveCall {
	if (self.busy)
		return;
	self.busy = YES;
	__weak typeof(self) weakSelf = self;
	[[TGCallStore shared]leaveGroupCall:self.groupCallId completion:^(BOOL ok, NSString *error){
		TGGroupCallViewController *me = weakSelf;
		if (!me)
			return;
		me.busy = NO;
		if (!ok)
			[TGAlertSheet showMessage:error ?: @"An error occurred."
								title:@"Leave" inView:me.view];
		[me loadCall];
	}];
}

- (void)endCall {
	__weak typeof(self) weakSelf = self;
	// A broadcast channel is a live stream; a group's voice chat is not,
	// even when the call carries video.
	BOOL live = [self.call[@"isLiveStory"] boolValue];
	NSString *title = live ? @"End Live Stream" : @"End Video Chat";
	NSString *message = live
			? @"Are you sure you want to end this live stream?"
			: @"Are you sure you want to end this video chat?";
	[TGAlertSheet showConfirm:message
						title:title action:title destructive:YES
					   inView:self.view onConfirm:^{
		TGGroupCallViewController *me = weakSelf;
		if (!me)
			return;
		[[TGCallStore shared]endGroupCall:me.groupCallId completion:^(BOOL ok, NSString *error){
			if (!ok)
				[TGAlertSheet showMessage:error ?: @"An error occurred."
									title:title inView:me.view];
			[me loadCall];
		}];
	}];
}

- (NSDictionary *)selfSender {
	NSDictionary *participant = [[TGCallStore shared]currentGroupCallParticipant:self.groupCallId];
	if (participant[@"sender"])
		return participant[@"sender"];
	int64_t meId = [[TGProfileStore shared].me[@"id"] longLongValue];
	return @{@"@type" : @"messageSenderUser", @"user_id" : @(meId)};
}

- (void)toggleSelfMuted {
	if (!self.busy){
		self.busy = YES;
		NSDictionary *participant = [[TGCallStore shared]currentGroupCallParticipant:self.groupCallId];
		BOOL muted = [participant[@"isMutedForAllUsers"] boolValue] ||
					 [participant[@"isMutedForCurrentUser"] boolValue];
		__weak typeof(self) weakSelf = self;
		[[TGCallStore shared]toggleGroupCallParticipant:[self selfSender]
											   inCall:self.groupCallId isMuted:!muted
											completion:^(BOOL ok, NSString *error){
			TGGroupCallViewController *me = weakSelf;
			if (!me)
				return;
			me.busy = NO;
			if (!ok)
				[TGAlertSheet showMessage:error ?: @"An error occurred."
									title:@"Mute" inView:me.view];
			[me loadCall];
		}];
	}
}

- (void)toggleSelfHand {
	NSDictionary *participant = [[TGCallStore shared]currentGroupCallParticipant:self.groupCallId];
	BOOL raised = [participant[@"isHandRaised"] boolValue];
	__weak typeof(self) weakSelf = self;
	[[TGCallStore shared]toggleGroupCallParticipant:[self selfSender]
										   inCall:self.groupCallId
									 isHandRaised:!raised
									   completion:^(BOOL ok, NSString *error){
		TGGroupCallViewController *me = weakSelf;
		if (!me)
			return;
		if (!ok)
			[TGAlertSheet showMessage:error ?: @"An error occurred."
								title:nil inView:me.view];
		[me loadCall];
	}];
}

- (void)toggleSelfSpeaking {
	NSDictionary *participant = [[TGCallStore shared]currentGroupCallParticipant:self.groupCallId];
	BOOL speaking = [participant[@"isSpeaking"] boolValue];
	int32_t source = [participant[@"audioSourceId"] intValue];
	__weak typeof(self) weakSelf = self;
	[[TGCallStore shared]setGroupCallParticipantSpeaking:source inCall:self.groupCallId
											isSpeaking:!speaking
											completion:^(NSDictionary *sender, NSString *error){
		TGGroupCallViewController *me = weakSelf;
		if (!me)
			return;
		if (error.length)
			[TGAlertSheet showMessage:error title:@"Speaking" inView:me.view];
		[me loadCall];
	}];
}

- (void)toggleMyVideo {
	BOOL on = [self.call[@"isMyVideoEnabled"] boolValue];
	__weak typeof(self) weakSelf = self;
	[[TGCallStore shared]toggleGroupCallMyVideoEnabled:self.groupCallId enabled:!on
										  completion:^(BOOL ok, NSString *error){
		TGGroupCallViewController *me = weakSelf;
		if (!me)
			return;
		if (!ok)
			[TGAlertSheet showMessage:error ?: @"An error occurred."
								title:@"Video" inView:me.view];
		[me loadCall];
	}];
}

- (void)toggleMyVideoPaused {
	BOOL paused = [self.call[@"isMyVideoPaused"] boolValue];
	__weak typeof(self) weakSelf = self;
	[[TGCallStore shared]toggleGroupCallMyVideoPaused:self.groupCallId paused:!paused
										 completion:^(BOOL ok, NSString *error){
		TGGroupCallViewController *me = weakSelf;
		if (!me)
			return;
		if (!ok)
			[TGAlertSheet showMessage:error ?: @"An error occurred."
								title:@"Video" inView:me.view];
		[me loadCall];
	}];
}

- (void)startScheduled {
	__weak typeof(self) weakSelf = self;
	[[TGCallStore shared]startScheduledVideoChat:self.groupCallId
									completion:^(BOOL ok, NSString *error){
		TGGroupCallViewController *me = weakSelf;
		if (!me)
			return;
		if (!ok)
			[TGAlertSheet showMessage:error ?: @"An error occurred."
								title:@"Scheduled Video Chat" inView:me.view];
		[me loadCall];
	}];
}

#pragma mark - invitation actions

- (void)inviteMember {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Invite" message:nil
				placeholder:@"123456789" text:nil action:@"Invite"
					 inView:self.view onSubmit:^(NSString *text){
		TGGroupCallViewController *me = weakSelf;
		if (!me)
			return;
		int64_t userId = text.longLongValue;
		if (userId <= 0)
			return;
		if ([me.call[@"isVideoChat"] boolValue]){
			[[TGCallStore shared]inviteVideoChatParticipants:@[@(userId)]
					toCall:me.groupCallId completion:^(BOOL ok, NSString *error){
				[me reportInvite:ok error:error];
			}];
		} else {
			[[TGCallStore shared]inviteGroupCallParticipant:userId toCall:me.groupCallId
					isVideo:NO completion:^(NSDictionary *answer, NSString *error){
				NSString *outcome = answer[@"outcome"];
				NSString *sentence = error;
				if (!sentence.length){
					sentence = [outcome isEqualToString:@"success"] ? @"Invited."
							: [outcome isEqualToString:@"privacy"] ? @"Their privacy settings refused it."
							: [outcome isEqualToString:@"already"] ? @"They are already in the call."
							: @"They were banned from this call.";
				}
				[TGAlertSheet showMessage:sentence title:@"Invite" inView:me.view];
				[me loadCall];
			}];
		}
	}];
}

- (void)reportInvite:(BOOL)ok error:(NSString *)error {
	if (!ok)
		[TGAlertSheet showMessage:error ?: @"An error occurred."
							title:@"Invite" inView:self.view];
	else
		[TGAlertSheet showMessage:@"Done" title:@"Invite" inView:self.view];
	[self loadCall];
}

- (void)copyInviteLink {
	NSString *link = self.call[@"inviteLink"];
	__weak typeof(self) weakSelf = self;
	[[TGCallStore shared]videoChatInviteLink:self.groupCallId canSelfUnmute:YES
								completion:^(NSString *url, NSString *error){
		TGGroupCallViewController *me = weakSelf;
		if (!me)
			return;
		NSString *copy = url.length ? url : link;
		if (!copy.length){
			[TGAlertSheet showMessage:error ?: @"An error occurred."
								title:@"Invite Link" inView:me.view];
			return;
		}
		[UIPasteboard generalPasteboard].string = copy;
		[TGAlertSheet showMessage:copy title:@"Link copied." inView:me.view];
	}];
}

#pragma mark - tools

- (void)openParticipants {
	TGGroupCallParticipantsViewController *screen =
			[[TGGroupCallParticipantsViewController alloc] initWithChatId:self.chatId
															 groupCallId:self.groupCallId];
	screen.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:screen animated:YES];
}

- (void)openSetup {
	TGVideoChatSetupViewController *screen =
			[[TGVideoChatSetupViewController alloc] initWithChatId:self.chatId
													   groupCallId:self.groupCallId];
	screen.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:screen animated:YES];
}

- (void)openMessages {
	TGCallMessagesViewController *screen =
			[[TGCallMessagesViewController alloc] initWithChatId:self.chatId
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
