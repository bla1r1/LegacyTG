#import "TGStoryAlbumsViewController.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGMediaStore.h"
#import "TGStoryViewerViewController.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import "TGRows.h"

/// Album story dates use the app language, not the device locale.
static NSString *TGStoryAlbumDateText(NSNumber *unixTime) {
	static NSDateFormatter *formatter = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		formatter = [[NSDateFormatter alloc] init];
		[formatter setDateStyle:NSDateFormatterMediumStyle];
		[formatter setTimeStyle:NSDateFormatterShortStyle];
	});
	if (![unixTime isKindOfClass:NSNumber.class] || unixTime.doubleValue <= 0)
		return @"-";
	NSString *language = TGAppLanguage();
	formatter.locale = language.length
			? [NSLocale localeWithLocaleIdentifier:language]
			: [NSLocale currentLocale];
	return [formatter stringFromDate:
			[NSDate dateWithTimeIntervalSince1970:unixTime.doubleValue]];
}

/// The picture is a peer-row picture: the album's own photo when it has one,
/// otherwise the "A" tile the old row drew.
static UIImage *TGStoryAlbumPicture(NSString *path, NSNumber *albumId) {
	if (path.length){
		UIImage *image = [TGIcons decodedImageAtPath:path
				fittingSize:CGSizeMake(TGMetricListAvatar, TGMetricListAvatar)
						 fill:YES
						scale:[UIScreen mainScreen].scale];
		if (image)
			return image;
	}
	return [TGIcons avatarWithInitials:@"A" size:TGMetricListAvatar
							  colourId:albumId.longLongValue];
}

/// The album list draws the album record (id and name); its stories are read
/// only when the album opens, which is one request instead of N.
@interface TGStoryAlbumsViewController ()
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, assign) int32_t storyToAdd;
@property (nonatomic, strong) NSMutableArray *albums;
@property (nonatomic, strong) NSMutableDictionary *pictures;
@property (nonatomic, strong) NSMutableSet *picturesRequested;
@end

/// One album's stories with add, remove and drag-to-order. Private because
/// no other screen should need the album id without going through the list.
@interface TGStoryAlbumDetailViewController : TGRowsViewController
- (instancetype)initWithChatId:(int64_t)chatId
					   albumId:(int32_t)albumId
						  name:(NSString *)name;
@end

@implementation TGStoryAlbumsViewController

- (instancetype)initWithChatId:(int64_t)chatId storyToAdd:(int32_t)storyId {
	self = [super init];
	if (self){
		_chatId = chatId;
		_storyToAdd = storyId;
		_albums = [NSMutableArray array];
		_pictures = [NSMutableDictionary dictionary];
		_picturesRequested = [NSMutableSet set];
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGLocalized(@"Albums");
	self.navigationItem.rightBarButtonItems = @[
		[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
				target:self action:@selector(createAlbum)],
		self.editButtonItem,
	];
	[self reloadAlbums];
	[self rebuildSections];
}

- (void)reloadAlbums {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] storyAlbumsForChat:self.chatId completion:^(NSArray *albums){
		TGStoryAlbumsViewController *me = weakSelf;
		if (!me)
			return;
		me.albums = [albums mutableCopy] ?: [NSMutableArray array];
		[me rebuildSections];
	}];
}

- (void)createAlbum {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:TGLocalized(@"New Album")
					message:nil
				placeholder:TGLocalized(@"Album")
					   text:nil
					 action:TGLocalized(@"Create")
					 inView:self.view
				   onSubmit:^(NSString *name){
		TGStoryAlbumsViewController *me = weakSelf;
		if (!me)
			return;
		[[TGClient shared] createStoryAlbumNamed:name
										  inChat:me.chatId
										storyIds:@[]
									  completion:^(NSDictionary *album, NSString *error){
			if (!album){
				[TGAlertSheet showMessage:(error ?: TGLocalized(@"An error occurred."))
									title:TGLocalized(@"New Album") inView:me.view];
				return;
			}
			[me reloadAlbums];
		}];
	}];
}

#pragma mark - rows

- (UIImage *)pictureForAlbum:(NSDictionary *)album {
	NSNumber *albumId = @([album[@"albumId"] longLongValue]);
	UIImage *cached = self.pictures[albumId];
	if (cached)
		return cached;

	NSNumber *photoId = album[@"photoFileId"];
	if ([photoId isKindOfClass:NSNumber.class] && photoId.integerValue > 0){
		if (![self.picturesRequested containsObject:albumId]){
			[self.picturesRequested addObject:albumId];
			__weak typeof(self) weakSelf = self;
			[[TGMediaStore shared] downloadFile:photoId.integerValue
					priority:TGDownloadPriorityOnScreen
					completion:^(NSString *path){
				TGStoryAlbumsViewController *me = weakSelf;
				if (!me)
					return;
				UIImage *image = TGStoryAlbumPicture(path, albumId);
				if (image){
					me.pictures[albumId] = image;
					[me rebuildSections];
				}
			}];
		}
		return nil;
	}
	return [TGIcons avatarWithInitials:@"A" size:TGMetricListAvatar
							  colourId:albumId.longLongValue];
}

- (void)rebuildSections {
	__weak typeof(self) weakSelf = self;
	NSMutableArray *rows = [NSMutableArray array];
	if (!self.albums.count){
		[rows addObject:TGRow(TGKindPlain, TGLocalized(@"No Results"))];
	} else {
		for (NSUInteger index = 0; index < self.albums.count; index++){
			NSDictionary *album = self.albums[index];
			NSNumber *albumId = @([album[@"albumId"] longLongValue]);
			NSMutableDictionary *row = TGPeerRow(albumId,
					album[@"name"] ?: TGLocalized(@"Album"), nil,
					^{ [weakSelf albumTappedAtIndex:(NSInteger)index]; });
			UIImage *picture = [self pictureForAlbum:album];
			if (picture)
				row[TGRowAvatarImage] = picture;
			if (!self.storyToAdd)
				row[TGRowAccessory] = TGRowAccessoryDisclosure;
			[rows addObject:row];
		}
	}
	self.sections = @[TGSection(nil, nil, rows)];
	[self reloadRows];
}

#pragma mark - choosing

- (void)albumTappedAtIndex:(NSInteger)index {
	if (index < 0 || index >= (NSInteger)self.albums.count)
		return;
	NSDictionary *album = self.albums[(NSUInteger)index];
	int32_t albumId = [album[@"albumId"] intValue];
	if (self.storyToAdd){
		__weak typeof(self) weakSelf = self;
		[TGAlertSheet showConfirm:TGLocalized(@"Add to Album")
							title:TGLocalized(@"Album")
						   action:TGLocalized(@"Add")
					  destructive:NO
						   inView:self.view
						onConfirm:^{
			TGStoryAlbumsViewController *me = weakSelf;
			if (!me)
				return;
			[[TGClient shared] addStories:@[@(me.storyToAdd)]
								toAlbum:albumId
								 inChat:me.chatId
							 completion:^(NSDictionary *changed, NSString *error){
				if (!changed){
					[TGAlertSheet showMessage:(error ?: TGLocalized(@"An error occurred."))
										title:TGLocalized(@"Album") inView:me.view];
					return;
				}
				[me.navigationController popViewControllerAnimated:YES];
			}];
		}];
		return;
	}
	TGStoryAlbumDetailViewController *detail = [[TGStoryAlbumDetailViewController alloc]
			initWithChatId:self.chatId albumId:albumId
					 name:album[@"name"] ?: TGLocalized(@"Album")];
	detail.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:detail animated:YES];
}

#pragma mark - editing

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
	return indexPath.row < (NSInteger)self.albums.count;
}

- (void)tableView:(UITableView *)tableView
		moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath
			  toIndexPath:(NSIndexPath *)destinationIndexPath {
	NSMutableArray *albums = self.albums;
	NSDictionary *album = albums[(NSUInteger)sourceIndexPath.row];
	[albums removeObjectAtIndex:(NSUInteger)sourceIndexPath.row];
	[albums insertObject:album atIndex:MIN((NSUInteger)destinationIndexPath.row,
										   albums.count)];
	NSMutableArray *ids = [NSMutableArray array];
	for (NSDictionary *item in albums)
		[ids addObject:item[@"albumId"] ?: @(0)];
	[self rebuildSections];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] reorderStoryAlbums:ids inChat:self.chatId
							   completion:^(BOOL ok, NSString *error){
		if (!ok){
			TGStoryAlbumsViewController *me = weakSelf;
			[TGAlertSheet showMessage:(error ?: TGLocalized(@"An error occurred."))
								title:TGLocalized(@"Albums") inView:me.view];
			[me reloadAlbums];
		}
	}];
}

- (void)tableView:(UITableView *)tableView
		commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
		 forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle != UITableViewCellEditingStyleDelete ||
		indexPath.row >= (NSInteger)self.albums.count)
		return;
	NSDictionary *album = self.albums[(NSUInteger)indexPath.row];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] deleteStoryAlbum:[album[@"albumId"] intValue]
								 inChat:self.chatId
							 completion:^(BOOL ok, NSString *error){
		TGStoryAlbumsViewController *me = weakSelf;
		if (!ok){
			[TGAlertSheet showMessage:(error ?: TGLocalized(@"An error occurred."))
								title:TGLocalized(@"Albums") inView:me.view];
			return;
		}
		[me reloadAlbums];
	}];
}

@end

#pragma mark - one album

@interface TGStoryAlbumDetailViewController ()
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, assign) int32_t albumId;
@property (nonatomic, copy) NSString *albumName;
@property (nonatomic, strong) NSMutableArray *stories;
@property (nonatomic, strong) NSMutableDictionary *pictures;
@property (nonatomic, strong) NSMutableSet *picturesRequested;
@end

@implementation TGStoryAlbumDetailViewController

- (instancetype)initWithChatId:(int64_t)chatId
					   albumId:(int32_t)albumId
						  name:(NSString *)name {
	self = [super init];
	if (self){
		_chatId = chatId;
		_albumId = albumId;
		_albumName = [name copy] ?: TGLocalized(@"Album");
		_stories = [NSMutableArray array];
		_pictures = [NSMutableDictionary dictionary];
		_picturesRequested = [NSMutableSet set];
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = self.albumName;
	self.navigationItem.rightBarButtonItems = @[
		[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
				target:self action:@selector(addStory)],
		[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"More")
				style:UIBarButtonItemStylePlain
				target:self action:@selector(albumMenu)],
		self.editButtonItem,
	];
	[self reloadStories];
	[self rebuildSections];
}

- (void)reloadStories {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] storiesInAlbum:self.albumId inChat:self.chatId
								offset:0 limit:60
							completion:^(NSArray *stories, NSString *error){
		TGStoryAlbumDetailViewController *me = weakSelf;
		if (!me)
			return;
		me.stories = [stories mutableCopy] ?: [NSMutableArray array];
		[me rebuildSections];
		if (error.length)
			[TGAlertSheet showMessage:error title:TGLocalized(@"Album")
								inView:me.view];
	}];
}

- (void)albumMenu {
	NSArray *choices = @[TGLocalized(@"Rename Album"),
			TGLocalized(@"Delete Album")];
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:choices title:self.albumName destructiveIndex:1
					   inView:self.view onChoice:^(NSInteger choice){
		TGStoryAlbumDetailViewController *me = weakSelf;
		if (!me)
			return;
		if (choice == 0){
			[me renameAlbum];
			return;
		}
		[TGAlertSheet showConfirm:TGLocalized(@"Delete Album")
							title:TGLocalized(@"Delete Album")
						   action:TGLocalized(@"Delete")
					  destructive:YES
						   inView:me.view
						onConfirm:^{
			[[TGClient shared] deleteStoryAlbum:me.albumId
										 inChat:me.chatId
									 completion:^(BOOL ok, NSString *error){
				if (!ok){
					[TGAlertSheet showMessage:(error ?: TGLocalized(@"An error occurred."))
										title:TGLocalized(@"Album") inView:me.view];
					return;
				}
				[me.navigationController popViewControllerAnimated:YES];
			}];
		}];
	}];
}

- (void)renameAlbum {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:TGLocalized(@"Rename Album")
					message:nil
				placeholder:TGLocalized(@"Album")
					   text:self.albumName
					 action:TGLocalized(@"Save")
					 inView:self.view
				   onSubmit:^(NSString *name){
		TGStoryAlbumDetailViewController *me = weakSelf;
		if (!me)
			return;
		[[TGClient shared] setStoryAlbumName:name
									 albumId:me.albumId
									  inChat:me.chatId
								  completion:^(NSDictionary *album, NSString *error){
			if (!album){
				[TGAlertSheet showMessage:(error ?: TGLocalized(@"An error occurred."))
									title:TGLocalized(@"Album") inView:me.view];
				return;
			}
			me.albumName = album[@"name"] ?: name;
			me.title = me.albumName;
			[me rebuildSections];
		}];
	}];
}

- (void)addStory {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] archivedStoryIdsForChat:self.chatId fromStoryId:0 limit:30
								   completion:^(NSArray *storyIds, NSString *error){
		TGStoryAlbumDetailViewController *me = weakSelf;
		if (!me)
			return;
		if (!storyIds.count){
			[TGAlertSheet showMessage:(error ?: TGLocalized(@"An error occurred."))
								title:TGLocalized(@"Album") inView:me.view];
			return;
		}
		NSMutableArray *wanted = [NSMutableArray array];
		for (NSNumber *storyId in storyIds){
			BOOL already = NO;
			for (NSDictionary *story in me.stories)
				if ([story[@"storyId"] isEqualToNumber:storyId]){
					already = YES;
					break;
				}
			if (!already)
				[wanted addObject:storyId];
		}
		if (!wanted.count){
			[TGAlertSheet showMessage:TGLocalized(@"An error occurred.")
								title:TGLocalized(@"Album") inView:me.view];
			return;
		}
		NSMutableArray *titles = [NSMutableArray array];
		for (NSNumber *storyId in wanted)
			[titles addObject:[NSString stringWithFormat:TGLocalized(@"Story %@"),
					storyId]];
		[TGAlertSheet showChoices:titles title:TGLocalized(@"Add Story")
				destructiveIndex:-1 inView:me.view onChoice:^(NSInteger choice){
			if (choice < 0 || choice >= (NSInteger)wanted.count)
				return;
			[[TGClient shared] addStories:@[wanted[(NSUInteger)choice]]
								toAlbum:me.albumId
								 inChat:me.chatId
							 completion:^(NSDictionary *album, NSString *error){
				if (!album){
					[TGAlertSheet showMessage:(error ?: TGLocalized(@"An error occurred."))
										title:TGLocalized(@"Album") inView:me.view];
					return;
				}
				[me reloadStories];
			}];
		}];
	}];
}

#pragma mark - rows

- (UIImage *)pictureForStory:(NSDictionary *)story {
	NSNumber *storyId = @([story[@"storyId"] longLongValue]);
	UIImage *cached = self.pictures[storyId];
	if (cached)
		return cached;

	NSNumber *photoId = story[@"thumbPhotoId"] ?: story[@"photoId"];
	if ([photoId isKindOfClass:NSNumber.class] && photoId.integerValue > 0 &&
		![self.picturesRequested containsObject:storyId]){
		[self.picturesRequested addObject:storyId];
		__weak typeof(self) weakSelf = self;
		[[TGMediaStore shared] downloadFile:photoId.integerValue
				priority:TGDownloadPriorityOnScreen
				completion:^(NSString *path){
			TGStoryAlbumDetailViewController *me = weakSelf;
			if (!me)
				return;
			UIImage *image = path.length ? [TGIcons decodedImageAtPath:path
					fittingSize:CGSizeMake(TGMetricListAvatar, TGMetricListAvatar)
							 fill:YES
							scale:[UIScreen mainScreen].scale] : nil;
			if (!image)
				return;
			me.pictures[storyId] = image;
			[me rebuildSections];
		}];
	}
	return nil;
}

- (void)rebuildSections {
	__weak typeof(self) weakSelf = self;
	NSMutableArray *rows = [NSMutableArray array];
	if (!self.stories.count){
		[rows addObject:TGRow(TGKindPlain, TGLocalized(@"No Stories"))];
	} else {
		for (NSUInteger index = 0; index < self.stories.count; index++){
			NSDictionary *story = self.stories[index];
			NSString *caption = [story[@"caption"] isKindOfClass:NSString.class]
					? story[@"caption"] : nil;
			NSString *title = caption.length ? caption : TGLocalized(@"Story");
			NSInteger viewers = (NSInteger)[story[@"viewers"] integerValue];
			NSString *views = TGLocalizedPluralValue(@"%@ view", @"%@ views",
					[NSString stringWithFormat:@"%ld", (long)viewers], viewers);
			NSString *detail = [NSString stringWithFormat:@"%@ · %@", views,
					TGStoryAlbumDateText(story[@"date"])];
			NSNumber *storyId = @([story[@"storyId"] longLongValue]);
			NSMutableDictionary *row = TGPeerRow(storyId, title, detail,
					^{ [weakSelf openStoryAtIndex:(NSInteger)index]; });
			UIImage *picture = [self pictureForStory:story];
			if (picture)
				row[TGRowAvatarImage] = picture;
			[rows addObject:row];
		}
	}
	self.sections = @[TGSection(nil, nil, rows)];
	[self reloadRows];
}

- (void)openStoryAtIndex:(NSInteger)index {
	if (index < 0 || index >= (NSInteger)self.stories.count)
		return;
	__weak typeof(self) weakSelf = self;
	TGStoryViewerViewController *viewer = [[TGStoryViewerViewController alloc]
			initWithChatId:self.chatId
					 title:self.albumName
				   stories:self.stories
				startIndex:index
				 canManage:YES];
	viewer.hidesBottomBarWhenPushed = YES;
	viewer.onStoriesChanged = ^{ [weakSelf reloadRows]; };
	[self.navigationController pushViewController:viewer animated:YES];
}

#pragma mark - editing

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
	return indexPath.row < (NSInteger)self.stories.count;
}

- (void)tableView:(UITableView *)tableView
		moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath
			  toIndexPath:(NSIndexPath *)destinationIndexPath {
	NSDictionary *story = self.stories[(NSUInteger)sourceIndexPath.row];
	[self.stories removeObjectAtIndex:(NSUInteger)sourceIndexPath.row];
	[self.stories insertObject:story atIndex:MIN((NSUInteger)destinationIndexPath.row,
												 (NSUInteger)self.stories.count)];
	NSMutableArray *ids = [NSMutableArray array];
	for (NSDictionary *item in self.stories)
		[ids addObject:item[@"storyId"] ?: @(0)];
	[self rebuildSections];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] reorderStories:ids inAlbum:self.albumId inChat:self.chatId
						   completion:^(NSDictionary *album, NSString *error){
		TGStoryAlbumDetailViewController *me = weakSelf;
		if (!album){
			[TGAlertSheet showMessage:(error ?: TGLocalized(@"An error occurred."))
								title:TGLocalized(@"Album") inView:me.view];
			[me reloadStories];
		}
	}];
}

- (void)tableView:(UITableView *)tableView
		commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
		 forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle != UITableViewCellEditingStyleDelete ||
		indexPath.row >= (NSInteger)self.stories.count)
		return;
	NSDictionary *story = self.stories[(NSUInteger)indexPath.row];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] removeStories:@[story[@"storyId"] ?: @(0)]
						   fromAlbum:self.albumId
							  inChat:self.chatId
						  completion:^(NSDictionary *album, NSString *error){
		TGStoryAlbumDetailViewController *me = weakSelf;
		if (!album){
			[TGAlertSheet showMessage:(error ?: TGLocalized(@"An error occurred."))
								title:TGLocalized(@"Album") inView:me.view];
			return;
		}
		[me reloadStories];
	}];
}

@end

// vim:ft=objc
