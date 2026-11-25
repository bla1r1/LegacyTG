//
// TGURLSafety.m - Allowlist check for external URLs opened from chat/UI.
//
#import "TGURLSafety.h"

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

BOOL TGIsSafeExternalURL(NSURL *url) {
	if (![url isKindOfClass:[NSURL class]])
		return NO;
	NSString *scheme = url.scheme.lowercaseString;
	if (!scheme.length)
		return NO;
	return [scheme isEqualToString:@"https"] ||
		   [scheme isEqualToString:@"http"] ||
		   [scheme isEqualToString:@"tg"] ||
		   [scheme isEqualToString:@"telegram"] ||
		   [scheme isEqualToString:@"mailto"];
}

BOOL TGIsSafeExternalURLString(NSString *urlString) {
	if (![urlString isKindOfClass:[NSString class]] || !urlString.length)
		return NO;
	NSURL *url = [NSURL URLWithString:urlString];
	return TGIsSafeExternalURL(url);
}

BOOL TGOpenSafeExternalURL(NSURL *url) {
	if (!TGIsSafeExternalURL(url))
		return NO;
#if TARGET_OS_IPHONE
	return [[UIApplication sharedApplication] openURL:url];
#else
	return YES;
#endif
}

void TGCopySensitiveStringToPasteboard(NSString *value, NSTimeInterval ttlSeconds) {
#if TARGET_OS_IPHONE
	NSString *copied = [value isKindOfClass:[NSString class]] ? [value copy] : @"";
	[UIPasteboard generalPasteboard].string = copied;
	if (copied.length && ttlSeconds > 0) {
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(ttlSeconds * NSEC_PER_SEC)),
				dispatch_get_main_queue(), ^{
			UIPasteboard *pb = [UIPasteboard generalPasteboard];
			if ([pb.string isEqualToString:copied])
				pb.string = @"";
		});
	}
#else
	(void)value;
	(void)ttlSeconds;
#endif
}
