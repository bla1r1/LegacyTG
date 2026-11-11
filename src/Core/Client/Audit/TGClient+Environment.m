#import "TGClient+Environment.h"
#import "TGClientInternal.h"
#import "TGClient+AuditSupport.h"

@implementation TGClient (Environment)

#pragma mark - environment

- (void)currentWeatherAtLatitude:(double)latitude
					   longitude:(double)longitude
					  completion:(void (^)(NSDictionary *, NSString *))completion {
	NSDictionary *location = @{@"@type" : @"location",
							   @"latitude" : @(latitude),
							   @"longitude" : @(longitude),
							   @"horizontal_accuracy" : @0};
	[self request:@{@"@type" : @"getCurrentWeather", @"location" : location}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		if (completion)
			completion(@{@"temperature" : TGAuditNumber(result, @"temperature"),
						 @"emoji" : TGAuditString(result, @"emoji")}, nil);
	}];
}

@end
