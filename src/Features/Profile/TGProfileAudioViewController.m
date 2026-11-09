#import "TGProfileAudioViewController.h"
#import "TGAlertSheet.h"
#import "TGClient.h"
#import "TGMediaStore.h"
#import "TGMusicPlayer.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGSnackbar.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import "TGRows.h"

/// One page of the saved-music list. The old screen asked for 100 once and
/// showed the total above it, so anything past the first 100 never appeared.
static const NSInteger kProfileAudioPage = 100;

/// The shared peer row draws a circular picture; the track still needs its
/// cover and its play/pause disc, so the two are composed before the row gets
/// them. No cover keeps the old music-note tile.
static UIImage *TGProfileAudioArtwork(UIImage *cover, BOOL playing) {
	CGFloat side = TGMetricTrackArt;
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), NO, 0);
	CGRect rect = CGRectMake(0, 0, side, side);
	if (cover){
		[cover drawInRect:rect];
	} else {
		TGTheme *theme = [TGTheme shared];
		[theme.fileTileColour setFill];
		UIRectFill(rect);
		UIImage *glyph = [TGIcons glyphNamed:@"music"
				colour:[theme secondaryTextColour] side:TGMetricMenuGlyph];
		CGFloat glyphSide = TGMetricMenuGlyph;
		[glyph drawInRect:CGRectMake(TGCenteredOrigin(side, glyphSide),
				TGCenteredOrigin(side, glyphSide), glyphSide, glyphSide)];
	}
	CGFloat discSide = TGMetricTrackDisc;
	UIImage *disc = [TGIcons mediaDiscOfSide:discSide playing:playing];
	[disc drawInRect:CGRectMake(TGCenteredOrigin(side, discSide),
			TGCenteredOrigin(side, discSide), discSide, discSide)];
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

@interface TGProfileAudioViewController ()
@property (nonatomic, strong) NSArray *audios;
@property (nonatomic, assign) NSInteger total;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL loadingMore;
@property (nonatomic, strong) NSMutableDictionary *covers;
@property (nonatomic, strong) NSMutableSet *coversRequested;
@end

@implementation TGProfileAudioViewController

- (BOOL)isOwnProfile {
	return self.userId == [[TGClient shared].me[@"id"] longLongValue];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = self.subjectTitle.length ? self.subjectTitle
			: TGLocalized(@"Profile Music");
	self.audios = @[];
	self.covers = [NSMutableDictionary dictionary];
	self.coversRequested = [NSMutableSet set];
	[self applyTheme];
	if ([self isOwnProfile])
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
				initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
									 target:self action:@selector(addTapped)];
	// A row's verbs do not fit on a tap: the hold is the menu.
	UILongPressGestureRecognizer *hold = [[UILongPressGestureRecognizer alloc]
			initWithTarget:self action:@selector(rowHeld:)];
	hold.minimumPressDuration = TGAnimationDurationHighlight;
	[self.tableView addGestureRecognizer:hold];
	[self load];
	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(playerChanged)
				name:TGMusicPlayerChangedNotification object:nil];
}

- (void)applyTheme {
	[super applyTheme];
	if (self.audios)
		[self rebuildSections];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)load {
	if (self.loading)
		return;
	self.loading = YES;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] profileAudiosForUser:self.userId offset:0 limit:kProfileAudioPage
								 completion:^(NSArray *audios, NSInteger total,
											  NSString *error){
		TGProfileAudioViewController *me = weakSelf;
		if (!me)
			return;
		me.loading = NO;
		if (error.length){
			[TGAlertSheet showMessage:error title:TGLocalized(@"Profile Music")
								inView:me.view];
			return;
		}
		me.audios = audios ?: @[];
		me.total = total ?: (NSInteger)me.audios.count;
		[me rebuildSections];
		if (me.autoplay && me.audios.count){
			me.autoplay = NO;
			[me playAtIndex:0];
		}
	}];
}

/// The list is paged by the same offset the first request starts at, so the
/// total above it and the rows below it finally agree.
- (void)loadMore {
	if (self.loading || self.loadingMore || !self.audios.count)
		return;
	if (self.total > 0 && (NSInteger)self.audios.count >= self.total)
		return;
	self.loadingMore = YES;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] profileAudiosForUser:self.userId
									 offset:(NSInteger)self.audios.count
									  limit:kProfileAudioPage
								 completion:^(NSArray *audios, NSInteger total,
											  NSString *error){
		TGProfileAudioViewController *me = weakSelf;
		if (!me)
			return;
		me.loadingMore = NO;
		if (error.length || !audios.count){
			if (total > 0)
				me.total = total;
			return;
		}
		me.total = total ?: (NSInteger)(me.audios.count + audios.count);
		me.audios = [me.audios arrayByAddingObjectsFromArray:audios];
		[me rebuildSections];
	}];
}

- (void)playerChanged {
	// The current row wears a pause glyph and the accent title. The player
	// holds one queue, so any of its state changes can be the row's.
	[self rebuildSections];
}

- (NSString *)durationText:(NSNumber *)seconds {
	NSInteger value = [seconds integerValue];
	if (value <= 0)
		return @"";
	return [NSString stringWithFormat:@"%ld:%02ld", (long)(value / 60),
			(long)(value % 60)];
}

#pragma mark - rows

- (void)requestCover:(NSNumber *)coverId {
	if (!coverId || [self.coversRequested containsObject:coverId])
		return;
	[self.coversRequested addObject:coverId];
	__weak typeof(self) weakSelf = self;
	[[TGMediaStore shared] downloadFile:coverId.integerValue
			priority:TGDownloadPriorityOnScreen
			completion:^(NSString *path){
		TGProfileAudioViewController *me = weakSelf;
		if (!me || !path.length)
			return;
		UIImage *image = [TGIcons decodedImageAtPath:path
				fittingSize:CGSizeMake(TGMetricTrackArt, TGMetricTrackArt)
						 fill:YES
						scale:[UIScreen mainScreen].scale];
		if (!image)
			return;
		me.covers[coverId] = image;
		[me rebuildSections];
	}];
}

- (void)rebuildSections {
	__weak typeof(self) weakSelf = self;
	NSInteger count = self.total > 0 ? self.total : (NSInteger)self.audios.count;
	NSString *header = self.audios.count
			? TGLocalizedPluralValue(@"%@ track", @"%@ tracks",
					[NSString stringWithFormat:@"%ld", (long)count], count)
			: nil;
	NSString *footer = self.audios.count ? nil : TGLocalized(@"No music");

	TGMusicPlayer *player = [TGMusicPlayer shared];
	NSMutableArray *rows = [NSMutableArray array];
	for (NSUInteger index = 0; index < self.audios.count; index++){
		NSDictionary *audio = self.audios[index];
		NSString *title = [audio[@"title"] length] ? audio[@"title"]
				: ([audio[@"fileName"] length] ? audio[@"fileName"]
						: TGLocalized(@"Audio"));
		NSString *performer = [audio[@"performer"] length]
				? audio[@"performer"] : TGLocalized(@"Unknown artist");
		NSInteger messageId = [audio[@"fileId"] longLongValue];
		BOOL current = player.currentMessageId == messageId;

		NSNumber *coverId = [audio[@"albumCoverId"] isKindOfClass:NSNumber.class]
				? audio[@"albumCoverId"] : nil;
		UIImage *cover = coverId ? self.covers[coverId] : nil;
		if (coverId && !cover)
			[self requestCover:coverId];

		NSMutableDictionary *row = TGPeerRow(@(messageId), title, performer,
				^{ [weakSelf playAtIndex:(NSInteger)index]; });
		row[TGRowHeight] = @(TGMetricTrackRow);
		row[TGRowAccessory] = [self durationText:audio[@"duration"]];
		row[TGRowAvatarImage] = TGProfileAudioArtwork(cover,
				current && player.playing);
		if (current)
			row[TGRowTitleColour] = [[TGTheme shared] accentColour];
		[rows addObject:row];
	}
	self.sections = @[TGSection(header, footer, rows)];
	[self reloadRows];
}

#pragma mark - table

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	CGFloat distance = scrollView.contentSize.height -
			(scrollView.contentOffset.y + scrollView.bounds.size.height);
	if (distance < TGMetricTrackRow * 3.0f)
		[self loadMore];
}

- (void)playAtIndex:(NSInteger)index {
	if (index < 0 || index >= (NSInteger)self.audios.count)
		return;
	NSMutableArray *tracks = [NSMutableArray array];
	for (NSDictionary *audio in self.audios){
		NSNumber *fileId = audio[@"fileId"] ?: @(0);
		[tracks addObject:@{
			@"kind" : @"messageAudio",
			// The player marks the current row by message id. Saved tracks
			// have no message, so their file id is the stable stand-in.
			@"id" : fileId,
			@"docId" : fileId,
			@"audioTitle" : audio[@"title"] ?: @"",
			@"audioPerformer" : audio[@"performer"] ?: @"",
			@"duration" : audio[@"duration"] ?: @(0),
			@"albumCoverId" : audio[@"albumCoverId"] ?: [NSNull null],
		}];
	}
	[[TGMusicPlayer shared] playTracks:tracks atIndex:index inChat:0];
	[TGSnackbar showInView:self.view
					  text:[NSString stringWithFormat:TGLocalized(@"Playing %@"),
							  self.audios[(NSUInteger)index][@"title"]
									  ?: TGLocalized(@"audio")]
				   seconds:2 onCommit:nil];
}

#pragma mark - own profile: reorder and remove

/// The order operations all go through one sheet so the row number the user
/// sees is the row number sent, not an index into a filtered list.
- (void)rowHeld:(UILongPressGestureRecognizer *)hold {
	if (hold.state != UIGestureRecognizerStateBegan)
		return;
	CGPoint where = [hold locationInView:self.tableView];
	NSIndexPath *path = [self.tableView indexPathForRowAtPoint:where];
	if (!path || path.section != 0 ||
		path.row >= (NSInteger)self.audios.count)
		return;
	NSDictionary *audio = self.audios[(NSUInteger)path.row];
	NSMutableArray *choices = [NSMutableArray arrayWithObjects:
			TGLocalized(@"Play"), TGLocalized(@"View in Profile"), nil];
	BOOL own = [self isOwnProfile];
	if (own){
		[choices addObject:TGLocalized(@"Move Up")];
		if (path.row > 0)
			[choices addObject:TGLocalized(@"Move Down")];
		[choices addObject:TGLocalized(@"Remove from Profile")];
	}
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:choices
						title:(audio[@"title"] ?: TGLocalized(@"Audio"))
			 destructiveIndex:(own ? (NSInteger)choices.count - 1 : -1)
					   inView:self.view
					 onChoice:^(NSInteger index){
		NSString *choice = choices[(NSUInteger)index];
		if ([choice isEqualToString:TGLocalized(@"Play")]){
			[weakSelf playAtIndex:path.row];
			return;
		}
		if ([choice isEqualToString:TGLocalized(@"View in Profile")]){
			[weakSelf checkAudio:audio];
			return;
		}
		if ([choice isEqualToString:TGLocalized(@"Move Up")]){
			[weakSelf moveAudio:audio after:0];
			return;
		}
		if ([choice isEqualToString:TGLocalized(@"Move Down")]){
			NSDictionary *previous = weakSelf.audios[(NSUInteger)path.row - 1];
			[weakSelf moveAudio:audio
						  after:[previous[@"fileId"] integerValue]];
			return;
		}
		if ([choice isEqualToString:TGLocalized(@"Remove from Profile")])
			[weakSelf removeAudio:audio];
	}];
}

- (void)checkAudio:(NSDictionary *)audio {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] isProfileAudioFileId:[audio[@"fileId"] integerValue]
								 completion:^(BOOL isAudio, NSString *error){
		NSString *text = isAudio
				? TGLocalized(@"An error occurred.")
				: ([error length] ? error
						: TGLocalized(@"An error occurred."));
		[TGAlertSheet showMessage:text title:TGLocalized(@"Profile Music")
						   inView:weakSelf.view];
	}];
}

- (void)moveAudio:(NSDictionary *)audio after:(NSInteger)afterFileId {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setProfileAudioFileId:[audio[@"fileId"] integerValue]
								 afterFileId:afterFileId
								  completion:^(BOOL ok, NSString *error){
		if (!ok){
			[TGAlertSheet showMessage:(error ?: TGLocalized(@"An error occurred."))
								title:TGLocalized(@"Profile Music")
							   inView:weakSelf.view];
			return;
		}
		[weakSelf load];
	}];
}

- (void)removeAudio:(NSDictionary *)audio {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:TGLocalized(@"Remove from Profile")
						title:(audio[@"title"] ?: TGLocalized(@"Profile Music"))
					   action:TGLocalized(@"Remove")
				  destructive:YES
					   inView:self.view
					onConfirm:^{
		[[TGClient shared] removeProfileAudioFileId:
				[audio[@"fileId"] integerValue]
										 completion:^(BOOL ok, NSString *error){
			if (!ok){
				[TGAlertSheet showMessage:
						(error ?: TGLocalized(@"An error occurred."))
									title:TGLocalized(@"Profile Music")
								   inView:weakSelf.view];
				return;
			}
			[weakSelf load];
		}];
	}];
}

#pragma mark - adding from Saved Messages

/// There is no document picker on this OS, but the files TDLib already holds
/// are a real source: pick an audio message from Saved Messages, download its
/// bytes, and add that path. The profile is the account's own list, so a
/// track already sent to Saved Messages is the honest way in.
- (void)addTapped {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] historyForChat:[[TGClient shared] savedMessagesChatId]
								limit:100
						   completion:^(NSArray *messages){
		TGProfileAudioViewController *me = weakSelf;
		if (!me)
			return;
		NSMutableArray *tracks = [NSMutableArray array];
		for (NSDictionary *message in messages)
			if ([message[@"kind"] isEqualToString:@"messageAudio"])
				[tracks addObject:message];
		if (!tracks.count){
			[TGAlertSheet showMessage:TGLocalized(@"An error occurred.")
								title:TGLocalized(@"Add to Profile")
							   inView:me.view];
			return;
		}
		NSMutableArray *titles = [NSMutableArray array];
		for (NSDictionary *track in tracks)
			[titles addObject:[NSString stringWithFormat:
					TGLocalized(@"%@ — %@"),
					track[@"audioTitle"] ?: track[@"docName"]
							?: TGLocalized(@"Audio"),
					track[@"audioPerformer"] ?: TGLocalized(@"Unknown artist")]];
		[TGAlertSheet showChoices:titles title:TGLocalized(@"Add to Profile")
				destructiveIndex:-1 inView:me.view onChoice:^(NSInteger index){
			[me addTrack:tracks[(NSUInteger)index]];
		}];
	}];
}

- (void)addTrack:(NSDictionary *)track {
	NSNumber *fileId = track[@"docId"];
	if ([fileId longLongValue] <= 0){
		[TGAlertSheet showMessage:TGLocalized(@"An error occurred.")
							title:TGLocalized(@"Add to Profile") inView:self.view];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGMediaStore shared] downloadFile:fileId.integerValue
						 completion:^(NSString *path){
		TGProfileAudioViewController *me = weakSelf;
		if (!me || !path.length){
			[TGAlertSheet showMessage:TGLocalized(@"An error occurred.")
								title:TGLocalized(@"Add to Profile")
							   inView:me.view];
			return;
		}
		[[TGClient shared] addProfileAudioAtPath:path
										   title:track[@"audioTitle"] ?: @""
									   performer:track[@"audioPerformer"] ?: @""
										duration:[track[@"duration"] integerValue]
									  completion:^(BOOL ok, NSString *error){
			if (!ok){
				[TGAlertSheet showMessage:
						(error ?: TGLocalized(@"An error occurred."))
									title:TGLocalized(@"Add to Profile")
								   inView:me.view];
				return;
			}
			[me load];
		}];
	}];
}

@end

// vim:ft=objc
