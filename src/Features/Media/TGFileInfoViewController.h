//
// TGFileInfoViewController - the file record behind a picture or document.
//
#import <Foundation/Foundation.h>
#import "TGLocalization.h"

static inline NSString *TGFileInfoBytesText(long long bytes) {
	if (bytes <= 0)
		return @"0 B";
	if (bytes < 1024)
		return [NSString stringWithFormat:@"%lld B", bytes];
	if (bytes < 1024 * 1024)
		return [NSString stringWithFormat:@"%.0f KB", bytes / 1024.0];
	if (bytes < 1024LL * 1024 * 1024)
		return [NSString stringWithFormat:@"%.1f MB", bytes / (1024.0 * 1024.0)];
	return [NSString stringWithFormat:@"%.2f GB",
			bytes / (1024.0 * 1024.0 * 1024.0)];
}

/// The record's rows as title/detail pairs, in the order the sheet shows them.
static inline NSArray *TGFileInfoDetailModels(NSDictionary *info,
		NSDictionary *names, NSString *suggestedName, long long prefixBytes,
		BOOL loaded) {
	NSDictionary *record = info ?: @{};
	NSDictionary *nameInfo = names ?: @{};
	NSString *name = suggestedName;
	if (!name.length)
		name = [record[@"localPath"] lastPathComponent];
	if (!name.length)
		name = loaded ? TGLocalized(@"Unavailable") : TGLocalized(@"Loading...");

	NSString *extension = nameInfo[@"extension"] ?: @"";
	NSString *mime = nameInfo[@"mime"] ?: @"";
	NSString *type = (extension.length || mime.length)
			? [NSString stringWithFormat:@"%@%@%@", extension,
					(extension.length && mime.length) ? @" - " : @"", mime]
			: TGLocalized(@"Unknown");
	long long size = [record[@"size"] longLongValue];
	if (size <= 0)
		size = [record[@"expectedSize"] longLongValue];
	long long expected = [record[@"expectedSize"] longLongValue];
	NSString *localPath = record[@"localPath"];
	if (!localPath.length)
		localPath = [record[@"completed"] boolValue]
				? TGLocalized(@"Downloaded") : TGLocalized(@"Not downloaded");
	NSString *remote = record[@"remoteId"];
	if (!remote.length)
		remote = TGLocalized(@"None");
	else if ([record[@"remoteResolved"] boolValue])
		remote = [NSString stringWithFormat:TGLocalized(@"%@ (available)"),
				remote];
	else
		remote = [NSString stringWithFormat:TGLocalized(@"%@ (unavailable)"),
				remote];

	return @[
		@{@"title" : TGLocalized(@"Name"), @"detail" : name},
		@{@"title" : TGLocalized(@"Type"), @"detail" : type},
		@{@"title" : TGLocalized(@"Clean Name"),
		  @"detail" : nameInfo[@"cleanName"] ?: TGLocalized(@"Unknown")},
		@{@"title" : TGLocalized(@"Size"), @"detail" : TGFileInfoBytesText(size)},
		@{@"title" : TGLocalized(@"Expected Size"),
		  @"detail" : TGFileInfoBytesText(expected)},
		@{@"title" : TGLocalized(@"Downloaded"),
		  @"detail" : [NSString stringWithFormat:@"%@ of %@",
				  TGFileInfoBytesText(prefixBytes), TGFileInfoBytesText(size)]},
		@{@"title" : TGLocalized(@"Local Path"), @"detail" : localPath},
		@{@"title" : TGLocalized(@"Remote ID"), @"detail" : remote},
	];
}

/// Share and Save need the bytes on this device; Copy is always there and
/// Delete only goes when there is something to delete.
static inline NSArray *TGFileInfoActionTitles(BOOL downloaded,
		NSString *pathExtension) {
	NSMutableArray *titles = [NSMutableArray array];
	if (downloaded){
		[titles addObject:TGLocalized(@"Share")];
		NSString *extension = [pathExtension lowercaseString];
		if ([@[@"jpg", @"jpeg", @"png", @"webp"] containsObject:extension] ||
			[@[@"mp4", @"mov", @"m4v"] containsObject:extension])
			[titles addObject:TGLocalized(@"Save to Photos")];
	}
	[titles addObject:TGLocalized(@"Copy")];
	if (downloaded)
		[titles addObject:TGLocalized(@"Delete")];
	return titles;
}

#ifndef TGROW_MODELS_ONLY
#import <UIKit/UIKit.h>
#import "TGRowsViewController.h"

@interface TGFileInfoViewController : TGRowsViewController

/// Set before the view loads. A file id of 0 shows the "unavailable" state.
@property (nonatomic, assign) NSInteger fileId;

/// Opens the sheet over whatever is on screen. The media viewer and the
/// download list have no navigation controller of their own to push onto.
+ (void)presentForFile:(NSInteger)fileId fromView:(UIView *)host;

@end
#endif

// vim:ft=objc
