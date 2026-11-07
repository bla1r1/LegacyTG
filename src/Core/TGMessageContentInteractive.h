//
// TGMessageContentInteractive.h - structured data for message contents that
// the flat message dictionary cannot hold as plain text.
//
#import <Foundation/Foundation.h>

/// Extra keys an interactive content adds to a flattened message, or nil when
/// the content is none of these types. `content` is TDLib `message.content`.
FOUNDATION_EXPORT NSDictionary *TGFlattenInteractiveContent(NSDictionary *content);
