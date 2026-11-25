//
// TGProxySetupViewController.m - pre-login and settings proxy & auto-fallback UI.
//
#import "TGProxySetupViewController.h"
#import "TGAlertSheet.h"
#import "TGLocalization.h"
#import "TGPresent.h"
#import "TGRows.h"
#import "TGSettingsStore.h"

@interface TGProxySetupViewController ()
@property (nonatomic, strong) NSArray *proxies;
@property (nonatomic, copy) NSString *statusText;
@end

@implementation TGProxySetupViewController

- (instancetype)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGLocalized(@"Proxy");
	self.statusText = [[TGSettingsStore shared] autoProxyStatusText];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(statusDidChange:)
												 name:TGAutoProxyStatusChangedNotification
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(statusDidChange:)
												 name:TGConnectionStateChangedNotification
											   object:nil];
	[self loadProxies];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)statusDidChange:(NSNotification *)note {
	self.statusText = [[TGSettingsStore shared] autoProxyStatusText];
	[self rebuildSections];
}

- (void)loadProxies {
	__weak typeof(self) weakSelf = self;
	[[TGSettingsStore shared] proxiesWithCompletion:^(NSArray *proxies) {
		TGProxySetupViewController *me = weakSelf;
		if (!me)
			return;
		me.proxies = proxies ?: @[];
		[me rebuildSections];
	}];
}

- (void)rebuildSections {
	__weak typeof(self) weakSelf = self;
	TGSettingsStore *store = [TGSettingsStore shared];
	BOOL autoOn = [store autoProxyEnabled];
	BOOL probing = [store autoProxyIsProbing];
	NSString *bootstrap = [store autoProxyBootstrapURL];
	NSString *bootstrapDetail = bootstrap.length ? ([NSURL URLWithString:bootstrap].host ?: bootstrap) : TGLocalized(@"Not set");

	NSMutableArray *autoRows = [NSMutableArray array];
	[autoRows addObject:TGSwitchRow(TGLocalized(@"Auto-Proxy (Anti-DPI)"), autoOn, ^(BOOL on) {
		[store setAutoProxyEnabled:on];
		[weakSelf rebuildSections];
	})];
	[autoRows addObject:TGTapRow(probing ? TGLocalized(@"Checking proxies...") : TGLocalized(@"Check & Connect Now"), nil, ^{
		if ([store autoProxyIsProbing])
			return;
		[store triggerAutoProxyFallbackNow];
		[weakSelf rebuildSections];
	})];
	[autoRows addObject:TGTapRow(TGLocalized(@"Bootstrap URL"), bootstrapDetail, ^{
		[weakSelf askBootstrapURL];
	})];

	NSString *autoFooter = self.statusText.length ? self.statusText : TGLocalized(@"Direct connection");

	BOOL anyEnabled = NO;
	for (NSDictionary *p in self.proxies) {
		if ([p[@"enabled"] boolValue]) {
			anyEnabled = YES;
			break;
		}
	}

	NSMutableArray *proxyRows = [NSMutableArray array];
	if (anyEnabled) {
		[proxyRows addObject:TGTapRow(TGLocalized(@"Use Direct Connection"), nil, ^{
			[store disableProxy];
			[weakSelf loadProxies];
		})];
	}
	[proxyRows addObject:TGTapRow(TGLocalized(@"Add Proxy"), nil, ^{
		[weakSelf askAddProxy];
	})];

	for (NSDictionary *proxy in self.proxies) {
		NSString *server = proxy[@"server"] ?: @"?";
		NSInteger port = [proxy[@"port"] integerValue];
		NSString *kind = [proxy[@"kind"] uppercaseString] ?: @"SOCKS5";
		BOOL enabled = [proxy[@"enabled"] boolValue];
		NSString *title = [NSString stringWithFormat:@"%@:%ld", server, (long)port];
		NSString *detail = enabled ? [NSString stringWithFormat:@"%@ • %@", kind, TGLocalized(@"Active")] : kind;
		[proxyRows addObject:TGTapRow(title, detail, ^{
			[weakSelf showActionsForProxy:proxy named:title];
		})];
	}

	self.sections = @[
		TGSection(TGLocalized(@"Automatic Fallback"), autoFooter, autoRows),
		TGSection(TGLocalized(@"Proxies"), nil, proxyRows),
	];
	[self reloadRows];
}

- (void)askBootstrapURL {
	__weak typeof(self) weakSelf = self;
	TGSettingsStore *store = [TGSettingsStore shared];
	[TGAlertSheet showInput:TGLocalized(@"Bootstrap URL")
					message:TGLocalized(@"HTTPS URL returning tg://proxy links or JSON.")
				placeholder:@"https://example.com/proxies.txt"
					   text:[store autoProxyBootstrapURL]
					 action:TGLocalized(@"Save")
					 inView:self.view
				   onSubmit:^(NSString *text) {
		[store setAutoProxyBootstrapURL:text];
		[weakSelf rebuildSections];
	}];
}

- (void)askAddProxy {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:TGLocalized(@"Add Proxy")
					message:nil
				placeholder:@"t.me/proxy?... or 1.2.3.4:1080"
					   text:nil
					 action:TGLocalized(@"Add")
					 inView:self.view
				   onSubmit:^(NSString *text) {
		TGProxySetupViewController *me = weakSelf;
		if (!me)
			return;
		void (^added)(NSInteger) = ^(NSInteger proxyId) {
			if (!proxyId) {
				[TGAlertSheet showMessage:TGLocalized(@"Could not add proxy.")
									  title:TGLocalized(@"Proxy")
									 inView:me.view];
				return;
			}
			[me loadProxies];
		};

		if ([text rangeOfString:@"proxy"].location != NSNotFound &&
			[text rangeOfString:@"?"].location != NSNotFound) {
			if (![[TGSettingsStore shared] addProxyFromLink:text completion:added]) {
				[TGAlertSheet showMessage:TGLocalized(@"Invalid proxy link.")
									  title:TGLocalized(@"Proxy")
									 inView:me.view];
			}
			return;
		}

		NSArray *parts = [text componentsSeparatedByString:@":"];
		NSInteger port = parts.count > 1 ? [parts[1] integerValue] : 0;
		if (parts.count < 2 || port <= 0 || port > 65535) {
			[TGAlertSheet showMessage:TGLocalized(@"Enter t.me/proxy?... or host:port.")
								  title:TGLocalized(@"Proxy")
								 inView:me.view];
			return;
		}
		[[TGSettingsStore shared] addProxyAtServer:parts[0]
											  port:port
											  kind:@"socks5"
										  username:nil
										  password:nil
											secret:nil
											enable:YES
										completion:added];
	}];
}

- (void)showActionsForProxy:(NSDictionary *)proxy named:(NSString *)name {
	NSInteger proxyId = [proxy[@"id"] integerValue];
	__weak typeof(self) weakSelf = self;
	[TGPresent showMenuTitles:@[TGLocalized(@"Use Proxy"), TGLocalized(@"Check"), TGLocalized(@"Remove")]
			 destructiveIndex:2
					 fromView:nil
				 onController:self
					 onChoice:^(NSInteger index) {
		TGProxySetupViewController *me = weakSelf;
		if (!me)
			return;
		if (index == 0) {
			[[TGSettingsStore shared] enableProxy:proxyId];
			[me loadProxies];
		} else if (index == 1) {
			[[TGSettingsStore shared] testProxyAtServer:proxy[@"server"]
												   port:[proxy[@"port"] integerValue]
												   kind:proxy[@"kind"]
											   username:nil
											   password:nil
												 secret:nil
											 completion:^(BOOL works) {
				[TGAlertSheet showMessage:works
						? [NSString stringWithFormat:@"%@ %@", name, TGLocalized(@"works.")]
						: [NSString stringWithFormat:@"%@ %@", name, TGLocalized(@"did not respond.")]
									  title:TGLocalized(@"Proxy")
									 inView:me.view];
			}];
		} else {
			[[TGSettingsStore shared] removeProxy:proxyId];
			[me loadProxies];
		}
	}];
}

@end
