#import "TGFileInfoViewController.h"
#import "TGMediaStore.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGIcons.h"
#import "TGRows.h"
#import "UIImage+WebP.h"
#import "TGPageHeaderView.h"
#import "TGBarItem.h"
#import "TGPresent.h"

@interface TGFileInfoViewController ()
@property (nonatomic, strong) NSDictionary *info;
@property (nonatomic, strong) NSDictionary *names;
@property (nonatomic, copy) NSString *suggestedName;
@property (nonatomic, assign) long long prefixBytes;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, strong) TGPageHeaderView *header;
@end

@implementation TGFileInfoViewController

+ (void)presentForFile:(NSInteger)fileId fromView:(UIView *)host {
	UIWindow *window = host.window ?: [UIApplication sharedApplication].keyWindow;
	TGFileInfoViewController *info = [[TGFileInfoViewController alloc] init];
	info.fileId = fileId;
	[TGPresent presentModal:info kind:TGModalInfo from:window.rootViewController];
}

- (instancetype)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.pageKind = TGPageKindDetail;
	self.title = TGLocalized(@"File");
	self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
	[self setupHeader];
	[self rebuildSections];
	[self applyTheme];

	[self load];
}

- (void)applyTheme {
	[super applyTheme];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	[self updateHeader];
}

- (void)setupHeader {
	CGFloat width = self.tableView.bounds.size.width;
	if (width <= 0)
		width = TGMetricScreenWidth;
	// Name and size arrive with the file record: one line each is kept.
	self.header = [[TGPageHeaderView alloc] initWithWidth:width
			artSide:TGMetricPageArtSide title:@"" subtitle:@"" text:nil];
	self.header.titleLabel.numberOfLines = 1;
	self.header.titleLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
	self.tableView.tableHeaderView = self.header;
}

- (void)updateHeader {
	self.header.imageView.image = [TGIcons fileDiscOfSide:TGMetricPageArtSide];
	self.header.titleLabel.text = [self heroName];
	self.header.subtitleLabel.text = TGFileInfoBytesText([self heroSize]);
	[self.header applyTheme];
}

- (void)load {
	if (self.fileId <= 0){
		self.loaded = YES;
		[self rebuildSections];
		return;
	}

	__weak typeof(self) weakSelf = self;
	[[TGMediaStore shared] fileInfo:self.fileId completion:^(NSDictionary *info){
		weakSelf.info = info;
		weakSelf.loaded = YES;
		[weakSelf rebuildSections];
	}];
	[[TGMediaStore shared] fileDownloadedPrefixSize:self.fileId offset:0
									 completion:^(long long bytes){
		weakSelf.prefixBytes = bytes;
		[weakSelf rebuildSections];
	}];
	NSString *documents = [NSSearchPathForDirectoriesInDomains(
			NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
	[[TGMediaStore shared] suggestedFileNameForFile:self.fileId directory:documents
									 completion:^(NSString *name){
		weakSelf.suggestedName = name;
		[weakSelf rebuildSections];
		[[TGMediaStore shared] fileNameInfo:name completion:^(NSDictionary *info){
			weakSelf.names = info;
			[weakSelf rebuildSections];
		}];
	}];
}

- (NSArray *)detailRows {
	return TGFileInfoDetailModels(self.info, self.names, self.suggestedName,
			self.prefixBytes, self.loaded);
}

/// The things a file record can be acted on with. Telegram's file sheet puts
/// Share and Save above the record, not behind a hold, and offers Delete only
/// when the bytes are actually on this device.
- (NSArray *)actionRows {
	NSString *path = [self localPath];
	return TGFileInfoActionTitles(path.length > 0,
			path.pathExtension.lowercaseString);
}

- (NSString *)heroName {
	NSDictionary *info = self.info ?: @{};
	NSString *name = self.suggestedName;
	if (!name.length)
		name = [info[@"localPath"] lastPathComponent];
	return name.length ? name : (self.loaded ? TGLocalized(@"Unavailable")
			: TGLocalized(@"Loading..."));
}

- (long long)heroSize {
	NSDictionary *info = self.info ?: @{};
	long long size = [info[@"size"] longLongValue];
	if (size <= 0)
		size = [info[@"expectedSize"] longLongValue];
	return size;
}

- (void)rebuildSections {
	NSMutableArray *details = [NSMutableArray array];
	for (NSDictionary *model in [self detailRows])
		[details addObject:TGTapRow(model[@"title"], model[@"detail"], nil)];

	__weak typeof(self) weakSelf = self;
	NSMutableArray *actions = [NSMutableArray array];
	for (NSString *title in [self actionRows]){
		if ([title isEqualToString:TGLocalized(@"Share")]){
			[actions addObject:TGActionRow(title, ^{ [weakSelf shareFile]; })];
		} else if ([title isEqualToString:TGLocalized(@"Save to Photos")]){
			[actions addObject:TGActionRow(title, ^{ [weakSelf saveFile]; })];
		} else if ([title isEqualToString:TGLocalized(@"Delete")]){
			[actions addObject:TGRedRow(title, ^{ [weakSelf confirmDelete]; })];
		} else {
			[actions addObject:TGActionRow(title, ^{ [weakSelf copyDetails]; })];
		}
	}

	self.sections = @[
		TGSection(TGLocalized(@"File"), nil, details),
		TGSection(TGLocalized(@"Actions"), nil, actions),
	];
	[self updateHeader];
	[self reloadRows];
}

- (void)confirmDelete {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:TGLocalized(@"Delete")
						title:TGLocalized(@"Delete")
					   action:TGLocalized(@"Delete") destructive:YES
					   inView:self.view
					onConfirm:^{
		TGFileInfoViewController *me = weakSelf;
		if (!me)
			return;
		[[TGMediaStore shared] deleteLocalFile:me.fileId];
		[TGAlertSheet showMessage:TGLocalized(@"Done")
							  title:TGLocalized(@"File") inView:me.view];
		[me load];
	}];
}

- (void)copyDetails {
	NSMutableArray *lines = [NSMutableArray array];
	for (NSDictionary *row in [self detailRows])
		[lines addObject:[NSString stringWithFormat:@"%@: %@",
				row[@"title"], row[@"detail"]]];
	[UIPasteboard generalPasteboard].string =
			[lines componentsJoinedByString:@"\n"];
	[TGAlertSheet showMessage:TGLocalized(@"Copied to clipboard.")
						 title:TGLocalized(@"File") inView:self.view];
}

/// The record's own path, not a fresh download: the action is only offered
/// when the bytes are already here.
- (NSString *)localPath {
	NSDictionary *info = self.info ?: @{};
	NSString *path = [info[@"localPath"] isKindOfClass:NSString.class]
			? info[@"localPath"] : @"";
	return [[NSFileManager defaultManager] fileExistsAtPath:path] ? path : nil;
}

- (void)shareFile {
	NSString *path = [self localPath];
	if (!path.length)
		return;
	[TGPresent shareItems:@[[NSURL fileURLWithPath:path]] from:self sourceView:self.view];
}

- (void)saveFile {
	NSString *path = [self localPath];
	if (!path.length)
		return;
	NSString *extension = path.pathExtension.lowercaseString;
	if ([extension isEqualToString:@"mp4"] || [extension isEqualToString:@"mov"] ||
		[extension isEqualToString:@"m4v"]){
		UISaveVideoAtPathToSavedPhotosAlbum(path, self,
				@selector(video:didFinishSavingWithError:contextInfo:), NULL);
		return;
	}
	UIImage *image = [UIImage imageWithContentsOfFile:path];
	if (!image && [extension isEqualToString:@"webp"])
		image = [UIImage convertFromWebP:path compressedData:nil error:nil];
	if (!image){
		[TGAlertSheet showMessage:TGLocalized(@"An error occurred.")
							  title:TGLocalized(@"Save") inView:self.view];
		return;
	}
	UIImageWriteToSavedPhotosAlbum(image, self,
			@selector(image:didFinishSavingWithError:contextInfo:), NULL);
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error
  contextInfo:(void *)contextInfo {
	[TGAlertSheet showMessage:(error ? TGLocalized(@"An error occurred.")
			: TGLocalized(@"Saved to Photos."))
						 title:nil inView:self.view];
}

- (void)video:(NSString *)path didFinishSavingWithError:(NSError *)error
   contextInfo:(void *)contextInfo {
	[TGAlertSheet showMessage:(error ? TGLocalized(@"An error occurred.")
			: TGLocalized(@"Saved to Photos."))
						 title:nil inView:self.view];
}

@end

// vim:ft=objc
