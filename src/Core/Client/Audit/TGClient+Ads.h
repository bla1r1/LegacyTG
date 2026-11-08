#import "TGClient+Base.h"

@interface TGClient (Ads)

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
