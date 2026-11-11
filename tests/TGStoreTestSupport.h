// TGStoreTestSupport.h - test-only declarations for store methods that are
// implemented in the stores but not yet part of their public headers.
//
// The host suite exercises the same store code the app calls; these
// categories keep that possible without widening every store header at once.
#import <Foundation/Foundation.h>
#import "TGAccountStore.h"
#import "TGGroupStore.h"
#import "TGProfileStore.h"
#import "TGSettingsStore.h"
#import "TGTextStylesStore.h"

@interface TGAccountStore (TGTestSupport)
@property (nonatomic, readonly) int64_t pushReceiverId;
- (void)countryCodeWithCompletion:(void (^)(NSString *code))completion;
- (void)resetStateForAccountSwitch;
- (void)accountUsernamesWithCompletion:(void (^)(NSDictionary *usernames))completion;
- (void)toggleUsernameIsActive:(NSString *)username isActive:(BOOL)isActive completion:(void (^)(BOOL ok, NSString *error))completion;
- (void)reorderActiveUsernames:(NSArray *)usernames completion:(void (^)(BOOL ok, NSString *error))completion;
- (void)connectedWebsitesWithCompletion:(void (^)(NSArray *sites, NSString *error))completion;
- (void)disconnectWebsite:(int64_t)websiteId completion:(void (^)(BOOL ok, NSString *error))completion;
- (void)disconnectAllWebsitesWithCompletion:(void (^)(BOOL ok, NSString *error))completion;
- (void)recoveryEmailAddress:(NSString *)password completion:(void (^)(NSString *email))completion;
- (void)setPassword:(NSString *)oldPassword new:(NSString *)newPassword hint:(NSString *)hint setEmailAddress:(BOOL)setEmailAddress email:(NSString *)recoveryEmail completion:(void (^)(BOOL ok))completion;
- (void)setRecoveryEmailAddress:(NSString *)password to:(NSString *)email completion:(void (^)(BOOL ok))completion;
- (void)pushReceiverOfPayload:(NSDictionary *)payload completion:(void (^)(BOOL ok, int64_t receiverId))completion;
- (void)sendEmailCode:(NSString *)code;
- (void)recoverPasswordWithCode:(NSString *)code completion:(void (^)(NSString *error))completion;
- (void)requestPasswordRecoveryWithCompletion:(void (^)(NSString *error))completion;
- (void)reportAuthenticationCodeMissing;
- (void)setLoginEmailAddress:(NSString *)email completion:(void (^)(NSString *pattern, NSString *error))completion;
- (void)resendLoginEmailAddressCodeWithCompletion: (void (^)(NSString *pattern, NSString *error))completion;
- (void)checkLoginEmailAddressCode:(NSString *)code completion:(void (^)(NSString *error))completion;
- (void)checkAuthenticationWebToken:(NSString *)token dcId:(NSInteger)dcId completion:(void (^)(NSString *error))completion;
- (void)dismissWebToken:(NSString *)token completion:(void (^)(NSString *error))completion;
- (void)confirmQrCodeAuthenticationLink:(NSString *)link completion:(void (^)(NSString *error))completion;
- (void)phoneNumberInfoForPrefix:(NSString *)prefix completion:(void (^)(NSDictionary *info))completion;
- (NSDictionary *)phoneNumberInfoForPrefixSync:(NSString *)prefix;
- (void)sendPhoneNumberChangeCode:(NSString *)phoneNumber completion:(void (^)(NSDictionary *info, NSString *error))completion;
- (void)checkPhoneNumberChangeCode:(NSString *)code completion:(void (^)(NSString *error))completion;
- (void)resendPhoneNumberChangeCodeWithCompletion: (void (^)(NSDictionary *info, NSString *error))completion;
- (void)reportPhoneNumberCodeMissingWithCompletion: (void (^)(NSString *error))completion;
- (void)sendAuthenticationFirebaseSms:(NSString *)token completion:(void (^)(NSString *error))completion;
- (void)sendPhoneNumberFirebaseSms:(NSString *)token completion:(void (^)(NSString *error))completion;
- (void)requestAccountPasswordRecoveryWithCompletion: (void (^)(NSString *pattern, NSString *error))completion;
- (void)checkAccountPasswordRecoveryCode:(NSString *)code completion:(void (^)(NSString *error))completion;
- (void)recoverAccountPasswordWithCode:(NSString *)code newPassword:(NSString *)password hint:(NSString *)hint completion:(void (^)(NSDictionary *state, NSString *error))completion;
- (void)resetAccountPasswordWithCompletion: (void (^)(NSString *result, double date, NSString *error))completion;
- (void)cancelAccountPasswordResetWithCompletion: (void (^)(NSString *error))completion;
- (void)temporaryPasswordStateWithCompletion: (void (^)(BOOL has, NSInteger validFor, NSString *error))completion;
- (void)createTemporaryPassword:(NSString *)password validFor:(NSInteger)seconds completion:(void (^)(BOOL has, NSInteger validFor, NSString *error))completion;
- (void)cancelRecoveryEmailAddressVerificationWithCompletion: (void (^)(NSDictionary *state, NSString *error))completion;
- (void)sendEmailAddressVerificationCodeTo:(NSString *)email completion:(void (^)(NSString *pattern, NSString *error))completion;
- (void)resendEmailAddressVerificationCodeWithCompletion: (void (^)(NSString *pattern, NSString *error))completion;
- (void)checkEmailAddressVerificationCode:(NSString *)code completion:(void (^)(NSString *error))completion;
- (void)setApplicationVerificationToken:(NSString *)token verificationId:(int64_t)verificationId completion:(void (^)(NSString *error))completion;
- (void)supportNameWithCompletion:(void (^)(NSString *name, NSString *error))completion;
- (void)supportInfoForUser:(int64_t)userId completion:(void (^)(NSDictionary *info, NSString *error))completion;
- (void)setSupportInfo:(NSString *)message forUser:(int64_t)userId completion:(void (^)(NSDictionary *info, NSString *error))completion;
- (void)registerWithFirstName:(NSString *)firstName lastName:(NSString *)lastName completion:(void (^)(BOOL ok, NSString *error))completion;
- (NSString *)registrationTerms;
- (void)countriesWithCompletion:(void (^)(NSArray *countries))completion;
- (void)registerPushToken:(NSString *)token sandbox:(BOOL)sandbox completion:(void (^)(BOOL ok))completion;
- (void)processPushPayload:(NSDictionary *)payload;
@end

@interface TGProfileStore (TGTestSupport)
- (void)setAccountAccentColor:(NSInteger)accentId backgroundEmojiId:(int64_t)emojiId completion:(void (^)(BOOL ok, NSString *error))completion;
- (void)setAccountProfileAccentColor:(NSInteger)accentId backgroundEmojiId:(int64_t)emojiId completion:(void (^)(BOOL ok, NSString *error))completion;
@end

@interface TGSettingsStore (TGTestSupport)
@property (nonatomic, readonly) NSDictionary *reactionNotificationSettings;
- (void)setReactionNotificationsEnabled:(BOOL)enabled completion:(void (^)(BOOL ok))completion;
- (void)autosaveSettingsWithCompletion:(void (^)(NSDictionary *settings))completion;
- (void)setAutosaveSettingsForScope:(NSString *)scope photos:(BOOL)photos videos:(BOOL)videos maxVideoSize:(long long)maxVideoSize completion:(void (^)(BOOL ok))completion;
- (void)clearAutosaveSettingsExceptionsWithCompletion:(void (^)(BOOL ok))completion;
- (void)storageStatsWithCompletion:(void (^)(long long bytes, NSInteger files))completion;
- (void)setDefaultMessageAutoDeleteTime:(NSInteger)seconds;
- (void)sentDocuments:(NSString *)query completion:(void (^)(NSArray *messages))completion;
- (void)callbackQueryMessage:(int64_t)messageId inChat:(int64_t)chatId callbackQueryId:(int64_t)callbackQueryId completion:(void (^)(NSDictionary *message))completion;
- (void)setReactions:(NSArray *)emojis onMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(BOOL ok))completion;
- (void)preparedInlineMessageFromBot:(int64_t)botUserId preparedMessageId:(NSString *)preparedMessageId completion:(void (^)(NSDictionary *prepared))completion;
- (void)savePreparedInlineMessageForUser:(int64_t)userId text:(NSString *)text title:(NSString *)title completion:(void (^)(NSString *preparedMessageId))completion;
- (void)sendTextDraft:(NSString *)text toChat:(int64_t)chatId topic:(int64_t)topicId draftId:(int64_t)draftId canStop:(BOOL)canStop keep:(BOOL)keepOnStop completion:(void (^)(BOOL ok))completion;
- (void)stopTextDraft:(int64_t)draftId inChat:(int64_t)chatId topic:(int64_t)topicId completion:(void (^)(BOOL ok))completion;
- (void)personalChatHistoryForUser:(int64_t)userId limit:(NSInteger)limit completion:(void (^)(NSArray *messages))completion;
- (void)editInlineMessageText:(NSString *)inlineMessageId text:(NSString *)text completion:(void (^)(BOOL ok))completion;
- (void)editInlineMessageCaption:(NSString *)inlineMessageId caption:(NSString *)caption completion:(void (^)(BOOL ok))completion;
- (void)clearInlineMessageReplyMarkup:(NSString *)inlineMessageId completion:(void (^)(BOOL ok))completion;
- (void)editInlineMessagePhoto:(NSString *)inlineMessageId photoId:(int64_t)photoId caption:(NSString *)caption completion:(void (^)(BOOL ok))completion;
- (void)editInlineMessageLiveLocation:(NSString *)inlineMessageId latitude:(double)latitude longitude:(double)longitude completion:(void (^)(BOOL ok))completion;
- (void)savedNotificationSoundsWithCompletion: (void (^)(NSArray *sounds))completion;
- (void)savedNotificationSound:(int64_t)soundId completion:(void (^)(NSDictionary *sound))completion;
- (void)addSavedNotificationSoundAtPath:(NSString *)path completion:(void (^)(NSDictionary *sound, NSString *error))completion;
- (void)removeSavedNotificationSound:(int64_t)soundId completion:(void (^)(BOOL ok, NSString *error))completion;
- (void)removeNotification:(int32_t)notificationId inGroup:(int32_t)groupId completion:(void (^)(BOOL ok, NSString *error))completion;
- (void)removeNotificationGroup:(int32_t)groupId maxNotificationId:(int32_t)maxNotificationId completion:(void (^)(BOOL ok, NSString *error))completion;
- (void)savedOrderInfoWithCompletion:(void (^)(NSDictionary *order, NSString *error))completion;
- (void)deleteSavedOrderInfoWithCompletion:(void (^)(BOOL ok, NSString *error))completion;
- (void)bankCardInfoForNumber:(NSString *)number completion:(void (^)(NSDictionary *info, NSString *error))completion;
- (void)addOfferToMessage:(int64_t)messageId inChat:(int64_t)chatId starCount:(int64_t)starCount sendDate:(int32_t)sendDate completion:(void (^)(NSDictionary *message, NSString *error))completion;
- (void)validateOrderInfoForInvoice:(NSString *)invoiceName order:(NSDictionary *)order allowSave:(BOOL)allowSave completion:(void (^)(NSDictionary *validated, NSString *error))completion;
- (void)sendCallLog:(NSString *)log forMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(BOOL ok, NSString *error))completion;
- (void)sendCallDebugInformation:(NSString *)information forMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(BOOL ok, NSString *error))completion;
- (void)preparedKeyboardButtonFromBot:(int64_t)botUserId preparedButtonId:(NSString *)preparedButtonId completion:(void (^)(NSDictionary *button, NSString *error))completion;
- (void)savePreparedKeyboardButtonText:(NSString *)text forUser:(int64_t)userId completion:(void (^)(NSString *preparedButtonId, NSString *error))completion;
- (BOOL)hasFileWaiterRecord:(NSInteger)fileId;
- (NSUInteger)fileWaiterCount:(NSInteger)fileId;
- (NSInteger)fileWaiterPriority:(NSInteger)fileId;
- (void)setPrivacyRule:(NSString *)setting type:(NSString *)ruleType allowUserIds:(NSArray *)allowUserIds restrictUserIds:(NSArray *)restrictUserIds completion:(void (^)(BOOL ok, NSString *error))completion;
- (void)privacyRuleDetails:(NSString *)setting completion:(void (^)(NSString *ruleType, NSArray *allowUserIds, NSArray *restrictUserIds))completion;
- (void)setOption:(NSString *)name integerValue:(int64_t)value;
- (void)languagePackInfo:(NSString *)packId completion:(void (^)(NSDictionary *info))completion;
- (void)languagePackStrings:(NSString *)packId keys:(NSArray *)keys completion:(void (^)(NSArray *strings))completion;
- (void)loadAppLanguagePack:(NSString *)packId completion:(void (^)(BOOL ok))completion;
- (void)languagePackString:(NSString *)key pack:(NSString *)packId completion:(void (^)(NSString *value, NSString *kind))completion;
- (void)addCustomServerLanguagePack:(NSString *)packId completion:(void (^)(BOOL ok))completion;
- (void)setCustomLanguagePack:(NSString *)packId name:(NSString *)name nativeName:(NSString *)nativeName strings:(NSArray *)strings completion:(void (^)(BOOL ok))completion;
- (void)setCustomLanguagePackString:(NSString *)key value:(NSString *)value pack:(NSString *)packId completion:(void (^)(BOOL ok))completion;
- (void)editCustomLanguagePackInfo:(NSDictionary *)info completion:(void (^)(BOOL ok))completion;
- (void)synchronizeLanguagePack:(NSString *)packId completion:(void (^)(BOOL ok))completion;
- (void)deleteLanguagePack:(NSString *)packId completion:(void (^)(BOOL ok))completion;
- (void)countryInfoForCode:(NSString *)countryCode completion:(void (^)(NSDictionary *country))completion;
- (void)preferredCountryLanguageForCode:(NSString *)countryCode completion:(void (^)(NSString *languageCode))completion;
- (void)countryFlagEmojiForCode:(NSString *)countryCode completion:(void (^)(NSString *emoji))completion;
- (void)deleteAccountWithReason:(NSString *)reason password:(NSString *)password completion:(void (^)(BOOL ok))completion;
- (void)editProxy:(NSInteger)proxyId server:(NSString *)server port:(NSInteger)port kind:(NSString *)kind username:(NSString *)username password:(NSString *)password secret:(NSString *)secret enable:(BOOL)enable completion:(void (^)(BOOL ok))completion;
- (void)testProxyAtServer:(NSString *)server port:(NSInteger)port kind:(NSString *)kind username:(NSString *)username password:(NSString *)password secret:(NSString *)secret completion:(void (^)(BOOL works))completion;
- (void)checkRecoveryEmailCode:(NSString *)code completion:(void (^)(BOOL ok))completion;
- (void)setScope:(NSString *)scope muted:(BOOL)muted;
- (void)blockedUsersWithCompletion:(void (^)(NSArray *users))completion;
- (void)autoDownloadSettingsPresetsWithCompletion: (void (^)(NSDictionary *presets))completion;
- (void)applyAutoDownloadPreset:(NSDictionary *)preset forNetwork:(NSString *)network completion:(void (^)(BOOL ok))completion;
- (void)currentStateWithCompletion:(void (^)(NSArray *updates, NSString *error))completion;
- (void)applicationConfigWithCompletion:(void (^)(NSDictionary *config, NSString *error))completion;
- (void)databaseStatisticsWithCompletion:(void (^)(NSString *statistics, NSString *error))completion;
- (void)setNetworkType:(NSString *)networkType completion:(void (^)(BOOL ok, NSString *error))completion;
- (void)addNetworkStatisticsForNetworkType:(NSString *)networkType sentBytes:(long long)sent receivedBytes:(long long)received duration:(double)duration completion:(void (^)(BOOL ok, NSString *error))completion;
- (void)statisticalGraphForChat:(int64_t)chatId token:(NSString *)token x:(NSInteger)x completion:(void (^)(NSDictionary *graph, NSString *error))completion;
- (void)sendCustomRequestMethod:(NSString *)method parameters:(NSString *)parameters completion:(void (^)(NSString *result, NSString *error))completion;
- (void)setDatabaseEncryptionKey:(NSData *)newKey completion:(void (^)(BOOL ok, NSString *error))completion;
- (void)chatCountForFolder:(NSDictionary *)folder completion:(void (^)(NSInteger count))completion;
- (void)chatsToLeaveForFolder:(NSInteger)folderId completion:(void (^)(NSArray *chatIds))completion;
- (void)defaultIconNameForFolder:(NSDictionary *)folder completion:(void (^)(NSString *name))completion;
- (void)inviteLinksForFolder:(NSInteger)folderId completion:(void (^)(NSArray *links))completion;
- (void)chatsForFolderInviteLink:(NSInteger)folderId completion:(void (^)(NSArray *chatIds))completion;
- (void)createInviteLinkForFolder:(NSInteger)folderId name:(NSString *)name chatIds:(NSArray *)chatIds completion:(void (^)(NSString *link))completion;
- (void)editInviteLinkForFolder:(NSInteger)folderId link:(NSString *)link name:(NSString *)name chatIds:(NSArray *)chatIds completion:(void (^)(BOOL ok))completion;
- (void)deleteInviteLinkForFolder:(NSInteger)folderId link:(NSString *)link completion:(void (^)(BOOL ok))completion;
- (void)checkFolderInviteLink:(NSString *)link completion:(void (^)(NSDictionary *folder))completion;
- (void)addFolderByInviteLink:(NSString *)link chatIds:(NSArray *)chatIds completion:(void (^)(BOOL ok))completion;
- (void)newChatsForFolder:(NSInteger)folderId completion:(void (^)(NSArray *chatIds))completion;
- (void)processNewChats:(NSArray *)chatIds forFolder:(NSInteger)folderId completion:(void (^)(BOOL ok))completion;
- (void)toggleFolderTags:(BOOL)on;
- (void)answerJoinRequestQuery:(int64_t)queryId approve:(BOOL)approve completion:(void (^)(BOOL ok))completion;
- (void)inactiveSupergroupChatsWithCompletion:(void (^)(NSArray *chats))completion;
- (void)createdPublicChatsOfType:(NSString *)type completion:(void (^)(NSArray *chats))completion;
- (void)checkCreatedPublicChatsLimitForType:(NSString *)type completion:(void (^)(BOOL ok, NSString *reason))completion;
- (void)checkUsername:(NSString *)username forChat:(int64_t)chatId completion:(void (^)(NSString *result))completion;
- (void)notificationExceptionsWithCompletion: (void (^)(NSArray *chats))completion;
- (void)chatForBasicGroup:(int64_t)basicGroupId completion:(void (^)(int64_t chatId))completion;
- (void)chatForSupergroup:(int64_t)supergroupId completion:(void (^)(int64_t chatId))completion;
- (void)chatForSecretChat:(int32_t)secretChatId completion:(void (^)(int64_t chatId))completion;
- (void)fileDownloadsMatching:(NSString *)query activeOnly:(BOOL)activeOnly completion:(void (^)(NSArray *downloads, NSInteger activeCount))completion;
- (void)removeFileFromDownloads:(NSInteger)fileId deleteFromCache:(BOOL)deleteFromCache;
- (void)setDownloadOfFile:(NSInteger)fileId paused:(BOOL)paused;
- (void)setAllDownloadsPaused:(BOOL)paused;
- (void)createFolderNamed:(NSString *)name icon:(NSString *)icon withChats:(NSArray *)chatIds completion:(void (^)(NSInteger folderId))completion;
- (void)editFolder:(NSInteger)folderId name:(NSString *)name chats:(NSArray *)chatIds completion:(void (^)(BOOL ok))completion;
- (void)deleteFolder:(NSInteger)folderId leavingChats:(NSArray *)leaveChatIds;
- (void)reorderFolderIds:(NSArray *)folderIds mainListAt:(NSInteger)position;
- (void)recommendedFoldersWithCompletion:(void (^)(NSArray *folders))completion;
- (void)createRecommendedFolder:(NSDictionary *)folder completion:(void (^)(NSInteger folderId))completion;
- (void)addProxyAtServer:(NSString *)server port:(NSInteger)port kind:(NSString *)kind username:(NSString *)username password:(NSString *)password secret:(NSString *)secret enable:(BOOL)enable completion:(void (^)(NSInteger proxyId))completion;
- (BOOL)addProxyFromLink:(NSString *)link completion:(void (^)(NSInteger proxyId))completion;
- (void)proxiesWithCompletion:(void (^)(NSArray *proxies))completion;
- (void)disableProxy;
- (void)pingProxyAtServer:(NSString *)server port:(NSInteger)port kind:(NSString *)kind username:(NSString *)username password:(NSString *)password secret:(NSString *)secret completion:(void (^)(double seconds))completion;
- (void)setArchiveSettingsArchiveAndMute:(BOOL)archiveAndMute keepUnmutedArchived:(BOOL)keepUnmuted keepFolderChatsArchived:(BOOL)keepFolders;
@end

@interface TGTextStylesStore (TGTestSupport)
- (NSArray *)textCompositionStyles;
@end

@interface TGGroupStore (TGTestSupport)
+ (NSDictionary *)chatPermissionsForPreset:(NSString *)preset;
@property (nonatomic, readonly) NSArray *communities;
@end
