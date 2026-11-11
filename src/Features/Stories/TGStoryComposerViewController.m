#import "TGStoryComposerViewController.h"
#import "TGStoryCameraViewController.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGLocalization.h"
#import "TGRows.h"
#import "TGProfileStore.h"
#import "TGStoryStore.h"

/// Telegram accepts a 1080x1920 photo and a 720x1280 video. This client only
/// re-sizes the photo; a picked video is sent as recorded.
static const CGFloat kStoryPhotoWidth = 1080.0f;
static const CGFloat kStoryPhotoHeight = 1920.0f;
/// POST STORY AS carries only the poster; WHO CAN VIEW THIS STORY carries the
/// privacy controls: privacy, expiry, profile, saving and albums.
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
	return [[TGProfileStore shared].me[@"is_premium"] boolValue];
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
	self = [super init];
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
	[[TGStoryStore shared]canPostStoryInChat:chatId completion:^(NSDictionary *answer){
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
	[self rebuildSections];

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
		[me rebuildSections];
		[me reloadRows];
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
	[[TGStoryStore shared]chatsToPostStoriesWithCompletion:^(NSArray *chats){
		TGStoryComposerViewController *me = weakSelf;
		if (!me)
			return;
		me.postChats = chats ?: @[];
		[me rebuildSections];
		[me reloadRows];
	}];
}

#pragma mark - rows

- (void)rebuildSections {
	__weak typeof(self) weakSelf = self;
	NSMutableArray *sections = [NSMutableArray array];

	NSMutableDictionary *target = [TGTapRow(@"Post Story As",
			self.targetTitle ?: @"My Story", ^{
		[weakSelf chooseTargetChat];
	}) mutableCopy];
	[sections addObject:TGSection(@"POST STORY AS", nil, @[target])];

	NSMutableArray *viewRows = [NSMutableArray array];
	[viewRows addObject:[TGTapRow(@"Privacy", [self privacyTitle], ^{
		[weakSelf choosePrivacy];
	}) mutableCopy]];
	[viewRows addObject:[TGTapRow(TGLocalizedFormat(@"Expires in %@",
			[self activePeriodTitle]), nil, ^{
		[weakSelf chooseActivePeriod];
	}) mutableCopy]];
	[viewRows addObject:TGSwitchRow(@"Add to Profile", self.postedToChatPage,
			^(BOOL on){
		weakSelf.postedToChatPage = on;
	})];
	[viewRows addObject:TGSwitchRow(@"Restrict Saving Content", self.protectContent,
			^(BOOL on){
		weakSelf.protectContent = on;
	})];
	NSString *albums = self.albumIds.count
			? [self.albumIds componentsJoinedByString:@", "] : @"None";
	[viewRows addObject:[TGTapRow(@"Albums", albums, ^{
		[weakSelf chooseAlbums];
	}) mutableCopy]];
	[sections addObject:TGSection(@"WHO CAN VIEW THIS STORY", nil, viewRows)];

	NSMutableArray *publishRows = [NSMutableArray array];
	NSString *postTitle = self.posting ? @"Uploading..." : @"Post Story";
	if (self.posting){
		[publishRows addObject:TGRow(TGKindAction, postTitle)];
	} else {
		[publishRows addObject:TGActionRow(postTitle, ^{
			[weakSelf postStory];
		})];
	}
	[publishRows addObject:TGRedRow(@"Cancel", ^{
		[weakSelf closeFlow];
	})];
	[sections addObject:TGSection(nil, nil, publishRows)];

	self.sections = sections;
}

#pragma mark - choices

- (void)chooseAlbums {
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
		[me rebuildSections];
		[me reloadRows];
	}];
}

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
				[me rebuildSections];
				[me reloadRows];
			}];
			return;
		}
		[me rebuildSections];
		[me reloadRows];
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
		[me rebuildSections];
		[me reloadRows];
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
		[me rebuildSections];
		[me reloadRows];
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
	[self rebuildSections];
	[self reloadRows];
	__weak typeof(self) weakSelf = self;
	[[TGStoryStore shared]canPostStoryInChat:self.targetChatId
							   completion:^(NSDictionary *answer){
		TGStoryComposerViewController *me = weakSelf;
		if (!me || !me.posting)
			return;
		if (![answer[@"ok"] boolValue]){
			me.posting = NO;
			[me rebuildSections];
			[me reloadRows];
			[TGAlertSheet showMessage:TGStoryRefusalText(answer)
								title:@"New Story" inView:me.view];
			return;
		}
		[[TGStoryStore shared]postStoryToChat:me.targetChatId
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
			[me rebuildSections];
			[me reloadRows];
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
