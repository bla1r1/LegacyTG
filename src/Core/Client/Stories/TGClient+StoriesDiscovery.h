#import "TGClient+Base.h"

@interface TGClient (StoriesDiscovery)

/// FoundStories flattened to "totalCount", "nextOffset" and "stories".
/// `address` uses the four strings TDLib names: "countryCode", "state",
/// "city" and "street". At least one has to be present.
@end
