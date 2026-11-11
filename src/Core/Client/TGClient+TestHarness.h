//
// TGClient+TestHarness.h - td_api's test* calls. They exist to exercise the
// schema, not a user action, so their screen is Debug → TDLib Test Harness.
//
// Each method sends the real request and hands back what Telegram answered.
// A build whose server does not expose a test function gets its refusal; the
// harness prints it instead of drawing a made-up result.
//
#import "TGClient+Base.h"

@interface TGClient (TestHarness)

/// `base64` is what TDLib's JSON wants for a byte vector.
/// Telegram answers the error object this call names. That is a successful
/// call returning an error, not a refusal by Telegram, so it comes back as
/// code and message with no `error`.
/// The update Telegram returns. The harness names its type; nothing in the
/// app acts on it.
@end

// vim:ft=objc
