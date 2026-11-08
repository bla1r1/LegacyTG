#import "TGClient+Base.h"

@interface TGClient (StoriesDiscovery)

/// FoundStories flattened to "totalCount", "nextOffset" and "stories".
- (void)searchPublicStoriesByTag:(NSString *)tag
						  offset:(NSString *)offset
						   limit:(NSInteger)limit
					  completion:(void (^)(NSDictionary *page, NSString *error))completion;

/// `address` uses the four strings TDLib names: "countryCode", "state",
/// "city" and "street". At least one has to be present.
- (void)searchPublicStoriesByLocation:(NSDictionary *)address
							   offset:(NSString *)offset
								limit:(NSInteger)limit
						   completion:(void (^)(NSDictionary *page, NSString *error))completion;

- (void)searchPublicStoriesByVenue:(NSString *)venueProvider
						   venueId:(NSString *)venueId
							offset:(NSString *)offset
							 limit:(NSInteger)limit
						completion:(void (^)(NSDictionary *page, NSString *error))completion;

@end
