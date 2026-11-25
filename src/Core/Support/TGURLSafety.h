//
// TGURLSafety.h - Allowlist check for external URLs opened from chat/UI.
//
#import <Foundation/Foundation.h>

/// Returns YES if `url` uses an allowed external scheme
/// (`http`, `https`, `tg`, `telegram`, `mailto`).
FOUNDATION_EXPORT BOOL TGIsSafeExternalURL(NSURL *url);

/// Convenience wrapper for string URLs.
FOUNDATION_EXPORT BOOL TGIsSafeExternalURLString(NSString *urlString);

/// Opens `url` via UIApplication only when `TGIsSafeExternalURL(url)` is YES.
/// Returns YES if the URL was accepted (and opened on iOS).
FOUNDATION_EXPORT BOOL TGOpenSafeExternalURL(NSURL *url);

/// Copies a sensitive string (verification key, phone number) to the system
/// pasteboard and clears it after `ttlSeconds` if unchanged.
FOUNDATION_EXPORT void TGCopySensitiveStringToPasteboard(NSString *value, NSTimeInterval ttlSeconds);
