//
// TGMessageContentCommerce.h - commerce content flattened for the bubble.
//
// Paid media, invoices, giveaways and gifts have nothing to render without
// their numbers and file ids, so they are read once here and handed to the
// message dictionary as nested values.
//
#import <Foundation/Foundation.h>

/// Extra keys a commerce content adds to a flattened message, or nil when the
/// content is none of these types. `content` is TDLib `message.content`.
FOUNDATION_EXPORT NSDictionary *TGFlattenCommerceContent(NSDictionary *content);
