//
// TGStickerEditorViewController.m - see the header.
//
#import "TGStickerEditorViewController.h"
#import "TGAlertSheet.h"
#import "TGClient.h"
#import "TGStickerGalleryViewController.h"
#import "TGStyle.h"
#import "TGTheme.h"
#import "TGLocalization.h"
#import "TGRows.h"
#import "UIImage+WebP.h"

typedef NS_ENUM(NSInteger, TGStickerPick) {
	TGStickerPickNone = 0,
	TGStickerPickAdd,
	TGStickerPickReplace,
	TGStickerPickThumbnail
};

@interface TGStickerEditorViewController () <
		UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, strong) NSMutableArray *stickers;   // panel-shaped, in order
@property (nonatomic, copy) NSString *loadedName;         // getStickerSetName answer
@property (nonatomic, assign) TGStickerPick picking;
@property (nonatomic, assign) NSInteger replacingFileId;
@property (nonatomic, assign) BOOL busy;
@end

@implementation TGStickerEditorViewController

- (void)viewDidLoad {
	[super viewDidLoad];

	self.title = self.creating ? TGLocalized(@"New Sticker Set")
			: (self.setTitle.length ? self.setTitle : TGLocalized(@"Sticker"));
	self.stickers = [NSMutableArray array];
	[self applyTheme];

	if (!self.creating){
		// The id alone does not carry the short name the write requests
		// change a pack by, so it is read once and shown on the info row.
		if (!self.setName.length && self.setId)
			[[TGClient shared] stickerSetNameForId:self.setId
					completion:^(NSString *name){
				self.loadedName = name ?: @"";
				self.setName = self.loadedName;
				[self rebuildSections];
			}];
		[self reloadStickers];
	} else {
		[self rebuildSections];
	}
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self applyTheme];
}

- (void)applyTheme {
	[super applyTheme];
	TGTheme *theme = [TGTheme shared];
	self.tableView.backgroundColor = [theme listBackgroundColour];
	self.tableView.separatorColor = [theme separatorColour];
	[theme styleNavigationBar:self.navigationController.navigationBar];
}

#pragma mark - loading

- (void)reloadStickers {
	if (!self.setId){
		[self rebuildSections];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] stickersInSet:@(self.setId) completion:^(NSArray *stickers){
		TGStickerEditorViewController *me = weakSelf;
		if (!me)
			return;
		[me.stickers setArray:(stickers ?: @[])];
		[me rebuildSections];
	}];
}

#pragma mark - rows

- (NSString *)typeDetail {
	BOOL customEmoji = [self.stickerType isEqualToString:@"stickerTypeCustomEmoji"] ||
			[self.stickerType isEqualToString:@"customEmoji"];
	if (customEmoji)
		return TGLocalized(@"Custom emoji");
	if ([self.stickerType isEqualToString:@"stickerTypeMask"] ||
		[self.stickerType isEqualToString:@"mask"])
		return TGLocalized(@"Masks");
	return TGLocalized(@"Stickers");
}

- (void)rebuildSections {
	__weak typeof(self) weakSelf = self;
	if (self.creating){
		NSMutableArray *rows = [NSMutableArray array];
		[rows addObject:TGSubtitleRow(TGLocalized(@"Title"),
				self.setTitle.length ? self.setTitle : @"",
				^{ [weakSelf askForTitle]; })];
		[rows addObject:TGSubtitleRow(TGLocalized(@"Name"),
				self.setName.length ? self.setName : @"",
				^{ [weakSelf askForName]; })];
		[rows addObject:TGSubtitleRow(TGLocalized(@"Stickers"),
				[self.stickerType isEqualToString:@"mask"]
						? TGLocalized(@"Masks") : TGLocalized(@"Stickers"),
				^{ [weakSelf askForType]; })];
		[rows addObject:TGSubtitleRow(self.busy
				? TGLocalized(@"Uploading...") : TGLocalized(@"Create Sticker Set"),
				nil, ^{ [weakSelf createPack]; })];
		self.sections = @[TGSection(TGLocalized(@"New Sticker Set"), nil, rows)];
		[self reloadRows];
		return;
	}

	NSMutableArray *infoRows = [NSMutableArray array];
	[infoRows addObject:TGSubtitleRow(TGLocalized(@"Name"),
			self.setName.length ? self.setName
					: (self.loadedName.length ? self.loadedName : @"-"), nil)];
	[infoRows addObject:TGSubtitleRow(TGLocalized(@"Title"),
			self.setTitle.length ? self.setTitle : @"-",
			^{ [weakSelf askForTitle]; })];
	[infoRows addObject:TGSubtitleRow(TGLocalized(@"Stickers"),
			[self typeDetail], nil)];
	[infoRows addObject:TGSubtitleRow(TGLocalized(@"Stickers"),
			[NSString stringWithFormat:@"%lu",
					(unsigned long)self.stickers.count], nil)];
	[infoRows addObject:TGSubtitleRow(TGLocalized(@"Edit Sticker Set"), nil,
			^{ [weakSelf askForTitleAndSave]; })];
	[infoRows addObject:TGSubtitleRow(TGLocalized(@"Set Cover Icon"), nil,
			^{ [weakSelf chooseCover]; })];

	NSMutableArray *stickerRows = [NSMutableArray array];
	[stickerRows addObject:TGSubtitleRow(TGLocalized(@"Add Stickers"), nil,
			^{ [weakSelf askHowToAdd]; })];
	for (NSUInteger index = 0; index < self.stickers.count; index++){
		NSDictionary *sticker = self.stickers[index];
		NSString *emoji = [sticker[@"emoji"] length] ? sticker[@"emoji"]
				: TGLocalized(@"Sticker");
		NSString *title = [NSString stringWithFormat:@"%ld.  %@",
				(long)(index + 1), emoji];
		NSString *detail = [NSString stringWithFormat:TGLocalized(@"file %@  ·  %@"),
				sticker[@"fileId"] ?: @"-",
				[sticker[@"isAnimated"] boolValue]
						? TGLocalized(@"animated") : TGLocalized(@"still")];
		[stickerRows addObject:TGSubtitleRow(title, detail, ^{
			[weakSelf stickerTappedAtIndex:(NSInteger)index];
		})];
	}

	self.sections = @[
		TGSection(TGLocalized(@"Stickers"), nil, infoRows),
		TGSection(TGLocalized(@"Stickers"), nil, stickerRows),
		TGSection(nil, nil, @[
			TGRedRow(TGLocalized(@"Delete Sticker Set"),
					^{ [weakSelf confirmDeletePack]; }),
		]),
	];
	[self reloadRows];
}

- (void)chooseCover {
	if ([self.stickerType isEqualToString:@"stickerTypeCustomEmoji"] ||
		[self.stickerType isEqualToString:@"customEmoji"])
		[self chooseCustomEmojiThumbnail];
	else
		[self pickImageFor:TGStickerPickThumbnail];
}

#pragma mark - creating

- (void)askForTitle {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:TGLocalized(@"Title") message:nil
				placeholder:TGLocalized(@"My Stickers")
					   text:self.setTitle action:TGLocalized(@"Save")
					 inView:self.view onSubmit:^(NSString *text){
		TGStickerEditorViewController *me = weakSelf;
		me.setTitle = text;
		[me rebuildSections];
	}];
}

- (void)askForName {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:TGLocalized(@"Name")
					message:TGLocalized(@"Only a–z, 0–9, and underscores allowed.")
				placeholder:TGLocalized(@"my_stickers")
					   text:self.setName action:TGLocalized(@"Check")
					 inView:self.view onSubmit:^(NSString *text){
		TGStickerEditorViewController *me = weakSelf;
		[[TGClient shared] checkStickerSetName:text completion:^(NSString *status,
															   NSString *message){
			TGStickerEditorViewController *panel = weakSelf;
			if (!panel)
				return;
			if ([status isEqualToString:@"ok"]){
				panel.setName = text;
				[panel rebuildSections];
				[TGAlertSheet showMessage:message title:TGLocalized(@"Name")
								   inView:panel.view];
				return;
			}
			[panel offerSuggestionForTitle:panel.setTitle typed:text reason:message];
		}];
	}];
}

- (void)askForType {
	__weak typeof(self) weakSelf = self;
	NSArray *titles = @[TGLocalized(@"Stickers"), TGLocalized(@"Masks")];
	[TGAlertSheet showChoices:titles title:TGLocalized(@"Stickers")
			 destructiveIndex:-1 inView:self.view onChoice:^(NSInteger index){
		TGStickerEditorViewController *me = weakSelf;
		me.stickerType = index == 1 ? @"mask" : @"regular";
		[me rebuildSections];
	}];
}

/// A name that is taken or malformed is not a dead end: Telegram names the
/// one it would use for this title, and one tap adopts it.
- (void)offerSuggestionForTitle:(NSString *)title typed:(NSString *)typed reason:(NSString *)reason {
	[[TGClient shared] suggestStickerSetNameForTitle:title ?: typed
			completion:^(NSString *suggestion){
		TGStickerEditorViewController *me = self;
		if (!suggestion.length || [suggestion isEqualToString:typed]){
			[TGAlertSheet showMessage:reason ?: TGLocalized(@"An error occurred.")
								  title:TGLocalized(@"Name") inView:me.view];
			return;
		}
		NSString *message = [NSString stringWithFormat:
				TGLocalized(@"%@\n\nTelegram suggests %@."),
				reason ?: TGLocalized(@"An error occurred."), suggestion];
		[TGAlertSheet showChoices:@[[NSString stringWithFormat:
									TGLocalized(@"Use %@"), suggestion],
									TGLocalized(@"Cancel")]
							title:TGLocalized(@"Name")
							message:message
				 destructiveIndex:-1
						   inView:me.view
						 onChoice:^(NSInteger index){
			if (index != 0)
				return;
			me.setName = suggestion;
			[me rebuildSections];
		}];
	}];
}

- (void)createPack {
	if (self.busy)
		return;
	if (!self.setTitle.length || !self.setName.length){
		[TGAlertSheet showMessage:TGLocalized(@"An error occurred.")
							  title:TGLocalized(@"New Sticker Set")
							 inView:self.view];
		return;
	}
	self.busy = YES;
	[self rebuildSections];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] checkStickerSetName:self.setName completion:^(NSString *status,
																   NSString *message){
		TGStickerEditorViewController *me = weakSelf;
		if (!me)
			return;
		if (![status isEqualToString:@"ok"]){
			me.busy = NO;
			[me rebuildSections];
			[me offerSuggestionForTitle:me.setTitle typed:me.setName reason:message];
			return;
		}
		[me uploadSampleThenCreate];
	}];
}

/// A pack cannot be empty, so the first sticker is uploaded before the pack
/// exists. The bundled .tgs is always on the device, which makes creation
/// work on a fresh install with no photo library access.
- (void)uploadSampleThenCreate {
	NSString *path = [[NSBundle mainBundle] pathForResource:@"dev_sticker" ofType:@"tgs"];
	if (!path)
		path = [[NSBundle mainBundle].bundlePath
				stringByAppendingPathComponent:@"dev_sticker.tgs"];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] uploadStickerAtPath:path format:@"tgs" completion:^(NSInteger fileId){
		TGStickerEditorViewController *me = weakSelf;
		if (!me)
			return;
		NSArray *stickers = @[];
		if (fileId > 0){
			NSDictionary *sticker = [[TGClient shared]
					newStickerWithFileId:fileId format:@"tgs" emojis:@"\U0001F600"
								keywords:@[@"sample"] maskPosition:nil];
			stickers = @[sticker];
		}
		[[TGClient shared] createStickerSetNamed:me.setName title:me.setTitle
				stickerType:me.stickerType stickers:stickers
				completion:^(NSDictionary *set){
			TGStickerEditorViewController *panel = weakSelf;
			if (!panel)
				return;
			panel.busy = NO;
			if (!set){
				[panel rebuildSections];
				[TGAlertSheet showMessage:TGLocalized(@"An error occurred.")
									  title:TGLocalized(@"New Sticker Set")
									 inView:panel.view];
				return;
			}
			panel.creating = NO;
			panel.setId = [set[@"id"] longLongValue];
			panel.setName = set[@"name"] ?: panel.setName;
			panel.setTitle = set[@"title"] ?: panel.setTitle;
			panel.stickerType = set[@"stickerType"] ?: @"stickerTypeRegular";
			panel.title = panel.setTitle;
			[panel reloadStickers];
			[TGAlertSheet showMessage:TGLocalized(@"Stickers Added")
								  title:TGLocalized(@"New Sticker Set")
								 inView:panel.view];
		}];
	}];
}

#pragma mark - editing an existing pack

- (void)askForTitleAndSave {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:TGLocalized(@"Edit Sticker Set") message:nil
				placeholder:TGLocalized(@"Title")
					   text:self.setTitle action:TGLocalized(@"Save")
					 inView:self.view onSubmit:^(NSString *text){
		TGStickerEditorViewController *me = weakSelf;
		if (!me)
			return;
		[[TGClient shared] setStickerSetNamed:me.setName title:text
				completion:^(BOOL ok){
			TGStickerEditorViewController *panel = weakSelf;
			if (!panel)
				return;
			if (!ok){
				[TGAlertSheet showMessage:TGLocalized(@"An error occurred.")
									  title:TGLocalized(@"Edit Sticker Set")
									 inView:panel.view];
				return;
			}
			panel.setTitle = text;
			panel.title = text;
			[panel rebuildSections];
		}];
	}];
}

- (void)askHowToAdd {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:@[TGLocalized(@"Photos"),
			TGLocalized(@"Stickers")]
						 title:TGLocalized(@"Add Stickers")
				 destructiveIndex:-1
						   inView:self.view
					 onChoice:^(NSInteger index){
		TGStickerEditorViewController *me = weakSelf;
		if (index == 0){
			[me pickImageFor:TGStickerPickAdd];
			return;
		}
		[me addBundledSampleSticker];
	}];
}

- (void)addBundledSampleSticker {
	NSString *path = [[NSBundle mainBundle] pathForResource:@"dev_video_sticker" ofType:@"webm"];
	if (!path)
		path = [[NSBundle mainBundle].bundlePath
				stringByAppendingPathComponent:@"dev_video_sticker.webm"];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] uploadStickerAtPath:path format:@"webm" completion:^(NSInteger fileId){
		TGStickerEditorViewController *me = weakSelf;
		if (!me || fileId <= 0){
			[TGAlertSheet showMessage:TGLocalized(@"An error occurred.")
								  title:TGLocalized(@"Add Sticker") inView:me.view];
			return;
		}
		NSDictionary *sticker = [[TGClient shared]
				newStickerWithFileId:fileId format:@"webm" emojis:@"\U0001F44D"
							keywords:@[@"sample"] maskPosition:nil];
		[[TGClient shared] addStickerToSetNamed:me.setName sticker:sticker
				completion:^(BOOL ok){
			TGStickerEditorViewController *panel = weakSelf;
			if (!panel)
				return;
			if (!ok)
				[TGAlertSheet showMessage:TGLocalized(@"An error occurred.")
									  title:TGLocalized(@"Add Sticker")
									 inView:panel.view];
			[panel reloadStickers];
		}];
	}];
}

- (void)stickerTappedAtIndex:(NSInteger)index {
	if (index < 0 || index >= (NSInteger)self.stickers.count)
		return;
	NSDictionary *sticker = self.stickers[(NSUInteger)index];
	NSInteger fileId = [sticker[@"fileId"] integerValue];
	if (fileId <= 0)
		return;

	BOOL first = index == 0;
	BOOL last = index == (NSInteger)self.stickers.count - 1;
	NSMutableArray *titles = [NSMutableArray arrayWithObjects:
			TGLocalized(@"Emoji Tags..."), TGLocalized(@"Edit Emoji Tags..."),
			TGLocalized(@"Edit Keywords..."), TGLocalized(@"Mask Position..."),
			TGLocalized(@"Remove Mask Position"), nil];
	if (!first)
		[titles addObject:TGLocalized(@"Move Up")];
	if (!last)
		[titles addObject:TGLocalized(@"Move Down")];
	[titles addObjectsFromArray:@[TGLocalized(@"Replace"),
			TGLocalized(@"Remove")]];

	NSUInteger removeIndex = [titles indexOfObject:TGLocalized(@"Remove")];
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:titles title:[sticker[@"emoji"] length]
			? sticker[@"emoji"] : TGLocalized(@"Sticker")
			destructiveIndex:(NSInteger)removeIndex
					   inView:self.view
					 onChoice:^(NSInteger choice){
		TGStickerEditorViewController *me = weakSelf;
		if (!me)
			return;
		NSString *what = titles[(NSUInteger)choice];
		if ([what isEqualToString:TGLocalized(@"Emoji Tags...")])
			[me showEmojiTagsForFileId:fileId];
		else if ([what isEqualToString:TGLocalized(@"Edit Emoji Tags...")])
			[me askEmojiTagsForFileId:fileId current:sticker[@"emoji"]];
		else if ([what isEqualToString:TGLocalized(@"Edit Keywords...")])
			[me askKeywordsForFileId:fileId];
		else if ([what isEqualToString:TGLocalized(@"Mask Position...")])
			[me askMaskPositionForFileId:fileId];
		else if ([what isEqualToString:TGLocalized(@"Remove Mask Position")])
			[me removeMaskPositionForFileId:fileId];
		else if ([what isEqualToString:TGLocalized(@"Move Up")])
			[me moveFileId:fileId toPosition:index - 1];
		else if ([what isEqualToString:TGLocalized(@"Move Down")])
			[me moveFileId:fileId toPosition:index + 1];
		else if ([what isEqualToString:TGLocalized(@"Replace")]){
			me.replacingFileId = fileId;
			[me pickImageFor:TGStickerPickReplace];
		}
		else if ([what isEqualToString:TGLocalized(@"Remove")])
			[me removeFileId:fileId];
	}];
}

- (void)showEmojiTagsForFileId:(NSInteger)fileId {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] stickerEmojisForFileId:fileId completion:^(NSArray *own){
		TGStickerEditorViewController *me = weakSelf;
		if (!me)
			return;
		NSString *query = own.count ? own.firstObject : @"";
		[[TGClient shared] allStickerEmojisForQuery:query chatId:0
				stickerType:@"regular" mainOnly:NO completion:^(NSArray *all){
			TGStickerEditorViewController *panel = weakSelf;
			if (!panel)
				return;
			NSString *message = [NSString stringWithFormat:
					TGLocalized(@"Filed under: %@\n\nEvery tag matching %@:\n%@"),
					own.count ? [own componentsJoinedByString:@" "]
							: TGLocalized(@"none"),
					query.length ? query : TGLocalized(@"this sticker"),
					all.count ? [all componentsJoinedByString:@" "]
							: TGLocalized(@"none")];
			[TGAlertSheet showMessage:message title:TGLocalized(@"Emoji")
							   inView:panel.view];
		}];
	}];
}

- (void)askEmojiTagsForFileId:(NSInteger)fileId current:(NSString *)current {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:TGLocalized(@"Emoji")
					message:nil
				placeholder:@"\U0001F600" text:current
					 action:TGLocalized(@"Save")
					 inView:self.view onSubmit:^(NSString *text){
		TGStickerEditorViewController *me = weakSelf;
		[[TGClient shared] setStickerFileId:fileId emojis:text completion:^(BOOL ok){
			[me reportSaved:ok title:TGLocalized(@"Emoji")];
		}];
	}];
}

- (void)askKeywordsForFileId:(NSInteger)fileId {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:TGLocalized(@"Edit")
					message:nil
				placeholder:TGLocalized(@"cat, sleeping") text:@""
					 action:TGLocalized(@"Save")
					 inView:self.view onSubmit:^(NSString *text){
		TGStickerEditorViewController *me = weakSelf;
		NSMutableArray *words = [NSMutableArray array];
		for (NSString *word in [text componentsSeparatedByString:@","]){
			NSString *trimmed = [word stringByTrimmingCharactersInSet:
					[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			if (trimmed.length)
				[words addObject:trimmed];
		}
		[[TGClient shared] setStickerFileId:fileId keywords:words completion:^(BOOL ok){
			[me reportSaved:ok title:TGLocalized(@"Edit")];
		}];
	}];
}

- (void)askMaskPositionForFileId:(NSInteger)fileId {
	NSArray *points = @[TGLocalized(@"Forehead"), TGLocalized(@"Eyes"),
			TGLocalized(@"Mouth"), TGLocalized(@"Chin")];
	NSArray *types = @[@"maskPointForehead", @"maskPointEyes",
					   @"maskPointMouth", @"maskPointChin"];
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:points title:TGLocalized(@"Masks")
			 destructiveIndex:-1 inView:self.view onChoice:^(NSInteger index){
		TGStickerEditorViewController *me = weakSelf;
		NSDictionary *mask = @{
			@"@type" : @"maskPosition",
			@"point" : @{@"@type" : types[(NSUInteger)index]},
			@"x_shift" : @0,
			@"y_shift" : @0,
			@"scale" : @1,
		};
		[[TGClient shared] setStickerFileId:fileId maskPosition:mask
				completion:^(BOOL ok){
			[me reportSaved:ok title:TGLocalized(@"Masks")];
		}];
	}];
}

/// td_api takes a null mask_position to clear one; the client writes that
/// null, and this row is the only way to ask for it.
- (void)removeMaskPositionForFileId:(NSInteger)fileId {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setStickerFileId:fileId maskPosition:nil
			completion:^(BOOL ok){
		TGStickerEditorViewController *me = weakSelf;
		[me reportSaved:ok title:TGLocalized(@"Masks")];
	}];
}

- (void)moveFileId:(NSInteger)fileId toPosition:(NSInteger)position {
	if (position < 0 || position >= (NSInteger)self.stickers.count)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setStickerFileId:fileId positionInSet:position
			completion:^(BOOL ok){
		TGStickerEditorViewController *me = weakSelf;
		if (!ok)
			[TGAlertSheet showMessage:TGLocalized(@"An error occurred.")
								  title:TGLocalized(@"Reorder") inView:me.view];
		[me reloadStickers];
	}];
}

- (void)removeFileId:(NSInteger)fileId {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:TGLocalized(@"Remove")
						title:TGLocalized(@"Remove")
					   action:TGLocalized(@"Remove") destructive:YES
					   inView:self.view onConfirm:^{
		TGStickerEditorViewController *me = weakSelf;
		[[TGClient shared] removeStickerFileId:fileId completion:^(BOOL ok){
			TGStickerEditorViewController *panel = weakSelf;
			if (!ok)
				[TGAlertSheet showMessage:TGLocalized(@"An error occurred.")
									  title:TGLocalized(@"Remove")
									 inView:panel.view];
			[panel reloadStickers];
		}];
		(void)me;
	}];
}

- (void)reportSaved:(BOOL)ok title:(NSString *)title {
	[TGAlertSheet showMessage:(ok ? TGLocalized(@"Saved")
								  : TGLocalized(@"An error occurred."))
						  title:title inView:self.view];
	if (ok)
		[self reloadStickers];
}

#pragma mark - photos

- (void)pickImageFor:(TGStickerPick)what {
	if (![UIImagePickerController isSourceTypeAvailable:
			UIImagePickerControllerSourceTypePhotoLibrary]){
		[TGAlertSheet showMessage:TGLocalized(@"An error occurred.")
							  title:TGLocalized(@"Photos") inView:self.view];
		return;
	}
	self.picking = what;
	UIImagePickerController *picker = [[UIImagePickerController alloc] init];
	picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
	picker.delegate = self;
	[self presentViewController:picker animated:YES completion:nil];
}

/// Static stickers are sent as WebP and Telegram checks the bytes: a PNG
/// named .png but declared stickerFormatWebp is refused. The encoder pads the
/// picture to the required square first, so this is the only place a picked
/// image becomes a file.
- (NSString *)writeWebPImage:(UIImage *)image named:(NSString *)name {
	NSData *data = [UIImage webPDataFromImage:image
									  quality:TGCompressionQualityStandard];
	if (!data)
		return nil;
	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
	if (![data writeToFile:path atomically:YES])
		return nil;
	return path;
}

- (void)imagePickerController:(UIImagePickerController *)picker
		didFinishPickingMediaWithInfo:(NSDictionary *)info {
	[picker dismissViewControllerAnimated:YES completion:nil];
	UIImage *image = info[UIImagePickerControllerOriginalImage];
	TGStickerPick what = self.picking;
	self.picking = TGStickerPickNone;
	if (!image)
		return;

	NSString *path = [self writeWebPImage:image named:@"sticker-edit.webp"];
	if (!path){
		[TGAlertSheet showMessage:TGLocalized(@"An error occurred.")
							  title:TGLocalized(@"Photos") inView:self.view];
		return;
	}

	__weak typeof(self) weakSelf = self;
	if (what == TGStickerPickThumbnail){
		[self saveThumbnailAtPath:path];
		return;
	}

	[[TGClient shared] uploadStickerAtPath:path format:@"webp" completion:^(NSInteger fileId){
		TGStickerEditorViewController *me = weakSelf;
		if (!me)
			return;
		if (fileId <= 0){
			[TGAlertSheet showMessage:TGLocalized(@"An error occurred.")
								  title:TGLocalized(@"Add Sticker") inView:me.view];
			return;
		}
		NSDictionary *sticker = [[TGClient shared]
				newStickerWithFileId:fileId format:@"webp" emojis:@"\U0001F642"
							keywords:@[] maskPosition:nil];
		if (what == TGStickerPickReplace){
			[[TGClient shared] replaceStickerInSetNamed:me.setName
					oldFileId:me.replacingFileId newSticker:sticker
					completion:^(BOOL ok){
				TGStickerEditorViewController *panel = weakSelf;
				if (!ok)
					[TGAlertSheet showMessage:TGLocalized(@"An error occurred.")
										  title:TGLocalized(@"Replace")
										 inView:panel.view];
				[panel reloadStickers];
			}];
			return;
		}
		[[TGClient shared] addStickerToSetNamed:me.setName sticker:sticker
				completion:^(BOOL ok){
			TGStickerEditorViewController *panel = weakSelf;
			if (!ok)
				[TGAlertSheet showMessage:TGLocalized(@"An error occurred.")
									  title:TGLocalized(@"Add Sticker")
									 inView:panel.view];
			[panel reloadStickers];
		}];
	}];
}

- (void)saveThumbnailAtPath:(NSString *)path {
	__weak typeof(self) weakSelf = self;
	BOOL customEmoji = [self.stickerType isEqualToString:@"stickerTypeCustomEmoji"] ||
			[self.stickerType isEqualToString:@"customEmoji"];
	if (customEmoji){
		[weakSelf chooseCustomEmojiThumbnail];
		return;
	}
	[[TGClient shared] setStickerSetNamed:self.setName thumbnailAtPath:path
			format:@"webp" completion:^(BOOL ok){
		TGStickerEditorViewController *me = weakSelf;
		[TGAlertSheet showMessage:(ok ? TGLocalized(@"Saved")
									  : TGLocalized(@"An error occurred."))
							  title:TGLocalized(@"Sticker") inView:me.view];
	}];
}

/// A custom emoji pack's thumbnail is one of its emoji, not a photo: the
/// default profile shelf is a concrete list to choose from.
- (void)chooseCustomEmojiThumbnail {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] defaultProfilePhotoCustomEmojiStickersWithCompletion:
			^(NSArray *stickers){
		TGStickerEditorViewController *me = weakSelf;
		if (!me)
			return;
		// Zero is the request's own "remove the thumbnail", so it leads the
		// list even when Telegram sends no default emoji to pick from.
		NSMutableArray *titles = [NSMutableArray arrayWithObject:
				TGLocalized(@"Remove")];
		NSMutableArray *ids = [NSMutableArray arrayWithObject:@(0)];
		for (NSDictionary *sticker in stickers){
			int64_t emojiId = [sticker[@"customEmojiId"] longLongValue];
			if (!emojiId)
				continue;
			[titles addObject:[NSString stringWithFormat:@"%@  ·  %lld",
					[sticker[@"emoji"] length] ? sticker[@"emoji"]
							: TGLocalized(@"Emoji"),
					(long long)emojiId]];
			[ids addObject:@(emojiId)];
		}
		[TGAlertSheet showChoices:titles title:TGLocalized(@"Sticker")
				 destructiveIndex:-1 inView:me.view onChoice:^(NSInteger index){
			int64_t emojiId = [ids[(NSUInteger)index] longLongValue];
			[[TGClient shared] setCustomEmojiStickerSetNamed:me.setName
					thumbnailCustomEmojiId:emojiId completion:^(BOOL ok){
				[TGAlertSheet showMessage:(ok ? TGLocalized(@"Saved")
											  : TGLocalized(@"An error occurred."))
									  title:TGLocalized(@"Sticker") inView:me.view];
			}];
		}];
	}];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
	self.picking = TGStickerPickNone;
	[picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - deleting

- (void)confirmDeletePack {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:TGLocalized(@"Delete Sticker Set")
						title:TGLocalized(@"Delete Sticker Set")
					   action:TGLocalized(@"Delete") destructive:YES
					   inView:self.view onConfirm:^{
		TGStickerEditorViewController *me = weakSelf;
		[[TGClient shared] deleteStickerSetNamed:me.setName completion:^(BOOL ok){
			TGStickerEditorViewController *panel = weakSelf;
			if (!ok){
				[TGAlertSheet showMessage:TGLocalized(@"An error occurred.")
									  title:TGLocalized(@"Delete Sticker Set")
									 inView:panel.view];
				return;
			}
			[panel.navigationController popViewControllerAnimated:YES];
		}];
	}];
}

@end
