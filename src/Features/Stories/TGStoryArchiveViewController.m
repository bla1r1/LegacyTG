#import "TGStoryArchiveViewController.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGStoryViewerViewController.h"
#import "TGIcons.h"
#import "TGLocalization.h"

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
@end

@implementation TGStoryArchiveViewController

- (instancetype)initWithChatId:(int64_t)chatId title:(NSString *)title {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self){
		_chatId = chatId;
		_chatTitle = [title copy] ?: @"Stories";
		_stories = [NSMutableArray array];
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Archived Stories";
	[[TGTheme shared] styleGroupedTable:self.tableView];
	[self loadMore];
}

- (void)loadMore {
	if (self.loading)
		return;
	self.loading = YES;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] archivedStoryIdsForChat:self.chatId
								   fromStoryId:self.lastStoryId
										   limit:30
								   completion:^(NSArray *storyIds, NSString *error){
		TGStoryArchiveViewController *me = weakSelf;
		if (!me)
			return;
		if (error.length && !storyIds.count){
			me.loading = NO;
			[TGAlertSheet showMessage:error title:@"Story Archive" inView:me.view];
			return;
		}
		if (!storyIds.count){
			me.loading = NO;
			[me.tableView reloadData];
			return;
		}
		me.lastStoryId = [storyIds.lastObject intValue];
		[me fetchStories:storyIds at:0];
	}];
}

- (void)fetchStories:(NSArray *)ids at:(NSInteger)index {
	if (index >= (NSInteger)ids.count){
		self.loading = NO;
		[self.tableView reloadData];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] story:[ids[index] intValue] fromChat:self.chatId
				  completion:^(NSDictionary *story){
		TGStoryArchiveViewController *me = weakSelf;
		if (!me)
			return;
		if (story)
			[me.stories addObject:story];
		[me fetchStories:ids at:index + 1];
	}];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return self.stories.count + 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"archiveStory"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:@"archiveStory"];
	[[TGTheme shared] styleCell:cell];
	cell.imageView.image = nil;
	if (indexPath.row >= (NSInteger)self.stories.count){
		if (!self.stories.count && !self.loading){
			cell.textLabel.text = @"No Archived Stories";
			cell.detailTextLabel.text = nil;
			cell.accessoryType = UITableViewCellAccessoryNone;
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
			return cell;
		}
		cell.textLabel.text = self.loading ? @"Loading..." : @"Show More";
		cell.detailTextLabel.text = nil;
		cell.accessoryType = UITableViewCellAccessoryNone;
		cell.selectionStyle = self.loading
				? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleBlue;
		return cell;
	}
	NSDictionary *story = self.stories[indexPath.row];
	cell.textLabel.text = story[@"caption"];
	if (!cell.textLabel.text.length)
		cell.textLabel.text = @"Story";
	cell.textLabel.font = TGFontBody();
	cell.detailTextLabel.font = TGFontSubhead();
	NSInteger viewers = (NSInteger)[story[@"viewers"] integerValue];
	NSString *views = TGLocalizedPluralValue(@"%@ view", @"%@ views",
			[NSString stringWithFormat:@"%ld", (long)viewers], viewers);
	cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@", views,
			TGStoryArchiveDateText(story[@"date"]) ?: @""];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	NSNumber *photoId = story[@"thumbPhotoId"] ?: story[@"photoId"];
	if ([photoId isKindOfClass:NSNumber.class] && photoId.integerValue > 0){
		__weak UITableViewCell *weakCell = cell;
		[[TGClient shared] downloadFile:photoId.integerValue
							   priority:TGDownloadPriorityOnScreen
							 completion:^(NSString *path){
			[weakCell.imageView setImage:path.length
					? [UIImage imageWithContentsOfFile:path] : nil];
			[weakCell setNeedsLayout];
		}];
	}
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.row >= (NSInteger)self.stories.count){
		if (!self.stories.count || self.loading)
			return;
		[tableView deselectRowAtIndexPath:indexPath animated:YES];
		[self loadMore];
		return;
	}
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	TGStoryViewerViewController *viewer = [[TGStoryViewerViewController alloc]
			initWithChatId:self.chatId
					 title:self.chatTitle
				   stories:self.stories
				startIndex:indexPath.row
				 canManage:YES];
	viewer.hidesBottomBarWhenPushed = YES;
	viewer.onStoriesChanged = ^{
		[tableView reloadData];
	};
	[self.navigationController pushViewController:viewer animated:YES];
}

@end
