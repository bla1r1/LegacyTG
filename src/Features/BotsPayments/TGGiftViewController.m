//
// TGGiftViewController.m - detail screen for a received gift.
//
#import "TGGiftViewController.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGLottieView.h"
#import "TGIcons.h"
#import "TGCapabilities.h"
#import "TGMessageLayout.h"

static const CGFloat kArtSide = TGMetricProfilePhotoSide;
static const CGFloat kHeaderPadTop = TGMetricPadLarge;
static const CGFloat kHeaderPadMid = TGMetricPadMedium;
static const CGFloat kHeaderPadBottom = TGMetricPadLarge;
static const CGFloat kTitleHeight = TGMetricLineTitle;
static const CGFloat kHeaderHeight = TGMetricPadLarge + TGMetricProfilePhotoSide + TGMetricPadMedium + TGMetricLineTitle + TGMetricPadLarge;
static const CGFloat kNoteMargin = TGMetricPadLarge + TGMetricPadMedium;
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
	self.title = @"Gift";

	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	[self applyTheme];
	[self setupTableHeader];

	__weak typeof(self) weakSelf = self;
	[[NSNotificationCenter defaultCenter] addObserverForName:TGThemeChangedNotification
													  object:nil
													   queue:[NSOperationQueue mainQueue]
												  usingBlock:^(NSNotification *note) {
		[weakSelf applyTheme];
		[weakSelf.tableView reloadData];
	}];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self applyTheme];
	if (self.lottieView.loaded && [TGCapabilities canPlayAnimatedStickers] && [TGCapabilities animatedStickersWanted]) {
		[self.lottieView play];
	}
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[self.lottieView stop];
}

- (void)applyTheme {
	[[TGTheme shared] styleGroupedTable:self.tableView];
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
			return (stars == 1) ? @"1 Star" : [NSString stringWithFormat:@"%ld Stars", (long)stars];
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
		[[TGClient shared] downloadFile:stillId.integerValue
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
		[[TGClient shared] downloadFile:stickerId.integerValue
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

	self.tableView.tableHeaderView = header;
}

- (void)requestSenderUserIfNeeded:(int64_t)userId {
	if (self.requestedUserId == userId || userId == 0)
		return;
	self.requestedUserId = userId;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] ensureUserName:userId completion:^{
		dispatch_async(dispatch_get_main_queue(), ^{
			TGGiftViewController *me = weakSelf;
			if (!me) return;
			if ([me.tableView numberOfSections] > 0 && [me.tableView numberOfRowsInSection:0] > 0) {
				[me.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0]]
									withRowAnimation:UITableViewRowAnimationNone];
			}
		});
	}];
}

- (NSString *)senderDisplayName {
	if ([self.gift[@"isPrivate"] boolValue]) {
		return @"Hidden";
	}

	int64_t userId = [self.gift[@"senderUserId"] longLongValue];
	if (userId > 0) {
		NSString *userName = [[TGClient shared] nameForUserId:userId];
		if (userName.length > 0) {
			return userName;
		}
		[self requestSenderUserIfNeeded:userId];
		return @"";
	}

	int64_t chatId = [self.gift[@"senderChatId"] longLongValue];
	if (chatId != 0) {
		NSString *chatTitle = [[TGClient shared] titleForChat:chatId];
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
		fmt.dateFormat = @"dd.MM.yy, HH:mm";
	});
	return [fmt stringFromDate:[NSDate dateWithTimeIntervalSince1970:[unix doubleValue]]];
}

#pragma mark - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return ([self giftNote].length > 0) ? 2 : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0) {
		return [self.gift[@"isCollectible"] boolValue] ? 5 : 3;
	}
	return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == 1) {
		return @"Note";
	}
	return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 1) {
		NSString *note = [self giftNote];
		CGFloat textW = tableView.bounds.size.width - TGDoubled(kNoteMargin);
		if (textW <= 0)
			textW = TGMetricScreenWidth - TGDoubled(kNoteMargin);
		CGSize size = TGTextSize(note, TGFontBody(), textW);
		return MAX(TGMetricRow, ceilf(size.height) + TGDoubled(TGMetricPadMedium));
	}
	return TGMetricRow;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 1) {
		static NSString *const kNoteCellId = @"TGGiftNoteCell";
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kNoteCellId];
		if (!cell) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kNoteCellId];
		}
		[[TGTheme shared] styleCell:cell];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		cell.textLabel.text = [self giftNote];
		cell.textLabel.font = TGFontBody();
		cell.textLabel.textColor = [[TGTheme shared] primaryTextColour];
		cell.textLabel.numberOfLines = 0;
		cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
		cell.detailTextLabel.text = nil;
		return cell;
	}

	static NSString *const kDetailCellId = @"TGGiftDetailCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kDetailCellId];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kDetailCellId];
	}
	[[TGTheme shared] styleCell:cell];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;

	BOOL isCollectible = [self.gift[@"isCollectible"] boolValue];
	NSString *title = @"";
	NSString *detail = @"";

	if (indexPath.row == 0) {
		title = @"From";
		detail = [self senderDisplayName];
	} else if (indexPath.row == 1) {
		title = @"Date";
		detail = [self formattedDate];
	} else if (isCollectible) {
		if (indexPath.row == 2) {
			title = @"Model";
			detail = [self.gift[@"modelName"] isKindOfClass:[NSString class]] ? self.gift[@"modelName"] : @"";
		} else if (indexPath.row == 3) {
			title = @"Symbol";
			detail = [self.gift[@"symbolName"] isKindOfClass:[NSString class]] ? self.gift[@"symbolName"] : @"";
		} else if (indexPath.row == 4) {
			title = @"Backdrop";
			detail = [self.gift[@"backdropName"] isKindOfClass:[NSString class]] ? self.gift[@"backdropName"] : @"";
		}
	} else {
		title = @"Value";
		NSInteger stars = [self.gift[@"starCount"] integerValue];
		detail = (stars == 1) ? @"1 Star" : [NSString stringWithFormat:@"%ld Stars", (long)stars];
	}

	cell.textLabel.text = title;
	cell.detailTextLabel.text = detail;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:NO];
}

@end
