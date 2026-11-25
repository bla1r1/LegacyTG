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
#import "TGBarItem.h"
#import "TGLabel.h"

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
	self.pageKind = TGPageKindDetail;
	self.title = TGLocalized(@"Update");
	if (!self.info.isBlocking){
		self.navigationItem.leftBarButtonItem = [TGBarItem itemWithTitle:@"Skip" primary:NO
				target:self action:@selector(skipTapped:)];
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
	UILabel *versionLabel = TGLabelWith(TGLabelHeader, CGRectMake(titleX,
					TGMetricPadLarge + TGCenteredOrigin(TGMetricFileInfoIcon,
							TGMetricLineHeader),
					width - titleX - TGMetricGutter, TGMetricLineHeader), nil);
	versionLabel.text = version;
	[header addSubview:versionLabel];

	CGFloat bodyY = TGMetricPadLarge + TGMetricFileInfoIcon + TGMetricPad;
	UILabel *changelog = TGLabelWith(TGLabelBody, CGRectMake(TGMetricGutter, bodyY, bodyWidth, bodySize.height), nil);
	changelog.text = self.info.changelog;
	changelog.numberOfLines = 0;
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

static BOOL TGIsTrustedUpdateHost(NSString *host) {
	if (!host.length)
		return NO;
	NSString *lower = host.lowercaseString;
	NSArray *allowed = @[@"github.com", @"githubusercontent.com", @"t.me", @"legacytg.org"];
	for (NSString *domain in allowed) {
		if ([lower isEqualToString:domain] ||
			[lower hasSuffix:[@"." stringByAppendingString:domain]])
			return YES;
	}
	return NO;
}

- (void)openUpdate {
	NSString *url = nil;
	if ([TGUpdateStore isJailbroken] && self.info.cydiaURL.length)
		url = self.info.cydiaURL;
	else
		url = self.info.ipaURL;
	if (!url.length)
		return;
	NSURL *target = [NSURL URLWithString:url];
	NSString *scheme = target.scheme.lowercaseString;
	if (!target)
		return;
	if ([scheme isEqualToString:@"https"]) {
		if (!TGIsTrustedUpdateHost(target.host))
			return;
	} else if ([scheme isEqualToString:@"cydia"]) {
		if (!target.host.length && !target.path.length)
			return;
	} else {
		return;
	}
	[[UIApplication sharedApplication] openURL:target];
}

@end
