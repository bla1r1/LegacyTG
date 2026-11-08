//
// TGQRCodeLink.h - what a scanned QR payload means.
//
// A QR from another Telegram client is either a login token
// (tg://login?token=…) or a link to a chat (t.me/name, tg://resolve?domain=).
// Keeping the parsing here rather than in the view controller lets the host
// tests cover the shapes without a camera session.
//
#ifndef TGQRCODELINK_H
#define TGQRCODELINK_H

#import <Foundation/Foundation.h>

/// The token of a `tg://login?token=…` payload, or nil for any other link.
static inline NSString *TGQRCodeAuthToken(NSString *text) {
    if (![text isKindOfClass:[NSString class]])
        return nil;
    NSRange marker = [text rangeOfString:@"tg://login?token="];
    if (marker.location == NSNotFound)
        return nil;
    NSString *rest = [text substringFromIndex:NSMaxRange(marker)];
    NSRange stop = [rest rangeOfCharacterFromSet:
            [NSCharacterSet characterSetWithCharactersInString:@"&#"]];
    NSString *token = stop.location == NSNotFound ? rest
            : [rest substringToIndex:stop.location];
    return token.length ? token : nil;
}

static inline BOOL TGQRCodeIsAuthTransferLink(NSString *text) {
    return TGQRCodeAuthToken(text) != nil;
}

/// The first path component after a t.me/telegram.me/telegram.dog host, or
/// the `domain=` query value of a tg://resolve link. Nil when the payload is
/// neither. A post link (`t.me/name/123`) still names the chat, not the post.
static inline NSString *TGQRCodeUsername(NSString *text) {
    if (![text isKindOfClass:[NSString class]] || !text.length)
        return nil;

    NSArray *hosts = @[@"t.me/", @"telegram.me/", @"telegram.dog/"];
    for (NSString *host in hosts) {
        NSRange marker = [text rangeOfString:host];
        if (marker.location == NSNotFound)
            continue;
        NSString *rest = [text substringFromIndex:NSMaxRange(marker)];
        NSRange stop = [rest rangeOfCharacterFromSet:
                [NSCharacterSet characterSetWithCharactersInString:@"/?#"]];
        NSString *name = stop.location == NSNotFound ? rest
                : [rest substringToIndex:stop.location];
        return name.length ? name : nil;
    }

    NSRange marker = [text rangeOfString:@"domain="];
    if (marker.location != NSNotFound) {
        NSString *rest = [text substringFromIndex:NSMaxRange(marker)];
        NSRange stop = [rest rangeOfCharacterFromSet:
                [NSCharacterSet characterSetWithCharactersInString:@"&#"]];
        NSString *name = stop.location == NSNotFound ? rest
                : [rest substringToIndex:stop.location];
        return name.length ? name : nil;
    }
    return nil;
}

#endif // TGQRCODELINK_H
