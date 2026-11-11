//
// TGStarsStore.h - what the Premium, Stars and gift screens may ask for.
//
// Affiliate programs, sponsored messages and ads, Premium, the Star wallet
// and its revenue, gifts and auctions, boosts, paid messages and speech
// recognition. The request bodies live here, in the same thematic
// extensions the client categories used, so a screen never imports TGClient
// or one of its duty headers.
//
#import <Foundation/Foundation.h>

@interface TGStarsStore : NSObject

+ (instancetype)shared;

@end

//
// TGClient+Affiliate.h - Telegram's affiliate programs: the catalogue, the
// programs this account or bot has connected, and the program a channel
// shows under its posts.
//
// Every call names the affiliate it is about. `kind` is "user" (this
// account), "bot" (a bot user id) or "channel" (a chat id); the screen that
// asks for it says which id belongs in the field.
//
@interface TGStarsStore (Affiliate)

/// `sort` is "profitability", "creationDate" or "revenue"; anything else
/// falls back to Telegram's default.
- (void)searchAffiliateProgramsForKind:(NSString *)kind
							 botUserId:(int64_t)botUserId
								chatId:(int64_t)chatId
							  sortOrder:(NSString *)sort
								 offset:(NSString *)offset
								  limit:(int32_t)limit
							 completion:(void (^)(NSDictionary *page,
												  NSString *error))completion;

- (void)connectedAffiliateProgramsForKind:(NSString *)kind
								botUserId:(int64_t)botUserId
								   chatId:(int64_t)chatId
								   offset:(NSString *)offset
									limit:(int32_t)limit
							   completion:(void (^)(NSDictionary *page,
													NSString *error))completion;

/// One connection. `programBotUserId` is the bot that owns the program, not
/// the affiliate the connection belongs to.
- (void)connectedAffiliateProgramForKind:(NSString *)kind
							   botUserId:(int64_t)botUserId
								  chatId:(int64_t)chatId
						  programBotUserId:(int64_t)programBotUserId
							  completion:(void (^)(NSDictionary *program,
												   NSString *error))completion;

- (void)connectAffiliateProgramForKind:(NSString *)kind
							 botUserId:(int64_t)botUserId
								chatId:(int64_t)chatId
						programBotUserId:(int64_t)programBotUserId
							completion:(void (^)(NSDictionary *program,
												 NSString *error))completion;

- (void)disconnectAffiliateProgramForKind:(NSString *)kind
								botUserId:(int64_t)botUserId
								   chatId:(int64_t)chatId
									  url:(NSString *)url
							   completion:(void (^)(NSDictionary *program,
													NSString *error))completion;

/// The chat behind a t.me affiliate link, or Telegram's refusal.
- (void)searchChatAffiliateProgram:(NSString *)username
						  referrer:(NSString *)referrer
						completion:(void (^)(NSDictionary *chat,
											 NSString *error))completion;

/// Sets the commission and duration a channel shows to affiliates.
- (void)setChatAffiliateProgram:(int64_t)chatId
			 commissionPerMille:(int32_t)commissionPerMille
					 monthCount:(int32_t)monthCount
					 completion:(void (^)(BOOL ok, NSString *error))completion;

@end

// vim:ft=objc

@interface TGStarsStore (Ads)

- (void)sponsoredMessagesForChat:(int64_t)chatId
					  completion:(void (^)(NSArray *messages,
										   NSString *error))completion;

/// Tells Telegram the advertisement was opened: its name, its media or its
/// full-screen video. The answer is Telegram's, usually just ok.
- (void)clickSponsoredMessage:(int64_t)messageId
					   inChat:(int64_t)chatId
					mediaClick:(BOOL)mediaClick
				  fromFullscreen:(BOOL)fromFullscreen
				   completion:(void (^)(BOOL ok, NSString *error))completion;

/// Reports a sponsored message. An empty option id asks Telegram for the
/// reason list; the answer says whether it wants a choice, accepted the
/// report, hid ads, or requires Premium.
- (void)reportSponsoredMessage:(int64_t)messageId
						inChat:(int64_t)chatId
						option:(NSString *)optionId
					completion:(void (^)(NSDictionary *result,
										 NSString *error))completion;

/// The account-wide switch. Telegram ignores it for non-Premium accounts,
/// where sponsored messages are always shown; the server's answer says so.
- (void)setSponsoredMessagesEnabled:(BOOL)enabled
						 completion:(void (^)(BOOL ok, NSString *error))completion;

/// The owner's switch for one channel. `supergroupId` is the supergroup id,
/// not the chat id; the screen says so where it asks.
- (void)setChannelSponsoredMessagesEnabled:(BOOL)enabled
							  supergroupId:(int64_t)supergroupId
							   completion:(void (^)(BOOL ok,
													NSString *error))completion;

/// Sponsored chats in search results. Each row is "uniqueId", "chatId",
/// "sponsorInfo" and "additionalInfo".
- (void)searchSponsoredChats:(NSString *)query
				  completion:(void (^)(NSArray *chats,
									   NSString *error))completion;

- (void)openSponsoredChat:(int64_t)uniqueId
			   completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)viewSponsoredChat:(int64_t)uniqueId
			   completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)reportSponsoredChat:(int64_t)uniqueId
					 option:(NSString *)optionId
				 completion:(void (^)(NSDictionary *result,
									 NSString *error))completion;

/// Advertisements that play before or under one video message. Each row is
/// "uniqueId", "text", "minDisplayDuration", "maxDisplayDuration",
/// "canBeReported", "title", "sponsor" and "additionalInfo".
- (void)videoAdvertisementsForChat:(int64_t)chatId
						 message:(int64_t)messageId
					  completion:(void (^)(NSArray *advertisements,
										   NSString *error))completion;

- (void)clickVideoAdvertisement:(int64_t)uniqueId
					 completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)viewVideoAdvertisement:(int64_t)uniqueId
					completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)reportVideoAdvertisement:(int64_t)uniqueId
						  option:(NSString *)optionId
					  completion:(void (^)(NSDictionary *result,
										   NSString *error))completion;

@end

@interface TGStarsStore (Speech)

/// Asks Telegram's own recognizer to transcribe a voice or video note. TDLib
/// answers ok at once and the text arrives in updateMessageContent; the chat
/// re-reads the message and the bubble shows the result. No speech engine is
/// shipped with the app, and none is needed.
- (void)recognizeSpeechInChat:(int64_t)chatId
					  message:(int64_t)messageId
				   completion:(void (^)(BOOL ok, NSString *error))completion;

/// Quality vote for a finished transcript.
- (void)rateSpeechInChat:(int64_t)chatId
				 message:(int64_t)messageId
					isGood:(BOOL)isGood
			  completion:(void (^)(BOOL ok, NSString *error))completion;

/// Informs TDLib that a music file was listened to for `duration` seconds.
/// Telegram uses it for the "listened" mark and for recommendations.
- (void)markAudioListened:(int32_t)fileId
				 duration:(int32_t)duration
			   completion:(void (^)(BOOL ok, NSString *error))completion;

@end

@interface TGStarsStore (Premium)

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

@interface TGStarsStore (Stars)

/// The Star wallet: transactions and subscriptions. `ownerKind` is "user" or
/// "chat"; `direction` is "incoming", "outgoing" or empty for both.
- (void)starTransactionsForOwner:(NSString *)ownerKind
						 ownerId:(int64_t)ownerId
					 direction:(NSString *)direction
						offset:(NSString *)offset
						 limit:(int32_t)limit
					completion:(void (^)(NSDictionary *page,
										 NSString *error))completion;

- (void)starSubscriptionsOnlyExpiring:(BOOL)onlyExpiring
							   offset:(NSString *)offset
						   completion:(void (^)(NSDictionary *page,
												NSString *error))completion;

- (void)setStarSubscription:(NSString *)subscriptionId
				   canceled:(BOOL)canceled
				 completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)reuseStarSubscription:(NSString *)subscriptionId
				   completion:(void (^)(BOOL ok, NSString *error))completion;

@end

@interface TGStarsStore (Gifts)

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

@interface TGStarsStore (Boosts)

/// Boost slots this account can still spend, as "slotId",
/// "currentlyBoostedChatId", "startDate", "expirationDate" and
/// "cooldownUntilDate".
- (void)availableChatBoostSlotsWithCompletion:(void (^)(NSArray *slots,
													   NSString *error))completion;

/// A chat's boost level and counts, as "level", "boostCount",
/// "currentLevelBoostCount", "nextLevelBoostCount" and "boostUrl".
- (void)chatBoostStatusForChat:(int64_t)chatId
					completion:(void (^)(NSDictionary *status,
										 NSString *error))completion;

/// The offline feature table for channels or groups.
- (void)chatBoostFeaturesForChannel:(BOOL)isChannel
						 completion:(void (^)(NSDictionary *features,
											  NSString *error))completion;

- (void)chatBoostLevelFeaturesForChannel:(BOOL)isChannel
								   level:(int32_t)level
							  completion:(void (^)(NSDictionary *features,
												   NSString *error))completion;

- (void)chatBoostLinkForChat:(int64_t)chatId
				  completion:(void (^)(NSString *link, NSString *error))completion;

- (void)chatBoostLinkInfo:(NSString *)url
			   completion:(void (^)(NSDictionary *info, NSString *error))completion;

/// The boosts on a chat; `offset` and `limit` page the list.
- (void)chatBoostsForChat:(int64_t)chatId
				   offset:(NSString *)offset
					limit:(int32_t)limit
			   completion:(void (^)(NSDictionary *page, NSString *error))completion;

/// Spends the named slots on a chat. No payment provider is involved: the
/// slots are the Premium boost allowance.
- (void)boostChat:(int64_t)chatId
		  slotIds:(NSArray *)slotIds
	   completion:(void (^)(NSArray *slots, NSString *error))completion;

@end

@interface TGStarsStore (Revenue)

- (void)chatRevenueStatisticsForChat:(int64_t)chatId
							  dark:(BOOL)dark
						  completion:(void (^)(NSDictionary *statistics,
											   NSString *error))completion;

- (void)chatRevenueTransactionsForChat:(int64_t)chatId
								offset:(NSString *)offset
								 limit:(int32_t)limit
							completion:(void (^)(NSDictionary *page,
												 NSString *error))completion;

- (void)starRevenueStatisticsForOwner:(NSString *)ownerKind
							  ownerId:(int64_t)ownerId
								 dark:(BOOL)dark
						   completion:(void (^)(NSDictionary *statistics,
												NSString *error))completion;

- (void)gramRevenueStatisticsWithDark:(BOOL)dark
						   completion:(void (^)(NSDictionary *statistics,
												NSString *error))completion;

- (void)paidMessageRevenueForUser:(int64_t)userId
					   completion:(void (^)(int64_t starCount,
											NSString *error))completion;

- (void)directMessagesChatTopicRevenueForChat:(int64_t)chatId
										topic:(int64_t)topicId
								   completion:(void (^)(int64_t starCount,
														NSString *error))completion;

@end

@interface TGStarsStore (Discovery)

/// Lets a user send this account unpaid messages after they paid before.
- (void)allowUnpaidMessagesFromUser:(int64_t)userId
							 refund:(BOOL)refund
						 completion:(void (^)(BOOL ok, NSString *error))completion;

/// Redeems the token a t.me link carries so one unpaid message can be sent.
- (void)applyUnpaidMessagesToken:(NSString *)token
						  forUser:(int64_t)userId
					   completion:(void (^)(BOOL ok, NSString *error))completion;

/// The senders that may carry a paid reaction in a chat.
- (void)paidReactionSendersForChat:(int64_t)chatId
						completion:(void (^)(NSArray *senders,
											 NSString *error))completion;

/// The Star price a supergroup charges per message, and the same for a live
/// story's call messages.
- (void)setChatPaidMessageStarCount:(int64_t)chatId
							  count:(int32_t)starCount
						 completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)setGroupCallPaidMessageStarCount:(int32_t)groupCallId
								   count:(int32_t)starCount
							  completion:(void (^)(BOOL ok,
												   NSString *error))completion;

/// Whether one direct-messages topic accepts unpaid messages, with an option
/// to refund the messages already paid for.
- (void)setDirectMessagesTopicUnpaid:(int64_t)chatId
							   topic:(int64_t)topicId
							 allowed:(BOOL)allowed
							  refund:(BOOL)refund
						  completion:(void (^)(BOOL ok, NSString *error))completion;

/// A receipt for a successful payment message.
- (void)paymentReceiptForChat:(int64_t)chatId
					  message:(int64_t)messageId
				   completion:(void (^)(NSDictionary *receipt,
										NSString *error))completion;

/// The Telegram Ads account URL for a channel or bot this account owns.
- (void)starAdAccountURLForOwner:(NSString *)ownerKind
						 ownerId:(int64_t)ownerId
					  completion:(void (^)(NSString *link, NSString *error))completion;

/// The boost count a user needs before slow mode and restrictions stop
/// applying to them, for an owned supergroup.
- (void)setSupergroupUnrestrictBoostCount:(int32_t)count
							  supergroupId:(int64_t)supergroupId
							   completion:(void (^)(BOOL ok,
													NSString *error))completion;

- (void)giveawayInfoForChat:(int64_t)chatId
					message:(int64_t)messageId
				 completion:(void (^)(NSDictionary *info, NSString *error))completion;

- (void)collectibleItemInfoForKind:(NSString *)kind
							 value:(NSString *)value
						completion:(void (^)(NSDictionary *info,
											 NSString *error))completion;

@end

// vim:ft=objc
