#import "TGFileInfoViewController.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGIcons.h"
#import "TGRows.h"
#import "UIImage+WebP.h"

@interface TGFileInfoViewController ()
@property (nonatomic, strong) NSDictionary *info;
@property (nonatomic, strong) NSDictionary *names;
@property (nonatomic, copy) NSString *suggestedName;
@property (nonatomic, assign) long long prefixBytes;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, strong) UIImageView *heroIcon;
@property (nonatomic, strong) UILabel *heroNameLabel;
@property (nonatomic, strong) UILabel *heroSizeLabel;
@end

@implementation TGFileInfoViewController

+ (void)presentForFile:(NSInteger)fileId fromView:(UIView *)host {
	UIWindow *window = host.window ?: [UIApplication sharedApplication].keyWindow;
	UIViewController *top = window.rootViewController;
	while (top.presentedViewController)
		top = top.presentedViewController;
	if (!top)
		return;

	TGFileInfoViewController *info = [[TGFileInfoViewController alloc] init];
	info.fileId = fileId;
	UINavigationController *nav = [[UINavigationController alloc]
			initWithRootViewController:info];
	info.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
			initWithBarButtonSystemItem:UIBarButtonSystemItemDone
								 target:info action:@selector(dismissSelf)];
	[top presentViewController:nav animated:YES completion:nil];
}

- (void)dismissSelf {
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (instancetype)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	[super viewDidLoad];
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
	UIView *header = [[UIView alloc] initWithFrame:
			CGRectMake(0, 0, width, TGMetricFileInfoHero)];
	header.backgroundColor = [UIColor clearColor];

	self.heroIcon = [[UIImageView alloc] initWithFrame:CGRectMake(
			TGMetricPadLarge,
			TGCenteredOrigin(TGMetricFileInfoHero, TGMetricFileInfoIcon),
			TGMetricFileInfoIcon, TGMetricFileInfoIcon)];
	self.heroIcon.contentMode = UIViewContentModeScaleAspectFit;
	[header addSubview:self.heroIcon];

	CGFloat textX = CGRectGetMaxX(self.heroIcon.frame) + TGMetricPadMedium;
	self.heroNameLabel = [[UILabel alloc] initWithFrame:CGRectMake(textX,
			TGMetricPadMedium + TGMetricPadSmall,
			width - textX - TGMetricPadLarge, TGMetricLineHeader)];
	self.heroNameLabel.font = TGFontHeader();
	self.heroNameLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
	self.heroNameLabel.backgroundColor = [UIColor clearColor];
	[header addSubview:self.heroNameLabel];

	self.heroSizeLabel = [[UILabel alloc] initWithFrame:CGRectMake(textX,
			CGRectGetMaxY(self.heroNameLabel.frame),
			self.heroNameLabel.bounds.size.width, TGMetricLineCaption)];
	self.heroSizeLabel.font = TGFontSubhead();
	self.heroSizeLabel.backgroundColor = [UIColor clearColor];
	[header addSubview:self.heroSizeLabel];

	self.tableView.tableHeaderView = header;
}

- (void)updateHeader {
	TGTheme *theme = [TGTheme shared];
	self.heroIcon.image = [TGIcons fileDiscOfSide:TGMetricFileInfoIcon];
	self.heroNameLabel.text = [self heroName];
	self.heroNameLabel.textColor = [theme primaryTextColour];
	self.heroSizeLabel.text = TGFileInfoBytesText([self heroSize]);
	self.heroSizeLabel.textColor = [theme secondaryTextColour];
}

- (void)load {
	if (self.fileId <= 0){
		self.loaded = YES;
		[self rebuildSections];
		return;
	}

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] fileInfo:self.fileId completion:^(NSDictionary *info){
		weakSelf.info = info;
		weakSelf.loaded = YES;
		[weakSelf rebuildSections];
	}];
	[[TGClient shared] fileDownloadedPrefixSize:self.fileId offset:0
									 completion:^(long long bytes){
		weakSelf.prefixBytes = bytes;
		[weakSelf rebuildSections];
	}];
	NSString *documents = [NSSearchPathForDirectoriesInDomains(
			NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
	[[TGClient shared] suggestedFileNameForFile:self.fileId directory:documents
									 completion:^(NSString *name){
		weakSelf.suggestedName = name;
		[weakSelf rebuildSections];
		[[TGClient shared] fileNameInfo:name completion:^(NSDictionary *info){
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
		[[TGClient shared] deleteLocalFile:me.fileId];
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
	UIActivityViewController *share = [[UIActivityViewController alloc]
			initWithActivityItems:@[[NSURL fileURLWithPath:path]]
			applicationActivities:nil];
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad &&
		[share respondsToSelector:@selector(popoverPresentationController)]){
		share.popoverPresentationController.sourceView = self.view;
		share.popoverPresentationController.sourceRect = self.view.bounds;
	}
	[self presentViewController:share animated:YES completion:nil];
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
