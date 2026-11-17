#import "TGDownloadList.h"

NSDictionary *TGDownloadListModel(NSArray *downloads, NSDictionary *counts) {
	NSMutableArray *downloading = [NSMutableArray array];
	NSMutableArray *downloaded = [NSMutableArray array];
	for (NSDictionary *item in [downloads isKindOfClass:NSArray.class] ? downloads : @[]) {
		if (![item isKindOfClass:NSDictionary.class])
			continue;
		[[item[@"done"] boolValue] ? downloaded : downloading addObject:item];
	}
	// Newest first: a file joins the queue at add_date and leaves it at
	// complete_date.
	[downloading sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b){
		return [b[@"addDate"] ?: @0 compare:a[@"addDate"] ?: @0];
	}];
	[downloaded sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b){
		return [b[@"completeDate"] ?: @0 compare:a[@"completeDate"] ?: @0];
	}];
	NSDictionary *c = [counts isKindOfClass:NSDictionary.class] ? counts : @{};
	NSInteger active = [c[@"active_count"] integerValue];
	NSInteger paused = [c[@"paused_count"] integerValue];
	NSInteger completed = [c[@"completed_count"] integerValue];
	return @{
		@"downloading"  : downloading,
		@"downloaded"   : downloaded,
		// active_count counts paused downloads too: all paused means the
		// header offers Resume All.
		@"allPaused"    : @(active > 0 && paused >= active),
		@"hasCompleted" : @(completed > 0 || downloaded.count > 0),
	};
}
