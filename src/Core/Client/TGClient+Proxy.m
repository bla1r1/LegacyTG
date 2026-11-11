//
// TGClient+Proxy.m - the proxy list, which matters most where Telegram is
// blocked and this is the only client old enough to run on the phone.
//
// TDLib keeps the list itself and persists it in the database, so there is
// nothing to store here: this is the list, the four kinds of proxy it
// accepts, and which one is on.
//
#import "TGClientInternal.h"

@implementation TGClient (Proxy)

/// Changes a proxy in place rather than removing and re-adding it, which is
/// what the page used to do - and which lost its position in the list and
/// whether it was the one in use.
/// Whether a proxy can actually carry Telegram, which a ping does not say: a
/// handshake can answer while the proxy refuses to pass the data centre.
/// Off means direct, and there is no proxy id in it: TDLib disables whichever
/// one is on.
/// How long the handshake took, in seconds, or a negative number when it did
/// not answer. The one number worth showing beside a proxy row.
/// A t.me/proxy or tg://proxy link, which is how a proxy is nearly always
/// passed around. Returns NO when the link carries no server and port.
#pragma mark - web proxy carrier

@end

// vim:ft=objc
