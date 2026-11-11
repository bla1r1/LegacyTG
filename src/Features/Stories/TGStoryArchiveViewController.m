#import "TGStoryArchiveViewController.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGMediaStore.h"
#import "TGStoryViewerViewController.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import "TGRows.h"
#import "TGStoryStore.h"

/// The archive list's date uses the app language, not the device locale.
static NSString *TGStoryArchiveDateText(NSNumber *unixTime) {
	static NSDateFormatter *formatter = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		formatter = [[NSDateFormatter alloc] init];
		[formatter setDateStyle:NSDateFormatterMediumStyle];
		[formatter setTimeStyle:NSDateFormatterShortStyle];
	});
	if (![unixTime isKindOfClass:NSNumber.class] || unixTime.doubleValue <= 0)
		return nil;
	NSString *language = TGAppLanguage();
	formatter.locale = language.length
			? [NSLocale localeWithLocaleIdentifier:language]
			: [NSLocale currentLocale];
	return [formatter stringFromDate:
			[NSDate dateWithTimeIntervalSince1970:unixTime.doubleValue]];
}

@interface TGStoryArchiveViewController ()
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, copy) NSString *chatTitle;
@property (nonatomic, strong) NSMutableArray *stories;
@property (nonatomic, assign) int32_t lastStoryId;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, strong) NSMutableDictionary *pictures;
@property (nonatomic, strong) NSMutableSet *picturesRequested;
@end

@implementation TGStoryArchiveViewController

- (instancetype)initWithChatId:(int64_t)chatId title:(NSString *)title {
	self = [super init];
	if (self){
		_chatId = chatId;
		_chatTitle = [title copy] ?: TGLocalized(@"Stories");
		_stories = [NSMutableArray array];
		_pictures = [NSMutableDictionary dictionary];
		_picturesRequested = [NSMutableSet set];
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGLocalized(@"Archived Stories");
	[self loadMore];
	[self rebuildSections];
}

- (void)loadMore {
	if (self.loading)
		return;
	self.loading = YES;
	__weak typeof(self) weakSelf = self;
	[[TGStoryStore shared]archivedStoryIdsForChat:self.chatId
								   fromStoryId:self.lastStoryId
										   limit:30
								   completion:^(NSArray *storyIds, NSString *error){
		TGStoryArchiveViewController *me = weakSelf;
		if (!me)
			return;
		if (error.length && !storyIds.count){
			me.loading = NO;
			[me rebuildSections];
			[TGAlertSheet showMessage:error
								 title:TGLocalized(@"Story Archive")
								inView:me.view];
			return;
		}
		if (!storyIds.count){
			me.loading = NO;
			[me rebuildSections];
			return;
		}
		me.lastStoryId = [storyIds.lastObject intValue];
		[me fetchStories:storyIds at:0];
	}];
}

- (void)fetchStories:(NSArray *)ids at:(NSInteger)index {
	if (index >= (NSInteger)ids.count){
		self.loading = NO;
		[self rebuildSections];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGStoryStore shared]story:[ids[(NSUInteger)index] intValue] fromChat:self.chatId
				  completion:^(NSDictionary *story){
		TGStoryArchiveViewController *me = weakSelf;
		if (!me)
			return;
		if (story)
			[me.stories addObject:story];
		[me fetchStories:ids at:index + 1];
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
			TGStoryArchiveViewController *me = weakSelf;
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
	if (!self.stories.count && !self.loading){
		[rows addObject:TGRow(TGKindPlain,
				TGLocalized(@"No Archived Stories"))];
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
					TGStoryArchiveDateText(story[@"date"]) ?: @""];
			NSNumber *storyId = @([story[@"storyId"] longLongValue]);
			NSMutableDictionary *row = TGPeerRow(storyId, title, detail,
					^{ [weakSelf openStoryAtIndex:(NSInteger)index]; });
			row[TGRowAccessory] = TGRowAccessoryDisclosure;
			UIImage *picture = [self pictureForStory:story];
			if (picture)
				row[TGRowAvatarImage] = picture;
			[rows addObject:row];
		}
		NSString *footerTitle = self.loading ? TGLocalized(@"Loading...")
				: TGLocalized(@"Show More");
		[rows addObject:TGSubtitleRow(footerTitle, nil, self.loading
				? nil : ^{ [weakSelf loadMore]; })];
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
					 title:self.chatTitle
				   stories:self.stories
				startIndex:index
				 canManage:YES];
	viewer.hidesBottomBarWhenPushed = YES;
	viewer.onStoriesChanged = ^{ [weakSelf reloadRows]; };
	[self.navigationController pushViewController:viewer animated:YES];
}

@end

// vim:ft=objc
