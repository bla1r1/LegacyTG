#import "TGClient+Base.h"

@interface TGClient (StoriesLive)

/// Starts a live story. `rtmp` asks Telegram for an RTMP stream; without a
/// camera encoder this client still shows the server's stream key and the
/// live state. The answer carries "ok", "story" and, on failure, "error".
/// Joins the call behind a live story and returns Telegram's join payload.
/// This client has no camera to put into it; the payload and the server's
/// refusal are shown as they arrive.
/// Who is streaming: "kind", "id", "name", "isCurrentUser", "isSpeaking",
/// "isMuted" and "bio".
/// The chat's RTMP address: "url" and "streamKey".
/// Asks Telegram for a new stream key, invalidating the old one.
/// Senders messages may be posted in the live story as, with "needsPremium".
/// `sender` is a dictionary with "kind" ("user" or "chat") and "id".
/// "totalStarCount" and "donors": "kind", "id", "name", "stars", "isTop",
/// "isMe" and "isAnonymous".
/// Paid reactions are batched: add one, then commit when the undo window
/// ends, or remove every pending one when the user changes their mind.
@end
