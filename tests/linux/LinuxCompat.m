// tests/linux/LinuxCompat.m - Apple API the app calls that GNUstep spells
// differently or lacks, for the Linux host run only. Each mirrors Apple's
// documented behaviour; none fakes a result a test asserts on.
#import <AppKit/AppKit.h>

@implementation NSData (TGLinuxCompat)
- (instancetype)initWithBase64Encoding:(NSString *)string {
	return [self initWithBase64EncodedString:string
									 options:NSDataBase64DecodingIgnoreUnknownCharacters];
}
@end

@implementation NSURL (TGLinuxCompat)
// Excluding a file from backup has no meaning off iOS.
- (BOOL)setResourceValue:(id)value forKey:(NSString *)key error:(NSError **)error {
	return YES;
}
@end

@implementation NSAttributedString (TGLinuxCompat)
- (NSRect)boundingRectWithSize:(NSSize)size options:(NSUInteger)options
					   context:(id)context {
	return [self boundingRectWithSize:size options:(NSStringDrawingOptions)options];
}
@end

@implementation NSString (TGLinuxCompat)
- (NSRect)boundingRectWithSize:(NSSize)size options:(NSUInteger)options
					attributes:(NSDictionary *)attributes context:(id)context {
	return [self boundingRectWithSize:size options:(NSStringDrawingOptions)options attributes:attributes];
}
@end

#pragma mark - Security (see tests/linux/Security/Security.h)

#import <Security/Security.h>

const CFStringRef kSecClass = (__bridge CFStringRef)@"class";
const CFStringRef kSecClassGenericPassword = (__bridge CFStringRef)@"genp";
const CFStringRef kSecAttrService = (__bridge CFStringRef)@"svce";
const CFStringRef kSecAttrAccount = (__bridge CFStringRef)@"acct";
const CFStringRef kSecReturnData = (__bridge CFStringRef)@"r_Data";
const CFStringRef kSecMatchLimit = (__bridge CFStringRef)@"m_Limit";
const CFStringRef kSecMatchLimitOne = (__bridge CFStringRef)@"m_LimitOne";
const CFStringRef kSecValueData = (__bridge CFStringRef)@"v_Data";
const CFStringRef kSecAttrAccessible = (__bridge CFStringRef)@"pdmn";
const CFStringRef kSecAttrAccessibleAfterFirstUnlock = (__bridge CFStringRef)@"ck";
const CFStringRef kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly = (__bridge CFStringRef)@"cku";

static NSMutableDictionary *TGLinuxKeychain(void) {
	static NSMutableDictionary *items;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ items = [NSMutableDictionary dictionary]; });
	return items;
}

static NSString *TGLinuxKeychainKey(NSDictionary *query) {
	return [NSString stringWithFormat:@"%@|%@", query[(__bridge id)kSecAttrService] ?: @"",
			query[(__bridge id)kSecAttrAccount] ?: @""];
}

OSStatus SecItemAdd(CFDictionaryRef attributes, CFTypeRef *result) {
	NSDictionary *a = (__bridge NSDictionary *)attributes;
	NSString *key = TGLinuxKeychainKey(a);
	@synchronized (TGLinuxKeychain()) {
		if (TGLinuxKeychain()[key])
			return errSecDuplicateItem;
		TGLinuxKeychain()[key] = [a[(__bridge id)kSecValueData] copy] ?: [NSData data];
	}
	return errSecSuccess;
}

OSStatus SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) {
	NSData *data;
	@synchronized (TGLinuxKeychain()) {
		data = TGLinuxKeychain()[TGLinuxKeychainKey((__bridge NSDictionary *)query)];
	}
	if (!data)
		return errSecItemNotFound;
	if (result)
		*result = (__bridge_retained CFTypeRef)[data copy];
	return errSecSuccess;
}

OSStatus SecItemUpdate(CFDictionaryRef query, CFDictionaryRef attributes) {
	NSString *key = TGLinuxKeychainKey((__bridge NSDictionary *)query);
	@synchronized (TGLinuxKeychain()) {
		if (!TGLinuxKeychain()[key])
			return errSecItemNotFound;
		TGLinuxKeychain()[key] = [((__bridge NSDictionary *)attributes)[(__bridge id)kSecValueData] copy]
				?: [NSData data];
	}
	return errSecSuccess;
}

OSStatus SecItemDelete(CFDictionaryRef query) {
	NSString *key = TGLinuxKeychainKey((__bridge NSDictionary *)query);
	@synchronized (TGLinuxKeychain()) {
		if (!TGLinuxKeychain()[key])
			return errSecItemNotFound;
		[TGLinuxKeychain() removeObjectForKey:key];
	}
	return errSecSuccess;
}

#pragma mark - more Apple spellings

@implementation NSData (TGLinuxCompatEncode)
- (NSString *)base64Encoding {
	return [self base64EncodedStringWithOptions:0];
}
@end

#import <objc/runtime.h>
static char TGLinuxAttachmentImageKey, TGLinuxAttachmentBoundsKey;
@implementation NSTextAttachment (TGLinuxCompat)
// iOS's attachment carries its picture directly; GNUstep's goes through a cell.
- (NSImage *)image { return objc_getAssociatedObject(self, &TGLinuxAttachmentImageKey); }
- (void)setImage:(NSImage *)image {
	objc_setAssociatedObject(self, &TGLinuxAttachmentImageKey, image, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (NSRect)bounds {
	return [objc_getAssociatedObject(self, &TGLinuxAttachmentBoundsKey) rectValue];
}
- (void)setBounds:(NSRect)bounds {
	objc_setAssociatedObject(self, &TGLinuxAttachmentBoundsKey, [NSValue valueWithRect:bounds],
			OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@implementation NSAttributedString (TGLinuxCompatEnumerate)
// GNUstep has the attribute lookups but not the block enumerators.
- (void)enumerateAttribute:(NSString *)name inRange:(NSRange)range
				   options:(NSUInteger)options
				usingBlock:(void (^)(id value, NSRange range, BOOL *stop))block {
	NSMutableArray *runs = [NSMutableArray array];
	NSUInteger at = range.location, end = NSMaxRange(range);
	while (at < end) {
		NSRange run;
		id value = [self attribute:name atIndex:at longestEffectiveRange:&run inRange:NSMakeRange(at, end - at)];
		[runs addObject:@[value ?: [NSNull null], [NSValue valueWithRange:run]]];
		at = NSMaxRange(run) > at ? NSMaxRange(run) : at + 1;
	}
	BOOL stop = NO;
	NSEnumerator *walk = (options & (1UL << 1)) ? [runs reverseObjectEnumerator] : [runs objectEnumerator];
	for (NSArray *run in walk) {
		id value = run[0] == [NSNull null] ? nil : run[0];
		block(value, [run[1] rangeValue], &stop);
		if (stop)
			break;
	}
}

- (void)enumerateAttributesInRange:(NSRange)range options:(NSUInteger)options
						usingBlock:(void (^)(NSDictionary *attrs, NSRange range, BOOL *stop))block {
	NSMutableArray *runs = [NSMutableArray array];
	NSUInteger at = range.location, end = NSMaxRange(range);
	while (at < end) {
		NSRange run;
		NSDictionary *attrs = [self attributesAtIndex:at longestEffectiveRange:&run inRange:NSMakeRange(at, end - at)];
		[runs addObject:@[attrs ?: @{}, [NSValue valueWithRange:run]]];
		at = NSMaxRange(run) > at ? NSMaxRange(run) : at + 1;
	}
	BOOL stop = NO;
	NSEnumerator *walk = (options & (1UL << 1)) ? [runs reverseObjectEnumerator] : [runs objectEnumerator];
	for (NSArray *run in walk) {
		block(run[0], [run[1] rangeValue], &stop);
		if (stop)
			break;
	}
}
@end

#pragma mark - NSColor CGColor

#import <CoreGraphics/CoreGraphics.h>

// gnustep-gui declares -CGColor but its colour classes do not answer it.
// Apple returns a colour owned by the NSColor; tying the CGColor to the object's
// lifetime keeps that contract without leaking per call.
#import <objc/runtime.h>
static char kTGLinuxCGColorKey;

@implementation NSColor (TGLinuxCompat)
- (CGColorRef)CGColor {
	id cached = objc_getAssociatedObject(self, &kTGLinuxCGColorKey);
	if (cached) return (__bridge CGColorRef)cached;
	NSColor *rgb = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	CGFloat r = 0, g = 0, b = 0, a = 1;
	[rgb ?: self getRed:&r green:&g blue:&b alpha:&a];
	CGColorRef color = CGColorCreateGenericRGB(r, g, b, a);
	objc_setAssociatedObject(self, &kTGLinuxCGColorKey, (__bridge_transfer id)color,
							 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	return color;
}
@end
