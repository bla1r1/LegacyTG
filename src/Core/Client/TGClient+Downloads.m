//
// TGClient+Downloads.m - the download manager, and the two things a download
// could not do: stop, and go away.
//
// Downloading worked from the first day (TGClient+Files). What had no request
// at all was cancelling one, deleting the file afterwards, and the list
// Telegram keeps of everything this account has pulled down.
//
#import "TGClientInternal.h"

@implementation TGClient (Downloads)

/// Stops a download. `onlyIfPending` leaves one that has already started
/// alone, which is what a list sweep wants; a user's Cancel does not.
- (void)cancelDownloadOfFile:(NSInteger)fileId onlyIfPending:(BOOL)onlyIfPending {
	[self send:@{
		@"@type"           : @"cancelDownloadFile",
		@"file_id"         : @(fileId),
		@"only_if_pending" : @(onlyIfPending),
	}];
	// The waiter records in +Files outlive the request otherwise, and every
	// caller of downloadFile: would sit there until the watchdog fired.
	[self releaseFileWaiters:fileId];
}

/// Deletes the local copy. The file stays on Telegram and can be fetched
/// again; this is what frees the disk.
/// Puts a file in the download list, which is what their Download Manager
/// shows. A file pulled down by downloadFile: alone never appears there.
/// The download list. Entries carry "fileId", "name", "size", "paused" and
/// "done"; `activeOnly` is the "in progress" tab of their manager.
/// Out of the list. `deleteFromCache` also frees the disk, which is the only
/// version of this worth offering on a phone with 8 GB in it.
@end

// vim:ft=objc
