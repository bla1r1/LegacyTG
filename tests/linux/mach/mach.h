// tests/linux/mach/mach.h - enough Mach for TGPerf's memory reading on the
// Linux host run: task_info answers KERN_FAILURE, so the reading is 0.
#pragma once
#include <stdint.h>
#include "mach_time.h"
typedef int kern_return_t;
typedef unsigned int mach_msg_type_number_t;

typedef int *task_info_t;
typedef int task_flavor_t;
#define KERN_SUCCESS 0
#define KERN_FAILURE 5
#define MACH_TASK_BASIC_INFO 20
struct mach_task_basic_info {
	uint64_t virtual_size, resident_size, resident_size_max;
	int64_t user_time[2], system_time[2];
	int policy, suspend_count;
};
#define MACH_TASK_BASIC_INFO_COUNT ((mach_msg_type_number_t)(sizeof(struct mach_task_basic_info) / sizeof(int)))
static inline int mach_task_self(void) { return 0; }
static inline kern_return_t task_info(int t, task_flavor_t f, task_info_t i, mach_msg_type_number_t *c) {
	(void)t; (void)f; (void)i; (void)c;
	return KERN_FAILURE;
}
