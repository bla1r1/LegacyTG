//
// TGClient+Proxy.h - the client surface for proxies.
//
#import "TGClient+Base.h"

@interface TGClient (Proxy)

/// Every proxy TDLib has been told about. Entries carry "id", "server",
/// "port", "kind" (socks5/http/mtproto/web), "enabled" and "lastUsed".
/// Adds one and, with `enable`, switches to it at once. The completion gets
/// its id, or 0 when the server or port made no sense.
/// Adds a proxy out of a t.me/proxy or tg://proxy link, which is how one is
/// nearly always passed around. NO when the link carries no server and port.
/// Changes one in place, keeping its position and whether it is in use -
/// which removing and re-adding did not.
/// Whether a proxy can carry Telegram, which a ping does not say.
/// Back to a direct connection; there is no id in this one.
/// How long the handshake takes, in seconds, or a negative number when the
/// proxy does not answer.
#pragma mark - web proxy carrier

/// A text message a web proxy page passed to postMessage of the bridge
/// object. TDLib must see every one, in order, before it can run the page.
/// `carrierId` is the id from updateWebProxyCarrierOpened.
/// The same for a binary message, base64 as TDLib spells bytes.
/// reportWebProxyCarrierError. `kind` is "unsupported", "paused",
/// "terminated" or "refused"; "loadFailed" also takes a sentence.
@end
