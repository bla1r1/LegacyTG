//
// TGSuggestedPostViewController.m
//
#import "TGSuggestedPostViewController.h"
#import "TGMessageStore.h"
#import "TGAlertSheet.h"

@interface TGSuggestedPostViewController ()
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, assign) int64_t messageId;
@property (nonatomic, strong) NSDictionary *post;
@property (nonatomic, copy) NSString *loadError;
@end

@implementation TGSuggestedPostViewController

- (instancetype)initWithChatId:(int64_t)chatId messageId:(int64_t)messageId {
	self = [super init];
	if (!self)
		return nil;
	_chatId = chatId;
	_messageId = messageId;
	return self;
}

- (void)viewDidLoad {
	self.title = @"Suggest Post";
	[super viewDidLoad];
	[self loadPost];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self rebuild];
}

- (void)loadPost {
	__weak typeof(self) weakSelf = self;
	[[TGMessageStore shared] suggestedPostForMessage:self.messageId inChat:self.chatId
									completion:^(NSDictionary *post, NSString *error){
		TGSuggestedPostViewController *me = weakSelf;
		if (!me)
			return;
		me.post = post;
		me.loadError = post ? nil : (error ?: @"An error occurred.");
		[me rebuild];
	}];
}

- (void)rebuild {
	__weak typeof(self) weakSelf = self;
	NSMutableArray *detailRows = [NSMutableArray array];
	if (self.post){
		NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
		formatter.dateStyle = NSDateFormatterMediumStyle;
		formatter.timeStyle = NSDateFormatterShortStyle;
		NSNumber *sendDate = self.post[@"sendDate"];
		NSString *dateText = [sendDate longLongValue] > 0
				? [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:
						[sendDate doubleValue]]]
				: @"None";
		[detailRows addObject:TGFeatureRow(@"Price", self.post[@"price"], nil)];
		[detailRows addObject:TGFeatureRow(@"Date", dateText, nil)];
		[detailRows addObject:TGFeatureRow(@"Status", self.post[@"state"], nil)];
		[detailRows addObject:TGFeatureRow(@"Approve",
				[self.post[@"canBeApproved"] boolValue] ? @"Yes" : @"No", nil)];
		[detailRows addObject:TGFeatureRow(@"Decline",
				[self.post[@"canBeDeclined"] boolValue] ? @"Yes" : @"No", nil)];
	} else {
		NSMutableDictionary *row = TGFeatureRow(self.loadError ?: @"Loading...", nil, nil);
		row[TGFeatureRowKind] = TGFeatureKindPlain;
		[detailRows addObject:row];
	}

	NSMutableArray *actions = [NSMutableArray array];
	[actions addObject:TGFeatureAction(@"Approve", ^{ [weakSelf approve]; })];
	[actions addObject:TGFeatureAction(@"Decline", ^{ [weakSelf decline]; })];
	[actions addObject:TGFeatureAction(@"Reload", ^{ [weakSelf loadPost]; })];

	self.sections = @[
		TGFeatureSection(nil, nil, detailRows),
		TGFeatureSection(nil, nil, actions),
	];
	[self reloadRows];
}

- (void)approve {
	if (![self.post[@"canBeApproved"] boolValue]){
		[self toast:@"An error occurred."];
		return;
	}
	NSInteger sendDate = [self.post[@"sendDate"] integerValue];
	if (sendDate <= 0)
		sendDate = (NSInteger)[[NSDate date] timeIntervalSince1970];
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:nil
						 title:@"Approve"
						action:@"Approve"
				   destructive:NO
						inView:self.view
					 onConfirm:^{
		[[TGMessageStore shared] approveSuggestedPost:weakSelf.messageId
										 inChat:weakSelf.chatId
									   sendDate:sendDate
									 completion:^(BOOL ok, NSString *error){
			if (!ok){
				[weakSelf toast:error ?: @"An error occurred."];
				return;
			}
			[weakSelf loadPost];
		}];
	}];
}

- (void)decline {
	if (![self.post[@"canBeDeclined"] boolValue]){
		[self toast:@"An error occurred."];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:@[@"Decline", @"Write a comment..."]
						title:@"Decline"
			 destructiveIndex:0
					   inView:self.view
					 onChoice:^(NSInteger index){
		if (index == 0){
			[weakSelf sendDecline:@""];
			return;
		}
		[TGAlertSheet showInput:@"Decline"
						message:nil
					placeholder:@"Comment"
						   text:nil
						 action:@"Decline"
						 inView:weakSelf.view
					   onSubmit:^(NSString *comment){
			[weakSelf sendDecline:comment];
		}];
	}];
}

- (void)sendDecline:(NSString *)comment {
	__weak typeof(self) weakSelf = self;
	[[TGMessageStore shared] declineSuggestedPost:self.messageId
									 inChat:self.chatId
									comment:comment
								 completion:^(BOOL ok, NSString *error){
		if (!ok){
			[weakSelf toast:error ?: @"An error occurred."];
			return;
		}
		[weakSelf loadPost];
	}];
}

@end
