// tests/linux/Security/Security.h - a keychain for the Linux host run: generic
// passwords kept in this process, by service and account. The app stores the
// passcode hash and the database key there; the tests only need them back.
#pragma once
#include <CoreFoundation/CoreFoundation.h>
typedef int32_t OSStatus;
#define errSecSuccess 0
#define errSecItemNotFound (-25300)
#define errSecDuplicateItem (-25299)
#ifdef __cplusplus
extern "C" {
#endif
extern const CFStringRef kSecClass, kSecClassGenericPassword, kSecAttrService, kSecAttrAccount,
		kSecReturnData, kSecMatchLimit, kSecMatchLimitOne, kSecValueData, kSecAttrAccessible,
		kSecAttrAccessibleAfterFirstUnlock, kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;
OSStatus SecItemAdd(CFDictionaryRef attributes, CFTypeRef *result);
OSStatus SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result);
OSStatus SecItemUpdate(CFDictionaryRef query, CFDictionaryRef attributes);
OSStatus SecItemDelete(CFDictionaryRef query);
#ifdef __cplusplus
}
#endif
