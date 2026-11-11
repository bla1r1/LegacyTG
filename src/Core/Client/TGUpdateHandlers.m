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
- (BOOL)handleCoreUpdates:(NSString *)type obj:(NSDictionary *)obj;
- (BOOL)handleChatsUpdates:(NSString *)type obj:(NSDictionary *)obj;
- (BOOL)handleAccountUpdates:(NSString *)type obj:(NSDictionary *)obj;
- (BOOL)handleStoriesUpdates:(NSString *)type obj:(NSDictionary *)obj;
- (BOOL)handleNotificationsUpdates:(NSString *)type obj:(NSDictionary *)obj;
- (BOOL)handleFilesUpdates:(NSString *)type obj:(NSDictionary *)obj;
- (BOOL)handleMiscUpdates:(NSString *)type obj:(NSDictionary *)obj;
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
	const char *typeName = type.UTF8String;
	size_t typeLen = typeName ? strlen(typeName) : 0;

	if ([type hasPrefix:@"updateAuthorization"] || [type hasPrefix:@"authorization"] || [type isEqualToString:@"error"] || [type isEqualToString:@"ok"]) {
		NSLog(@"TGClient: <<< RECV: %@", obj);
	}

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
		NSLog(@"TGClient: signed in as +%@", self.client.me[@"phone"]);
		return;
	}

		if ([self handleCoreUpdates:type obj:obj])
		return;
	if ([self handleChatsUpdates:type obj:obj])
		return;
	if ([self handleAccountUpdates:type obj:obj])
		return;
	if ([self handleStoriesUpdates:type obj:obj])
		return;
	if ([self handleNotificationsUpdates:type obj:obj])
		return;
	if ([self handleFilesUpdates:type obj:obj])
		return;
	if ([self handleMiscUpdates:type obj:obj])
		return;

	if ([type isEqualToString:@"error"]){
		NSString *msg = obj[@"message"] ?: @"An error occurred.";
		NSLog(@"TGClient: <<< ERROR code=%@ msg=%@ details: %@", obj[@"code"], msg, obj);
		if ([obj[@"code"] intValue] == 404){
			// loadChats answers 404 when the whole list is loaded
			self.client.chatListComplete = YES;
			NSLog(@"TGClient: chat list complete (%lu)",
					(unsigned long)self.client.chatsById.count);
			return;
		}
		if (self.client.onError)
			self.client.onError(msg);
		return;
	}

}

@end

// vim:ft=objc
