//
// TGBackgroundKeeper.h - ultra-light silent audio loop keeping TDLib awake in background.
//
#import <Foundation/Foundation.h>

@interface TGBackgroundKeeper : NSObject

+ (instancetype)shared;

@property (nonatomic, readonly, getter=isRunning) BOOL running;

- (BOOL)start;
- (void)stop;

@end
