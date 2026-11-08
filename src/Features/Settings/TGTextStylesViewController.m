#import "TGTextStylesViewController.h"
#import "TGAlertSheet.h"
#import "TGClient.h"
#import "TGForwardPicker.h"
#import "TGListViewController.h"
#import "TGTheme.h"
#import "TGStyle.h"

@interface TGTextStylesViewController ()
@property (nonatomic, strong) NSArray *styles;
@end

@implementation TGTextStylesViewController

- (id)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Text Styles";
	self.styles = [TGClient shared].textCompositionStyles ?: @[];
	self.tableView.rowHeight = TGMetricRow;
	[self applyTheme];
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
			initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
								 target:self action:@selector(createTapped)];
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
			initWithTitle:@"Search" style:UIBarButtonItemStylePlain
				   target:self action:@selector(searchTapped)];

	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(stylesChanged:)
				name:TGTextCompositionStylesChangedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyTheme) name:TGThemeChangedNotification object:nil];
}

- (void)applyTheme {
	self.tableView.separatorColor = [[TGTheme shared] separatorColour];
	self.tableView.backgroundColor = [[TGTheme shared] groupedBackgroundColour];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	[self.tableView reloadData];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	self.styles = [TGClient shared].textCompositionStyles ?: @[];
	[self.tableView reloadData];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)stylesChanged:(NSNotification *)note {
	self.styles = [TGClient shared].textCompositionStyles ?: @[];
	[self.tableView reloadData];
}

#pragma mark - table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return self.styles.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"style"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:@"style"];
	[[TGTheme shared] styleCell:cell];
	NSDictionary *style = self.styles[indexPath.row];
	cell.textLabel.text = style[@"title"] ?: style[@"name"] ?: @"Style";
	cell.textLabel.font = TGFontBody();
	cell.textLabel.textColor = [[TGTheme shared] primaryTextColour];
	NSString *prompt = style[@"prompt"];
	cell.detailTextLabel.text = prompt.length ? prompt
			: ([style[@"isCreator"] boolValue] ? @"Created by you" : @"Telegram style");
	cell.detailTextLabel.font = TGFontSubhead();
	cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];
	cell.accessoryType = UITableViewCellAccessoryNone;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.row >= (NSInteger)self.styles.count)
		return;
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	[self showActionsForStyle:self.styles[indexPath.row]];
}

#pragma mark - one style

- (void)showActionsForStyle:(NSDictionary *)style {
	NSMutableArray *choices = [NSMutableArray arrayWithObjects:
			@"Preview", @"Edit", @"Add to Composer", nil];
	if ([style[@"isCreator"] boolValue])
		[choices addObject:@"Delete Style"];
	else
		[choices addObject:@"Remove from Composer"];
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:choices
						title:(style[@"title"] ?: style[@"name"])
			 destructiveIndex:(NSInteger)choices.count - 1
					   inView:self.view
					 onChoice:^(NSInteger index){
		NSString *choice = choices[index];
		if ([choice isEqualToString:@"Preview"]){
			[weakSelf previewStyle:style];
		} else if ([choice isEqualToString:@"Edit"]){
			[weakSelf editStyle:style];
		} else if ([choice isEqualToString:@"Add to Composer"]){
			[weakSelf addStyle:style];
		} else if ([choice isEqualToString:@"Delete Style"]){
			[weakSelf deleteStyle:style];
		} else if ([choice isEqualToString:@"Remove from Composer"]){
			[weakSelf removeStyle:style];
		}
	}];
}

- (void)addStyle:(NSDictionary *)style {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] addTextCompositionStyleNamed:style[@"name"]
										 completion:^(BOOL ok, NSString *error){
		[weakSelf report:ok error:error title:@"Add to Composer"];
	}];
}

- (void)removeStyle:(NSDictionary *)style {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] removeTextCompositionStyleNamed:style[@"name"]
											completion:^(BOOL ok, NSString *error){
		[weakSelf report:ok error:error title:@"Remove from Composer"];
	}];
}

- (void)deleteStyle:(NSDictionary *)style {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:nil
						title:(style[@"title"] ?: @"Delete Style")
					   action:@"Delete"
				  destructive:YES
					   inView:self.view
					onConfirm:^{
		[[TGClient shared] deleteTextCompositionStyleNamed:style[@"name"]
												completion:^(BOOL ok, NSString *error){
			[weakSelf report:ok error:error title:@"Delete Style"];
		}];
	}];
}

- (void)report:(BOOL)ok error:(NSString *)error title:(NSString *)title {
	[TGAlertSheet showMessage:(ok ? @"Done" : (error ?: @"An error occurred."))
						title:title inView:self.view];
}

#pragma mark - create and edit

- (void)createTapped {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"New Text Style"
					message:nil
				placeholder:@"Title" text:nil action:@"Next"
					 inView:self.view onSubmit:^(NSString *title){
		[TGAlertSheet showInput:@"New Text Style"
						message:nil
					placeholder:@"Prompt" text:nil action:@"Create"
						 inView:weakSelf.view onSubmit:^(NSString *prompt){
			[[TGClient shared] createTextCompositionStyle:title emojiId:0
												 prompt:prompt showCreator:YES
											  completion:^(NSDictionary *style,
														   NSString *error){
				[weakSelf report:(style != nil) error:error title:@"New Text Style"];
			}];
		}];
	}];
}

- (void)editStyle:(NSDictionary *)style {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Edit Text Style"
					message:nil
				placeholder:@"Title"
					   text:style[@"title"] ?: style[@"name"]
					 action:@"Next"
					 inView:self.view
				   onSubmit:^(NSString *title){
		[TGAlertSheet showInput:@"Edit Text Style"
						message:nil
					placeholder:@"Prompt"
						   text:style[@"prompt"]
						 action:@"Save"
						 inView:weakSelf.view
					   onSubmit:^(NSString *prompt){
			[[TGClient shared] editTextCompositionStyleNamed:style[@"name"]
													  title:title
													emojiId:[style[@"emojiId"] longLongValue]
													 prompt:prompt
												showCreator:[style[@"isCreator"] boolValue]
												 completion:^(NSDictionary *edited,
															  NSString *error){
				[weakSelf report:(edited != nil) error:error title:@"Edit Text Style"];
			}];
		}];
	}];
}

#pragma mark - examples

- (void)previewStyle:(NSDictionary *)style {
	__weak typeof(self) weakSelf = self;
	NSMutableArray *examples = [NSMutableArray array];
	[self loadExampleForStyle:style name:style[@"name"] number:0
					  into:examples completion:^{
		TGTextStylesViewController *me = weakSelf;
		if (!me)
			return;
		TGListViewController *list = [[TGListViewController alloc] init];
		list.listTitle = style[@"title"] ?: style[@"name"] ?: @"Examples";
		list.emptyText = @"Empty";
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *example in examples){
			NSString *source = example[@"sourceText"] ?: @"";
			NSString *result = example[@"resultText"] ?: @"";
			[rows addObject:@{@"title" : result,
							  @"detail" : source.length ? source : @"Example"}];
		}
		NSString *firstResult = examples.count ? examples[0][@"resultText"] : nil;
		if (firstResult.length){
			[rows addObject:@{@"title" : @"Send",
							  @"tap" : ^{
				TGForwardPicker *picker = [[TGForwardPicker alloc] init];
				picker.onPicked = ^(int64_t targetChatId){
					[[TGClient shared] sendText:firstResult toChat:targetChatId];
				};
				[me.navigationController pushViewController:picker animated:YES];
			}}];
		}
		list.rows = rows;
		list.listFooter = nil;
		[me.navigationController pushViewController:list animated:YES];
	}];
}

/// Telegram numbers examples from zero and answers 404 when the number is
/// past the end. Three is what the composer itself shows; stopping on the
/// first refusal keeps an account with one example from four failed calls.
- (void)loadExampleForStyle:(NSDictionary *)style
					   name:(NSString *)name
					 number:(NSInteger)number
					   into:(NSMutableArray *)examples
				 completion:(void (^)(void))completion {
	if (number >= 3 || !name.length){
		completion();
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] textCompositionStyleExampleNamed:name number:number
											completion:^(NSDictionary *example,
														 NSString *error){
		TGTextStylesViewController *me = weakSelf;
		if (!me)
			return;
		if (!example){
			completion();
			return;
		}
		[examples addObject:example];
		[me loadExampleForStyle:style name:name number:number + 1
						   into:examples completion:completion];
	}];
}

#pragma mark - find

- (void)searchTapped {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Search"
					message:nil
				placeholder:@"name" text:nil action:@"Search"
					 inView:self.view onSubmit:^(NSString *name){
		[[TGClient shared] searchTextCompositionStyleNamed:name
												completion:^(NSDictionary *style,
															 NSString *error){
			[weakSelf report:(style != nil) error:error title:@"Search"];
		}];
	}];
}

@end
