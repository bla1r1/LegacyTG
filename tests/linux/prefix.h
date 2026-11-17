// tests/linux/prefix.h - included before every file of the Linux host run
// (scripts/linux_test.py). On a Mac, AppKit brings QuartzCore in; GNUstep's
// AppKit does not, so the layer stand-in comes in here, with the Apple
// spellings GNUstep lacks (tests/linux/LinuxCompat.m implements them).
#ifdef __OBJC__
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
// Apple's FOUNDATION_EXPORT is extern "C" in C++, GNUstep's plain extern:
// the test mains are Objective-C++, so the app's C functions would be looked
// up under C++ names.
#undef FOUNDATION_EXPORT
#undef FOUNDATION_EXTERN
#ifdef __cplusplus
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#define FOUNDATION_EXTERN FOUNDATION_EXPORT
#import <AppKit/AppKit.h>
#import <CoreText/CoreText.h>
@interface NSAttributedString (TGLinuxCompat)
- (NSRect)boundingRectWithSize:(NSSize)size options:(NSUInteger)options
					   context:(id)context;
@end
@interface NSString (TGLinuxCompat)
- (NSRect)boundingRectWithSize:(NSSize)size options:(NSUInteger)options
					attributes:(NSDictionary *)attributes context:(id)context;
@end
// Opal's Core Text has no cascade list; the app already checks the symbol
// before calling it, as for iOS 6, so a weak declaration reads as absent.
#ifdef __cplusplus
extern "C"
#endif
CFArrayRef CTFontCopyDefaultCascadeListForLanguages(CTFontRef font, CFArrayRef languages)
		__attribute__((weak));
@interface NSData (TGLinuxCompat)
- (instancetype)initWithBase64Encoding:(NSString *)string;
@end
@interface NSData (TGLinuxCompatEncode)
- (NSString *)base64Encoding;
@end
@interface NSTextAttachment (TGLinuxCompat)
@property (nonatomic, strong) NSImage *image;
@property (nonatomic, assign) NSRect bounds;
@end
#ifndef typeof
#define typeof __typeof__
#endif
#if !defined(NSAttributedStringEnumerationReverse)
@interface NSAttributedString (TGLinuxCompatEnumerate)
- (void)enumerateAttribute:(NSString *)name inRange:(NSRange)range options:(NSUInteger)options
				usingBlock:(void (^)(id value, NSRange range, BOOL *stop))block;
- (void)enumerateAttributesInRange:(NSRange)range options:(NSUInteger)options
						usingBlock:(void (^)(NSDictionary *attrs, NSRange range, BOOL *stop))block;
@end
#endif
@interface NSURL (TGLinuxCompat)
- (BOOL)setResourceValue:(id)value forKey:(NSString *)key error:(NSError **)error;
@end
#endif
