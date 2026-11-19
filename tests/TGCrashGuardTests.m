// TGCrashGuardTests.m - the marker a crash leaves, read by the next launch.
//
// tlottie aborts on a bug (panic = abort, as official builds it), and a
// sticker it aborts on would crash the app every time it scrolled by. The
// child processes below abort for real; the parent reads what they left.
#import "TGTestRunner.h"
#import "TGCrashGuard.h"
#import "TGTLottie.h"
#include <mach/mach.h>
#include <sys/wait.h>
#include <unistd.h>

@interface TGCrashGuardTests : XCTestCase @end

static NSString *cgTempDirectory(void) {
	NSString *dir = [NSTemporaryDirectory() stringByAppendingPathComponent:
			[NSString stringWithFormat:@"tg-crashguard-%@", [NSUUID UUID].UUIDString]];
	[[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
	return dir;
}

/// Forks a child that names `name` (and leaves it again when `leave`), then
/// aborts. Answers the signal the child died of.
static int cgAbortInChild(const char *marker, const char *name, BOOL leave) {
	// The child's copy of an unflushed buffer would print the runner's lines twice.
	fflush(stdout);
	fflush(stderr);
	pid_t pid = fork();
	if (pid == 0) {
		// No crash report for a crash on purpose.
		task_set_exception_ports(mach_task_self(), EXC_MASK_CRASH, MACH_PORT_NULL,
				EXCEPTION_DEFAULT, THREAD_STATE_NONE);
		TGCrashGuardInstall(marker);
		TGCrashGuardEnter(name);
		if (leave)
			TGCrashGuardLeave();
		abort();
	}
	int status = 0;
	waitpid(pid, &status, 0);
	return WIFSIGNALED(status) ? WTERMSIG(status) : 0;
}

@implementation TGCrashGuardTests

- (void)testAbort_WritesTheWorkInProgressAndStillDies {
	NSString *marker = [cgTempDirectory() stringByAppendingPathComponent:@"tlottie.crashed"];
	XCTAssertEqual(cgAbortInChild(marker.fileSystemRepresentation, "5224607267797606837.tgs", NO), SIGABRT);
	NSString *written = [NSString stringWithContentsOfFile:marker encoding:NSUTF8StringEncoding error:NULL];
	XCTAssertTrue([written isEqualToString:@"5224607267797606837.tgs"], @"%@", written);
}

- (void)testAbort_OutsideTheWorkLeavesNoMarker {
	NSString *marker = [cgTempDirectory() stringByAppendingPathComponent:@"tlottie.crashed"];
	XCTAssertEqual(cgAbortInChild(marker.fileSystemRepresentation, "a.tgs", YES), SIGABRT);
	XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:marker]);
}

- (void)testCrashLog_TheFileTlottieCrashedOnIsRefusedFromThenOn {
	NSString *dir = cgTempDirectory();
	[@"bad.tgs" writeToFile:[dir stringByAppendingPathComponent:@"tlottie.crashed"] atomically:YES
			encoding:NSUTF8StringEncoding error:NULL];
	NSDictionary *anim = @{ @"v" : @"5.5.2", @"w" : @10, @"h" : @10, @"fr" : @60, @"ip" : @0, @"op" : @60,
							@"layers" : @[], @"assets" : @[] };
	NSData *json = [NSJSONSerialization dataWithJSONObject:anim options:0 error:nil];

	TGTLottieUseCrashLog(dir);
	XCTAssertTrue(TGTLottieCreate(json, @"bad.tgs") == NULL);
	TGTLottie *good = TGTLottieCreate(json, @"good.tgs");
	XCTAssertTrue(good != NULL);
	TGTLottieFree(good);
	XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:[dir stringByAppendingPathComponent:@"tlottie.crashed"]]);

	// The launch after: no marker, the list remembers.
	TGTLottieUseCrashLog(dir);
	XCTAssertTrue(TGTLottieCreate(json, @"bad.tgs") == NULL);

	// Leave the process with an empty list for the tests after this one.
	TGTLottieUseCrashLog(cgTempDirectory());
}

/// A real fault still dies of SIGSEGV with the marker written, and dies of
/// the fault itself, not of a signal the handler raised again.
- (void)testFault_DiesOfTheFaultWithTheMarker {
	NSString *marker = [cgTempDirectory() stringByAppendingPathComponent:@"tlottie.crashed"];
	fflush(stdout);
	fflush(stderr);
	pid_t pid = fork();
	if (pid == 0) {
		task_set_exception_ports(mach_task_self(), EXC_MASK_CRASH | EXC_MASK_BAD_ACCESS, MACH_PORT_NULL,
				EXCEPTION_DEFAULT, THREAD_STATE_NONE);
		TGCrashGuardInstall(marker.fileSystemRepresentation);
		TGCrashGuardEnter("fault.tgs");
		volatile int *nowhere = (volatile int *)(uintptr_t)8;
		*nowhere = 1;
		_exit(0);
	}
	int status = 0;
	waitpid(pid, &status, 0);
	XCTAssertTrue(WIFSIGNALED(status));
	int sig = WIFSIGNALED(status) ? WTERMSIG(status) : 0;
	XCTAssertTrue(sig == SIGSEGV || sig == SIGBUS, @"%d", sig);
	NSString *written = [NSString stringWithContentsOfFile:marker encoding:NSUTF8StringEncoding error:NULL];
	XCTAssertEqualObjects(written, @"fault.tgs");
}

@end
