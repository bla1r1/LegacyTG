#import "TGClient+Base.h"

@interface TGClient (Gifts)

/// Gifts that can be sent, the answer to "can this one be sent now", one
/// received gift, and the upgraded gift catalogue.
- (void)availableGiftsWithCompletion:(void (^)(NSArray *gifts,
											   NSString *error))completion;

- (void)canSendGift:(int64_t)giftId
		 completion:(void (^)(NSDictionary *result,
							  NSString *error))completion;

- (void)receivedGift:(NSString *)receivedGiftId
		  completion:(void (^)(NSDictionary *gift,
							   NSString *error))completion;

- (void)upgradedGiftNamed:(NSString *)name
			   completion:(void (^)(NSDictionary *gift,
									NSString *error))completion;

- (void)upgradedGiftValueInfoNamed:(NSString *)name
						completion:(void (^)(NSDictionary *info,
											 NSString *error))completion;

- (void)upgradedGiftVariantsForGift:(int64_t)regularGiftId
					   completion:(void (^)(NSDictionary *variants,
											NSString *error))completion;

- (void)giftUpgradePreviewForGift:(int64_t)regularGiftId
					   completion:(void (^)(NSDictionary *preview,
											NSString *error))completion;

- (void)giftCollectionsForOwner:(NSString *)ownerKind
						ownerId:(int64_t)ownerId
					 completion:(void (^)(NSArray *collections,
										  NSString *error))completion;

- (void)giftsForCraftingFromGift:(int64_t)regularGiftId
						  offset:(NSString *)offset
						   limit:(int32_t)limit
					  completion:(void (^)(NSArray *gifts,
										   NSString *error))completion;

- (void)searchGiftsForResaleFromGift:(int64_t)regularGiftId
							   order:(NSString *)order
						  offset:(NSString *)offset
						   limit:(int32_t)limit
					  completion:(void (^)(NSArray *gifts,
										   NSString *error))completion;

- (void)upgradedGiftEmojiStatusesWithCompletion:(void (^)(NSArray *statuses,
														 NSString *error))completion;

- (void)giftChatThemesWithOffset:(NSString *)offset
						   limit:(int32_t)limit
					  completion:(void (^)(NSArray *themes,
										   NSString *error))completion;

/// Auction reads and the two open/close signals. Bidding is the part that
/// spends Stars and is not here.
- (void)giftAuctionStateForAuction:(NSString *)auctionId
						completion:(void (^)(NSDictionary *state,
											 NSString *error))completion;

- (void)giftAuctionAcquiredGiftsForGift:(int64_t)giftId
							 completion:(void (^)(NSArray *gifts,
												  NSString *error))completion;

- (void)openGiftAuctionForGift:(int64_t)giftId
					completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)closeGiftAuctionForGift:(int64_t)giftId
					 completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)upgradedGiftsPromotionalAnimationWithCompletion:
		(void (^)(NSDictionary *animation, NSString *error))completion;

@end
