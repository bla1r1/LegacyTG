//
// TGPollComposeViewController.m
//
// Rows follow official ComposePollScreen: QUESTION (question, description),
// OPTIONS with the count footer, then SETTINGS. Quiz Mode keeps the switch
// in Settings; the right answer is a row of checks under the options rather
// than official's circle inside each option field, which our field row has
// no room for, and the explanation is its own card at the end.
//
#import <UIKit/UIKit.h>
#import "TGPollComposeViewController.h"
#import "TGSendStore.h"
#import "TGAlertSheet.h"
#import "TGBarItem.h"
#import "TGLocalization.h"
#import "TGPresent.h"
#import "TGRows.h"
#import "TGStylePalette.h"

// ponytail: Telegram's poll_answer_count_max today; TDLib's option is not
// cached anywhere yet. A lower server limit answers the send with an error.
static const NSUInteger kPollMaxOptions = 12;
static const NSUInteger kPollOptionLength = 100;

@interface TGPollComposeViewController ()
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, assign) BOOL isChannel;
@property (nonatomic, copy) NSString *question;
@property (nonatomic, copy) NSString *pollDescription;
@property (nonatomic, copy) NSString *explanation;
@property (nonatomic, strong) NSMutableArray *options;
@property (nonatomic, strong) NSMutableIndexSet *correct;
@property (nonatomic, assign) BOOL anonymous;
@property (nonatomic, assign) BOOL multiple;
@property (nonatomic, assign) BOOL addingOptions;
@property (nonatomic, assign) BOOL revoting;
@property (nonatomic, assign) BOOL shuffle;
@property (nonatomic, assign) BOOL quiz;
@property (nonatomic, assign) BOOL sending;
@end

@implementation TGPollComposeViewController

- (instancetype)initWithChatId:(int64_t)chatId isChannel:(BOOL)isChannel {
	self = [super init];
	if (!self)
		return nil;
	_chatId = chatId;
	_isChannel = isChannel;
	_options = [NSMutableArray arrayWithObject:@""];
	_correct = [NSMutableIndexSet indexSet];
	// Official's starting switches: a group sees who voted and may add
	// options; a channel is anonymous and shuffled.
	_multiple = YES;
	_revoting = YES;
	_anonymous = isChannel;
	_addingOptions = !isChannel;
	_shuffle = isChannel;
	return self;
}

- (instancetype)init {
	return [self initWithChatId:0 isChannel:NO];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.pageKind = TGPageKindForm;
	self.navigationItem.leftBarButtonItem = [TGBarItem itemWithRole:TGBarRoleCancel
			target:self action:@selector(cancelTapped)];
	self.navigationItem.rightBarButtonItem = [TGBarItem itemWithTitle:TGLocalizedKey(@"CreatePoll.Create", @"Send") primary:YES
			target:self action:@selector(sendTapped)];
	[self rebuild];
	[self focusFieldWithIdentifier:@"question"];
}

- (NSUInteger)filledCount {
	NSUInteger filled = 0;
	for (NSString *option in self.options)
		if (option.length)
			filled++;
	return filled;
}

- (void)rebuild {
	self.title = TGLocalized(self.quiz ? @"New Quiz" : @"New Poll");
	__weak typeof(self) weakSelf = self;

	NSMutableDictionary *question = TGFieldRow(TGLocalizedKey(@"CreatePoll.TextPlaceholder", @"Ask a question"), self.question,
			^(NSString *text){ weakSelf.question = text; });
	question[TGRowFieldIdentifier] = @"question";
	NSMutableDictionary *description = TGFieldRow(TGLocalized(@"Add Description (optional)"),
			self.pollDescription, ^(NSString *text){ weakSelf.pollDescription = text; });
	description[TGRowFieldIdentifier] = @"description";

	NSMutableArray *optionRows = [NSMutableArray array];
	for (NSUInteger i = 0; i < self.options.count; i++){
		BOOL last = i + 1 == self.options.count;
		NSMutableDictionary *row = TGFieldRow(TGLocalized(last ? @"Add an Option" : @"Option"),
				self.options[i], ^(NSString *text){ [weakSelf option:i changed:text]; });
		row[TGRowFieldIdentifier] = [NSString stringWithFormat:@"option%lu", (unsigned long)i];
		row[TGRowFieldMaxLength] = @(kPollOptionLength);
		[optionRows addObject:row];
	}
	NSUInteger filled = [self filledCount];
	NSString *optionsFooter = filled >= kPollMaxOptions
			? TGLocalized(@"You have added the maximum number of options.")
			: TGLocalizedPluralValue(@"You can add 1 more option.", @"You can add %@ more options.",
					[NSString stringWithFormat:@"%lu", (unsigned long)(kPollMaxOptions - filled)],
					(NSInteger)(kPollMaxOptions - filled));

	NSMutableArray *sections = [NSMutableArray arrayWithObjects:
			TGSection(TGLocalized(@"QUESTION"), nil, @[question, description]),
			TGSection(TGLocalized(@"OPTIONS"), optionsFooter, optionRows), nil];

	if (self.quiz){
		NSMutableArray *answers = [NSMutableArray array];
		for (NSUInteger i = 0; i < self.options.count; i++){
			if (![self.options[i] length])
				continue;
			[answers addObject:TGCheckRow(self.options[i], nil, [self.correct containsIndex:i], ^{
				[weakSelf toggleCorrect:i];
			})];
		}
		if (answers.count)
			[sections addObject:TGSection(nil, TGLocalized(@"Tap to choose the correct answer"), answers)];
	}

	NSMutableArray *settings = [NSMutableArray array];
	if (!self.isChannel)
		[settings addObject:TGSwitchInfoRow(TGLocalized(@"Show Who Voted"),
				TGLocalized(@"Display voter names on each option"), @"eye", TGIconTileAzure(), !self.anonymous, ^(BOOL on){
			weakSelf.anonymous = !on;
			if (!on)
				weakSelf.addingOptions = NO;
			[weakSelf rebuild];
		})];
	[settings addObject:TGSwitchInfoRow(TGLocalized(@"Allow Multiple Answers"),
			TGLocalized(@"Voters can select more than one option"), @"checkboxSelected", TGIconTileGreen(), self.multiple, ^(BOOL on){
		weakSelf.multiple = on;
		[weakSelf keepOneCorrectUnlessMultiple];
		[weakSelf rebuild];
	})];
	// Official locks this one off in a quiz; a switch that cannot move is
	// left out here instead.
	if (!self.isChannel && !self.quiz)
		[settings addObject:TGSwitchInfoRow(TGLocalized(@"Allow Adding Options"),
				TGLocalized(@"Participants can suggest new options"), @"plus", TGIconTileAmber(), self.addingOptions, ^(BOOL on){
			weakSelf.addingOptions = on;
			if (on)
				weakSelf.anonymous = NO;
			[weakSelf rebuild];
		})];
	[settings addObject:TGSwitchInfoRow(TGLocalized(@"Allow Revoting"),
			TGLocalized(@"Voters can change their vote"), @"undo", TGIconTileViolet(), self.revoting, ^(BOOL on){
		weakSelf.revoting = on;
	})];
	[settings addObject:TGSwitchInfoRow(TGLocalized(@"Shuffle Options"),
			TGLocalized(@"Answers appear in random order for each voter"), @"flip", TGIconTileCoral(), self.shuffle, ^(BOOL on){
		weakSelf.shuffle = on;
	})];
	[settings addObject:TGSwitchInfoRow(TGLocalized(@"Set Correct Answer"),
			TGLocalized(self.multiple ? @"Mark one or more options as the right answer"
									  : @"Mark one option as the right answer"), @"poll", TGIconTileGold(), self.quiz, ^(BOOL on){
		weakSelf.quiz = on;
		if (on){
			weakSelf.addingOptions = NO;
			weakSelf.revoting = NO;
		}
		[weakSelf rebuild];
	})];
	[sections addObject:TGSection(TGLocalized(@"SETTINGS"), nil, settings)];

	if (self.quiz){
		NSMutableDictionary *explanation = TGFieldRow(TGLocalized(@"Add a Comment (Optional)"),
				self.explanation, ^(NSString *text){ weakSelf.explanation = text; });
		explanation[TGRowFieldIdentifier] = @"explanation";
		[sections addObject:TGSection(TGLocalized(@"EXPLANATION"),
				TGLocalized(@"Users will see this comment after choosing a wrong answer, good for educational purposes."),
				@[explanation])];
	}
	self.sections = sections;
	[self reloadRows];
}

/// Official grows the list as you type: the last field filled brings a new
/// empty one, two empty fields at the end fold back into one. The page is
/// rebuilt only when that or the count footer changes, so typing stays cheap.
- (void)option:(NSUInteger)index changed:(NSString *)text {
	if (index >= self.options.count)
		return;
	BOOL wasFilled = [self.options[index] length] > 0;
	self.options[index] = text ?: @"";
	BOOL isFilled = text.length > 0;
	if (wasFilled == isFilled)
		return;
	if (!isFilled)
		[self.correct removeIndex:index];
	NSUInteger count = self.options.count;
	if (isFilled && index + 1 == count && count < kPollMaxOptions)
		[self.options addObject:@""];
	else if (!isFilled && count > 1 && index + 2 == count && ![self.options.lastObject length])
		[self.options removeLastObject];
	[self rebuild];
}

- (void)toggleCorrect:(NSUInteger)index {
	if ([self.correct containsIndex:index])
		[self.correct removeIndex:index];
	else {
		if (!self.multiple)
			[self.correct removeAllIndexes];
		[self.correct addIndex:index];
	}
	[self rebuild];
}

- (void)keepOneCorrectUnlessMultiple {
	if (self.multiple || self.correct.count < 2)
		return;
	NSUInteger first = self.correct.firstIndex;
	[self.correct removeAllIndexes];
	[self.correct addIndex:first];
}

#pragma mark - bar buttons

- (BOOL)hasAnyData {
	return self.question.length || self.pollDescription.length || [self filledCount] ||
			self.explanation.length;
}

- (void)cancelTapped {
	if (![self hasAnyData]){
		[TGPresent dismissModal:self];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showAlertActions:@[TGLocalized(@"No"), TGLocalized(@"Yes")] title:nil
			message:TGLocalized(@"Discard Poll?") inView:self.navigationController.view ?: self.view
			onAction:^(NSInteger index){
		if (index == 1)
			[TGPresent dismissModal:weakSelf];
	}];
}

/// Official's checks, in its order, each a short note at the bottom.
- (NSString *)missing {
	if (![[self.question stringByTrimmingCharactersInSet:
			NSCharacterSet.whitespaceAndNewlineCharacterSet] length])
		return @"Enter a question";
	if ([self filledCount] < (self.quiz ? 2 : 1))
		return self.quiz ? @"Add at least two options" : @"Add at least one option";
	if (self.quiz && !self.correct.count)
		return self.multiple ? @"Select at least one correct option" : @"Select a correct option";
	return nil;
}

- (void)sendTapped {
	if (self.sending)
		return;
	[self.view endEditing:YES];
	NSString *missing = [self missing];
	if (missing){
		[self toast:TGLocalized(missing)];
		return;
	}
	// TDLib counts the correct answers among the options it is sent, and the
	// empty trailing field is not sent.
	NSMutableArray *options = [NSMutableArray array];
	NSMutableArray *correct = [NSMutableArray array];
	for (NSUInteger i = 0; i < self.options.count; i++){
		if (![self.options[i] length])
			continue;
		if ([self.correct containsIndex:i])
			[correct addObject:@(options.count)];
		[options addObject:self.options[i]];
	}
	NSDictionary *draft = @{
		@"question" : self.question ?: @"", @"description" : self.pollDescription ?: @"",
		@"options" : options, @"anonymous" : @(self.anonymous), @"multiple" : @(self.multiple),
		@"addingOptions" : @(self.addingOptions), @"revoting" : @(self.revoting),
		@"shuffle" : @(self.shuffle), @"quiz" : @(self.quiz), @"correct" : correct,
		@"explanation" : self.explanation ?: @"",
	};
	self.sending = YES;
	__weak typeof(self) weakSelf = self;
	[[TGSendStore shared] sendPoll:draft toChat:self.chatId completion:^(BOOL ok, NSString *error){
		weakSelf.sending = NO;
		if (!ok){
			[weakSelf toast:error ?: TGLocalized(@"An error occurred.")];
			return;
		}
		[TGPresent dismissModal:weakSelf];
	}];
}

@end
