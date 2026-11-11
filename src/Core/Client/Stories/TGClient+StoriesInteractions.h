#import "TGClient+Base.h"

@interface TGClient (StoriesInteractions)

/// Interactions with an own-account story. `offset` is "" for the first page;
/// the answer carries "nextOffset".
/// Interactions with a story posted by a chat; requires an administrator
/// right in that chat.
/// Public messages and reposts of a story: "totalCount", "nextOffset" and
/// "forwards" rows carrying "kind", "title", "text" and a story when the
/// forward is itself a story.
/// Interaction and reaction graphs, each flattened to "lines" the list draws
/// as bars. A statisticalGraphAsync token is shown rather than followed: this
/// screen has nowhere to keep a graph that arrives after it closed.
/// The report is two steps: the first call with an empty option asks Telegram
/// which options exist; the chosen option and optional text are sent second.
@end
