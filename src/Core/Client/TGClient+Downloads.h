//
// TGClient+Downloads.h - the client surface for the download manager: cancelling, deleting, the download list.
//
#import "TGClient+Base.h"

@interface TGClient (Downloads)

/// Stops a download. `onlyIfPending` leaves one that has already started.
- (void)cancelDownloadOfFile:(NSInteger)fileId onlyIfPending:(BOOL)onlyIfPending;

/// Deletes the local copy; the file can be fetched again.
/// Puts a file in the download list their Download Manager shows.
/// The list. Entries carry "fileId", "name", "size", "paused" and "done".
@end
