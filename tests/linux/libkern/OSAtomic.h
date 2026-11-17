// tests/linux/libkern/OSAtomic.h - the OSAtomic calls the tests use, on the
// compiler's atomics (Apple's are full barriers too).
#pragma once
#include <stdint.h>
static inline int32_t OSAtomicIncrement32(volatile int32_t *v) { return __sync_add_and_fetch(v, 1); }
static inline int32_t OSAtomicDecrement32(volatile int32_t *v) { return __sync_sub_and_fetch(v, 1); }
static inline int32_t OSAtomicAdd32(int32_t a, volatile int32_t *v) { return __sync_add_and_fetch(v, a); }
static inline int32_t OSAtomicIncrement32Barrier(volatile int32_t *v) { return __sync_add_and_fetch(v, 1); }
static inline int32_t OSAtomicDecrement32Barrier(volatile int32_t *v) { return __sync_sub_and_fetch(v, 1); }
static inline void OSMemoryBarrier(void) { __sync_synchronize(); }
