//
// TGDevStore+ProxyCarrier.m - the Dev store's ProxyCarrier requests.
//
// Bodies copied from src/Core/Client/TGClient+Proxy.m; the store owns them.
//

#import "TGDevStore.h"
#import "TGClient.h"
#import "TGClientInternal.h"

@implementation TGDevStore (ProxyCarrier)
#pragma mark - web proxy carrier

- (void)processWebProxyCarrierMessage:(NSInteger)carrierId
								 text:(NSString *)text
						   completion:(void (^)(BOOL, NSString *))completion {
	[[TGClient shared] request:@{
		@"@type" : @"processWebProxyCarrierMessage",
		@"carrier_id" : @(carrierId),
		@"message" : @{@"@type" : @"webProxyCarrierMessageText",
					   @"text" : text ?: @""},
	} completion:^(NSDictionary *result){
		BOOL ok = ![result[@"@type"] isEqualToString:@"error"];
		NSString *message = result[@"message"];
		if (completion)
			completion(ok, ok ? nil : ([message isKindOfClass:NSString.class]
					? message : @"An error occurred."));
	}];
}

- (void)processWebProxyCarrierMessage:(NSInteger)carrierId
							  base64:(NSString *)base64
						  completion:(void (^)(BOOL, NSString *))completion {
	[[TGClient shared] request:@{
		@"@type" : @"processWebProxyCarrierMessage",
		@"carrier_id" : @(carrierId),
		@"message" : @{@"@type" : @"webProxyCarrierMessageBinary",
					   @"data" : base64 ?: @""},
	} completion:^(NSDictionary *result){
		BOOL ok = ![result[@"@type"] isEqualToString:@"error"];
		NSString *message = result[@"message"];
		if (completion)
			completion(ok, ok ? nil : ([message isKindOfClass:NSString.class]
					? message : @"An error occurred."));
	}];
}

- (void)reportWebProxyCarrierError:(NSInteger)carrierId
							  kind:(NSString *)kind
						   message:(NSString *)message
						completion:(void (^)(BOOL, NSString *))completion {
	NSDictionary *error = nil;
	if ([kind isEqualToString:@"paused"])
		error = @{@"@type" : @"webProxyCarrierErrorPaused"};
	else if ([kind isEqualToString:@"terminated"])
		error = @{@"@type" : @"webProxyCarrierErrorTerminated"};
	else if ([kind isEqualToString:@"refused"])
		error = @{@"@type" : @"webProxyCarrierErrorRefused"};
	else if ([kind isEqualToString:@"loadFailed"])
		error = @{@"@type" : @"webProxyCarrierErrorLoadFailed",
				  @"message" : message ?: @"An error occurred."};
	else
		error = @{@"@type" : @"webProxyCarrierErrorUnsupported"};
	[[TGClient shared] request:@{
		@"@type" : @"reportWebProxyCarrierError",
		@"carrier_id" : @(carrierId),
		@"error" : error,
	} completion:^(NSDictionary *result){
		BOOL ok = ![result[@"@type"] isEqualToString:@"error"];
		NSString *reply = result[@"message"];
		if (completion)
			completion(ok, ok ? nil : ([reply isKindOfClass:NSString.class]
					? reply : @"TDLib refused that carrier error."));
	}];
}

@end
