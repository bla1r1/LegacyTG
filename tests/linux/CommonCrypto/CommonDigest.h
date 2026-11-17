// tests/linux/CommonCrypto/CommonDigest.h - the one CommonCrypto digest the
// app uses, on OpenSSL for the Linux host run.
#pragma once
#include <openssl/sha.h>
typedef unsigned int CC_LONG;
#define CC_SHA256_DIGEST_LENGTH SHA256_DIGEST_LENGTH
static inline unsigned char *CC_SHA256(const void *data, CC_LONG len, unsigned char *md) {
	return SHA256((const unsigned char *)data, len, md);
}
