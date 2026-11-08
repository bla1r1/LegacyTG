#import "TGClient+Checklists.h"
#import "TGClientInternal.h"
#import "TGClient+FeatureSupport.h"

@implementation TGClient (Checklists)

#pragma mark - checklists

- (void)checklistForMessage:(int64_t)messageId
                     inChat:(int64_t)chatId
                 completion:(void (^)(NSDictionary *, NSString *))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{
		@"@type"      : @"getMessage",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
	} completion:^(NSDictionary *message){
		if (!TGFeatureOK(message)){
			if (completion)
				completion(nil, TGFeatureErrorText(message));
			return;
		}
		NSDictionary *content = TGFeatureDict(message[@"content"]);
		if (![content[@"@type"] isEqualToString:@"messageChecklist"]){
			if (completion)
				completion(nil, @"That message has no checklist.");
			return;
		}
		NSDictionary *list = TGFeatureDict(content[@"checklist"]);
		NSMutableArray *tasks = [NSMutableArray array];
		for (NSDictionary *task in TGFeatureArray(list[@"tasks"])){
			id completedBy = task[@"completed_by"];
			BOOL done = completedBy && ![completedBy isKindOfClass:NSNull.class];
			[tasks addObject:@{
				@"id"   : task[@"id"] ?: @(0),
				@"text" : TGFeatureDict(task[@"text"])[@"text"] ?: @"",
				@"done" : @(done),
			}];
		}
		NSDictionary *checklist = @{
			@"title"            : TGFeatureDict(list[@"title"])[@"text"] ?: @"",
			@"tasks"            : tasks,
			@"canAddTasks"      : list[@"can_add_tasks"] ?: @NO,
			@"canMarkTasks"     : list[@"can_mark_tasks_as_done"] ?: @NO,
			@"othersCanAddTasks": list[@"others_can_add_tasks"] ?: @NO,
			@"othersCanMarkTasks": list[@"others_can_mark_tasks_as_done"] ?: @NO,
		};
		weakSelf.checklistCache[@(messageId)] = checklist;
		if (completion)
			completion(checklist, nil);
	}];
}

- (void)editMessageChecklist:(int64_t)messageId
                      inChat:(int64_t)chatId
                       title:(NSString *)title
                       tasks:(NSArray *)tasks
                othersCanAdd:(BOOL)othersCanAdd
              othersCanMark:(BOOL)othersCanMark
                  completion:(void (^)(BOOL, NSString *))completion {
	[self request:@{
		@"@type"      : @"editMessageChecklist",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
		@"reply_markup": [NSNull null],
		@"checklist"  : [TGClient inputChecklistWithTitle:title
													tasks:tasks
											 othersCanAdd:othersCanAdd
											othersCanMark:othersCanMark],
	} completion:^(NSDictionary *result){
		BOOL ok = TGFeatureOK(result);
		if (ok)
			[self.checklistCache removeObjectForKey:@(messageId)];
		if (completion)
			completion(ok, ok ? nil : TGFeatureErrorText(result));
	}];
}

- (void)addChecklistTasks:(NSArray *)tasks
                toMessage:(int64_t)messageId
                   inChat:(int64_t)chatId
               completion:(void (^)(BOOL, NSString *))completion {
	NSMutableArray *input = [NSMutableArray array];
	for (NSDictionary *task in tasks){
		NSString *text = TGFeatureString(task[@"text"]);
		if (!text.length)
			continue;
		[input addObject:@{
			@"@type" : @"inputChecklistTask",
			@"id"    : @([task[@"id"] integerValue]),
			@"text"  : TGFormattedText(text),
		}];
	}
	if (!input.count){
		if (completion)
			completion(NO, @"No task to add.");
		return;
	}
	[self request:@{
		@"@type"      : @"addChecklistTasks",
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
		@"tasks"      : input,
	} completion:^(NSDictionary *result){
		BOOL ok = TGFeatureOK(result);
		if (ok)
			[self.checklistCache removeObjectForKey:@(messageId)];
		if (completion)
			completion(ok, ok ? nil : TGFeatureErrorText(result));
	}];
}

- (void)markChecklistTasksAsDone:(NSArray *)doneTaskIds
                    notDoneTaskIds:(NSArray *)notDoneTaskIds
                         onMessage:(int64_t)messageId
                            inChat:(int64_t)chatId
                        completion:(void (^)(BOOL, NSString *))completion {
	[self request:@{
		@"@type"                    : @"markChecklistTasksAsDone",
		@"chat_id"                  : @(chatId),
		@"message_id"               : @(messageId),
		@"marked_as_done_task_ids"  : doneTaskIds ?: @[],
		@"marked_as_not_done_task_ids": notDoneTaskIds ?: @[],
	} completion:^(NSDictionary *result){
		BOOL ok = TGFeatureOK(result);
		if (ok)
			[self.checklistCache removeObjectForKey:@(messageId)];
		if (completion)
			completion(ok, ok ? nil : TGFeatureErrorText(result));
	}];
}

- (void)sendChecklist:(NSString *)title
                tasks:(NSArray *)tasks
               toChat:(int64_t)chatId
           completion:(void (^)(BOOL, NSString *))completion {
	NSMutableArray *input = [NSMutableArray array];
	for (NSDictionary *task in tasks){
		NSString *text = TGFeatureString(task[@"text"]);
		if (!text.length)
			continue;
		[input addObject:@{
			@"@type" : @"inputChecklistTask",
			@"id"    : @(0),
			@"text"  : TGFormattedText(text),
		}];
	}
	if (!title.length || !input.count){
		if (completion)
			completion(NO, @"A checklist needs a title and a task.");
		return;
	}
	[self request:@{
		@"@type"                : @"sendMessage",
		@"chat_id"              : @(chatId),
		@"input_message_content": @{
			@"@type"     : @"inputMessageChecklist",
			@"checklist" : [TGClient inputChecklistWithTitle:title
													  tasks:input
											   othersCanAdd:YES
											  othersCanMark:YES],
		},
	} completion:^(NSDictionary *result){
		BOOL ok = TGFeatureOK(result);
		if (completion)
			completion(ok, ok ? nil : TGFeatureErrorText(result));
	}];
}


@end
