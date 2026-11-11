//
// TGMediaSupport.m - the pure file-record helpers shared by the media stores.
//
#import "TGMediaSupport.h"

NSString *TGFileTextAnswer(NSDictionary *result) {
	if (![result isKindOfClass:NSDictionary.class])
		return @"";
	if ([result[@"@type"] isEqualToString:@"error"])
		return @"";
	return [result[@"text"] isKindOfClass:NSString.class] ? result[@"text"] : @"";
}

NSDictionary *TGFlattenFileRecord(NSDictionary *file) {
	NSDictionary *local = file[@"local"];
	NSDictionary *remote = file[@"remote"];
	if (![local isKindOfClass:NSDictionary.class]) local = @{};
	if (![remote isKindOfClass:NSDictionary.class]) remote = @{};
	return @{
		@"fileId"           : file[@"id"] ?: @(0),
		@"size"             : file[@"size"] ?: @(0),
		@"expectedSize"     : file[@"expected_size"] ?: @(0),
		@"downloadedSize"   : local[@"downloaded_size"] ?: @(0),
		@"localPath"        : local[@"path"] ?: @"",
		@"downloading"      : local[@"is_downloading_active"] ?: @NO,
		@"completed"        : local[@"is_downloading_completed"] ?: @NO,
		@"remoteId"         : remote[@"id"] ?: @"",
		@"remoteUniqueId"   : remote[@"unique_id"] ?: @"",
		@"remoteUploading"  : remote[@"is_uploading_active"] ?: @NO,
		@"remoteUploadedSize" : remote[@"uploaded_size"] ?: @(0),
	};
}
