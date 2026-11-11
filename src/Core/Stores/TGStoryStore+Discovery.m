//
// TGStoryStore+Discovery.m - copied from TGClient+StoriesDiscovery.m.
//
#import "TGStoryStore.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGClient+StoriesSupport.h"

#import "TGClient+StoriesDiscovery.h"
#import "TGClient+StoriesSupport.h"
#import "TGClientInternal.h"

@implementation TGStoryStore (StoriesDiscovery)

#pragma mark - public discovery

static NSDictionary *TGStoryFoundStoriesPage(NSDictionary *result) {
	if (![result[@"@type"] isEqualToString:@"foundStories"])
		return nil;
	NSMutableArray *stories = [NSMutableArray array];
	for (NSDictionary *story in TGStoryArray(result[@"stories"]))
		if ([story isKindOfClass:NSDictionary.class])
			[stories addObject:TGStoryFlatten(story)];
	return @{
		@"totalCount" : result[@"total_count"] ?: @(0),
		@"nextOffset" : result[@"next_offset"] ?: @"",
		@"stories" : stories,
	};
}

- (void)searchPublicStoriesByTag:(NSString *)tag
						  offset:(NSString *)offset
						   limit:(NSInteger)limit
					  completion:(void (^)(NSDictionary *, NSString *))completion {
	NSString *clean = [tag isKindOfClass:NSString.class] ? tag : @"";
	if ([clean hasPrefix:@"#"])
		clean = [clean substringFromIndex:1];
	if (!clean.length){
		if (completion) completion(nil, @"Type a hashtag first.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"searchPublicStoriesByTag",
					@"story_tag" : clean,
					@"offset" : offset ?: @"",
					@"limit" : @(limit > 0 ? limit : 20)}
	   completion:^(NSDictionary *result){
		NSDictionary *page = TGStoryFoundStoriesPage(result);
		if (!page){
			if (completion)
				completion(nil, TGStoryErrorText(result));
			return;
		}
		if (completion) completion(page, nil);
	}];
}

- (void)searchPublicStoriesByLocation:(NSDictionary *)address
							   offset:(NSString *)offset
								limit:(NSInteger)limit
						   completion:(void (^)(NSDictionary *, NSString *))completion {
	NSString *country = address[@"countryCode"] ?: @"";
	NSString *state = address[@"state"] ?: @"";
	NSString *city = address[@"city"] ?: @"";
	NSString *street = address[@"street"] ?: @"";
	if (!country.length && !state.length && !city.length && !street.length){
		if (completion) completion(nil, @"Name a country, city or street.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"searchPublicStoriesByLocation",
					@"address" : @{@"@type" : @"locationAddress",
								   @"country_code" : country,
								   @"state" : state,
								   @"city" : city,
								   @"street" : street},
					@"offset" : offset ?: @"",
					@"limit" : @(limit > 0 ? limit : 20)}
	   completion:^(NSDictionary *result){
		NSDictionary *page = TGStoryFoundStoriesPage(result);
		if (!page){
			if (completion)
				completion(nil, TGStoryErrorText(result));
			return;
		}
		if (completion) completion(page, nil);
	}];
}

- (void)searchPublicStoriesByVenue:(NSString *)venueProvider
						   venueId:(NSString *)venueId
							offset:(NSString *)offset
							 limit:(NSInteger)limit
						completion:(void (^)(NSDictionary *, NSString *))completion {
	if (!venueProvider.length || !venueId.length){
		if (completion) completion(nil, @"A venue needs its provider and its id.");
		return;
	}
	[[TGClient shared] request:@{@"@type" : @"searchPublicStoriesByVenue",
					@"venue_provider" : venueProvider,
					@"venue_id" : venueId,
					@"offset" : offset ?: @"",
					@"limit" : @(limit > 0 ? limit : 20)}
	   completion:^(NSDictionary *result){
		NSDictionary *page = TGStoryFoundStoriesPage(result);
		if (!page){
			if (completion)
				completion(nil, TGStoryErrorText(result));
			return;
		}
		if (completion) completion(page, nil);
	}];
}

@end

// vim:ft=objc
