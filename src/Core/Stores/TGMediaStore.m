//
// TGMediaStore - forwards the media display's four questions to the client.
//
#import "TGMediaStore.h"
#import "TGClient.h"
#import "TGMessageStore.h"
#import "TGProfileStore.h"
#import "TGClientInternal.h"
#import "TGMediaSupport.h"

@implementation TGMediaStore {
	NSCache *_buffers;
}

+ (TGMediaStore *)shared {
	static TGMediaStore *one;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		one = [[TGMediaStore alloc] init];
		one->_buffers = [[NSCache alloc] init];
		one->_buffers.totalCostLimit = (sizeof(void *) == 4)
				? 16 * 1024 * 1024 : 32 * 1024 * 1024;
	});
	return one;
}

- (NSString *)nameForUserId:(int64_t)userId {
	return [[TGMessageStore shared] nameForUserId:userId];
}

- (NSNumber *)photoFileIdForUserId:(int64_t)userId {
	return [[TGProfileStore shared] photoFileIdForUserId:userId];
}

- (void)downloadFile:(NSInteger)fileId completion:(void (^)(NSString *path))completion {
	[[TGClient shared] downloadFile:fileId completion:completion];
}

- (void)downloadFile:(NSInteger)fileId priority:(NSInteger)priority
          completion:(void (^)(NSString *path))completion {
	[[TGClient shared] downloadFile:fileId priority:priority completion:completion];
}

- (void)fileInfo:(NSInteger)fileId completion:(void (^)(NSDictionary *))completion {
if (fileId <= 0){
		if (completion) completion(nil);
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"getFile", @"file_id" : @(fileId)}
	   completion:^(NSDictionary *result){
		if (![result isKindOfClass:NSDictionary.class] ||
			[result[@"@type"] isEqualToString:@"error"]){
			if (completion) completion(nil);
			return;
		}
		NSMutableDictionary *info = [TGFlattenFileRecord(result) mutableCopy];
		NSString *remoteId = info[@"remoteId"];
		if (![remoteId isKindOfClass:NSString.class] || !remoteId.length){
			if (completion) completion(info);
			return;
		}

		[[TGClient shared] request:@{
			@"@type"          : @"getRemoteFile",
			@"remote_file_id" : remoteId,
			@"file_type"      : @{@"@type" : @"fileTypeUnknown"},
		} completion:^(NSDictionary *remote){
			if ([remote isKindOfClass:NSDictionary.class] &&
				![remote[@"@type"] isEqualToString:@"error"]){
				info[@"remoteResolved"] = @YES;
				info[@"remoteSize"] = remote[@"size"] ?: @(0);
				info[@"remoteExpectedSize"] = remote[@"expected_size"] ?: @(0);
				info[@"remoteUploading"] = remote[@"remote"][@"is_uploading_active"] ?: @NO;
				info[@"remoteUploadedSize"] = remote[@"remote"][@"uploaded_size"] ?: @(0);
			} else {
				info[@"remoteResolved"] = @NO;
			}
			if (completion) completion(info);
		}];
	}];
}
- (void)fileDownloadedPrefixSize:(NSInteger)fileId offset:(long long)offset
					  completion:(void (^)(long long))completion {
if (fileId <= 0){
		if (completion) completion(0);
		return;
	}
	[[TGClient shared] request:@{
		@"@type"   : @"getFileDownloadedPrefixSize",
		@"file_id" : @(fileId),
		@"offset"  : @(offset),
	} completion:^(NSDictionary *result){
		long long bytes = 0;
		if ([result isKindOfClass:NSDictionary.class] &&
			![result[@"@type"] isEqualToString:@"error"])
			bytes = [result[@"size"] longLongValue];
		if (completion) completion(bytes);
	}];
}
- (void)suggestedFileNameForFile:(NSInteger)fileId directory:(NSString *)directory
					  completion:(void (^)(NSString *))completion {
if (fileId <= 0){
		if (completion) completion(@"");
		return;
	}
	NSString *folder = directory.length ? directory : NSTemporaryDirectory();
	[[TGClient shared] request:@{
		@"@type"     : @"getSuggestedFileName",
		@"file_id"   : @(fileId),
		@"directory" : folder,
	} completion:^(NSDictionary *result){
		if (completion) completion(TGFileTextAnswer(result));
	}];
}
- (void)fileNameInfo:(NSString *)name completion:(void (^)(NSDictionary *))completion {
NSString *value = name ?: @"";
	[[TGClient shared] request:@{@"@type" : @"getFileMimeType", @"file_name" : value}
	   completion:^(NSDictionary *mimeAnswer){
		NSString *mime = TGFileTextAnswer(mimeAnswer);
		[[TGClient shared] request:@{@"@type" : @"getFileExtension", @"mime_type" : mime}
		   completion:^(NSDictionary *extensionAnswer){
			NSString *extension = TGFileTextAnswer(extensionAnswer);
			[[TGClient shared] request:@{@"@type" : @"cleanFileName", @"file_name" : value}
			   completion:^(NSDictionary *cleanAnswer){
				NSDictionary *info = @{
					@"mime"      : mime,
					@"extension" : extension,
					@"cleanName" : TGFileTextAnswer(cleanAnswer),
				};
				if (completion) completion(info);
			}];
		}];
	}];
}
- (void)deleteLocalFile:(NSInteger)fileId {
[[TGClient shared] send:@{@"@type" : @"deleteFile", @"file_id" : @(fileId)}];
}
- (void)addFileToDownloads:(NSInteger)fileId inChat:(int64_t)chatId message:(int64_t)messageId {
[[TGClient shared] send:@{
		@"@type"      : @"addFileToDownloads",
		@"file_id"    : @(fileId),
		@"chat_id"    : @(chatId),
		@"message_id" : @(messageId),
		@"priority"   : @(1),
	}];
}
- (void)cancelDownloadOfFile:(NSInteger)fileId onlyIfPending:(BOOL)onlyIfPending {
[[TGClient shared] send:@{
		@"@type"           : @"cancelDownloadFile",
		@"file_id"         : @(fileId),
		@"only_if_pending" : @(onlyIfPending),
	}];

	[[TGClient shared] releaseFileWaiters:fileId];
}
- (NSData *)cachedBufferForFileId:(NSInteger)fileId {
	return [_buffers objectForKey:@(fileId)];
}
- (void)cacheBuffer:(NSData *)data forFileId:(NSInteger)fileId {
	if (data)
		[_buffers setObject:data forKey:@(fileId) cost:data.length];
}

@end
