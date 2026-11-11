//
// TGAccountSession.h - authorization state and the background close/restart.
//
// TGClient owns the caches; this object owns the account's auth facts and the
// pause/resume state machine. It never talks to TDLib directly: close and
// restart are two blocks installed by TGClient.
//
#import <Foundation/Foundation.h>
#import "TGClientTypes.h"

@interface TGAccountSession : NSObject

+ (instancetype)shared;

@property (nonatomic, assign) TGAuthState authState;
@property (nonatomic, assign) NSTimeInterval readyAt;
@property (nonatomic, copy) NSString *registrationTermsText;
@property (nonatomic, strong) NSDictionary *codeInfo;
@property (nonatomic, strong) NSDictionary *loginPasswordInfo;
@property (nonatomic, strong) NSDictionary *emailCodeInfo;
@property (nonatomic, copy) NSString *qrCodeLink;
@property (nonatomic, copy) NSString *pendingPhoneNumber;
@property (nonatomic, strong) NSDictionary *recaptchaVerificationRequestValue;

@property (nonatomic, assign) BOOL pausing;
@property (nonatomic, assign) BOOL paused;
@property (nonatomic, assign) BOOL resumeWanted;
@property (nonatomic, copy) void (^pauseDone)(void);

/// Installed by TGClient: asks TDLib to close, and starts it again.
@property (nonatomic, copy) BOOL (^isRunning)(void);
@property (nonatomic, copy) void (^onCloseRequested)(void);
@property (nonatomic, copy) void (^onRestartRequested)(void);

- (void)pauseForBackground:(void (^)(void))done;
- (void)resumeFromBackground;
- (void)clientClosed;

@end
