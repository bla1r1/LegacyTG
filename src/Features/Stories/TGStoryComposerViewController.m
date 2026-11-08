#import "TGStoryComposerViewController.h"
#import "TGStoryCameraViewController.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGLocalization.h"

/// Telegram accepts a 1080x1920 photo and a 720x1280 video. This client only
/// re-sizes the photo; a picked video is sent as recorded.
static const CGFloat kStoryPhotoWidth = 1080.0f;
static const CGFloat kStoryPhotoHeight = 1920.0f;
static const NSInteger kStorySectionChoices = 0;
static const NSInteger kStorySectionOptions = 1;
static const NSInteger kStorySectionPublish = 2;
/// POST STORY AS carries only the poster; WHO CAN VIEW THIS STORY carries the
/// privacy controls: privacy, expiry, profile, saving and albums.
static const NSInteger kStoryChoiceRows = 1;
static const NSInteger kStoryViewRows = 5;
/// Only 24 hours is free; the other three periods are Premium.
static const NSInteger kStoryFreePeriod = 86400;

/// What to tell somebody Telegram would not let post. TDLib's own wording for
/// "premium needed" talks about posting *more* stories, which is not what an
/// account that has never had Premium needs to hear.
static NSString *TGStoryRefusalText(NSDictionary *answer) {
	if ([answer[@"type"] isEqualToString:@"canPostStoryResultPremiumNeeded"])
		return @"Premium Needed";
	NSString *reason = answer[@"reason"];
	return reason.length ? reason : @"An error occurred.";
}

static BOOL TGStoryAccountHasPremium(void) {
	return [[TGClient shared].me[@"is_premium"] boolValue];
}

/// Opens at most one flow at a time: the answer from Telegram takes a moment,
/// and a second tap on the plus would otherwise stack a second camera.
static BOOL sStoryFlowOpening = NO;

@interface TGStoryComposerViewController ()
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, copy) NSString *posterTitle;
@property (nonatomic, assign) int64_t targetChatId;
@property (nonatomic, copy) NSString *targetTitle;
@property (nonatomic, strong) NSArray *postChats;
@property (nonatomic, copy) NSString *mediaPath;
@property (nonatomic, assign) BOOL isVideo;
@property (nonatomic, assign) double videoDuration;
@property (nonatomic, copy) NSString *caption;
@property (nonatomic, copy) NSString *privacy;
@property (nonatomic, strong) NSArray *privacyUserIds;
@property (nonatomic, assign) NSInteger activePeriod;
@property (nonatomic, assign) BOOL postedToChatPage;
@property (nonatomic, assign) BOOL protectContent;
@property (nonatomic, strong) NSArray *albumIds;
@property (nonatomic, assign) BOOL posting;
@end

@implementation TGStoryComposerViewController

- (instancetype)initWithChatId:(int64_t)chatId title:(NSString *)title {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self){
		_chatId = chatId;
		_posterTitle = [title copy] ?: @"Your story";
		_targetChatId = chatId;
		_targetTitle = [_posterTitle copy];
		_privacy = @"everyone";
		_privacyUserIds = @[];
		_activePeriod = 86400;
		_albumIds = @[];
	}
	return self;
}

+ (void)openFromController:(UIViewController *)controller
					chatId:(int64_t)chatId
					 title:(NSString *)title
				  onPosted:(void (^)(void))onPosted {
	if (!controller || sStoryFlowOpening)
		return;
	sStoryFlowOpening = YES;
	__weak UIViewController *weakController = controller;
	[[TGClient shared] canPostStoryInChat:chatId completion:^(NSDictionary *answer){
		sStoryFlowOpening = NO;
		UIViewController *host = weakController;
		if (!host)
			return;
		if (![answer[@"ok"] boolValue]){
			[TGAlertSheet showMessage:TGStoryRefusalText(answer)
								title:@"New Story" inView:host.view];
			return;
		}
		TGStoryComposerViewController *composer = [[TGStoryComposerViewController alloc]
				initWithChatId:chatId title:title];
		composer.onPosted = onPosted;
		// The caller may itself be sitting under a modal (the story viewer is).
		UIViewController *top = host;
		while (top.presentedViewController)
			top = top.presentedViewController;
		[top presentViewController:[TGStoryCameraViewController flowForComposer:composer]
						  animated:YES completion:nil];
	}];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Story";
	[[TGTheme shared] styleGroupedTable:self.tableView];

	__weak typeof(self) weakSelf = self;
	// postStory returns while the upload is still running, so the server's
	// final word arrives here. Only the post this screen started matters;
	// once the request has already answered the completion below has said it.
	[[NSNotificationCenter defaultCenter] addObserverForName:TGStoryPostFinishedNotification
			object:nil queue:[NSOperationQueue mainQueue]
		 usingBlock:^(NSNotification *note){
		TGStoryComposerViewController *me = weakSelf;
		if (!me || !me.posting)
			return;
		if ([note.userInfo[@"chatId"] longLongValue] != me.targetChatId)
			return;
		me.posting = NO;
		[me.tableView reloadData];
		if ([note.userInfo[@"ok"] boolValue]){
			if (me.onPosted)
				me.onPosted();
			[me closeFlow];
		} else {
			[TGAlertSheet showMessage:note.userInfo[@"error"]
								?: @"An error occurred."
								title:@"New Story" inView:me.view];
		}
	}];
	[self loadPostChats];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	// The camera and editor before this hide both the bar and the status bar.
	TGStoryFlowSetStatusBarHidden(NO);
	// Official keeps Done/Next inside the editor and has no bar of its own on
	// the publish sheet; Cancel is one of the rows below.
	[self.navigationController setNavigationBarHidden:YES animated:NO];
}

/// Chats this account may post on behalf of. The own story is always first:
/// a channel that is not in the answer yet must not hide it.
- (void)loadPostChats {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] chatsToPostStoriesWithCompletion:^(NSArray *chats){
		TGStoryComposerViewController *me = weakSelf;
		if (!me)
			return;
		me.postChats = chats ?: @[];
		[me.tableView reloadData];
	}];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == kStorySectionChoices)
		return kStoryChoiceRows;
	if (section == kStorySectionOptions)
		return kStoryViewRows;
	return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == kStorySectionChoices)
		return @"POST STORY AS";
	if (section == kStorySectionOptions)
		return @"WHO CAN VIEW THIS STORY";
	return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return TGMetricRow;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSString *identifier = [NSString stringWithFormat:@"story-%ld-%ld",
			(long)indexPath.section, (long)indexPath.row];
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:identifier];
	[[TGTheme shared] styleCell:cell];
	cell.accessoryView = nil;
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	cell.textLabel.textColor = [[TGTheme shared] primaryTextColour];
	cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];
	cell.textLabel.font = TGFontBody();
	cell.detailTextLabel.font = TGFontSubhead();

	if (indexPath.section == kStorySectionPublish){
		if (indexPath.row == 0){
			cell.textLabel.text = self.posting ? @"Uploading..." : @"Post Story";
			cell.textLabel.textColor = [[TGTheme shared] accentColour];
			cell.detailTextLabel.text = @"";
			cell.selectionStyle = self.mediaPath && !self.posting
					? UITableViewCellSelectionStyleBlue
					: UITableViewCellSelectionStyleNone;
		} else {
			cell.textLabel.text = @"Cancel";
			cell.textLabel.textColor = [[TGTheme shared] destructiveColour];
		}
		return cell;
	}

	if (indexPath.section == kStorySectionOptions){
		if (indexPath.row == 2 || indexPath.row == 3){
			UISwitch *toggle = [[UISwitch alloc] init];
			toggle.on = indexPath.row == 2 ? self.postedToChatPage : self.protectContent;
			toggle.tag = indexPath.row;
			[toggle addTarget:self action:@selector(toggleChanged:)
			 forControlEvents:UIControlEventValueChanged];
			cell.textLabel.text = indexPath.row == 2
					? @"Add to Profile" : @"Restrict Saving Content";
			cell.accessoryView = toggle;
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
			return cell;
		}
		if (indexPath.row == 0){
			cell.textLabel.text = @"Privacy";
			cell.detailTextLabel.text = [self privacyTitle];
			cell.accessoryType = UITableViewCellAccessoryNone;
			return cell;
		}
		if (indexPath.row == 1){
			cell.textLabel.text = TGLocalizedFormat(@"Expires in %@",
					[self activePeriodTitle]);
			cell.detailTextLabel.text = @"";
			cell.accessoryType = UITableViewCellAccessoryNone;
			return cell;
		}
		cell.textLabel.text = @"Albums";
		cell.detailTextLabel.text = self.albumIds.count
				? [self.albumIds componentsJoinedByString:@", "] : @"None";
		cell.accessoryType = UITableViewCellAccessoryNone;
		return cell;
	}

	// POST STORY AS: the account the story is posted as.
	cell.textLabel.text = @"Post Story As";
	cell.detailTextLabel.text = self.targetTitle ?: @"My Story";
	cell.accessoryType = UITableViewCellAccessoryNone;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.section == kStorySectionPublish){
		if (indexPath.row == 0)
			[self postStory];
		else
			[self closeFlow];
		return;
	}
	if (indexPath.section == kStorySectionChoices){
		[self chooseTargetChat];
		return;
	}
	// Index 2 and 3 are the switches; the table does not select them.
	if (indexPath.row == 0){
		[self choosePrivacy];
		return;
	}
	if (indexPath.row == 1){
		[self chooseActivePeriod];
		return;
	}
	if (indexPath.row != 4)
		return;
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Albums"
					message:nil
				placeholder:@"12, 15"
					   text:[self.albumIds componentsJoinedByString:@", "]
					 action:@"Save"
					 inView:self.view
				   onSubmit:^(NSString *text){
		TGStoryComposerViewController *me = weakSelf;
		if (!me)
			return;
		NSMutableArray *ids = [NSMutableArray array];
		for (NSString *part in [text componentsSeparatedByString:@","]){
			NSString *trimmed = [part stringByTrimmingCharactersInSet:
					[NSCharacterSet whitespaceCharacterSet]];
			if (trimmed.integerValue > 0)
				[ids addObject:@(trimmed.integerValue)];
		}
		me.albumIds = ids;
		[me.tableView reloadData];
	}];
}

#pragma mark - choices

- (void)choosePrivacy {
	NSArray *choices = @[@"Everybody", @"My Contacts", @"Close Friends", @"Selected Users"];
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:choices title:@"Who Can See"
				destructiveIndex:-1 inView:self.view onChoice:^(NSInteger choice){
		TGStoryComposerViewController *me = weakSelf;
		if (!me)
			return;
		if (choice == 0){
			me.privacy = @"everyone";
			me.privacyUserIds = @[];
		} else if (choice == 1){
			me.privacy = @"contacts";
			me.privacyUserIds = @[];
		} else if (choice == 2){
			me.privacy = @"closeFriends";
			me.privacyUserIds = @[];
		} else {
			[TGAlertSheet showInput:@"Selected Users"
							message:nil
						placeholder:@"123, 456"
							   text:nil
							 action:@"Save"
							 inView:me.view
						 onSubmit:^(NSString *text){
				NSMutableArray *ids = [NSMutableArray array];
				for (NSString *part in [text componentsSeparatedByString:@","]){
					NSString *trimmed = [part stringByTrimmingCharactersInSet:
							[NSCharacterSet whitespaceCharacterSet]];
					if (trimmed.longLongValue > 0)
						[ids addObject:@(trimmed.longLongValue)];
				}
				me.privacy = @"selected";
				me.privacyUserIds = ids;
				[me.tableView reloadData];
			}];
			return;
		}
		[me.tableView reloadData];
	}];
}

- (void)chooseActivePeriod {
	// The four periods are pack strings, not literal English hours.
	NSArray *choices = @[
		TGLocalizedFormat(@"%d Hours", (int)6),
		TGLocalizedFormat(@"%d Hours", (int)12),
		TGLocalizedFormat(@"%d Hours", (int)24),
		TGLocalizedFormat(@"%d Hours", (int)48)
	];
	NSArray *values = @[@21600, @43200, @86400, @172800];
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:choices title:@"Duration" destructiveIndex:-1
					   inView:self.view onChoice:^(NSInteger choice){
		TGStoryComposerViewController *me = weakSelf;
		if (!me || choice < 0 || choice >= (NSInteger)values.count)
			return;
		NSInteger period = [values[choice] integerValue];
		if (period != kStoryFreePeriod && !TGStoryAccountHasPremium()){
			[TGAlertSheet showMessage:@"Premium Needed"
								title:@"Duration" inView:me.view];
			return;
		}
		me.activePeriod = period;
		[me.tableView reloadData];
	}];
}

- (void)chooseTargetChat {
	NSMutableArray *titles = [NSMutableArray arrayWithObject:@"My Story"];
	NSMutableArray *ids = [NSMutableArray arrayWithObject:@(self.chatId)];
	for (NSDictionary *chat in self.postChats){
		NSNumber *chatId = chat[@"id"];
		if (![chatId isKindOfClass:NSNumber.class] || [chatId isEqualToNumber:@(self.chatId)])
			continue;
		[titles addObject:chat[@"title"] ?: @"Chat"];
		[ids addObject:chatId];
	}
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:titles title:@"Post Story As" destructiveIndex:-1
					   inView:self.view onChoice:^(NSInteger choice){
		TGStoryComposerViewController *me = weakSelf;
		if (!me || choice < 0 || choice >= (NSInteger)ids.count)
			return;
		me.targetChatId = [ids[choice] longLongValue];
		me.targetTitle = titles[choice];
		[me.tableView reloadData];
	}];
}

- (NSString *)privacyTitle {
	if ([self.privacy isEqualToString:@"contacts"]) return @"My Contacts";
	if ([self.privacy isEqualToString:@"closeFriends"]) return @"Close Friends";
	if ([self.privacy isEqualToString:@"selected"])
		return TGLocalizedFormat(@"%d Selected",
				(int)self.privacyUserIds.count);
	return @"Everybody";
}

- (NSString *)activePeriodTitle {
	if (self.activePeriod == 21600) return TGLocalizedFormat(@"%d Hours", (int)6);
	if (self.activePeriod == 43200) return TGLocalizedFormat(@"%d Hours", (int)12);
	if (self.activePeriod == 172800) return TGLocalizedFormat(@"%d Hours", (int)48);
	return TGLocalizedFormat(@"%d Hours", (int)24);
}

#pragma mark - what the earlier steps hand over

- (void)useMediaAtPath:(NSString *)path
			   isVideo:(BOOL)isVideo
			  duration:(double)duration
			   caption:(NSString *)caption {
	self.mediaPath = path;
	self.isVideo = isVideo;
	self.videoDuration = duration;
	self.caption = caption;
}

- (void)toggleChanged:(UISwitch *)toggle {
	// The switches sit at rows 2 and 3 of the WHO CAN VIEW section.
	if (toggle.tag == 2)
		self.postedToChatPage = toggle.on;
	else if (toggle.tag == 3)
		self.protectContent = toggle.on;
}

/// Telegram wants a 1080x1920 JPEG. Scaling here, not on the server, keeps a
/// 4S from uploading a 5 MP picture Telegram would reject or crop.
- (NSString *)writeStoryPhoto:(UIImage *)image {
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(kStoryPhotoWidth,
			kStoryPhotoHeight), YES, 1);
	[[UIColor blackColor] setFill];  // export/letterbox
	UIRectFill(CGRectMake(0, 0, kStoryPhotoWidth, kStoryPhotoHeight));
	CGFloat scale = MIN(kStoryPhotoWidth / image.size.width,
						kStoryPhotoHeight / image.size.height);
	CGFloat width = image.size.width * scale;
	CGFloat height = image.size.height * scale;
	CGRect target = CGRectMake(TGHalf(kStoryPhotoWidth - width),
							   TGHalf(kStoryPhotoHeight - height),
							   width, height);
	[image drawInRect:target];
	UIImage *scaled = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	NSData *jpeg = UIImageJPEGRepresentation(scaled, 0.9);
	if (!jpeg.length)
		return nil;
	NSString *path = [NSTemporaryDirectory()
			stringByAppendingPathComponent:@"tg-story.jpg"];
	return [jpeg writeToFile:path atomically:YES] ? path : nil;
}

#pragma mark - posting

- (void)postStory {
	if (self.posting)
		return;
	if (!self.mediaPath.length){
		[TGAlertSheet showMessage:@"An error occurred."
							title:@"New Story" inView:self.view];
		return;
	}
	self.posting = YES;
	[self.tableView reloadData];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] canPostStoryInChat:self.targetChatId
							   completion:^(NSDictionary *answer){
		TGStoryComposerViewController *me = weakSelf;
		if (!me || !me.posting)
			return;
		if (![answer[@"ok"] boolValue]){
			me.posting = NO;
			[me.tableView reloadData];
			[TGAlertSheet showMessage:TGStoryRefusalText(answer)
								title:@"New Story" inView:me.view];
			return;
		}
		[[TGClient shared] postStoryToChat:me.targetChatId
									  path:me.mediaPath
								   isVideo:me.isVideo
								  duration:me.videoDuration
								   caption:me.caption ?: @""
								   privacy:me.privacy
								   userIds:me.privacyUserIds
							 activePeriod:me.activePeriod
						  postedToChatPage:me.postedToChatPage
							protectContent:me.protectContent
								  albumIds:me.albumIds
								completion:^(NSDictionary *story, NSString *error){
			if (!me.posting)
				return;
			me.posting = NO;
			[me.tableView reloadData];
			if (!story){
				[TGAlertSheet showMessage:error ?: @"An error occurred."
									title:@"New Story" inView:me.view];
				return;
			}
			if (me.onPosted)
				me.onPosted();
			[me closeFlow];
		}];
	}];
}

/// Dismisses camera, editor and this table together; they are one modal.
- (void)closeFlow {
	[self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

@end
