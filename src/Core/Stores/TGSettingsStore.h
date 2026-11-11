//
// TGSettingsStore.h - the account, its privacy and its storage.
//
// One store for the settings pages: options, autosave, notification scopes,
// privacy rules, diagnostics, language packs, proxies, custom notification
// sounds, downloads, the file cache and the folders a chat can be filed in.
// Payments and the message-inspection console the Tier 3 page drives live here
// too, because those screens never get their own store.
//
// The store is the seam a settings screen talks to. The request bodies live
// here, not in the view: a screen names what it wants and the store builds the
// TDLib object. Reads that only expose the client's account cache are kept
// here too, so a screen never imports TGClient or one of its duty headers.
//
#import <Foundation/Foundation.h>
#import "TGClientTypes.h"
#import "TGClientNotifications.h"

@interface TGSettingsStore : NSObject

+ (instancetype)shared;

@end

@interface TGSettingsStore (State)
#pragma mark - state the pages read

/// TDLib's copy of archive-and-mute, a dictionary of booleans.
@property (nonatomic, readonly) NSDictionary *archiveSettings;
/// The account's saved background, or nil before Telegram sends one.
@property (nonatomic, readonly) NSDictionary *defaultBackground;
/// Notifications Telegram has queued while the app was away.
@property (nonatomic, readonly) BOOL havePendingNotifications;
/// The notification groups Telegram currently holds, newest first.
@property (nonatomic, readonly) NSArray *activeNotificationGroups;

/// The Tier 3 console's two logging rows. The level is TDLib's own: 1 is
/// errors only, 5 is everything.
- (void)setLogVerbosityLevel:(NSInteger)level;
@end


#pragma mark - Options
@interface TGSettingsStore (Options)

	- (void)optionValue:(NSString *)name completion:(void (^)(id value))completion;
	- (void)setOption:(NSString *)name boolValue:(BOOL)value;
	- (void)setOption:(NSString *)name integerValue:(int64_t)value;
	- (void)clearImportedContacts;
	- (void)importedContactCountWithCompletion:(void (^)(NSInteger count))completion;
	- (void)changeImportedContacts:(NSArray *)contacts completion:(void (^)(NSInteger importerCount, NSArray *userIds))completion;
	- (void)applicationDownloadLinkWithCompletion:(void (^)(NSString *url))completion;
	- (void)setProfilePhotoAtPath:(NSString *)path completion:(void (^)(BOOL ok))completion;
	- (void)myBirthdayWithCompletion:(void (^)(NSInteger day, NSInteger month, NSInteger year))completion;
	- (void)setBirthdayDay:(NSInteger)day month:(NSInteger)month year:(NSInteger)year completion:(void (^)(BOOL ok, NSString *error))completion;
	- (void)storiesForChat:(int64_t)chatId completion:(void (^)(NSArray *stories))completion;
@end


#pragma mark - Autosave
@interface TGSettingsStore (Autosave)

	- (void)autosaveSettingsWithCompletion:(void (^)(NSDictionary *settings))completion;
	- (void)setAutosaveSettingsForScope:(NSString *)scope photos:(BOOL)photos videos:(BOOL)videos maxVideoSize:(long long)maxVideoSize completion:(void (^)(BOOL ok))completion;
	- (void)clearAutosaveSettingsExceptionsWithCompletion:(void (^)(BOOL ok))completion;
@end


#pragma mark - Notifications
@interface TGSettingsStore (Notifications)

	- (void)notificationsMutedForScope:(NSString *)scope completion:(void (^)(BOOL muted))completion;
	- (void)setScope:(NSString *)scope muted:(BOOL)muted;
	- (void)notificationPreviewForScope:(NSString *)scope completion:(void (^)(BOOL show))completion;
	- (void)setScope:(NSString *)scope showPreview:(BOOL)show;
	- (void)resetAllNotificationSettings;
@end


#pragma mark - Privacy
@interface TGSettingsStore (Privacy)

	- (NSString *)nameForUserId:(int64_t)userId;
	- (void)userInfo:(int64_t)userId completion:(void (^)(NSDictionary *user))completion;
	- (void)mediaInChat:(int64_t)chatId filter:(NSString *)filter completion:(void (^)(NSArray *messages))completion;
	- (void)mediaInChat:(int64_t)chatId filter:(NSString *)filter fromMessageId:(int64_t)fromMessageId limit:(NSInteger)limit completion:(void (^)(NSArray *messages))completion;
	- (void)ensureUserName:(int64_t)userId completion:(void (^)(void))completion;
	- (void)terminateAllOtherSessions:(void (^)(BOOL ok))completion;
	- (void)checkRecoveryEmailCode:(NSString *)code completion:(void (^)(BOOL ok))completion;
	- (void)resendRecoveryEmailCode;
	- (void)deleteAccountWithReason:(NSString *)reason password:(NSString *)password completion:(void (^)(BOOL ok))completion;
	- (void)recentCallsWithCompletion:(void (^)(NSArray *calls))completion;
	- (void)privacyRule:(NSString *)setting completion:(void (^)(NSString *value))completion;
	- (void)privacyRuleDetails:(NSString *)setting completion:(void (^)(NSString *ruleType, NSArray *allowUserIds, NSArray *restrictUserIds))completion;
	- (void)setPrivacyRule:(NSString *)setting to:(NSString *)value;
	- (void)setPrivacyRule:(NSString *)setting to:(NSString *)value completion:(void (^)(BOOL ok, NSString *error))completion;
	- (void)setPrivacyRule:(NSString *)setting type:(NSString *)ruleType allowUserIds:(NSArray *)allowUserIds restrictUserIds:(NSArray *)restrictUserIds completion:(void (^)(BOOL ok, NSString *error))completion;
	- (void)blockedUsersWithCompletion:(void (^)(NSArray *users))completion;
	- (void)accountTtlWithCompletion:(void (^)(NSInteger days))completion;
	- (void)setAccountTtlDays:(NSInteger)days;
	- (void)languagesWithCompletion:(void (^)(NSArray *languages, NSString *current))completion;
	- (void)setLanguage:(NSString *)packId;
@end


#pragma mark - Diagnostics
@interface TGSettingsStore (Diagnostics)

/// YES once the key has been read; NO means it was never fetched.
- (BOOL)databaseEncryptionKeyIsKnown;
/// Whether a local database encryption key is in use.
- (BOOL)databaseEncryptionKeyIsSet;

	- (void)currentStateWithCompletion:(void (^)(NSArray *updates, NSString *error))completion;
	- (void)applicationConfigWithCompletion:(void (^)(NSDictionary *config, NSString *error))completion;
	- (void)databaseStatisticsWithCompletion:(void (^)(NSString *statistics, NSString *error))completion;
	- (void)setNetworkType:(NSString *)networkType completion:(void (^)(BOOL ok, NSString *error))completion;
	- (void)addNetworkStatisticsForNetworkType:(NSString *)networkType sentBytes:(long long)sent receivedBytes:(long long)received duration:(double)duration completion:(void (^)(BOOL ok, NSString *error))completion;
	- (void)statisticalGraphForChat:(int64_t)chatId token:(NSString *)token x:(NSInteger)x completion:(void (^)(NSDictionary *graph, NSString *error))completion;
	- (void)sendCustomRequestMethod:(NSString *)method parameters:(NSString *)parameters completion:(void (^)(NSString *result, NSString *error))completion;
	- (BOOL)databaseEncryptionKeyIsKnown;
	- (BOOL)databaseEncryptionKeyIsSet;
	- (void)setDatabaseEncryptionKey:(NSData *)newKey completion:(void (^)(BOOL ok, NSString *error))completion;
@end


#pragma mark - Language
@interface TGSettingsStore (Language)

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
	- (void)parseMarkdownText:(NSString *)text completion:(void (^)(NSDictionary *formatted))completion;
	- (void)textEntitiesInText:(NSString *)text completion:(void (^)(NSArray *entities))completion;
	- (void)translateText:(NSString *)text toLanguageCode:(NSString *)languageCode tone:(NSString *)tone completion:(void (^)(NSString *text))completion;
@end


#pragma mark - Proxy
@interface TGSettingsStore (Proxy)

	- (void)proxiesWithCompletion:(void (^)(NSArray *proxies))completion;
	- (void)addProxyAtServer:(NSString *)server port:(NSInteger)port kind:(NSString *)kind username:(NSString *)username password:(NSString *)password secret:(NSString *)secret enable:(BOOL)enable completion:(void (^)(NSInteger proxyId))completion;
	- (BOOL)addProxyFromLink:(NSString *)link completion:(void (^)(NSInteger proxyId))completion;
	- (void)editProxy:(NSInteger)proxyId server:(NSString *)server port:(NSInteger)port kind:(NSString *)kind username:(NSString *)username password:(NSString *)password secret:(NSString *)secret enable:(BOOL)enable completion:(void (^)(BOOL ok))completion;
	- (void)testProxyAtServer:(NSString *)server port:(NSInteger)port kind:(NSString *)kind username:(NSString *)username password:(NSString *)password secret:(NSString *)secret completion:(void (^)(BOOL works))completion;
	- (void)enableProxy:(NSInteger)proxyId;
	- (void)disableProxy;
	- (void)removeProxy:(NSInteger)proxyId;
	- (void)pingProxyAtServer:(NSString *)server port:(NSInteger)port kind:(NSString *)kind username:(NSString *)username password:(NSString *)password secret:(NSString *)secret completion:(void (^)(double seconds))completion;
	- (void)processWebProxyCarrierMessage:(NSInteger)carrierId text:(NSString *)text completion:(void (^)(BOOL ok, NSString *error))completion;
	- (void)processWebProxyCarrierMessage:(NSInteger)carrierId base64:(NSString *)base64 completion:(void (^)(BOOL ok, NSString *error))completion;
	- (void)reportWebProxyCarrierError:(NSInteger)carrierId kind:(NSString *)kind message:(NSString *)message completion:(void (^)(BOOL ok, NSString *error))completion;
@end


#pragma mark - SystemNotifications
@interface TGSettingsStore (SystemNotifications)

	- (void)savedNotificationSoundsWithCompletion: (void (^)(NSArray *sounds))completion;
	- (void)savedNotificationSound:(int64_t)soundId completion:(void (^)(NSDictionary *sound))completion;
	- (void)addSavedNotificationSoundAtPath:(NSString *)path completion:(void (^)(NSDictionary *sound, NSString *error))completion;
	- (void)removeSavedNotificationSound:(int64_t)soundId completion:(void (^)(BOOL ok, NSString *error))completion;
	- (void)removeNotification:(int32_t)notificationId inGroup:(int32_t)groupId completion:(void (^)(BOOL ok, NSString *error))completion;
	- (void)removeNotificationGroup:(int32_t)groupId maxNotificationId:(int32_t)maxNotificationId completion:(void (^)(BOOL ok, NSString *error))completion;
@end


#pragma mark - Storage
@interface TGSettingsStore (Storage)

	- (void)downloadFile:(NSInteger)fileId completion:(void (^)(NSString *path))completion;
	- (void)downloadFile:(NSInteger)fileId priority:(NSInteger)priority completion:(void (^)(NSString *path))completion;
	- (void)networkStatsWithCompletion:(void (^)(long long sent, long long received))completion;
	- (void)resetNetworkStats;
	- (BOOL)autoDownloadOverMobile;
	- (BOOL)autoDownloadOverWifi;
	- (void)setAutoDownloadOverMobile:(BOOL)mobile wifi:(BOOL)wifi;
	- (void)storageStatsWithCompletion:(void (^)(long long bytes, NSInteger files))completion;
	- (void)clearCacheOfTypes:(NSArray *)kinds completion:(void (^)(long long freed))completion;
	- (void)storageBreakdownWithCompletion:(void (^)(NSArray *categories, long long total))completion;
	- (void)clearLocalDatabase;
	- (void)fileInfo:(NSInteger)fileId completion:(void (^)(NSDictionary *info))completion;
	- (void)fileDownloadedPrefixSize:(NSInteger)fileId offset:(long long)offset completion:(void (^)(long long bytes))completion;
	- (void)fileNameInfo:(NSString *)name completion:(void (^)(NSDictionary *info))completion;
	- (void)suggestedFileNameForFile:(NSInteger)fileId directory:(NSString *)directory completion:(void (^)(NSString *name))completion;
	- (void)readFilePartOfFile:(NSInteger)fileId offset:(long long)offset count:(NSInteger)count completion:(void (^)(NSData *data))completion;
	- (void)cancelPreliminaryUploadOfFile:(NSInteger)fileId;
	- (void)generateTextFileNamed:(NSString *)name contents:(NSString *)contents progress:(void (^)(NSInteger fileId, float progress, NSString *stage))progress completion:(void (^)(NSInteger fileId, NSString *path, NSError *error))completion;
	- (void)autoDownloadSettingsPresetsWithCompletion: (void (^)(NSDictionary *presets))completion;
	- (void)applyAutoDownloadPreset:(NSDictionary *)preset forNetwork:(NSString *)network completion:(void (^)(BOOL ok))completion;
@end


#pragma mark - Folders
@interface TGSettingsStore (Folders)

	- (int64_t)lastReadOutboxForChat:(int64_t)chatId;
	- (int64_t)lastReadInboxForChat:(int64_t)chatId;
	- (NSNumber *)photoFileIdForChat:(int64_t)chatId;
	- (void)mergeActionBar:(NSDictionary *)bar intoChatRow:(NSMutableDictionary *)row;
	- (void)memberCountForChat:(int64_t)chatId completion:(void (^)(NSInteger count))completion;
	- (void)chatKindForChat:(int64_t)chatId completion:(void (^)(NSDictionary *kind))completion;
	- (void)joinChat:(int64_t)chatId completion:(void (^)(BOOL ok, BOOL requestSent))completion;
	- (void)closeChat:(int64_t)chatId;
	- (void)createFolderNamed:(NSString *)name icon:(NSString *)icon withChats:(NSArray *)chatIds completion:(void (^)(NSInteger folderId))completion;
	- (void)folderDetails:(NSInteger)folderId completion:(void (^)(NSDictionary *folder))completion;
	- (void)editFolder:(NSInteger)folderId name:(NSString *)name chats:(NSArray *)chatIds completion:(void (^)(BOOL ok))completion;
	- (void)deleteFolder:(NSInteger)folderId leavingChats:(NSArray *)leaveChatIds;
	- (void)reorderFolderIds:(NSArray *)folderIds mainListAt:(NSInteger)position;
	- (void)reorderFoldersToLocalIds:(NSArray *)folderIds mainListAt:(NSInteger)position;
	- (void)recommendedFoldersWithCompletion:(void (^)(NSArray *folders))completion;
	- (void)createRecommendedFolder:(NSDictionary *)folder completion:(void (^)(NSInteger folderId))completion;
	- (void)readChatListOfFolder:(NSInteger)folderId archived:(BOOL)archived;
	- (void)refreshArchiveChatListSettings:(void (^)(void))completion;
	- (void)setArchiveSettingsArchiveAndMute:(BOOL)archiveAndMute keepUnmutedArchived:(BOOL)keepUnmuted keepFolderChatsArchived:(BOOL)keepFolders;
@end


#pragma mark - Tools
@interface TGSettingsStore (Tools)

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
	- (void)chatListsForChat:(int64_t)chatId completion:(void (^)(NSArray *lists))completion;
	- (void)toggleFolderTags:(BOOL)on;
	- (void)inviteLink:(NSString *)link inChat:(int64_t)chatId completion:(void (^)(NSDictionary *info))completion;
	- (void)inviteLinkCountsForChat:(int64_t)chatId completion:(void (^)(NSArray *counts))completion;
	- (void)membersOfInviteLink:(NSString *)link inChat:(int64_t)chatId completion:(void (^)(NSArray *members))completion;
	- (void)createSubscriptionInviteLink:(int64_t)chatId name:(NSString *)name stars:(NSInteger)stars period:(NSInteger)period completion:(void (^)(NSString *link))completion;
	- (void)editSubscriptionInviteLink:(NSString *)link inChat:(int64_t)chatId name:(NSString *)name completion:(void (^)(BOOL ok))completion;
	- (void)editInviteLink:(NSString *)link inChat:(int64_t)chatId name:(NSString *)name expiration:(NSInteger)expiration memberLimit:(NSInteger)memberLimit joinRequest:(BOOL)joinRequest completion:(void (^)(BOOL ok))completion;
	- (void)deleteRevokedInviteLink:(NSString *)link inChat:(int64_t)chatId completion:(void (^)(BOOL ok))completion;
	- (void)deleteAllRevokedInviteLinks:(int64_t)chatId creator:(int64_t)creatorId completion:(void (^)(BOOL ok))completion;
	- (void)answerJoinRequestQuery:(int64_t)queryId approve:(BOOL)approve completion:(void (^)(BOOL ok))completion;
	- (void)processAllJoinRequests:(int64_t)chatId link:(NSString *)link approve:(BOOL)approve completion:(void (^)(BOOL ok))completion;
	- (void)deleteReplyMarkupInChat:(int64_t)chatId messageId:(int64_t)messageId;
	- (void)dismissReplyMarkupInChat:(int64_t)chatId;
	- (void)searchRecentlyFoundChats:(NSString *)query completion:(void (^)(NSArray *chats))completion;
	- (void)forgetRecentlyFoundChat:(int64_t)chatId;
	- (void)clearRecentlyFoundChats;
	- (void)similarChatsForChat:(int64_t)chatId completion:(void (^)(NSArray *chats, NSInteger total))completion;
	- (void)openSimilarChat:(int64_t)openedChatId fromChat:(int64_t)chatId;
	- (void)recommendedChatsWithCompletion:(void (^)(NSArray *chats))completion;
	- (void)suitableDiscussionChatsWithCompletion:(void (^)(NSArray *chats))completion;
	- (void)suitablePersonalChatsWithCompletion:(void (^)(NSArray *chats))completion;
	- (void)setPersonalChat:(int64_t)chatId completion:(void (^)(BOOL ok))completion;
	- (void)inactiveSupergroupChatsWithCompletion:(void (^)(NSArray *chats))completion;
	- (void)createdPublicChatsOfType:(NSString *)type completion:(void (^)(NSArray *chats))completion;
	- (void)checkCreatedPublicChatsLimitForType:(NSString *)type completion:(void (^)(BOOL ok, NSString *reason))completion;
	- (void)checkUsername:(NSString *)username forChat:(int64_t)chatId completion:(void (^)(NSString *result))completion;
	- (void)newChatPrivacySettingsWithCompletion: (void (^)(NSDictionary *settings))completion;
	- (void)setNewChatPrivacyAllowUnknown:(BOOL)allowUnknown completion:(void (^)(BOOL ok))completion;
	- (void)notificationExceptionsWithCompletion: (void (^)(NSArray *chats))completion;
	- (void)chatRecordForChat:(int64_t)chatId completion:(void (^)(NSDictionary *chat))completion;
	- (void)groupFullInfoForChat:(int64_t)chatId completion:(void (^)(NSDictionary *info))completion;
	- (void)addChat:(int64_t)chatId toList:(NSDictionary *)list completion:(void (^)(BOOL ok))completion;
	- (void)ownerAfterLeavingChat:(int64_t)chatId completion:(void (^)(NSDictionary *user))completion;
	- (void)chatStatisticsForChat:(int64_t)chatId completion:(void (^)(NSArray *rows, NSString *kind))completion;
	- (void)eventLogForChat:(int64_t)chatId completion:(void (^)(NSArray *events))completion;
	- (void)reportChatPhotoInChat:(int64_t)chatId reason:(NSString *)reason detail:(NSString *)detail completion:(void (^)(BOOL ok))completion;
	- (void)defaultChatPhotoEmojiStickersWithCompletion: (void (^)(NSArray *stickers))completion;
	- (void)setEmojiPhotoForChat:(int64_t)chatId customEmojiId:(int64_t)customEmojiId colour:(NSInteger)colour completion:(void (^)(BOOL ok))completion;
	- (void)setChatAccentColour:(int64_t)chatId colourId:(NSInteger)colourId;
	- (void)setChatProfileAccentColour:(int64_t)chatId colourId:(NSInteger)colourId;
	- (void)setChatTheme:(int64_t)chatId name:(NSString *)name completion:(void (^)(BOOL ok))completion;
	- (void)setChatBackground:(int64_t)chatId imagePath:(NSString *)imagePath colour:(NSInteger)colour onlyForSelf:(BOOL)onlyForSelf completion:(void (^)(BOOL ok))completion;
	- (void)deleteChatBackground:(int64_t)chatId restorePrevious:(BOOL)restore;
	- (void)setAvailableReactionsForChat:(int64_t)chatId mode:(NSString *)mode completion:(void (^)(BOOL ok))completion;
	- (void)setSlowModeDelayForChat:(int64_t)chatId seconds:(NSInteger)seconds completion:(void (^)(BOOL ok))completion;
	- (void)toggleTranslatableForChat:(int64_t)chatId on:(BOOL)on;
	- (void)toggleProtectedContentForChat:(int64_t)chatId on:(BOOL)on completion:(void (^)(BOOL ok))completion;
	- (void)toggleDefaultSilentForChat:(int64_t)chatId on:(BOOL)on;
	- (void)setClientNote:(NSString *)note forChat:(int64_t)chatId completion:(void (^)(BOOL ok))completion;
	- (void)setDiscussionGroup:(int64_t)discussionChatId forChat:(int64_t)chatId completion:(void (^)(BOOL ok))completion;
	- (void)setLocationAddress:(NSString *)address forChat:(int64_t)chatId completion:(void (^)(BOOL ok))completion;
	- (void)setMemberTag:(NSString *)tag forUser:(int64_t)userId inChat:(int64_t)chatId completion:(void (^)(BOOL ok))completion;
	- (void)processProtectedContentDisableRequestInChat:(int64_t)chatId messageId:(int64_t)messageId approve:(BOOL)approve completion:(void (^)(BOOL ok))completion;
	- (void)sparsePositionsInChat:(int64_t)chatId filter:(NSString *)filter fromMessage:(int64_t)messageId completion:(void (^)(NSInteger total, NSArray *positions))completion;
	- (void)messagePosition:(int64_t)messageId inChat:(int64_t)chatId filter:(NSString *)filter completion:(void (^)(NSInteger position, NSInteger total))completion;
	- (void)toggleSession:(int64_t)sessionId canAcceptSecretChats:(BOOL)can;
	- (void)chatForBasicGroup:(int64_t)basicGroupId completion:(void (^)(int64_t chatId))completion;
	- (void)chatForSupergroup:(int64_t)supergroupId completion:(void (^)(int64_t chatId))completion;
	- (void)chatForSecretChat:(int32_t)secretChatId completion:(void (^)(int64_t chatId))completion;
@end


#pragma mark - Downloads
@interface TGSettingsStore (Downloads)

	- (void)cancelDownloadOfFile:(NSInteger)fileId onlyIfPending:(BOOL)onlyIfPending;
	- (void)deleteLocalFile:(NSInteger)fileId;
	- (void)addFileToDownloads:(NSInteger)fileId inChat:(int64_t)chatId message:(int64_t)messageId;
	- (void)fileDownloadsMatching:(NSString *)query activeOnly:(BOOL)activeOnly completion:(void (^)(NSArray *downloads, NSInteger activeCount))completion;
	- (void)setDownloadOfFile:(NSInteger)fileId paused:(BOOL)paused;
	- (void)setAllDownloadsPaused:(BOOL)paused;
	- (void)removeFileFromDownloads:(NSInteger)fileId deleteFromCache:(BOOL)deleteFromCache;
	- (void)clearDownloadsDeletingFromCache:(BOOL)deleteFromCache;
@end


#pragma mark - Payments
@interface TGSettingsStore (Payments)

	- (void)savedOrderInfoWithCompletion:(void (^)(NSDictionary *order, NSString *error))completion;
	- (void)deleteSavedOrderInfoWithCompletion:(void (^)(BOOL ok, NSString *error))completion;
	- (void)bankCardInfoForNumber:(NSString *)number completion:(void (^)(NSDictionary *info, NSString *error))completion;
	- (void)addOfferToMessage:(int64_t)messageId inChat:(int64_t)chatId starCount:(int64_t)starCount sendDate:(int32_t)sendDate completion:(void (^)(NSDictionary *message, NSString *error))completion;
	- (void)validateOrderInfoForInvoice:(NSString *)invoiceName order:(NSDictionary *)order allowSave:(BOOL)allowSave completion:(void (^)(NSDictionary *validated, NSString *error))completion;
@end


#pragma mark - MessageMeta
@interface TGSettingsStore (MessageMeta)

	- (void)messageLinkInfo:(NSString *)link completion:(void (^)(int64_t chatId, int64_t messageId))completion;
	- (void)clearAllDraftMessages;
	- (void)defaultMessageAutoDeleteTimeWithCompletion: (void (^)(NSInteger seconds))completion;
	- (void)setDefaultMessageAutoDeleteTime:(NSInteger)seconds;
	- (void)viewersOfMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(NSArray *viewers))completion;
	- (void)readDateOfMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(NSTimeInterval date, NSString *reason))completion;
	- (void)authorOfMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(NSDictionary *user))completion;
	- (void)embeddingCodeOfMessage:(int64_t)messageId inChat:(int64_t)chatId album:(BOOL)album completion:(void (^)(NSString *code))completion;
	- (void)publicForwardsOfMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(NSArray *messages))completion;
	- (void)availableReactionsForMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(NSArray *emojis))completion;
	- (void)addedReactionsOfMessage:(int64_t)messageId inChat:(int64_t)chatId emoji:(NSString *)emoji offset:(NSString *)offset completion:(void (^)(NSArray *rows, NSString *next))completion;
	- (void)addedReactionsOfMessage:(int64_t)messageId inChat:(int64_t)chatId reactionType:(NSDictionary *)reactionType offset:(NSString *)offset completion:(void (^)(NSArray *rows, NSString *next))completion;
	- (void)deleteReactionsOfSender:(NSDictionary *)sender ofMessage:(int64_t)messageId inChat:(int64_t)chatId;
	- (void)deleteAllReactionsOfSender:(NSDictionary *)sender inChat:(int64_t)chatId;
	- (void)messageCountInChat:(int64_t)chatId thread:(int64_t)threadId completion:(void (^)(NSInteger count))completion;
	- (void)messageCountInChat:(int64_t)chatId filter:(NSString *)filterType completion:(void (^)(NSInteger count))completion;
	- (void)calendarJumpForChat:(int64_t)chatId endDate:(NSInteger)end completion:(void (^)(int64_t messageId, NSInteger total))completion;
	- (void)clearAllCallMessages;
	- (void)sentDocuments:(NSString *)query completion:(void (^)(NSArray *messages))completion;
	- (void)publicMessagesByTag:(NSString *)tag offset:(NSString *)offset completion:(void (^)(NSArray *messages, NSString *next))completion;
	- (void)recentLocationsInChat:(int64_t)chatId completion:(void (^)(NSArray *messages))completion;
	- (void)translateMessage:(int64_t)messageId inChat:(int64_t)chatId toCode:(NSString *)languageCode completion:(void (^)(NSString *text))completion;
	- (void)messageEffectWithId:(int64_t)effectId completion:(void (^)(NSDictionary *effect))completion;
	- (void)messageFileTypeForHead:(NSString *)head completion:(void (^)(NSDictionary *fileType))completion;
	- (void)importConfirmationTextForChat:(int64_t)chatId completion:(void (^)(NSString *text))completion;
	- (void)importMessagesFromFile:(NSString *)path attachedFiles:(NSArray *)attachedPaths intoChat:(int64_t)chatId completion:(void (^)(BOOL ok))completion;
	- (void)preparedInlineMessageFromBot:(int64_t)botUserId preparedMessageId:(NSString *)preparedMessageId completion:(void (^)(NSDictionary *prepared))completion;
	- (void)savePreparedInlineMessageForUser:(int64_t)userId text:(NSString *)text title:(NSString *)title completion:(void (^)(NSString *preparedMessageId))completion;
	- (void)sendTextDraft:(NSString *)text toChat:(int64_t)chatId topic:(int64_t)topicId draftId:(int64_t)draftId canStop:(BOOL)canStop keep:(BOOL)keepOnStop completion:(void (^)(BOOL ok))completion;
	- (void)stopTextDraft:(int64_t)draftId inChat:(int64_t)chatId topic:(int64_t)topicId completion:(void (^)(BOOL ok))completion;
@end


#pragma mark - MessageRecord
@interface TGSettingsStore (MessageRecord)

	- (void)addLocalTextMessage:(NSString *)text toChat:(int64_t)chatId completion:(void (^)(int64_t messageId))completion;
	- (void)clickAnimatedEmojiMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(NSString *emoji))completion;
	- (void)clearReplyMarkupOfMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(BOOL ok))completion;
	- (void)callbackQueryMessage:(int64_t)messageId inChat:(int64_t)chatId callbackQueryId:(int64_t)callbackQueryId completion:(void (^)(NSDictionary *message))completion;
	- (void)localMessageWithId:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(NSDictionary *message))completion;
	- (void)positionOfMessage:(int64_t)messageId inChat:(int64_t)chatId thread:(int64_t)threadId completion:(void (^)(NSInteger position))completion;
	- (void)sparsePositionsInChat:(int64_t)chatId fromMessageId:(int64_t)fromMessageId thread:(int64_t)threadId limit:(NSInteger)limit completion:(void (^)(NSArray *messageIds))completion;
	- (void)statisticsOfMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(NSDictionary *statistics))completion;
	- (void)reportViewOfMessage:(int64_t)messageId inChat:(int64_t)chatId timeInViewMs:(NSInteger)timeInViewMs activeTimeInViewMs:(NSInteger)activeTimeInViewMs heightRatio:(NSInteger)heightPerMille seenRangeRatio:(NSInteger)seenPerMille completion:(void (^)(BOOL ok))completion;
	- (void)setReactions:(NSArray *)emojis onMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(BOOL ok))completion;
	- (void)personalChatHistoryForUser:(int64_t)userId limit:(NSInteger)limit completion:(void (^)(NSArray *messages))completion;
@end


#pragma mark - InlineMessages
@interface TGSettingsStore (InlineMessages)

	- (void)pinMessage:(int64_t)messageId inChat:(int64_t)chatId notify:(BOOL)notify;
	- (void)unpinMessage:(int64_t)messageId inChat:(int64_t)chatId;
	- (void)unpinAllMessagesInChat:(int64_t)chatId thread:(int64_t)threadId;
	- (void)messageAtDate:(NSTimeInterval)date inChat:(int64_t)chatId completion:(void (^)(NSDictionary *message))completion;
	- (void)editInlineMessageText:(NSString *)inlineMessageId text:(NSString *)text completion:(void (^)(BOOL ok))completion;
	- (void)editInlineMessageCaption:(NSString *)inlineMessageId caption:(NSString *)caption completion:(void (^)(BOOL ok))completion;
	- (void)clearInlineMessageReplyMarkup:(NSString *)inlineMessageId completion:(void (^)(BOOL ok))completion;
	- (void)editInlineMessagePhoto:(NSString *)inlineMessageId photoId:(int64_t)photoId caption:(NSString *)caption completion:(void (^)(BOOL ok))completion;
	- (void)editInlineMessageLiveLocation:(NSString *)inlineMessageId latitude:(double)latitude longitude:(double)longitude completion:(void (^)(BOOL ok))completion;
	- (void)linkPreviewForText:(NSString *)text completion:(void (^)(NSDictionary *preview))completion;
	- (void)internalLinkKind:(NSString *)link completion:(void (^)(NSString *kind, NSString *value))completion;
	- (void)markdownOfMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(NSString *markdown))completion;
	- (void)reportSpamMessages:(NSArray *)messageIds inChat:(int64_t)chatId completion:(void (^)(BOOL ok))completion;
	- (void)blockSenderOfMessage:(int64_t)messageId deleteMessages:(BOOL)deleteMessages reportSpam:(BOOL)reportSpam;
	- (void)stopPoll:(int64_t)messageId inChat:(int64_t)chatId;
	- (void)pollVotersOfOption:(NSInteger)optionIndex ofMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(NSArray *voters, BOOL end))completion;
	- (void)pollVoteStatisticsOfMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(NSDictionary *graph))completion;
	- (void)addPollOption:(NSString *)text toMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(BOOL ok))completion;
	- (void)deletePollOption:(NSString *)optionId ofMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(BOOL ok))completion;
	- (void)pollOptionProperties:(NSString *)optionId ofMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(NSDictionary *properties, NSString *error))completion;
	- (void)readAllChatPollVotes:(int64_t)chatId;
	- (void)reportReactionBySender:(NSDictionary *)sender ofMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(BOOL ok))completion;
	- (void)reactTo:(int64_t)messageId inChat:(int64_t)chatId emoji:(NSString *)emoji;
	- (void)removeReaction:(NSString *)emoji fromMessage:(int64_t)messageId inChat:(int64_t)chatId;
	- (void)sendTypingToChat:(int64_t)chatId thread:(int64_t)threadId;
	- (void)cancelTypingInChat:(int64_t)chatId thread:(int64_t)threadId;
	- (void)openContentOfMessage:(int64_t)messageId inChat:(int64_t)chatId;
	- (void)resendMessages:(NSArray *)messageIds inChat:(int64_t)chatId;
	- (void)repliedMessageTo:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(NSDictionary *message))completion;
	- (void)messagesInChat:(int64_t)chatId messageIds:(NSArray *)messageIds completion:(void (^)(NSArray *messages))completion;
	- (void)messagePropertiesForChat:(int64_t)chatId messageId:(int64_t)messageId completion:(void (^)(NSDictionary *properties))completion;
	- (void)linkToMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(NSString *link))completion;
	- (void)deleteMessage:(int64_t)messageId inChat:(int64_t)chatId;
	- (void)deleteMessages:(NSArray *)messageIds inChat:(int64_t)chatId;
	- (void)deleteMessages:(NSArray *)messageIds inChat:(int64_t)chatId revoke:(BOOL)revoke;
	- (void)markRead:(NSArray *)messageIds inChat:(int64_t)chatId;
@end


#pragma mark - Reactions
@interface TGSettingsStore (Reactions)

/// The recent-reactions switch. The same value the privacy page draws.
@property (nonatomic, readonly) BOOL reactionNotificationsEnabled;

/// The other two rows the reactions page edits.
- (void)clearRecentReactionsWithCompletion:(void (^)(BOOL ok))completion;
- (void)setDefaultReactionEmoji:(NSString *)emoji
					 completion:(void (^)(BOOL ok))completion;

	- (void)setReactionNotificationsEnabled:(BOOL)enabled completion:(void (^)(BOOL ok))completion;
@end


#pragma mark - BotTools
@interface TGSettingsStore (BotTools)

	- (void)preparedKeyboardButtonFromBot:(int64_t)botUserId preparedButtonId:(NSString *)preparedButtonId completion:(void (^)(NSDictionary *button, NSString *error))completion;
	- (void)savePreparedKeyboardButtonText:(NSString *)text forUser:(int64_t)userId completion:(void (^)(NSString *preparedButtonId, NSString *error))completion;
@end


#pragma mark - Calls
@interface TGSettingsStore (Calls)

	- (void)sendCallLog:(NSString *)log forMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(BOOL ok, NSString *error))completion;
	- (void)sendCallDebugInformation:(NSString *)information forMessage:(int64_t)messageId inChat:(int64_t)chatId completion:(void (^)(BOOL ok, NSString *error))completion;
@end

@interface TGSettingsStore (BasicGroups)
#pragma mark - the debug resolver

/// A basic group's record and the chat that carries its name, in one call.
- (void)basicGroupInfo:(int64_t)basicGroupId
			completion:(void (^)(NSDictionary *info))completion;
@end
