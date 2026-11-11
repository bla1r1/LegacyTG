#import "TGClient+Base.h"

@interface TGClient (StoriesViewer)

/// Tells TDLib the story is open, so views count and read state moves.
/// Tells TDLib the viewer closed. Sent when leaving a story, whatever moved
/// the user away from it.
/// Reactions Telegram offers for stories: "emojis" (top first), "recent",
/// "popular", "allowCustom" and "unavailable" (Telegram's reason, or nil).
/// Sets a reaction on a story. `emoji` nil removes the current one; custom
/// emoji reactions are sent as "custom:<id>" so the picker has one string
/// to carry. Unsupported for live stories.
@end
