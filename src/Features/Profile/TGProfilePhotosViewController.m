//
// TGProfilePhotosViewController - every profile photo an account still has,
// as the shared square grid. Holding a photo offers to take it off the account.
//
#import "TGProfilePhotosViewController.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGAlertSheet.h"
#import "TGStyle.h"
#import "TGLocalization.h"
#import "TGRows.h"
#import "TGProfileLogic.h"
#import "TGGridRowCell.h"

static const NSInteger kPhotoGridColumns = 3;

@interface TGProfilePhotosViewController ()
@property (nonatomic, assign) int64_t userId;
@property (nonatomic, strong) NSArray *photos;   // @{"photoId", "fileId"}
@property (nonatomic, strong) NSMutableDictionary *images;
@property (nonatomic, strong) NSMutableSet *requested;
@end

@implementation TGProfilePhotosViewController

- (instancetype)initWithUserId:(int64_t)userId {
	if ((self = [super init])){
		_userId = userId;
		_photos = @[];
		_images = [NSMutableDictionary dictionary];
		_requested = [NSMutableSet set];
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGLocalized(@"Profile Photos");
	[self applyTheme];
	[self refresh];
}

- (void)applyTheme {
	[super applyTheme];
	[[TGTheme shared] styleGroupedTable:self.tableView];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self applyTheme];
}

- (void)refresh {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] userProfilePhotos:self.userId completion:^(NSArray *photos){
		TGProfilePhotosViewController *me = weakSelf;
		if (!me)
			return;
		me.photos = photos ?: @[];
		[me rebuildSections];
	}];
}

- (NSString *)dateTextForPhoto:(NSDictionary *)photo {
	double date = [photo[@"date"] doubleValue];
	if (date <= 0)
		return TGLocalized(@"Profile Photos");
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	formatter.dateStyle = NSDateFormatterMediumStyle;
	formatter.timeStyle = NSDateFormatterNoStyle;
	NSString *language = TGAppLanguage();
	formatter.locale = language.length
			? [NSLocale localeWithLocaleIdentifier:language]
			: [NSLocale currentLocale];
	return [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:date]];
}

- (void)downloadPhoto:(NSDictionary *)photo {
	NSNumber *fileId = photo[@"fileId"];
	if (![fileId isKindOfClass:NSNumber.class] || fileId.integerValue <= 0)
		return;
	if (self.images[fileId] || [self.requested containsObject:fileId])
		return;
	[self.requested addObject:fileId];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] downloadFile:fileId.integerValue
						   priority:TGDownloadPriorityAvatar
						 completion:^(NSString *path){
		if (!path.length)
			return;
		UIImage *image = [TGIcons decodedImageAtPath:path
				fittingSize:CGSizeMake(TGMetricProfilePhotoSide,
						TGMetricProfilePhotoSide)
						 fill:YES
						scale:[UIScreen mainScreen].scale];
		if (!image)
			return;
		dispatch_async(dispatch_get_main_queue(), ^{
			TGProfilePhotosViewController *me = weakSelf;
			if (!me)
				return;
			me.images[fileId] = image;
			[me rebuildSections];
		});
	}];
}

- (void)rebuildSections {
	if (!self.photos.count){
		self.sections = @[TGSection(nil, nil,
				@[TGRow(TGKindPlain, TGLocalized(@"No Photos"))])];
		[self reloadRows];
		return;
	}
	__weak typeof(self) weakSelf = self;
	NSArray *rows = TGProfileGridRowModels(self.photos, kPhotoGridColumns,
			^NSDictionary *(NSInteger index){
		TGProfilePhotosViewController *me = weakSelf;
		NSDictionary *photo = me.photos[(NSUInteger)index];
		NSMutableDictionary *tile = [NSMutableDictionary dictionary];
		NSNumber *fileId = photo[@"fileId"];
		UIImage *image = [fileId isKindOfClass:NSNumber.class]
				? me.images[fileId] : nil;
		if (image)
			tile[TGGridItemImage] = image;
		else {
			NSNumber *photoId = photo[@"photoId"];
			tile[TGGridItemImage] = [TGIcons avatarWithInitials:@"?"
					size:TGMetricProfilePhotoSide
					colourId:photoId.longLongValue];
			[me downloadPhoto:photo];
		}
		tile[TGGridItemCaption] = [me dateTextForPhoto:photo];
		tile[TGGridItemHold] = ^{ [weakSelf confirmRemoveAtIndex:index]; };
		return tile;
	}, nil);
	self.sections = @[TGSection(nil, nil, rows)];
	[self reloadRows];
}

- (void)confirmRemoveAtIndex:(NSInteger)index {
	if (index < 0 || index >= (NSInteger)self.photos.count)
		return;
	NSDictionary *photo = self.photos[(NSUInteger)index];
	int64_t photoId = [photo[@"photoId"] longLongValue];
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:nil
						title:TGLocalized(@"Remove Photo")
					   action:TGLocalized(@"Remove")
				  destructive:YES
					   inView:self.view
					onConfirm:^{
		[[TGClient shared] deleteProfilePhoto:photoId completion:^(BOOL ok){
			if (!ok)
				return;
			TGProfilePhotosViewController *me = weakSelf;
			NSMutableArray *fresh = [me.photos mutableCopy];
			[fresh removeObjectAtIndex:(NSUInteger)index];
			me.photos = fresh;
			[me rebuildSections];
		}];
	}];
}

@end

// vim:ft=objc
