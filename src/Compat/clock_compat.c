/*
 * clock_compat.c - clock_gettime for the app binary on iOS 6-9.
 *
 * libvpx's encoder times every frame with clock_gettime(CLOCK_MONOTONIC_RAW),
 * which libSystem has only from iOS 10. Against a modern SDK it links as a
 * weak import that dyld leaves NULL on older systems, and the first VP8 frame
 * of a call branched to address 0 (found on the iOS 6.1.3 emulator). A strong
 * definition here wins at static link time; where the system has the real
 * one, it is used.
 *
 * TDLib carries its own copy (ios7_compat.c, linked into the dylib).
 */
#include <dlfcn.h>
#include <errno.h>
#include <mach/mach_time.h>
#include <sys/time.h>
#include <time.h>

int clock_gettime(clockid_t clock_id, struct timespec *ts) {
	static int (*system_clock)(clockid_t, struct timespec *);
	static int looked;
	if (!looked){
		system_clock = (int (*)(clockid_t, struct timespec *))dlsym(RTLD_NEXT, "clock_gettime");
		looked = 1;
	}
	if (system_clock)
		return system_clock(clock_id, ts);
	if (!ts){
		errno = EINVAL;
		return -1;
	}
	if (clock_id == CLOCK_REALTIME){
		struct timeval tv;
		gettimeofday(&tv, NULL);
		ts->tv_sec = tv.tv_sec;
		ts->tv_nsec = tv.tv_usec * 1000;
		return 0;
	}
	// Every other clock (MONOTONIC, MONOTONIC_RAW, UPTIME_RAW) is the
	// uptime clock here; the callers only take differences.
	static mach_timebase_info_data_t base;
	if (!base.denom)
		mach_timebase_info(&base);
	uint64_t ns = mach_absolute_time() * base.numer / base.denom;
	ts->tv_sec = (time_t)(ns / 1000000000ULL);
	ts->tv_nsec = (long)(ns % 1000000000ULL);
	return 0;
}
