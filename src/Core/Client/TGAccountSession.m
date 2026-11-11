//
// TGAccountSession.m - auth facts and the background lifecycle.
//
#import "TGAccountSession.h"

@implementation TGAccountSession

+ (instancetype)shared {
	static TGAccountSession *session = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ session = [[TGAccountSession alloc] init]; });
	return session;
}

- (void)pauseForBackground:(void (^)(void))done {
	if ((self.isRunning && !self.isRunning()) || self.pausing || self.paused){
		if (done)
			done();
		return;
	}
	self.pausing = YES;
	self.resumeWanted = NO;
	self.pauseDone = done;
	if (self.onCloseRequested)
		self.onCloseRequested();
}

- (void)resumeFromBackground {
	if (self.pausing){
		self.resumeWanted = YES;      // back before the close finished
		return;
	}
	if (!self.paused)
		return;
	self.paused = NO;
	if (self.onRestartRequested)
		self.onRestartRequested();
}

- (void)clientClosed {
	if (!self.pausing)
		return;
	self.pausing = NO;
	self.paused = YES;
	void (^done)(void) = self.pauseDone;
	self.pauseDone = nil;
	if (self.resumeWanted){
		self.resumeWanted = NO;
		[self resumeFromBackground];
	}
	if (done)
		done();
}

@end

// vim:ft=objc
