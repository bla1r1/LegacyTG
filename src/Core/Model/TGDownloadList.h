//
// TGDownloadList.h - Settings > Downloads arranged as official's download
// list (ChatListUI ChatListSearchListPaneNode): "Downloading" with Pause All
// or Resume All, then "Recently Downloaded" newest first.
//
#import <Foundation/Foundation.h>

/// `downloads` are TGSettingsStore entries (fileId, name, size, paused, done,
/// addDate, completeDate); `counts` is TDLib's downloadedFileCounts
/// (active_count, paused_count, completed_count). Answers
/// @{downloading, downloaded (arrays), allPaused, hasCompleted (BOOL)}.
FOUNDATION_EXPORT NSDictionary *TGDownloadListModel(NSArray *downloads, NSDictionary *counts);
