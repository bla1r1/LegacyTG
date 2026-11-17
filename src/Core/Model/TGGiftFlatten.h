//
// TGGiftFlatten.h - flatten TDLib receivedGift records down to row and viewer fields.
//
#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSDictionary *TGFlattenReceivedGift(NSDictionary *receivedGift);

/// A unique gift attribute's rarity as official badges it (GiftViewScreen
/// formatPercentage): "1.2%", "5%", "<0.1%" for zero per mille, or the
/// localized "uncommon" / "rare" / "epic" / "legendary". "" when absent.
FOUNDATION_EXPORT NSString *TGGiftRarityText(NSDictionary *rarity);
