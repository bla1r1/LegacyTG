//
// TGAiComposeViewController.m
//
#import "TGAiComposeViewController.h"
#import "TGClient.h"
#import "TGAlertSheet.h"
#import "TGForwardPicker.h"

@interface TGAiComposeViewController ()
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSString *prompt;
@property (nonatomic, copy) NSString *style;
@property (nonatomic, copy) NSString *language;
@property (nonatomic, copy) NSString *tone;
@property (nonatomic, assign) BOOL addEmojis;
@property (nonatomic, copy) NSString *result;
@end

@implementation TGAiComposeViewController

- (void)viewDidLoad {
	self.title = @"Create with AI";
	[super viewDidLoad];
	NSString *code = [[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode];
	self.language = code.length ? code : @"en";
	self.tone = @"";
	self.text = @"";
	self.prompt = @"";
	self.style = @"";
	[self rebuild];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self rebuild];
}

- (NSString *)short:(NSString *)value {
	if (!value.length)
		return nil;
	return value.length > 48
			? [[value substringToIndex:48] stringByAppendingString:@"…"]
			: value;
}

- (void)rebuild {
	__weak typeof(self) weakSelf = self;
	NSMutableArray *inputRows = [NSMutableArray array];
	[inputRows addObject:TGFeatureRow(@"Text", [self short:self.text], ^{
		[weakSelf editText];
	})];
	[inputRows addObject:TGFeatureRow(@"Prompt", [self short:self.prompt], ^{
		[weakSelf editPrompt];
	})];
	[inputRows addObject:TGFeatureRow(@"Style", self.style.length ? self.style : @"None", ^{
		[weakSelf editStyle];
	})];
	[inputRows addObject:TGFeatureRow(@"Language", self.language, ^{
		[weakSelf editLanguage];
	})];
	[inputRows addObject:TGFeatureRow(@"Tone",
			self.tone.length ? self.tone : @"neutral", ^{
		[weakSelf editTone];
	})];
	[inputRows addObject:TGFeatureRow(@"Add Emoji", self.addEmojis ? @"On" : @"Off", ^{
		weakSelf.addEmojis = !weakSelf.addEmojis;
		[weakSelf rebuild];
	})];
	[inputRows addObject:TGFeatureOpenRow(@"Recipient", self.chatTitle.length
			? self.chatTitle : @"Select Chat", ^{
		[weakSelf chooseChat];
	})];

	NSMutableArray *actionRows = [NSMutableArray array];
	[actionRows addObject:TGFeatureAction(@"Create with AI", ^{ [weakSelf composeText]; })];
	[actionRows addObject:TGFeatureAction(@"AI Editor", ^{ [weakSelf fixText]; })];
	[actionRows addObject:TGFeatureAction(@"Compose", ^{
		[weakSelf composeRich];
	})];
	[actionRows addObject:TGFeatureAction(@"Fix", ^{
		[weakSelf fixRich];
	})];
	[actionRows addObject:TGFeatureAction(@"Generate", ^{
		[weakSelf createRich];
	})];
	[actionRows addObject:TGFeatureAction(@"Translate", ^{
		[weakSelf translateRich];
	})];

	NSMutableArray *sendRows = [NSMutableArray array];
	if (self.result.length){
		[sendRows addObject:TGFeatureOpenRow(@"Result", [self short:self.result], ^{
			[weakSelf showResult];
		})];
	}
	[sendRows addObject:TGFeatureAction(@"Send Message", ^{ [weakSelf sendResult]; })];
	[sendRows addObject:TGFeatureAction(@"Send as Rich Draft", ^{
		[weakSelf sendDraft];
	})];

	self.sections = @[
		TGFeatureSection(nil, nil, inputRows),
		TGFeatureSection(@"AI Tools", nil, actionRows),
		TGFeatureSection(@"Result", nil, sendRows),
	];
	[self reloadRows];
}

#pragma mark - fields

- (void)editText {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Text"
					message:nil
				placeholder:@"Text"
					   text:self.text
					 action:@"Save"
					 inView:self.view
				   onSubmit:^(NSString *text){
		weakSelf.text = text;
		[weakSelf rebuild];
	}];
}

- (void)editPrompt {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Prompt"
					message:nil
				placeholder:@"Prompt"
					   text:self.prompt
					 action:@"Save"
					 inView:self.view
				   onSubmit:^(NSString *prompt){
		weakSelf.prompt = prompt;
		[weakSelf rebuild];
	}];
}

- (void)editStyle {
	__weak typeof(self) weakSelf = self;
	NSArray *titles = @[@"None", @"Formal", @"Casual", @"Excited"];
	[TGAlertSheet showChoices:titles
						title:@"Style"
			 destructiveIndex:-1
					   inView:self.view
					 onChoice:^(NSInteger index){
		weakSelf.style = index == 0 ? @"" : [titles[index] lowercaseString];
		[weakSelf rebuild];
	}];
}

- (void)editLanguage {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Language"
					message:nil
				placeholder:@"en"
					   text:self.language
					 action:@"Save"
					 inView:self.view
				   onSubmit:^(NSString *code){
		weakSelf.language = code;
		[weakSelf rebuild];
	}];
}

- (void)editTone {
	__weak typeof(self) weakSelf = self;
	NSArray *titles = @[@"Neutral", @"Formal", @"Casual"];
	[TGAlertSheet showChoices:titles
						title:@"Tone"
			 destructiveIndex:-1
					   inView:self.view
					 onChoice:^(NSInteger index){
		weakSelf.tone = index == 0 ? @"" : [titles[index] lowercaseString];
		[weakSelf rebuild];
	}];
}

- (void)chooseChat {
	TGForwardPicker *picker = [[TGForwardPicker alloc] init];
	__weak typeof(self) weakSelf = self;
	picker.onPicked = ^(int64_t targetChatId){
		weakSelf.chatId = targetChatId;
		weakSelf.chatTitle = [[TGClient shared] titleForChat:targetChatId] ?: @"Chat";
		[weakSelf rebuild];
	};
	[self.navigationController pushViewController:picker animated:YES];
}

#pragma mark - requests

- (void)composeText {
	if (!self.text.length){
		[self toast:@"An error occurred."];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] composeTextWithAi:self.text
							 translateTo:self.language
								   style:self.style
							   addEmojis:self.addEmojis
							  completion:^(NSString *text, NSString *error){
		if (!text){
			[weakSelf toast:error ?: @"An error occurred."];
			return;
		}
		weakSelf.result = text;
		[weakSelf showResult];
	}];
}

- (void)fixText {
	if (!self.text.length){
		[self toast:@"An error occurred."];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] fixTextWithAi:self.text
						  completion:^(NSString *text, NSString *diff, NSString *error){
		if (!text){
			[weakSelf toast:error ?: @"An error occurred."];
			return;
		}
		weakSelf.result = text;
		[weakSelf showResult];
	}];
}

- (void)composeRich {
	if (!self.text.length){
		[self toast:@"An error occurred."];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] composeRichMessageWithAi:self.text
									translateTo:self.language
										  style:self.style
								   customPrompt:@""
									  addEmojis:self.addEmojis
									 completion:^(NSString *text, NSString *error){
		if (!text.length){
			[weakSelf toast:error ?: @"An error occurred."];
			return;
		}
		weakSelf.result = text;
		[weakSelf showResult];
	}];
}

- (void)fixRich {
	if (!self.text.length){
		[self toast:@"An error occurred."];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] fixRichMessageWithAi:self.text
								  completion:^(NSString *text, NSString *error){
		if (!text.length){
			[weakSelf toast:error ?: @"An error occurred."];
			return;
		}
		weakSelf.result = text;
		[weakSelf showResult];
	}];
}

- (void)createRich {
	if (!self.prompt.length){
		[self toast:@"An error occurred."];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] createRichMessageWithAi:self.prompt
								  languageCode:self.language
									 addEmojis:self.addEmojis
									completion:^(NSString *text, NSString *error){
		if (!text.length){
			[weakSelf toast:error ?: @"An error occurred."];
			return;
		}
		weakSelf.result = text;
		[weakSelf showResult];
	}];
}

- (void)translateRich {
	if (!self.text.length){
		[self toast:@"An error occurred."];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] translateRichMessage:self.text
									 toCode:self.language
									   tone:self.tone
								 completion:^(NSString *text, NSString *error){
		if (!text.length){
			[weakSelf toast:error ?: @"An error occurred."];
			return;
		}
		weakSelf.result = text;
		[weakSelf showResult];
	}];
}

- (void)showResult {
	__weak typeof(self) weakSelf = self;
	TGFeatureResultViewController *screen = [[TGFeatureResultViewController alloc]
			initWithTitle:@"Result" body:self.result];
	screen.onSend = self.chatId ? ^(NSString *text){
		[weakSelf sendText:text];
	} : nil;
	screen.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:screen animated:YES];
	[self rebuild];
}

- (void)sendResult {
	if (!self.result.length){
		[self toast:@"An error occurred."];
		return;
	}
	[self sendText:self.result];
}

- (void)sendText:(NSString *)text {
	if (!self.chatId){
		[self chooseChat];
		return;
	}
	[[TGClient shared] sendText:text toChat:self.chatId];
	[self toast:@"Sent"];
}

- (void)sendDraft {
	if (!self.chatId){
		[self chooseChat];
		return;
	}
	NSString *body = self.result.length ? self.result : self.text;
	if (!body.length){
		[self toast:@"An error occurred."];
		return;
	}
	__weak typeof(self) weakSelf = self;
	int64_t draftId = (int64_t)arc4random();
	[[TGClient shared] sendRichMessageDraft:body
									 toChat:self.chatId
									topicId:0
									draftId:draftId
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

@end
