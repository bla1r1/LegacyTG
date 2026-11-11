//
// TGDevStore.m - the Dev screens' store surface.
//
#import "TGDevStore.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGClient+Files.h"
#import "TGClient+FeatureSupport.h"
#import "TGBase64.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation TGDevStore

+ (instancetype)shared {
	static TGDevStore *store = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ store = [[TGDevStore alloc] init]; });
	return store;
}

#pragma mark - suggestions

- (void)setDisplayName:(NSString *)name forUserId:(int64_t)userId {
	[TGClient shared].usersById[@(userId)] = name;
}

- (NSArray *)suggestedActions {
	return [TGClient shared].suggestedActionsValue ?: @[];
}

- (void)hideSuggestedAction:(NSDictionary *)action
				 completion:(void (^)(BOOL, NSString *))completion {
	NSDictionary *object = TGFeatureDict(action[@"action"]);
	if (!object.count){
		if (completion)
			completion(NO, @"No suggested action was chosen.");
		return;
	}
	[[TGClient shared] request:@{
		@"@type"  : @"hideSuggestedAction",
		@"action" : object,
	} completion:^(NSDictionary *result){
		BOOL ok = TGFeatureOK(result);
		if (ok){
			NSString *key = TGFeatureActionKey(object);
			NSMutableArray *kept = [NSMutableArray array];
			for (NSDictionary *row in [TGClient shared].suggestedActionsValue){
				if (![TGFeatureActionKey(TGFeatureDict(row[@"action"])) isEqualToString:key])
					[kept addObject:row];
			}
			[TGClient shared].suggestedActionsValue = kept;
		}
		if (completion)
			completion(ok, ok ? nil : TGFeatureErrorText(result));
	}];
}

#pragma mark - files

- (void (^)(NSInteger, float))onFileUploadProgress {
	return [TGClient shared].onFileUploadProgress;
}

- (void)setOnFileUploadProgress:(void (^)(NSInteger, float))handler {
	[TGClient shared].onFileUploadProgress = handler;
}

- (void)readFilePartOfFile:(NSInteger)fileId
					offset:(long long)offset
					 count:(NSInteger)count
				completion:(void (^)(NSData *))completion {
	if (fileId <= 0){
		if (completion) completion(nil);
		return;
	}
	[[TGClient shared] request:@{
		@"@type"   : @"readFilePart",
		@"file_id" : @(fileId),
		@"offset"  : @(offset),
		@"count"   : @(MAX((NSInteger)0, count)),
	} completion:^(NSDictionary *result){
		NSData *data = nil;
		if ([result isKindOfClass:NSDictionary.class] &&
			[result[@"@type"] isEqualToString:@"data"])
			data = TGBase64Decode(result[@"data"]);
		if (completion) completion(data);
	}];
}

/// A generation is a conversation with the receive loop: TDLib answers
/// preliminaryUploadFile with updateFileGenerationStart and keeps the
/// generation id in the client's pending table. The client owns that state,
/// so the store lets it finish the flow rather than starting a second one
/// that no update would ever reach.
- (void)cancelPreliminaryUploadOfFile:(NSInteger)fileId {
	[[TGClient shared] cancelPreliminaryUploadOfFile:fileId];
}

- (void)generateTextFileNamed:(NSString *)name
					 contents:(NSString *)contents
					 progress:(void (^)(NSInteger, float, NSString *))progress
				   completion:(void (^)(NSInteger, NSString *, NSError *))completion {
	[[TGClient shared] generateTextFileNamed:name contents:contents
									progress:progress completion:completion];
}

@end

#pragma clang diagnostic pop
