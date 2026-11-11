//
// TGClient+ProfileAudio - the music a profile puts above its photos.
//
#import "TGClient+Base.h"

@interface TGClient (ProfileAudio)

/// One page of a user's profile audio. Each entry: "fileId", "title",
/// "performer", "duration", "fileName", "mimeType" and "albumCoverId" (or
/// NSNull). `total` is what Telegram counts for the whole list.
/// Adds a local audio file. TDLib uploads it and puts it at the beginning of
/// the list, which is where Telegram shows the newest.
/// Moves `fileId` after `afterFileId`; 0 moves it to the beginning.
/// Telegram answers OK when the file is in the list and a 404 otherwise, so
/// both are a real answer and not a failure. `error` is set only for the
/// latter, with the server's wording.
@end
