//
// TGChecklistPresentation.m - the words and the done rule a checklist shows.
//
// Every value may be NSNull or the wrong class, so the readers below check
// the class before they trust it.
//
#import "TGChecklistPresentation.h"

static NSArray *TGChecklistTasks(NSDictionary *checklist) {
	id tasks = [checklist isKindOfClass:NSDictionary.class]
			? checklist[@"tasks"] : nil;
	return [tasks isKindOfClass:NSArray.class] ? tasks : @[];
}

static long long TGChecklistLongLong(id value) {
	if ([value isKindOfClass:NSNumber.class] || [value isKindOfClass:NSString.class])
		return [value longLongValue];
	return 0;
}

static BOOL TGChecklistBool(id value) {
	if ([value isKindOfClass:NSNumber.class] || [value isKindOfClass:NSString.class])
		return [value boolValue];
	return NO;
}

NSString *TGChecklistProgressLine(NSDictionary *checklist) {
	NSArray *tasks = TGChecklistTasks(checklist);
	NSUInteger done = 0;
	for (id raw in tasks)
		if (TGChecklistTaskDone([raw isKindOfClass:NSDictionary.class] ? raw : nil))
			done++;
	if (done == 0)
		return @"No tasks completed";
	return [NSString stringWithFormat:@"%lu of %lu completed",
			(unsigned long)done, (unsigned long)tasks.count];
}

BOOL TGChecklistTaskDone(NSDictionary *task) {
	if (![task isKindOfClass:NSDictionary.class])
		return NO;
	if (TGChecklistLongLong(task[@"completedByUserId"]) != 0)
		return YES;
	return TGChecklistLongLong(task[@"completionDate"]) > 0;
}

BOOL TGChecklistCanToggle(NSDictionary *checklist) {
	if (![checklist isKindOfClass:NSDictionary.class])
		return NO;
	return TGChecklistBool(checklist[@"canMarkTasksAsDone"]);
}
