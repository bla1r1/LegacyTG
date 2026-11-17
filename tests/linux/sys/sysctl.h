// tests/linux/sys/sysctl.h - glibc dropped sysctl; the Linux host run asks
// for no hardware names, so every query fails as an unknown name.
#pragma once
#include <stddef.h>
#include <errno.h>
static inline int sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
	(void)name; (void)oldp; (void)newp; (void)newlen;
	if (oldlenp)
		*oldlenp = 0;
	errno = ENOENT;
	return -1;
}
