//
// TGQuickReplyMessagesViewController.m
//
#import "TGQuickReplyMessagesViewController.h"
#import "TGClient.h"
#import "TGAlertSheet.h"

@interface TGQuickReplyMessagesViewController ()
@property (nonatomic, assign) NSInteger shortcutId;
@property (nonatomic, copy) NSString *shortcutName;
@property (nonatomic, strong) NSMutableArray *messages;
@property (nonatomic, strong) NSMutableSet *selectedIds;
@property (nonatomic, strong) NSMutableArray *removedIds;
@end

@implementation TGQuickReplyMessagesViewController

- (instancetype)initWithShortcutId:(NSInteger)shortcutId name:(NSString *)name {
	self = [super init];
	if (!self)
		return nil;
	_shortcutId = shortcutId;
	_shortcutName = [name copy] ?: @"Shortcut";
	_selectedIds = [NSMutableSet set];
	_removedIds = [NSMutableArray array];
	return self;
}

- (void)viewDidLoad {
	self.title = self.shortcutName;
	[super viewDidLoad];
	[self loadMessages];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self rebuild];
}

- (void)loadMessages {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] loadQuickReplyMessagesForShortcut:self.shortcutId
											  completion:^(NSArray *messages){
		TGQuickReplyMessagesViewController *me = weakSelf;
		if (!me)
			return;
		me.messages = [messages mutableCopy] ?: [NSMutableArray array];
		[me.selectedIds removeAllObjects];
		[me rebuild];
	}];
}

- (void)rebuild {
	__weak typeof(self) weakSelf = self;
	NSMutableArray *messageRows = [NSMutableArray array];
	for (NSDictionary *message in self.messages){
		NSNumber *ident = message[@"id"];
		NSString *text = message[@"text"];
		if (!text.length){
			NSString *kind = message[@"kind"];
			text = kind.length ? kind : @"Message";
		}
		BOOL checked = [self.selectedIds containsObject:ident];
		[messageRows addObject:TGFeatureCheck(text, nil, checked, ^{
			if (!ident)
				return;
			if ([weakSelf.selectedIds containsObject:ident])
				[weakSelf.selectedIds removeObject:ident];
			else
				[weakSelf.selectedIds addObject:ident];
			[weakSelf rebuild];
		})];
	}
	if (!messageRows.count){
		NSMutableDictionary *empty = TGFeatureRow(@"No messages here yet...", nil, nil);
		empty[TGFeatureRowKind] = TGFeatureKindPlain;
		[messageRows addObject:empty];
	}

	NSMutableArray *actions = [NSMutableArray array];
	[actions addObject:TGFeatureAction(@"Add Message", ^{ [weakSelf addMessage]; })];
	[actions addObject:TGFeatureAction(@"Add to Album", ^{ [weakSelf addAlbum]; })];
	[actions addObject:TGFeatureAction(@"Edit Message", ^{
		[weakSelf editSelectedMessage];
	})];
	[actions addObject:TGFeatureAction(@"Delete Messages", ^{
		[weakSelf deleteSelectedMessages];
	})];
	if (self.removedIds.count){
		[actions addObject:TGFeatureAction(@"Restore",
				^{ [weakSelf readdRemovedMessages]; })];
	}
	[actions addObject:TGFeatureAction(@"Rename", ^{ [weakSelf renameShortcut]; })];

	NSMutableDictionary *delete = TGFeatureRow(@"Delete Quick Reply", nil, ^{
		[weakSelf deleteShortcut];
	});
	delete[TGFeatureRowKind] = TGFeatureKindDestructive;

	self.sections = @[
		TGFeatureSection(nil, nil, messageRows),
		TGFeatureSection(nil, nil, actions),
		TGFeatureSection(nil, nil, @[delete]),
	];
	[self reloadRows];
}

#pragma mark - writes

- (void)addMessage {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Add Message"
					message:nil
				placeholder:@"Message"
					   text:nil
					 action:@"Add"
					 inView:self.view
				   onSubmit:^(NSString *text){
		[[TGClient shared] addQuickReplyShortcutMessage:weakSelf.shortcutName
												   text:text
											 completion:^(NSDictionary *message,
														  NSString *error){
			if (!message){
				[weakSelf toast:error ?: @"An error occurred."];
				return;
			}
			[weakSelf loadMessages];
		}];
	}];
}

- (void)addAlbum {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Message"
					message:nil
				placeholder:@"Message"
					   text:nil
					 action:@"Next"
					 inView:self.view
				   onSubmit:^(NSString *first){
		[TGAlertSheet showInput:@"Message"
						message:nil
					placeholder:@"Message"
						   text:nil
						 action:@"Add"
						 inView:weakSelf.view
					   onSubmit:^(NSString *second){
			[[TGClient shared] addQuickReplyShortcutMessageAlbum:weakSelf.shortcutName
														   texts:@[first, second]
													  completion:^(NSArray *messages,
																   NSString *error){
				if (!messages.count){
					[weakSelf toast:error ?: @"An error occurred."];
					return;
				}
				[weakSelf loadMessages];
			}];
		}];
	}];
}

- (void)editSelectedMessage {
	if (self.selectedIds.count != 1){
		[self toast:@"An error occurred."];
		return;
	}
	NSNumber *ident = self.selectedIds.anyObject;
	NSDictionary *message = nil;
	for (NSDictionary *candidate in self.messages){
		if ([candidate[@"id"] isEqualToNumber:ident]){
			message = candidate;
			break;
		}
	}
	if (!message)
		return;
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Edit Message"
					message:self.shortcutName
				placeholder:@"Message"
					   text:message[@"text"]
					 action:@"Save"
					 inView:self.view
				   onSubmit:^(NSString *text){
		[[TGClient shared] editQuickReplyMessage:ident.longLongValue
									  shortcutId:weakSelf.shortcutId
											text:text
									  completion:^(BOOL ok, NSString *error){
			if (!ok){
				[weakSelf toast:error ?: @"An error occurred."];
				return;
			}
			[weakSelf loadMessages];
		}];
	}];
}

- (void)deleteSelectedMessages {
	if (!self.selectedIds.count){
		[self toast:@"An error occurred."];
		return;
	}
	NSArray *ids = self.selectedIds.allObjects;
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:nil
						 title:@"Delete Messages"
						action:@"Delete"
				   destructive:YES
						inView:self.view
					 onConfirm:^{
		[[TGClient shared] deleteQuickReplyShortcutMessages:ids
												shortcutId:weakSelf.shortcutId
												completion:^(BOOL ok, NSString *error){
			if (!ok){
				[weakSelf toast:error ?: @"An error occurred."];
				return;
			}
			[weakSelf.removedIds addObjectsFromArray:ids];
			[weakSelf loadMessages];
		}];
	}];
}

- (void)readdRemovedMessages {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] readdQuickReplyShortcutMessages:self.removedIds
										  shortcutName:self.shortcutName
											completion:^(NSArray *messages, NSString *error){
		if (!messages.count && error.length){
			[weakSelf toast:error];
			return;
		}
		[weakSelf.removedIds removeAllObjects];
		[weakSelf loadMessages];
	}];
}

- (void)renameShortcut {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Rename"
					message:nil
				placeholder:@"Shortcut"
					   text:self.shortcutName
					 action:@"Save"
					 inView:self.view
				   onSubmit:^(NSString *name){
		[[TGClient shared] checkQuickReplyShortcutName:name
											completion:^(BOOL ok, NSString *error){
			if (!ok){
				[weakSelf toast:error ?: @"An error occurred."];
				return;
			}
			[[TGClient shared] setQuickReplyShortcutName:weakSelf.shortcutId
												   name:name
											 completion:^(BOOL saved, NSString *why){
				if (!saved){
					[weakSelf toast:why ?: @"An error occurred."];
					return;
				}
				weakSelf.shortcutName = name;
				weakSelf.title = name;
				[weakSelf loadMessages];
			}];
		}];
	}];
}

- (void)deleteShortcut {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:nil
						 title:@"Delete Quick Reply"
						action:@"Delete"
				   destructive:YES
						inView:self.view
					 onConfirm:^{
		[[TGClient shared] deleteQuickReplyShortcut:weakSelf.shortcutId
										completion:^(BOOL ok, NSString *error){
			if (!ok){
				[weakSelf toast:error ?: @"An error occurred."];
				return;
			}
			[weakSelf.navigationController popViewControllerAnimated:YES];
		}];
	}];
}

@end
