#import "TGEmojiPanel.h"
#import "TGEmojiData.h"
#import "TGCapabilities.h"
#import "TGEmojiStore.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGPopupMenu.h"
#import "TGStickerStore.h"
#import "TGClientNotifications.h"
#import "UIImage+WebP.h"
#import <QuartzCore/QuartzCore.h>
#import "TGStyle.h"
#import "TGMessageLayout.h"
#import "TGAlertSheet.h"
#import "TGLottieView.h"
#import "TGCustomEmojiStore.h"
#import <objc/runtime.h>
#import "TGEmojiPanelInternal.h"


static const char kTGItemDataKey = 0;

static inline void TGSetButtonItemData(UIButton *button, id item) {
	objc_setAssociatedObject(button, &kTGItemDataKey, item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static inline id TGGetButtonItemData(UIButton *button) {
	return objc_getAssociatedObject(button, &kTGItemDataKey);
}

/// The first character a title can show for a set with no cover: a whole
/// composed character, never half a surrogate pair, and never one no font has.
static NSString *TGFirstDrawableCharacter(NSString *title) {
	NSString *shown = TGStripUndrawableScalars(title ?: @"");
	return shown.length
			? [shown substringWithRange:[shown rangeOfComposedCharacterSequenceAtIndex:0]] : @"?";
}

/// A set row as the search feed draws it: the tile carries the whole record
/// so the install sheet has the id and the count, and a cover to show.
static NSArray *TGPackSearchTiles(NSArray *sets) {
	NSMutableArray *found = [NSMutableArray array];
	for (NSDictionary *set in (sets ?: @[])){
		if (![set isKindOfClass:NSDictionary.class] || !set[@"id"])
			continue;
		NSMutableDictionary *tile = [NSMutableDictionary dictionary];
		tile[@"pack"] = set;
		NSDictionary *cover = set[@"cover"];
		NSString *icon = cover[@"emoji"];
		if ([icon length])
			tile[@"emoji"] = icon;
		else if ([set[@"title"] length])
			tile[@"emoji"] = TGFirstDrawableCharacter(set[@"title"]);
		NSNumber *thumbId = cover[@"thumbId"];
		if ([thumbId isKindOfClass:NSNumber.class])
			tile[@"thumbId"] = thumbId;
		[found addObject:tile];
	}
	return found;
}

static const CGFloat kStripHeight = TGMetricEmojiStripHeight;   // categories / sets along the top
static const CGFloat kTabsHeight  = TGMetricEmojiTabsHeight;   // Emoji | Stickers | GIFs
static const CGFloat kEmojiCell   = TGMetricEmojiCell;
/// The backspace key at the end of the tab row, and the arrow drawn on it.
static const CGFloat kBackspaceWidth  = 46.0f;
static const CGFloat kBackspaceGlyphW = TGMetricBubbleDiscColumn;
static const CGFloat kBackspaceGlyphH = TGMetricStampTicksRoom;

static const NSInteger kItemTagBase = 1000;  // grid buttons carry their index
static const NSInteger kHeaderTag   = 900;   // a section title in the feed
static const CGFloat   kHeaderHeight = TGMetricEmojiHeader;
static const CGFloat   kPreviewHeaderWidth = 240.0f;
static const CGFloat   kPreviewHeaderHeight = 130.0f;
static const CGFloat   kPreviewSide = 110.0f;
/// The emoji card's header is the glyph alone; an animation preview adds a
/// caption line under the renderer.
static const CGFloat   kEmojiCardHeaderHeight = 100.0f;
static const CGFloat   kEmojiPreviewHeaderHeight = 150.0f;
static const CGFloat   kEmojiPreviewCaptionHeight = 24.0f;

/// Pictures decoded for the grid and the strip, by file id; shared by every
/// panel so reopening one draws at once.
static NSCache *TGPanelImageCache(void) {
	static NSCache *cache = nil;
	if (!cache){
		cache = [[NSCache alloc] init];
		cache.countLimit = 160;
	}
	return cache;
}

/// A still picture from a file TDLib downloaded: JPEG and PNG through UIKit,
/// WebP through the decoder the app carries.
static UIImage *TGPanelDecode(NSString *path) {
	if (!path.length)
		return nil;
	UIImage *image = nil;
	if (![path.pathExtension.lowercaseString isEqualToString:@"webp"])
		image = [UIImage imageWithContentsOfFile:path];
	if (!image)
		image = [UIImage convertFromWebP:path compressedData:nil error:nil];
	return image;
}

/// The key that deletes backwards, from TGIconPaths.
static UIImage *TGBackspaceImage(UIColor *colour) {
	return [TGIcons glyphNamed:@"backspace" colour:colour side:kBackspaceGlyphW];
}



@implementation TGEmojiPanel (TGEmojiPanelBase)


+ (void)initialize {
	if (self != [TGEmojiPanel class])
		return;
	// The decoded-thumbnail cache is keyed by TDLib file id, so one id names a
	// different picture after an account switch. The cache is a file-scope
	// static shared by every panel, so it is emptied when the account changes
	// instead of drawing the previous account's sticker under a new one.
	[[NSNotificationCenter defaultCenter]
			addObserverForName:TGAccountDidSwitchNotification
						object:nil queue:[NSOperationQueue mainQueue]
				 usingBlock:^(NSNotification *note){
		[TGPanelImageCache() removeAllObjects];
	}];
}

+ (CGFloat)preferredHeight {
	return TGMetricEmojiPanelHeight;
}

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (!self)
		return nil;

	CGFloat w = frame.size.width;
	CGFloat h = frame.size.height;

	self.strip = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, w, kStripHeight)];
	self.strip.showsHorizontalScrollIndicator = NO;
	self.strip.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.strip.scrollsToTop = NO;
	[self addSubview:self.strip];

	self.stripLine = [[UIView alloc] initWithFrame:CGRectMake(0, kStripHeight - TGMetricHairline, w, TGMetricHairline)];
	self.stripLine.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self addSubview:self.stripLine];

	self.grid = [[UIScrollView alloc] initWithFrame:
			CGRectMake(0, kStripHeight, w, h - kStripHeight - kTabsHeight)];
	self.grid.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.grid.alwaysBounceVertical = YES;
	self.grid.scrollsToTop = NO;
	self.grid.delegate = self;
	[self addSubview:self.grid];

	self.emptyLabel = [[UILabel alloc] initWithFrame:self.grid.frame];
	self.emptyLabel.autoresizingMask = self.grid.autoresizingMask;
	self.emptyLabel.textAlignment = NSTextAlignmentCenter;
	self.emptyLabel.font = TGFontBody();
	self.emptyLabel.backgroundColor = [UIColor clearColor];
	self.emptyLabel.numberOfLines = 2;
	self.emptyLabel.hidden = YES;
	[self addSubview:self.emptyLabel];

	self.tabs = [[UIView alloc] initWithFrame:CGRectMake(0, h - kTabsHeight, w, kTabsHeight)];
	self.tabs.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
	[self addSubview:self.tabs];

	self.tabsLine = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, TGMetricHairline)];
	self.tabsLine.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.tabs addSubview:self.tabsLine];

	NSArray *titles = @[@"Emoji", @"Stickers", @"GIFs", @"Custom"];
	NSMutableArray *buttons = [NSMutableArray array];
	CGFloat tabW = TGMetricPersonRow;
	CGFloat x = TGCenteredOrigin(w, tabW * titles.count);
	for (NSUInteger i = 0; i < titles.count; i++){
		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		button.frame = CGRectMake(x + tabW * i, 0, tabW, kTabsHeight);
		button.tag = (NSInteger)i;
		button.titleLabel.font = TGFontSubheadStrong();
		button.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
		[button setTitle:titles[i] forState:UIControlStateNormal];
		[button addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];
		[self.tabs addSubview:button];
		[buttons addObject:button];
	}
	self.tabButtons = buttons;

	self.backspace = [UIButton buttonWithType:UIButtonTypeCustom];
	self.backspace.frame = CGRectMake(w - kBackspaceWidth, 0, kBackspaceWidth, kTabsHeight);
	self.backspace.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	[self.backspace addTarget:self action:@selector(backspaceTapped)
			 forControlEvents:UIControlEventTouchUpInside];
	[self.tabs addSubview:self.backspace];

	self.requested = [NSMutableSet set];
	self.cells = [NSMutableDictionary dictionary];

	self.pool = [NSMutableArray array];
	// A set installed, a GIF saved or a sticker favourited on another client
	// lands here; the tab is re-asked rather than latched until it is reopened.
	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(stickerListsChanged)
				name:TGStickerListsChangedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(customEmojiLoaded:)
				name:TGCustomEmojiLoadedNotification object:nil];
	[self applyTheme];
	[self selectTab:TGEmojiPanelTabEmoji];
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
}

/// Installing a set fires one update per list it touches, so the re-read waits
/// out the burst. The emoji tab reads none of these lists.
- (void)stickerListsChanged {
	if (self.tab == TGEmojiPanelTabEmoji)
		return;
	self.customEmojiLoaded = NO;
	[NSObject cancelPreviousPerformRequestsWithTarget:self
			selector:@selector(reselectCurrentTab) object:nil];
	[self performSelector:@selector(reselectCurrentTab) withObject:nil afterDelay:0.3];
}

- (void)reselectCurrentTab {
	[self selectTab:self.tab];
}

- (void)applyTheme {
	TGTheme *theme = [TGTheme shared];
	self.backgroundColor = [theme inputBarColour];
	self.stripLine.backgroundColor = [theme separatorColour];
	self.tabsLine.backgroundColor = [theme separatorColour];
	self.emptyLabel.textColor = [theme secondaryTextColour];
	[self.backspace setImage:TGBackspaceImage([theme secondaryTextColour]) forState:UIControlStateNormal];
	for (UIButton *button in self.tabButtons){
		BOOL on = button.tag == self.tab;
		[button setTitleColor:on ? [theme accentColour] : [theme secondaryTextColour]
					 forState:UIControlStateNormal];
	}
	[self reloadStrip];
}


@end
