//
// TGStorySave.h - which file a story saves to the camera roll.
//
// A video story's `photoId` is its poster frame, so the old "photoId ?:
// thumbPhotoId" rule saved the thumbnail and never the video. The kind is
// decided first, then the matching file id is returned.
//
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, TGStorySaveKind) {
	TGStorySaveKindNone = 0,
	TGStorySaveKindPhoto,
	TGStorySaveKindVideo,
};

static inline TGStorySaveKind TGStorySaveKindForStory(NSDictionary *story,
													  NSNumber **fileIdOut) {
	NSNumber *videoId = [story[@"videoId"] isKindOfClass:NSNumber.class]
			? story[@"videoId"] : nil;
	if (videoId.integerValue > 0){
		if (fileIdOut)
			*fileIdOut = videoId;
		return TGStorySaveKindVideo;
	}
	NSNumber *photoId = [story[@"photoId"] isKindOfClass:NSNumber.class]
			? story[@"photoId"] : nil;
	if (photoId.integerValue <= 0 &&
		[story[@"thumbPhotoId"] isKindOfClass:NSNumber.class])
		photoId = story[@"thumbPhotoId"];
	if (photoId.integerValue > 0){
		if (fileIdOut)
			*fileIdOut = photoId;
		return TGStorySaveKindPhoto;
	}
	return TGStorySaveKindNone;
}
