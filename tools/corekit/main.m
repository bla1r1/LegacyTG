//
// main.m - CoreKit headless smoke test.
//
// Links the same client and store sources the app uses, with no feature screen
// and no real UIKit: if this runs, the domain layer is usable without the app.
//
#import <Foundation/Foundation.h>
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGSendStore.h"
#import "TGMessageStore.h"
#import "TGGroupStore.h"
#import "TGSettingsStore.h"

static NSDictionary *Decode(NSData *data) {
	NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	NSString *trimmed = [json componentsSeparatedByString:@"\0"][0];
	return [NSJSONSerialization JSONObjectWithData:
			[trimmed dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
}

int main(int argc, const char *argv[]) {
	@autoreleasepool {
		TGClient *client = TGClient.shared;
		[client.outbox removeAllObjects];
		[client.pendingRequests removeAllObjects];

		[[TGSendStore shared] sendText:@"corekit" toChat:1 thread:0 replyTo:0
					   schedulingState:nil];

		NSDictionary *request = nil;
		for (NSData *data in client.outbox)
			request = Decode(data);
		NSString *type = request[@"@type"] ?: @"(none)";
		printf("CoreKit: store=%s request=%s chat=%lld\n",
			   "TGSendStore", type.UTF8String,
			   [request[@"chat_id"] longLongValue]);
		printf("CoreKit: stores loaded send=%d message=%d group=%d settings=%d\n",
			   [TGSendStore shared] != nil,
			   [TGMessageStore shared] != nil,
			   [TGGroupStore shared] != nil,
			   [TGSettingsStore shared] != nil);
	}
	return 0;
}
