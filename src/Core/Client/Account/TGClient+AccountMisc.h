//
// TGClient+Account.h - the client surface for the account and its people: sessions, contacts, blocked users, storage stats.
//
#import "TGClient+Base.h"


@interface TGClient (AccountMisc)

/// TDLib's active notification groups, the ones it would have shown while the
/// app was closed. Each group: "id", "type" (a label), "typeName", "chatId",
/// "totalCount" and "notifications" - rows with "id", "date", "silent", "kind"
/// and the text to draw. Kept by the four updateNotification* branches, so the
/// screen never has to rebuild the list from raw TDLib records.
@property (nonatomic, readonly) NSArray *activeNotificationGroups;
@property (nonatomic, readonly) BOOL haveDelayedNotifications;
@property (nonatomic, readonly) BOOL haveUnreceivedNotifications;
/// Delayed or unreceived notifications are outstanding; the screen shows a
/// refresh indicator until both flags are off.
@property (nonatomic, readonly) BOOL havePendingNotifications;
/// Remove one row. TDLib also sends updateNotificationGroup, but applying it
/// here too keeps a screen that asked for the removal from blinking back.
- (void)removeNotification:(int32_t)notificationId
				   inGroup:(int32_t)groupId
				completion:(void (^)(BOOL ok))completion;
/// Remove a whole group. `maxNotificationId` is the highest id in it; TDLib
/// needs it to close the group rather than only the rows the client knows.
- (void)removeNotificationGroup:(int32_t)groupId
			  maxNotificationId:(int32_t)maxNotificationId
					 completion:(void (^)(BOOL ok))completion;
/// From updateFreezeState: "is_frozen", "freezing_date", "deletion_date" and
/// "appeal_link". Nil until Telegram has said anything about this account.
@property (nonatomic, readonly, copy) NSDictionary *freezeState;
/// From updateAgeVerificationParameters: "min_age", "verification_bot_username"
/// and "country". Nil until Telegram sends the parameters.
@property (nonatomic, readonly, copy) NSDictionary *ageVerificationParameters;
/// From updateApplicationRecaptchaVerificationRequired: "verification_id",
/// "action" and "recaptcha_key_id". Nil when no reCAPTCHA is being asked for.
@property (nonatomic, readonly, copy) NSDictionary *recaptchaVerificationRequest;
/// The subscription record updateUserSubscription last sent for `userId`:
/// "payload", "is_canceled", "is_restored" and "is_payment_failed". Nil when
/// Telegram has said nothing about that user.
- (NSDictionary *)subscriptionForUserId:(int64_t)userId;
/// From updateAvailableMessageEffects: the reaction-effect ids and the
/// sticker-effect ids Telegram offers. Empty arrays before the update arrives.
@property (nonatomic, readonly, copy) NSArray *availableMessageEffectIds;
@property (nonatomic, readonly, copy) NSArray *availableStickerEffectIds;
/// From updateDefaultBackground: a dictionary with "for_dark_theme" and the
/// whole "background" object. Nil before the update arrives.
@property (nonatomic, readonly, copy) NSDictionary *defaultBackground;
/// From updateEmojiChatThemes: emojiChatTheme records, each with a "name" and
/// its light and dark themeSettings. Empty before the update arrives.
@property (nonatomic, readonly, copy) NSArray *emojiChatThemes;
/// The last updateStopMessageDraft: "chat_id", "forum_topic_id", "draft_id"
/// and "draft_text" (the cache the stop cleared). Nil before the first stop.
@property (nonatomic, readonly, copy) NSDictionary *stoppedMessageDraft;
/// The last updateVideoPublished: "chat_id" and "message_id". Nil before the
/// first auto-published video.
@property (nonatomic, readonly, copy) NSDictionary *publishedVideo;

@end
