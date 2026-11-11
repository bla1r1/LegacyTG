#import "TGStoryViewerViewController.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGIcons.h"
#import "TGPeerStore.h"
#import "TGStoryInfoViewController.h"
#import "TGStoryAlbumsViewController.h"
#import "TGStoryComposerViewController.h"
#import "TGStorySave.h"
#import "TGLiveStoryViewController.h"
#import "TGMessageLayout.h"
#import "TGPopupMenu.h"
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import "TGMediaStore.h"
#import "TGProfileStore.h"
#import "TGStoryStore.h"

/// How long a still story stays up. Videos use their own duration when TDLib
/// knows it; a story without a duration falls back to the same five seconds.
static const NSTimeInterval kStoryStillSeconds = 5.0;
/// The progress bars repaint twenty times a second: smooth on a 4S, and less
/// than a frame a tick on a 3GS.
static const NSTimeInterval kStoryTick = 0.05;
static const NSInteger kStoryReactionChoices = 6;

/// A story's timestamp as the header says it. The old "%@m" read as metres
/// once the pack translated it; these are the pack's time templates.
static NSString *TGStoryRelativeTime(NSTimeInterval timestamp) {
	if (timestamp <= 0)
		return @"";
	NSTimeInterval age = [[NSDate date] timeIntervalSince1970] - timestamp;
	if (age < 60)
		return TGLocalized(@"now");
	if (age < 3600)
		return TGLocalizedFormat(@"%@ minutes ago", @(age / 60));
	if (age < 86400)
		return TGLocalizedFormat(@"%@ hours ago", @(age / 3600));
	return TGLocalizedFormat(@"%@ days ago", @(age / 86400));
}

@interface TGStoryViewerViewController () <UIGestureRecognizerDelegate>
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, copy) NSString *storyTitle;
@property (nonatomic, strong) NSMutableArray *stories;
@property (nonatomic, assign) NSInteger index;
@property (nonatomic, assign) BOOL canManage;
@property (nonatomic, strong) UIView *progressHost;
@property (nonatomic, strong) NSMutableArray *progressFills;
@property (nonatomic, strong) UIImageView *picture;
@property (nonatomic, strong) UIView *topShade;
@property (nonatomic, strong) UIView *bottomShade;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) UILabel *senderLabel;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UIImageView *authorAvatar;
@property (nonatomic, strong) UIButton *infoButton;
@property (nonatomic, strong) UILabel *captionLabel;
@property (nonatomic, strong) UILabel *infoLabel;
@property (nonatomic, strong) UIActivityIndicatorView *loadingView;
/// The still gradient the official loading effect draws behind a story while
/// its picture downloads; no blur or animation on the A4.
@property (nonatomic, strong) UIView *loadingEffect;
@property (nonatomic, strong) UIView *reactionRail;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) NSTimeInterval elapsed;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, assign) BOOL paused;
@property (nonatomic, assign) CGPoint dragStart;
@property (nonatomic, strong) NSArray *reactionEmojis;
@property (nonatomic, assign) BOOL closed;
/// The peer's public address, needed to gate Copy Link: only a public story
/// on a peer with an address has a link to copy.
@property (nonatomic, copy) NSString *peerAddress;
@end

@implementation TGStoryViewerViewController

- (instancetype)initWithChatId:(int64_t)chatId
						title:(NSString *)title
					   stories:(NSArray *)stories
					startIndex:(NSInteger)startIndex
					  canManage:(BOOL)canManage {
	self = [super initWithNibName:nil bundle:nil];
	if (self){
		_chatId = chatId;
		_storyTitle = [title copy];
		_stories = [stories mutableCopy] ?: [NSMutableArray array];
		_index = MAX(0, MIN(startIndex, (NSInteger)_stories.count - 1));
		_canManage = canManage;
		_progressFills = [NSMutableArray array];
		self.wantsFullScreenLayout = YES;
		self.hidesBottomBarWhenPushed = YES;
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.view.backgroundColor = [[TGTheme shared] mediaViewerBackdropColour];

	_picture = [[UIImageView alloc] initWithFrame:self.view.bounds];
	_picture.contentMode = UIViewContentModeScaleAspectFit;
	_picture.backgroundColor = [UIColor clearColor];
	[self.view addSubview:_picture];

	_topShade = [self shadeViewFromTop:YES];
	_bottomShade = [self shadeViewFromTop:NO];
	[self.view addSubview:_topShade];
	[self.view addSubview:_bottomShade];

	_progressHost = [[UIView alloc] initWithFrame:CGRectZero];
	_progressHost.backgroundColor = [UIColor clearColor];
	[self.view addSubview:_progressHost];

	_senderLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_senderLabel.font = TGFontSubheadStrong();
	_senderLabel.textColor = [[TGTheme shared] onMediaColour];
	_senderLabel.backgroundColor = [UIColor clearColor];
	_senderLabel.lineBreakMode = NSLineBreakByTruncatingTail;
	[self.view addSubview:_senderLabel];

	_timeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_timeLabel.font = TGFontMicro();
	_timeLabel.textColor = [[TGTheme shared] secondaryTextColour];
	_timeLabel.backgroundColor = [UIColor clearColor];
	[self.view addSubview:_timeLabel];

	_authorAvatar = [[UIImageView alloc] initWithFrame:CGRectZero];
	_authorAvatar.contentMode = UIViewContentModeScaleAspectFill;
	_authorAvatar.clipsToBounds = YES;
	_authorAvatar.layer.cornerRadius = TGHalf(TGMetricStoryHeaderAvatar);
	_authorAvatar.backgroundColor = [[TGTheme shared] fileTileColour];
	[self.view addSubview:_authorAvatar];

	_captionLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_captionLabel.font = TGFontBody();
	_captionLabel.textColor = [[TGTheme shared] onMediaColour];
	_captionLabel.backgroundColor = [UIColor clearColor];
	_captionLabel.numberOfLines = 4;
	[self.view addSubview:_captionLabel];

	_infoLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_infoLabel.font = TGFontMeta();
	_infoLabel.textColor = [[TGTheme shared] secondaryTextColour];
	_infoLabel.backgroundColor = [UIColor clearColor];
	[self.view addSubview:_infoLabel];

	// The thumbnail takes a moment; the empty black frame read as a failed
	// story, so a spinner fills it until the picture arrives.
	_loadingEffect = [[UIView alloc] initWithFrame:self.view.bounds];
	_loadingEffect.autoresizingMask = UIViewAutoresizingFlexibleWidth |
			UIViewAutoresizingFlexibleHeight;
	CAGradientLayer *loadingGradient = [CAGradientLayer layer];
	loadingGradient.colors = @[
		(id)[[TGTheme shared] fileTileColour].CGColor,
		(id)[[TGTheme shared] mediaViewerBackdropColour].CGColor];
	loadingGradient.startPoint = CGPointMake(0.5, TGMetricZero);
	loadingGradient.endPoint = CGPointMake(0.5, TGMetricScaleFull);
	[_loadingEffect.layer addSublayer:loadingGradient];
	[self.view addSubview:_loadingEffect];

	_loadingView = [[UIActivityIndicatorView alloc]
			initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
	_loadingView.hidesWhenStopped = YES;
	_loadingView.backgroundColor = [UIColor clearColor];
	[self.view addSubview:_loadingView];

	UIButton *close = [UIButton buttonWithType:UIButtonTypeCustom];
	close.frame = CGRectMake(0, 0, TGMetricStoryCloseSide, TGMetricStoryCloseSide);
	[close setImage:[TGIcons glyphNamed:@"close" colour:[[TGTheme shared] onMediaColour]
								  side:TGMetricStoryCloseSide - TGMetricPadSmall]
		   forState:UIControlStateNormal];
	[close addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:close];
	close.tag = 9001;

	UIButton *menu = [UIButton buttonWithType:UIButtonTypeCustom];
	menu.frame = CGRectMake(0, 0, TGMetricStoryCloseSide, TGMetricStoryCloseSide);
	[menu setImage:[TGIcons glyphNamed:@"more" colour:[[TGTheme shared] onMediaColour]
								 side:TGMetricStoryCloseSide - TGMetricPadSmall]
		  forState:UIControlStateNormal];
	[menu addTarget:self action:@selector(menuTapped) forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:menu];
	menu.tag = 9002;

	// The views line under the picture is a button: it is where the viewer
	// list and the story's counters live, and Telegram makes it open them.
	_infoButton = [UIButton buttonWithType:UIButtonTypeCustom];
	_infoButton.backgroundColor = [UIColor clearColor];
	[_infoButton addTarget:self action:@selector(openInfo)
		  forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:_infoButton];

	// A flick down puts the story away and goes back where it came from.
	UIPanGestureRecognizer *drag = [[UIPanGestureRecognizer alloc]
			initWithTarget:self action:@selector(storyDragged:)];
	drag.delegate = self;
	[self.view addGestureRecognizer:drag];

	UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
			initWithTarget:self action:@selector(tapAt:)];
	tap.delegate = self;
	[self.view addGestureRecognizer:tap];

	UILongPressGestureRecognizer *hold = [[UILongPressGestureRecognizer alloc]
			initWithTarget:self action:@selector(held:)];
	hold.minimumPressDuration = 0.18;
	[self.view addGestureRecognizer:hold];

	[self.view bringSubviewToFront:close];
	[self.view bringSubviewToFront:menu];
	[self.view bringSubviewToFront:_infoButton];

	// A story edited or deleted on another client arrives while this viewer
	// is open. The row handles its own copy; here the story id decides
	// whether the picture on screen or the count behind it moved.
	__weak typeof(self) weakSelf = self;
	[[NSNotificationCenter defaultCenter] addObserverForName:TGStoriesChangedNotification
			object:nil queue:[NSOperationQueue mainQueue]
		usingBlock:^(NSNotification *note){
		TGStoryViewerViewController *me = weakSelf;
		if (!me || me.closed)
			return;
		if ([note.userInfo[@"chatId"] longLongValue] != me.chatId)
			return;
		NSDictionary *story = note.userInfo[@"story"];
		if ([story isKindOfClass:NSDictionary.class]){
			NSInteger at = [me indexOfStoryId:[story[@"storyId"] intValue]];
			if (at < 0){
				[me.stories addObject:story];
				at = (NSInteger)me.stories.count - 1;
			} else {
				me.stories[at] = story;
			}
			if (at == me.index)
				[me showCurrentStory];
			return;
		}
		NSNumber *deleted = note.userInfo[@"deletedStoryId"];
		if (![deleted isKindOfClass:NSNumber.class])
			return;
		NSInteger at = [me indexOfStoryId:deleted.intValue];
		if (at < 0)
			return;
		[me.stories removeObjectAtIndex:at];
		if (!me.stories.count){
			[me finish];
			return;
		}
		if (at < me.index)
			me.index--;
		else if (at == me.index)
			me.index = MIN(me.index, (NSInteger)me.stories.count - 1);
		[me showCurrentStory];
	}];

	__weak typeof(self) weakViewer = self;
	[[TGProfileStore shared]chatRecordForChat:self.chatId completion:^(NSDictionary *chat){
		NSDictionary *type = [chat[@"type"] isKindOfClass:NSDictionary.class]
				? chat[@"type"] : nil;
		NSArray *names = type[@"supergroup"][@"usernames"][@"active_usernames"];
		if (![names isKindOfClass:NSArray.class] || !names.count)
			names = type[@"private"][@"usernames"][@"active_usernames"];
		if (![names isKindOfClass:NSArray.class] || !names.count){
			NSString *single = type[@"private"][@"username"];
			if ([single isKindOfClass:NSString.class] && single.length)
				names = @[single];
		}
		NSString *address = [names isKindOfClass:NSArray.class]
				? names.firstObject : nil;
		if ([address isKindOfClass:NSString.class] && address.length)
			weakViewer.peerAddress = address;
	}];

	[self loadReactions];
	[self showCurrentStory];
}

- (NSInteger)indexOfStoryId:(int32_t)storyId {
	for (NSInteger i = 0; i < (NSInteger)self.stories.count; i++){
		id entry = self.stories[i];
		if ([entry isKindOfClass:NSDictionary.class] &&
			[entry[@"storyId"] intValue] == storyId)
			return i;
		if ([entry isKindOfClass:NSNumber.class] && [entry intValue] == storyId)
			return i;
	}
	return -1;
}

- (UIView *)shadeViewFromTop:(BOOL)top {
	UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
	view.userInteractionEnabled = NO;
	view.backgroundColor = [UIColor clearColor];
	CAGradientLayer *gradient = [CAGradientLayer layer];
	gradient.colors = @[(id)[[TGTheme shared] scrimColour].CGColor,
						(id)[UIColor clearColor].CGColor];
	gradient.startPoint = CGPointMake(0.5,
									  top ? TGMetricZero : TGMetricScaleFull);
	gradient.endPoint = CGPointMake(0.5,
									top ? TGMetricScaleFull : TGMetricZero);
	[view.layer addSublayer:gradient];
	return view;
}

- (void)layoutShade:(UIView *)shade {
	for (CALayer *layer in shade.layer.sublayers)
		if ([layer isKindOfClass:CAGradientLayer.class])
			layer.frame = shade.bounds;
}

- (void)viewWillLayoutSubviews {
	[super viewWillLayoutSubviews];
	CGFloat width = self.view.bounds.size.width;
	CGFloat height = self.view.bounds.size.height;
	_picture.frame = self.view.bounds;
	_loadingEffect.frame = self.view.bounds;
	for (CALayer *layer in _loadingEffect.layer.sublayers)
		if ([layer isKindOfClass:CAGradientLayer.class])
			layer.frame = _loadingEffect.bounds;
	_loadingView.center = CGPointMake(CGRectGetMidX(self.view.bounds),
			CGRectGetMidY(self.view.bounds));
	self.topShade.frame = CGRectMake(0, 0, width, TGMetricStoryShadeTop);
	self.bottomShade.frame = CGRectMake(0, height - TGMetricStoryShadeBottom,
										width, TGMetricStoryShadeBottom);
	[self layoutShade:self.topShade];
	[self layoutShade:self.bottomShade];
	if (_playerLayer)
		_playerLayer.frame = _picture.bounds;

	CGFloat top = TGMetricStoryProgressTop;
	CGFloat side = TGMetricStoryCloseSide + TGMetricStoryCloseInset;
	self.progressHost.frame = CGRectMake(TGMetricStoryProgressGap, top,
			width - TGDoubled(TGMetricStoryProgressGap),
			TGMetricStoryProgressHeight);
	UIView *close = [self.view viewWithTag:9001];
	UIView *menu = [self.view viewWithTag:9002];
	CGFloat headerY = top + TGMetricStoryProgressHeight + TGMetricPadSmall;
	if (close)
		close.frame = CGRectMake(width - side - TGMetricStoryCloseSide, headerY,
								 TGMetricStoryCloseSide, TGMetricStoryCloseSide);
	if (menu)
		menu.frame = CGRectMake(CGRectGetMinX(close.frame) -
								TGMetricStoryHeaderGap - TGMetricStoryCloseSide,
								headerY, TGMetricStoryCloseSide,
								TGMetricStoryCloseSide);
	_authorAvatar.frame = CGRectMake(side,
			headerY + TGCenteredOrigin(TGMetricStoryCloseSide,
									   TGMetricStoryHeaderAvatar),
			TGMetricStoryHeaderAvatar, TGMetricStoryHeaderAvatar);
	CGFloat nameX = CGRectGetMaxX(_authorAvatar.frame) + TGMetricStoryHeaderGap;
	CGFloat nameW = CGRectGetMinX(menu.frame) - nameX - TGMetricStoryHeaderGap;
	if (nameW < 0)
		nameW = 0;
	_senderLabel.frame = CGRectMake(nameX, headerY, nameW,
			TGMetricStoryViewerNameHeight);
	_timeLabel.frame = CGRectMake(nameX, CGRectGetMaxY(_senderLabel.frame),
			nameW, TGMetricLineMicro);
	_captionLabel.frame = CGRectMake(TGMetricPadLarge,
			height - TGMetricStoryReactionRow - TGMetricStoryCaptionBottomOffset,
			width - TGDoubled(TGMetricPadLarge), TGMetricStoryCaptionHeight);
	_infoLabel.frame = CGRectMake(TGMetricPadLarge,
			height - TGMetricStoryReactionRow - TGMetricPadLarge, width -
			TGDoubled(TGMetricPadLarge), TGMetricLineCaption);
	_infoButton.frame = _infoLabel.frame;
	self.reactionRail.frame = CGRectMake(TGMetricPadLarge,
			height - TGMetricStoryReactionRow - TGMetricPadSmall,
			width - TGDoubled(TGMetricPadLarge), TGMetricStoryReactionRow);
	[self rebuildProgressBars];
}

- (void)rebuildProgressBars {
	for (UIView *old in self.progressHost.subviews)
		[old removeFromSuperview];
	[self.progressFills removeAllObjects];
	NSInteger count = MAX(1, (NSInteger)self.stories.count);
	CGFloat total = self.progressHost.bounds.size.width -
			(count - 1) * TGMetricStoryProgressGap;
	CGFloat each = total / (CGFloat)count;
	for (NSInteger i = 0; i < count; i++){
		UIView *track = [[UIView alloc] initWithFrame:CGRectMake(
				i * (each + TGMetricStoryProgressGap), 0, each,
				TGMetricStoryProgressHeight)];
		track.backgroundColor = [[TGTheme shared] scrimColour];
		track.layer.cornerRadius = TGHalf(TGMetricStoryProgressHeight);
		[track setClipsToBounds:YES];
		UIView *fill = [[UIView alloc] initWithFrame:track.bounds];
		fill.backgroundColor = [[TGTheme shared] onMediaColour];
		fill.layer.cornerRadius = TGHalf(TGMetricStoryProgressHeight);
		[track addSubview:fill];
		[self.progressHost addSubview:track];
		[self.progressFills addObject:fill];
	}
}

- (void)showCurrentStory {
	[self stopTimer];
	[self stopVideo];
	[self removePlayerLayer];
	_picture.image = nil;
	[self rebuildProgressBars];
	for (NSInteger i = 0; i < self.index && i < (NSInteger)self.progressFills.count; i++){
		UIView *fill = self.progressFills[i];
		CGRect frame = fill.frame;
		frame.size.width = fill.superview.bounds.size.width;
		fill.frame = frame;
	}
	if (self.index < 0 || self.index >= (NSInteger)self.stories.count){
		[self finish];
		return;
	}
	id entry = self.stories[self.index];
	self.senderLabel.text = self.storyTitle.length ? self.storyTitle : @"Story";
	[self refreshAuthorAvatar];
	[self updateHeaderCounterForStory:nil];
	if ([entry isKindOfClass:NSNumber.class]){
		[self loadStoryId:[entry intValue]];
		return;
	}
	[self showStory:entry];
}

- (void)refreshAuthorAvatar {
	NSString *title = self.senderLabel.text.length ? self.senderLabel.text : @"Story";
	NSString *initial = [TGIcons initialsForTitle:title];
	self.authorAvatar.image = [TGIcons avatarWithInitials:initial
												   size:TGMetricStoryHeaderAvatar
											   colourId:self.chatId];

	UIImage *cached = [[TGPeerStore shared] cachedAvatarForPeer:self.chatId
														   side:TGMetricStoryHeaderAvatar];
	if (cached){
		self.authorAvatar.image = cached;
		return;
	}
	__weak typeof(self) weakSelf = self;
	__weak UIImageView *weakAvatar = self.authorAvatar;
	[[TGPeerStore shared] loadAvatarForPeer:self.chatId
									   side:TGMetricStoryHeaderAvatar
								 completion:^(UIImage *image){
		TGStoryViewerViewController *me = weakSelf;
		if (me && !me.closed && image)
			weakAvatar.image = image;
	}];
}

/// The name and "2/5" on one line, the relative time on the next; official
/// puts the counter beside the name rather than in the time line.
- (void)updateHeaderCounterForStory:(NSDictionary *)story {
	NSString *name = [story[@"title"] isKindOfClass:NSString.class]
			? story[@"title"] : self.storyTitle;
	if (!name.length)
		name = TGLocalized(@"Story");
	if (self.stories.count > 1) {
		name = [name stringByAppendingFormat:@"  %ld/%ld",
				(long)(self.index + 1), (long)self.stories.count];
	}
	self.senderLabel.text = name;
	self.timeLabel.text = TGStoryRelativeTime([story[@"date"] doubleValue]);
}

- (void)loadStoryId:(int32_t)storyId {
	__weak typeof(self) weakSelf = self;
	[[TGStoryStore shared]story:storyId fromChat:self.chatId completion:^(NSDictionary *story){
		TGStoryViewerViewController *me = weakSelf;
		if (!me || me.closed)
			return;
		if (!story){
			[me advance:1];
			return;
		}
		me.stories[me.index] = story;
		[me showStory:story];
	}];
}

- (void)showStory:(NSDictionary *)story {
	_picture.image = nil;
	self.loadingEffect.hidden = NO;
	[self.loadingView startAnimating];
	self.senderLabel.text = story[@"title"] ?: self.storyTitle;
	[self refreshAuthorAvatar];
	[self updateHeaderCounterForStory:story];
	NSString *caption = [story[@"caption"] isKindOfClass:NSString.class] ? story[@"caption"] : @"";
	NSArray *captionEntities = [story[@"captionEntities"] isKindOfClass:NSArray.class] ? story[@"captionEntities"] : nil;
	if (captionEntities.count && caption.length) {
		self.captionLabel.attributedText = TGAttributedMessageText(caption, captionEntities, self.captionLabel.font, self.captionLabel.textColor);
	} else {
		self.captionLabel.text = caption;
	}
	NSInteger viewers = [story[@"viewers"] integerValue];
	NSInteger reactions = [story[@"reactions"] integerValue];
	NSMutableArray *bits = [NSMutableArray array];
	if ([story[@"isLive"] boolValue]) {
		[bits addObject:TGLocalized(@"LIVE")];
	} else if (viewers > 0) {
		[bits addObject:TGLocalizedPluralValue(@"%@ view", @"%@ views",
				[NSString stringWithFormat:@"%ld", (long)viewers], (NSInteger)viewers)];
	} else {
		[bits addObject:TGLocalized(@"No views")];
	}
	if (reactions > 0)
		[bits addObject:TGLocalizedPlural(@"%d reaction", @"%d reactions", (NSInteger)reactions)];
	if ([story[@"isPostedToChatPage"] boolValue])
		[bits addObject:TGLocalized(@"Story posted to your profile")];
	self.infoLabel.text = [bits componentsJoinedByString:@" · "];

	[self loadReactionsForStory:story];
	[self startProgressForStory:story];
	[self openCurrent];

	NSNumber *photoId = story[@"thumbPhotoId"] ?: story[@"photoId"];
	if ([story[@"isVideo"] boolValue] || [story[@"isLive"] boolValue])
		photoId = story[@"thumbPhotoId"];
	if ([photoId isKindOfClass:NSNumber.class] && photoId.integerValue > 0){
		__weak typeof(self) weakSelf = self;
		[[TGMediaStore shared]downloadFile:photoId.integerValue
							   priority:TGDownloadPriorityOnScreen
							 completion:^(NSString *path){
			TGStoryViewerViewController *me = weakSelf;
			if (!me || !path.length)
				return;
			[me.picture setImage:[UIImage imageWithContentsOfFile:path]];
			me.loadingEffect.hidden = YES;
			[me.loadingView stopAnimating];
		}];
	} else {
		self.loadingEffect.hidden = YES;
		[self.loadingView stopAnimating];
	}

	NSNumber *videoId = story[@"videoId"];
	if ([videoId isKindOfClass:NSNumber.class] && videoId.integerValue > 0)
		[self playVideoId:videoId.integerValue];
}

- (void)playVideoId:(NSInteger)videoId {
	__weak typeof(self) weakSelf = self;
	[[TGMediaStore shared]downloadFile:videoId completion:^(NSString *path){
		TGStoryViewerViewController *me = weakSelf;
		if (!me || !path.length || me.closed)
			return;
		me.loadingEffect.hidden = YES;
		[me.loadingView stopAnimating];
		NSError *sessionError = nil;
		[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback
											   error:&sessionError];
		[[AVAudioSession sharedInstance] setActive:YES error:NULL];
		AVPlayer *player = [AVPlayer playerWithURL:[NSURL fileURLWithPath:path]];
		AVPlayerLayer *layer = [AVPlayerLayer playerLayerWithPlayer:player];
		layer.videoGravity = AVLayerVideoGravityResizeAspect;
		layer.frame = me.picture.bounds;
		[me.picture.layer addSublayer:layer];
		me.player = player;
		me.playerLayer = layer;
		[player play];
	}];
}

- (void)removePlayerLayer {
	[self.player pause];
	[self.playerLayer removeFromSuperlayer];
	self.player = nil;
	self.playerLayer = nil;
}

- (void)stopVideo {
	[self removePlayerLayer];
}

#pragma mark - progress

- (void)startProgressForStory:(NSDictionary *)story {
	if ([story[@"isLive"] boolValue]){
		[self markProgressComplete:YES];
		return;
	}
	double known = [story[@"duration"] doubleValue];
	self.duration = [story[@"isVideo"] boolValue] && known > 0
			? known : kStoryStillSeconds;
	self.elapsed = 0;
	self.paused = NO;
	self.timer = [NSTimer scheduledTimerWithTimeInterval:kStoryTick
												 target:self
											   selector:@selector(tick)
											   userInfo:nil
												repeats:YES];
}

- (void)tick {
	if (self.paused || self.closed)
		return;
	self.elapsed += kStoryTick;
	CGFloat fraction = self.duration > 0
			? (CGFloat)(self.elapsed / self.duration) : 1;
	[self updateProgress:fraction];
	if (fraction >= 1){
		[self stopTimer];
		[self advance:1];
	}
}

- (void)updateProgress:(CGFloat)fraction {
	if (self.index < 0 || self.index >= (NSInteger)self.progressFills.count)
		return;
	UIView *fill = self.progressFills[self.index];
	CGRect frame = fill.frame;
	frame.size.width = fill.superview.bounds.size.width *
			MAX(0, MIN(1, fraction));
	fill.frame = frame;
}

- (void)markProgressComplete:(BOOL)complete {
	for (NSInteger i = 0; i < (NSInteger)self.progressFills.count; i++){
		UIView *fill = self.progressFills[i];
		CGRect frame = fill.frame;
		frame.size.width = (i < self.index || complete)
				? fill.superview.bounds.size.width : 0;
		fill.frame = frame;
	}
}

- (void)stopTimer {
	[self.timer invalidate];
	self.timer = nil;
}

- (void)pause {
	if (self.paused)
		return;
	self.paused = YES;
	[self.player pause];
}

- (void)resume {
	if (!self.paused)
		return;
	self.paused = NO;
	[self.player play];
}

#pragma mark - reactions

- (void)loadReactions {
	__weak typeof(self) weakSelf = self;
	[[TGStoryStore shared]storyAvailableReactionsWithCompletion:^(NSDictionary *reactions){
		TGStoryViewerViewController *me = weakSelf;
		if (!me || !reactions)
			return;
		me.reactionEmojis = reactions[@"emojis"] ?: @[];
		[me rebuildReactionRail];
	}];
}

- (void)loadReactionsForStory:(NSDictionary *)story {
	NSString *chosen = story[@"chosenReaction"];
	if (chosen.length && self.reactionEmojis.count){
		NSMutableArray *ordered = [NSMutableArray arrayWithObject:chosen];
		for (NSString *emoji in self.reactionEmojis)
			if (![emoji isEqualToString:chosen])
				[ordered addObject:emoji];
		self.reactionEmojis = ordered;
	}
	[self rebuildReactionRail];
}

- (void)rebuildReactionRail {
	if (self.reactionRail)
		[self.reactionRail removeFromSuperview];
	self.reactionRail = [[UIView alloc] initWithFrame:CGRectZero];
	self.reactionRail.backgroundColor = [UIColor clearColor];
	[self.view addSubview:self.reactionRail];

	NSArray *emojis = self.reactionEmojis;
	NSInteger shown = MIN((NSInteger)emojis.count, kStoryReactionChoices);
	for (NSInteger i = 0; i < shown; i++){
		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		button.frame = CGRectMake(i * (TGMetricStoryReactionButton +
									   TGMetricStoryReactionGap), 0,
								   TGMetricStoryReactionButton,
								   TGMetricStoryReactionButton);
		button.backgroundColor = [[TGTheme shared] scrimColour];
		button.layer.cornerRadius = TGHalf(TGMetricStoryReactionButton);
		button.tag = 100 + i;
		[button addTarget:self action:@selector(reactionTapped:)
				forControlEvents:UIControlEventTouchUpInside];
		UILongPressGestureRecognizer *remove = [[UILongPressGestureRecognizer alloc]
				initWithTarget:self action:@selector(reactionHeld:)];
		[button addGestureRecognizer:remove];
		UILabel *glyph = [[UILabel alloc] initWithFrame:button.bounds];
		glyph.text = emojis[i];
		glyph.font = TGFontEmoji();
		glyph.textAlignment = NSTextAlignmentCenter;
		glyph.backgroundColor = [UIColor clearColor];
		[button addSubview:glyph];
		[self.reactionRail addSubview:button];
	}
	if (!shown){
		UILabel *hint = [[UILabel alloc] initWithFrame:CGRectMake(0, 0,
				TGMetricScreenWidth, TGMetricStoryReactionButton)];
		hint.text = @"No Results";
		hint.font = TGFontMeta();
		hint.textColor = [[TGTheme shared] secondaryTextColour];
		hint.backgroundColor = [UIColor clearColor];
		[self.reactionRail addSubview:hint];
	}
	[self.view setNeedsLayout];
}

- (void)reactionTapped:(UIButton *)button {
	NSInteger i = button.tag - 100;
	if (i < 0 || i >= (NSInteger)self.reactionEmojis.count)
		return;
	NSString *emoji = self.reactionEmojis[i];
	NSDictionary *story = self.currentStory;
	if ([story[@"isLive"] boolValue]){
		int32_t callId = [story[@"groupCallId"] intValue];
		__weak typeof(self) weakSelf = self;
		[[TGStoryStore shared]addPendingLiveStoryReactionInCall:callId stars:1
				completion:^(BOOL ok, NSString *error){
			TGStoryViewerViewController *me = weakSelf;
			if (!me)
				return;
			if (!ok){
				[TGAlertSheet showMessage:error ?: @"An error occurred."
									title:@"Live Stream Reaction" inView:me.view];
				return;
			}
			// The undo window is two seconds; committing after it is what
			// makes the star count on the server, not in this screen.
			[me performSelector:@selector(commitLiveReaction:)
					 withObject:@(callId) afterDelay:2.0];
		}];
		return;
	}
	NSString *chosen = story[@"chosenReaction"];
	BOOL remove = [chosen isEqualToString:emoji];
	__weak typeof(self) weakSelf = self;
	[[TGStoryStore shared]setStoryReaction:remove ? nil : emoji
								onStory:[story[@"storyId"] intValue]
							   fromChat:self.chatId
							   completion:^(BOOL ok, NSString *error){
		TGStoryViewerViewController *me = weakSelf;
		if (!me)
			return;
		if (!ok){
			[TGAlertSheet showMessage:error ?: @"An error occurred."
								title:@"Reaction" inView:me.view];
			return;
		}
		NSMutableDictionary *changed = [me.currentStory mutableCopy];
		changed[@"chosenReaction"] = remove ? @"" : emoji;
		me.stories[me.index] = changed;
		if (me.onStoriesChanged)
			me.onStoriesChanged();
	}];
}

- (void)reactionHeld:(UILongPressGestureRecognizer *)hold {
	if (hold.state != UIGestureRecognizerStateBegan)
		return;
	NSDictionary *story = self.currentStory;
	if (![story[@"isLive"] boolValue])
		return;
	__weak typeof(self) weakSelf = self;
	[[TGStoryStore shared]removePendingLiveStoryReactionsInCall:
			[story[@"groupCallId"] intValue]
			completion:^(BOOL ok, NSString *error){
		TGStoryViewerViewController *me = weakSelf;
		if (!me)
			return;
		[TGAlertSheet showMessage:ok
				? @"Saved"
				: (error ?: @"An error occurred.")
				title:@"Live Stream Reaction" inView:me.view];
	}];
}

- (void)commitLiveReaction:(NSNumber *)callId {
	__weak typeof(self) weakSelf = self;
	[[TGStoryStore shared]commitPendingLiveStoryReactionsInCall:callId.intValue
			completion:^(BOOL ok, NSString *error){
		TGStoryViewerViewController *me = weakSelf;
		if (!me || !ok)
			return;
		[TGAlertSheet showMessage:@"Saved"
							title:@"Live Stream Reaction" inView:me.view];
	}];
}

#pragma mark - navigation

- (NSDictionary *)currentStory {
	if (self.index < 0 || self.index >= (NSInteger)self.stories.count)
		return @{};
	id entry = self.stories[self.index];
	return [entry isKindOfClass:NSDictionary.class] ? entry : @{};
}

- (void)advance:(NSInteger)delta {
	NSInteger next = self.index + delta;
	NSDictionary *current = self.currentStory;
	if (current[@"storyId"]){
		[[TGStoryStore shared]closeStory:[current[@"storyId"] intValue]
							 fromChat:self.chatId completion:nil];
	}
	if (next < 0){
		[self finish];
		return;
	}
	if (next >= (NSInteger)self.stories.count){
		[self finish];
		return;
	}
	self.index = next;
	[self showCurrentStory];
}

- (void)openCurrent {
	NSDictionary *story = self.currentStory;
	if (!story[@"storyId"])
		return;
	[[TGStoryStore shared]openStory:[story[@"storyId"] intValue]
						fromChat:self.chatId completion:nil];
}

- (void)tapAt:(UITapGestureRecognizer *)tap {
	CGPoint point = [tap locationInView:self.view];
	// The left third goes back and the rest goes on, as Telegram's stories
	// do - a 320 pt phone gives 107 pt to each side.
	[self advance:(point.x < self.view.bounds.size.width / 3.0f) ? -1 : 1];
}

/// A drag down carries the story with the finger; letting go before the
/// threshold puts it back and resumes the timer.
- (void)storyDragged:(UIPanGestureRecognizer *)drag {
	CGPoint moved = [drag translationInView:self.view];

	if (drag.state == UIGestureRecognizerStateBegan){
		self.dragStart = self.view.center;
		[self pause];
		return;
	}
	if (drag.state == UIGestureRecognizerStateChanged){
		self.view.center = CGPointMake(self.dragStart.x,
				self.dragStart.y + MAX(0, moved.y));
		return;
	}
	if (drag.state != UIGestureRecognizerStateEnded &&
		drag.state != UIGestureRecognizerStateCancelled)
		return;

	CGFloat velocity = [drag velocityInView:self.view].y;
	if (moved.y > TGMetricViewerDismissDistance ||
		velocity > TGMetricViewerDismissVelocity){
		[UIView animateWithDuration:TGAnimationDurationFast animations:^{
			self.view.center = CGPointMake(self.dragStart.x,
					self.dragStart.y + self.view.bounds.size.height);
			self.view.alpha = TGAlphaTransparent;
		} completion:^(BOOL done){
			[self finish];
		}];
		return;
	}

	[UIView animateWithDuration:TGAnimationDurationFast animations:^{
		self.view.center = self.dragStart;
	} completion:^(BOOL done){
		[self resume];
	}];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture {
	if ([gesture isKindOfClass:UIPanGestureRecognizer.class]){
		CGPoint velocity = [(UIPanGestureRecognizer *)gesture velocityInView:self.view];
		return fabs(velocity.y) > fabs(velocity.x);
	}
	return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
		shouldReceiveTouch:(UITouch *)touch {
	UIView *view = touch.view;
	while (view){
		if ([view isKindOfClass:UIControl.class])
			return NO;
		if (view == self.view)
			break;
		view = view.superview;
	}
	return YES;
}

- (void)held:(UILongPressGestureRecognizer *)hold {
	if (hold.state == UIGestureRecognizerStateBegan)
		[self pause];
	else if (hold.state == UIGestureRecognizerStateEnded ||
			 hold.state == UIGestureRecognizerStateCancelled)
		[self resume];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self.navigationController setNavigationBarHidden:YES animated:NO];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[self.navigationController setNavigationBarHidden:NO animated:NO];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
}

- (void)closeTapped {
	[self finish];
}

- (void)finish {
	if (self.closed)
		return;
	self.closed = YES;
	[self stopTimer];
	[self stopVideo];
	NSDictionary *story = self.currentStory;
	if (story[@"storyId"])
		[[TGStoryStore shared]closeStory:[story[@"storyId"] intValue]
							 fromChat:self.chatId completion:nil];
	if (self.onStoriesChanged)
		self.onStoriesChanged();
	UIViewController *presenter = self.presentingViewController
			?: self.navigationController.presentingViewController;
	if (presenter)
		[presenter dismissViewControllerAnimated:YES completion:nil];
	else
		[self.navigationController popViewControllerAnimated:YES];
}

- (void)dealloc {
	[self stopTimer];
	[self stopVideo];
}

#pragma mark - the own story menu

- (void)menuTapped {
	NSDictionary *story = self.currentStory;
	if (!story[@"storyId"])
		return;
	BOOL own = self.canManage || [story[@"canBeEdited"] boolValue] ||
			[story[@"canBeDeleted"] boolValue];
	BOOL publicStory = [story[@"privacy"] isEqualToString:@"everyone"] &&
			self.peerAddress.length > 0;
	NSMutableArray *choices = [NSMutableArray array];
	void (^add)(NSString *, BOOL) = ^(NSString *title, BOOL destructive){
		[choices addObject:destructive
				? @{@"title" : title, @"destructive" : @YES}
				: @{@"title" : title}];
	};

	add(@"Story", NO);
	if ([story[@"isLive"] boolValue] && !own)
		add(@"View Story", NO);
	if (!own)
		add(@"Report Story", NO);
	if (!own && publicStory)
		add(@"Copy Link", NO);
	add(@"Save to Gallery", NO);

	if (own) {
		add(@"Edit Caption", NO);
		add(@"Story Cover", NO);
		add([story[@"isPostedToChatPage"] boolValue]
				? @"Remove from Profile" : @"Add to Profile", NO);
		add(@"Pin", NO);
		add(@"Privacy", NO);
		add(@"Add to Album", NO);
		add(@"Albums", NO);
		add(@"Edit Story", NO);
		// Add Story is not a story context action in official; the own menu
		// ends with Delete Story.
		add(@"Delete Story", YES);
	}

	// An anchored context menu, not a titled bottom sheet. iOS 6 has no
	// UIContextMenu, so TGPopupMenu draws the card under the More button.
	UIView *menuButton = [self.view viewWithTag:9002];
	CGPoint anchor = menuButton
			? CGPointMake(CGRectGetMidX(menuButton.frame),
					CGRectGetMaxY(menuButton.frame))
			: CGPointMake(self.view.bounds.size.width - TGMetricPadLarge,
					TGMetricPadLarge);
	__weak typeof(self) weakSelf = self;
	[TGPopupMenu showItems:choices atPoint:anchor inView:self.view
				headerView:nil onChoice:^(NSInteger choice, NSString *title){
		TGStoryViewerViewController *me = weakSelf;
		if (!me || choice < 0 || choice >= (NSInteger)choices.count)
			return;
		if ([title isEqualToString:@"Story"])
			[me openInfo];
		else if ([title isEqualToString:@"Report Story"])
			[me openReport];
		else if ([title isEqualToString:@"Save to Gallery"])
			[me saveToGallery];
		else if ([title isEqualToString:@"Copy Link"])
			[me copyLink];
		else if ([title isEqualToString:@"Edit Caption"])
			[me editCaption];
		else if ([title isEqualToString:@"Story Cover"])
			[me changeCover];
		else if ([title isEqualToString:@"Delete Story"])
			[me confirmDelete];
		else if ([title isEqualToString:@"Add to Profile"] ||
				 [title isEqualToString:@"Remove from Profile"])
			[me toggleProfile:![story[@"isPostedToChatPage"] boolValue]];
		else if ([title isEqualToString:@"Pin"])
			[me pinToChatPage];
		else if ([title isEqualToString:@"Privacy"])
			[me choosePrivacy];
		else if ([title isEqualToString:@"Add to Album"])
			[me addToAlbum];
		else if ([title isEqualToString:@"Albums"])
			[me openAlbums];
		else if ([title isEqualToString:@"Edit Story"])
			[me editBusiness];
		else if ([title isEqualToString:@"View Story"])
			[me openLive];
	}];
}

- (void)saveToGallery {
	NSDictionary *story = self.currentStory;
	NSNumber *fileId = nil;
	TGStorySaveKind kind = TGStorySaveKindForStory(story, &fileId);
	if (kind == TGStorySaveKindNone || !fileId)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGMediaStore shared]downloadFile:fileId.integerValue
						   completion:^(NSString *path){
		TGStoryViewerViewController *me = weakSelf;
		if (!me)
			return;
		if (!path.length) {
			[TGAlertSheet showMessage:TGLocalized(@"An error occurred.")
								title:TGLocalized(@"Save to Gallery") inView:me.view];
			return;
		}
		BOOL saved = NO;
		if (kind == TGStorySaveKindVideo) {
			// A video story saves the video file, not its poster frame.
			UISaveVideoAtPathToSavedPhotosAlbum(path, nil, nil, NULL);
			saved = YES;
		} else {
			UIImage *image = [UIImage imageWithContentsOfFile:path];
			if (image) {
				UIImageWriteToSavedPhotosAlbum(image, nil, nil, NULL);
				saved = YES;
			}
		}
		// "Saved" alone is the Saved Messages folder in the pack.
		NSString *done = kind == TGStorySaveKindVideo
				? @"Video saved to Photos." : @"Image saved to Photos.";
		[TGAlertSheet showMessage:TGLocalized(saved ? done : @"An error occurred.")
							title:TGLocalized(@"Save to Gallery") inView:me.view];
	}];
}

- (void)copyLink {
	NSDictionary *story = self.currentStory;
	NSString *link = [story[@"link"] isKindOfClass:NSString.class]
			? story[@"link"] : nil;
	void (^finish)(NSString *) = ^(NSString *result){
		if (!result.length)
			return;
		[UIPasteboard generalPasteboard].string = result;
		[TGAlertSheet showMessage:TGLocalized(@"Link copied to clipboard.")
							title:TGLocalized(@"Copy Link") inView:self.view];
	};
	if (link.length){
		finish(link);
		return;
	}
	// Ask the client for the exported link rather than inventing t.me/c/....
	// The peer address is only the fallback for a public story, which is the
	// only case the menu offers this action.
	__weak typeof(self) weakSelf = self;
	[[TGStoryStore shared] storyLinkForStory:[story[@"storyId"] intValue]
									  inChat:self.chatId
								  completion:^(NSString *exported){
		if (exported.length){
			finish(exported);
			return;
		}
		TGStoryViewerViewController *me = weakSelf;
		if (!me.peerAddress.length)
			return;
		finish([NSString stringWithFormat:@"https://t.me/%@/%d",
				me.peerAddress, [story[@"storyId"] intValue]]);
	}];
}

- (void)openInfo {
	NSDictionary *story = self.currentStory;
	TGStoryInfoViewController *info = [[TGStoryInfoViewController alloc]
			initWithChatId:self.chatId
				   storyId:[story[@"storyId"] intValue]
					  story:story
					  mode:TGStoryInfoModeInfo];
	[self presentStoryInfo:info];
}

- (void)openReport {
	NSDictionary *story = self.currentStory;
	TGStoryInfoViewController *info = [[TGStoryInfoViewController alloc]
			initWithChatId:self.chatId
				   storyId:[story[@"storyId"] intValue]
					  story:story
					  mode:TGStoryInfoModeReport];
	[self presentStoryInfo:info];
}

/// An in-story panel, not a full-screen modal: the panel rises from the
/// bottom and the story stays visible above it, as StoryItemSetViewList does
/// inside the official container.
- (void)presentStoryInfo:(TGStoryInfoViewController *)info {
	CGFloat height = floor(self.view.bounds.size.height * 0.72f);
	[self addChildViewController:info];
	info.view.frame = CGRectMake(0, self.view.bounds.size.height - height,
			self.view.bounds.size.width, height);
	info.view.autoresizingMask = UIViewAutoresizingFlexibleWidth |
			UIViewAutoresizingFlexibleTopMargin;
	info.view.backgroundColor = [[TGTheme shared] groupedBackgroundColour];
	info.view.layer.cornerRadius = TGMetricCornerCard;
	info.view.clipsToBounds = YES;
	info.view.tag = 9010;
	info.overlayPanel = YES;
	[self.view addSubview:info.view];
	[info didMoveToParentViewController:self];
}

- (void)editCaption {
	NSDictionary *story = self.currentStory;
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Edit Caption"
					message:nil
				placeholder:@"Caption"
					   text:story[@"caption"]
					 action:@"Save"
					 inView:self.view
				   onSubmit:^(NSString *text){
		TGStoryViewerViewController *me = weakSelf;
		if (!me)
			return;
		[[TGStoryStore shared]editStory:[story[@"storyId"] intValue]
							fromChat:me.chatId
								path:nil
							 isVideo:NO
							duration:0
							 caption:text
						  completion:^(BOOL ok, NSString *error){
			if (!ok)
				[TGAlertSheet showMessage:error ?: @"An error occurred."
									title:@"Edit Story" inView:me.view];
			else
				[me reloadCurrent];
		}];
	}];
}

- (void)changeCover {
	NSDictionary *story = self.currentStory;
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Story Cover"
					message:nil
				placeholder:@"0.0"
					   text:@"0"
					 action:@"Save"
					 inView:self.view
				   onSubmit:^(NSString *text){
		TGStoryViewerViewController *me = weakSelf;
		if (!me)
			return;
		double stamp = text.doubleValue;
		[[TGStoryStore shared]editStoryCover:[story[@"storyId"] intValue]
								 fromChat:me.chatId
						  coverTimestamp:stamp
							  completion:^(BOOL ok, NSString *error){
			[TGAlertSheet showMessage:ok ? @"Saved"
					: (error ?: @"An error occurred.")
								title:@"Story Cover" inView:me.view];
		}];
	}];
}

- (void)confirmDelete {
	NSDictionary *story = self.currentStory;
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:@"Delete Story"
						title:@"Delete Story"
					   action:@"Delete"
				  destructive:YES
					   inView:self.view
					onConfirm:^{
		TGStoryViewerViewController *me = weakSelf;
		if (!me)
			return;
		void (^done)(BOOL, NSString *) = ^(BOOL ok, NSString *error){
			if (!ok){
				[TGAlertSheet showMessage:error ?: @"An error occurred."
									title:@"Delete Story" inView:me.view];
				return;
			}
			if (me.onStoriesChanged)
				me.onStoriesChanged();
			[me advance:1];
		};
		// A business story goes through the peer-aware delete; a user story
		// goes through the ordinary one.
		if ([story[@"isBusiness"] boolValue])
			[[TGStoryStore shared]deleteBusinessStory:[story[@"storyId"] intValue]
									  fromChat:me.chatId completion:done];
		else
			[[TGStoryStore shared]deleteStory:[story[@"storyId"] intValue]
								  fromChat:me.chatId completion:done];
	}];
}

- (void)toggleProfile:(BOOL)posted {
	NSDictionary *story = self.currentStory;
	__weak typeof(self) weakSelf = self;
	[[TGStoryStore shared]toggleStory:[story[@"storyId"] intValue]
						  fromChat:self.chatId
				   postedToChatPage:posted
					   completion:^(BOOL ok, NSString *error){
		TGStoryViewerViewController *me = weakSelf;
		if (!me)
			return;
		if (!ok){
			[TGAlertSheet showMessage:error ?: @"An error occurred."
								title:@"Story" inView:me.view];
			return;
		}
		NSMutableDictionary *changed = [me.currentStory mutableCopy];
		changed[@"isPostedToChatPage"] = @(posted);
		me.stories[me.index] = changed;
		if (me.onStoriesChanged)
			me.onStoriesChanged();
	}];
}

- (void)pinToChatPage {
	NSDictionary *story = self.currentStory;
	__weak typeof(self) weakSelf = self;
	[[TGStoryStore shared]setPinnedStoryIds:@[story[@"storyId"] ?: @(0)]
								  inChat:self.chatId
							  completion:^(BOOL ok, NSString *error){
		TGStoryViewerViewController *me = weakSelf;
		if (!me)
			return;
		[TGAlertSheet showMessage:ok ? @"Saved"
				: (error ?: @"An error occurred.")
							title:@"Story" inView:me.view];
	}];
}

- (void)choosePrivacy {
	NSDictionary *story = self.currentStory;
	NSArray *choices = @[@"Everybody", @"My Contacts", @"Close Friends", @"Selected Users"];
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:choices title:@"Privacy" destructiveIndex:-1
					   inView:self.view onChoice:^(NSInteger choice){
		TGStoryViewerViewController *me = weakSelf;
		if (!me)
			return;
		NSString *mode = choice == 1 ? @"contacts"
				: (choice == 2 ? @"closeFriends"
				: (choice == 3 ? @"selected" : @"everyone"));
		if (choice == 3){
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
				[me applyPrivacy:mode userIds:ids];
			}];
			return;
		}
		[me applyPrivacy:mode userIds:@[]];
	}];
}

- (void)applyPrivacy:(NSString *)mode userIds:(NSArray *)userIds {
	NSDictionary *story = self.currentStory;
	__weak typeof(self) weakSelf = self;
	[[TGStoryStore shared]setStoryPrivacySettings:[story[@"storyId"] intValue]
									   privacy:mode
									   userIds:userIds
									completion:^(BOOL ok, NSString *error){
		TGStoryViewerViewController *me = weakSelf;
		if (!me)
			return;
		[TGAlertSheet showMessage:ok ? @"Saved"
				: (error ?: @"An error occurred.")
							title:@"Privacy" inView:me.view];
	}];
}

/// Albums are a nested menu on the story action, not a screen with its own
/// Add/Edit/More bar. The same menu adds one story or opens an album.
- (void)showAlbumMenuAddingCurrentStory:(BOOL)adding {
	NSDictionary *story = self.currentStory;
	NSInteger storyId = [story[@"storyId"] intValue];
	__weak typeof(self) weakSelf = self;
	[[TGStoryStore shared]storyAlbumsForChat:self.chatId completion:^(NSArray *albums){
		TGStoryViewerViewController *me = weakSelf;
		if (!me)
			return;
		NSMutableArray *choices = [NSMutableArray array];
		for (NSDictionary *album in albums)
			[choices addObject:@{@"title" : album[@"name"] ?: @"Album",
					@"album" : album}];
		[choices addObject:@{@"title" : @"New Album"}];
		UIView *menuButton = [me.view viewWithTag:9002];
		CGPoint anchor = menuButton
				? CGPointMake(CGRectGetMidX(menuButton.frame),
						CGRectGetMaxY(menuButton.frame))
				: CGPointMake(me.view.bounds.size.width - TGMetricPadLarge,
						TGMetricPadLarge);
		[TGPopupMenu showItems:choices atPoint:anchor inView:me.view
					headerView:nil onChoice:^(NSInteger choice, NSString *title){
			TGStoryViewerViewController *viewer = weakSelf;
			if (!viewer || choice < 0 ||
				choice >= (NSInteger)choices.count)
				return;
			NSDictionary *album = choices[(NSUInteger)choice][@"album"];
			if (!album){
				[viewer createAlbumAddingStory:adding ? storyId : 0];
				return;
			}
			int32_t albumId = [album[@"albumId"] intValue];
			if (adding){
				[[TGStoryStore shared]addStories:@[@(storyId)]
									  toAlbum:albumId
									   inChat:viewer.chatId
								   completion:^(NSDictionary *changed,
												NSString *error){
					[TGAlertSheet showMessage:changed ? @"Saved"
							: (error ?: @"An error occurred.")
											title:@"Add to Album" inView:viewer.view];
				}];
				return;
			}
			[[TGStoryStore shared]storiesInAlbum:albumId inChat:viewer.chatId
										 offset:0 limit:60
								   completion:^(NSArray *stories, NSString *error){
				NSMutableArray *ids = [NSMutableArray array];
				for (NSDictionary *item in stories)
					if ([item[@"storyId"] isKindOfClass:NSNumber.class])
						[ids addObject:item[@"storyId"]];
				if (!ids.count){
					[TGAlertSheet showMessage:error ?: @"No stories"
										title:@"Albums" inView:viewer.view];
					return;
				}
				[viewer.stories setArray:ids];
				viewer.index = 0;
				[viewer showCurrentStory];
			}];
		}];
	}];
}

- (void)createAlbumAddingStory:(NSInteger)storyId {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"New Album" message:nil placeholder:@"Album"
					   text:nil action:@"Create" inView:self.view
				 onSubmit:^(NSString *name){
		TGStoryViewerViewController *me = weakSelf;
		if (!me)
			return;
		NSArray *ids = storyId > 0 ? @[@(storyId)] : @[];
		[[TGStoryStore shared]createStoryAlbumNamed:name inChat:me.chatId
										storyIds:ids
									  completion:^(NSDictionary *album,
												   NSString *error){
			[TGAlertSheet showMessage:album ? @"Saved"
					: (error ?: @"An error occurred.")
								title:@"New Album" inView:me.view];
		}];
	}];
}

- (void)addToAlbum {
	[self showAlbumMenuAddingCurrentStory:YES];
}

- (void)openAlbums {
	[self showAlbumMenuAddingCurrentStory:NO];
}

- (void)editBusiness {
	NSDictionary *story = self.currentStory;
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Edit Story"
					message:nil
				placeholder:@"Caption"
					   text:story[@"caption"]
					 action:@"Save"
					 inView:self.view
				   onSubmit:^(NSString *text){
		TGStoryViewerViewController *me = weakSelf;
		if (!me)
			return;
		[[TGStoryStore shared]editBusinessStory:[story[@"storyId"] intValue]
									fromChat:me.chatId
										path:nil
									 isVideo:NO
									duration:0
									 caption:text
								  completion:^(BOOL ok, NSString *error){
			[TGAlertSheet showMessage:ok ? @"Saved"
					: (error ?: @"An error occurred.")
								title:@"Story" inView:me.view];
		}];
	}];
}

- (void)deleteBusiness {
	NSDictionary *story = self.currentStory;
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:@"Delete Story"
						title:@"Story"
					   action:@"Delete"
				  destructive:YES
					   inView:self.view
					onConfirm:^{
		TGStoryViewerViewController *me = weakSelf;
		if (!me)
			return;
		[[TGStoryStore shared]deleteBusinessStory:[story[@"storyId"] intValue]
									  fromChat:me.chatId
									completion:^(BOOL ok, NSString *error){
			[TGAlertSheet showMessage:ok ? @"Saved"
					: (error ?: @"An error occurred.")
								title:@"Story" inView:me.view];
		}];
	}];
}

- (void)openLive {
	NSDictionary *story = self.currentStory;
	TGLiveStoryViewController *live = [[TGLiveStoryViewController alloc]
			initWithChatId:self.chatId
			   groupCallId:[story[@"groupCallId"] intValue]];
	live.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:live animated:YES];
}

- (void)addStory {
	__weak typeof(self) weakSelf = self;
	[TGStoryComposerViewController openFromController:self chatId:self.chatId
												title:@"Your story" onPosted:^{
		TGStoryViewerViewController *me = weakSelf;
		if (me.onStoriesChanged)
			me.onStoriesChanged();
	}];
}

- (void)reloadCurrent {
	NSDictionary *story = self.currentStory;
	if (!story[@"storyId"])
		return;
	__weak typeof(self) weakSelf = self;
	[[TGStoryStore shared]story:[story[@"storyId"] intValue]
					fromChat:self.chatId
				  completion:^(NSDictionary *fresh){
		TGStoryViewerViewController *me = weakSelf;
		if (!me || !fresh)
			return;
		me.stories[me.index] = fresh;
		[me showStory:fresh];
	}];
}

@end
