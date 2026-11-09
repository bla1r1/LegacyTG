//
// TGBackgroundsViewController.m - the chat wallpaper gallery.
//
// The official screen is two actions, a footer, then the account's installed
// backgrounds as a square-tile grid. The thumbnails are baked once: a pattern
// is its fill plus the pattern image, a photo is the downloaded picture.
//
#import "TGBackgroundsViewController.h"
#import "TGBackgroundEditorViewController.h"
#import "TGBackgroundStore.h"
#import "TGAlertSheet.h"
#import "TGSettingsFormatting.h"
#import "TGStyle.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import "TGRows.h"
#import "TGGridRowCell.h"
#import <QuartzCore/QuartzCore.h>

/// The current theme's wallpaper is the first cell in the gallery, the way
/// official shows the active background before the collection.
static NSDictionary *TGBThemeWallpaperItem(void) {
	NSString *name = [[TGTheme shared] importedName];
	return @{
		@"id" : @"theme-wallpaper",
		@"title" : name.length ? name : @"Classic",
		@"themeWallpaper" : @YES,
	};
}

/// TDLib's RGB integer as a colour. This is server data - the colour Telegram
/// itself draws the wallpaper with - not a design token.
static UIColor *TGBackgroundColour(NSInteger rgb) {
	CGFloat red   = (CGFloat)((rgb >> 16) & 0xFF) / 255.0f;
	CGFloat green = (CGFloat)((rgb >> 8) & 0xFF) / 255.0f;
	CGFloat blue  = (CGFloat)(rgb & 0xFF) / 255.0f;
	return [UIColor colorWithRed:red green:green blue:blue alpha:1.0f];
}

static CGSize TGBBackgroundThumbSize(void) {
	return CGSizeMake(TGMetricBackgroundThumbSide,
			TGMetricBackgroundThumbSide * TGMetricBackgroundGridAspect);
}

static void TGBDrawFilling(UIImage *image, CGRect rect, CGBlendMode mode) {
	if (!image || image.size.width <= 0 || image.size.height <= 0)
		return;
	CGFloat scale = MAX(rect.size.width / image.size.width,
			rect.size.height / image.size.height);
	CGSize drawn = CGSizeMake(image.size.width * scale, image.size.height * scale);
	CGRect frame = CGRectMake(CGRectGetMinX(rect) + TGCenteredOrigin(rect.size.width, drawn.width),
			CGRectGetMinY(rect) + TGCenteredOrigin(rect.size.height, drawn.height),
			drawn.width, drawn.height);
	[image drawInRect:frame blendMode:mode alpha:TGAlphaOpaque];
}

/// One grid picture: the background's fill, its pattern or photo, all clipped
/// to the cell's rounded rectangle. Called once per background, then cached.
static UIImage *TGBackgroundThumbnail(NSDictionary *background, UIImage *source) {
	CGSize size = TGBBackgroundThumbSize();
	UIGraphicsBeginImageContextWithOptions(size, YES, 0);
	CGRect rect = CGRectMake(0, 0, size.width, size.height);
	UIBezierPath *clip = [UIBezierPath bezierPathWithRoundedRect:rect
			cornerRadius:TGMetricCornerMedium];
	[clip addClip];

	NSNumber *fill = background[@"fillColour"];
	UIColor *fallback = fill ? TGBackgroundColour(fill.integerValue)
			: [[TGTheme shared] groupedBackgroundColour];
	[fallback setFill];
	UIRectFill(rect);

	if (background[@"localWallpaperType"]){
		UIImage *texture = [TGTheme textureImageForType:
				(TGWallpaperType)[background[@"localWallpaperType"] integerValue]];
		TGBDrawFilling(texture, rect, kCGBlendModeNormal);
	} else if (background[@"themeWallpaper"]){
		UIImage *paper = [[TGTheme shared] wallpaper];
		if (paper)
			TGBDrawFilling(paper, rect, kCGBlendModeNormal);
	} else if (source){
		TGBDrawFilling(source, rect, kCGBlendModeNormal);
	}
	// A server pattern is not drawn here: TGBackgroundStore bakes the real
	// .tgv over this fill, and the cell keeps the fill until it arrives.

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

/// Which cell carries the check: the theme default when no local choice is
/// in force, a texture when its type is selected, or the server's default.
static BOOL TGBBackgroundIsCurrent(NSDictionary *background, int64_t currentId) {
	TGTheme *theme = [TGTheme shared];
	if ([background[@"themeWallpaper"] boolValue])
		return [theme wallpaperType] == TGWallpaperTypeNone;
	NSNumber *localType = background[@"localWallpaperType"];
	if ([localType isKindOfClass:NSNumber.class])
		return [theme wallpaperType] == (TGWallpaperType)localType.integerValue;
	int64_t identifier = [background[@"id"] longLongValue];
	return identifier == currentId || [background[@"isDefault"] boolValue];
}

@interface TGBackgroundsViewController () <UINavigationControllerDelegate,
		UIImagePickerControllerDelegate>
@property (nonatomic, strong) NSArray *installed;
@property (nonatomic, strong) NSMutableDictionary *previews;
@property (nonatomic, strong) NSMutableSet *requested;
@property (nonatomic, copy) NSString *errorText;
@property (nonatomic, assign) BOOL editingBackgrounds;
@property (nonatomic, assign) BOOL loadedDarkTheme;
@property (nonatomic, assign) BOOL hasLoaded;
@end

@implementation TGBackgroundsViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGLocalized(@"Chat Wallpaper");
	self.installed = @[];
	self.previews = [NSMutableDictionary dictionary];
	self.requested = [NSMutableSet set];
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
			initWithTitle:TGLocalized(@"Edit")
					style:UIBarButtonItemStylePlain
				   target:self action:@selector(toggleEditing)];
	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(patternThumbnailReady:)
				name:TGBackgroundStoreChangedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(themeChanged:)
				name:TGThemeChangedNotification object:nil];
	[self applyTheme];
	[self loadInstalled];
}

- (void)patternThumbnailReady:(NSNotification *)note {
	(void)note;
	[self reloadRows];
}

- (void)themeChanged:(NSNotification *)note {
	(void)note;
	// The theme wallpaper's picture and the light/dark shelf both change.
	if (self.hasLoaded)
		[self loadInstalled];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self applyTheme];
	if (self.hasLoaded)
		[self loadInstalled];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - loading

- (void)loadInstalled {
	BOOL dark = [[TGTheme shared] isDark];
	self.loadedDarkTheme = dark;
	self.hasLoaded = YES;
	__weak typeof(self) weakSelf = self;
	[[TGBackgroundStore shared] installedBackgroundsForDarkTheme:dark
			completion:^(NSArray *backgrounds, NSString *error){
		weakSelf.installed = TGSettingsBackgroundsForDarkTheme(backgrounds, dark);
		weakSelf.errorText = error;
		[weakSelf rebuild];
	}];
}

- (void)rebuild {
	self.sections = [self buildSections];
	[self reloadRows];
}

#pragma mark - sections

- (CGFloat)gridWidth {
	CGFloat width = self.tableView.bounds.size.width - TGMetricGridTableMargin;
	return width > 0 ? width : TGMetricScreenWidth - TGMetricGridTableMargin;
}

- (NSInteger)gridColumns {
	return TGGridColumnsForWidth([self gridWidth], TGMetricBackgroundThumbSide);
}

- (NSArray *)buildSections {
	__weak typeof(self) weakSelf = self;
	NSMutableArray *sections = [NSMutableArray array];
	[sections addObject:TGSection(nil,
			TGLocalized(@"You can set a custom background image and share it with your friends."),
			@[
		TGTapRow(TGLocalized(@"Set a Color"), nil,
				^{ [weakSelf openEditor]; }),
		TGTapRow(TGLocalized(@"Choose from Photos"), nil,
				^{ [weakSelf presentPicker]; }),
	])];

	if (self.errorText.length)
		[sections addObject:TGSection(nil, nil,
				@[TGRow(TGKindPlain, self.errorText)])];

	NSMutableArray *items = [NSMutableArray array];
	[items addObject:TGBThemeWallpaperItem()];
	[items addObjectsFromArray:TGSettingsWallpaperGridItems(
			TGSettingsLocalWallpaperItems(), self.installed)];

	int64_t current = [[TGBackgroundStore shared]
			defaultBackgroundIdForDarkTheme:[[TGTheme shared] isDark]];
	NSMutableArray *tiles = [NSMutableArray array];
	for (NSDictionary *background in items){
		UIImage *image = [self previewForBackground:background];
		NSMutableDictionary *tile = [NSMutableDictionary dictionary];
		if (image)
			tile[TGGridItemImage] = image;
		tile[TGGridItemInitials] = [TGIcons initialsForTitle:
				background[@"title"] ?: @""] ?: @"";
		tile[TGGridItemChecked] = @(TGBBackgroundIsCurrent(background, current));
		[tiles addObject:tile];
	}

	NSInteger columns = [self gridColumns];
	NSMutableArray *rows = [NSMutableArray array];
	for (NSUInteger start = 0; start < tiles.count;
			start += (NSUInteger)columns){
		NSRange range = NSMakeRange(start, MIN((NSUInteger)columns,
				tiles.count - start));
		NSArray *line = [tiles subarrayWithRange:range];
		[rows addObject:TGGridRow(line, columns, ^(NSInteger index){
			NSUInteger absolute = start + (NSUInteger)index;
			TGBackgroundsViewController *me = weakSelf;
			if (me && absolute < items.count)
				[me tappedBackground:items[absolute]];
		})];
	}
	[sections addObject:TGSection(nil, nil, rows)];
	return sections;
}

#pragma mark - previews

- (UIImage *)previewForBackground:(NSDictionary *)background {
	id identifier = background[@"id"];
	UIImage *cached = self.previews[identifier];
	if (cached)
		return cached;

	if (background[@"localWallpaperType"] || background[@"themeWallpaper"]){
		UIImage *image = TGBackgroundThumbnail(background, nil);
		if (image && identifier)
			self.previews[identifier] = image;
		return image;
	}

	if ([background[@"typeName"] isEqualToString:@"pattern"]){
		UIImage *image = [[TGBackgroundStore shared]
				patternThumbnailForBackground:background
										 size:TGBBackgroundThumbSize()
										 dark:[[TGTheme shared] isDark]];
		if (image){
			if (identifier)
				self.previews[identifier] = image;
			return image;
		}
		return TGBackgroundThumbnail(background, nil);
	}

	if (identifier && ![self.requested containsObject:identifier]){
		[self.requested addObject:identifier];
		__weak typeof(self) weakSelf = self;
		[[TGBackgroundStore shared] loadThumbnailForBackground:background
				completion:^(UIImage *image){
			if (!image)
				return;
			weakSelf.previews[identifier] = TGBackgroundThumbnail(background, image);
			[weakSelf reloadRows];
		}];
	}
	return TGBackgroundThumbnail(background, nil);
}

#pragma mark - actions

- (void)openEditor {
	TGBackgroundEditorViewController *editor =
			[[TGBackgroundEditorViewController alloc] init];
	editor.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:editor animated:YES];
}

- (void)toggleEditing {
	self.editingBackgrounds = !self.editingBackgrounds;
	self.navigationItem.rightBarButtonItem.title = self.editingBackgrounds
			? TGLocalized(@"Done") : TGLocalized(@"Edit");
	[self rebuild];
}

- (void)tappedBackground:(NSDictionary *)background {
	if (!self.editingBackgrounds){
		if ([background[@"themeWallpaper"] boolValue]){
			[[TGTheme shared] setWallpaperType:TGWallpaperTypeNone];
			[self rebuild];
			return;
		}
		NSNumber *localType = background[@"localWallpaperType"];
		if ([localType isKindOfClass:NSNumber.class]){
			[[TGTheme shared] setWallpaperType:
					(TGWallpaperType)localType.integerValue];
			[self rebuild];
			return;
		}
		__weak typeof(self) weakSelf = self;
		[[TGBackgroundStore shared] setDefaultBackground:background
				forDarkTheme:[[TGTheme shared] isDark]
				completion:^(NSDictionary *installed, NSString *error){
			if (!installed){
				[TGAlertSheet showMessage:(error ?: TGLocalized(@"An error occurred."))
									 title:TGLocalized(@"Chat Wallpaper")
									inView:weakSelf.view];
				return;
			}
			[weakSelf loadInstalled];
		}];
		return;
	}

	if ([background[@"themeWallpaper"] boolValue] ||
		[background[@"localWallpaperType"] isKindOfClass:NSNumber.class])
		return;

	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:nil
						title:TGLocalized(@"Remove Wallpaper")
					   action:TGLocalized(@"Remove") destructive:YES inView:self.view
					onConfirm:^{
		[[TGBackgroundStore shared] removeInstalledBackground:
				[background[@"id"] longLongValue]
				completion:^(BOOL ok, NSString *error){
			if (!ok){
				[TGAlertSheet showMessage:(error ?: TGLocalized(@"An error occurred."))
									 title:TGLocalized(@"Remove Wallpaper")
									inView:weakSelf.view];
				return;
			}
			[weakSelf loadInstalled];
		}];
	}];
}

#pragma mark - photos

- (void)presentPicker {
	if (![UIImagePickerController isSourceTypeAvailable:
			UIImagePickerControllerSourceTypePhotoLibrary])
		return;
	UIImagePickerController *picker = [[UIImagePickerController alloc] init];
	picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
	picker.delegate = self;
	[self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker
		didFinishPickingMediaWithInfo:(NSDictionary *)info {
	[picker dismissViewControllerAnimated:YES completion:nil];
	UIImage *image = info[UIImagePickerControllerOriginalImage];
	if (!image)
		return;
	[[TGTheme shared] setWallpaperImage:image];
	[self loadInstalled];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
	[picker dismissViewControllerAnimated:YES completion:nil];
}

@end

// vim:ft=objc
