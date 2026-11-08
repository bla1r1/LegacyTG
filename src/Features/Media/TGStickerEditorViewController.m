//
// TGStickerEditorViewController.m - see the header.
//
#import "TGStickerEditorViewController.h"
#import "TGAlertSheet.h"
#import "TGClient.h"
#import "TGStickerGalleryViewController.h"
#import "TGStyle.h"
#import "TGTheme.h"
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


	self.title = self.creating ? @"New Sticker Set"
			: (self.setTitle.length ? self.setTitle : @"Sticker");
	self.tableView.rowHeight = TGMetricRow;
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
				[self.tableView reloadData];
			}];
		[self reloadStickers];
	}
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self applyTheme];
}

- (void)applyTheme {
	TGTheme *theme = [TGTheme shared];
	self.tableView.backgroundColor = [theme listBackgroundColour];
	self.tableView.separatorColor = [theme separatorColour];
	[theme styleNavigationBar:self.navigationController.navigationBar];
}

#pragma mark - loading

- (void)reloadStickers {
	if (!self.setId){
		[self.tableView reloadData];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] stickersInSet:@(self.setId) completion:^(NSArray *stickers){
		TGStickerEditorViewController *me = weakSelf;
		if (!me)
			return;
		[me.stickers setArray:(stickers ?: @[])];
		[me.tableView reloadData];
	}];
}

#pragma mark - rows

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return self.creating ? 1 : 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (self.creating)
		return 4;
	if (section == 0)
		return 6;   // name, title, type, count, rename, thumbnail
	if (section == 1)
		return (NSInteger)self.stickers.count + 1;   // add, then the stickers
	return 1;       // delete
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (self.creating)
		return @"New Sticker Set";
	if (section == 0)
		return @"Stickers";
	if (section == 1)
		return @"Stickers";
	return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	return nil;
}

- (UITableViewCell *)cellForTable:(UITableView *)tableView {
	static NSString *cellId = @"row";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:cellId];
	TGTheme *theme = [TGTheme shared];
	cell.backgroundColor = [theme listBackgroundColour];
	cell.textLabel.textColor = [theme primaryTextColour];
	cell.detailTextLabel.textColor = [theme secondaryTextColour];
	cell.textLabel.font = TGFontRow();
	cell.detailTextLabel.font = TGFontCaption();
	cell.accessoryType = UITableViewCellAccessoryNone;
	return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [self cellForTable:tableView];
	cell.accessoryType = UITableViewCellAccessoryNone;

	if (self.creating){
		switch (indexPath.row){
			case 0:
				cell.textLabel.text = @"Title";
				cell.detailTextLabel.text = self.setTitle.length ? self.setTitle
						: @"";
				break;
			case 1:
				cell.textLabel.text = @"Name";
				cell.detailTextLabel.text = self.setName.length ? self.setName
						: @"";
				break;
			case 2:
				cell.textLabel.text = @"Stickers";
				cell.detailTextLabel.text = [self.stickerType isEqualToString:@"mask"]
						? @"Masks" : @"Stickers";
				break;
			default:
				cell.textLabel.text = self.busy ? @"Uploading..." : @"Create Sticker Set";
				cell.detailTextLabel.text = nil;
				cell.accessoryType = UITableViewCellAccessoryNone;
				break;
		}
		return cell;
	}

	if (indexPath.section == 0){
		switch (indexPath.row){
			case 0:
				cell.textLabel.text = @"Name";
				cell.detailTextLabel.text = self.setName.length ? self.setName
						: (self.loadedName.length ? self.loadedName : @"-");
				cell.accessoryType = UITableViewCellAccessoryNone;
				cell.selectionStyle = UITableViewCellSelectionStyleNone;
				break;
			case 1:
				cell.textLabel.text = @"Title";
				cell.detailTextLabel.text = self.setTitle.length ? self.setTitle : @"-";
				break;
			case 2:
				cell.textLabel.text = @"Stickers";
				cell.detailTextLabel.text =
						[self.stickerType isEqualToString:@"stickerTypeCustomEmoji"] ||
						[self.stickerType isEqualToString:@"customEmoji"]
						? @"Custom emoji" :
						([self.stickerType isEqualToString:@"stickerTypeMask"] ||
						 [self.stickerType isEqualToString:@"mask"]
					 ? @"Masks" : @"Stickers");
				cell.accessoryType = UITableViewCellAccessoryNone;
				cell.selectionStyle = UITableViewCellSelectionStyleNone;
				break;
			case 3:
				cell.textLabel.text = @"Stickers";
				cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu",
						(unsigned long)self.stickers.count];
				cell.accessoryType = UITableViewCellAccessoryNone;
				cell.selectionStyle = UITableViewCellSelectionStyleNone;
				break;
			case 4:
				cell.textLabel.text = @"Edit Sticker Set";
				cell.detailTextLabel.text = nil;
				break;
			default:
				cell.textLabel.text = @"Set Cover Icon";
				cell.detailTextLabel.text = nil;
				break;
		}
		return cell;
	}

	if (indexPath.section == 1){
		if (indexPath.row == 0){
			cell.textLabel.text = @"Add Stickers";
			cell.detailTextLabel.text = nil;
			return cell;
		}
		NSDictionary *sticker = self.stickers[(NSUInteger)(indexPath.row - 1)];
		NSString *emoji = [sticker[@"emoji"] length] ? sticker[@"emoji"] : @"Sticker";
		cell.textLabel.text = [NSString stringWithFormat:@"%ld.  %@",
				(long)indexPath.row, emoji];
		cell.detailTextLabel.text = [NSString stringWithFormat:@"file %@  ·  %@",
				sticker[@"fileId"] ?: @"-",
				[sticker[@"isAnimated"] boolValue] ? @"animated" : @"still"];
		return cell;
	}

	cell.textLabel.text = @"Delete Sticker Set";
	cell.textLabel.textColor = [TGTheme shared].destructiveColour;
	cell.detailTextLabel.text = nil;
	cell.accessoryType = UITableViewCellAccessoryNone;
	return cell;
}

#pragma mark - choosing rows

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (!self.creating && indexPath.section == 0 &&
		(indexPath.row == 0 || indexPath.row == 2 || indexPath.row == 3))
		return;
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	if (self.creating){
		if (indexPath.row == 0)
			[self askForTitle];
		else if (indexPath.row == 1)
			[self askForName];
		else if (indexPath.row == 2)
			[self askForType];
		else
			[self createPack];
		return;
	}

	if (indexPath.section == 0){
		if (indexPath.row == 1)
			[self askForTitle];
		else if (indexPath.row == 4)
			[self askForTitleAndSave];
		else if (indexPath.row == 5){
			if ([self.stickerType isEqualToString:@"stickerTypeCustomEmoji"] ||
				[self.stickerType isEqualToString:@"customEmoji"])
				[self chooseCustomEmojiThumbnail];
			else
				[self pickImageFor:TGStickerPickThumbnail];
		}
		return;
	}

	if (indexPath.section == 1){
		if (indexPath.row == 0){
			[self askHowToAdd];
			return;
		}
		[self stickerTappedAtIndex:indexPath.row - 1];
		return;
	}

	[self confirmDeletePack];
}

#pragma mark - creating

- (void)askForTitle {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Title" message:nil
				placeholder:@"My Stickers" text:self.setTitle action:@"Save"
					 inView:self.view onSubmit:^(NSString *text){
		TGStickerEditorViewController *me = weakSelf;
		me.setTitle = text;
		[me.tableView reloadData];
	}];
}

- (void)askForName {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Name"
					message:@"Only a–z, 0–9, and underscores allowed."
				placeholder:@"my_stickers" text:self.setName action:@"Check"
					 inView:self.view onSubmit:^(NSString *text){
		TGStickerEditorViewController *me = weakSelf;
		[[TGClient shared] checkStickerSetName:text completion:^(NSString *status,
															   NSString *message){
			TGStickerEditorViewController *panel = weakSelf;
			if (!panel)
				return;
			if ([status isEqualToString:@"ok"]){
				panel.setName = text;
				[panel.tableView reloadData];
				[TGAlertSheet showMessage:message title:@"Name" inView:panel.view];
				return;
			}
			[panel offerSuggestionForTitle:panel.setTitle typed:text reason:message];
		}];
	}];
}

- (void)askForType {
	__weak typeof(self) weakSelf = self;
	NSArray *titles = @[@"Stickers", @"Masks"];
	[TGAlertSheet showChoices:titles title:@"Stickers"
			 destructiveIndex:-1 inView:self.view onChoice:^(NSInteger index){
		TGStickerEditorViewController *me = weakSelf;
		me.stickerType = index == 1 ? @"mask" : @"regular";
		[me.tableView reloadData];
	}];
}

/// A name that is taken or malformed is not a dead end: Telegram names the
/// one it would use for this title, and one tap adopts it.
- (void)offerSuggestionForTitle:(NSString *)title typed:(NSString *)typed reason:(NSString *)reason {
	[[TGClient shared] suggestStickerSetNameForTitle:title ?: typed
			completion:^(NSString *suggestion){
		TGStickerEditorViewController *me = self;
		if (!suggestion.length || [suggestion isEqualToString:typed]){
			[TGAlertSheet showMessage:reason ?: @"An error occurred."
								  title:@"Name" inView:me.view];
			return;
		}
		NSString *message = [NSString stringWithFormat:@"%@\n\nTelegram suggests %@.",
				reason ?: @"An error occurred.", suggestion];
		[TGAlertSheet showChoices:@[[NSString stringWithFormat:@"Use %@", suggestion],
									@"Cancel"]
							title:@"Name"
							message:message
				 destructiveIndex:-1
						   inView:me.view
						 onChoice:^(NSInteger index){
			if (index != 0)
				return;
			me.setName = suggestion;
			[me.tableView reloadData];
		}];
	}];
}

- (void)createPack {
	if (self.busy)
		return;
	if (!self.setTitle.length || !self.setName.length){
		[TGAlertSheet showMessage:@"An error occurred."
							  title:@"New Sticker Set" inView:self.view];
		return;
	}
	self.busy = YES;
	[self.tableView reloadData];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] checkStickerSetName:self.setName completion:^(NSString *status,
																   NSString *message){
		TGStickerEditorViewController *me = weakSelf;
		if (!me)
			return;
		if (![status isEqualToString:@"ok"]){
			me.busy = NO;
			[me.tableView reloadData];
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
				[panel.tableView reloadData];
				[TGAlertSheet showMessage:@"An error occurred."
									  title:@"New Sticker Set" inView:panel.view];
				return;
			}
			panel.creating = NO;
			panel.setId = [set[@"id"] longLongValue];
			panel.setName = set[@"name"] ?: panel.setName;
			panel.setTitle = set[@"title"] ?: panel.setTitle;
			panel.stickerType = set[@"stickerType"] ?: @"stickerTypeRegular";
			panel.title = panel.setTitle;
			[panel reloadStickers];
			[TGAlertSheet showMessage:@"Stickers Added"
								  title:@"New Sticker Set" inView:panel.view];
		}];
	}];
}

#pragma mark - editing an existing pack

- (void)askForTitleAndSave {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Edit Sticker Set" message:nil
				placeholder:@"Title" text:self.setTitle action:@"Save"
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
				[TGAlertSheet showMessage:@"An error occurred."
									  title:@"Edit Sticker Set" inView:panel.view];
				return;
			}
			panel.setTitle = text;
			panel.title = text;
			[panel.tableView reloadData];
		}];
	}];
}

- (void)askHowToAdd {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:@[@"Photos", @"Stickers"]
						 title:@"Add Stickers"
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
			[TGAlertSheet showMessage:@"An error occurred."
								  title:@"Add Sticker" inView:me.view];
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
				[TGAlertSheet showMessage:@"An error occurred."
									  title:@"Add Sticker" inView:panel.view];
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
			@"Emoji Tags...", @"Edit Emoji Tags...", @"Edit Keywords...",
			@"Mask Position...", @"Remove Mask Position", nil];
	if (!first)
		[titles addObject:@"Move Up"];
	if (!last)
		[titles addObject:@"Move Down"];
	[titles addObjectsFromArray:@[@"Replace", @"Remove"]];

	NSUInteger removeIndex = [titles indexOfObject:@"Remove"];
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:titles title:[sticker[@"emoji"] length]
			? sticker[@"emoji"] : @"Sticker"
			destructiveIndex:(NSInteger)removeIndex
					   inView:self.view
					 onChoice:^(NSInteger choice){
		TGStickerEditorViewController *me = weakSelf;
		if (!me)
			return;
		NSString *what = titles[(NSUInteger)choice];
		if ([what isEqualToString:@"Emoji Tags..."])
			[me showEmojiTagsForFileId:fileId];
		else if ([what isEqualToString:@"Edit Emoji Tags..."])
			[me askEmojiTagsForFileId:fileId current:sticker[@"emoji"]];
		else if ([what isEqualToString:@"Edit Keywords..."])
			[me askKeywordsForFileId:fileId];
		else if ([what isEqualToString:@"Mask Position..."])
			[me askMaskPositionForFileId:fileId];
		else if ([what isEqualToString:@"Remove Mask Position"])
			[me removeMaskPositionForFileId:fileId];
		else if ([what isEqualToString:@"Move Up"])
			[me moveFileId:fileId toPosition:index - 1];
		else if ([what isEqualToString:@"Move Down"])
			[me moveFileId:fileId toPosition:index + 1];
		else if ([what isEqualToString:@"Replace"]){
			me.replacingFileId = fileId;
			[me pickImageFor:TGStickerPickReplace];
		}
		else if ([what isEqualToString:@"Remove"])
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
					@"Filed under: %@\n\nEvery tag matching %@:\n%@",
					own.count ? [own componentsJoinedByString:@" "] : @"none",
					query.length ? query : @"this sticker",
					all.count ? [all componentsJoinedByString:@" "] : @"none"];
			[TGAlertSheet showMessage:message title:@"Emoji" inView:panel.view];
		}];
	}];
}

- (void)askEmojiTagsForFileId:(NSInteger)fileId current:(NSString *)current {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Emoji"
					message:nil
				placeholder:@"\U0001F600" text:current action:@"Save"
					 inView:self.view onSubmit:^(NSString *text){
		TGStickerEditorViewController *me = weakSelf;
		[[TGClient shared] setStickerFileId:fileId emojis:text completion:^(BOOL ok){
			[me reportSaved:ok title:@"Emoji"];
		}];
	}];
}

- (void)askKeywordsForFileId:(NSInteger)fileId {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Edit"
					message:nil
				placeholder:@"cat, sleeping" text:@"" action:@"Save"
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
			[me reportSaved:ok title:@"Edit"];
		}];
	}];
}

- (void)askMaskPositionForFileId:(NSInteger)fileId {
	NSArray *points = @[@"Forehead", @"Eyes", @"Mouth", @"Chin"];
	NSArray *types = @[@"maskPointForehead", @"maskPointEyes",
					   @"maskPointMouth", @"maskPointChin"];
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:points title:@"Masks"
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
			[me reportSaved:ok title:@"Masks"];
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
		[me reportSaved:ok title:@"Masks"];
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
			[TGAlertSheet showMessage:@"An error occurred."
								  title:@"Reorder" inView:me.view];
		[me reloadStickers];
	}];
}

- (void)removeFileId:(NSInteger)fileId {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:@"Remove"
						title:@"Remove" action:@"Remove" destructive:YES
					   inView:self.view onConfirm:^{
		TGStickerEditorViewController *me = weakSelf;
		[[TGClient shared] removeStickerFileId:fileId completion:^(BOOL ok){
			TGStickerEditorViewController *panel = weakSelf;
			if (!ok)
				[TGAlertSheet showMessage:@"An error occurred."
									  title:@"Remove" inView:panel.view];
			[panel reloadStickers];
		}];
		(void)me;
	}];
}

- (void)reportSaved:(BOOL)ok title:(NSString *)title {
	[TGAlertSheet showMessage:(ok ? @"Saved" : @"An error occurred.")
						  title:title inView:self.view];
	if (ok)
		[self reloadStickers];
}

#pragma mark - photos

- (void)pickImageFor:(TGStickerPick)what {
	if (![UIImagePickerController isSourceTypeAvailable:
			UIImagePickerControllerSourceTypePhotoLibrary]){
		[TGAlertSheet showMessage:@"An error occurred."
							  title:@"Photos" inView:self.view];
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
		[TGAlertSheet showMessage:@"An error occurred."
							  title:@"Photos" inView:self.view];
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
			[TGAlertSheet showMessage:@"An error occurred."
								  title:@"Add Sticker" inView:me.view];
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
					[TGAlertSheet showMessage:@"An error occurred."
										  title:@"Replace" inView:panel.view];
				[panel reloadStickers];
			}];
			return;
		}
		[[TGClient shared] addStickerToSetNamed:me.setName sticker:sticker
				completion:^(BOOL ok){
			TGStickerEditorViewController *panel = weakSelf;
			if (!ok)
				[TGAlertSheet showMessage:@"An error occurred."
									  title:@"Add Sticker" inView:panel.view];
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
		[TGAlertSheet showMessage:(ok ? @"Saved"
									  : @"An error occurred.")
							  title:@"Sticker" inView:me.view];
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
		NSMutableArray *titles = [NSMutableArray arrayWithObject:@"Remove"];
		NSMutableArray *ids = [NSMutableArray arrayWithObject:@(0)];
		for (NSDictionary *sticker in stickers){
			int64_t emojiId = [sticker[@"customEmojiId"] longLongValue];
			if (!emojiId)
				continue;
			[titles addObject:[NSString stringWithFormat:@"%@  ·  %lld",
					[sticker[@"emoji"] length] ? sticker[@"emoji"] : @"Emoji",
					(long long)emojiId]];
			[ids addObject:@(emojiId)];
		}
		[TGAlertSheet showChoices:titles title:@"Sticker"
				 destructiveIndex:-1 inView:me.view onChoice:^(NSInteger index){
			int64_t emojiId = [ids[(NSUInteger)index] longLongValue];
			[[TGClient shared] setCustomEmojiStickerSetNamed:me.setName
					thumbnailCustomEmojiId:emojiId completion:^(BOOL ok){
				[TGAlertSheet showMessage:(ok ? @"Saved"
											  : @"An error occurred.")
									  title:@"Sticker" inView:me.view];
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
	[TGAlertSheet showConfirm:@"Delete Sticker Set"
						title:@"Delete Sticker Set" action:@"Delete" destructive:YES
					   inView:self.view onConfirm:^{
		TGStickerEditorViewController *me = weakSelf;
		[[TGClient shared] deleteStickerSetNamed:me.setName completion:^(BOOL ok){
			TGStickerEditorViewController *panel = weakSelf;
			if (!ok){
				[TGAlertSheet showMessage:@"An error occurred."
									  title:@"Delete Sticker Set" inView:panel.view];
				return;
			}
			[panel.navigationController popViewControllerAnimated:YES];
		}];
	}];
}

@end
