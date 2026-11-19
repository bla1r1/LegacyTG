//
// TGPerf.m - see TGPerf.h.
//
#import <Foundation/Foundation.h>
#import "TGPerf.h"
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <pthread.h>
#include <stdio.h>
#include <string.h>

double TGPerfNow(void) {
	// mach_absolute_time is the only clock iOS 6 exports: clock_gettime is
	// weakly matched there, and calling it jumped into a null stub. Ticks
	// replay the boot epoch, so the count can outgrow a double's precision
	// on a device that never powers off - anchoring to our first call keeps
	// every absolute small and every subtraction of two of them exact.
	static mach_timebase_info_data_t tb;
	if (tb.denom == 0)
		mach_timebase_info(&tb);
	static double epochMs = -1.0;
	if (epochMs < 0.0)
		epochMs = (double)mach_absolute_time() * (double)tb.numer
				/ (double)tb.denom / 1.0e6;
	double nowMs = (double)mach_absolute_time() * (double)tb.numer
			/ (double)tb.denom / 1.0e6;
	return nowMs - epochMs;
}

// A slow cell used to NSLog from the main thread, and on iOS 6 NSLog is a
// synchronous trip to syslogd: scrolling a chat on the iPod touch 4, the
// reports themselves were 1.8% of the main thread. Lines now go to a ring
// and one flush at BACKGROUND logs them 0.3 s later or once nothing else
// wants the CPU; past 64 pending the oldest go, and the flush says how many.
// At DEFAULT the flushes held back every BACKGROUND queue in the process
// (custom emoji decodes, sticker loops) for as long as reports kept coming.
#define TG_PERF_RING 64
static char sPerfRing[TG_PERF_RING][192];
static unsigned sPerfHead, sPerfTail, sPerfDropped;
static int sPerfFlushScheduled;
static pthread_mutex_t sPerfLock = PTHREAD_MUTEX_INITIALIZER;

static void TGPerfFlush(void) {
	char lines[TG_PERF_RING][192];
	unsigned count = 0, dropped;
	pthread_mutex_lock(&sPerfLock);
	while (sPerfTail != sPerfHead && count < TG_PERF_RING) {
		memcpy(lines[count++], sPerfRing[sPerfTail % TG_PERF_RING], sizeof(lines[0]));
		sPerfTail++;
	}
	dropped = sPerfDropped;
	sPerfDropped = 0;
	sPerfFlushScheduled = 0;
	pthread_mutex_unlock(&sPerfLock);
	for (unsigned i = 0; i < count; i++)
		NSLog(@"[perf] %s", lines[i]);
	if (dropped)
		NSLog(@"[perf] %u more reports dropped", dropped);
}

void TGPerfReport(const char *what, const char *detail, double startMs, double budgetMs) {
	double took = TGPerfNow() - startMs;
	if (took < budgetMs)
		return;
	pthread_mutex_lock(&sPerfLock);
	if (sPerfHead - sPerfTail >= TG_PERF_RING) {
		sPerfTail++;
		sPerfDropped++;
	}
	snprintf(sPerfRing[sPerfHead % TG_PERF_RING], sizeof(sPerfRing[0]), "%s %s took %.1f ms (budget %.0f)",
			what ?: "?", detail ?: "", took, budgetMs);
	sPerfHead++;
	int schedule = !sPerfFlushScheduled;
	sPerfFlushScheduled = 1;
	pthread_mutex_unlock(&sPerfLock);
	if (schedule)
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
				dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{ TGPerfFlush(); });
}

size_t TGPerfResidentBytes(void) {
	struct mach_task_basic_info info;
	mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
	if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO,
			(task_info_t)&info, &count) != KERN_SUCCESS)
		return 0;
	return (size_t)info.resident_size;
}

void TGPerfReportMemory(const char *what) {
	size_t bytes = TGPerfResidentBytes();
	if (!bytes)
		return;
	NSLog(@"[perf] %s resident %.1f MB", what ?: "?", (double)bytes / (1024.0 * 1024.0));
}
