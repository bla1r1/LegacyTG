//
// TGCrashGuard.c - see TGCrashGuard.h.
//
#include "TGCrashGuard.h"
#include <fcntl.h>
#include <signal.h>
#include <string.h>
#include <unistd.h>

static const int kTGCrashSignals[] = { SIGABRT, SIGSEGV, SIGBUS, SIGILL };
#define TG_CRASH_SIGNAL_COUNT (sizeof(kTGCrashSignals) / sizeof(kTGCrashSignals[0]))

static struct sigaction sPrevious[TG_CRASH_SIGNAL_COUNT];
static int sInstalled;
static char sMarkerPath[1024];
// The handler reads these while the thread it interrupted may be writing
// them; a torn name only costs a wrong entry in a list of refused files.
static volatile char sCurrent[256];

static void TGCrashGuardHandler(int sig) {
	if (sCurrent[0] && sMarkerPath[0]) {
		int fd = open(sMarkerPath, O_WRONLY | O_CREAT | O_TRUNC, 0644);
		if (fd >= 0) {
			size_t length = 0;
			while (length < sizeof(sCurrent) - 1 && sCurrent[length])
				length++;
			ssize_t written = write(fd, (const char *)sCurrent, length);
			(void)written;
			close(fd);
		}
	}
	// Whoever handled the signal before (the system's crash report) still
	// gets it: their handler goes back and this one returns. A fault then
	// runs its instruction again and faults under them, so the report names
	// the thread and the frame that faulted; abort() raises SIGABRT again by
	// itself. A raise() here made every crash report a SIGSEGV on whichever
	// idle thread ran this handler, with the real stack gone.
	for (size_t i = 0; i < TG_CRASH_SIGNAL_COUNT; i++) {
		if (kTGCrashSignals[i] == sig) {
			sigaction(sig, &sPrevious[i], NULL);
			break;
		}
	}
}

int TGCrashGuardInstall(const char *markerPath) {
	if (!markerPath || strlen(markerPath) >= sizeof(sMarkerPath))
		return -1;
	strcpy(sMarkerPath, markerPath);
	if (sInstalled)
		return 0;
	struct sigaction action;
	memset(&action, 0, sizeof(action));
	action.sa_handler = TGCrashGuardHandler;
	sigemptyset(&action.sa_mask);
	for (size_t i = 0; i < TG_CRASH_SIGNAL_COUNT; i++) {
		if (sigaction(kTGCrashSignals[i], &action, &sPrevious[i]) != 0)
			return -1;
	}
	sInstalled = 1;
	return 0;
}

void TGCrashGuardEnter(const char *name) {
	size_t i = 0;
	if (name) {
		for (; i < sizeof(sCurrent) - 1 && name[i]; i++)
			sCurrent[i] = name[i];
	}
	sCurrent[i] = 0;
}

void TGCrashGuardLeave(void) {
	sCurrent[0] = 0;
}
