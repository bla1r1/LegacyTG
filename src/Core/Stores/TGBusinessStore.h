//
// TGBusinessStore.h - the business profile and business-message requests.
//
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "TGClientTypes.h"

/// The codename a t.me/business link carries, from its URL. Pure, shared with
/// the settings dialogs.
FOUNDATION_EXPORT NSString *TGBusinessLinkName(NSString *link);

/// Per-account defaults key for a business connection (pure helper).
FOUNDATION_EXPORT NSString *TGAccountDefaultsKey(NSString *base);

@interface TGBusinessStore : NSObject

+ (instancetype)shared;

- (void)businessFeaturesForSource:(NSString *)source
					   completion:(void (^)(NSArray *, NSString *))completion;
- (void)businessInfoWithCompletion:(void (^)(NSDictionary *, NSString *))completion;
- (void)businessConnectionWithId:(NSString *)connectionId
					  completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)setBusinessAccountName:(NSString *)firstName
						  last:(NSString *)lastName
				  connectionId:(NSString *)connectionId
					completion:(void (^)(BOOL, NSString *))completion;
- (void)setBusinessAccountBio:(NSString *)bio
				 connectionId:(NSString *)connectionId
				   completion:(void (^)(BOOL, NSString *))completion;
- (void)setBusinessAccountUsername:(NSString *)username
					  connectionId:(NSString *)connectionId
						completion:(void (^)(BOOL, NSString *))completion;
- (void)setBusinessAccountProfilePhotoAtPath:(NSString *)path
									public:(BOOL)isPublic
								connectionId:(NSString *)connectionId
								  completion:(void (^)(BOOL, NSString *))completion;
- (void)businessChatLinksWithCompletion:(void (^)(NSArray *, NSString *))completion;
- (void)createBusinessChatLinkWithText:(NSString *)text
								 title:(NSString *)title
							completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)editBusinessChatLink:(NSString *)link
						text:(NSString *)text
					   title:(NSString *)title
				  completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)deleteBusinessChatLink:(NSString *)link
					completion:(void (^)(BOOL, NSString *))completion;
- (void)businessChatLinkInfoForName:(NSString *)linkName
						 completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)setBusinessLocationLatitude:(NSNumber *)latitude
						  longitude:(NSNumber *)longitude
							address:(NSString *)address
						 completion:(void (^)(BOOL, NSString *))completion;
- (void)setBusinessOpeningHoursTimeZone:(NSString *)timeZone
							  intervals:(NSArray *)intervals
							 completion:(void (^)(BOOL, NSString *))completion;
- (void)setBusinessGreetingMessageEnabled:(BOOL)enabled
							   shortcutId:(NSInteger)shortcutId
						   inactivityDays:(NSInteger)inactivityDays
							   recipients:(NSDictionary *)recipients
							   completion:(void (^)(BOOL, NSString *))completion;
- (void)setBusinessAwayMessageEnabled:(BOOL)enabled
						   shortcutId:(NSInteger)shortcutId
							 schedule:(NSString *)schedule
							startDate:(int32_t)startDate
							  endDate:(int32_t)endDate
						  offlineOnly:(BOOL)offlineOnly
						   recipients:(NSDictionary *)recipients
						   completion:(void (^)(BOOL, NSString *))completion;
- (void)setBusinessStartPageTitle:(NSString *)title
						  message:(NSString *)message
					  stickerPath:(NSString *)stickerPath
					   completion:(void (^)(BOOL, NSString *))completion;
- (void)sendBusinessMessageWithConnectionId:(NSString *)connectionId
									 chatId:(int64_t)chatId
									   text:(NSString *)text
						   disableNotification:(BOOL)disableNotification
							  protectContent:(BOOL)protectContent
								 completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)sendBusinessMessageAlbumWithConnectionId:(NSString *)connectionId
										  chatId:(int64_t)chatId
										   paths:(NSArray *)paths
										  caption:(NSString *)caption
							  disableNotification:(BOOL)disableNotification
								 protectContent:(BOOL)protectContent
									  completion:(void (^)(NSArray *, NSString *))completion;
- (void)editBusinessMessageTextWithConnectionId:(NSString *)connectionId
										 chatId:(int64_t)chatId
									  messageId:(int64_t)messageId
										   text:(NSString *)text
									 completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)editBusinessMessageCaptionWithConnectionId:(NSString *)connectionId
											chatId:(int64_t)chatId
										 messageId:(int64_t)messageId
										   caption:(NSString *)caption
										completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)editBusinessMessageMediaWithConnectionId:(NSString *)connectionId
										  chatId:(int64_t)chatId
									   messageId:(int64_t)messageId
											path:(NSString *)path
										 isVideo:(BOOL)isVideo
										 caption:(NSString *)caption
									  completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)editBusinessMessageLiveLocationWithConnectionId:(NSString *)connectionId
												 chatId:(int64_t)chatId
											  messageId:(int64_t)messageId
											   latitude:(double)latitude
											  longitude:(double)longitude
											 livePeriod:(NSInteger)livePeriod
											 completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)editBusinessMessageChecklistWithConnectionId:(NSString *)connectionId
											  chatId:(int64_t)chatId
										   messageId:(int64_t)messageId
											   title:(NSString *)title
											   tasks:(NSArray *)tasks
											completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)editBusinessMessageReplyMarkupWithConnectionId:(NSString *)connectionId
												chatId:(int64_t)chatId
											 messageId:(int64_t)messageId
											completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)stopBusinessPollWithConnectionId:(NSString *)connectionId
								  chatId:(int64_t)chatId
							   messageId:(int64_t)messageId
							  completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)readBusinessMessageWithConnectionId:(NSString *)connectionId
									 chatId:(int64_t)chatId
								  messageId:(int64_t)messageId
								 completion:(void (^)(BOOL, NSString *))completion;
- (void)setBusinessMessagePinnedWithConnectionId:(NSString *)connectionId
										  chatId:(int64_t)chatId
									   messageId:(int64_t)messageId
										  pinned:(BOOL)pinned
									  completion:(void (^)(BOOL, NSString *))completion;
- (void)deleteBusinessMessagesWithConnectionId:(NSString *)connectionId
									 messageIds:(NSArray *)messageIds
									 completion:(void (^)(BOOL, NSString *))completion;
- (void)businessProfileForUser:(int64_t)userId
					completion:(void (^)(NSDictionary *full))completion;

@end
