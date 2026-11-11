//
// TGGiftViewController.m - detail screen for a received gift.
//
#import "TGGiftViewController.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGLottieView.h"
#import "TGIcons.h"
#import "TGCapabilities.h"
#import "TGMessageLayout.h"
#import "TGGiftText.h"
#import "TGRows.h"
#import "TGMessageStore.h"
#import "TGDownloadPriority.h"

static const CGFloat kArtSide = TGMetricProfilePhotoSide;
static const CGFloat kHeaderPadTop = TGMetricPadLarge;
static const CGFloat kHeaderPadMid = TGMetricPadMedium;
static const CGFloat kHeaderPadBottom = TGMetricPadLarge;
static const CGFloat kTitleHeight = TGMetricLineTitle;
static const CGFloat kHeaderHeight = TGMetricPadLarge + TGMetricProfilePhotoSide + TGMetricPadMedium + TGMetricLineTitle + TGMetricLineMicro + TGMetricPadLarge;
static const CGFloat kRGBDivisor = 255.0f;

static UIImage *TGGiftRadialGradient(int32_t centerColor, int32_t edgeColor, CGFloat side) {
	static NSCache *cache = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		cache = [[NSCache alloc] init];
	});
	NSString *key = [NSString stringWithFormat:@"%x-%x@%g", centerColor, edgeColor, side];
	UIImage *cached = [cache objectForKey:key];
	if (cached)
		return cached;

	CGFloat rC = ((centerColor >> 16) & 0xFF) / kRGBDivisor;
	CGFloat gC = ((centerColor >> 8)  & 0xFF) / kRGBDivisor;
	CGFloat bC = ( centerColor        & 0xFF) / kRGBDivisor;

	CGFloat rE = ((edgeColor >> 16) & 0xFF) / kRGBDivisor;
	CGFloat gE = ((edgeColor >> 8)  & 0xFF) / kRGBDivisor;
	CGFloat bE = ( edgeColor        & 0xFF) / kRGBDivisor;

	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGFloat components[8] = {
		rC, gC, bC, 1.0f,
		rE, gE, bE, 1.0f
	};
	CGFloat locations[2] = { 0.0f, 1.0f };
	CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, components, locations, 2);

	UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), YES, [UIScreen mainScreen].scale);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGPoint center = CGPointMake(TGHalf(side), TGHalf(side));
	CGFloat radius = side;
	CGContextDrawRadialGradient(ctx, gradient, center, 0, center, radius, kCGGradientDrawsAfterEndLocation);
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

	CGGradientRelease(gradient);
	CGColorSpaceRelease(colorSpace);

	if (image)
		[cache setObject:image forKey:key];
	return image;
}

@interface TGGiftViewController ()
@property (nonatomic, copy) NSDictionary *gift;
@property (nonatomic, strong) TGLottieView *lottieView;
@property (nonatomic, assign) int64_t requestedUserId;
@property (nonatomic, strong) UIButton *closeButton;
/// The sender line in the table header. The name may arrive after the header
/// is built, and the header is not a cell, so it is updated in place.
@property (nonatomic, weak) UILabel *senderLabel;
@end

@implementation TGGiftViewController

- (instancetype)initWithGift:(NSDictionary *)gift {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self) {
		_gift = [gift copy] ?: @{};
	}
	return self;
}

- (instancetype)init {
	return [self initWithGift:@{}];
}

- (instancetype)initWithStyle:(UITableViewStyle)style {
	return [self initWithGift:@{}];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_lottieView stop];
	_lottieView = nil;
}

- (NSString *)currentGiftId {
	id rid = self.gift[@"receivedGiftId"];
	if ([rid isKindOfClass:[NSString class]] && [rid length] > 0)
		return rid;
	if ([self.gift[@"isCollectible"] boolValue]) {
		return [NSString stringWithFormat:@"col_%@_%ld", self.gift[@"title"] ?: @"", (long)[self.gift[@"number"] integerValue]];
	}
	return [NSString stringWithFormat:@"reg_%lld_%lld", [self.gift[@"giftId"] longLongValue], [self.gift[@"starCount"] longLongValue]];
}

- (NSString *)giftNote {
	id note = self.gift[@"note"];
	if ([note isKindOfClass:[NSString class]] && [note length] > 0)
		return note;
	id msg = self.gift[@"message"];
	if ([msg isKindOfClass:[NSString class]] && [msg length] > 0)
		return msg;
	return @"";
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGLocalized(@"Gift");


	[self applyTheme];
	[self setupTableHeader];
	[self rebuildSections];

	// The art is the screen: no bar, and a Close X sits over it as official
	// draws it.
	self.closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.closeButton.frame = CGRectMake(TGMetricPadMedium, TGMetricPadMedium,
			TGMetricStoryCloseSide, TGMetricStoryCloseSide);
	[self.closeButton setImage:[TGIcons glyphNamed:@"close"
			colour:[[TGTheme shared] primaryTextColour]
			side:TGMetricStoryCloseSide - TGMetricPadSmall]
			forState:UIControlStateNormal];
	[self.closeButton addTarget:self action:@selector(closeTapped)
			forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:self.closeButton];

}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self.navigationController setNavigationBarHidden:YES animated:NO];
	[self applyTheme];
	if (self.lottieView.loaded && [TGCapabilities canPlayAnimatedStickers] && [TGCapabilities animatedStickersWanted]) {
		[self.lottieView play];
	}
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[self.navigationController setNavigationBarHidden:NO animated:NO];
	[self.lottieView stop];
}

- (void)closeTapped {
	if (self.navigationController.presentingViewController)
		[self.navigationController dismissViewControllerAnimated:YES completion:nil];
	else
		[self.navigationController popViewControllerAnimated:YES];
}

- (void)applyTheme {
	[super applyTheme];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (NSString *)headerTitleText {
	if ([self.gift[@"isCollectible"] boolValue]) {
		NSString *title = [self.gift[@"title"] isKindOfClass:[NSString class]] ? self.gift[@"title"] : @"";
		NSInteger number = [self.gift[@"number"] integerValue];
		if (title.length > 0 && number > 0) {
			return [NSString stringWithFormat:@"%@ #%ld", title, (long)number];
		} else if (number > 0) {
			return [NSString stringWithFormat:@"#%ld", (long)number];
		} else if (title.length > 0) {
			return title;
		}
		return @"Gift";
	} else {
		NSInteger stars = [self.gift[@"starCount"] integerValue];
		if (stars > 0) {
			return TGLocalizedFormat(@"%@ Stars", @(stars));
		}
		NSString *title = [self.gift[@"title"] isKindOfClass:[NSString class]] ? self.gift[@"title"] : @"";
		return title.length > 0 ? title : @"Gift";
	}
}

- (void)setupTableHeader {
	CGFloat width = self.tableView.bounds.size.width;
	if (width <= 0)
		width = TGMetricScreenWidth;

	UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, kHeaderHeight)];
	header.backgroundColor = [UIColor clearColor];

	CGFloat artX = TGCenteredOrigin(width, kArtSide);
	CGRect artFrame = CGRectMake(artX, kHeaderPadTop, kArtSide, kArtSide);
	UIView *artContainer = [[UIView alloc] initWithFrame:artFrame];
	artContainer.layer.cornerRadius = TGMetricCornerCard;
	artContainer.clipsToBounds = YES;
	[header addSubview:artContainer];

	BOOL isCollectible = [self.gift[@"isCollectible"] boolValue];
	if (isCollectible) {
		UIImageView *bg = [[UIImageView alloc] initWithFrame:artContainer.bounds];
		bg.contentMode = UIViewContentModeScaleAspectFill;
		bg.clipsToBounds = YES;
		[artContainer addSubview:bg];

		int32_t centerColor = [self.gift[@"backdropCenterColor"] intValue];
		int32_t edgeColor = [self.gift[@"backdropEdgeColor"] intValue];
		__weak typeof(bg) weakBg = bg;
		__weak typeof(self) weakSelf = self;
		NSString *giftId = [self currentGiftId];

		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			UIImage *bgImage = TGGiftRadialGradient(centerColor, edgeColor, kArtSide);
			dispatch_async(dispatch_get_main_queue(), ^{
				if (weakSelf && [weakSelf.currentGiftId isEqualToString:giftId]) {
					weakBg.image = bgImage;
				}
			});
		});
	} else {
		artContainer.backgroundColor = [[TGTheme shared] cardBackgroundColour];
	}

	UIImageView *stillView = [[UIImageView alloc] initWithFrame:artContainer.bounds];
	stillView.contentMode = UIViewContentModeScaleAspectFit;
	stillView.clipsToBounds = YES;
	[artContainer addSubview:stillView];

	TGLottieView *lottie = [[TGLottieView alloc] initWithFrame:artContainer.bounds];
	lottie.clipsToBounds = YES;
	[artContainer addSubview:lottie];
	self.lottieView = lottie;

	NSNumber *stillId = isCollectible ? self.gift[@"modelThumbFileId"] : (self.gift[@"thumbFileId"] ?: self.gift[@"stickerThumbFileId"]);
	NSNumber *stickerId = isCollectible ? self.gift[@"modelStickerFileId"] : self.gift[@"stickerFileId"];

	__weak typeof(self) weakSelf = self;
	__weak typeof(stillView) weakStill = stillView;
	__weak typeof(lottie) weakLottie = lottie;
	NSString *giftId = [self currentGiftId];

	if ([stillId isKindOfClass:[NSNumber class]] && [stillId integerValue] > 0) {
		[[TGMessageStore shared] downloadFile:stillId.integerValue
							   priority:TGDownloadPriorityOnScreen
							 completion:^(NSString *path){
			if (!path.length) return;
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				UIImage *img = [TGIcons decodedImageAtPath:path
											   fittingSize:CGSizeMake(kArtSide, kArtSide)
													  fill:NO
													 scale:[UIScreen mainScreen].scale];
				if (!img) return;
				dispatch_async(dispatch_get_main_queue(), ^{
					if (weakSelf && [weakSelf.currentGiftId isEqualToString:giftId]) {
						weakStill.image = img;
					}
				});
			});
		}];
	}

	if ([stickerId isKindOfClass:[NSNumber class]] && [stickerId integerValue] > 0) {
		[[TGMessageStore shared] downloadFile:stickerId.integerValue
							   priority:TGDownloadPriorityOnScreen
							 completion:^(NSString *path){
			if (!path.length) return;
			dispatch_async(dispatch_get_main_queue(), ^{
				if (!weakSelf || ![weakSelf.currentGiftId isEqualToString:giftId])
					return;
				BOOL canPlay = [TGCapabilities canPlayAnimatedStickers] && [TGCapabilities animatedStickersWanted];
				weakLottie.onStickerReady = ^{
					if (!weakSelf || ![weakSelf.currentGiftId isEqualToString:giftId])
						return;
					if (canPlay) {
						[weakLottie play];
					} else {
						[weakLottie stop];
					}
				};
				if ([weakLottie loadStickerFile:path]) {
					if (canPlay) {
						[weakLottie play];
					} else {
						[weakLottie stop];
					}
				}
			});
		}];
	}

	CGFloat titleY = kHeaderPadTop + kArtSide + kHeaderPadMid;
	CGFloat titleW = width - TGDoubled(TGMetricPadLarge);
	UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(TGMetricPadLarge, titleY, titleW, kTitleHeight)];
	titleLabel.text = [self headerTitleText];
	titleLabel.font = TGFontTitle();
	titleLabel.textColor = [[TGTheme shared] primaryTextColour];
	titleLabel.textAlignment = NSTextAlignmentCenter;
	titleLabel.backgroundColor = [UIColor clearColor];
	[header addSubview:titleLabel];

	// The sender belongs under the art, not in a "From" row below it.
	UILabel *senderLabel = [[UILabel alloc] initWithFrame:CGRectMake(
			TGMetricPadLarge, titleY + kTitleHeight, titleW, TGMetricLineMicro)];
	senderLabel.text = [self senderText];
	senderLabel.font = TGFontSubhead();
	senderLabel.textColor = [[TGTheme shared] secondaryTextColour];
	senderLabel.textAlignment = NSTextAlignmentCenter;
	senderLabel.backgroundColor = [UIColor clearColor];
	[header addSubview:senderLabel];
	self.senderLabel = senderLabel;

	self.tableView.tableHeaderView = header;
}

- (NSString *)senderText {
	NSString *name = [self senderDisplayName];
	return TGGiftSenderText(name);
}

- (void)requestSenderUserIfNeeded:(int64_t)userId {
	if (self.requestedUserId == userId || userId == 0)
		return;
	self.requestedUserId = userId;
	__weak typeof(self) weakSelf = self;
	[[TGMessageStore shared] ensureUserName:userId completion:^{
		dispatch_async(dispatch_get_main_queue(), ^{
			TGGiftViewController *me = weakSelf;
			if (!me) return;
			// The sender is in the header, not row 0 (which is Date now).
			me.senderLabel.text = [me senderText];
			[me.senderLabel setNeedsLayout];
		});
	}];
}

- (NSString *)senderDisplayName {
	if ([self.gift[@"isPrivate"] boolValue]) {
		return @"Hidden";
	}

	int64_t userId = [self.gift[@"senderUserId"] longLongValue];
	if (userId > 0) {
		NSString *userName = [[TGMessageStore shared] nameForUserId:userId];
		if (userName.length > 0) {
			return userName;
		}
		[self requestSenderUserIfNeeded:userId];
		return @"";
	}

	int64_t chatId = [self.gift[@"senderChatId"] longLongValue];
	if (chatId != 0) {
		NSString *chatTitle = [[TGMessageStore shared] titleForChat:chatId];
		if (chatTitle.length > 0) {
			return chatTitle;
		}
	}

	return @"";
}

- (NSString *)formattedDate {
	NSNumber *unix = self.gift[@"date"];
	if (![unix isKindOfClass:[NSNumber class]] || [unix doubleValue] <= 0)
		return @"";
	static NSDateFormatter *fmt = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		fmt = [[NSDateFormatter alloc] init];
		fmt.dateStyle = NSDateFormatterMediumStyle;
		fmt.timeStyle = NSDateFormatterNoStyle;
	});
	NSString *language = TGAppLanguage();
	fmt.locale = language.length
			? [NSLocale localeWithLocaleIdentifier:language]
			: [NSLocale currentLocale];
	return [fmt stringFromDate:[NSDate dateWithTimeIntervalSince1970:[unix doubleValue]]];
}

#pragma mark - rows

- (NSString *)detailForTitle:(NSString *)title {
	if ([title isEqualToString:TGLocalized(@"Date")])
		return [self formattedDate];
	if ([title isEqualToString:TGLocalized(@"Model")])
		return [self.gift[@"modelName"] isKindOfClass:[NSString class]]
				? self.gift[@"modelName"] : @"";
	if ([title isEqualToString:TGLocalized(@"Symbol")])
		return [self.gift[@"symbolName"] isKindOfClass:[NSString class]]
				? self.gift[@"symbolName"] : @"";
	if ([title isEqualToString:TGLocalized(@"Backdrop")])
		return [self.gift[@"backdropName"] isKindOfClass:[NSString class]]
				? self.gift[@"backdropName"] : @"";
	if ([self.gift[@"isCollectible"] boolValue])
		return TGGiftValueText(self.gift);
	NSInteger stars = [self.gift[@"starCount"] integerValue];
	// The pack only has the "%@ Stars" form; a one-star gift used to fall
	// back to English through the missing singular.
	return TGLocalizedFormat(@"%@ Stars", @(stars));
}

- (void)rebuildSections {
	NSMutableArray *rows = [NSMutableArray array];
	for (NSString *title in TGGiftDetailRowTitles(self.gift))
		[rows addObject:TGTapRow(title, [self detailForTitle:title], nil)];

	NSString *note = [self giftNote];
	if (note.length){
		NSMutableDictionary *row = [TGTapRow(note, nil, nil) mutableCopy];
		row[TGRowTitleLines] = @0;
		[rows addObject:row];
	}

	self.sections = @[TGSection(nil, nil, rows)];
	[self reloadRows];
}

@end
