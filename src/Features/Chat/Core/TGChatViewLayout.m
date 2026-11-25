#import "TGPerf.h"
#import "TGChatViewController.h"
#import "TGMessageStore.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGForwardPicker.h"
#import "TGVoiceRecorder.h"
#import "TGProfileViewController.h"
#import "TGThemeFile.h"
#import "TGCapabilities.h"
#import "TGDevice.h"
#import <AddressBookUI/AddressBookUI.h>
#import <CoreLocation/CoreLocation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <QuartzCore/QuartzCore.h>
#import <MediaPlayer/MediaPlayer.h>
#import <MapKit/MapKit.h>
#import <AVFoundation/AVFoundation.h>
#import "TGVoiceDecoder.h"
#import "TGEmojiData.h"
#import "TGCustomEmojiStore.h"
#import "UIImage+WebP.h"
#import "TGLottieView.h"
#import "TGDevShowcase.h"
#import "TGCallViewController.h"
#import "TGPopupMenu.h"
#import "TGSnackbar.h"
#import "TGMediaViewer.h"
#import "TGPollPresentation.h"
#import "TGChecklistPresentation.h"
#import "TGGiftViewController.h"
#import "TGStoryViewerViewController.h"
#import "TGCommunityViewController.h"
#import "TGMusicPlayer.h"
#import "TGDevShowcase.h"
#import "TGMessageLayout.h"
#import "TGBubbleCell.h"
#import "TGChatViewControllerInternal.h"
#import "TGMessageStreamStore.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGDMTopicsViewController.h"

#if TG_DEV
#endif



static int64_t sActiveChatId = 0;

#pragma mark - controller


static char kTGTableContentSizeContext;

@implementation TGChatViewController (TGChatViewLayout)

+ (int64_t)activeChatId {
	return sActiveChatId;
}

#pragma mark - layout

- (void)viewDidLoad {
	[super viewDidLoad];

	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	// A chat that opens right after a popped one must not inherit a defer flag
	// left set by a scroll whose settle callback was cancelled on the way out.
	[TGLottieView setBuildsDeferred:NO];
	// The sticker and emoji panel opens from here. Its emoji list and the font
	// scan behind it are built off the main thread a second after the chat,
	// once the history load has had the single core.
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
			dispatch_get_main_queue(), ^{ TGWarmEmojiData(); });

	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	double vcStart = TGPerfNow();
	self.openStart = vcStart;
	[self buildTitleView];
	TGPerfReport("chat vc", "title", vcStart, 50.0);
	self.streamStore = [[TGMessageStreamStore alloc] init];
	self.messages = @[];
	TGDeviceTier tier = [TGDevice tier];
	self.layoutCache = [[TGMessageLayoutCache alloc] initWithCapacity:
			tier == TGDeviceTierVintage ? 80 : 500];
	self.gifPaths = [NSMutableDictionary dictionary];
	self.gifsRequested = [NSMutableSet set];
	self.senderAvatars = [[TGImageLruCache alloc] initWithCapacity:
			tier == TGDeviceTierVintage ? 24 : tier == TGDeviceTierLegacy ? 60 : 120];
	self.senderAvatarsRequested = [NSMutableSet set];
	// About 1.1 MB a photo (a 400 px decode plus its rounded copy): forty of
	// them were 45 MB, past where jetsam kills the app on a 256 MB phone. Rows
	// fetch an evicted photo again, so a small window is enough.
	self.images = [[TGImageLruCache alloc] initWithCapacity:
			tier == TGDeviceTierVintage ? 12 : tier == TGDeviceTierLegacy ? 24 : 40];
	self.imagesRequested = [NSMutableSet set];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(memoryWarning:)
			name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
	self.lottiePaths = [NSMutableDictionary dictionary];
	self.playedAnimations = [NSMutableSet set];
	self.maps = [[TGImageLruCache alloc] initWithCapacity:
			tier == TGDeviceTierVintage ? 5 : 20];
	self.mapsRequested = [NSMutableSet set];
	self.quotes = [NSMutableDictionary dictionary];
	self.quotesRequested = [NSMutableSet set];
	self.selectedMessageIds = [NSMutableSet set];
	self.view.backgroundColor = [[TGTheme shared] chatBackgroundColour];

	CGRect b = self.view.bounds;

	self.table = [[UITableView alloc] initWithFrame:
			CGRectMake(0, 0, b.size.width, b.size.height - kInputHeight)];
	self.table.dataSource = self;
	self.table.delegate = self;
	// Rows laid out again after the first paint (a picture's size, an emoji,
	// a reaction) grew the page under a chat holding its bottom, and the
	// newest messages ended up below the input bar: the hold follows them.
	[self.table addObserver:self forKeyPath:@"contentSize" options:0 context:&kTGTableContentSizeContext];
	self.table.separatorStyle = UITableViewCellSeparatorStyleNone;
	self.table.backgroundColor = [UIColor clearColor];
	self.table.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.table.clipsToBounds = YES;
	// The wallpaper goes behind the table, which is transparent over it.
	self.wallpaperView = [[UIImageView alloc] initWithFrame:self.view.bounds];
	self.wallpaperView.contentMode = UIViewContentModeScaleAspectFill;
	self.wallpaperView.clipsToBounds = YES;
	self.wallpaperView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
										  UIViewAutoresizingFlexibleHeight;
	self.wallpaperView.backgroundColor = [[TGTheme shared] chatBackgroundColour];
	if ([TGCapabilities canShowWallpaper]) {
		// The pattern takes about a frame to render on the A4, and the chat
		// open paid for it inside the push: the tint shows at once, the
		// texture lands when the background thread finishes.
		__weak UIImageView *weakWallpaper = self.wallpaperView;
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
			UIImage *image = [[TGTheme shared] wallpaper];
			dispatch_async(dispatch_get_main_queue(), ^{
				weakWallpaper.image = image;
			});
		});
	} else {
		self.wallpaperView.image = nil;
	}
	[self.view addSubview:self.wallpaperView];

	// Hold a message for the things a chat needs and a tap cannot carry.
	[self.table addGestureRecognizer:[[UILongPressGestureRecognizer alloc]
			initWithTarget:self action:@selector(messageHeld:)]];

	UITapGestureRecognizer *tableTap = [[UITapGestureRecognizer alloc]
			initWithTarget:self action:@selector(tableTapped:)];
	tableTap.cancelsTouchesInView = NO;
	[self.table addGestureRecognizer:tableTap];

	// Records where a finger lands and declines the touch, so it changes
	// nothing else: the row's tap then knows which part was hit.
	self.touchRecorder = [[UITapGestureRecognizer alloc] initWithTarget:nil action:nil];
	self.touchRecorder.delegate = self;
	[self.table addGestureRecognizer:self.touchRecorder];

	[self.view addSubview:self.table];

	[self buildInputBar:b];
	TGPerfReport("chat vc", "input bar", vcStart, 100.0);
	[self refreshReplyKeyboard];
	// After the input bar exists: the kind decides what replaces it. Called
	// from the title build before, it framed the channel bar on a nil input
	// bar (zero size), and the composer stayed up until TDLib answered.
	if (self.chatId != [[TGMessageStore shared] savedMessagesChatId])
		[self loadChatKindAndChrome];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(replyMarkupChanged:)
			name:TGChatReplyMarkupChangedNotification object:nil];
	// Server-side composer facts: a bot's draft was stopped, or a scheduled
	// video went live. Both arrive as updates, not as a re-open.
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(draftStopped:)
			name:TGChatDraftStoppedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(videoPublished:)
			name:TGChatVideoPublishedNotification object:nil];
	// A custom emoji's picture arrived: the bubbles on screen swap the clear
	// stand-in for it. Their size does not change, only what is drawn.
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(customEmojiLoaded:)
			name:TGCustomEmojiLoadedNotification object:nil];
	// A send turned into a failure, or a retry is on its way: the bubble's
	// mark is drawn from the store, so the row has to be redrawn.
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sendStateChanged:)
			name:TGSendStoreMessageStateChangedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(speedLimited:)
			name:TGSpeedLimitNotification object:nil];
	TGPerfReport("chat vc", "chrome", vcStart, 50.0);

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:)
			name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:)
			name:UIKeyboardWillHideNotification object:nil];

	// Coalesced "messages in this chat changed" batches; the immediate
	// onMessage path below still appends a single new message.
	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(messageStoreChanged:)
				name:TGMessageStoreChangedNotification object:nil];

	[self installLiveHandlers];

	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(musicChanged)
				name:TGMusicPlayerChangedNotification object:nil];
	// One tick turns into two when they read it.
	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(readOutboxChanged:)
				name:TGChatReadOutboxChangedNotification object:nil];

	if (!TGIsDevChat(self.chatId)) {
		// Captured before opening marks everything read.
		self.readInboxAtOpen = [[TGMessageStore shared] lastReadInboxForChat:self.chatId];
		[[TGMessageStore shared] openChat:self.chatId];
		// Opening clears unread; the @ and the reaction badges are counted apart
		// from it and stay until they are read in their own right.
		[[TGMessageStore shared] readAllMentionsAndReactionsInChat:self.chatId];
		// So are the votes: the badge on a fresh poll answer is the chat's to
		// see, and the chat has now seen it.
		[[TGMessageStore shared] readAllChatPollVotes:self.chatId];

		// Whatever was typed here last and not sent - here or on another device.
		NSString *draft = [[TGMessageStore shared] draftForChat:self.chatId];
		if (draft.length && !self.input.text.length){
			self.input.text = draft;
			[self inputChanged];
		}
	}

	[self reload];
	TGPerfReportMemory("chat opened");
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	CGFloat width = self.view.bounds.size.width;
	CGFloat viewH = self.view.bounds.size.height;
	if (width <= 0.0f || viewH <= 0.0f)
		return;

	CGFloat defaultBarH = TGIsPad() ? TGMetricTabBarHeight : kInputHeight;
	CGFloat barH = (self.composerBarHeight > 0.0f && !self.inputBar.hidden) ? self.composerBarHeight : defaultBarH;
	CGRect bottomBarFrame = CGRectMake(0, viewH - barH, width, barH);
	CGRect liftedBar = bottomBarFrame, liftedTable = CGRectZero;
	TGChatComposerAboveKeyboard(self.view.bounds.size, barH, self.composerLift,
			&liftedBar, &liftedTable);

	if (self.inputBar) {
		self.inputBar.frame = liftedBar;
	}
	UIView *channelBar = [self.view viewWithTag:kChatChannelBottomBarTag];
	if (channelBar) {
		channelBar.frame = bottomBarFrame;
		UIView *centreBtn = [channelBar viewWithTag:kChatMuteBarTag] ?: [channelBar viewWithTag:kChatJoinChannelBarTag];
		if (centreBtn) {
			CGFloat side = barH;
			CGFloat leftW = 0.0f;
			if (self.directMessagesChatId != 0) leftW += side;
			if (self.linkedChatId != 0) leftW += side;
			CGFloat inset = MAX(leftW, side);
			CGFloat centreW = width - TGDoubled(inset);
			if (centreW > 0.0f) {
				centreBtn.frame = CGRectMake(inset, 0.0f, centreW, side);
			}
		}
	}
	NSArray *standInTags = @[@(kChatUnblockBarTag), @(kChatJoinGroupBarTag)];
	for (NSNumber *tag in standInTags) {
		UIView *standIn = [self.view viewWithTag:[tag integerValue]];
		if (standIn && standIn.superview == self.view) {
			standIn.frame = bottomBarFrame;
		}
	}

	CGFloat tableHeight = viewH - barH - (self.inputBar ? self.composerLift : TGMetricZero);
	if (tableHeight < 0.0f) tableHeight = 0.0f;
	BOOL widthChanged = self.table.frame.size.width != width;
	self.table.frame = CGRectMake(0, 0, width, tableHeight);

	if (widthChanged) {
		// Every bubble measured itself against the old width.
		[self.layoutCache removeAllObjects];
		[self.table reloadData];
		// The number of lines the composer text wraps to may change with it.
		[self updateComposerHeightAnimated:NO];
	}
	// The first build can run before the controller has a real width. The well
	// bitmap is deliberately left unset then; a real layout is the moment it
	// can be drawn.
	if (self.inputBar && self.composerWell && !self.composerWell.image)
		[self updateComposerHeightAnimated:NO];
	[self layoutChrome];
}

/// A two-line header: the chat name with member count or status beneath it,
/// which is what tells you where you are in a group.
- (void)buildTitleView {
	UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kTitleWidth, kTitleRow)];

	UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(0, TGMetricBorderWidth,
			kTitleWidth, TGMetricLineRow)];
	BOOL isSaved = self.chatId == [[TGMessageStore shared] savedMessagesChatId];
	name.text = isSaved ? TGLocalized(@"Saved Messages") : (self.chatTitle ?: @"Chat");
	name.font = TGFontHeader();
	name.textColor = [[TGTheme shared] barTitleColour];
	name.backgroundColor = [UIColor clearColor];
	name.textAlignment = NSTextAlignmentCenter;
	name.shadowColor = [[TGTheme shared] navBarTextShadowColour];
	name.shadowOffset = TGMetricShadowOffsetNav;
	[header addSubview:name];
	self.titleNameLabel = name;

	UILabel *subtitle = [[UILabel alloc] initWithFrame:CGRectMake(0,
			TGMetricBorderWidth + TGMetricLineRow, kTitleWidth, TGMetricLineMicro)];
	subtitle.font = TGFontMeta();
	subtitle.textColor = [[TGTheme shared] barSubtitleColour];
	subtitle.backgroundColor = [UIColor clearColor];
	subtitle.textAlignment = NSTextAlignmentCenter;
	[header addSubview:subtitle];
	self.titleSubtitleLabel = subtitle;

	header.userInteractionEnabled = YES;
	[header addGestureRecognizer:[[UITapGestureRecognizer alloc]
			initWithTarget:self action:@selector(openProfile)]];
	// The tap opens the profile; the hold starts message search, as
	// ChatController's title long-press does. The avatar's hold owns the menu.
	UILongPressGestureRecognizer *headerHold = [[UILongPressGestureRecognizer alloc]
			initWithTarget:self action:@selector(titleHeld:)];
	headerHold.minimumPressDuration = 0.6;
	[header addGestureRecognizer:headerHold];
	self.navigationItem.titleView = header;
	[self buildAvatarButton];
	// Saved Messages and forums carry search beside the avatar; a 200 pt
	// title centred on the bar then ran under both buttons.
	if (self.navigationItem.rightBarButtonItems.count > 1){
		CGFloat narrow = kTitleWidth - 2 * TGMetricRow;
		header.frame = CGRectMake(0, 0, narrow, kTitleRow);
		name.frame = CGRectMake(0, TGMetricBorderWidth, narrow, TGMetricLineRow);
		subtitle.frame = CGRectMake(0, TGMetricBorderWidth + TGMetricLineRow,
				narrow, TGMetricLineMicro);
	}

	// "typing..." takes the subtitle over while it lasts, then hands it back.
	__weak typeof(self) weakSelf = self;
	self.restingSubtitle = @"";

	// The subtitle belongs to the network whenever TDLib is not ready (B4):
	// a chat opened offline used to freeze at its captured "last seen"
	// instead of breathing "Waiting for network".
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(titleSubtitleOwnerChanged:)
			name:TGConnectionStateChangedNotification object:nil];
	[nc addObserver:self selector:@selector(titleSubtitleOwnerChanged:)
			name:TGUserStatusChangedNotification object:nil];

	// An imported theme can arrive while a chat is open - repaint rather than
	// wait for the screen to be pushed again.
	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(themeChanged:)
				name:TGThemeChangedNotification object:nil];

	// A secret chat's state is its header, and it can change while you
	// watch: the key exchange answers, or the other side closes the chat.
	[[TGMessageStore shared] secretChatIdForChat:self.chatId completion:^(NSInteger secretId, int64_t userId){
		if (!secretId)
			return;
		weakSelf.secretChatId = secretId;
		weakSelf.secretUserId = userId;
		if (&UIApplicationUserDidTakeScreenshotNotification)
			[[NSNotificationCenter defaultCenter] addObserver:weakSelf
					selector:@selector(secretScreenshotTaken:)
						name:UIApplicationUserDidTakeScreenshotNotification object:nil];
		[weakSelf refreshSecretState];
	}];

	[self loadPinnedMessage];

	if (self.chatId == [[TGMessageStore shared] savedMessagesChatId])
		subtitle.hidden = YES;
}

FOUNDATION_EXPORT void TGBubbleFlushCache(void);

- (void)themeChanged:(NSNotification *)note {
	TGBubbleFlushCache();
	[TGIcons flush];
	TGTheme *theme = [TGTheme shared];
	[self.layoutCache removeAllObjects];
	self.view.backgroundColor = [theme chatBackgroundColour];
	self.table.backgroundColor = [UIColor clearColor];
	self.inputBar.backgroundColor = [theme inputBarColour];
	// Clear: the rounded well behind the field carries the field's colour.
	// Painted here, the text view became an opaque square over the well on
	// every theme pass after the first - a finished wallpaper bake is one.
	self.input.backgroundColor = [UIColor clearColor];
	self.input.textColor = [theme primaryTextColour];
	self.input.layer.borderColor = [theme separatorColour].CGColor;
	self.input.keyboardAppearance = [theme isDark] ? UIKeyboardAppearanceDark : UIKeyboardAppearanceLight;
	// Repaint the composer plate and its placeholder in the new theme.
	[self updateComposerHeightAnimated:NO];
	self.sendButton.backgroundColor = [theme accentColour];
	self.wallpaperView.backgroundColor = [theme chatBackgroundColour];
	self.wallpaperView.image = [TGCapabilities canShowWallpaper] ? [theme wallpaper] : nil;
	self.titleNameLabel.textColor = [theme barTitleColour];
	self.titleSubtitleLabel.textColor = [theme barSubtitleColour];
	if (self.pinnedBannerView) {
		self.pinnedBannerView.backgroundColor = [theme inputBarColour];
		self.pinnedBannerHair.backgroundColor = [theme separatorColour];
	}
	if (self.recordPanel) {
		self.recordPanel.backgroundColor = [theme inputBarColour];
	}
	[self.stickerPanel applyTheme];
	[self applyChromeTheme:theme];
	if (self.editToolbar) {
		self.editToolbar.backgroundColor = [theme inputBarColour];
		[self.editDeleteButton setTitleColor:[theme destructiveColour] forState:UIControlStateNormal];
		[self.editForwardButton setTitleColor:[theme accentColour] forState:UIControlStateNormal];
	}
	[theme styleNavigationBar:self.navigationController.navigationBar];
	[self.table reloadData];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	sActiveChatId = self.chatId;
	self.pushAnimatingUntil = animated ? CACurrentMediaTime() + 0.38 : 0.0;
	[self installLiveHandlers];
	if (self.jumpButton)
		[self refreshUnreadJumps];
	if (self.readWhenShown.count) {
		[[TGMessageStore shared] markRead:self.readWhenShown inChat:self.chatId];
		[self.readWhenShown removeAllObjects];
	}
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	self.pushAnimatingUntil = 0.0;
	// Jump buttons, floating date and swipe-to-reply are invisible during the
	// push transition: building them here keeps them off frame 1 of open.
	if (!self.jumpButton) {
		[self buildChrome];
		[self installSwipeToReply];
		[self refreshUnreadJumps];
		[self layoutChrome];
	}
	if (self.pendingHistoryPage)
		[self applyPendingHistoryPage];
}

/// This chat's live feed. A listener of its own, so a chat pushed on top of
/// this one (profile > Send Message, a forwarded-from link) has its feed and
/// this one keeps hearing. Idempotent: called on every appearance, which is
/// also what brings the feed back after a back swipe that was cancelled.
/// Chat.SpeedLimitAlert: the title alone; the "N times faster" number comes
/// from the Premium configuration this client does not read.
- (void)speedLimited:(NSNotification *)note {
	if ([TGChatViewController activeChatId] != self.chatId)
		return;
	BOOL upload = [note.userInfo[@"upload"] boolValue];
	[TGSnackbar showInView:self.view
					  text:upload ? TGLocalized(@"Upload speed limited") : TGLocalized(@"Download speed limited")
				   seconds:3 onCommit:nil];
}

- (void)installLiveHandlers {
	if (self.liveListener)
		return;
	__weak typeof(self) weakSelf = self;
	self.liveListener = [[TGMessageStore shared] addListenerForChat:self.chatId
			onMessage:^(NSDictionary *message, int64_t deletedId){
			TGChatViewController *me = weakSelf;
			if (!me)
				return;
			int64_t chatId = me.chatId;

			if (message){
				// Reading further up: leave the place alone and count it on the
				// jump button instead. Your own message always brings you down.
				[[TGSendStore shared] adoptMessages:@[message] inChat:chatId];
				BOOL follow = [me isNearBottom] || [message[@"outgoing"] boolValue];
				[me.streamStore appendNewerMessages:@[message]];
				me.rawMessages = [me.streamStore messages];
				me.messages = [me groupedMessagesFromMessages:me.rawMessages];
				[me.table reloadData];
				if (follow) {
					[me scrollToBottomAnimated:YES];
				} else {
					[me noteArrivedWhileAway];
				}
				[me fetchMissingImages];
				// Read means seen. Under a profile or another chat this
				// screen still hears its messages; they are marked when it
				// is back on top (viewWillAppear).
				if ([TGChatViewController activeChatId] == chatId) {
					[[TGMessageStore shared] markRead:@[message[@"id"]] inChat:chatId];
				} else if (message[@"id"]) {
					if (!me.readWhenShown)
						me.readWhenShown = [NSMutableArray array];
					[me.readWhenShown addObject:message[@"id"]];
				}
				return;
			}
			if (deletedId > 0 && [me.streamStore removeMessageId:deletedId]){
				me.rawMessages = [me.streamStore messages];
				me.messages = [me groupedMessagesFromMessages:me.rawMessages];
				[me.table reloadData];
				return;
			}
			// Edited or unknown deletion: re-read, once the table stands
			// still. Reactions and views in a busy channel arrive every few
			// hundred ms, and each re-read rebuilt the whole table (1.5 s of
			// main thread on the iPod touch 4) in the middle of a scroll.
			[NSObject cancelPreviousPerformRequestsWithTarget:me
					selector:@selector(reloadWhenStill) object:nil];
			[me performSelector:@selector(reloadWhenStill) withObject:nil afterDelay:0.1];
		}
		onChatAction:^(NSString *action){
			[weakSelf showChatAction:action resting:weakSelf.restingSubtitle];
		}
		onSecretChat:^(NSInteger secretChatId, NSString *state){
			if (secretChatId != weakSelf.secretChatId)
				return;
			[weakSelf refreshSecretState];
		}];
}

/// A voice note going on playing after you have left the chat is the one thing
/// nobody expects, and the timer would outlive the screen it repaints.
- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	if (sActiveChatId == self.chatId)
		sActiveChatId = 0;
	if (self.voicePlayer)
		[self stopPlayback];
	[self stopVideoNote];
	// The GPS is the chat's, not the app's: a trace watched from this screen
	// stops being watched when the screen is gone.
	[self.locationManager stopUpdatingLocation];
	[TGSnackbar commitNow];
	// Dismissing the menu restores the held message through its onDismiss;
	// this covers the one window where the lift exists but its menu has not
	// been added yet.
	[TGPopupMenu dismiss];
	[self endHoldPresentation];

	[NSObject cancelPreviousPerformRequestsWithTarget:self.table];
	[NSObject cancelPreviousPerformRequestsWithTarget:self];

	if ([self isMovingFromParentViewController]) {
		// An unsent message is a draft, not something to throw away. Saved
		// before closeChat so the chat list redraws with it in place.
		//
		// Only when it actually differs from the draft already there. It used
		// to be sent on the way out of every chat, which meant a clear-draft
		// request for every chat anybody ever opened - and in a channel this
		// account does not administer Telegram refuses it, so the device log
		// filled with "Need administrator rights in the channel chat" for
		// drafts nobody had typed.
		NSString *typed = self.input.text ?: @"";
		NSString *stored = [[TGMessageStore shared] draftForChat:self.chatId] ?: @"";
		if (self.editingId == 0 && ![typed isEqualToString:stored])
			[[TGMessageStore shared] setDraft:typed
								 inChat:self.chatId
								 thread:self.threadId
								replyTo:self.replyToId];
		if (!TGIsDevChat(self.chatId)) {
			[[TGMessageStore shared] cancelTypingInChat:self.chatId thread:self.threadId];
			[[TGMessageStore shared] closeChat:self.chatId];
		}
		[[NSNotificationCenter defaultCenter] removeObserver:self
				name:TGMessageStoreChangedNotification object:nil];
		[[TGMessageStore shared] removeChatListener:self.liveListener];
		self.liveListener = nil;
		[self stopChrome];
		[TGMessageStore shared].onFileProgress = nil;
		[self.images removeAllObjects];
		[self.imagesRequested removeAllObjects];
		[self.senderAvatars removeAllObjects];
		[self.senderAvatarsRequested removeAllObjects];
		[self.maps removeAllObjects];
		[self.mapsRequested removeAllObjects];
		[self.quotes removeAllObjects];
		[self.quotesRequested removeAllObjects];
		[self.layoutCache removeAllObjects];
		[self.lottiePaths removeAllObjects];
		[self.playedAnimations removeAllObjects];
	}
}

/// Keeps only the photos on screen. Nothing used to answer a memory warning,
/// so the next step after one was jetsam; an evicted photo comes back when its
/// row is drawn again (fetchImageForMessage:).
- (void)memoryWarning:(NSNotification *)note {
	NSMutableArray *keepIds = [NSMutableArray array];
	NSMutableArray *keepImages = [NSMutableArray array];
	for (NSIndexPath *path in self.table.indexPathsForVisibleRows) {
		if (path.row >= (NSInteger)self.messages.count)
			continue;
		NSDictionary *m = self.messages[path.row];
		NSArray *parts = [m[@"albumMessages"] isKindOfClass:NSArray.class] ? m[@"albumMessages"] : @[m];
		for (NSDictionary *part in parts) {
			NSNumber *fileId = part[@"photoId"];
			UIImage *img = [fileId isKindOfClass:NSNumber.class] ? self.images[fileId] : nil;
			if (img) {
				[keepIds addObject:fileId];
				[keepImages addObject:img];
			}
		}
	}
	[self.images removeAllObjects];
	for (NSUInteger i = 0; i < keepIds.count; i++)
		self.images[keepIds[i]] = keepImages[i];
	[self.senderAvatars removeAllObjects];
	[self.senderAvatarsRequested removeAllObjects];
	NSLog(@"memory warning: chat kept %lu photos", (unsigned long)keepIds.count);
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
						change:(NSDictionary *)change context:(void *)context {
	if (context != &kTGTableContentSizeContext) {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
		return;
	}
	if (self.anchorToBottom && !self.table.isTracking && !self.table.isDecelerating)
		[self scrollToBottomAnimated:NO];
}

- (void)dealloc {
	[self.table removeObserver:self forKeyPath:@"contentSize" context:&kTGTableContentSizeContext];
	// iOS 6 holds these delegates unretained. The table outlives this screen
	// while a pop or a scroll animation finishes, and its next layout pass
	// asked a freed controller for rows: SIGSEGV in objc_msgSend under
	// CoreAnimation's commit, twice on the iPod touch 4 on 18-19 November.
	self.table.delegate = nil;
	self.table.dataSource = nil;
	self.input.delegate = nil;
	self.chatSearchBar.delegate = nil;
	self.touchRecorder.delegate = nil;
	self.locationManager.delegate = nil;
	[NSObject cancelPreviousPerformRequestsWithTarget:self.table];
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[self.playbackTimer invalidate];
	self.playbackTimer = nil;
	[self.recordTimer invalidate];
	self.recordTimer = nil;
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	// A screen thrown away with its window (an account switch) never gets
	// viewWillDisappear; the client must not keep its listener.
	[[TGMessageStore shared] removeChatListener:self.liveListener];
}


@end
