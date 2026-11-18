//
// TGCrashGuard.h - names the work a crash happened in, for the next launch.
//
// tlottie is built with panic = abort, as the official client builds it: a bug
// in it takes the app down, and nothing in-process can catch that. What can be
// done is not to crash on the same sticker every time it scrolls by. The
// caller names the work before a risky call; if SIGABRT, SIGSEGV, SIGBUS or
// SIGILL arrives meanwhile, the handler writes that name to the marker file
// (open/write/close only, all async-signal-safe) and hands the signal on to
// whatever handled it before. The next launch reads the marker and stops
// giving that work to the code that crashed.
//
// Plain C: the handler and its test (a forked child that aborts) need no
// runtime.
//
#ifndef TG_CRASH_GUARD_H
#define TG_CRASH_GUARD_H

#ifdef __cplusplus
extern "C" {
#endif

/// Installs the handlers once and sets where a crash writes its name;
/// later calls only move the marker. 0 on success.
int TGCrashGuardInstall(const char *markerPath);

/// The work now in progress, up to 255 bytes; one at a time, so callers on
/// several threads hold their own lock around Enter ... Leave.
void TGCrashGuardEnter(const char *name);
void TGCrashGuardLeave(void);

#ifdef __cplusplus
}
#endif

#endif
