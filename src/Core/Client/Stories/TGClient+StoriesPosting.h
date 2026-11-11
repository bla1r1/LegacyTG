#import "TGClient+Base.h"

@interface TGClient (StoriesPosting)

/// Telegram's answer for "may this chat post a story now?". The dictionary
/// carries "ok", "reason", "storyCount", "retryAfter" and "storyId" (the
/// live story that has to be deleted first, when that is the reason).
/// Chats this account may post stories on behalf of: "id", "title",
/// "photoFileId" and "isChannel".
/// Posts a photo or video story. `path` is a local JPEG/MP4; the controller
/// has already sized it to Telegram's 1080x1920 / 720x1280 contract.
/// `caption` may be empty. `privacy` is "everyone", "contacts",
/// "closeFriends" or "selected"; `userIds` is used by the last.
/// Edits a story's media and/or caption. A nil `path` keeps the current
/// media; a nil `caption` keeps the current caption.
/// The poster frame used for a video story, in seconds from the start.
/// Keeps the story on the profile after it expires, or takes it off.
/// Own-account stories only; Telegram refuses it for a chat's story.
/// The two business-only variants. A user account gets Telegram's refusal,
/// which is the answer the menu shows.
@end
