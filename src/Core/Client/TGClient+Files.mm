#import "TGClientInternal.h"
#import "TGMediaSupport.h"
#import "TGBase64.h"


/// One pending generation, keyed by its original path. File-scope so the
/// reset on account switch (see -removeAllPendingGenerations) can reach it
/// before the preliminary-upload half of this file declares it again.
static NSMutableDictionary *gPendingGenerations;

// Note: this file is shared with the host test suite (tests/Makefile compiles
// it into TGClientTests); nothing device-only lives here.

#pragma mark - files

NSString *const TGFileDownloadedNotification = @"TGFileDownloadedNotification";

@implementation TGClient (Files)

- (void)removeAllPendingGenerations {
	[gPendingGenerations removeAllObjects];
}

#pragma mark - network and downloads

/// TDLib only offers presets through getAutoDownloadSettingsPresets; what is
/// actually in force is not readable back, so the app keeps the answer it
/// wrote. Off over mobile by default: this is a 3G phone with a small disk.
#pragma mark - storage

/// Computes storage breakdown by file category and returns total bytes.
#pragma mark - file records, names and bytes

/// A text answer from getFileMimeType, getFileExtension, cleanFileName and
/// getSuggestedFileName. Errors are an empty string: the File Info screen
/// still has rows to draw, and a missing MIME is not a failure of the file.
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

#pragma mark - preliminary upload and generation

/// One pending generation, keyed by its original path. Every field is filled
/// by whichever answer arrives first, and finishGenerationIfReady is what
/// makes the completion run exactly once after both have.
static const NSUInteger TGGenerationChunk = 32 * 1024;

static NSError *TGGenerationError(NSString *reason) {
	return [NSError errorWithDomain:@"LegacyTG.FileGeneration" code:400
						   userInfo:@{NSLocalizedDescriptionKey : reason ?: @"Generation failed"}];
}

/// Runs on the main queue (handleUpdateBatch), like every other screen state.
static void TGGenerationProgress(NSMutableDictionary *pending, NSInteger fileId,
								 float progress, NSString *stage) {
	void (^block)(NSInteger, float, NSString *) = pending[@"progress"];
	if (block)
		block(fileId, progress, stage ?: @"");
}

- (void)finishGenerationIfReady:(NSMutableDictionary *)pending {
	if (![pending[@"generated"] boolValue] || [pending[@"finished"] boolValue])
		return;
	NSInteger fileId = [pending[@"fileId"] integerValue];
	if (fileId <= 0)
		return;   // the preliminary-upload answer still owns the id
	pending[@"finished"] = @YES;

	NSString *path = pending[@"destination"] ?: pending[@"original"];
	TGGenerationProgress(pending, fileId, 1.0f, @"generated");
	void (^done)(NSInteger, NSString *, NSError *) = pending[@"completion"];
	NSString *original = pending[@"original"];
	if (original)
		[gPendingGenerations removeObjectForKey:original];
	if (done)
		done(fileId, path ?: @"", nil);
}

- (void)runGenerationIfReady:(NSMutableDictionary *)pending {
	if ([pending[@"started"] boolValue])
		return;
	id generation = pending[@"generationId"];
	if (![generation isKindOfClass:NSNumber.class] || [generation longLongValue] == 0)
		return;
	pending[@"started"] = @YES;

	long long generationId = [generation longLongValue];
	NSData *data = pending[@"data"] ?: [NSData data];
	long long total = (long long)data.length;
	NSInteger fileId = [pending[@"fileId"] integerValue];

	// Tell TDLib the size before the first part, then one progress report per
	// part as the bytes land. A generated thumbnail is a few KB; a text file
	// this app writes is small, but the same code makes a larger one without
	// holding one giant request in the outbox.
	for (long long offset = 0; offset < total; offset += (long long)TGGenerationChunk){
		NSUInteger length = (NSUInteger)MIN((long long)TGGenerationChunk, total - offset);
		NSData *part = [data subdataWithRange:NSMakeRange((NSUInteger)offset, length)];
		[self send:@{
			@"@type"             : @"setFileGenerationProgress",
			@"generation_id"     : @(generationId),
			@"expected_size"     : @(total),
			@"local_prefix_size" : @(offset),
		}];
		[self send:@{
			@"@type"         : @"writeGeneratedFilePart",
			@"generation_id" : @(generationId),
			@"offset"        : @(offset),
			@"data"          : TGBase64Encode(part),
		}];
		if (total > 0)
			TGGenerationProgress(pending, fileId,
					(float)((offset + (long long)length) / (double)total), @"generating");
	}
	if (total == 0)
		[self send:@{
			@"@type"             : @"setFileGenerationProgress",
			@"generation_id"     : @(generationId),
			@"expected_size"     : @(0),
			@"local_prefix_size" : @(0),
		}];

	[self send:@{
		@"@type"         : @"finishFileGeneration",
		@"generation_id" : @(generationId),
		@"error"         : [NSNull null],
	}];
	pending[@"generated"] = @YES;
	[self finishGenerationIfReady:pending];
}

- (void)handleFileGenerationStart:(NSDictionary *)update {
	NSString *original = update[@"original_path"];
	if (![original isKindOfClass:NSString.class] || !original.length)
		return;
	NSMutableDictionary *pending = gPendingGenerations[original];
	if (!pending)
		return;
	pending[@"generationId"] = update[@"generation_id"] ?: @(0);
	pending[@"destination"] = update[@"destination_path"] ?: @"";
	[self runGenerationIfReady:pending];
}

- (void)handleFileGenerationStop:(NSDictionary *)update {
	NSNumber *generationId = update[@"generation_id"];
	if (![generationId isKindOfClass:NSNumber.class])
		return;
	NSMutableDictionary *found = nil;
	for (NSString *key in gPendingGenerations.allKeys){
		NSMutableDictionary *pending = gPendingGenerations[key];
		if ([pending[@"generationId"] isEqual:generationId]){
			found = pending;
			break;
		}
	}
	if (!found)
		return;
	// A stop that follows our finishFileGeneration is the normal end of the
	// generation, not a failure: the upload still owes a file id, so the
	// pending record waits for that answer.
	if ([found[@"generated"] boolValue])
		return;
	NSString *original = found[@"original"];
	if (original)
		[gPendingGenerations removeObjectForKey:original];
	if (![found[@"finished"] boolValue]){
		found[@"finished"] = @YES;
		void (^done)(NSInteger, NSString *, NSError *) = found[@"completion"];
		if (done)
			done(0, @"", TGGenerationError(@"TDLib stopped the generation."));
	}
}

- (void)handleFileUploadProgress:(NSInteger)fileId file:(NSDictionary *)file {
	if (fileId <= 0)
		return;
	NSMutableDictionary *found = nil;
	for (NSString *key in gPendingGenerations.allKeys){
		NSMutableDictionary *pending = gPendingGenerations[key];
		if ([pending[@"fileId"] integerValue] == fileId){
			found = pending;
			break;
		}
	}
	if (!found)
		return;
	double expected = [file[@"expected_size"] doubleValue];
	if (expected <= 0)
		expected = [found[@"data"] length];
	double uploaded = [file[@"remote"][@"uploaded_size"] doubleValue];
	float fraction = expected > 0 ? (float)(uploaded / expected) : 0;
	TGGenerationProgress(found, fileId, fraction, @"uploading");
}

- (void)generateTextFileNamed:(NSString *)name
					 contents:(NSString *)contents
					 progress:(void (^)(NSInteger, float, NSString *))progress
				   completion:(void (^)(NSInteger, NSString *, NSError *))completion {
	NSString *base = name.lastPathComponent ?: @"legacy-note.txt";
	if (!base.length)
		base = @"legacy-note.txt";
	NSString *extension = base.pathExtension.length ? base.pathExtension : @"txt";
	NSString *unique = [[NSUUID UUID] UUIDString] ?: @"0";
	NSString *original = [[NSTemporaryDirectory()
			stringByAppendingPathComponent:[@"legacy-gen-" stringByAppendingString:unique]]
			stringByAppendingPathExtension:extension];

	NSData *data = [contents ?: @"" dataUsingEncoding:NSUTF8StringEncoding] ?: [NSData data];
	NSMutableDictionary *pending = [@{
		@"original"   : original,
		@"data"       : data,
		@"fileId"     : @(0),
		@"generationId" : @(0),
		@"started"    : @NO,
		@"generated"  : @NO,
		@"finished"   : @NO,
	} mutableCopy];
	if (progress) pending[@"progress"] = [progress copy];
	if (completion) pending[@"completion"] = [completion copy];
	if (!gPendingGenerations)
		gPendingGenerations = [NSMutableDictionary dictionary];
	gPendingGenerations[original] = pending;

	TGGenerationProgress(pending, 0, 0, @"preparing");
	__weak __typeof__(self) weakSelf = self;
	[self request:@{
		@"@type" : @"preliminaryUploadFile",
		@"file"  : @{
			@"@type"         : @"inputFileGenerated",
			@"original_path" : original,
			@"conversion"    : @"legacy-text",
			@"expected_size" : @(data.length),
		},
		@"file_type" : @{@"@type" : @"fileTypeDocument"},
		@"priority"  : @(1),
	} completion:^(NSDictionary *result){
		TGClient *me = weakSelf;
		if (!me) return;
		// A cancel may have retired this record while the answer was on its
		// way; a late answer must not move the screen back to "uploading".
		if (gPendingGenerations[original] != pending ||
			[pending[@"finished"] boolValue])
			return;
		if (![result isKindOfClass:NSDictionary.class] ||
			[result[@"@type"] isEqualToString:@"error"]){
			[gPendingGenerations removeObjectForKey:original];
			if (![pending[@"finished"] boolValue]){
				pending[@"finished"] = @YES;
				void (^done)(NSInteger, NSString *, NSError *) = pending[@"completion"];
				if (done)
					done(0, @"", TGGenerationError(
							result[@"message"] ?: @"An error occurred."));
			}
			return;
		}
		NSInteger fileId = [result[@"id"] integerValue];
		pending[@"fileId"] = @(fileId);
		TGGenerationProgress(pending, fileId, 0, @"uploading");
		[me finishGenerationIfReady:pending];
	}];
}

- (void)cancelPreliminaryUploadOfFile:(NSInteger)fileId {
	// A file id of 0 means the generation is still in its preparing step and
	// the upload answer has not named one yet. There is at most one such
	// generation per screen, so cancel it rather than leave its completion
	// waiting to fire after the user has walked away.
	if (fileId <= 0){
		NSMutableDictionary *pending = nil;
		for (NSString *key in gPendingGenerations.allKeys){
			NSMutableDictionary *candidate = gPendingGenerations[key];
			if ([candidate[@"fileId"] integerValue] == 0 &&
				![candidate[@"finished"] boolValue]){
				pending = candidate;
				break;
			}
		}
		if (!pending)
			return;
		NSString *original = pending[@"original"];
		if (original)
			[gPendingGenerations removeObjectForKey:original];
		NSNumber *generationId = pending[@"generationId"];
		if ([generationId longLongValue] && ![pending[@"generated"] boolValue]){
			[self send:@{
				@"@type"         : @"finishFileGeneration",
				@"generation_id" : generationId,
				@"error"         : @{@"@type" : @"error", @"code" : @(400),
									 @"message" : @"Cancelled"},
			}];
		}
		if (![pending[@"finished"] boolValue]){
			pending[@"finished"] = @YES;
			void (^done)(NSInteger, NSString *, NSError *) = pending[@"completion"];
			if (done)
				done(0, @"", TGGenerationError(@"Upload cancelled."));
		}
		return;
	}

	[self send:@{@"@type" : @"cancelPreliminaryUploadFile",
				 @"file_id" : @(fileId)}];

	NSMutableDictionary *found = nil;
	for (NSString *key in gPendingGenerations.allKeys){
		NSMutableDictionary *pending = gPendingGenerations[key];
		if ([pending[@"fileId"] integerValue] == fileId){
			found = pending;
			break;
		}
	}
	if (!found)
		return;

	NSString *original = found[@"original"];
	if (original)
		[gPendingGenerations removeObjectForKey:original];
	// A generation in flight has to be told to stop too; cancelling only the
	// upload leaves TDLib waiting for the remaining parts.
	NSNumber *generationId = found[@"generationId"];
	if ([generationId longLongValue] && ![found[@"generated"] boolValue]){
		[self send:@{
			@"@type"         : @"finishFileGeneration",
			@"generation_id" : generationId,
			@"error"         : @{@"@type" : @"error", @"code" : @(400),
								 @"message" : @"Cancelled"},
		}];
	}
	if (![found[@"finished"] boolValue]){
		found[@"finished"] = @YES;
		void (^done)(NSInteger, NSString *, NSError *) = found[@"completion"];
		if (done)
			done(fileId, @"", TGGenerationError(@"Upload cancelled."));
	}
}

#pragma mark - auto-download presets

@end
