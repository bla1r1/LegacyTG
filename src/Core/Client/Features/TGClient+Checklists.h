#import "TGClient+Base.h"

@interface TGClient (Checklists)

#pragma mark - checklists

/// Reads the message and returns its checklist: "title", "tasks" (each "id",
/// "text", "done"), "canAddTasks", "canMarkTasks", "othersCanAddTasks" and
/// "othersCanMarkTasks". Nil for a message that is not a checklist.
- (void)checklistForMessage:(int64_t)messageId
                     inChat:(int64_t)chatId
                 completion:(void (^)(NSDictionary *checklist, NSString *error))completion;

/// Replaces the whole checklist. `tasks` are dictionaries with "id" (0 for
/// a new task) and "text".
- (void)editMessageChecklist:(int64_t)messageId
                      inChat:(int64_t)chatId
                       title:(NSString *)title
                       tasks:(NSArray *)tasks
                othersCanAdd:(BOOL)othersCanAdd
              othersCanMark:(BOOL)othersCanMark
                  completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)addChecklistTasks:(NSArray *)tasks
                toMessage:(int64_t)messageId
                   inChat:(int64_t)chatId
               completion:(void (^)(BOOL ok, NSString *error))completion;

/// `doneTaskIds` and `notDoneTaskIds` are the tasks to flip, by their int32
/// ids. Sending the same list on both sides is refused by the server.
- (void)markChecklistTasksAsDone:(NSArray *)doneTaskIds
                    notDoneTaskIds:(NSArray *)notDoneTaskIds
                         onMessage:(int64_t)messageId
                            inChat:(int64_t)chatId
                        completion:(void (^)(BOOL ok, NSString *error))completion;

/// Sends a new checklist into a chat. The same inputChecklist object the
/// editor builds, wrapped in a regular sendMessage.
- (void)sendChecklist:(NSString *)title
                tasks:(NSArray *)tasks
               toChat:(int64_t)chatId
           completion:(void (^)(BOOL ok, NSString *error))completion;


@end
