//
// TGMessageToolsViewController.m
//
#import "TGMessageToolsViewController.h"
#import "TGClient.h"
#import "TGAlertSheet.h"

@implementation TGMessageToolsViewController

- (void)viewDidLoad {
	self.title = @"Message Tools";
	[super viewDidLoad];
	[self rebuild];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self rebuild];
}

- (void)rebuild {
	__weak typeof(self) weakSelf = self;
	// Everything official puts in a message or the composer has moved there:
	// Translate, facts, checklists and suggested posts are hold-menu rows, the
	// AI composer is the composer's three-line button. This screen is only
	// reached from the dev hub and keeps the calls that have no release entry.
	NSMutableArray *aiRows = [NSMutableArray array];
	[aiRows addObject:TGFeatureAction(@"AI Summary", ^{ [weakSelf summarize]; })];
	[aiRows addObject:TGFeatureAction(@"Get Full Rich Message", ^{
		[weakSelf fullRichMessage];
	})];

	NSMutableArray *richRows = [NSMutableArray array];
	[richRows addObject:TGFeatureAction(@"Send as Rich Draft", ^{ [weakSelf sendDraft]; })];

	self.sections = @[
		TGFeatureSection(@"AI Tools", nil, aiRows),
		TGFeatureSection(@"Rich Messages", nil, richRows),
	];
	[self reloadRows];
}

#pragma mark - requests

- (void)summarize {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] summarizeMessage:self.messageId
								 inChat:self.chatId
							translateTo:@""
								   tone:@""
							 completion:^(NSString *text, NSString *error){
		if (!text.length){
			[weakSelf toast:error ?: @"An error occurred."];
			return;
		}
		[weakSelf show:text title:@"AI Summary"];
	}];
}

- (void)fixText {
	if (!self.messageText.length){
		[self toast:@"An error occurred."];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] fixTextWithAi:self.messageText
						  completion:^(NSString *text, NSString *diff, NSString *error){
		if (!text.length){
			[weakSelf toast:error ?: @"An error occurred."];
			return;
		}
		[weakSelf show:text title:@"Fix"];
	}];
}

- (void)translateRichMessage {
	__weak typeof(self) weakSelf = self;
	NSString *code = [[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode];
	[[TGClient shared] translateMessageRichMessage:self.messageId
											inChat:self.chatId
											toCode:code.length ? code : @"en"
											  tone:@""
										completion:^(NSString *text, NSString *error){
		if (!text.length){
			[weakSelf toast:error ?: @"An error occurred."];
			return;
		}
		[weakSelf show:text title:@"Translation"];
	}];
}

- (void)fullRichMessage {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] getFullRichMessage:self.messageId
								   inChat:self.chatId
							   completion:^(NSString *text, NSDictionary *message,
											NSString *error){
		if (!text.length){
			[weakSelf toast:error ?: @"An error occurred."];
			return;
		}
		[weakSelf show:text title:@"Full Rich Message"];
	}];
}

- (void)sendDraft {
	if (!self.messageText.length){
		[self toast:@"An error occurred."];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] sendRichMessageDraft:self.messageText
									 toChat:self.chatId
									topicId:0
									draftId:(int64_t)arc4random()
									canStop:NO
								 keepOnStop:YES
								 completion:^(BOOL ok, NSString *error){
		if (!ok){
			[weakSelf toast:error ?: @"An error occurred."];
			return;
		}
		[weakSelf toast:@"Draft Saved"];
	}];
}

- (void)editFactCheck {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Fact Check"
					message:nil
				placeholder:@"Fact check"
					   text:self.factCheck
					 action:@"Save"
					 inView:self.view
				   onSubmit:^(NSString *text){
		[[TGClient shared] setMessageFactCheck:weakSelf.messageId
										inChat:weakSelf.chatId
										  text:text
									completion:^(BOOL ok, NSString *error){
			if (!ok){
				[weakSelf toast:error ?: @"An error occurred."];
				return;
			}
			weakSelf.factCheck = text;
			[weakSelf rebuild];
		}];
	}];
}

- (void)clearFactCheck {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setMessageFactCheck:self.messageId
									inChat:self.chatId
									  text:nil
								completion:^(BOOL ok, NSString *error){
		if (!ok){
			[weakSelf toast:error ?: @"An error occurred."];
			return;
		}
		weakSelf.factCheck = @"";
		[weakSelf rebuild];
	}];
}

- (void)show:(NSString *)text title:(NSString *)title {
	TGFeatureResultViewController *screen = [[TGFeatureResultViewController alloc]
			initWithTitle:title body:text];
	screen.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:screen animated:YES];
}

@end
