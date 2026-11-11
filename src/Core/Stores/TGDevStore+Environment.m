//
// TGDevStore+Environment.m - the Dev store's Environment requests.
//
// Bodies copied from src/Core/Client/Audit/TGClient+Environment.m; the store owns them.
//

#import "TGDevStore.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGClient+AuditSupport.h"

@implementation TGDevStore (Environment)

#pragma mark - environment

- (void)jsonValueForText:(NSString *)text
			  completion:(void (^)(NSDictionary *, NSString *))completion {
	text = text ?: @"";
	TGAuditExecute([TGClient shared], @{@"@type" : @"getJsonValue", @"json" : text},
				^(NSDictionary *result){
		if (!result){
			if (completion) completion(nil, @"TDLib's execute symbol is not loaded.");
			return;
		}
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		if (completion) completion(result, nil);
	});
}

- (void)jsonTextForValue:(NSDictionary *)value
			  completion:(void (^)(NSString *, NSString *))completion {
	TGAuditExecute([TGClient shared], @{@"@type" : @"getJsonString",
						@"json_value" : (value ?: @{@"@type" : @"jsonValueNull"})},
				^(NSDictionary *result){
		if (!result){
			if (completion) completion(nil, @"TDLib's execute symbol is not loaded.");
			return;
		}
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		if (completion) completion(TGAuditString(result, @"text"), nil);
	});
}

- (void)themeParametersJSONString:(NSDictionary *)colours
					   completion:(void (^)(NSString *, NSString *))completion {
	static NSArray *roles = nil;
	if (!roles)
		roles = @[@"backgroundColor", @"secondaryBackgroundColor",
				  @"headerBackgroundColor", @"bottomBarBackgroundColor",
				  @"sectionBackgroundColor", @"sectionSeparatorColor",
				  @"textColor", @"accentTextColor", @"sectionHeaderTextColor",
				  @"subtitleTextColor", @"destructiveTextColor", @"hintColor",
				  @"linkColor", @"buttonColor", @"buttonTextColor"];
	NSMutableDictionary *theme = [NSMutableDictionary dictionary];
	theme[@"@type"] = @"themeParameters";
	for (NSString *role in roles){
		NSString *key = [role stringByReplacingOccurrencesOfString:@"Color" withString:@"_color"];
		// The snake_case key has to keep the first word intact: the role is
		// written in camelCase and only its suffix changes.
		key = [key stringByReplacingOccurrencesOfString:@"([a-z])([A-Z])"
											 withString:@"$1_$2"
												options:NSRegularExpressionSearch
												  range:NSMakeRange(0, key.length)];
		key = [key lowercaseString];
		theme[key] = TGAuditNumber(colours ?: @{}, role);
	}
	TGAuditExecute([TGClient shared], @{@"@type" : @"getThemeParametersJsonString",
						@"theme" : theme}, ^(NSDictionary *result){
		if (!result){
			if (completion) completion(nil, @"TDLib's execute symbol is not loaded.");
			return;
		}
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		if (completion) completion(TGAuditString(result, @"text"), nil);
	});
}

- (void)logStreamWithCompletion:(void (^)(NSDictionary *, NSString *))completion {
	TGAuditExecute([TGClient shared], @{@"@type" : @"getLogStream"}, ^(NSDictionary *result){
		if (!result){
			if (completion) completion(nil, @"TDLib's execute symbol is not loaded.");
			return;
		}
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		if (completion) completion(result, nil);
	});
}

- (void)logVerbosityLevelWithCompletion:(void (^)(int32_t, NSString *))completion {
	TGAuditExecute([TGClient shared], @{@"@type" : @"getLogVerbosityLevel"}, ^(NSDictionary *result){
		if (!result){
			if (completion) completion(0, @"TDLib's execute symbol is not loaded.");
			return;
		}
		if (TGAuditFailed(result)){
			if (completion) completion(0, TGAuditError(result));
			return;
		}
		if (completion) completion([TGAuditNumber(result, @"verbosity_level") intValue], nil);
	});
}

- (void)logTagsWithCompletion:(void (^)(NSArray *, NSString *))completion {
	TGAuditExecute([TGClient shared], @{@"@type" : @"getLogTags"}, ^(NSDictionary *result){
		if (!result){
			if (completion) completion(nil, @"TDLib's execute symbol is not loaded.");
			return;
		}
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSArray *tags = result[@"tags"];
		if (completion) completion([tags isKindOfClass:NSArray.class] ? tags : @[], nil);
	});
}

- (void)logVerbosityForTag:(NSString *)tag
				completion:(void (^)(int32_t, NSString *))completion {
	tag = [tag stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!tag.length){
		if (completion) completion(0, @"A log tag is needed.");
		return;
	}
	TGAuditExecute([TGClient shared], @{@"@type" : @"getLogTagVerbosityLevel", @"tag" : tag},
				^(NSDictionary *result){
		if (!result){
			if (completion) completion(0, @"TDLib's execute symbol is not loaded.");
			return;
		}
		if (TGAuditFailed(result)){
			if (completion) completion(0, TGAuditError(result));
			return;
		}
		if (completion) completion([TGAuditNumber(result, @"verbosity_level") intValue], nil);
	});
}

- (void)setLogVerbosityForTag:(NSString *)tag
						level:(int32_t)level
				   completion:(void (^)(BOOL, NSString *))completion {
	tag = [tag stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!tag.length){
		if (completion) completion(NO, @"A log tag is needed.");
		return;
	}
	if (level < 1 || level > 1024){
		if (completion) completion(NO, @"TDLib takes a verbosity level from 1 to 1024.");
		return;
	}
	TGAuditExecute([TGClient shared], @{@"@type" : @"setLogTagVerbosityLevel",
						@"tag" : tag, @"new_verbosity_level" : @(level)},
				^(NSDictionary *result){
		BOOL failed = !result || TGAuditFailed(result);
		NSString *error = !result
				? @"TDLib's execute symbol is not loaded."
				: (failed ? TGAuditError(result) : nil);
		if (completion) completion(!failed, error);
	});
}

- (void)setLogStreamKind:(NSString *)kind
					path:(NSString *)path
			  completion:(void (^)(BOOL, NSString *))completion {
	NSDictionary *stream = nil;
	if ([kind isEqualToString:@"file"]){
		path = [path stringByTrimmingCharactersInSet:
				[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		if (!path.length){
			if (completion) completion(NO, @"A file path is needed for a file stream.");
			return;
		}
		stream = @{@"@type" : @"logStreamFile",
				   @"path" : path,
				   @"max_file_size" : @(1048576),
				   @"redirect_stderr" : @NO};
	} else if ([kind isEqualToString:@"empty"]){
		stream = @{@"@type" : @"logStreamEmpty"};
	} else {
		stream = @{@"@type" : @"logStreamDefault"};
	}
	TGAuditExecute([TGClient shared], @{@"@type" : @"setLogStream", @"log_stream" : stream},
				^(NSDictionary *result){
		BOOL failed = !result || TGAuditFailed(result);
		NSString *error = !result
				? @"TDLib's execute symbol is not loaded."
				: (failed ? TGAuditError(result) : nil);
		if (completion) completion(!failed, error);
	});
}

- (void)addLogMessage:(NSString *)text
				level:(int32_t)level
		   completion:(void (^)(BOOL, NSString *))completion {
	TGAuditExecute([TGClient shared], @{@"@type" : @"addLogMessage",
						@"verbosity_level" : @(MAX((int32_t)0, MIN(level, (int32_t)1023))),
						@"text" : (text ?: @"")},
				^(NSDictionary *result){
		BOOL failed = !result || TGAuditFailed(result);
		NSString *error = !result
				? @"TDLib's execute symbol is not loaded."
				: (failed ? TGAuditError(result) : nil);
		if (completion) completion(!failed, error);
	});
}

- (void)saveApplicationLogEvent:(NSString *)type
						chatId:(int64_t)chatId
						  data:(NSString *)data
					completion:(void (^)(BOOL, NSString *))completion {
	type = [type stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!type.length){
		if (completion) completion(NO, @"An event type is needed.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"saveApplicationLogEvent",
					@"type" : type,
					@"chat_id" : @(chatId),
					@"data" : TGAuditJsonValue(data)}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

- (void)timeZonesWithCompletion:(void (^)(NSArray *, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"getTimeZones"} completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *zone in result[@"time_zones"]){
			if (![zone isKindOfClass:NSDictionary.class])
				continue;
			[rows addObject:@{
				@"id"     : TGAuditString(zone, @"id"),
				@"name"   : TGAuditString(zone, @"name"),
				@"offset" : TGAuditNumber(zone, @"utc_time_offset"),
			}];
		}
		if (completion) completion(rows, nil);
	}];
}

- (void)currencyExchangeRatesWithCompletion:(void (^)(NSArray *, NSString *))completion {
	[[TGClient shared] request:@{@"@type" : @"getCurrencyExchangeRates"}
	   completion:^(NSDictionary *result){
		if (TGAuditFailed(result)){
			if (completion) completion(nil, TGAuditError(result));
			return;
		}
		NSMutableArray *rows = [NSMutableArray array];
		for (NSDictionary *rate in result[@"rates"]){
			if (![rate isKindOfClass:NSDictionary.class])
				continue;
			[rows addObject:@{
				@"currency" : TGAuditString(rate, @"currency"),
				@"rate"     : TGAuditNumber(rate, @"rate"),
			}];
		}
		if (completion) completion(rows, nil);
	}];
}

- (void)currentWeatherAtLatitude:(double)latitude
					   longitude:(double)longitude
					  completion:(void (^)(NSDictionary *, NSString *))completion {
	NSDictionary *location = @{@"@type" : @"location",
							   @"latitude" : @(latitude),
							   @"longitude" : @(longitude),
							   @"horizontal_accuracy" : @0};
	[[TGClient shared] request:@{@"@type" : @"getCurrentWeather", @"location" : location}
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

- (void)alarmAfterSeconds:(double)seconds
			   completion:(void (^)(BOOL, NSString *))completion {
	if (seconds <= 0 || seconds > 86400){
		if (completion) completion(NO, @"The wait must be between 1 second and a day.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"setAlarm", @"seconds" : @(seconds)}
	   completion:^(NSDictionary *result){
		BOOL failed = TGAuditFailed(result);
		if (completion) completion(!failed, failed ? TGAuditError(result) : nil);
	}];
}

@end
