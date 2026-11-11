#import "TGDevFileToolsViewController.h"
#import "TGDevStore.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGRows.h"

@interface TGDevFileToolsViewController ()
@property (nonatomic, assign) BOOL busy;
@property (nonatomic, assign) float progress;
@property (nonatomic, copy) NSString *stage;
@property (nonatomic, assign) NSInteger fileId;
@property (nonatomic, copy) NSString *generatedPath;
@property (nonatomic, assign) long long generatedSize;
@property (nonatomic, copy) NSString *preview;
@end

@implementation TGDevFileToolsViewController

- (instancetype)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGLocalized(@"File Tools");
	self.stage = TGLocalized(@"Ready");
	self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
	[self rebuildSections];
	[self applyTheme];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self applyTheme];
	// The generation has its own progress block, but an upload that continues
	// past the generated file answering is only visible through updateFile.
	__weak typeof(self) weakSelf = self;
	[TGDevStore shared].onFileUploadProgress = ^(NSInteger fileId, float progress){
		TGDevFileToolsViewController *me = weakSelf;
		if (!me || me.fileId != fileId)
			return;
		me.progress = progress;
		me.stage = TGLocalized(@"Uploading");
		[me rebuildSections];
	};
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[TGDevStore shared].onFileUploadProgress = nil;
}

- (void)applyTheme {
	[super applyTheme];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (BOOL)hasTransfer {
	return self.busy || self.fileId > 0;
}

- (BOOL)hasResult {
	return self.generatedPath.length > 0;
}

#pragma mark - rows

- (void)rebuildSections {
	__weak typeof(self) weakSelf = self;
	NSMutableArray *sections = [NSMutableArray array];

	NSString *generateTitle = self.busy ? TGLocalized(@"Generating...")
			: TGLocalized(@"Generate and Upload a File");
	NSDictionary *generateRow = self.busy
			? TGRow(TGKindPlain, generateTitle)
			: TGActionRow(generateTitle, ^{ [weakSelf showGenerate]; });
	[sections addObject:TGSection(TGLocalized(@"GENERATE AND UPLOAD"),
			TGLocalized(@"TDLib asks this app for the bytes through "
					@"updateFileGenerationStart. The file is written part by part, "
					@"finished, and uploaded with preliminaryUploadFile - the same "
					@"path a recording takes before it is sent. Cancel stops the "
					@"upload."), @[generateRow])];

	if (self.hasTransfer){
		NSMutableDictionary *progress = [TGTapRow(
				TGDevFileToolsProgressText(self.stage, self.progress), nil, nil)
				mutableCopy];
		progress[TGRowHeight] = @(TGMetricRow + TGMetricLineMicro);
		NSString *actionTitle = self.busy ? TGLocalized(@"Cancel Upload")
				: TGLocalized(@"Clear");
		[sections addObject:TGSection(TGLocalized(@"TRANSFER"), nil, @[
			progress,
			TGRedRow(actionTitle, ^{ [weakSelf cancelOrClear]; }),
		])];
	}

	if (self.hasResult){
		NSMutableArray *rows = [NSMutableArray array];
		NSArray *models = TGDevFileToolsResultModels(self.generatedPath,
				self.generatedSize, self.preview);
		for (NSUInteger index = 0; index < models.count; index++){
			NSDictionary *model = models[index];
			if (index < 2){
				[rows addObject:TGTapRow(model[@"title"], model[@"detail"], nil)];
			} else {
				NSMutableDictionary *preview = [TGTapRow(model[@"title"], nil,
						^{ [weakSelf readPreview]; }) mutableCopy];
				preview[TGRowTitleLines] = @0;
				[rows addObject:preview];
			}
		}
		[sections addObject:TGSection(TGLocalized(@"GENERATED FILE"), nil, rows)];
	}

	self.sections = sections;
	[self reloadRows];
}

- (void)showGenerate {
	if (self.busy)
		return;
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:TGLocalized(@"Generate a File")
					message:TGLocalized(@"A text file is written through TDLib's "
							@"file-generation API and uploaded preliminarily. The "
							@"upload stops short of a message, which is what "
							@"preliminary means.")
				placeholder:TGLocalized(@"File name")
					   text:@"legacy-note.txt"
					 action:TGLocalized(@"Create")
					 inView:self.view
				   onSubmit:^(NSString *name){
		[weakSelf startGenerationWithName:name];
	}];
}

- (void)cancelOrClear {
	if (self.busy){
		[[TGDevStore shared] cancelPreliminaryUploadOfFile:self.fileId];
		self.busy = NO;
		self.stage = TGLocalized(@"Cancelled");
		self.progress = 0;
		self.fileId = 0;
	} else {
		self.generatedPath = nil;
		self.preview = nil;
		self.fileId = 0;
		self.generatedSize = 0;
		self.stage = TGLocalized(@"Ready");
	}
	[self rebuildSections];
}

#pragma mark - generation

- (void)startGenerationWithName:(NSString *)name {
	NSMutableString *contents = [NSMutableString string];
	[contents appendString:@"LegacyTG generated file\n"];
	[contents appendFormat:@"Name: %@\n", name];
	[contents appendFormat:@"Created: %@\n\n", [NSDate date]];
	[contents appendString:@"This text was written to TDLib part by part through "
					   @"writeGeneratedFilePart and setFileGenerationProgress, then "
					   @"handed to preliminaryUploadFile.\n"];
	for (NSUInteger i = 0; i < 80; i++)
		[contents appendFormat:@"Line %lu - the file generator keeps writing so the "
						  @"progress bar has more than one part to move.\n",
						  (unsigned long)(i + 1)];

	self.busy = YES;
	self.progress = 0;
	self.stage = TGLocalized(@"Preparing");
	self.fileId = 0;
	self.generatedPath = nil;
	self.generatedSize = 0;
	self.preview = nil;
	[self rebuildSections];

	__weak typeof(self) weakSelf = self;
	[[TGDevStore shared] generateTextFileNamed:name contents:contents
			progress:^(NSInteger fileId, float progress, NSString *stage){
		TGDevFileToolsViewController *me = weakSelf;
		if (!me)
			return;
		if (fileId > 0)
			me.fileId = fileId;
		me.progress = progress;
		me.stage = stage;
		[me rebuildSections];
	} completion:^(NSInteger fileId, NSString *path, NSError *error){
		TGDevFileToolsViewController *me = weakSelf;
		if (!me)
			return;
		me.busy = NO;
		if (error){
			me.fileId = 0;
			me.stage = TGLocalized(@"Stopped");
			me.progress = 0;
			[me rebuildSections];
			[TGAlertSheet showMessage:error.localizedDescription
								 title:TGLocalized(@"File Tools") inView:me.view];
			return;
		}
		me.fileId = fileId;
		me.generatedPath = path;
		me.stage = TGLocalized(@"Uploading");
		NSDictionary *attributes = [[NSFileManager defaultManager]
				attributesOfItemAtPath:path error:nil];
		me.generatedSize = [attributes[NSFileSize] longLongValue];
		[me rebuildSections];
		[me readPreview];
	}];
}

- (void)readPreview {
	if (self.fileId <= 0)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGDevStore shared] readFilePartOfFile:self.fileId offset:0 count:320
							   completion:^(NSData *data){
		TGDevFileToolsViewController *me = weakSelf;
		if (!me)
			return;
		NSString *text = data.length
				? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]
				: nil;
		me.preview = text.length ? text : (data.length
				? TGLocalized(@"(The first bytes are not text.)")
				: TGLocalized(@"TDLib has not cached the first part yet."));
		[me rebuildSections];
	}];
}

@end

// vim:ft=objc
