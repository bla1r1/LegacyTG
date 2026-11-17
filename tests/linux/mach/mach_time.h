// tests/linux/mach/mach_time.h - the Mach clock on CLOCK_MONOTONIC, in
// nanoseconds, for the Linux host run.
#pragma once
#include <stdint.h>
#include <time.h>
typedef struct { uint32_t numer, denom; } mach_timebase_info_data_t;
typedef mach_timebase_info_data_t *mach_timebase_info_t;
static inline int mach_timebase_info(mach_timebase_info_t info) {
	info->numer = 1;
	info->denom = 1;
	return 0;
}
static inline uint64_t mach_absolute_time(void) {
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return (uint64_t)ts.tv_sec * 1000000000ull + (uint64_t)ts.tv_nsec;
}
