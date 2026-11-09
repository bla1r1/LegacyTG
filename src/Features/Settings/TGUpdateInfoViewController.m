//
// TGUpdateInfoViewController.m - the official UpdateInfoController shape:
// app icon, version, the changelog, one Update row and Skip in the bar.
//
#import "TGUpdateInfoViewController.h"
#import "TGUpdateStore.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGLocalization.h"
#import "TGRows.h"

static UIImage *TGUpdateAppIcon(void) {
	for (NSString *name in @[@"Icon-60@2x.png", @"Icon@2x.png", @"Icon.png"]){
		UIImage *image = [UIImage imageNamed:name];
		if (image)
			return image;
	}
	return nil;
}

@interface TGUpdateInfoViewController ()

@property (nonatomic, strong) TGUpdateInfo *info;

@end

@implementation TGUpdateInfoViewController

- (instancetype)initWithUpdateInfo:(TGUpdateInfo *)info {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (!self)
		return nil;
	_info = info;
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGLocalized(@"Update");
	if (!self.info.isBlocking){
		self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
				initWithTitle:TGLocalized(@"Skip")
						style:UIBarButtonItemStylePlain
					   target:self
					   action:@selector(skipTapped:)];
	}
	[self buildHeader];
	self.sections = @[TGSection(nil, nil, @[
		TGActionRow(TGLocalized(@"Update"), ^{ [self openUpdate]; }),
	])];
	[self reloadRows];
}

/// The icon and changelog are a table header, not a row: they are one block
/// above the table's own section and the shared cell does not draw artwork.
- (void)buildHeader {
	CGFloat width = CGRectGetWidth(self.tableView.bounds) ?: TGMetricScreenWidth;
	CGFloat bodyWidth = width - TGMetricGutter - TGMetricGutter;
	CGSize bodySize = [self.info.changelog sizeWithFont:TGFontBody()
			constrainedToSize:CGSizeMake(bodyWidth, CGFLOAT_MAX)
			lineBreakMode:NSLineBreakByWordWrapping];
	CGFloat height = TGMetricPadLarge + TGMetricFileInfoIcon;
	if (self.info.changelog.length)
		height += TGMetricPad + bodySize.height;
	height += TGMetricPadLarge;

	TGTheme *theme = [TGTheme shared];
	UIView *header = [[UIView alloc] initWithFrame:
			CGRectMake(0, 0, width, height)];
	header.backgroundColor = [theme cardBackgroundColour];

	UIImageView *icon = [[UIImageView alloc] initWithFrame:
			CGRectMake(TGMetricGutter, TGMetricPadLarge,
					TGMetricFileInfoIcon, TGMetricFileInfoIcon)];
	icon.image = TGUpdateAppIcon();
	icon.contentMode = UIViewContentModeScaleAspectFit;
	[header addSubview:icon];

	NSString *version = self.info.version.length
			? [NSString stringWithFormat:@"LegacyTG %@", self.info.version]
			: @"LegacyTG";
	CGFloat titleX = TGMetricGutter + TGMetricFileInfoIcon + TGMetricPad;
	UILabel *versionLabel = [[UILabel alloc] initWithFrame:
			CGRectMake(titleX,
					TGMetricPadLarge + TGCenteredOrigin(TGMetricFileInfoIcon,
							TGMetricLineHeader),
					width - titleX - TGMetricGutter, TGMetricLineHeader)];
	versionLabel.text = version;
	versionLabel.font = TGFontHeader();
	versionLabel.textColor = [theme primaryTextColour];
	versionLabel.backgroundColor = [UIColor clearColor];
	[header addSubview:versionLabel];

	CGFloat bodyY = TGMetricPadLarge + TGMetricFileInfoIcon + TGMetricPad;
	UILabel *changelog = [[UILabel alloc] initWithFrame:
			CGRectMake(TGMetricGutter, bodyY, bodyWidth, bodySize.height)];
	changelog.text = self.info.changelog;
	changelog.font = TGFontBody();
	changelog.numberOfLines = 0;
	changelog.textColor = [theme primaryTextColour];
	changelog.backgroundColor = [UIColor clearColor];
	[header addSubview:changelog];

	self.tableView.tableHeaderView = header;
}

- (void)skipTapped:(id)sender {
	[TGUpdateStore skipBuild:self.info.build];
	[self dismissScreen];
}

- (void)dismissScreen {
	UIViewController *presented = self.navigationController ?: self;
	[presented dismissViewControllerAnimated:YES completion:nil];
}

- (void)openUpdate {
	NSString *url = nil;
	if ([TGUpdateStore isJailbroken] && self.info.cydiaURL.length)
		url = self.info.cydiaURL;
	else
		url = self.info.ipaURL;
	if (!url.length)
		return;
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
}

@end
