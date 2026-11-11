//
// TGClient+ProfileAudio.m - the list, its order, and the add/remove calls.
//
#import "TGClient+ProfileAudio.h"
#import "TGClientInternal.h"

/// One audio object flattened for a row. The player needs the file id and a
/// title; the row shows the performer and the length as its second line.
NSDictionary *TGProfileAudioRow(NSDictionary *audio) {
	if (![audio isKindOfClass:NSDictionary.class])
		return nil;
	NSNumber *fileId = audio[@"audio"][@"id"];
	if (![fileId isKindOfClass:NSNumber.class])
		return nil;
	NSNumber *coverId = audio[@"album_cover_thumbnail"][@"file"][@"id"];
	return @{
		@"fileId"       : fileId,
		@"title"        : audio[@"title"] ?: @"",
		@"performer"    : audio[@"performer"] ?: @"",
		@"duration"     : audio[@"duration"] ?: @(0),
		@"fileName"     : audio[@"file_name"] ?: @"",
		@"mimeType"     : audio[@"mime_type"] ?: @"",
		@"albumCoverId" : [coverId isKindOfClass:NSNumber.class]
				? coverId : (id)[NSNull null],
	};
}

@implementation TGClient (ProfileAudio)

@end
