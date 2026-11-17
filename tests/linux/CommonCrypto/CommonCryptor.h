// tests/linux/CommonCrypto/CommonCryptor.h - Common Crypto's PBKDF2 on
// OpenSSL for the Linux host run (the passcode key is derived with it).
#pragma once
#include <stddef.h>
#include <stdint.h>
#include <openssl/evp.h>
#define kCCSuccess 0
#define kCCParamError (-4300)
#define kCCPBKDF2 2
#define kCCPRFHmacAlgSHA1 1
#define kCCPRFHmacAlgSHA256 3
static inline int CCKeyDerivationPBKDF(int algorithm, const char *password, size_t passwordLen,
		const uint8_t *salt, size_t saltLen, int prf, unsigned rounds,
		uint8_t *derivedKey, size_t derivedKeyLen) {
	if (algorithm != kCCPBKDF2)
		return kCCParamError;
	const EVP_MD *md = prf == kCCPRFHmacAlgSHA1 ? EVP_sha1() : EVP_sha256();
	return PKCS5_PBKDF2_HMAC(password, (int)passwordLen, salt, (int)saltLen, (int)rounds, md,
			(int)derivedKeyLen, derivedKey) == 1 ? kCCSuccess : kCCParamError;
}
