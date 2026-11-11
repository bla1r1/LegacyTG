//
// TGNotificationCategoryViewController.m
//
// The official per-category notifications page (NotificationsPeerCategory-
// Controller.swift): one switch for the scope, the display options that TDLib
// keeps on the scope record, and the exceptions list. Add/delete exception
// actions have no client call in this build; the list still shows what the
// account overrides today.
//
#import "TGNotificationCategoryViewController.h"
#import "TGLocalization.h"
#import "TGRows.h"
#import "TGSettingsFormatting.h"
#import "TGSettingsStore.h"


@interface TGNotificationCategoryViewController ()
@property (nonatomic, copy) NSString *scope;
@property (nonatomic, copy) NSString *categoryTitle;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) BOOL preview;
@property (nonatomic, strong) NSArray *exceptions;
@end

@implementation TGNotificationCategoryViewController

- (instancetype)initWithScope:(NSString *)scope title:(NSString *)title {
	self = [super init];
	if (self){
		_scope = [scope copy];
		_categoryTitle = [title copy];
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = self.categoryTitle;
	[self rebuildSections];
	[self load];
	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(notificationSettingsChanged)
				name:TGNotificationSettingsChangedNotification object:nil];
}

- (void)dealloc {
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self applyTheme];
}

- (void)notificationSettingsChanged {
	[NSObject cancelPreviousPerformRequestsWithTarget:self
			selector:@selector(load) object:nil];
	[self performSelector:@selector(load) withObject:nil afterDelay:0.3];
}

- (void)load {
	__weak typeof(self) weakSelf = self;
	[[TGSettingsStore shared] notificationsMutedForScope:self.scope
									   completion:^(BOOL muted){
		TGNotificationCategoryViewController *me = weakSelf;
		if (!me)
			return;
		me.enabled = !muted;
		[me rebuildSections];
	}];
	[[TGSettingsStore shared] notificationPreviewForScope:self.scope
										completion:^(BOOL show){
		TGNotificationCategoryViewController *me = weakSelf;
		if (!me)
			return;
		me.preview = show;
		[me rebuildSections];
	}];
	[[TGSettingsStore shared] notificationExceptionsWithCompletion:^(NSArray *chats){
		TGNotificationCategoryViewController *me = weakSelf;
		if (!me)
			return;
		// The client asks once for every scope; this page keeps the chats
		// that belong to its own category.
		me.exceptions = TGNotificationExceptionsForScope(chats, me.scope);
		[me rebuildSections];
	}];
}

#pragma mark - sections

- (void)rebuildSections {
	__weak typeof(self) weakSelf = self;
	NSMutableArray *sections = [NSMutableArray array];
	[sections addObject:TGSection(nil, nil, @[
		TGSwitchRow(TGLocalized(@"Notifications"), self.enabled, ^(BOOL on){
			weakSelf.enabled = on;
			[[TGSettingsStore shared] setScope:weakSelf.scope muted:!on];
			[weakSelf rebuildSections];
		}),
	])];

	if (self.enabled || self.exceptions.count){
		[sections addObject:TGSection(TGLocalized(@"Options"), nil, @[
			TGSwitchRow(TGLocalized(@"Message Preview"), self.preview, ^(BOOL on){
				weakSelf.preview = on;
				[[TGSettingsStore shared] setScope:weakSelf.scope showPreview:on];
				[weakSelf rebuildSections];
			}),
			// The scope record's sound id is not exposed by the client's
			// scope setters, so this row names Telegram's default and keeps
			// the position official gives it.
			TGTapRow(TGLocalized(@"Sound"), TGLocalized(@"Default"), nil),
		])];
	}

	NSMutableArray *exceptionRows = [NSMutableArray array];
	for (NSDictionary *chat in self.exceptions){
		[exceptionRows addObject:TGSubtitleRow(chat[@"title"] ?: TGLocalized(@"Chat"),
				TGNotificationExceptionDetail(chat), nil)];
	}
	[sections addObject:TGSection(TGLocalized(@"EXCEPTIONS"), nil, exceptionRows)];
	self.sections = sections;
	[self reloadRows];
}

@end
