//
// TGClient+Diagnostics.m - TDLib's own state, configuration and counters.
//
// A screen here is looking at the machinery rather than at Telegram's
// content, so the failure mode is different: every request can be refused
// for a reason the server spells out, and a silent boolean would hide it.
// Each method therefore carries the server's sentence to its completion.
//
#import "TGClient+Diagnostics.h"
#import "TGClientInternal.h"
#import "TGDatabaseKey.h"
#import "TGBase64.h"

@implementation TGClient (Diagnostics)

#pragma mark - state and configuration

#pragma mark - network

#pragma mark - charts

#pragma mark - raw request and database key

@end
