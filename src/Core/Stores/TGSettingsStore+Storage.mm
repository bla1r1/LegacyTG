#import "TGSettingsStore.h"
#import "TGClientInternal.h"
#import "TGMediaSupport.h"
#import "TGBase64.h"



// Note: this file is shared with the host test suite (tests/Makefile compiles
// it into TGClientTests); nothing device-only lives here.

@implementation TGSettingsStore (Storage)

#pragma mark - network and downloads

- (void)networkStatsWithCompletion:(void (^)(long long, long long))completion {
	[[TGClient shared] request:@{@"@type" : @"getNetworkStatistics", @"only_current" : @NO}
	   completion:^(NSDictionary *stats){
		long long sent = 0, received = 0;
		for (NSDictionary *entry in stats[@"entries"]){
			sent     += [entry[@"sent_bytes"] longLongValue];
			received += [entry[@"received_bytes"] longLongValue];
		}
		if (completion) completion(sent, received);
	}];
}

- (void)resetNetworkStats {
	[[TGClient shared] send:@{@"@type" : @"resetNetworkStatistics"}];
}

/// TDLib only offers presets through getAutoDownloadSettingsPresets; what is
/// actually in force is not readable back, so the app keeps the answer it
/// wrote. Off over mobile by default: this is a 3G phone with a small disk.
- (BOOL)autoDownloadOverMobile {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	return [defaults objectForKey:@"TGAutoDownloadMobile"]
			? [defaults boolForKey:@"TGAutoDownloadMobile"] : NO;
}

- (BOOL)autoDownloadOverWifi {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	return [defaults objectForKey:@"TGAutoDownloadWifi"]
			? [defaults boolForKey:@"TGAutoDownloadWifi"] : YES;
}

- (void)setAutoDownloadOverMobile:(BOOL)mobile wifi:(BOOL)wifi {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setBool:mobile forKey:@"TGAutoDownloadMobile"];
	[defaults setBool:wifi forKey:@"TGAutoDownloadWifi"];
	[defaults synchronize];

	// "Off" here means off in TDLib too, not merely hidden in the interface.
	NSDictionary *(^settingsFor)(BOOL) = ^NSDictionary *(BOOL enabled){
		return @{
			@"@type"                    : @"autoDownloadSettings",
			@"is_auto_download_enabled" : @(enabled),
			@"max_photo_file_size"      : @(10 * 1024 * 1024),
			@"max_video_file_size"      : @(10 * 1024 * 1024),
			@"max_other_file_size"      : @(10 * 1024 * 1024),
			@"video_upload_bitrate"     : @(0),
			@"preload_large_videos"     : @NO,
			@"preload_next_audio"       : @NO,
			@"use_less_data_for_calls"  : @YES,
		};
	};
	[[TGClient shared] send:@{@"@type" : @"setAutoDownloadSettings", @"settings" : settingsFor(mobile),
				 @"type"  : @{@"@type" : @"networkTypeMobile"}}];
	[[TGClient shared] send:@{@"@type" : @"setAutoDownloadSettings", @"settings" : settingsFor(wifi),
				 @"type"  : @{@"@type" : @"networkTypeWiFi"}}];
}

#pragma mark - storage

- (void)storageStatsWithCompletion:(void (^)(long long, NSInteger))completion {
	[[TGClient shared] request:@{@"@type" : @"getStorageStatisticsFast"}
	   completion:^(NSDictionary *stats){
		if (completion)
			completion([stats[@"files_size"] longLongValue],
					   [stats[@"file_count"] integerValue]);
	}];
}

- (void)clearCacheOfTypes:(NSArray *)kinds completion:(void (^)(long long))completion {
	NSMutableArray *types = [NSMutableArray array];
	for (NSString *kind in kinds)
		[types addObject:@{@"@type" : kind}];

	// count/ttl/size of -1 mean "no limit of that sort", so only the file
	// types listed decide what goes.
	[[TGClient shared] request:@{
		@"@type"          : @"optimizeStorage",
		@"size"           : @(-1),
		@"ttl"            : @(-1),
		@"count"          : @(-1),
		@"immunity_delay" : @(0),
		@"file_types"     : types,
		@"chat_ids"       : @[],
		@"exclude_chat_ids" : @[],
		@"return_deleted_file_statistics" : @YES,
		@"chat_limit"     : @(0),
	} completion:^(NSDictionary *stats){
		long long freed = 0;
		for (NSDictionary *byChat in stats[@"by_chat"])
			for (NSDictionary *byType in byChat[@"by_file_type"])
				freed += [byType[@"size"] longLongValue];
		if (completion) completion(freed);
	}];
}

/// Computes storage breakdown by file category and returns total bytes.
- (void)storageBreakdownWithCompletion:(void (^)(NSArray *, long long))completion {
	// The categories their page shows, and the TDLib file types under each.
	static NSArray *groups = nil;
	if (!groups)
		groups = @[
			@[@"Photos",   @[@"fileTypePhoto", @"fileTypeProfilePhoto", @"fileTypeThumbnail"]],
			@[@"Video",    @[@"fileTypeVideo", @"fileTypeVideoNote", @"fileTypeAnimation"]],
			@[@"Stickers", @[@"fileTypeSticker"]],
			@[@"Music",    @[@"fileTypeAudio", @"fileTypeVoiceNote"]],
			@[@"Files",    @[@"fileTypeDocument"]],
		];

	[[TGClient shared] request:@{@"@type" : @"getStorageStatistics", @"chat_limit" : @(256)}
	   completion:^(NSDictionary *stats){
		NSMutableDictionary *bytesByType = [NSMutableDictionary dictionary];
		for (NSDictionary *chat in stats[@"by_chat"]){
			for (NSDictionary *entry in chat[@"by_file_type"]){
				NSString *type = entry[@"file_type"][@"@type"];
				if (!type) continue;
				long long previous = [bytesByType[type] longLongValue];
				bytesByType[type] = @(previous + [entry[@"size"] longLongValue]);
			}
		}

		long long total = [stats[@"size"] longLongValue];
		long long accounted = 0;
		NSMutableArray *out = [NSMutableArray array];
		for (NSArray *group in groups){
			long long bytes = 0;
			for (NSString *kind in group[1])
				bytes += [bytesByType[kind] longLongValue];
			accounted += bytes;
			if (bytes > 0)
				[out addObject:@{@"name" : group[0], @"bytes" : @(bytes),
								 @"kinds" : group[1]}];
		}

		// Whatever the walk did not attribute is still on the disk, and a chart
		// that silently drops it does not add up to the number above it.
		if (total > accounted)
			[out addObject:@{@"name"  : @"Other",
							 @"bytes" : @(total - accounted),
							 @"kinds" : @[]}];

		[out sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b){
			long long x = [a[@"bytes"] longLongValue], y = [b[@"bytes"] longLongValue];
			return x > y ? NSOrderedAscending : (x < y ? NSOrderedDescending : NSOrderedSame);
		}];
		if (completion) completion(out, total);
	}];
}

- (void)clearLocalDatabase {
	// Wipes cached chats/messages but keeps the session.
	[[TGClient shared] send:@{@"@type" : @"optimizeStorage", @"chat_limit" : @(0)}];
	[[TGClient shared].chatsById removeAllObjects];
	[[TGClient shared] rebuildChats];
}

#pragma mark - file records, names and bytes

/// A text answer from getFileMimeType, getFileExtension, cleanFileName and
/// getSuggestedFileName. Errors are an empty string: the File Info screen
/// still has rows to draw, and a missing MIME is not a failure of the file.
NSString *TGSettingsFileTextAnswer(NSDictionary *result) {
	if (![result isKindOfClass:NSDictionary.class])
		return @"";
	if ([result[@"@type"] isEqualToString:@"error"])
		return @"";
	return [result[@"text"] isKindOfClass:NSString.class] ? result[@"text"] : @"";
}

NSDictionary *TGSettingsFlattenFileRecord(NSDictionary *file) {
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
		NSMutableDictionary *info = [TGSettingsFlattenFileRecord(result) mutableCopy];
		NSString *remoteId = info[@"remoteId"];
		if (![remoteId isKindOfClass:NSString.class] || !remoteId.length){
			if (completion) completion(info);
			return;
		}
		// getFile answers with the remote id, not the remote record; the File
		// Info screen's "Remote ID" row is only worth showing if TDLib can
		// still resolve it, so ask and fold the answer back in.
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

- (void)fileDownloadedPrefixSize:(NSInteger)fileId
						  offset:(long long)offset
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

- (void)fileNameInfo:(NSString *)name
		  completion:(void (^)(NSDictionary *))completion {
	NSString *value = name ?: @"";
	[[TGClient shared] request:@{@"@type" : @"getFileMimeType", @"file_name" : value}
	   completion:^(NSDictionary *mimeAnswer){
		NSString *mime = TGSettingsFileTextAnswer(mimeAnswer);
		[[TGClient shared] request:@{@"@type" : @"getFileExtension", @"mime_type" : mime}
		   completion:^(NSDictionary *extensionAnswer){
			NSString *extension = TGSettingsFileTextAnswer(extensionAnswer);
			[[TGClient shared] request:@{@"@type" : @"cleanFileName", @"file_name" : value}
			   completion:^(NSDictionary *cleanAnswer){
				NSDictionary *info = @{
					@"mime"      : mime,
					@"extension" : extension,
					@"cleanName" : TGSettingsFileTextAnswer(cleanAnswer),
				};
				if (completion) completion(info);
			}];
		}];
	}];
}

- (void)suggestedFileNameForFile:(NSInteger)fileId
					   directory:(NSString *)directory
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
		if (completion) completion(TGSettingsFileTextAnswer(result));
	}];
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

#pragma mark - auto-download presets

static NSDictionary *TGFlattenAutoDownloadSettings(NSDictionary *settings) {
	if (![settings isKindOfClass:NSDictionary.class])
		return @{};
	return @{
		@"enabled"         : settings[@"is_auto_download_enabled"] ?: @NO,
		@"maxPhotoSize"    : settings[@"max_photo_file_size"] ?: @(0),
		@"maxVideoSize"    : settings[@"max_video_file_size"] ?: @(0),
		@"maxOtherSize"    : settings[@"max_other_file_size"] ?: @(0),
		@"preloadVideos"   : settings[@"preload_large_videos"] ?: @NO,
		@"preloadAudio"    : settings[@"preload_next_audio"] ?: @NO,
		@"lessDataForCalls" : settings[@"use_less_data_for_calls"] ?: @NO,
	};
}

- (void)autoDownloadSettingsPresetsWithCompletion:(void (^)(NSDictionary *))completion {
	[[TGClient shared] request:@{@"@type" : @"getAutoDownloadSettingsPresets"}
	   completion:^(NSDictionary *result){
		if (![result isKindOfClass:NSDictionary.class] ||
			[result[@"@type"] isEqualToString:@"error"]){
			if (completion) completion(nil);
			return;
		}
		NSDictionary *presets = @{
			@"low"    : TGFlattenAutoDownloadSettings(result[@"low"]),
			@"medium" : TGFlattenAutoDownloadSettings(result[@"medium"]),
			@"high"   : TGFlattenAutoDownloadSettings(result[@"high"]),
		};
		if (completion) completion(presets);
	}];
}

- (void)applyAutoDownloadPreset:(NSDictionary *)preset
					 forNetwork:(NSString *)network
					 completion:(void (^)(BOOL))completion {
	if (![preset isKindOfClass:NSDictionary.class]){
		if (completion) completion(NO);
		return;
	}
	NSString *networkType = @"networkTypeWiFi";
	if ([network isEqualToString:@"mobile"])
		networkType = @"networkTypeMobile";
	else if ([network isEqualToString:@"roaming"])
		networkType = @"networkTypeMobileRoaming";

	NSDictionary *settings = @{
		@"@type"                    : @"autoDownloadSettings",
		@"is_auto_download_enabled" : preset[@"enabled"] ?: @NO,
		@"max_photo_file_size"      : preset[@"maxPhotoSize"] ?: @(0),
		@"max_video_file_size"      : preset[@"maxVideoSize"] ?: @(0),
		@"max_other_file_size"      : preset[@"maxOtherSize"] ?: @(0),
		@"video_upload_bitrate"     : @(0),
		@"preload_large_videos"     : preset[@"preloadVideos"] ?: @NO,
		@"preload_next_audio"       : preset[@"preloadAudio"] ?: @NO,
		@"preload_stories"          : @NO,
		@"use_less_data_for_calls"  : preset[@"lessDataForCalls"] ?: @NO,
	};
	[[TGClient shared] request:@{
		@"@type"    : @"setAutoDownloadSettings",
		@"settings" : settings,
		@"type"     : @{@"@type" : networkType},
	} completion:^(NSDictionary *result){
		if (completion)
			completion(![result[@"@type"] isEqualToString:@"error"]);
	}];
}

@end
