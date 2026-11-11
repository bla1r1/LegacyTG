#import "TGTextStylesViewController.h"
#import "TGAlertSheet.h"
#import "TGForwardPicker.h"
#import "TGListViewController.h"
#import "TGRows.h"
#import "TGSendStore.h"
#import "TGTextStylesStore.h"


@interface TGTextStylesViewController ()
@property (nonatomic, strong) NSArray *styles;
@end

@implementation TGTextStylesViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Text Styles";
	self.styles = [TGTextStylesStore shared].textCompositionStyles ?: @[];
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
			initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
								 target:self action:@selector(createTapped)];
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
			initWithTitle:@"Search" style:UIBarButtonItemStylePlain
				   target:self action:@selector(searchTapped)];

	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(stylesChanged:)
				name:TGTextCompositionStylesChangedNotification object:nil];
	[self rebuildSections];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	self.styles = [TGTextStylesStore shared].textCompositionStyles ?: @[];
	[self rebuildSections];
}

- (void)stylesChanged:(NSNotification *)note {
	self.styles = [TGTextStylesStore shared].textCompositionStyles ?: @[];
	[self rebuildSections];
}

#pragma mark - rows

- (void)rebuildSections {
	__weak typeof(self) weakSelf = self;
	NSMutableArray *rows = [NSMutableArray array];
	for (NSDictionary *style in self.styles){
		[rows addObject:TGSubtitleRow(TGTextStyleRowTitle(style),
				TGTextStyleRowDetail(style),
				^{ [weakSelf showActionsForStyle:style]; })];
	}
	self.sections = @[TGSection(nil, nil, rows)];
	[self reloadRows];
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
	[[TGTextStylesStore shared] addTextCompositionStyleNamed:style[@"name"]
										 completion:^(BOOL ok, NSString *error){
		[weakSelf report:ok error:error title:@"Add to Composer"];
	}];
}

- (void)removeStyle:(NSDictionary *)style {
	__weak typeof(self) weakSelf = self;
	[[TGTextStylesStore shared] removeTextCompositionStyleNamed:style[@"name"]
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
		[[TGTextStylesStore shared] deleteTextCompositionStyleNamed:style[@"name"]
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
			[[TGTextStylesStore shared] createTextCompositionStyle:title emojiId:0
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
			[[TGTextStylesStore shared] editTextCompositionStyleNamed:style[@"name"]
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
					[[TGSendStore shared] sendText:firstResult
										   toChat:targetChatId
										   thread:0
										  replyTo:0
								  schedulingState:nil
										   silent:NO];
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
	[[TGTextStylesStore shared] textCompositionStyleExampleNamed:name number:number
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
		[[TGTextStylesStore shared] searchTextCompositionStyleNamed:name
												completion:^(NSDictionary *style,
															 NSString *error){
			[weakSelf report:(style != nil) error:error title:@"Search"];
		}];
	}];
}

@end
