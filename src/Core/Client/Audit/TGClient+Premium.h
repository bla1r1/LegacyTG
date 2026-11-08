#import "TGClient+Base.h"

@interface TGClient (Premium)

/// The feature and limit lists on the Premium page. Each feature is its type
/// name; each limit keeps "type", "defaultValue" and "premiumValue".
- (void)premiumFeaturesFromSource:(NSString *)source
					   completion:(void (^)(NSDictionary *features,
											NSString *error))completion;

/// Tells Telegram a Premium feature card was opened.
- (void)viewPremiumFeature:(NSString *)featureType
				completion:(void (^)(BOOL ok, NSString *error))completion;

/// One limit's free and Premium values, as "type", "defaultValue" and
/// "premiumValue".
- (void)premiumLimitOfType:(NSString *)limitType
				completion:(void (^)(NSDictionary *limit,
									 NSString *error))completion;

/// Premium stickers, examples and the month-specific info sticker.
- (void)premiumStickersWithLimit:(int32_t)limit
					  completion:(void (^)(NSArray *stickers,
										   NSString *error))completion;

- (void)premiumStickerExamplesWithCompletion:(void (^)(NSArray *stickers,
													   NSString *error))completion;

- (void)premiumInfoStickerForMonths:(int32_t)months
						 completion:(void (^)(NSDictionary *sticker,
											 NSString *error))completion;

/// Checks a Premium gift code without redeeming it. The answer keeps
/// "monthCount", "dayCount", "isFromGiveaway", "userId" and "useDate".
- (void)checkPremiumGiftCode:(NSString *)code
				  completion:(void (^)(NSDictionary *info,
									   NSString *error))completion;

- (void)applyPremiumGiftCode:(NSString *)code
				  completion:(void (^)(BOOL ok, NSString *error))completion;

/// Tells Telegram the Premium subscribe button was pressed. The purchase
/// itself is the App Store's, which this build does not carry; the signal is
/// still real and is what the server logs.
- (void)clickPremiumSubscriptionButtonWithCompletion:(void (^)(BOOL ok,
															  NSString *error))completion;

@end
