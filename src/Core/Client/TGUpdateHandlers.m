//
// TGUpdateHandlers.m - one place for every update* branch.
//
#import "TGUpdateHandlers.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGState.h"
#import "TGTransport.h"
#import "TGUpdateRouter.h"
#import "TGAccountSession.h"
#import "TGJson.h"
#include "TGUpdateType.h"
#import "TGOptions.h"
#import "TGBase64.h"
#import "TGCall.h"
#import "TGUpdateHandlersSupport.h"

@interface TGClient (TGUpdateHandlerPrivate)
- (void)markSavedMessagesRow;
@end

@interface TGUpdateHandlers (Families)
- (BOOL)handleCoreUpdates:(NSString *)type kind:(TGUpdateType)kind obj:(NSDictionary *)obj;
- (BOOL)handleChatsUpdates:(NSString *)type kind:(TGUpdateType)kind obj:(NSDictionary *)obj;
- (BOOL)handleAccountUpdates:(NSString *)type kind:(TGUpdateType)kind obj:(NSDictionary *)obj;
- (BOOL)handleStoriesUpdates:(NSString *)type kind:(TGUpdateType)kind obj:(NSDictionary *)obj;
- (BOOL)handleNotificationsUpdates:(NSString *)type kind:(TGUpdateType)kind obj:(NSDictionary *)obj;
- (BOOL)handleFilesUpdates:(NSString *)type kind:(TGUpdateType)kind obj:(NSDictionary *)obj;
- (BOOL)handleMiscUpdates:(NSString *)type kind:(TGUpdateType)kind obj:(NSDictionary *)obj;
@end

@implementation TGUpdateHandlers

+ (instancetype)shared {
	static TGUpdateHandlers *handlers = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ handlers = [[TGUpdateHandlers alloc] init]; });
	return handlers;
}

- (void)handleUpdate:(NSDictionary *)obj {

	if ([[TGUpdateRouter shared] deliverResponse:obj])
		return;
	NSString *type = obj[@"@type"];
	// Looked up once. Each of the seven families used to convert the name
	// to UTF-8 and hash it again, for every update.
	const char *typeName = type.UTF8String;
	TGUpdateType kind = typeName ? TGUpdateTypeFor(typeName, strlen(typeName)) : TGUpdateUnknown;

#if TG_DEV
	if ([type hasPrefix:@"updateAuthorization"] || [type hasPrefix:@"authorization"] || [type isEqualToString:@"error"] || [type isEqualToString:@"ok"]) {
		NSLog(@"TGClient: <<< RECV: %@", obj);
	}
#endif

	// Log each response kind once - enough to see what TDLib actually sends
	// without dumping the user's messages into the log.
	static NSMutableSet *seen = nil;
	if (!seen) seen = [NSMutableSet set];
	if (type && ![seen containsObject:type]){
		[seen addObject:type];
		NSLog(@"TGClient: first %@", type);
	}

	// Answer to getMe. updateUser also carries our own record, but the direct
	// reply is the one that always has the phone number.
	if ([type isEqualToString:@"user"] && obj[@"phone_number"]){
		self.client.me = @{
			@"id"         : obj[@"id"] ?: @(0),
			@"first_name" : obj[@"first_name"] ?: @"",
			@"last_name"  : obj[@"last_name"] ?: @"",
			@"username"   : TGUFirstActiveUsername(obj) ?: (obj[@"username"] ?: @""),
			@"phone"      : obj[@"phone_number"] ?: @"",
		};
		// getMe is the first moment the active account's title and phone are
		// both known; the slot list has to carry them so the switcher can
		// name each account.
		[self.client recordActiveAccountFromMe:self.client.me];
		// loadChats runs before getMe, so the chat with yourself can arrive
		// before its id is known; re-mark it now that me is here.
		[self.client markSavedMessagesRow];
		// No phone number: stderr is a file in Caches and, before iOS 7, a
		// syslog any app can read.
		NSLog(@"TGClient: signed in");
		return;
	}

	if ([self handleCoreUpdates:type kind:kind obj:obj])
		return;
	if ([self handleChatsUpdates:type kind:kind obj:obj])
		return;
	if ([self handleAccountUpdates:type kind:kind obj:obj])
		return;
	if ([self handleStoriesUpdates:type kind:kind obj:obj])
		return;
	if ([self handleNotificationsUpdates:type kind:kind obj:obj])
		return;
	if ([self handleFilesUpdates:type kind:kind obj:obj])
		return;
	if ([self handleMiscUpdates:type kind:kind obj:obj])
		return;

	if ([type isEqualToString:@"error"]){
		NSString *msg = obj[@"message"] ?: @"An error occurred.";
#if TG_DEV
		NSLog(@"TGClient: <<< ERROR code=%@ msg=%@ details: %@", obj[@"code"], msg, obj);
#else
		NSLog(@"TGClient: <<< ERROR code=%@ msg=%@", obj[@"code"], msg);
#endif
		// An unclaimed 404 stays quiet, as before - but it no longer says
		// anything about the chat list: loadChats reads its own answer now.
		if ([obj[@"code"] intValue] == 404)
			return;
		if (self.client.onError)
			self.client.onError(msg);
		return;
	}

}

@end

// vim:ft=objc
